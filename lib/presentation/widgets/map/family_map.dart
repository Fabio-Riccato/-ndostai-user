import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'member_marker.dart';

class FamilyMap extends ConsumerStatefulWidget {
  const FamilyMap({super.key});
  @override
  ConsumerState<FamilyMap> createState() => _FamilyMapState();
}

class _FamilyMapState extends ConsumerState<FamilyMap> {
  final _mapController = MapController();
  String? _focusedUserId;
  bool _centeredOnce = false; // centra automaticamente solo la prima volta

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Centra la mappa sul primo membro con posizione nota (di solito l'utente corrente)
  void _autoCenterIfNeeded(List<CircleMemberModel> members, String? currentUserId) {
    if (_centeredOnce) return;
    // Prima cerca l'utente corrente, poi qualsiasi membro con posizione
    final target = members.firstWhere(
          (m) => m.id == currentUserId && m.latitude != null,
      orElse: () => members.firstWhere(
            (m) => m.latitude != null,
        orElse: () => members.isEmpty ? throw Exception() : members.first,
      ),
    );
    if (target.latitude == null || target.longitude == null) return;
    _centeredOnce = true;
    // Usa addPostFrameCallback per evitare di chiamare move durante il build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(
          LatLng(target.latitude!, target.longitude!),
          AppConstants.mapDefaultZoom,
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final places       = ref.watch(placesProvider).valueOrNull ?? [];
    final currentUser  = ref.watch(authProvider).user;

    // Tenta auto-center ogni volta che i dati arrivano
    membersAsync.whenData((members) => _autoCenterIfNeeded(members, currentUser?.id));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(45.4654, 9.1866), // Milano come default italiano
        initialZoom: AppConstants.mapDefaultZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // ── Tile layer OpenStreetMap (gratuito) ──────────────────
        // NOTA: in flutter_map v7 il tileBuilder NON accetta TileImage;
        // usiamo il ColorFiltered direttamente con tileBuilder corretto.
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.familytrack.app',
          // Effetto dark map: inverti colori + riaggiusta tonalità
          tileBuilder: (context, tileWidget, tile) => ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -0.8, 0,    0,    0, 255,
              0,  -0.8,  0,    0, 255,
              0,   0,   -0.8,  0, 255,
              0,   0,    0,    1,   0,
            ]),
            child: tileWidget,
          ),
        ),

        // ── Cerchi geofence dei luoghi ───────────────────────────
        if (places.isNotEmpty)
          CircleLayer(
            circles: places.map((p) => CircleMarker(
              point: LatLng(p.latitude, p.longitude),
              radius: p.radiusM,
              useRadiusInMeter: true,
              color: AppTheme.primary.withOpacity(0.12),
              borderColor: AppTheme.primary.withOpacity(0.5),
              borderStrokeWidth: 1.5,
            )).toList(),
          ),

        // ── Label dei luoghi ─────────────────────────────────────
        if (places.isNotEmpty)
          MarkerLayer(
            markers: places.map((p) => Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 130, height: 34,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p.isHome ? Icons.home_rounded : Icons.place_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(child: Text(p.name,
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
                ]),
              ),
            )).toList(),
          ),

        // ── Marker membri ────────────────────────────────────────
        membersAsync.when(
          loading: () => const MarkerLayer(markers: []),
          error:   (_, __) => const MarkerLayer(markers: []),
          data: (members) {
            final withPos = members
                .where((m) => m.latitude != null && m.longitude != null)
                .toList();

            return MarkerLayer(
              markers: withPos.map((m) {
                final isExpanded = _focusedUserId == m.id;
                return Marker(
                  point: LatLng(m.latitude!, m.longitude!),
                  width:  isExpanded ? 210 : 72,
                  height: isExpanded ? 110 : 80,
                  // Allineamento: la punta del marker è in basso al centro
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _focusedUserId = isExpanded ? null : m.id;
                      });
                      _mapController.move(
                        LatLng(m.latitude!, m.longitude!),
                        AppConstants.mapMemberZoom,
                      );
                    },
                    child: MemberMarker(
                      member: m,
                      isSelf: m.id == currentUser?.id,
                      expanded: isExpanded,
                      places: places,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
