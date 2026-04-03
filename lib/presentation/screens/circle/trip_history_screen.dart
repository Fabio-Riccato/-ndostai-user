import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gap/gap.dart';
import 'dart:convert';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/theme/app_theme.dart';

class TripHistoryScreen extends ConsumerWidget {
  final String userId;
  final String circleId;
  const TripHistoryScreen({super.key, required this.userId, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripHistoryProvider((userId: userId, circleId: circleId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronologia posizioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppTheme.danger))),
        data: (trips) {
          if (trips.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history_rounded, size: 64, color: Colors.white24),
                Gap(16),
                Text('Nessuno spostamento nell\'ultima settimana',
                  style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (_, i) => _TripCard(trip: trips[i]),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  final TripModel trip;
  const _TripCard({required this.trip});
  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final startStr = _fmt(t.startTime);
    final endStr   = _fmt(t.endTime);
    final duration = t.endTime.difference(t.startTime);
    final dStr     = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes % 60}min'
        : '${duration.inMinutes}min';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route line
                  Row(children: [
                    Column(children: [
                      const Icon(Icons.circle_outlined, size: 12, color: AppTheme.success),
                      Container(width: 2, height: 24, color: Colors.white24),
                      const Icon(Icons.flag_rounded, size: 14, color: AppTheme.danger),
                    ]),
                    const Gap(12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.startAddress, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)),
                      const Gap(12),
                      Text(t.endAddress, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ])),
                  ]),
                  const Gap(12),
                  const Divider(height: 1),
                  const Gap(10),
                  // Stats row
                  Row(children: [
                    _Stat(Icons.schedule_rounded, '$startStr → $endStr'),
                    const Spacer(),
                    _Stat(Icons.straighten_rounded, '${t.distanceKm.toStringAsFixed(1)} km'),
                    const Gap(16),
                    _Stat(Icons.speed_rounded, '${t.maxSpeedKmh.round()} km/h max'),
                    const Gap(8),
                    Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.white38, size: 20),
                  ]),
                ],
              ),
            ),
          ),

          // Expanded map
          if (_expanded && t.pathGeoJson != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: SizedBox(
                height: 200,
                child: _TripMap(trip: t),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDay = DateTime(dt.year, dt.month, dt.day);
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return dtDay == today ? t : '$t del ${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: Colors.white38),
    const Gap(4),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
  ]);
}

class _TripMap extends StatelessWidget {
  final TripModel trip;
  const _TripMap({required this.trip});

  @override
  Widget build(BuildContext context) {
    List<LatLng> points = [];
    if (trip.pathGeoJson != null) {
      try {
        final geo = jsonDecode(trip.pathGeoJson!) as Map<String, dynamic>;
        final coords = (geo['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        points = coords;
      } catch (_) {}
    }
    if (points.isEmpty) {
      points = [
        LatLng(trip.startLat, trip.startLng),
        LatLng(trip.endLat, trip.endLng),
      ];
    }

    final center = LatLng(
      (trip.startLat + trip.endLat) / 2,
      (trip.startLng + trip.endLng) / 2,
    );

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        PolylineLayer(polylines: [
          Polyline(points: points, strokeWidth: 3, color: AppTheme.primary),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: points.first, width: 20, height: 20,
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.success),
              child: const Icon(Icons.circle, size: 12, color: Colors.white),
            ),
          ),
          Marker(
            point: points.last, width: 28, height: 28,
            child: const Icon(Icons.flag_rounded, color: AppTheme.danger, size: 24),
          ),
        ]),
      ],
    );
  }
}
