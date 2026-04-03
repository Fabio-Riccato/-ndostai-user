import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'gradient_button.dart';

class PlacesList extends ConsumerWidget {
  final String circleId;
  const PlacesList({super.key, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placesAsync = ref.watch(placesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Luoghi salvati',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Aggiungi'),
                onPressed: () => _showAddPlace(context, ref),
              ),
            ],
          ),
          placesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Errore: $e',
                  style: const TextStyle(color: AppTheme.danger)),
            ),
            data: (places) {
              if (places.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.place_outlined, size: 48, color: Colors.white24),
                      Gap(12),
                      Text('Nessun luogo salvato',
                          style: TextStyle(color: Colors.white38)),
                      Gap(4),
                      Text('Aggiungi luoghi per ricevere notifiche',
                          style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ]),
                  ),
                );
              }
              return Column(
                children: places
                    .map((p) => _PlaceTile(place: p, circleId: circleId))
                    .toList(),
              );
            },
          ),
          const Gap(80),
        ],
      ),
    );
  }

  void _showAddPlace(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddPlaceSheet(circleId: circleId),
    );
  }
}

// ── Place tile ──────────────────────────────────────────────
class _PlaceTile extends ConsumerWidget {
  final PlaceModel place;
  final String circleId;
  const _PlaceTile({required this.place, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            place.isHome ? Icons.home_rounded : Icons.place_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        title: Text(place.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${place.latitude.toStringAsFixed(4)}, '
              '${place.longitude.toStringAsFixed(4)}  •  r=${place.radiusM.round()}m',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        trailing: IconButton(
          icon:
          const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
          onPressed: () =>
              ref.read(placesProvider.notifier).remove(place.id),
        ),
      ),
    );
  }
}

// ── Add place bottom sheet ──────────────────────────────────
class _AddPlaceSheet extends ConsumerStatefulWidget {
  final String circleId;
  const _AddPlaceSheet({required this.circleId});
  @override
  ConsumerState<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends ConsumerState<_AddPlaceSheet> {
  final _nameCtrl = TextEditingController();
  LatLng? _picked;
  LatLng _initialCenter = const LatLng(45.4654, 9.1866);
  bool _loading = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _resolveInitialCenter();
  }

  /// Usa la posizione GPS corrente come centro iniziale della mappa
  Future<void> _resolveInitialCenter() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() {
          _initialCenter = LatLng(pos.latitude, pos.longitude);
          _mapReady = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _mapReady = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _picked == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(placesProvider.notifier).add({
        'circleId': widget.circleId,
        'name': _nameCtrl.text.trim(),
        'latitude': _picked!.latitude,
        'longitude': _picked!.longitude,
        'radiusM': 150,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.82,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Aggiungi luogo',
              style:
              TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const Gap(14),
          // Nome
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Nome (es. "Casa", "Ufficio")',
              prefixIcon:
              Icon(Icons.label_outline, color: AppTheme.primary),
            ),
          ),
          const Gap(12),
          Row(children: [
            const Icon(Icons.touch_app_rounded,
                size: 16, color: Colors.white38),
            const Gap(6),
            Text(
              _picked == null
                  ? 'Tocca la mappa per selezionare il punto'
                  : 'Punto selezionato ✓  (tocca di nuovo per cambiarlo)',
              style: TextStyle(
                color: _picked == null ? Colors.white54 : AppTheme.success,
                fontSize: 12,
              ),
            ),
          ]),
          const Gap(8),

          // ── Mappa ────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _mapReady
                  ? FlutterMap(
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 14,
                  onTap: (_, latlng) =>
                      setState(() => _picked = latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.familytrack.app',
                  ),
                  if (_picked != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _picked!,
                        width: 48,
                        height: 48,
                        child: const Icon(Icons.place_rounded,
                            color: AppTheme.danger, size: 44),
                      ),
                    ]),
                ],
              )
              // Schermata di caricamento mentre otteniamo il GPS
                  : Container(
                color: AppTheme.surfaceDark,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      Gap(12),
                      Text('Caricamento mappa...',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Gap(14),
          GradientButton(
            label: _picked == null
                ? 'Seleziona prima un punto sulla mappa'
                : 'Salva luogo',
            loading: _loading,
            onTap: _picked == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
