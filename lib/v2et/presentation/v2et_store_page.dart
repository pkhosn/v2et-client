import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';

class V2etStorePage extends ConsumerStatefulWidget {
  const V2etStorePage({super.key});

  @override
  ConsumerState<V2etStorePage> createState() => _V2etStorePageState();
}

class _V2etStorePageState extends ConsumerState<V2etStorePage> {
  String _selectedBilling = 'all';

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const [];
    final visibleOffers = offers.where((offer) {
      if (_selectedBilling == 'all') return true;
      if (_selectedBilling == 'recurring') return !offer.isOnetimeOnly;
      return offer.isOnetimeOnly;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, 16),
          children: [
            Row(
              children: [
                Text(tr('商店', 'Store'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.invalidate(v2etStoreOffersProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF342F3E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E3EE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterPill(
                      label: tr('全部', 'All'),
                      icon: Icons.link_rounded,
                      selected: _selectedBilling == 'all',
                      onTap: () => setState(() => _selectedBilling = 'all'),
                    ),
                    _FilterPill(
                      label: tr('周期性', 'Recurring'),
                      icon: Icons.autorenew_rounded,
                      selected: _selectedBilling == 'recurring',
                      onTap: () => setState(() => _selectedBilling = 'recurring'),
                    ),
                    _FilterPill(
                      label: tr('一次性', 'One-time'),
                      icon: Icons.calendar_today_outlined,
                      selected: _selectedBilling == 'onetime',
                      onTap: () => setState(() => _selectedBilling = 'onetime'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (visibleOffers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Center(
                  child: Text(
                    tr('暂无套餐数据', 'No plans available yet'),
                    style: const TextStyle(color: Color(0xFF514C59)),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000 ? 2 : 1;
                  final spacing = 12.0;
                  final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final offer in visibleOffers)
                        SizedBox(
                          width: width,
                          child: _OfferCard(offer: offer, zh: zh),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.zh});

  final V2etStoreOffer offer;
  final bool zh;

  String tr(String a, String b) => zh ? a : b;

  @override
  Widget build(BuildContext context) {
    final featureRows = _featureRows(offer.features);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2DDEA)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(offer.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: '¥',
                  style: TextStyle(color: Color(0xFF2F2A39), fontSize: 20),
                ),
                TextSpan(
                  text: _mainPrice(offer),
                  style: const TextStyle(color: Color(0xFF4D387C), fontSize: 44, fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: _mainBilling(offer),
                  style: const TextStyle(color: Color(0xFF484451), fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.water_drop_outlined,
                  title: _trafficText(offer.traffic),
                  subtitle: tr('流量', 'Traffic'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  icon: Icons.speed_rounded,
                  title: offer.speed ?? tr('不限速率', 'Unlimited'),
                  subtitle: tr('速率', 'Speed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  icon: Icons.devices_rounded,
                  title: offer.deviceLimit == null ? tr('不限制', 'Unlimited') : '${offer.deviceLimit}${tr('台', '')}',
                  subtitle: tr('设备', 'Device'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFD3CEDC)),
          const SizedBox(height: 12),
          for (final row in featureRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    row.enabled ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: row.enabled ? const Color(0xFF5A3D89) : const Color(0xFF9B96A4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.text,
                      style: TextStyle(
                        color: row.enabled ? const Color(0xFF2D2737) : const Color(0xFF8F8A97),
                        decoration: row.enabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF573C87),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: Text(tr('立即购买', 'Buy Now')),
            ),
          ),
        ],
      ),
    );
  }

  String _trafficText(int? trafficBytes) {
    if (trafficBytes == null || trafficBytes <= 0) return '0GB';
    final gb = trafficBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(gb >= 100 ? 0 : 2)}GB';
    final mb = trafficBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 2)}MB';
  }

  String _mainPrice(V2etStoreOffer c) {
    if (c.prices.isEmpty) return '0.00';
    final key = c.prices.keys.first;
    return c.prices[key]!.toStringAsFixed(2);
  }

  String _mainBilling(V2etStoreOffer c) {
    if (c.prices.isEmpty) return zh ? '/未定义' : '/undefined';
    final key = c.prices.keys.first;
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

  List<_FeatureRow> _featureRows(List<String> source) {
    return source
        .take(6)
        .map((e) {
          final text = e.trim();
          final disabled = text.startsWith('-') || text.startsWith('x ') || text.startsWith('✗');
          return _FeatureRow(
            text: text.replaceFirst(RegExp(r'^(-|x\s+|✗\s*)'), '').trim(),
            enabled: !disabled,
          );
        })
        .toList();
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5A3D89) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF3A3545)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF3A3545),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF5B438B), size: 20),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), textAlign: TextAlign.center),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6E6878), fontSize: 12)),
        ],
      ),
    );
  }
}

class _FeatureRow {
  const _FeatureRow({required this.text, required this.enabled});

  final String text;
  final bool enabled;
}
