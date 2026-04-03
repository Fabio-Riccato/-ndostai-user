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
  bool _centeredOnce = false;

  // Dimensioni fisse del marker utente (cerchio + punta)
  // La punta è in fondo: il punto geografico deve coincidere con la punta.
  // Altezza totale = badge(22) + gap(2) + cerchio(52) + punta(10) = 86
  // La punta è all'altezza 86 dal top → anchor y = 86/2 = 43 dal centro = bottom
  static const double _markerW = 60.0;
  static const double _markerH = 86.0;
  // Offset: x=0 (centrato), y = sposta in su di metà altezza (così la punta tocca il punto)
  // In flutter_map l'alignment va da -1 (top) a +1 (bottom).
  // Vogliamo che il BOTTOM del widget sia sul punto → alignment = Alignment.bottomCenter
  // MA flutter_map ancora non lo implementa correttamente su tutti i zoom.
  // Soluzione: usiamo rotateAlignment e calcoliamo l'offset manuale via point offset.

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _autoCenterIfNeeded(List<CircleMemberModel> members, String? currentUserId) {
    if (_centeredOnce) return;
    try {
      final target = members.firstWhere(
            (m) => m.id == currentUserId && m.latitude != null,
        orElse: () => members.firstWhere(
              (m) => m.latitude != null,
          orElse: () => throw Exception('no position'),
        ),
      );
      if (target.latitude == null) return;
      _centeredOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _mapController.move(
            LatLng(target.latitude!, target.longitude!),
            AppConstants.mapDefaultZoom,
          );
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final places       = ref.watch(placesProvider).valueOrNull ?? [];
    final currentUser  = ref.watch(authProvider).user;

    membersAsync.whenData(
            (members) => _autoCenterIfNeeded(members, currentUser?.id));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(45.4654, 9.1866),
        initialZoom: AppConstants.mapDefaultZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // ── Tile layer dark ──────────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.familytrack.app',
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

        // ── Geofence circles ─────────────────────────────────
        if (places.isNotEmpty)
          CircleLayer(
            circles: places.map((p) => CircleMarker(
              point: LatLng(p.latitude, p.longitude),
              radius: p.radiusM,
              useRadiusInMeter: true,
              color: AppTheme.primary.withOpacity(0.10),
              borderColor: AppTheme.primary.withOpacity(0.45),
              borderStrokeWidth: 1.5,
            )).toList(),
          ),

        // ── Pin luoghi (Google Maps style) ───────────────────
        // alignment: Alignment(0, 1) = bottom center del widget sul punto
        if (places.isNotEmpty)
          MarkerLayer(
            markers: places.map((p) => Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 40,
              height: 50,
              // Alignment(0, 1) = ancora sul bordo inferiore centrale
              // ovvero la punta del pin tocca esattamente la coordinata
              alignment: const Alignment(0, 1),
              child: PlaceMarker(place: p),
            )).toList(),
          ),

        // ── Marker utenti ────────────────────────────────────
        membersAsync.when(
          loading: () => const MarkerLayer(markers: []),
          error: (_, __) => const MarkerLayer(markers: []),
          data: (members) {
            final withPos = members
                .where((m) => m.latitude != null && m.longitude != null)
                .toList();

            return MarkerLayer(
              markers: withPos.map((m) {
                final isExpanded = _focusedUserId == m.id;
                final markerW = isExpanded ? 210.0 : _markerW;
                final markerH = isExpanded ? 220.0 : _markerH;

                return Marker(
                  point: LatLng(m.latitude!, m.longitude!),
                  width: markerW,
                  height: markerH,
                  // Alignment(0, 1): il bottom-center del widget coincide col punto.
                  // La punta del bubble è esattamente in fondo → posizione corretta
                  // a QUALSIASI livello di zoom, perché flutter_map applica
                  // questo offset in coordinate schermo dopo la proiezione.
                  alignment: const Alignment(0, 1),
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
