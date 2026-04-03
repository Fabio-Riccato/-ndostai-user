import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class MemberMarker extends StatelessWidget {
  final CircleMemberModel member;
  final bool isSelf;
  final bool expanded;
  final List<PlaceModel> places;

  const MemberMarker({
    super.key,
    required this.member,
    required this.isSelf,
    required this.expanded,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status icon above avatar
        _StatusIcon(activity: member.activityStatus, isAirplane: member.isAirplaneMode),
        const Gap(2),

        // Avatar circle
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelf ? AppTheme.accent
                : member.isOnline ? AppTheme.primary : Colors.grey,
              width: 3,
            ),
            boxShadow: [BoxShadow(
              color: (isSelf ? AppTheme.accent : AppTheme.primary).withOpacity(0.4),
              blurRadius: 10, spreadRadius: 1,
            )],
          ),
          child: ClipOval(
            child: ColorFiltered(
              colorFilter: member.isOnline
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : const ColorFilter.matrix([
                    0.33, 0.33, 0.33, 0, 0,
                    0.33, 0.33, 0.33, 0, 0,
                    0.33, 0.33, 0.33, 0, 0,
                    0,    0,    0,    1, 0,
                  ]),
              child: _avatarChild(),
            ),
          ),
        ),

        // Expanded info bubble
        if (expanded) ...[
          const Gap(4),
          _InfoBubble(member: member, places: places),
        ],
      ],
    );
  }

  Widget _avatarChild() {
    if (member.avatarUrl != null && member.avatarUrl!.isNotEmpty) {
      final url = member.avatarUrl!.startsWith('http')
          ? member.avatarUrl!
          : '${AppConstants.baseUrl}${member.avatarUrl}';
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialsBg(),
        errorWidget: (_, __, ___) => _initialsBg(),
      );
    }
    return _initialsBg();
  }

  Widget _initialsBg() => Container(
    color: AppTheme.primary.withOpacity(0.3),
    alignment: Alignment.center,
    child: Text(
      member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
    ),
  );
}

// ── Status icon above marker ────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final String activity;
  final bool isAirplane;
  const _StatusIcon({required this.activity, required this.isAirplane});

  @override
  Widget build(BuildContext context) {
    if (isAirplane) return _chip(Icons.airplanemode_active_rounded, Colors.blue);
    switch (activity) {
      case 'driving': return _chip(Icons.directions_car_filled_rounded, AppTheme.accent);
      case 'walking': return _chip(Icons.directions_walk_rounded, AppTheme.success);
      case 'still':   return _chip(Icons.home_rounded, AppTheme.warning);
      default:        return const SizedBox.shrink();
    }
  }

  Widget _chip(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.9),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
    ),
    child: Icon(icon, size: 14, color: Colors.white),
  );
}

// ── Expanded info bubble ────────────────────────────────────
class _InfoBubble extends StatelessWidget {
  final CircleMemberModel member;
  final List<PlaceModel> places;
  const _InfoBubble({required this.member, required this.places});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)),
          const Gap(3),
          _detail(),
        ],
      ),
    );
  }

  Widget _detail() {
    if (!member.isOnline) {
      final ago = member.lastSeen != null ? _elapsed(member.lastSeen!) : 'sconosciuto';
      return Text('offline da $ago', style: const TextStyle(color: Colors.grey, fontSize: 11));
    }
    switch (member.activityStatus) {
      case 'driving':
        final kmh = (member.speed * 3.6).round();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.speed_rounded, size: 12, color: AppTheme.accent),
          const Gap(4),
          Text('$kmh km/h', style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
        ]);
      case 'still':
        final elapsed = member.locationUpdatedAt != null ? _elapsed(member.locationUpdatedAt!) : '';
        return Text('fermo${elapsed.isNotEmpty ? " da $elapsed" : ""}', style: const TextStyle(color: Colors.white60, fontSize: 11));
      default:
        return const SizedBox.shrink();
    }
  }

  String _elapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${diff.inMinutes}min';
  }
}
