import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common/gradient_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _nameCtrl   = TextEditingController();
  bool _obscure     = true;
  File? _avatar;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (xf != null) setState(() => _avatar = File(xf.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
      email:      _emailCtrl.text.trim(),
      password:   _passCtrl.text,
      username:   _nameCtrl.text.trim(),
      avatarPath: _avatar?.path,
    );
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.isAuthenticated) context.go('/onboarding');
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
                const Gap(20),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => context.go('/login'),
                ),
                const Gap(12),
                const Text('Crea account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const Gap(6),
                Text('Inizia a condividere la tua posizione', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                const Gap(32),

                // Avatar picker
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.cardDark,
                          backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                          child: _avatar == null
                            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.camera_alt_outlined, color: AppTheme.primary, size: 28),
                                const Gap(4),
                                Text('Foto', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                              ])
                            : null,
                        ),
                        if (_avatar != null)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Center(child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('(opzionale)', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                )),
                const Gap(28),

                _label('Nome utente'),
                const Gap(8),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Come ti chiami?',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) >= 2 ? null : 'Minimo 2 caratteri',
                ),
                const Gap(16),

                _label('Email'),
                const Gap(8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'nome@email.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
                  ),
                  validator: (v) => (v?.contains('@') ?? false) ? null : 'Email non valida',
                ),
                const Gap(16),

                _label('Password'),
                const Gap(8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Minimo 8 car., maiuscola, numero, simbolo',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Minimo 8 caratteri';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Serve almeno una maiuscola';
                    if (!RegExp(r'\d').hasMatch(v)) return 'Serve almeno un numero';
                    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Serve almeno un simbolo';
                    return null;
                  },
                ),
                const Gap(12),

                if (auth.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                    ),
                    child: Text(auth.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                  ),

                const Gap(32),
                GradientButton(label: 'Registrati', loading: auth.loading, onTap: _submit),
                const Gap(24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Hai già un account? ', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text('Accedi', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
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

  Widget _label(String t) => Text(t, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13));
}
