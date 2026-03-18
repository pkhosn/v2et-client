import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etDashboardPage extends HookConsumerWidget {
  const V2etDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final zh = locale.startsWith('zh');
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final stats = ref.watch(statsNotifierProvider).asData?.value;
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final serviceMode = ref.watch(ConfigOptions.serviceMode);
    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;
    final theme = Theme.of(context);
    String tr(String a, String b) => zh ? a : b;

    final used = activeProfile is RemoteProfileEntity
        ? activeProfile.subInfo?.consumption
        : null;
    final total = activeProfile is RemoteProfileEntity
        ? activeProfile.subInfo?.total
        : null;
    final ratio = (used != null && total != null && total > 0)
        ? (used / total).clamp(0.0, 1.0)
        : 0.0;

    Future<void> setSmart() async {
      await ref
          .read(ConfigOptions.serviceMode.notifier)
          .update(
            PlatformUtils.isDesktop
                ? ServiceMode.systemProxy
                : ServiceMode.proxy,
          );
    }

    Future<void> setGlobal() async {
      await ref
          .read(ConfigOptions.serviceMode.notifier)
          .update(ServiceMode.proxy);
    }

    Future<void> toggleTun() async {
      final next = serviceMode == ServiceMode.tun
          ? (PlatformUtils.isDesktop
                ? ServiceMode.systemProxy
                : ServiceMode.proxy)
          : ServiceMode.tun;
      await ref.read(ConfigOptions.serviceMode.notifier).update(next);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('仪表盘', 'Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
          const Gap(8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  savedCredentials?.email ?? tr('未登录', 'Not logged in'),
                  style: theme.textTheme.titleLarge,
                ),
                const Gap(8),
                Text(sub?.planName ?? tr('未登录套餐', 'No plan yet')),
                const Gap(4),
                Text(
                  '${tr('到期', 'Expire')}: ${sub?.expiredAt?.toLocal().toIso8601String().split('T').first ?? tr('未知', 'Unknown')}',
                ),
                const Gap(4),
                Text(
                  '${tr('总流量', 'Total')}: ${_bytes(sub?.transferEnableBytes)}',
                ),
                const Gap(4),
                Text(
                  '${tr('线路', 'Lines')}: ${sub?.nodeCount?.toString() ?? tr('未知', 'Unknown')}',
                ),
                const Gap(10),
                LinearProgressIndicator(value: ratio),
                const Gap(6),
                Text(
                  '${tr('已用', 'Used')}: ${_bytes(used)} / ${_bytes(total)}',
                  style: theme.textTheme.bodySmall,
                ),
                const Gap(12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/store'),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr('续费订阅', 'Renew Subscription')),
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          _Card(
            onTap: () => context.goNamed('proxies'),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.public_rounded)),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('选择节点', 'Select Node'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('自动选择', 'Auto Select'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const Gap(22),
          const Center(child: ConnectionButton()),
          const Gap(10),
          const Center(child: ActiveProxyDelayIndicator()),
          const Gap(12),
          _Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SpeedItem(
                  label: tr('上传', 'Upload'),
                  value: (stats?.uplink.toInt() ?? 0).speed(),
                ),
                _SpeedItem(
                  label: tr('下载', 'Download'),
                  value: (stats?.downlink.toInt() ?? 0).speed(),
                ),
              ],
            ),
          ),
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(
                label: tr('智能分流', 'Smart'),
                selected:
                    serviceMode != ServiceMode.proxy &&
                    serviceMode != ServiceMode.tun,
                onTap: setSmart,
              ),
              const Gap(8),
              _ModeChip(
                label: tr('全局代理', 'Global'),
                selected: serviceMode == ServiceMode.proxy,
                onTap: setGlobal,
              ),
              const Gap(8),
              _ModeChip(
                label: 'TUN',
                selected: serviceMode == ServiceMode.tun,
                onTap: toggleTun,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _bytes(int? value) {
    if (value == null || value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var v = value.toDouble();
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 2)} ${units[i]}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondaryContainer,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? theme.colorScheme.onPrimary : null,
          ),
        ),
      ),
    );
  }
}

class _SpeedItem extends StatelessWidget {
  const _SpeedItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
