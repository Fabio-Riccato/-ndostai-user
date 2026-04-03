import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

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

// ── General settings ────────────────────────────────────────
class _GeneralSettings extends ConsumerWidget {
  const _GeneralSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Account card
        _SectionHeader('Account'),
        _SettingCard(children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(
                user?.username.isNotEmpty == true ? user!.username[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(user?.username ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user?.email ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: TextButton(
              onPressed: () => _showEditAccount(context, ref, user?.username ?? ''),
              child: const Text('Modifica'),
            ),
          ),
        ]),
        const Gap(16),

        // Location permission
        _SectionHeader('Autorizzazioni'),
        _SettingCard(children: [
          _PermissionTile(
            icon: Icons.location_on_rounded,
            title: 'Posizione',
            subtitle: 'Condivisione posizione in tempo reale',
            onToggle: (v) async {
              // Open app settings if needed
              if (!v) await _showDisableWarning(context);
            },
          ),
        ]),
        const Gap(16),

        // Logout
        _SectionHeader('Sessione'),
        _SettingCard(children: [
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
            title: const Text('Esci', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ]),
      ],
    );
  }

  void _showEditAccount(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Modifica account'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Nome utente'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ApiService().updateAccount(username: ctrl.text.trim());
              if (context.mounted) Navigator.pop(context);
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
        content: const Text('Gli altri membri della cerchia non potranno più vedere la tua posizione.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: AppTheme.danger))),
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
        content: const Text('Sarai disconnesso dal tuo account su questo dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Esci', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Circle settings ─────────────────────────────────────────
class _CircleSettings extends ConsumerStatefulWidget {
  const _CircleSettings();
  @override
  ConsumerState<_CircleSettings> createState() => _CircleSettingsState();
}

class _CircleSettingsState extends ConsumerState<_CircleSettings> {
  bool _driving = true;
  bool _flight = true;
  bool _places = true;

  @override
  Widget build(BuildContext context) {
    final circles     = ref.watch(circlesProvider).valueOrNull ?? [];
    final selectedId  = ref.watch(selectedCircleProvider);
    final circle      = circles.firstWhere((c) => c.id == selectedId, orElse: () => circles.isNotEmpty ? circles.first : throw Exception());
    final membersAsync = ref.watch(membersProvider);
    final currentUser = ref.watch(authProvider).user;

    if (circles.isEmpty) {
      return const Center(child: Text('Nessuna cerchia', style: TextStyle(color: Colors.white38)));
    }

    final members = membersAsync.valueOrNull ?? [];
    final isAdmin = circle.adminId == currentUser?.id;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Circle info
        _SectionHeader('Cerchia: ${circle.name}'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.vpn_key_rounded, color: AppTheme.primary, size: 20),
            const Gap(10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Codice invito', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(circle.inviteCode, style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 4, color: AppTheme.primary)),
            ]),
          ]),
        ),
        const Gap(16),

        // Features
        _SectionHeader('Funzionalità'),
        _SettingCard(children: [
          SwitchListTile(
            secondary: const Icon(Icons.directions_car_rounded, color: AppTheme.accent),
            title: const Text('Rilevamento guida'),
            subtitle: const Text('Rileva quando sei alla guida e la velocità', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _driving,
            onChanged: (v) {
              setState(() => _driving = v);
              _updateSettings(ref, selectedId!, drivingDetection: v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.airplanemode_active_rounded, color: Colors.blue),
            title: const Text('Rilevamento volo'),
            subtitle: const Text('Notifica la cerchia quando atterra', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _flight,
            onChanged: (v) {
              setState(() => _flight = v);
              _updateSettings(ref, selectedId!, flightDetection: v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_rounded, color: AppTheme.warning),
            title: const Text('Notifiche posizioni'),
            subtitle: const Text('Avvisa quando arrivi/lasci un luogo', style: TextStyle(color: Colors.white38, fontSize: 12)),
            value: _places,
            onChanged: (v) {
              setState(() => _places = v);
              _updateSettings(ref, selectedId!, placeNotifications: v);
            },
          ),
        ]),
        const Gap(16),

        // Members management
        _SectionHeader('Gestisci cerchia'),
        _SettingCard(children: [
          ...members.map((m) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Text(m.username.isNotEmpty ? m.username[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
            title: Text(m.username, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(m.isAdmin ? 'Amministratore' : 'Membro',
              style: TextStyle(color: m.isAdmin ? AppTheme.warning : Colors.white38, fontSize: 12)),
            trailing: (isAdmin && !m.isAdmin && m.id != currentUser?.id)
              ? IconButton(
                  icon: const Icon(Icons.person_remove_rounded, color: AppTheme.danger, size: 20),
                  onPressed: () => _removeConfirm(context, ref, selectedId!, m.id, m.username),
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

  Future<void> _updateSettings(WidgetRef ref, String circleId, {bool? drivingDetection, bool? flightDetection, bool? placeNotifications}) async {
    final data = <String, dynamic>{};
    if (drivingDetection != null)   data['drivingDetection']   = drivingDetection;
    if (flightDetection != null)    data['flightDetection']    = flightDetection;
    if (placeNotifications != null) data['placeNotifications'] = placeNotifications;
    await ApiService().updateCircleSettings(circleId, data);
  }

  void _shareCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Codice invito'),
        content: Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 8, color: AppTheme.primary), textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
      ),
    );
  }

  void _removeConfirm(BuildContext context, WidgetRef ref, String circleId, String userId, String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Rimuovi membro'),
        content: Text('Vuoi rimuovere $username dalla cerchia?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ApiService().removeMember(circleId, userId);
              await ref.read(membersProvider.notifier).loadForCircle(circleId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Rimuovi', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text.toUpperCase(), style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Colors.white38, letterSpacing: 1.2,
    )),
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
  const _PermissionTile({required this.icon, required this.title, required this.subtitle, required this.onToggle});
  @override
  State<_PermissionTile> createState() => _PermissionTileState();
}

class _PermissionTileState extends State<_PermissionTile> {
  bool _enabled = true;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(widget.icon, color: AppTheme.primary),
    title: Text(widget.title),
    subtitle: Text(widget.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    value: _enabled,
    onChanged: (v) { setState(() => _enabled = v); widget.onToggle(v); },
  );
}
