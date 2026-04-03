// gradient_button.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: disabled
            ? const LinearGradient(colors: [Color(0xFF3A3A5C), Color(0xFF3A3A5C)])
            : const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled ? [] : [
            BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: TextStyle(
                color: disabled ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.w700, fontSize: 16,
              )),
        ),
      ),
    );
  }
}
