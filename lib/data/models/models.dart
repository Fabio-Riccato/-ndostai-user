class UserModel {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final int batteryLevel;
  final bool isOnline;
  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;
  final double speed;
  final String activityStatus; // still, walking, driving, flying, unknown
  final bool isAirplaneMode;
  final DateTime? locationUpdatedAt;
  final DateTime? stoppedAt;
  final String? nearbyAddress;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.batteryLevel = 100,
    this.isOnline = false,
    this.lastSeen,
    this.latitude,
    this.longitude,
    this.speed = 0,
    this.activityStatus = 'unknown',
    this.isAirplaneMode = false,
    this.locationUpdatedAt,
    this.stoppedAt,
    this.nearbyAddress,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:               j['id'] as String,
    username:         j['username'] as String,
    email:            j['email'] as String? ?? '',
    avatarUrl:        j['avatar_url'] as String? ?? j['avatarUrl'] as String?,
    batteryLevel:     (j['battery_level'] as num?)?.toInt() ?? 100,
    isOnline:         j['is_online'] as bool? ?? false,
    lastSeen:         j['last_seen'] != null ? DateTime.tryParse(j['last_seen'] as String) : null,
    latitude:         (j['latitude'] as num?)?.toDouble(),
    longitude:        (j['longitude'] as num?)?.toDouble(),
    speed:            (j['speed'] as num?)?.toDouble() ?? 0,
    activityStatus:   j['activity_status'] as String? ?? 'unknown',
    isAirplaneMode:   j['is_airplane_mode'] as bool? ?? false,
    locationUpdatedAt: j['location_updated_at'] != null ? DateTime.tryParse(j['location_updated_at'] as String) : null,
    stoppedAt:        j['stopped_at'] != null ? DateTime.tryParse(j['stopped_at'] as String) : null,
    nearbyAddress:    j['nearby_address'] as String? ?? j['nearbyAddress'] as String?,
  );

  UserModel copyWith({
    String? avatarUrl,
    double? latitude,
    double? longitude,
    double? speed,
    String? activityStatus,
    int? batteryLevel,
    bool? isOnline,
    bool? isAirplaneMode,
    DateTime? locationUpdatedAt,
    DateTime? lastSeen,
    DateTime? stoppedAt,
    Object? nearbyAddress = _keep,
  }) => UserModel(
    id:                id,
    username:          username,
    email:             email,
    avatarUrl:         avatarUrl         ?? this.avatarUrl,
    batteryLevel:      batteryLevel      ?? this.batteryLevel,
    isOnline:          isOnline          ?? this.isOnline,
    lastSeen:          lastSeen          ?? this.lastSeen,
    latitude:          latitude          ?? this.latitude,
    longitude:         longitude         ?? this.longitude,
    speed:             speed             ?? this.speed,
    activityStatus:    activityStatus    ?? this.activityStatus,
    isAirplaneMode:    isAirplaneMode    ?? this.isAirplaneMode,
    locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
    stoppedAt:         stoppedAt         ?? this.stoppedAt,
    nearbyAddress:     nearbyAddress == _keep
        ? this.nearbyAddress
        : nearbyAddress as String?,
  );
}

// Sentinel per copyWith — distingue "parametro non passato" da "null esplicito"
const Object _keep = Object();

class CircleModel {
  final String id;
  final String name;
  final String inviteCode;
  final String adminId;
  final String? adminUsername;
  final DateTime createdAt;

  const CircleModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.adminId,
    this.adminUsername,
    required this.createdAt,
  });

  factory CircleModel.fromJson(Map<String, dynamic> j) => CircleModel(
    id:            j['id'] as String,
    name:          j['name'] as String,
    inviteCode:    j['inviteCode'] as String? ?? j['invite_code'] as String? ?? '',
    adminId:       j['adminId'] as String? ?? j['admin_id'] as String? ?? '',
    adminUsername: j['adminUsername'] as String? ?? j['admin_username'] as String?,
    createdAt:     DateTime.tryParse(j['createdAt'] as String? ?? j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class PlaceModel {
  final String id;
  final String circleId;
  final String name;
  final bool isHome;
  final double latitude;
  final double longitude;
  final double radiusM;

  const PlaceModel({
    required this.id,
    required this.circleId,
    required this.name,
    this.isHome = false,
    required this.latitude,
    required this.longitude,
    this.radiusM = 150,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> j) => PlaceModel(
    id:        j['id'] as String,
    circleId:  j['circle_id'] as String? ?? j['circleId'] as String? ?? '',
    name:      j['name'] as String,
    isHome:    j['is_home'] as bool? ?? false,
    latitude:  (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radiusM:   (j['radius_m'] as num?)?.toDouble() ?? 150,
  );
}

class TripModel {
  final String id;
  final String userId;
  final double startLat;
  final double startLng;
  final String startAddress;
  final DateTime startTime;
  final double endLat;
  final double endLng;
  final String endAddress;
  final DateTime endTime;
  final double distanceM;
  final double maxSpeedMs;
  final String? pathGeoJson;

  const TripModel({
    required this.id,
    required this.userId,
    required this.startLat,
    required this.startLng,
    required this.startAddress,
    required this.startTime,
    required this.endLat,
    required this.endLng,
    required this.endAddress,
    required this.endTime,
    required this.distanceM,
    required this.maxSpeedMs,
    this.pathGeoJson,
  });

  // Getter di comodità per la UI (converte da unità SI)
  double get distanceKm => distanceM / 1000.0;
  double get maxSpeedKmh => maxSpeedMs * 3.6;

  factory TripModel.fromJson(Map<String, dynamic> j) => TripModel(
    id:           j['id'] as String,
    userId:       j['user_id'] as String? ?? j['userId'] as String? ?? '',
    startLat:     (j['start_lat'] as num).toDouble(),
    startLng:     (j['start_lng'] as num).toDouble(),
    startAddress: j['start_address'] as String? ?? '',
    startTime:    DateTime.tryParse(j['start_time'] as String? ?? '') ?? DateTime.now(),
    endLat:       (j['end_lat'] as num).toDouble(),
    endLng:       (j['end_lng'] as num).toDouble(),
    endAddress:   j['end_address'] as String? ?? '',
    endTime:      DateTime.tryParse(j['end_time'] as String? ?? '') ?? DateTime.now(),
    distanceM:    (j['distance_m'] as num?)?.toDouble() ?? 0,
    maxSpeedMs:   (j['max_speed_ms'] as num?)?.toDouble() ?? 0,
    pathGeoJson:  j['path_geojson'] as String?,
  );
}

class DrivingReportModel {
  final String userId;
  final String username;
  final String? avatarUrl;
  final String weekStart;
  final double distanceKm;
  final double maxSpeedKmh;
  final int phoneUses;

  const DrivingReportModel({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.weekStart,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.phoneUses,
  });

  factory DrivingReportModel.fromJson(Map<String, dynamic> j) => DrivingReportModel(
    userId:      j['userId'] as String? ?? j['user_id'] as String? ?? '',
    username:    j['username'] as String? ?? '',
    avatarUrl:   j['avatarUrl'] as String? ?? j['avatar_url'] as String?,
    weekStart:   j['weekStart'] as String? ?? j['week_start'] as String? ?? '',
    distanceKm:  (j['distanceKm'] as num?)?.toDouble() ?? 0,
    maxSpeedKmh: (j['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
    phoneUses:   (j['phoneUses'] as num?)?.toInt() ?? 0,
  );
}

class CircleMemberModel extends UserModel {
  final bool isAdmin;
  final bool drivingDetection;
  final bool flightDetection;
  final bool placeNotifications;

  const CircleMemberModel({
    required super.id,
    required super.username,
    required super.email,
    super.avatarUrl,
    super.batteryLevel,
    super.isOnline,
    super.lastSeen,
    super.latitude,
    super.longitude,
    super.speed,
    super.activityStatus,
    super.isAirplaneMode,
    super.locationUpdatedAt,
    super.stoppedAt,
    super.nearbyAddress,
    this.isAdmin = false,
    this.drivingDetection = true,
    this.flightDetection = true,
    this.placeNotifications = true,
  });

  factory CircleMemberModel.fromJson(Map<String, dynamic> j) => CircleMemberModel(
    id:                j['id'] as String,
    username:          j['username'] as String,
    email:             j['email'] as String? ?? '',
    avatarUrl:         j['avatar_url'] as String? ?? j['avatarUrl'] as String?,
    batteryLevel:      (j['battery_level'] as num?)?.toInt() ?? 100,
    isOnline:          j['is_online'] as bool? ?? false,
    lastSeen:          j['last_seen'] != null ? DateTime.tryParse(j['last_seen'] as String) : null,
    latitude:          (j['latitude'] as num?)?.toDouble(),
    longitude:         (j['longitude'] as num?)?.toDouble(),
    speed:             (j['speed'] as num?)?.toDouble() ?? 0,
    activityStatus:    j['activity_status'] as String? ?? 'unknown',
    isAirplaneMode:    j['is_airplane_mode'] as bool? ?? false,
    locationUpdatedAt: j['location_updated_at'] != null ? DateTime.tryParse(j['location_updated_at'] as String) : null,
    stoppedAt:         j['stopped_at'] != null ? DateTime.tryParse(j['stopped_at'] as String) : null,
    nearbyAddress:     j['nearby_address'] as String? ?? j['nearbyAddress'] as String?,
    isAdmin:           j['is_admin'] as bool? ?? false,
    drivingDetection:  j['driving_detection'] as bool? ?? true,
    flightDetection:   j['flight_detection'] as bool? ?? true,
    placeNotifications: j['place_notifications'] as bool? ?? true,
  );
}