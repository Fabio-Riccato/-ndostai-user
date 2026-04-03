import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

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
    return InkWell(
      onTap: () => context.push('/trips/${member.id}?circleId=$circleId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar + battery sotto
            SizedBox(
              width: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _Avatar(member: member),
                  Positioned(
                    bottom: -6,
                    child: _BatteryBadge(level: member.batteryLevel),
                  ),
                ],
              ),
            ),
            const Gap(14),

            // Testo centrale — Expanded evita overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome + badge admin in un Row con Flexible
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          isSelf ? '${member.username} (tu)' : member.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (member.isAdmin) ...[
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('admin',
                              style: TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const Gap(3),
                  _LocationText(member: member),
                ],
              ),
            ),

            const Gap(8),
            // Icona attività a destra
            _ActivityIcon(
                activity: member.activityStatus, isOnline: member.isOnline),
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
    final Widget img = member.avatarUrl != null
        ? CachedNetworkImage(
      imageUrl: member.avatarUrl!.startsWith('http')
          ? member.avatarUrl!
          : '${AppConstants.baseUrl}${member.avatarUrl}',
      fit: BoxFit.cover,
      placeholder: (_, __) => _initials(),
      errorWidget: (_, __, ___) => _initials(),
    )
        : _initials();

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: member.isOnline
              ? AppTheme.primary
              : Colors.grey.shade700,
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
      member.username.isNotEmpty
          ? member.username[0].toUpperCase()
          : '?',
      style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700),
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
    padding:
    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.surfaceDark,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.cardDark, width: 1.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 10, color: _color),
      const Gap(2),
      Text('$level%',
          style: TextStyle(
              fontSize: 9,
              color: _color,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Location text ───────────────────────────────────────────
class _LocationText extends StatelessWidget {
  final CircleMemberModel member;
  const _LocationText({required this.member});

  @override
  Widget build(BuildContext context) {
    if (!member.isOnline && member.lastSeen != null) {
      return Text(
        'offline da ${_elapsed(member.lastSeen!)}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      );
    }
    final since = member.locationUpdatedAt != null
        ? ' · ${_timeStr(member.locationUpdatedAt!)}'
        : '';
    return Text(
      '${_activityLabel()}$since',
      style: const TextStyle(color: Colors.white54, fontSize: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _activityLabel() {
    switch (member.activityStatus) {
      case 'driving':
        return '🚗 In macchina · ${(member.speed * 3.6).round()} km/h';
      case 'walking':
        return '🚶 Camminando';
      case 'still':
        return '📍 Fermo';
      default:
        return '📍 Posizione aggiornata';
    }
  }

  String _timeStr(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay  = DateTime(dt.year, dt.month, dt.day);
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dDay == today) return t;
    return '$t del ${dt.day}/${dt.month}/${dt.year}';
  }

  String _elapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays}g ${diff.inHours % 24}h ${diff.inMinutes % 60}min';
    }
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${diff.inMinutes}min';
  }
}

// ── Activity icon ───────────────────────────────────────────
class _ActivityIcon extends StatelessWidget {
  final String activity;
  final bool isOnline;
  const _ActivityIcon(
      {required this.activity, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return const Icon(Icons.cloud_off_rounded,
          color: Colors.grey, size: 22);
    }
    switch (activity) {
      case 'driving':
        return const Icon(Icons.directions_car_filled_rounded,
            color: AppTheme.accent, size: 22);
      case 'walking':
        return const Icon(Icons.directions_walk_rounded,
            color: AppTheme.success, size: 22);
      case 'still':
        return const Icon(Icons.home_rounded,
            color: AppTheme.warning, size: 22);
      default:
        return const Icon(Icons.location_on_rounded,
            color: Colors.white38, size: 22);
    }
  }
}