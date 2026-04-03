import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/app_constants.dart';
import '../services/api_service.dart';

enum ActivityType { still, walking, driving, unknown }

class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _batteryTimer;
  Timer? _stillTimer; // timer per rilevare quando l'utente si ferma

  ActivityType _currentActivity = ActivityType.unknown;
  Position?    _lastSentPosition;
  DateTime?    _lastSentTime;
  DateTime?    _lastMovedTime;   // ultima volta che il GPS registrava movimento
  double       _accelMagnitude = 9.8; // 1g di default (fermo)

  final _activityController = StreamController<ActivityType>.broadcast();
  Stream<ActivityType> get activityStream => _activityController.stream;
  ActivityType get currentActivity => _currentActivity;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  bool _running = false;
  int  _batteryLevel = 100;
  final _battery = Battery();

  /// Avvia tutti i servizi di rilevamento posizione e batteria
  Future<void> start() async {
    if (_running) return;
    _running = true;

    // Leggi subito la batteria
    await _updateBattery();
    // Aggiorna la batteria ogni 60 secondi
    _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) => _updateBattery());

    // Accelerometro per attività detection più precisa
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 300),
    ).listen(_onAccel);

    // Stream GPS — su Android usa AndroidSettings per background location
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,                     // ricevi ogni 3 m (più reattivo)
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'FamilyTrack sta rilevando la tua posizione',
        notificationTitle: 'Posizione attiva',
        enableWakeLock: true,
      ),
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(_onPosition, onError: (e) => debugPrint('[GPS] Error: $e'));
  }

  Future<void> _updateBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      debugPrint('[Battery] Level: $_batteryLevel%');
    } catch (e) {
      debugPrint('[Battery] Read error: $e');
    }
  }

  void stop() {
    _running = false;
    _positionSub?.cancel();
    _accelSub?.cancel();
    _batteryTimer?.cancel();
    _stillTimer?.cancel();
  }

  void dispose() {
    stop();
    _activityController.close();
    _positionController.close();
  }

  // ── Accelerometro ──────────────────────────────────────────
  void _onAccel(AccelerometerEvent e) {
    // Magnitudine vettore accelerazione (include gravità ~9.8)
    _accelMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  }

  // ── GPS position update ─────────────────────────────────────
  void _onPosition(Position pos) {
    _positionController.add(pos);

    final speedMs = pos.speed < 0 ? 0.0 : pos.speed;

    // Classifica l'attività in base a velocità GPS + accelerometro
    final newActivity = _classifyActivity(speedMs);

    // Aggiorna il timer dell'ultimo movimento
    if (speedMs > AppConstants.walkingSpeedThresholdMs) {
      _lastMovedTime = DateTime.now();
      _stillTimer?.cancel();
    } else if (_lastMovedTime != null) {
      // Se fermo da più di 2 minuti → forza "still" e invia aggiornamento
      _stillTimer?.cancel();
      _stillTimer = Timer(const Duration(minutes: 2), () {
        if (_currentActivity != ActivityType.still) {
          _currentActivity = ActivityType.still;
          _activityController.add(ActivityType.still);
          // Forza invio immediato per aggiornare lo stato sul server
          if (_lastSentPosition != null) {
            _sendUpdate(_lastSentPosition!, 0, ActivityType.still);
          }
        }
      });
    }

    if (newActivity != _currentActivity) {
      _currentActivity = newActivity;
      _activityController.add(newActivity);
    }

    if (_shouldSend(pos, speedMs)) {
      _lastSentPosition = pos;
      _lastSentTime     = DateTime.now();
      _sendUpdate(pos, speedMs, newActivity);
    }
  }

  ActivityType _classifyActivity(double speedMs) {
    if (speedMs >= AppConstants.drivingSpeedThresholdMs) return ActivityType.driving;
    if (speedMs >= AppConstants.walkingSpeedThresholdMs) return ActivityType.walking;
    // Accelerometro: differenza dalla gravità (9.8) > soglia → movimento
    final accelDelta = (_accelMagnitude - 9.8).abs();
    if (accelDelta > 1.5) return ActivityType.walking;
    return ActivityType.still;
  }

  bool _shouldSend(Position pos, double speedMs) {
    final now         = DateTime.now();
    final intervalMs  = _intervalForActivity(_currentActivity);
    final minDistM    = _distanceForActivity(_currentActivity);

    final timeOk = _lastSentTime == null ||
        now.difference(_lastSentTime!).inMilliseconds >= intervalMs;

    final distOk = _lastSentPosition == null ||
        Geolocator.distanceBetween(
          _lastSentPosition!.latitude, _lastSentPosition!.longitude,
          pos.latitude, pos.longitude,
        ) >= minDistM;

    // In guida: invia sempre se la velocità è cambiata di più di 5 km/h
    final speedChanged = _currentActivity == ActivityType.driving &&
        _lastSentPosition != null &&
        (speedMs - (_lastSentPosition!.speed < 0 ? 0 : _lastSentPosition!.speed)).abs() > 1.4;

    return (timeOk && distOk) || speedChanged;
  }

  int _intervalForActivity(ActivityType a) {
    switch (a) {
      case ActivityType.driving: return AppConstants.locationIntervalDrivingMs;
      case ActivityType.walking: return AppConstants.locationIntervalWalkingMs;
      default:                   return AppConstants.locationIntervalStillMs;
    }
  }

  double _distanceForActivity(ActivityType a) {
    switch (a) {
      case ActivityType.driving: return AppConstants.locationMinDistanceDrivingM;
      case ActivityType.walking: return AppConstants.locationMinDistanceWalkingM;
      default:                   return AppConstants.locationMinDistanceStillM;
    }
  }

  Future<void> _sendUpdate(Position pos, double speedMs, ActivityType activity) async {
    try {
      await ApiService().updateLocation({
        'latitude':       pos.latitude,
        'longitude':      pos.longitude,
        'accuracy':       pos.accuracy,
        'speed':          speedMs,
        'heading':        pos.heading,
        'altitude':       pos.altitude,
        'activityStatus': _activityName(activity),
        'batteryLevel':   _batteryLevel,   // ora reale, non sempre 100
        'isAirplaneMode': false,
      });
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

  /// Richiede ALWAYS permission (necessario per background tracking)
  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GPS] Location services disabled');
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      debugPrint('[GPS] Permission denied forever');
      return false;
    }

    // Se abbiamo solo whileInUse, chiedi "always"
    if (perm == LocationPermission.whileInUse) {
      debugPrint('[GPS] Requesting always permission...');
      perm = await Geolocator.requestPermission();
    }

    debugPrint('[GPS] Permission: $perm');
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
