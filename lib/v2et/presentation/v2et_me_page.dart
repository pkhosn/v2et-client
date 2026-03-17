import 'package:flutter/material.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etMePage extends ConsumerWidget {
  const V2etMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final items = ref.watch(v2etSupportEntriesProvider);

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
              child: ListTile(title: Text(zh ? item.title : _enLabel(item.route, item.title)), trailing: const Icon(Icons.chevron_right_rounded)),
            ),
        ],
      ),
    );
  }

  String _enLabel(String route, String fallback) {
    return switch (route) {
      'orders' => 'Orders',
      'traffic' => 'Traffic Details',
      'tickets' => 'Tickets',
      'support' => 'Support',
      'invites' => 'Invites',
      'gift-card' => 'Gift Card',
      _ => fallback,
    };
  }
}
