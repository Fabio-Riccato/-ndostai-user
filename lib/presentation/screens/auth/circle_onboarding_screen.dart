import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/gradient_button.dart';

class CircleOnboardingScreen extends ConsumerStatefulWidget {
  const CircleOnboardingScreen({super.key});
  @override
  ConsumerState<CircleOnboardingScreen> createState() =>
      _CircleOnboardingScreenState();
}

class _CircleOnboardingScreenState
    extends ConsumerState<CircleOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _createCtrl = TextEditingController();
  final _joinCtrl   = TextEditingController();
  bool _loading     = false;
  String? _error;
  String? _createdCode;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {
      _error = null;
      _createdCode = null;
    }));
  }

  @override
  void dispose() {
    _tab.dispose();
    _createCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_createCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final circle =
      await ref.read(circlesProvider.notifier).create(_createCtrl.text.trim());
      setState(() { _createdCode = circle.inviteCode; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Errore nella creazione. Riprova.';
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final circle = await ref.read(circlesProvider.notifier).join(code);
      ref.read(selectedCircleProvider.notifier).select(circle.id);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Codice non valido o sei già membro.';
        _loading = false;
      });
    }
  }

  void _goHome() {
    final circles = ref.read(circlesProvider).valueOrNull ?? [];
    if (circles.isNotEmpty) {
      ref.read(selectedCircleProvider.notifier).select(circles.last.id);
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Usa SingleChildScrollView per evitare overflow quando la tastiera appare
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header fisso
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.4),
                            blurRadius: 20, spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(Icons.people_alt_rounded,
                          size: 32, color: Colors.white),
                    ),
                  ),
                  const Gap(16),
                  const Text('La tua cerchia',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700)),
                  const Gap(6),
                  Text(
                    'Crea un gruppo o unisciti a uno esistente',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  ),
                  const Gap(24),

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      unselectedLabelColor: Colors.white38,
                      tabs: const [
                        Tab(text: '✨  Crea cerchia'),
                        Tab(text: '🔗  Entra'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Gap(4),

            // Contenuto tab — scrollabile per gestire tastiera
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  // ── Tab CREA ──────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                    child: _createdCode != null
                        ? _CodeDisplay(_createdCode!, onGo: _goHome)
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nome della cerchia',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const Gap(10),
                        TextField(
                          controller: _createCtrl,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _create(),
                          decoration: const InputDecoration(
                            hintText: 'es. "Famiglia Rossi"',
                            prefixIcon: Icon(Icons.group_outlined,
                                color: AppTheme.primary),
                          ),
                        ),
                        if (_error != null) ...[
                          const Gap(12),
                          _errorBox(_error!),
                        ],
                        const Gap(24),
                        GradientButton(
                          label: 'Crea cerchia',
                          loading: _loading,
                          onTap: _create,
                        ),
                      ],
                    ),
                  ),

                  // ── Tab ENTRA ─────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Codice invito',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const Gap(10),
                        TextField(
                          controller: _joinCtrl,
                          style: const TextStyle(
                              color: Colors.white,
                              letterSpacing: 4,
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _join(),
                          decoration: const InputDecoration(
                            hintText: 'XXXXXXXX',
                            hintStyle: TextStyle(
                                letterSpacing: 4,
                                fontSize: 22,
                                color: Colors.white24),
                          ),
                        ),
                        if (_error != null) ...[
                          const Gap(12),
                          _errorBox(_error!),
                        ],
                        const Gap(24),
                        GradientButton(
                          label: 'Entra nella cerchia',
                          loading: _loading,
                          onTap: _join,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.danger.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppTheme.danger, size: 16),
      const Gap(8),
      Expanded(
        child: Text(msg,
            style: const TextStyle(
                color: AppTheme.danger, fontSize: 13)),
      ),
    ]),
  );
}

// ── Schermata codice creato ─────────────────────────────────
class _CodeDisplay extends StatelessWidget {
  final String code;
  final VoidCallback onGo;
  const _CodeDisplay(this.code, {required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.2),
                AppTheme.accent.withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
          ),
          child: Column(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.success, size: 44),
            const Gap(14),
            const Text('Cerchia creata!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const Gap(6),
            Text('Condividi questo codice con chi vuoi invitare',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12),
                textAlign: TextAlign.center),
            const Gap(18),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: AppTheme.primary,
              ),
            ),
            const Gap(8),
            Text('(tieni premuto per copiare)',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ]),
        ),
        const Gap(28),
        GradientButton(label: 'Vai alla mappa  →', onTap: onGo),
      ],
    );
  }
}
