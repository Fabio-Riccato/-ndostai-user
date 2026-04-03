import 'package:flutter/material.dart';
import '../../../data/models/models.dart';
import '../../../core/theme/app_theme.dart';

class CircleDropdown extends StatelessWidget {
  final List<CircleModel> circles;
  final String? selectedId;
  final void Function(String) onChanged;

  const CircleDropdown({
    super.key,
    required this.circles,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (circles.isEmpty) return const SizedBox.shrink();
    final selected = circles.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => circles.first,
    );

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              selected.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (circles.length > 1) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white54),
            ],
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    if (circles.length <= 1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Seleziona cerchia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          ...circles.map((c) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(c.name[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
            title: Text(c.name),
            subtitle: Text('Codice: ${c.inviteCode}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: c.id == selectedId
              ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
              : null,
            onTap: () {
              onChanged(c.id);
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
