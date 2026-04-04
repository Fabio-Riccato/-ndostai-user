import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_utils.dart';

// ─────────────────────────────────────────────────────────────
// Marker utente sulla mappa — cerchio semplice (senza punta)
// ─────────────────────────────────────────────────────────────
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

  Color get _ringColor {
    if (!member.isOnline) return Colors.grey.shade500;
    if (isSelf) return AppTheme.accent;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final nearbyPlace = _findNearbyPlace();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Info bubble (solo quando tappato)
        if (expanded) ...[
          _InfoBubble(member: member, nearbyPlace: nearbyPlace),
          const Gap(4),
        ],

        // Badge attività sopra il cerchio
        _ActivityBadge(
          activity: member.activityStatus,
          isAirplane: member.isAirplaneMode,
          speedKmh: member.activityStatus == 'driving'
              ? (member.speed * 3.6).round()
              : null,
        ),
        const Gap(3),

        // Cerchio avatar — nessuna punta
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.cardDark,
            border: Border.all(color: _ringColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: _ringColor.withOpacity(0.45),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
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
      ],
    );
  }

  PlaceModel? _findNearbyPlace() {
    if (member.latitude == null || member.longitude == null) return null;
    for (final p in places) {
      final d = _haversineM(member.latitude!, member.longitude!, p.latitude, p.longitude);
      if (d <= p.radiusM) return p;
    }
    return null;
  }

  Widget _avatarChild() {
    final url = resolveAvatarUrl(member.avatarUrl);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initials(),
        errorWidget: (_, __, ___) => _initials(),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
    color: _ringColor.withOpacity(0.2),
    alignment: Alignment.center,
    child: Text(
      member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────
// Badge attività (icona sopra il cerchio)
// ─────────────────────────────────────────────────────────────
class _ActivityBadge extends StatelessWidget {
  final String activity;
  final bool isAirplane;
  final int? speedKmh;
  const _ActivityBadge({required this.activity, required this.isAirplane, this.speedKmh});

  @override
  Widget build(BuildContext context) {
    if (isAirplane) return _pill(Icons.airplanemode_active_rounded, Colors.blue, null);
    switch (activity) {
      case 'driving':
        return _pill(Icons.directions_car_filled_rounded, AppTheme.accent,
            speedKmh != null ? '$speedKmh km/h' : null);
      case 'walking':
        return _pill(Icons.directions_walk_rounded, AppTheme.success, null);
      case 'still':
        return _pill(Icons.home_rounded, AppTheme.warning, null);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pill(IconData icon, Color color, String? label) => Container(
    padding: EdgeInsets.symmetric(horizontal: label != null ? 8 : 6, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white),
      if (label != null) ...[
        const Gap(4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// Info bubble (visibile quando si tocca il marker)
// ─────────────────────────────────────────────────────────────
class _InfoBubble extends StatelessWidget {
  final CircleMemberModel member;
  final PlaceModel? nearbyPlace;
  const _InfoBubble({required this.member, this.nearbyPlace});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.cardDark.withOpacity(0.97),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(member.username,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
        const Gap(4),
        _statusLine(),
      ],
    ),
  );

  Widget _statusLine() {
    if (!member.isOnline) {
      final ago = member.lastSeen != null ? _elapsed(member.lastSeen!) : '?';
      return _row(Icons.cloud_off_rounded, Colors.grey, 'offline da $ago');
    }

    // Fermo presso un luogo
    if (member.activityStatus == 'still' && nearbyPlace != null) {
      final since = _sinceStr(member.stoppedAt ?? member.locationUpdatedAt);
      return _row(
        nearbyPlace!.isHome ? Icons.home_rounded : Icons.place_rounded,
        AppTheme.primary,
        'Presso "${nearbyPlace!.name}"$since',
      );
    }

    // A piedi vicino a un luogo
    if (member.activityStatus == 'walking' && nearbyPlace != null) {
      final since = _sinceStr(member.locationUpdatedAt);
      return _row(Icons.directions_walk_rounded, AppTheme.success,
          'A piedi vicino a "${nearbyPlace!.name}"$since');
    }

    switch (member.activityStatus) {
      case 'driving':
        final kmh = (member.speed * 3.6).round();
        return _row(Icons.directions_car_filled_rounded, AppTheme.accent, 'In macchina · $kmh km/h');
      case 'walking':
        final since = _sinceStr(member.locationUpdatedAt);
        return _row(Icons.directions_walk_rounded, AppTheme.success, 'Camminando$since');
      case 'still':
        final since = _sinceStr(member.stoppedAt ?? member.locationUpdatedAt);
        return _row(Icons.pause_circle_outline_rounded, Colors.white54, 'Fermo$since');
      default:
        return _row(Icons.location_on_rounded, Colors.white38, 'Posizione aggiornata');
    }
  }

  Widget _row(IconData icon, Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: color),
      const Gap(5),
      Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 11, height: 1.3), softWrap: true)),
    ],
  );

  /// "dalle HH:MM" oppure "dalle HH:MM del GG/MM/AAAA" se non è oggi
  String _sinceStr(DateTime? dt) {
    if (dt == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay  = DateTime(dt.year, dt.month, dt.day);
    final t     = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dDay == today) return ' dalle $t';
    return ' dalle $t del ${dt.day}/${dt.month}/${dt.year}';
  }

  String _elapsed(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    if (d.inMinutes > 0) return '${d.inMinutes}min';
    return 'adesso';
  }
}

// ─────────────────────────────────────────────────────────────
// Pin luoghi — stile Google Maps (solo usato in family_map)
// ─────────────────────────────────────────────────────────────
class PlaceMarker extends StatelessWidget {
  final PlaceModel place;
  const PlaceMarker({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final color = place.isHome ? AppTheme.primary : AppTheme.accent;
    return CustomPaint(
      painter: _PinPainter(color: color),
      child: SizedBox(
        width: 40, height: 50,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, top: 2, left: 2, right: 2),
          child: Center(child: Icon(
            place.isHome ? Icons.home_rounded : Icons.place_rounded,
            color: Colors.white, size: 18,
          )),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final shadow = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final r = size.width / 2;
    final center = Offset(size.width / 2, r);
    canvas.drawCircle(center, r, shadow);
    canvas.drawCircle(center, r, paint);

    final path = Path()
      ..moveTo(0, r * 1.3)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, r * 1.3)
      ..close();
    canvas.drawPath(path, paint);

    canvas.drawCircle(center, r * 0.42, Paint()..color = Colors.white.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}