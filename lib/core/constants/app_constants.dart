class AppConstants {
  AppConstants._();

  // ---- Server ----
  /// Change this to your server's IP/domain
  static const String baseUrl = 'http://192.168.178.27:3000';
  static const String wsUrl   = 'ws://192.168.178.27:3000/ws';

  // ---- Location update intervals ----
  /// Minimum interval between location updates sent to server (adaptive)
  static const int locationIntervalStillMs   = 60000;  // 1 min when still
  static const int locationIntervalWalkingMs = 15000;  // 15 sec walking
  static const int locationIntervalDrivingMs =  5000;  //  5 sec driving

  /// Minimum distance change (metres) to trigger an update
  static const double locationMinDistanceStillM   = 50.0;
  static const double locationMinDistanceWalkingM = 20.0;
  static const double locationMinDistanceDrivingM = 10.0;

  // ---- Activity thresholds ----
  static const double drivingSpeedThresholdMs  = 5.0;  // > 5 m/s (~18 km/h) → driving
  static const double walkingSpeedThresholdMs  = 0.5;  // > 0.5 m/s         → walking
  static const double drivingAccelThreshold    = 2.0;  // m/s² accelerometer magnitude

  // ---- Geofence ----
  static const double defaultGeofenceRadiusM = 150.0;

  // ---- History ----
  static const int historyDays = 7;

  // ---- UI ----
  static const double mapDefaultZoom    = 14.0;
  static const double mapMemberZoom     = 16.0;
  static const double bottomSheetMinH   = 0.18;
  static const double bottomSheetMidH   = 0.45;
  static const double bottomSheetMaxH   = 0.92;

  // ---- Battery thresholds ----
  static const int batteryLow    = 15;
  static const int batteryMedium = 50;

  // ---- Misc ----
  static const String appName = 'FamilyTrack';
  static const String storageKeyToken       = 'auth_token';
  static const String storageKeyLastCircle  = 'last_circle_id';
  static const String storageKeyUserId      = 'user_id';
}
