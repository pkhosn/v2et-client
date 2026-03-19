import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/routing_config_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hiddify/v2et/data/v2et_support_launcher.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
    this.v2etMode = false,
  });
  // managed by go router(Shell Route)
  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;
  final bool v2etMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    // focus switch management
    final primaryFocusHash = useState<int?>(null);
    final navScopeNode = useFocusScopeNode();
    useEffect(() {
      bool handler(KeyEvent event) {
        final arrows = isMobileBreakpoint ? KeyboardConst.verticalArrows : KeyboardConst.horizontalArrows;
        if (!arrows.contains(event.logicalKey)) return false;
        if (event is KeyDownEvent) {
          primaryFocusHash.value = FocusManager.instance.primaryFocus.hashCode;
        } else {
          // focus node does not change => true.
          if (primaryFocusHash.value == FocusManager.instance.primaryFocus.hashCode) {
            if (branchesScope.values.any((node) => node.hasFocus)) {
              navScopeNode.requestFocus();
            } else if (navScopeNode.hasFocus) {
              branchesScope[_scopeKeyForIndex()]?.requestFocus();
            }
          }
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () {
        HardwareKeyboard.instance.removeHandler(handler);
      };
    }, [isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex]);

    useEffect(() {
      if (!v2etMode) {
        return null;
      }
      final timer = Timer.periodic(const Duration(minutes: 10), (_) {
        ref.invalidate(v2etRuntimeConfigProvider);
      });
      return timer.cancel;
    }, [v2etMode]);

    if (v2etMode) {
      final actions = _actions(t, zh, showProfilesAction, isMobileBreakpoint, v2etMode);
      final runtimeConfig = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
      final supportUri = buildV2etSupportUri(runtimeConfig);

      useEffect(() {
        final port = runtimeConfig?.defaultPort;
        if (port == null || port <= 0 || port > 65535) {
          return null;
        }
        final current = ref.read(ConfigOptions.mixedPort);
        if (current != port) {
          ref.read(ConfigOptions.mixedPort.notifier).update(port);
        }
        return null;
      }, [runtimeConfig?.defaultPort]);

      return Material(
        color: const Color(0xFFF5F2F8),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F2F8),
          body: isMobileBreakpoint
              ? navigationShell
              : Row(
                  children: [
                    _V2etDesktopSidebar(
                      actions: actions,
                      selectedIndex: navigationShell.currentIndex,
                      onTap: (index) => _onTap(context, index),
                      onNoticeTap: () => ref.read(v2etNoticeDialogTriggerProvider.notifier).state++,
                      onSettingsTap: () => navigationShell.goBranch(3, initialLocation: true),
                    ),
                    Expanded(child: navigationShell),
                  ],
                ),
          floatingActionButton: supportUri == null
              ? null
              : FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF5A3D89),
                  foregroundColor: Colors.white,
                  onPressed: () async {
                    await launchUrl(supportUri, mode: LaunchMode.externalApplication);
                  },
                  child: const Icon(Icons.support_agent_rounded),
                ),
          bottomNavigationBar: isMobileBreakpoint
              ? _V2etBottomBar(
                  actions: actions,
                  selectedIndex: navigationShell.currentIndex,
                  onTap: (index) => _onTap(context, index),
                )
              : null,
        ),
      );
    }

    return Material(
      child: Scaffold(
        body: isMobileBreakpoint
            ? navigationShell
            : Row(
                children: [
                  FocusScope(
                    node: navScopeNode,
                    child: NavigationRail(
                      extended: Breakpoint(context).isDesktop(),
                      destinations: _navRailDests(_actions(t, zh, showProfilesAction, isMobileBreakpoint, v2etMode)),
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) => _onTap(context, index),
                      trailing: Breakpoint(context).isDesktop()
                          ? const Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(width: 220, child: SideBarStatsOverview()),
                              ),
                            )
                          : null,
                    ),
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
        bottomNavigationBar: isMobileBreakpoint
            ? FocusScope(
                node: navScopeNode,
                child: NavigationBar(
                  selectedIndex: v2etMode
                      ? navigationShell.currentIndex
                      : (navigationShell.currentIndex <= 1 ? navigationShell.currentIndex : 0),
                  destinations: _navDests(_actions(t, zh, showProfilesAction, isMobileBreakpoint, v2etMode)),
                  onDestinationSelected: (index) => _onTap(context, index),
                ),
              )
            : null,
      ),
    );
  }

  // shell route action onTap
  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  String _scopeKeyForIndex() {
    if (v2etMode) {
      return switch (navigationShell.currentIndex) {
        0 => 'home',
        1 => 'profiles',
        2 => 'about',
        _ => 'settings',
      };
    }
    return getNameOfBranch(isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex);
  }

  List<ShellRouteAction> _actions(
    Translations t,
    bool zh,
    bool showProfilesAction,
    bool isMobileBreakpoint,
    bool v2etMode,
  ) {
    if (v2etMode) {
      return [
        ShellRouteAction(Icons.dashboard_customize_rounded, zh ? '仪表盘' : 'Dashboard'),
        ShellRouteAction(Icons.shopping_bag_rounded, zh ? '商店' : 'Store'),
        ShellRouteAction(Icons.account_circle_rounded, zh ? '我的' : 'Me'),
      ];
    }
    return [
      ShellRouteAction(Icons.power_settings_new_rounded, t.pages.home.title),
      if (showProfilesAction && !isMobileBreakpoint) ShellRouteAction(Icons.view_list_rounded, t.pages.profiles.title),
      ShellRouteAction(Icons.settings_rounded, t.pages.settings.title),
      if (!isMobileBreakpoint) ShellRouteAction(Icons.description_rounded, t.pages.logs.title),
      if (!isMobileBreakpoint) ShellRouteAction(Icons.info_rounded, t.pages.about.title),
    ];
  }

  List<NavigationDestination> _navDests(List<ShellRouteAction> actions) =>
      actions.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.title)).toList();
  List<NavigationRailDestination> _navRailDests(List<ShellRouteAction> actions) =>
      actions.map((e) => NavigationRailDestination(icon: Icon(e.icon), label: Text(e.title))).toList();
}

class _V2etDesktopSidebar extends StatelessWidget {
  const _V2etDesktopSidebar({
    required this.actions,
    required this.selectedIndex,
    required this.onTap,
    required this.onNoticeTap,
    required this.onSettingsTap,
  });

  final List<ShellRouteAction> actions;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onNoticeTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      decoration: const BoxDecoration(
        color: Color(0xFFF0ECF4),
        border: Border(right: BorderSide(color: Color(0xFFE4DFEB))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFE8E2F1), borderRadius: BorderRadius.circular(10)),
            child: const Center(
              child: Text(
                'K',
                style: TextStyle(
                  color: Color(0xFF4E5DCC),
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < actions.length; i++)
            _V2etNavItem(
              icon: actions[i].icon,
              label: actions[i].title,
              selected: selectedIndex == i,
              onTap: () => onTap(i),
            ),
          const Spacer(),
          IconButton(
            onPressed: onNoticeTap,
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF6D6977), size: 24),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF6D6977), size: 24),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _V2etNavItem extends StatelessWidget {
  const _V2etNavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE8DBFF) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: selected ? const Color(0xFF4D367A) : const Color(0xFF5A5663)),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF2A2434),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V2etBottomBar extends StatelessWidget {
  const _V2etBottomBar({required this.actions, required this.selectedIndex, required this.onTap});

  final List<ShellRouteAction> actions;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF0ECF4),
        border: Border(top: BorderSide(color: Color(0xFFE4DFEB))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selectedIndex == i ? const Color(0xFFE8DBFF) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            actions[i].icon,
                            size: 18,
                            color: selectedIndex == i ? const Color(0xFF4D367A) : const Color(0xFF5A5663),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          actions[i].title,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF2A2434),
                            fontWeight: selectedIndex == i ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
