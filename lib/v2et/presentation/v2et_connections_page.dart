import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';

class V2etConnectionsPage extends HookConsumerWidget {
  const V2etConnectionsPage({super.key});

  bool _zh(BuildContext context) => Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');

  int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString();
    return int.tryParse(text) ?? 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = _zh(context);
    final stats = ref.watch(statsNotifierProvider).valueOrNull;

    final inConn = stats?.connectionsIn ?? 0;
    final outConn = stats?.connectionsOut ?? 0;
    final goroutines = stats?.goroutines ?? 0;
    final memoryMb = stats == null ? 0 : (stats.memory.toInt() / 1024 / 1024).round();
    final uplink = (_toInt(stats?.uplink) / 1024).round();
    final downlink = (_toInt(stats?.downlink) / 1024).round();

    Widget card(String title, String value, {Color? color}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF667085))),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF1D2939)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(zh ? '连接详情' : 'Connections')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width < 900 ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            card(zh ? '入站连接' : 'Inbound', '$inConn', color: const Color(0xFF0BA5EC)),
            card(zh ? '出站连接' : 'Outbound', '$outConn', color: const Color(0xFF12B76A)),
            card(zh ? '并发协程' : 'Goroutines', '$goroutines'),
            card(zh ? '内存占用(MB)' : 'Memory (MB)', '$memoryMb'),
            card(zh ? '上行速率(KB/s)' : 'Uplink (KB/s)', '$uplink'),
            card(zh ? '下行速率(KB/s)' : 'Downlink (KB/s)', '$downlink'),
          ],
        ),
      ),
    );
  }
}
