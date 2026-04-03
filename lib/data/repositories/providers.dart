import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/ws_service.dart';
import '../../core/constants/app_constants.dart';

// ---- Selected Circle ----
class CircleSelectionNotifier extends StateNotifier<String?> {
  CircleSelectionNotifier() : super(null) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(AppConstants.storageKeyLastCircle);
  }

  Future<void> select(String? id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) await prefs.setString(AppConstants.storageKeyLastCircle, id);
    else await prefs.remove(AppConstants.storageKeyLastCircle);
  }
}

final selectedCircleProvider = StateNotifierProvider<CircleSelectionNotifier, String?>(
  (_) => CircleSelectionNotifier(),
);

// ---- Circles list ----
class CirclesNotifier extends StateNotifier<AsyncValue<List<CircleModel>>> {
  CirclesNotifier() : super(const AsyncValue.loading());
  final _api = ApiService();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final r = await _api.getUserCircles();
      final circles = (r['circles'] as List)
          .map((j) => CircleModel.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(circles);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<CircleModel> create(String name) async {
    final r = await _api.createCircle(name);
    final circle = CircleModel.fromJson(r['circle'] as Map<String, dynamic>);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, circle]);
    return circle;
  }

  Future<CircleModel> join(String code) async {
    final r = await _api.joinCircle(code);
    final circle = CircleModel.fromJson(r['circle'] as Map<String, dynamic>);
    final current = state.valueOrNull ?? [];
    if (!current.any((c) => c.id == circle.id)) {
      state = AsyncValue.data([...current, circle]);
    }
    return circle;
  }
}

final circlesProvider = StateNotifierProvider<CirclesNotifier, AsyncValue<List<CircleModel>>>(
  (_) => CirclesNotifier(),
);

// ---- Members for selected circle (real-time) ----
class MembersNotifier extends StateNotifier<AsyncValue<List<CircleMemberModel>>> {
  MembersNotifier() : super(const AsyncValue.loading()) {
    WsService().addHandler(_onWsMessage);
  }

  final _api = ApiService();
  String? _circleId;

  Future<void> loadForCircle(String circleId) async {
    _circleId = circleId;
    state = const AsyncValue.loading();
    try {
      final r = await _api.getCircleMembers(circleId);
      final members = (r['members'] as List)
          .map((j) => CircleMemberModel.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(members);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  void _onWsMessage(String type, Map<String, dynamic> data) {
    if (type == 'location_update') {
      final userId = data['userId'] as String?;
      if (userId == null) return;
      final members = state.valueOrNull;
      if (members == null) return;

      final idx = members.indexWhere((m) => m.id == userId);
      if (idx == -1) return;

      final updated = members[idx].copyWith(
        latitude:       (data['latitude']  as num?)?.toDouble(),
        longitude:      (data['longitude'] as num?)?.toDouble(),
        speed:          (data['speed']     as num?)?.toDouble(),
        activityStatus: data['activityStatus'] as String?,
        batteryLevel:   (data['batteryLevel'] as num?)?.toInt(),
        isOnline:       true,
        locationUpdatedAt: DateTime.now(),
      );
      final newList = List<CircleMemberModel>.from(members);
      newList[idx] = updated as CircleMemberModel;
      state = AsyncValue.data(newList);
    } else if (type == 'user_offline') {
      final userId = data['userId'] as String?;
      if (userId == null) return;
      final members = state.valueOrNull;
      if (members == null) return;
      final idx = members.indexWhere((m) => m.id == userId);
      if (idx == -1) return;
      final updated = members[idx].copyWith(isOnline: false, lastSeen: DateTime.now());
      final newList = List<CircleMemberModel>.from(members);
      newList[idx] = updated as CircleMemberModel;
      state = AsyncValue.data(newList);
    }
  }

  @override
  void dispose() {
    WsService().removeHandler(_onWsMessage);
    super.dispose();
  }
}

final membersProvider = StateNotifierProvider<MembersNotifier, AsyncValue<List<CircleMemberModel>>>(
  (_) => MembersNotifier(),
);

// ---- Places ----
class PlacesNotifier extends StateNotifier<AsyncValue<List<PlaceModel>>> {
  PlacesNotifier() : super(const AsyncValue.data([]));
  final _api = ApiService();

  Future<void> loadForCircle(String circleId) async {
    state = const AsyncValue.loading();
    try {
      final r = await _api.getPlaces(circleId);
      final places = (r['places'] as List)
          .map((j) => PlaceModel.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(places);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> add(Map<String, dynamic> data) async {
    final r = await _api.createPlace(data);
    final place = PlaceModel.fromJson(r['place'] as Map<String, dynamic>);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, place]);
  }

  Future<void> remove(String placeId) async {
    await _api.deletePlace(placeId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((p) => p.id != placeId).toList());
  }
}

final placesProvider = StateNotifierProvider<PlacesNotifier, AsyncValue<List<PlaceModel>>>(
  (_) => PlacesNotifier(),
);

// ---- Driving Reports ----
final drivingReportsProvider = FutureProvider.family<List<DrivingReportModel>, String>((ref, circleId) async {
  final r = await ApiService().getDrivingReports(circleId);
  return (r['reports'] as List)
      .map((j) => DrivingReportModel.fromJson(j as Map<String, dynamic>))
      .toList();
});

// ---- Trip History ----
final tripHistoryProvider = FutureProvider.family<List<TripModel>, ({String userId, String circleId})>((ref, args) async {
  final r = await ApiService().getLocationHistory(args.userId, args.circleId);
  return (r['trips'] as List)
      .map((j) => TripModel.fromJson(j as Map<String, dynamic>))
      .toList();
});
