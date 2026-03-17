import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etDashboardPage extends ConsumerWidget {
  const V2etDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final zh = locale.startsWith('zh');
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final theme = Theme.of(context);
    String tr(String a, String b) => zh ? a : b;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('仪表盘', 'Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
          ),
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
                Text(sub?.planName ?? tr('未登录套餐', 'No plan yet'), style: theme.textTheme.titleLarge),
                const Gap(8),
                Text(
                  '${tr('到期', 'Expire')}: ${sub?.expiredAt?.toLocal().toIso8601String().split('T').first ?? tr('未知', 'Unknown')}',
                ),
                const Gap(4),
                Text('${tr('流量', 'Traffic')}: ${_bytes(sub?.transferEnableBytes)}'),
                const Gap(4),
                Text('${tr('线路', 'Lines')}: ${sub?.nodeCount?.toString() ?? tr('未知', 'Unknown')}'),
              ],
            ),
          ),
          const Gap(12),
          _Card(
            onTap: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.public_rounded)),
                const Gap(12),
                Expanded(child: Text(tr('选择节点', 'Select Node'), style: theme.textTheme.titleMedium)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const Gap(22),
          const Center(child: ConnectionButton()),
          const Gap(10),
          const Center(child: ActiveProxyDelayIndicator()),
          const Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeChip(label: tr('智能分流', 'Smart')),
              const Gap(8),
              _ModeChip(label: tr('全局代理', 'Global')),
              const Gap(8),
              _ModeChip(label: 'TUN'),
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
  const _ModeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Text(label),
    );
  }
}
