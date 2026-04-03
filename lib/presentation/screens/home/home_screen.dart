import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gap/gap.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/services/api_service.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/ws_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/map/family_map.dart';
import '../../widgets/bottom_sheet/main_bottom_sheet.dart';
import '../../widgets/common/circle_dropdown.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _sheetController = DraggableScrollableController();
  int _bottomTab = 0; // 0=position, 1=driving

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Start location updates
    final hasPerms = await LocationService.requestPermissions();
    if (hasPerms) LocationService().start();

    // Connect WebSocket
    await WsService().connect();

    // Registra il token FCM per le notifiche push
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await ApiService().updateDeviceToken(fcmToken);
        debugPrint('[FCM] Token registered: $fcmToken');
      }
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }

    // Load circles & members
    await ref.read(circlesProvider.notifier).load();
    final circles = ref.read(circlesProvider).valueOrNull ?? [];
    if (circles.isEmpty && mounted) {
      context.go('/onboarding');
      return;
    }

    var selectedId = ref.read(selectedCircleProvider);
    if (selectedId == null && circles.isNotEmpty) {
      selectedId = circles.first.id;
      ref.read(selectedCircleProvider.notifier).select(selectedId);
    }

    if (selectedId != null) {
      ref.read(membersProvider.notifier).loadForCircle(selectedId);
      ref.read(placesProvider.notifier).loadForCircle(selectedId);
    }
  }

  void _onCircleChanged(String circleId) {
    ref.read(selectedCircleProvider.notifier).select(circleId);
    ref.read(membersProvider.notifier).loadForCircle(circleId);
    ref.read(placesProvider.notifier).loadForCircle(circleId);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circles  = ref.watch(circlesProvider).valueOrNull ?? [];
    final selectedId = ref.watch(selectedCircleProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Full-screen map
          const FamilyMap(),

          // Top overlay bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Settings button
                  _GlassButton(
                    icon: Icons.settings_outlined,
                    onTap: () => context.push('/settings'),
                  ),
                  const Spacer(),

                  // Circle dropdown (center)
                  if (circles.isNotEmpty)
                    CircleDropdown(
                      circles: circles,
                      selectedId: selectedId,
                      onChanged: _onCircleChanged,
                    ),

                  const Spacer(),
                  // Add circle button
                  _GlassButton(
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () => _showAddCircleSheet(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom draggable sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.22,
            minChildSize: 0.10,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.22, 0.50, 0.92],
            builder: (ctx, scrollCtrl) => MainBottomSheet(
              scrollController: scrollCtrl,
              circleId: selectedId,
              activeTab: _bottomTab,
              onTabChanged: (t) => setState(() => _bottomTab = t),
            ),
          ),
        ],
      ),

      // Bottom navigation (position / driving)
      bottomNavigationBar: _BottomNav(
        current: _bottomTab,
        onTap: (i) {
          setState(() => _bottomTab = i);
          if (i == 1 && selectedId != null) {
            context.push('/driving/$selectedId');
          }
        },
      ),
    );
  }

  void _showAddCircleSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddCircleSheet(
        onCreated: (id) => _onCircleChanged(id),
        onJoined:  (id) => _onCircleChanged(id),
      ),
    );
  }
}

// ─── Glass button ──────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

// ─── Bottom navigation ─────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: AppTheme.cardDark,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, -4))],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(icon: Icons.location_on_rounded,    label: 'Posizione', active: current == 0, onTap: () => onTap(0)),
        _NavItem(icon: Icons.directions_car_rounded, label: 'Guida',     active: current == 1, onTap: () => onTap(1)),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? AppTheme.primary : Colors.white38, size: 26),
        const Gap(3),
        Text(label, style: TextStyle(
          fontSize: 11, color: active ? AppTheme.primary : Colors.white38,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        )),
      ],
    ),
  );
}

// ─── Add/Join circle sheet ──────────────────────────────────
class _AddCircleSheet extends ConsumerStatefulWidget {
  final void Function(String) onCreated;
  final void Function(String) onJoined;
  const _AddCircleSheet({required this.onCreated, required this.onJoined});
  @override
  ConsumerState<_AddCircleSheet> createState() => _AddCircleSheetState();
}

class _AddCircleSheetState extends ConsumerState<_AddCircleSheet> {
  final _ctrl = TextEditingController();
  bool _createMode = true;
  bool _loading = false;
  String? _code;

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      if (_createMode) {
        final c = await ref.read(circlesProvider.notifier).create(_ctrl.text.trim());
        setState(() { _code = c.inviteCode; _loading = false; });
      } else {
        final c = await ref.read(circlesProvider.notifier).join(_ctrl.text.trim().toUpperCase());
        if (mounted) { Navigator.pop(context); widget.onJoined(c.id); }
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + pad),
      child: _code != null
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 44),
            const Gap(12),
            const Text('Cerchia creata!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(12)),
              child: Text(_code!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppTheme.primary)),
            ),
            const Gap(20),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); widget.onCreated(''); },
              child: const Text('Chiudi'),
            ),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _TabBtn('Crea', _createMode, () => setState(() => _createMode = true)),
              const Gap(12),
              _TabBtn('Entra', !_createMode, () => setState(() => _createMode = false)),
            ]),
            const Gap(20),
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: _createMode ? 'Nome cerchia' : 'Codice invito'),
            ),
            const Gap(16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) :
                Text(_createMode ? 'Crea' : 'Entra'),
            ),
          ]),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _TabBtn(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppTheme.primary : Colors.white24),
      ),
      child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
    ),
  );
}
