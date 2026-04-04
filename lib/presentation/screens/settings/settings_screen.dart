import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/avatar_utils.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Generali'), Tab(text: 'Cerchia')],
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.white38,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _GeneralSettings(),
          _CircleSettings(),
        ],
      ),
    );
  }
}

// ── Impostazioni generali ───────────────────────────────────
class _GeneralSettings extends ConsumerStatefulWidget {
  const _GeneralSettings();
  @override
  ConsumerState<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends ConsumerState<_GeneralSettings> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xf == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(xf.path, filename: 'avatar.jpg'),
      });
      final dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final token = await const flutter_secure_storage.FlutterSecureStorage()
          .read(key: AppConstants.storageKeyToken);
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      final r = await dio.post('/api/auth/account/avatar', data: formData);
      final avatarUrl = r.data['avatarUrl'] as String?;

      if (avatarUrl != null && mounted) {
        // Svuota la cache della vecchia immagine così CachedNetworkImage
        // non mostra quella precedente al prossimo rebuild.
        final oldUrl = resolveAvatarUrl(ref.read(authProvider).user?.avatarUrl);
        if (oldUrl != null) {
          await CachedNetworkImage.evictFromCache(oldUrl);
        }

        // Aggiorna il provider con il nuovo avatarUrl.
        ref.read(authProvider.notifier).updateAvatarUrl(avatarUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profilo aggiornata!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Card account con avatar modificabile ────────────
        _SectionHeader('Account'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              // Avatar grande cliccabile
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _changeAvatar,
                      child: Stack(
                        children: [
                          _uploadingAvatar
                              ? Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.2),
                            ),
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          )
                              : _AvatarWidget(
                            avatarUrl: user?.avatarUrl,
                            username: user?.username ?? '',
                            size: 72,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    // Info utente
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.username ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17),
                          ),
                          const Gap(3),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                          const Gap(8),
                          GestureDetector(
                            onTap: () =>
                                _showEditUsername(context, ref, user?.username ?? ''),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Modifica nome',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Tocca foto per cambiarla
              ListTile(
                dense: true,
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primary, size: 20),
                title: const Text('Cambia foto profilo',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text('Tocca la foto sopra o qui',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24),
                onTap: _uploadingAvatar ? null : _changeAvatar,
              ),
            ],
          ),
        ),
        const Gap(16),

        // ── Autorizzazioni ─────────────────────────────────
        _SectionHeader('Autorizzazioni'),
        _SettingCard(children: [
          _PermissionTile(
            icon: Icons.location_on_rounded,
            title: 'Posizione',
            subtitle: 'Condivisione posizione in tempo reale',
            onToggle: (v) async {
              if (!v) await _showDisableWarning(context);
            },
          ),
        ]),
        const Gap(16),

        // ── Sessione ───────────────────────────────────────
        _SectionHeader('Sessione'),
        _SettingCard(children: [
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
            title: const Text('Esci',
                style: TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w600)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ]),
      ],
    );
  }

  void _showEditUsername(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Modifica nome utente'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nome utente'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.length < 2) return;
              await ApiService().updateAccount(username: name);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nome aggiornato!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisableWarning(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Disabilita posizione?'),
        content: const Text(
            'Gli altri membri della cerchia non potranno vedere la tua posizione.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Esci dall\'account?'),
        content: const Text(
            'Sarai disconnesso dal tuo account su questo dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Esci',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Widget avatar riutilizzabile ─────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double size;

  const _AvatarWidget({
    required this.avatarUrl,
    required this.username,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    // BUG FIX: usa resolveAvatarUrl() da avatar_utils.dart in modo uniforme,
    // eliminando la logica duplicata e inline che era presente prima.
    final url = resolveAvatarUrl(avatarUrl);
    if (url != null) {
      return ClipOval(
        child: CachedNetworkImage(
          key: ValueKey(url), // forza rebuild quando l'URL cambia
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initials(),
          errorWidget: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppTheme.primary.withOpacity(0.25),
    ),
    alignment: Alignment.center,
    child: Text(
      username.isNotEmpty ? username[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.38,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ── Impostazioni cerchia ─────────────────────────────────────
class _CircleSettings extends ConsumerStatefulWidget {
  const _CircleSettings();
  @override
  ConsumerState<_CircleSettings> createState() => _CircleSettingsState();
}

class _CircleSettingsState extends ConsumerState<_CircleSettings> {
  bool _driving = true;
  bool _flight  = true;
  bool _places  = true;

  @override
  Widget build(BuildContext context) {
    final circles    = ref.watch(circlesProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCircleProvider);
    if (circles.isEmpty) {
      return const Center(
          child: Text('Nessuna cerchia', style: TextStyle(color: Colors.white38)));
    }
    final circle = circles.firstWhere(
          (c) => c.id == selectedId,
      orElse: () => circles.first,
    );
    final membersAsync = ref.watch(membersProvider);
    final currentUser  = ref.watch(authProvider).user;
    final members      = membersAsync.valueOrNull ?? [];
    final isAdmin      = circle.adminId == currentUser?.id;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Codice invito
        _SectionHeader('Cerchia: ${circle.name}'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.vpn_key_rounded, color: AppTheme.primary, size: 20),
            const Gap(12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Codice invito',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              SelectableText(
                circle.inviteCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: 4,
                  color: AppTheme.primary,
                ),
              ),
            ]),
          ]),
        ),
        const Gap(16),

        _SectionHeader('Funzionalità'),
        _SettingCard(children: [
          SwitchListTile(
            secondary: const Icon(Icons.directions_car_rounded,
                color: AppTheme.accent),
            title: const Text('Rilevamento guida'),
            subtitle: const Text('Rileva quando sei alla guida',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _driving,
            onChanged: (v) {
              setState(() => _driving = v);
              ApiService().updateCircleSettings(
                  circle.id, {'drivingDetection': v});
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.airplanemode_active_rounded,
                color: Colors.blue),
            title: const Text('Rilevamento volo'),
            subtitle: const Text('Notifica quando atterra',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _flight,
            onChanged: (v) {
              setState(() => _flight = v);
              ApiService().updateCircleSettings(
                  circle.id, {'flightDetection': v});
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary:
            const Icon(Icons.notifications_rounded, color: AppTheme.warning),
            title: const Text('Notifiche posizioni'),
            subtitle: const Text('Avvisa per arrivi/partenze',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _places,
            onChanged: (v) {
              setState(() => _places = v);
              ApiService().updateCircleSettings(
                  circle.id, {'placeNotifications': v});
            },
          ),
        ]),
        const Gap(16),

        _SectionHeader('Gestisci cerchia'),
        _SettingCard(children: [
          ...members.map((m) => ListTile(
            leading: _AvatarWidget(
                avatarUrl: m.avatarUrl, username: m.username, size: 40),
            title: Text(m.username,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              m.isAdmin ? 'Amministratore' : 'Membro',
              style: TextStyle(
                  color: m.isAdmin ? AppTheme.warning : Colors.white38,
                  fontSize: 12),
            ),
            trailing: (isAdmin && !m.isAdmin && m.id != currentUser?.id)
                ? IconButton(
              icon: const Icon(Icons.person_remove_rounded,
                  color: AppTheme.danger, size: 20),
              onPressed: () => _removeConfirm(
                  context, ref, circle.id, m.id, m.username),
            )
                : null,
          )),
          ListTile(
            leading: const Icon(Icons.person_add_rounded, color: AppTheme.primary),
            title: const Text('Invita qualcuno'),
            subtitle: const Text('Condividi il codice invito'),
            onTap: () => _shareCode(context, circle.inviteCode),
          ),
        ]),
      ],
    );
  }

  void _shareCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Codice invito'),
        content: SelectableText(
          code,
          style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: AppTheme.primary),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'))
        ],
      ),
    );
  }

  void _removeConfirm(BuildContext context, WidgetRef ref, String circleId,
      String userId, String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Rimuovi membro'),
        content: Text('Vuoi rimuovere $username dalla cerchia?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ApiService().removeMember(circleId, userId);
              await ref.read(membersProvider.notifier).loadForCircle(circleId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Rimuovi',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
            letterSpacing: 1.2)),
  );
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.cardDark,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(children: children),
  );
}

class _PermissionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(bool) onToggle;
  const _PermissionTile(
      {required this.icon,
        required this.title,
        required this.subtitle,
        required this.onToggle});
  @override
  State<_PermissionTile> createState() => _PermissionTileState();
}

class _PermissionTileState extends State<_PermissionTile> {
  bool _enabled = true;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(widget.icon, color: AppTheme.primary),
    title: Text(widget.title),
    subtitle: Text(widget.subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 12)),
    value: _enabled,
    onChanged: (v) {
      setState(() => _enabled = v);
      widget.onToggle(v);
    },
  );
}