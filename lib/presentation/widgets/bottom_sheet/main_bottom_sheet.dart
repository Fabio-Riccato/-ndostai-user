import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../common/member_card.dart';
import '../common/places_list.dart';

class MainBottomSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final String? circleId;
  final int activeTab;
  final void Function(int) onTabChanged;

  const MainBottomSheet({
    super.key,
    required this.scrollController,
    required this.circleId,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final placesAsync  = ref.watch(placesProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // Drag handle
          SliverToBoxAdapter(
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Tab buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _SheetTab(
                      icon: Icons.people_alt_rounded,
                      label: 'Cerchia',
                      active: activeTab == 0,
                      onTap: () => onTabChanged(0),
                    ),
                    const Gap(12),
                    _SheetTab(
                      icon: Icons.place_rounded,
                      label: 'Luoghi',
                      active: activeTab == 1,
                      onTap: () => onTabChanged(1),
                    ),
                  ],
                ),
              ),
              const Gap(8),
              const Divider(height: 1),
            ]),
          ),

          // Content
          if (activeTab == 0)
            membersAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Errore: $e', style: const TextStyle(color: AppTheme.danger)),
                ),
              ),
              data: (members) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final m = members[i];
                    return MemberCard(
                      member: m,
                      circleId: circleId ?? '',
                      isSelf: m.id == ref.read(authProvider).user?.id,
                    );
                  },
                  childCount: members.length,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: PlacesList(circleId: circleId ?? ''),
            ),
        ],
      ),
    );
  }
}

class _SheetTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SheetTab({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.primary.withOpacity(0.5) : Colors.transparent),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: active ? AppTheme.primary : Colors.white38),
          const Gap(8),
          Text(label, style: TextStyle(
            color: active ? AppTheme.primary : Colors.white38,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          )),
        ]),
      ),
    ),
  );
}
