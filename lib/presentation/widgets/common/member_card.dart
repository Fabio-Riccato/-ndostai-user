import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_utils.dart';

class MemberCard extends ConsumerWidget {
  final CircleMemberModel member;
  final String circleId;
  final bool isSelf;

  const MemberCard({
    super.key,
    required this.member,
    required this.circleId,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesProvider).valueOrNull ?? [];

    return InkWell(
      onTap: () => context.push('/trips/${member.id}?circleId=$circleId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _Avatar(member: member),
                  Positioned(bottom: -6, child: _BatteryBadge(level: member.batteryLevel)),
                ],
              ),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          isSelf ? '${member.username} (tu)' : member.username,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (member.isAdmin) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('admin',
                              style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const Gap(3),
                  _LocationText(member: member, places: places),
                ],
              ),
            ),
            const Gap(8),
            _ActivityIcon(activity: member.activityStatus, isOnline: member.isOnline),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ──────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final CircleMemberModel member;
  const _Avatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(member.avatarUrl);
    final Widget img = url != null
        ? CachedNetworkImage(
      imageUrl: url, fit: BoxFit.cover,
      placeholder: (_, __) => _initials(),
      errorWidget: (_, __, ___) => _initials(),
    )
        : _initials();

    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: member.isOnline ? AppTheme.primary : Colors.grey.shade700,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: member.isOnline
            ? img
            : ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0,
            0.33, 0.33, 0.33, 0, 0,
            0.33, 0.33, 0.33, 0, 0,
            0,    0,    0,    1, 0,
          ]),
          child: img,
        ),
      ),
    );
  }

  Widget _initials() => Container(
    color: AppTheme.primary.withOpacity(0.25),
    alignment: Alignment.center,
    child: Text(
      member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
    ),
  );
}

// ── Battery badge ───────────────────────────────────────────
class _BatteryBadge extends StatelessWidget {
  final int level;
  const _BatteryBadge({required this.level});

  Color get _color {
    if (level < AppConstants.batteryLow) return AppTheme.batteryLow;
    if (level < AppConstants.batteryMedium) return AppTheme.batteryMed;
    return AppTheme.batteryHigh;
  }

  IconData get _icon {
    if (level < AppConstants.batteryLow) return Icons.battery_alert_rounded;
    if (level < AppConstants.batteryMedium) return Icons.battery_3_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.surfaceDark,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.cardDark, width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 10, color: _color),
      const Gap(2),
      Text('$level%',
          style: TextStyle(fontSize: 9, color: _color, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Location text ───────────────────────────────────────────
class _LocationText extends StatelessWidget {
  final CircleMemberModel member;
  final List<PlaceModel> places;
  const _LocationText({required this.member, required this.places});

  @override
  Widget build(BuildContext context) {
    if (!member.isOnline && member.lastSeen != null) {
      return Text(
        'offline da ${_elapsed(member.lastSeen!)}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      _buildLabel(),
      style: const TextStyle(color: Colors.white54, fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _buildLabel() {
    final nearbyPlace = _findNearbyPlace();

    switch (member.activityStatus) {

    // ── FERMO ──────────────────────────────────────────────
      case 'still':
      // Usa stoppedAt (quando si è fermato davvero) oppure locationUpdatedAt
        final sinceTs = member.stoppedAt ?? member.locationUpdatedAt;
        if (nearbyPlace != null) {
          return 'Presso ${nearbyPlace.name}${_sinceStr(sinceTs)}';
        }
        return 'Fermo${_sinceStr(sinceTs)}';

    // ── CAMMINANDO ─────────────────────────────────────────
      case 'walking':
        if (nearbyPlace != null) {
          return 'A piedi vicino a ${nearbyPlace.name}${_sinceStr(member.locationUpdatedAt)}';
        }
        return 'Camminando${_sinceStr(member.locationUpdatedAt)}';

    // ── IN MACCHINA ────────────────────────────────────────
      case 'driving':
        final kmh = (member.speed * 3.6).round();
        return 'In macchina · $kmh km/h${_sinceStr(member.locationUpdatedAt)}';

    // ── UNKNOWN / ALTRO ───────────────────────────────────
    // "unknown" arriva quando il client non ha ancora classificato
    // l'attività o la velocità GPS è 0. Lo trattiamo come "still":
    // se c'è un luogo vicino mostriamo "Presso X", altrimenti
    // controlliamo la velocità per walking/driving, infine "Fermo".
      default:
        final sinceTs = member.stoppedAt ?? member.locationUpdatedAt;
        // Vicino a un luogo → mostra sempre "Presso"
        if (nearbyPlace != null) {
          return 'Presso ${nearbyPlace.name}${_sinceStr(sinceTs)}';
        }
        // Velocità significativa → è in movimento
        if (member.speed >= 5.0) {
          final kmh = (member.speed * 3.6).round();
          return 'In macchina · $kmh km/h${_sinceStr(member.locationUpdatedAt)}';
        }
        if (member.speed >= 0.5) {
          return 'Camminando${_sinceStr(member.locationUpdatedAt)}';
        }
        // Fermo senza luogo vicino
        return 'Fermo${_sinceStr(sinceTs)}';
    }
  }

  PlaceModel? _findNearbyPlace() {
    if (member.latitude == null || member.longitude == null) return null;
    for (final p in places) {
      if (_distM(member.latitude!, member.longitude!, p.latitude, p.longitude) <= p.radiusM) {
        return p;
      }
    }
    return null;
  }

  /// "dalle HH:MM" o "dalle HH:MM del GG/MM/AAAA" se non è oggi
  String _sinceStr(DateTime? dt) {
    if (dt == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay  = DateTime(dt.year, dt.month, dt.day);
    final t     = _timeOnly(dt);
    if (dDay == today) return ' dalle $t';
    return ' dalle $t del ${dt.day}/${dt.month}/${dt.year}';
  }

  String _timeOnly(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _elapsed(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0)  return '${d.inDays}g ${d.inHours % 24}h ${d.inMinutes % 60}min';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  static double _distM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final phi1   = lat1 * math.pi / 180;
    final phi2   = lat2 * math.pi / 180;
    final dPhi   = (lat2 - lat1) * math.pi / 180;
    final dLamba = (lon2 - lon1) * math.pi / 180;
    final a      = math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLamba / 2), 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

// ── Activity icon ───────────────────────────────────────────
class _ActivityIcon extends StatelessWidget {
  final String activity;
  final bool isOnline;
  const _ActivityIcon({required this.activity, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 22);
    switch (activity) {
      case 'driving': return const Icon(Icons.directions_car_filled_rounded, color: AppTheme.accent, size: 22);
      case 'walking': return const Icon(Icons.directions_walk_rounded, color: AppTheme.success, size: 22);
      case 'still':   return const Icon(Icons.home_rounded, color: AppTheme.warning, size: 22);
      default:        return const Icon(Icons.location_on_rounded, color: Colors.white38, size: 22);
    }
  }
}