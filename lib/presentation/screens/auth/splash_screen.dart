import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0));
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final notifier = ref.read(authProvider.notifier);
    final loggedIn  = await notifier.tryAutoLogin();
    if (!mounted) return;
    if (loggedIn) {
      // Check if user has circles
      final circlesNotifier = ref.read(circlesProvider.notifier);
      await circlesNotifier.load();
      final circles = ref.read(circlesProvider).valueOrNull ?? [];
      if (circles.isEmpty) {
        context.go('/onboarding');
      } else {
        if (ref.read(selectedCircleProvider) == null) {
          ref.read(selectedCircleProvider.notifier).select(circles.first.id);
        }
        context.go('/home');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 30, spreadRadius: 4)],
                ),
                child: const Icon(Icons.location_on_rounded, size: 52, color: Colors.white),
              ),
            ),
            const Gap(24),
            FadeTransition(
              opacity: _fade,
              child: Column(children: [
                const Text('FamilyTrack', style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.5,
                )),
                const Gap(8),
                Text('Sempre connessi, sempre al sicuro',
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.5))),
              ]),
            ),
            const Gap(60),
            FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary.withOpacity(0.6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
