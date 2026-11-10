import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/strings.dart';
import '../core/i18n/tr.dart';
import '../features/cart/application/cart_controller.dart';
import 'theme/gd_colors.dart';

/// The five tabs of the design: Katalog · QR · Savat · AI · Sozlamalar, on a
/// dark bar with a gold pill behind the active icon.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = <(IconData, IconData, Tr, String)>[
    (Icons.grid_view_outlined, Icons.grid_view_rounded, Strings.tabCatalog, 'tab.catalog'),
    (Icons.qr_code_2_outlined, Icons.qr_code_2_rounded, Strings.tabQr, 'tab.qr'),
    (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, Strings.tabCart, 'tab.cart'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, Strings.tabAi, 'tab.ai'),
    (Icons.person_outline_rounded, Icons.person_rounded, Strings.tabSettings, 'tab.settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gd;
    final badge = ref.watch(cartBadgeProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: c.nav),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      icon: shell.currentIndex == i ? _tabs[i].$2 : _tabs[i].$1,
                      label: _tabs[i].$3.of(context),
                      selected: shell.currentIndex == i,
                      badge: i == 2 ? badge : 0,
                      semanticsId: _tabs[i].$4,
                      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.selected, required this.badge, required this.onTap, required this.semanticsId});
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final c = context.gd;
    final color = selected ? c.gold : c.navInkMuted;
    return Semantics(
      identifier: semanticsId,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  height: 30,
                  decoration: BoxDecoration(color: selected ? c.gold : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, size: 22, color: selected ? c.onGold : color),
                ),
                if (badge > 0)
                  Positioned(
                    right: 6,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.nav, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('$badge', style: context.gdText.caption.copyWith(color: c.ink, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(label, style: context.gdText.caption.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
