import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etStorePage extends HookConsumerWidget {
  const V2etStorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    String tr(String a, String b) => zh ? a : b;
    final banners = ref.watch(v2etBannersProvider);
    final notices = ref.watch(v2etNoticesProvider).valueOrNull ?? const [];
    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const [];
    final selectedBilling = useState<String>('all');

    final visibleOffers = offers.where((offer) {
      if (selectedBilling.value == 'all') {
        return true;
      }
      if (selectedBilling.value == 'recurring') {
        return !offer.isOnetimeOnly;
      }
      return offer.isOnetimeOnly;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('商店', 'Store'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (banners.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  Image.network(
                    banners.first.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Text(
                      banners.first.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (notices.isNotEmpty) ...[
            const Gap(8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
              ChoiceChip(
                selected: selectedBilling.value == 'all',
                onSelected: (_) => selectedBilling.value = 'all',
                label: Text(tr('全部', 'All')),
              ),
              ChoiceChip(
                selected: selectedBilling.value == 'recurring',
                onSelected: (_) => selectedBilling.value = 'recurring',
                label: Text(tr('周期性', 'Recurring')),
              ),
              ChoiceChip(
                selected: selectedBilling.value == 'onetime',
                onSelected: (_) => selectedBilling.value = 'onetime',
                label: Text(tr('一次性', 'One-time')),
              ),
            ],
          ),
          const Gap(12),
          for (final c in visibleOffers)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Gap(6),
                    Text(
                      _priceHeadline(c, zh),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (c.traffic != null)
                          Chip(
                            label: Text(
                              '${_bytes(c.traffic)} ${tr('流量', 'Traffic')}',
                            ),
                          ),
                        if (c.speed != null) Chip(label: Text(c.speed!)),
                        if (c.deviceLimit != null)
                          Chip(
                            label: Text(
                              '${c.deviceLimit} ${tr('设备', 'devices')}',
                            ),
                          ),
                      ],
                    ),
                    if (c.prices.length > 1) ...[
                      const Gap(8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: c.prices.entries
                            .map(
                              (e) => Chip(
                                label: Text(
                                  '${_billingLabel(e.key, zh)} ¥${e.value.toStringAsFixed(2)}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (c.features.isNotEmpty) ...[
                      const Gap(10),
                      for (final item in c.features.take(6))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Gap(10),
                    FilledButton(
                      onPressed: () {},
                      child: Text(tr('立即购买', 'Buy Now')),
                    ),
                  ],
                ),
              ),
            ),
          if (visibleOffers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Text(tr('暂无套餐数据', 'No plans available yet')),
              ),
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

  String _priceHeadline(V2etStoreOffer offer, bool zh) {
    if (offer.prices.isEmpty) {
      return zh ? '¥0.00 /未定义' : '¥0.00 /undefined';
    }
    final order = [
      'month',
      'quarter',
      'half_year',
      'year',
      'two_year',
      'three_year',
      'onetime',
      'reset',
    ];
    final first = order.firstWhere(
      (k) => offer.prices.containsKey(k),
      orElse: () => offer.prices.keys.first,
    );
    return '¥${offer.prices[first]!.toStringAsFixed(2)} ${_billingLabel(first, zh)}';
  }

  String _billingLabel(String key, bool zh) {
    return switch (key) {
      'month' => zh ? '/月付' : '/month',
      'quarter' => zh ? '/季付' : '/quarter',
      'half_year' => zh ? '/半年' : '/half-year',
      'year' => zh ? '/年付' : '/year',
      'two_year' => zh ? '/两年' : '/2-year',
      'three_year' => zh ? '/三年' : '/3-year',
      'onetime' => zh ? '/一次性' : '/one-time',
      'reset' => zh ? '/重置包' : '/reset',
      _ => zh ? '/周期' : '/period',
    };
  }
}
