import 'package:flutter/material.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etMePage extends ConsumerWidget {
  const V2etMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();

    final items = [
      tr('订单记录', 'Orders'),
      tr('流量明细', 'Traffic Details'),
      tr('我的工单', 'My Tickets'),
      tr('在线客服', 'Support'),
      tr('邀请管理', 'Invites'),
      tr('礼品卡兑换', 'Gift Card'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('我的', 'Me'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(sub?.planName ?? tr('未登录', 'Not logged in')),
              subtitle: Text('${tr('线路', 'Lines')}: ${sub?.nodeCount ?? 0}'),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(title: Text(item), trailing: const Icon(Icons.chevron_right_rounded)),
            ),
        ],
      ),
    );
  }
}
