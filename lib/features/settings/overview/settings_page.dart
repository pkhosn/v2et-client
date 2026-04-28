import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).valueOrNull;
    final v2etEnabled = ref.watch(Preferences.enableV2etAdapter);
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        leading: v2etEnabled
            ? IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back_rounded))
            : null,
        title: Text(t.pages.settings.title),
        actions: [
          if (!v2etEnabled)
            MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          if (!v2etEnabled) const Gap(8),
        ],
      ),
      body: v2etEnabled
          ? _V2etStyledSettings(
              appInfoText: appInfo == null ? '--' : '${appInfo.version} (${appInfo.buildNumber})',
              tr: tr,
            )
          : ListView(
              children: [
                SettingsSection(
                  title: t.pages.settings.general.title,
                  icon: Icons.layers_rounded,
                  namedLocation: context.namedLocation('general'),
                ),
                SettingsSection(
                  title: t.pages.settings.routing.title,
                  icon: Icons.route_rounded,
                  namedLocation: context.namedLocation('routeOptions'),
                ),
                SettingsSection(
                  title: t.pages.settings.dns.title,
                  icon: Icons.dns_rounded,
                  namedLocation: context.namedLocation('dnsOptions'),
                ),
                SettingsSection(
                  title: t.pages.settings.inbound.title,
                  icon: Icons.input_rounded,
                  namedLocation: context.namedLocation('inboundOptions'),
                ),
                SettingsSection(
                  title: t.pages.settings.tlsTricks.title,
                  icon: Icons.content_cut_rounded,
                  namedLocation: context.namedLocation('tlsTricks'),
                ),
                SettingsSection(
                  title: t.pages.settings.warp.title,
                  icon: Icons.cloud_rounded,
                  namedLocation: context.namedLocation('warpOptions'),
                ),
                if (PlatformUtils.isIOS)
                  Material(
                    child: ListTile(
                      title: Text(t.pages.settings.resetTunnel),
                      leading: const Icon(Icons.autorenew_rounded),
                      onTap: () async {
                        await ref.read(resetTunnelNotifierProvider.notifier).run();
                      },
                    ),
                  ),
                if (Breakpoint(context).isMobile()) ...[
                  SettingsSection(
                    title: t.pages.logs.title,
                    icon: Icons.description_rounded,
                    namedLocation: context.namedLocation('logs'),
                  ),
                  SettingsSection(
                    title: t.pages.about.title,
                    icon: Icons.info_rounded,
                    namedLocation: context.namedLocation('about'),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('Version'),
                  subtitle: Text(appInfo == null ? '--' : '${appInfo.version} (${appInfo.buildNumber})'),
                ),
              ],
            ),
    );
  }
}

class _V2etStyledSettings extends HookConsumerWidget {
  const _V2etStyledSettings({required this.appInfoText, required this.tr});

  final String appInfoText;
  final String Function(String zh, String en) tr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixedPort = ref.watch(ConfigOptions.mixedPort);
    final allowLan = ref.watch(ConfigOptions.allowConnectionFromLan);
    final fakeDns = ref.watch(ConfigOptions.enableFakeDns);
    final ipv6Mode = ref.watch(ConfigOptions.ipv6Mode);

    Future<void> editMixedPort() async {
      final value = await ref
          .read(dialogNotifierProvider.notifier)
          .showSettingInput<int>(
            title: tr('端口设置', 'Port'),
            initialValue: mixedPort,
            validator: isPort,
            digitsOnly: true,
            mapTo: int.tryParse,
            onReset: ref.read(ConfigOptions.mixedPort.notifier).reset,
          );
      if (value == null) return;
      await ref.read(ConfigOptions.mixedPort.notifier).update(value);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      children: [
        _SettingCard(
          title: tr('代理设置', 'Proxy Settings'),
          subtitle: tr('管理本地代理服务', 'Manage local proxy service'),
          icon: Icons.route_rounded,
          color: const Color(0xFF2FB28D),
          children: [
            _SettingRow(
              title: tr('混合端口', 'Mixed Port'),
              subtitle: tr('HTTP & SOCKS5 共用端口', 'Shared by HTTP & SOCKS5'),
              icon: Icons.tag_rounded,
              trailing: _PillButton(text: '$mixedPort', onTap: editMixedPort),
            ),
            const Divider(height: 1),
            _SettingRow(
              title: tr('允许局域网', 'Allow LAN'),
              subtitle: tr('允许其他设备连接', 'Allow other devices to connect'),
              icon: Icons.lan_rounded,
              trailing: Switch(
                value: allowLan,
                onChanged: (v) => ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(v),
              ),
            ),
            const Divider(height: 1),
            _SettingRow(
              title: '127.0.0.1:$mixedPort',
              subtitle: tr('本地访问地址', 'Local address'),
              icon: Icons.link_rounded,
              trailing: _PillButton(
                text: tr('复制', 'Copy'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: '127.0.0.1:$mixedPort'));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: tr('IPv6 设置', 'IPv6 Settings'),
          subtitle: tr('统一管理 IPv6 相关能力', 'Manage IPv6 with one switch'),
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF39A9E2),
          children: [
            _SettingRow(
              title: tr('IPv6 总开关', 'IPv6 Master Switch'),
              subtitle: tr('统一控制核心和 DNS 的 IPv6 行为', 'Control core and DNS IPv6 behavior'),
              icon: Icons.toggle_on_rounded,
              trailing: Switch(
                value: ipv6Mode != IPv6Mode.disable,
                onChanged: (v) => ref
                    .read(ConfigOptions.ipv6Mode.notifier)
                    .update(v ? IPv6Mode.enable : IPv6Mode.disable),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: tr('DNS 设置', 'DNS Settings'),
          subtitle: tr('管理 DNS 解析配置', 'Manage DNS resolver options'),
          icon: Icons.dns_rounded,
          color: const Color(0xFF30BCA9),
          children: [
            _SettingRow(
              title: tr('DNS 覆写', 'DNS Override'),
              subtitle: tr('开启后使用应用内 DNS 配置', 'Use built-in DNS settings'),
              icon: Icons.settings_ethernet_rounded,
              trailing: Switch(
                value: fakeDns,
                onChanged: (v) => ref.read(ConfigOptions.enableFakeDns.notifier).update(v),
              ),
            ),
            const Divider(height: 1),
            _SettingRow(
              title: tr('DNS 详细配置', 'DNS Details'),
              subtitle: tr('模式与服务器等高级项', 'Mode, servers and advanced settings'),
              icon: Icons.tune_rounded,
              trailing: IconButton(
                onPressed: () => context.go(context.namedLocation('dnsOptions')),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: tr('更多设置', 'More Settings'),
          subtitle: tr('路由、入站、TLS、WARP 等', 'Route, inbound, TLS, WARP and others'),
          icon: Icons.dashboard_customize_rounded,
          color: const Color(0xFF7D68D8),
          children: [
            _JumpRow(title: tr('路由设置', 'Route Settings'), routeName: 'routeOptions'),
            const Divider(height: 1),
            _JumpRow(title: tr('入站设置', 'Inbound Settings'), routeName: 'inboundOptions'),
            const Divider(height: 1),
            _JumpRow(title: tr('TLS 设置', 'TLS Settings'), routeName: 'tlsTricks'),
            const Divider(height: 1),
            _JumpRow(title: tr('WARP 设置', 'WARP Settings'), routeName: 'warpOptions'),
            const Divider(height: 1),
            _JumpRow(title: tr('通用设置', 'General Settings'), routeName: 'general'),
          ],
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: tr('版本信息', 'Version'),
          subtitle: appInfoText,
          icon: Icons.new_releases_rounded,
          color: const Color(0xFF8E95A3),
          children: const [],
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3DEE9)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF76717E), fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFFE8EAF0),
        child: Icon(icon, color: const Color(0xFF4E5A69)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF7A7582), fontSize: 13)),
      trailing: trailing,
    );
  }
}

class _JumpRow extends StatelessWidget {
  const _JumpRow({required this.title, required this.routeName});
  final String title;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(context.namedLocation(routeName)),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        minimumSize: const Size(90, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFFE9E6EC),
        foregroundColor: const Color(0xFF2D2737),
      ),
      onPressed: onTap,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({super.key, required this.title, required this.icon, required this.namedLocation});

  final String title;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
