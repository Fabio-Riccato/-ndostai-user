import 'dart:async';
import 'dart:math';
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

  ActivityType _currentActivity = ActivityType.unknown;
  Position?    _lastSentPosition;
  DateTime?    _lastSentTime;
  double       _accelMagnitude = 0;

  final _activityController = StreamController<ActivityType>.broadcast();
  Stream<ActivityType> get activityStream => _activityController.stream;
  ActivityType get currentActivity => _currentActivity;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  bool _running = false;
  int _batteryLevel = 100;

  /// Call once on app start after permissions granted
  Future<void> start() async {
    if (_running) return;
    _running = true;

    // Accelerometer for activity detection
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen(_onAccel);

    // Continuous GPS stream (we throttle sending ourselves)
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // receive every 5 m minimum
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition);
  }

  void setBatteryLevel(int level) => _batteryLevel = level;

  void stop() {
    _running = false;
    _positionSub?.cancel();
    _accelSub?.cancel();
  }

  void dispose() {
    stop();
    _activityController.close();
    _positionController.close();
  }

  // ---------------------------------------------------------------
  void _onAccel(AccelerometerEvent e) {
    _accelMagnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  }

  void _onPosition(Position pos) {
    _positionController.add(pos);

    final speedMs = pos.speed < 0 ? 0.0 : pos.speed;
    final newActivity = _classifyActivity(speedMs);

    if (newActivity != _currentActivity) {
      _currentActivity = newActivity;
      _activityController.add(newActivity);
    }

    if (_shouldSend(pos)) {
      _lastSentPosition = pos;
      _lastSentTime     = DateTime.now();
      _sendUpdate(pos, speedMs, newActivity);
    }
  }

  ActivityType _classifyActivity(double speedMs) {
    // Primarily GPS speed, secondarily accelerometer
    if (speedMs >= AppConstants.drivingSpeedThresholdMs) return ActivityType.driving;
    if (speedMs >= AppConstants.walkingSpeedThresholdMs) return ActivityType.walking;
    // Low speed but high accel = walking
    if (_accelMagnitude > AppConstants.drivingAccelThreshold) return ActivityType.walking;
    return ActivityType.still;
  }

  bool _shouldSend(Position pos) {
    final now = DateTime.now();
    final intervalMs = _intervalForActivity(_currentActivity);
    final minDistM   = _distanceForActivity(_currentActivity);

    final timeOk = _lastSentTime == null ||
        now.difference(_lastSentTime!).inMilliseconds >= intervalMs;

    final distOk = _lastSentPosition == null ||
        Geolocator.distanceBetween(
          _lastSentPosition!.latitude, _lastSentPosition!.longitude,
          pos.latitude, pos.longitude,
        ) >= minDistM;

    return timeOk && distOk;
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
        'batteryLevel':   _batteryLevel,
        'isAirplaneMode': false,
      });
    } catch (e) {
      debugPrint('Location send error: $e');
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
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
