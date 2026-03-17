import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etStorePage extends ConsumerWidget {
  const V2etStorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    final banners = ref.watch(v2etBannersProvider);
    final notices = ref.watch(v2etNoticesProvider).valueOrNull ?? const [];
    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(tr('商店', 'Store'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (banners.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Stack(
                children: [
                  Image.network(
                    banners.first.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 140, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                  Positioned(left: 12, bottom: 12, child: Text(banners.first.title, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
            ),
          if (notices.isNotEmpty) ...[
            const Gap(8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.campaign_rounded),
                title: Text(notices.first.title),
                subtitle: Text(notices.first.content),
              ),
            ),
          ],
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(tr('全部', 'All'))),
              Chip(label: Text(tr('周期性', 'Recurring'))),
              Chip(label: Text(tr('一次性', 'One-time'))),
            ],
          ),
          const Gap(12),
          for (final c in offers)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
                    const Gap(6),
                    Text('¥${c.price.toStringAsFixed(2)} ${c.cycleLabel ?? tr('/周期', '/period')}', style: Theme.of(context).textTheme.titleLarge),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (c.traffic != null) Chip(label: Text('${_bytes(c.traffic)} ${tr('流量', 'Traffic')}')),
                        if (c.speed != null) Chip(label: Text(c.speed!)),
                        if (c.deviceLimit != null) Chip(label: Text('${c.deviceLimit} ${tr('设备', 'devices')}')),
                      ],
                    ),
                    const Gap(10),
                    FilledButton(onPressed: () {}, child: Text(tr('立即购买', 'Buy Now'))),
                  ],
                ),
              ),
            ),
          if (offers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(child: Text(tr('暂无套餐数据', 'No plans available yet'))),
            ),
        ],
      ),
    );
  }

  String _bytes(int? value) {
    if (value == null || value <= 0) return '0GB';
    final gb = value / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(gb >= 100 ? 0 : 2)}GB';
    final mb = value / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 2)}MB';
  }
}
