import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../data/repositories/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/gradient_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    final auth = ref.read(authProvider);

    // Se c'è un errore viene già mostrato nel build via auth.error
    if (!auth.isAuthenticated) return;

    // Login riuscito — carica le cerchie e naviga
    await ref.read(circlesProvider.notifier).load();
    if (!mounted) return;

    final circles = ref.read(circlesProvider).valueOrNull ?? [];
    if (circles.isEmpty) {
      context.go('/onboarding');
    } else {
      if (ref.read(selectedCircleProvider) == null) {
        ref.read(selectedCircleProvider.notifier).select(circles.first.id);
      }
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(60),
                // Logo
                Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20, spreadRadius: 2,
                      )],
                    ),
                    child: const Icon(Icons.location_on_rounded, size: 38, color: Colors.white),
                  ),
                ),
                const Gap(32),
                const Text('Bentornato!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                const Gap(6),
                Text('Accedi al tuo account',
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.5))),
                const Gap(40),

                // Email
                _label('Email'),
                const Gap(8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'nome@email.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                  ),
                  validator: (v) =>
                  (v?.contains('@') ?? false) ? null : 'Email non valida',
                ),
                const Gap(20),

                // Password
                _label('Password'),
                const Gap(8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white38,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                  (v?.length ?? 0) >= 1 ? null : 'Inserisci la password',
                ),
                const Gap(20),

                // Error box — mostrato solo quando c'è un errore
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: auth.error != null
                      ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.danger, size: 18),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            auth.error!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                const Gap(12),
                GradientButton(
                  label: 'Accedi',
                  loading: auth.loading,
                  onTap: auth.loading ? null : _submit,
                ),
                const Gap(24),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Non hai un account? ',
                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text('Registrati',
                        style: TextStyle(
                            color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const Gap(40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13));
}
