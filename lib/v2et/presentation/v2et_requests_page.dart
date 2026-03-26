import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/log/model/log_entity.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';

class V2etRequestsPage extends HookConsumerWidget {
  const V2etRequestsPage({super.key});

  bool _zh(BuildContext context) => Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');

  bool _looksLikeRequest(String message) {
    final text = message.toLowerCase();
    return text.contains('dns') ||
        text.contains('tcp') ||
        text.contains('udp') ||
        text.contains('http') ||
        text.contains('sniff') ||
        text.contains('connect') ||
        text.contains('request');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = _zh(context);
    final state = ref.watch(logsOverviewNotifierProvider);
    final logs = state.logs.valueOrNull ?? const <LogEntity>[];
    final requests = logs.where((e) => _looksLikeRequest(e.message)).take(300).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(zh ? '请求记录' : 'Requests'),
        actions: [
          IconButton(
            tooltip: zh ? '刷新' : 'Refresh',
            onPressed: () => ref.invalidate(logsOverviewNotifierProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: requests.isEmpty
          ? Center(
              child: Text(zh ? '暂无请求记录（请先连接并产生流量）' : 'No request records yet (connect and generate traffic first)'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = requests[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.level?.name.toUpperCase() ?? 'LOG',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475467), fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            item.time?.toString() ?? '--',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.message, style: const TextStyle(fontSize: 13, color: Color(0xFF101828))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
