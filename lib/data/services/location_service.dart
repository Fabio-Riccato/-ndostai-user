import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/app_constants.dart';
import '../services/api_service.dart';

enum ActivityType { still, walking, driving, unknown }

/// Algoritmo adattivo stile Life360:
///
/// FERMO  → GPS ogni 60s, distanceFilter 50m
///          scopo: capire SE l'utente si muove, non dove
///
/// A PIEDI → GPS ogni 10s, distanceFilter 15m
///           scopo: tracciare il percorso a piedi
///
/// IN AUTO → GPS ogni 4s, distanceFilter 8m
///           scopo: tracciare il percorso e la velocità in tempo reale
///
/// Transizione still→moving: richiede 2 posizioni consecutive con
/// velocità > soglia e distanza > MIN_MOVE_TO_START (20m) prima di
/// cambiare stato. Questo evita falsi positivi (es. GPS drift).
///
/// Transizione moving→still: richiede velocità < soglia per 90 secondi
/// consecutivi prima di segnare l'utente come fermo.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  // ── Subscriptions ────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _batteryTimer;
  Timer? _stillConfirmTimer;   // attende N sec prima di confermare "still"
  Timer? _slowPollTimer;       // timer per poll periodico quando fermo

  // ── Stato interno ────────────────────────────────────────
  ActivityType _currentActivity  = ActivityType.unknown;
  ActivityType _pendingActivity  = ActivityType.unknown; // non ancora confermata
  int          _movingStreak     = 0;   // quante posizioni consecutive in movimento

  Position?    _lastSentPosition;
  DateTime?    _lastSentTime;
  DateTime?    _stoppedAt;      // momento esatto in cui ci si è fermati
  DateTime?    _startedMovingAt;

  double _accelMagnitude = 9.8; // gravità di default (fermo)

  final _activityController = StreamController<ActivityType>.broadcast();
  Stream<ActivityType> get activityStream => _activityController.stream;
  ActivityType get currentActivity => _currentActivity;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  bool _running     = false;
  int  _batteryLevel = 100;
  final _battery    = Battery();

  // ── Soglie ───────────────────────────────────────────────
  // Quante posizioni consecutive in movimento prima di cambiare stato
  static const int _movingStreakRequired = 2;
  // Distanza minima percorsa per considerare che ci si è mossi
  static const double _minMoveToStartM = 20.0;
  // Secondi di velocità zero prima di confermare "still"
  static const int _stillConfirmSec = 90;

  // ── Impostazioni GPS per ogni stato ─────────────────────
  // AndroidSettings non supporta const constructor → usiamo factory methods

  static AndroidSettings _settingsStill() => AndroidSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 50,
    intervalDuration: const Duration(seconds: 60),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'FamilyTrack è attivo',
      notificationTitle: 'FamilyTrack',
      enableWakeLock: false,
    ),
  );

  static AndroidSettings _settingsWalking() => AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    intervalDuration: const Duration(seconds: 8),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'FamilyTrack sta tracciando il tuo percorso',
      notificationTitle: 'Percorso in corso',
      enableWakeLock: true,
    ),
  );

  static AndroidSettings _settingsDriving() => AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 8,
    intervalDuration: const Duration(seconds: 4),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: 'FamilyTrack sta tracciando la tua guida',
      notificationTitle: 'Guida in corso',
      enableWakeLock: true,
    ),
  );

  Future<void> start() async {
    if (_running) return;
    _running = true;

    await _updateBattery();
    _batteryTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _updateBattery());

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen(_onAccel);

    // Avvia con impostazioni "fermo" — si aggiorna quando si muove
    await _startGpsStream(ActivityType.still);
  }

  /// Riavvia lo stream GPS con le impostazioni appropriate per l'attività
  Future<void> _startGpsStream(ActivityType activity) async {
    await _positionSub?.cancel();
    _slowPollTimer?.cancel();

    LocationSettings settings;
    switch (activity) {
      case ActivityType.driving:
        settings = _settingsDriving();
      case ActivityType.walking:
        settings = _settingsWalking();
      default:
        settings = _settingsStill();
    }

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) => debugPrint('[GPS] Error: $e'));

    debugPrint('[GPS] Stream riavviato per attività: ${activity.name}');
  }

  Future<void> _updateBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } catch (_) {}
  }

  void stop() {
    _running = false;
    _positionSub?.cancel();
    _accelSub?.cancel();
    _batteryTimer?.cancel();
    _stillConfirmTimer?.cancel();
    _slowPollTimer?.cancel();
  }

  void dispose() {
    stop();
    _activityController.close();
    _positionController.close();
  }

  // ── Accelerometro ────────────────────────────────────────
  void _onAccel(AccelerometerEvent e) {
    _accelMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  }

  // ── Ogni posizione GPS ────────────────────────────────────
  void _onPosition(Position pos) {
    _positionController.add(pos);

    final speedMs    = pos.speed < 0 ? 0.0 : pos.speed;
    final rawActivity = _classifyRaw(speedMs);

    _updateActivityStateMachine(pos, speedMs, rawActivity);

    if (_shouldSend(pos, speedMs)) {
      _lastSentPosition = pos;
      _lastSentTime     = DateTime.now();
      _sendUpdate(pos, speedMs, _currentActivity);
    }
  }

  // ── Macchina a stati per l'attività ──────────────────────
  void _updateActivityStateMachine(Position pos, double speedMs, ActivityType raw) {
    switch (_currentActivity) {
      case ActivityType.still:
      case ActivityType.unknown:
        _handleFromStill(pos, speedMs, raw);
      case ActivityType.walking:
        _handleFromWalking(pos, speedMs, raw);
      case ActivityType.driving:
        _handleFromDriving(pos, speedMs, raw);
    }
  }

  void _handleFromStill(Position pos, double speedMs, ActivityType raw) {
    if (raw == ActivityType.still) {
      _movingStreak = 0;
      return;
    }
    // Possibile inizio movimento
    _movingStreak++;

    // Verifica che ci sia anche una distanza reale percorsa
    if (_lastSentPosition != null) {
      final dist = Geolocator.distanceBetween(
        _lastSentPosition!.latitude, _lastSentPosition!.longitude,
        pos.latitude, pos.longitude,
      );
      if (dist < _minMoveToStartM) {
        _movingStreak = 0; // GPS drift, non è movimento reale
        return;
      }
    }

    if (_movingStreak >= _movingStreakRequired) {
      // Confermato: l'utente si è messo in movimento
      _movingStreak = 0;
      _stoppedAt = null;
      _startedMovingAt = DateTime.now();
      _stillConfirmTimer?.cancel();
      final newActivity = raw;
      _setActivity(newActivity);
      _startGpsStream(newActivity); // aumenta la frequenza GPS
    }
  }

  void _handleFromWalking(Position pos, double speedMs, ActivityType raw) {
    if (raw == ActivityType.driving) {
      _setActivity(ActivityType.driving);
      _startGpsStream(ActivityType.driving);
      _stillConfirmTimer?.cancel();
      return;
    }
    if (raw == ActivityType.still) {
      _scheduleStillConfirm(pos);
    } else {
      _stillConfirmTimer?.cancel(); // ancora in movimento
    }
  }

  void _handleFromDriving(Position pos, double speedMs, ActivityType raw) {
    if (raw == ActivityType.walking || raw == ActivityType.still) {
      // Potrebbe essere un semaforo: aspetta prima di retrocedere
      _scheduleStillConfirm(pos);
    } else {
      _stillConfirmTimer?.cancel();
    }
  }

  /// Avvia timer: se rimane fermo per _stillConfirmSec → conferma "still"
  void _scheduleStillConfirm(Position pos) {
    if (_stillConfirmTimer?.isActive == true) return; // già in corso
    _stillConfirmTimer = Timer(Duration(seconds: _stillConfirmSec), () {
      if (_currentActivity != ActivityType.still) {
        _stoppedAt = DateTime.now();
        _setActivity(ActivityType.still);
        _startGpsStream(ActivityType.still); // riduce la frequenza GPS
        // Invia subito un aggiornamento con lo stato "still"
        if (pos.latitude != 0) {
          _lastSentPosition = pos;
          _lastSentTime = DateTime.now();
          _sendUpdate(pos, 0, ActivityType.still);
        }
      }
    });
  }

  void _setActivity(ActivityType a) {
    if (a == _currentActivity) return;
    _currentActivity = a;
    _activityController.add(a);
    debugPrint('[Activity] Cambiato a: ${a.name}');
  }

  // ── Classificazione istantanea ────────────────────────────
  ActivityType _classifyRaw(double speedMs) {
    if (speedMs >= AppConstants.drivingSpeedThresholdMs) return ActivityType.driving;
    if (speedMs >= AppConstants.walkingSpeedThresholdMs) return ActivityType.walking;
    // Accelerometro come fallback quando il GPS è lento
    final accelDelta = (_accelMagnitude - 9.8).abs();
    if (accelDelta > 1.8) return ActivityType.walking;
    return ActivityType.still;
  }

  // ── Decisione invio ───────────────────────────────────────
  bool _shouldSend(Position pos, double speedMs) {
    // Prima posizione: invia sempre
    if (_lastSentPosition == null || _lastSentTime == null) return true;

    final now        = DateTime.now();
    final elapsedMs  = now.difference(_lastSentTime!).inMilliseconds;
    final dist       = Geolocator.distanceBetween(
      _lastSentPosition!.latitude, _lastSentPosition!.longitude,
      pos.latitude, pos.longitude,
    );

    switch (_currentActivity) {
      case ActivityType.still:
      // Fermo: invia solo ogni 5 minuti (keepalive)
        return elapsedMs >= 5 * 60 * 1000;

      case ActivityType.walking:
      // A piedi: ogni 10s E almeno 15m
        return elapsedMs >= 10000 && dist >= 15;

      case ActivityType.driving:
      // In auto: ogni 4s E almeno 8m
      // OPPURE se la velocità è cambiata di >8 km/h
        final prevSpeed = _lastSentPosition!.speed < 0 ? 0 : _lastSentPosition!.speed;
        final speedDelta = (speedMs - prevSpeed).abs();
        return (elapsedMs >= 4000 && dist >= 8) || speedDelta > 2.2;

      default:
        return elapsedMs >= 30000;
    }
  }

  // ── Invio al server ───────────────────────────────────────
  Future<void> _sendUpdate(Position pos, double speedMs, ActivityType activity) async {
    try {
      final payload = {
        'latitude':       pos.latitude,
        'longitude':      pos.longitude,
        'accuracy':       pos.accuracy,
        'speed':          speedMs,
        'heading':        pos.heading,
        'altitude':       pos.altitude,
        'activityStatus': _activityName(activity),
        'batteryLevel':   _batteryLevel,
        'isAirplaneMode': false,
      };
      // Manda il timestamp esatto di quando ci si è fermati
      if (activity == ActivityType.still && _stoppedAt != null) {
        payload['stoppedAt'] = _stoppedAt!.toIso8601String();
      }
      await ApiService().updateLocation(payload);
    } catch (e) {
      debugPrint('[Location] Send error: $e');
    }
  }

  String _activityName(ActivityType a) {
    switch (a) {
      case ActivityType.driving: return 'driving';
      case ActivityType.walking: return 'walking';
      case ActivityType.still:   return 'still';
      default:                   return 'unknown';
    }
  }

  static Future<bool> requestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}