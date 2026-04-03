import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

// ── Marker principale utente (stile Life360: cerchio + punta) ──
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

  Color get _borderColor {
    if (!member.isOnline) return Colors.grey.shade500;
    if (isSelf) return AppTheme.accent;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Controlla se l'utente si trova presso un luogo salvato
    final nearbyPlace = _findNearbyPlace();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Etichetta info (visibile solo quando expanded) ──────
        if (expanded)
          _InfoBubble(member: member, nearbyPlace: nearbyPlace),

        if (expanded) const Gap(4),

        // ── Badge attività sopra il marker ─────────────────────
        _ActivityBadge(
          activity: member.activityStatus,
          isAirplane: member.isAirplaneMode,
          speedKmh: member.activityStatus == 'driving'
              ? (member.speed * 3.6).round()
              : null,
        ),
        const Gap(2),

        // ── Corpo del marker: cerchio + punta triangolare ───────
        CustomPaint(
          painter: _BubblePainter(
            borderColor: _borderColor,
            fillColor: member.isOnline
                ? AppTheme.cardDark
                : const Color(0xFF444444),
            shadowColor: _borderColor.withOpacity(0.5),
          ),
          child: SizedBox(
            width: 52,
            height: 60, // 52 cerchio + 8 punta
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8), // lascia spazio alla punta
              child: ClipOval(
                child: ColorFiltered(
                  colorFilter: member.isOnline
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                      : const ColorFilter.matrix([
                    0.33, 0.33, 0.33, 0, 0,
                    0.33, 0.33, 0.33, 0, 0,
                    0.33, 0.33, 0.33, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: _avatarChild(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  PlaceModel? _findNearbyPlace() {
    if (member.latitude == null || member.longitude == null) return null;
    for (final p in places) {
      final dist = _haversineM(
          member.latitude!, member.longitude!, p.latitude, p.longitude);
      if (dist <= p.radiusM) return p;
    }
    return null;
  }

  Widget _avatarChild() {
    final url = member.avatarUrl != null && member.avatarUrl!.isNotEmpty
        ? (member.avatarUrl!.startsWith('http')
        ? member.avatarUrl!
        : '${AppConstants.baseUrl}${member.avatarUrl}')
        : null;

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
    color: _borderColor.withOpacity(0.25),
    alignment: Alignment.center,
    child: Text(
      member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
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

// ── Painter: cerchio con bordo colorato + punta in basso ────
class _BubblePainter extends CustomPainter {
  final Color borderColor;
  final Color fillColor;
  final Color shadowColor;

  const _BubblePainter({
    required this.borderColor,
    required this.fillColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width / 2) - 2; // raggio cerchio
    final center = Offset(size.width / 2, r + 2);
    const tipH = 10.0; // altezza punta

    // Shadow
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, r + 1, shadowPaint);

    // Fill cerchio
    final fillPaint = Paint()..color = fillColor;
    canvas.drawCircle(center, r, fillPaint);

    // Bordo cerchio
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, borderPaint);

    // Punta triangolare in basso al centro
    final tipPath = Path();
    final tipX = size.width / 2;
    final tipY = center.dy + r + tipH;
    tipPath.moveTo(tipX - 7, center.dy + r - 2);
    tipPath.lineTo(tipX, tipY);
    tipPath.lineTo(tipX + 7, center.dy + r - 2);
    tipPath.close();

    canvas.drawPath(tipPath, fillPaint);
    // Bordo punta
    final tipBorder = Paint()
      ..color = borderColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    // Solo i lati della punta (non la base)
    final borderTip = Path();
    borderTip.moveTo(tipX - 7, center.dy + r - 2);
    borderTip.lineTo(tipX, tipY);
    borderTip.lineTo(tipX + 7, center.dy + r - 2);
    canvas.drawPath(borderTip, tipBorder);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.borderColor != borderColor ||
          old.fillColor != fillColor;
}

// ── Badge attività (icona sopra il marker) ──────────────────
class _ActivityBadge extends StatelessWidget {
  final String activity;
  final bool isAirplane;
  final int? speedKmh;

  const _ActivityBadge({
    required this.activity,
    required this.isAirplane,
    this.speedKmh,
  });

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

  Widget _pill(IconData icon, Color color, String? label) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: label != null ? 8 : 6, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        if (label != null) ...[
          const Gap(4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]
      ]),
    );
  }
}

// ── Bubble informazioni (solo quando tappato = expanded) ────
class _InfoBubble extends StatelessWidget {
  final CircleMemberModel member;
  final PlaceModel? nearbyPlace;

  const _InfoBubble({required this.member, this.nearbyPlace});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.cardDark.withOpacity(0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.username,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
          ),
          const Gap(4),
          _statusLine(),
        ],
      ),
    );
  }

  Widget _statusLine() {
    // Offline
    if (!member.isOnline) {
      final ago = member.lastSeen != null ? _elapsed(member.lastSeen!) : '?';
      return _row(Icons.cloud_off_rounded, Colors.grey, 'offline da $ago');
    }

    // Se nei pressi di un luogo → "Presso <nome> da <ora>"
    if (nearbyPlace != null && member.locationUpdatedAt != null) {
      final since = _timeStr(member.locationUpdatedAt!);
      final label = nearbyPlace!.isHome
          ? (member.activityStatus == 'walking'
          ? 'A piedi vicino a ${nearbyPlace!.name} da $since'
          : 'Presso ${nearbyPlace!.name} da $since')
          : 'Presso "${nearbyPlace!.name}" da $since';
      return _row(
          nearbyPlace!.isHome ? Icons.home_rounded : Icons.place_rounded,
          AppTheme.primary,
          label);
    }

    switch (member.activityStatus) {
      case 'driving':
        final kmh = (member.speed * 3.6).round();
        return _row(Icons.directions_car_filled_rounded, AppTheme.accent,
            'In macchina · $kmh km/h');
      case 'walking':
        final since = member.locationUpdatedAt != null
            ? ' da ${_timeStr(member.locationUpdatedAt!)}'
            : '';
        return _row(Icons.directions_walk_rounded, AppTheme.success,
            'Camminando$since');
      case 'still':
        final dur = member.locationUpdatedAt != null
            ? ' da ${_elapsed(member.locationUpdatedAt!)}'
            : '';
        return _row(Icons.pause_circle_outline_rounded, Colors.white54,
            'Fermo$dur');
      default:
        return _row(Icons.location_on_rounded, Colors.white38,
            'Posizione aggiornata');
    }
  }

  Widget _row(IconData icon, Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: color),
      const Gap(5),
      Flexible(
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 11, height: 1.3),
          softWrap: true,
        ),
      ),
    ],
  );

  String _timeStr(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(dt.year, dt.month, dt.day);
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dDay == today) return t;
    return '$t del ${dt.day}/${dt.month}';
  }

  String _elapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'adesso';
  }
}

// ── Marker per i luoghi (pin stile Google Maps con icona) ───
class PlaceMarker extends StatelessWidget {
  final PlaceModel place;

  const PlaceMarker({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final color = place.isHome ? AppTheme.primary : AppTheme.accent;

    return CustomPaint(
      painter: _PinPainter(color: color),
      child: SizedBox(
        width: 40,
        height: 50,
        child: Padding(
          // centra l'icona nella parte circolare del pin (senza la punta)
          padding: const EdgeInsets.only(bottom: 14, top: 2, left: 2, right: 2),
          child: Center(
            child: Icon(
              place.isHome ? Icons.home_rounded : Icons.place_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painter: pin Google Maps style ─────────────────────────
class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // La parte rotonda in cima
    final circleRadius = size.width / 2;
    final circleCenter = Offset(size.width / 2, circleRadius);

    // Shadow
    canvas.drawCircle(circleCenter, circleRadius, shadowPaint);

    // Cerchio colorato
    canvas.drawCircle(circleCenter, circleRadius, paint);

    // Punta triangolare in basso
    final path = Path();
    path.moveTo(0, circleRadius * 1.3);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, circleRadius * 1.3);
    path.close();
    canvas.drawPath(path, paint);

    // Cerchietto bianco interno
    final innerPaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawCircle(circleCenter, circleRadius * 0.45, innerPaint);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}
