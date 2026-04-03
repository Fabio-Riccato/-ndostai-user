import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class DrivingReportScreen extends ConsumerWidget {
  final String circleId;
  const DrivingReportScreen({super.key, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(drivingReportsProvider(circleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report di guida'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppTheme.danger))),
        data: (reports) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Week header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary.withOpacity(0.2), AppTheme.accent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 24),
                const Gap(12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Report settimana corrente', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(_weekRange(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ]),
            ),
            const Gap(20),

            if (reports.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(children: [
                  Icon(Icons.directions_car_outlined, size: 64, color: Colors.white24),
                  Gap(16),
                  Text('Nessun dato di guida questa settimana', style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
                ]),
              ))
            else
              ...reports.map((r) => _ReportCard(report: r)),
          ],
        ),
      ),
    );
  }

  String _weekRange() {
    final now = DateTime.now();
    final diff = now.getDay() == 0 ? -6 : 1 - now.getDay();
    // ignore: deprecated_member_use
    final mon = now.subtract(Duration(days: (now.weekday - 1)));
    final sun = mon.add(const Duration(days: 6));
    return '${mon.day}/${mon.month} – ${sun.day}/${sun.month}/${sun.year}';
  }
}

extension on DateTime {
  int getDay() => weekday;
}

class _ReportCard extends StatelessWidget {
  final DrivingReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row
          Row(children: [
            _avatar(),
            const Gap(12),
            Text(report.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const Gap(16),
          // Stats grid
          Row(children: [
            Expanded(child: _StatBox(
              icon: Icons.straighten_rounded,
              color: AppTheme.primary,
              value: '${report.distanceKm.toStringAsFixed(1)} km',
              label: 'Percorsi',
            )),
            const Gap(10),
            Expanded(child: _StatBox(
              icon: Icons.speed_rounded,
              color: AppTheme.warning,
              value: '${report.maxSpeedKmh.round()} km/h',
              label: 'Velocità max',
            )),
            const Gap(10),
            Expanded(child: _StatBox(
              icon: Icons.smartphone_rounded,
              color: report.phoneUses > 0 ? AppTheme.danger : AppTheme.success,
              value: '${report.phoneUses}x',
              label: 'Uso telefono',
            )),
          ]),

          // Speed bar
          const Gap(16),
          _SpeedBar(maxSpeedKmh: report.maxSpeedKmh),
        ],
      ),
    );
  }

  Widget _avatar() {
    if (report.avatarUrl != null) {
      final url = report.avatarUrl!.startsWith('http')
          ? report.avatarUrl!
          : '${AppConstants.baseUrl}${report.avatarUrl}';
      return CircleAvatar(radius: 20, backgroundImage: CachedNetworkImageProvider(url));
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primary.withOpacity(0.3),
      child: Text(report.username.isNotEmpty ? report.username[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatBox({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const Gap(6),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
      const Gap(2),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
    ]),
  );
}

class _SpeedBar extends StatelessWidget {
  final double maxSpeedKmh;
  const _SpeedBar({required this.maxSpeedKmh});

  @override
  Widget build(BuildContext context) {
    final ratio = (maxSpeedKmh / 200).clamp(0.0, 1.0);
    Color barColor = AppTheme.success;
    if (maxSpeedKmh > 130) barColor = AppTheme.danger;
    else if (maxSpeedKmh > 90) barColor = AppTheme.warning;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Velocità massima', style: TextStyle(color: Colors.white54, fontSize: 12)),
        Text('${maxSpeedKmh.round()} km/h',
          style: TextStyle(color: barColor, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
      const Gap(6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(barColor),
          minHeight: 8,
        ),
      ),
    ]);
  }
}
