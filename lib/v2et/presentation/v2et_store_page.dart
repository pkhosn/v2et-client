import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hiddify/v2et/presentation/v2et_notice.dart';

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
                decoration: BoxDecoration(color: const Color(0xFFE8E3EE), borderRadius: BorderRadius.circular(24)),
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
                  child: Text(tr('暂无套餐数据', 'No plans available yet'), style: const TextStyle(color: Color(0xFF514C59))),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = compact ? (constraints.maxWidth >= 760 ? 2 : 1) : 3;
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

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.zh});

  final V2etStoreOffer offer;
  final bool zh;

  String tr(String a, String b) => zh ? a : b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = _descriptionText(offer.features);
    final allPrices = _priceEntries(offer);
    final mainPrice = allPrices.isEmpty ? null : allPrices.first;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2DDEA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: const Color(0xFFECE8F3),
            child: Text(offer.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            color: const Color(0xFFF2EEF7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: '¥ ',
                        style: TextStyle(color: Color(0xFF2F2A39), fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: mainPrice == null ? '0.00' : mainPrice.$2.toStringAsFixed(2),
                        style: const TextStyle(color: Color(0xFF1D2636), fontSize: 48, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mainPrice == null ? tr('未定义周期', 'Undefined period') : _periodLabel(mainPrice.$1),
                  style: const TextStyle(color: Color(0xFF4E4957), fontSize: 28, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            color: const Color(0xFFF8F5FB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF2D2737), fontSize: 15, height: 1.5),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFBDECF2),
                      foregroundColor: const Color(0xFF195A65),
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                    onPressed: () async {
                      final V2boardSession? session = ref.read(v2etSessionProvider).valueOrNull;
                      if (session == null || !session.hasToken || offer.id == null) {
                        if (!context.mounted) return;
                        showV2etNotice(context, tr('请先登录后购买', 'Please login before purchase'), error: true);
                        return;
                      }

                      final period = await _pickPeriod(context, allPrices);
                      if (period == null || !context.mounted) return;

                      final method = await _pickPaymentMethod(context, ref, session);
                      if (method == null || !context.mounted) return;

                      await _startCheckout(
                        context: context,
                        ref: ref,
                        session: session,
                        planId: offer.id!,
                        period: period,
                        paymentMethod: method,
                      );
                    },
                    child: Text(tr('立即订阅', 'Subscribe now')),
                  ),
                ),
              ],
            ),
          ),
          if (allPrices.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allPrices
                    .skip(1)
                    .map(
                      (e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9E4EF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_periodLabel(e.$1)} ¥${e.$2.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3F3A49)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<(String, double)> _priceEntries(V2etStoreOffer c) {
    const order = ['month', 'quarter', 'half_year', 'year', 'two_year', 'three_year', 'onetime', 'reset'];
    final entries = c.prices.entries.toList();
    entries.sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
    return entries.map((e) => (e.key, e.value)).toList();
  }

  String _periodLabel(String key) {
    return switch (key) {
      'month' => zh ? '月付' : 'Month',
      'quarter' => zh ? '季付' : 'Quarter',
      'half_year' => zh ? '半年' : 'Half-year',
      'year' => zh ? '年付' : 'Year',
      'two_year' => zh ? '两年' : '2-year',
      'three_year' => zh ? '三年' : '3-year',
      'onetime' => zh ? '一次性' : 'One-time',
      'reset' => zh ? '重置包' : 'Reset',
      _ => zh ? '周期' : 'Period',
    };
  }

  String _descriptionText(List<String> source) {
    if (source.isEmpty) {
      return tr('高速稳定网络服务，适配多终端场景。', 'Fast and stable network service for multi-device usage.');
    }
    final lines = source
        .map((e) => e.replaceFirst(RegExp(r'^(-|x\s+|✗\s*)'), '').trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    return lines.join('\n');
  }

  Future<String?> _pickPeriod(BuildContext context, List<(String, double)> prices) async {
    if (prices.isEmpty) return null;
    if (prices.length == 1) return prices.first.$1;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in prices)
                ListTile(
                  title: Text(_periodLabel(entry.$1)),
                  subtitle: Text('¥ ${entry.$2.toStringAsFixed(2)}'),
                  onTap: () => Navigator.of(ctx).pop(entry.$1),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<V2etPaymentMethod?> _pickPaymentMethod(BuildContext context, WidgetRef ref, V2boardSession session) async {
    final methods = await ref.read(v2etPortalApiProvider).fetchPaymentMethods(session);
    if (!context.mounted) return null;
    if (methods.isEmpty) {
      showV2etNotice(context, tr('暂无可用支付方式', 'No payment method available'), error: true);
      return null;
    }
    return showModalBottomSheet<V2etPaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final method in methods)
                ListTile(title: Text(method.name), onTap: () => Navigator.of(ctx).pop(method)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required V2boardSession session,
    required int planId,
    required String period,
    required V2etPaymentMethod paymentMethod,
  }) async {
    try {
      final api = ref.read(v2etPortalApiProvider);
      final tradeNo = await api.createOrder(session: session, planId: planId, periodField: _periodField(period));
      final checkout = await api.checkoutOrder(session: session, tradeNo: tradeNo, paymentMethodId: paymentMethod.id);
      if (!context.mounted) return;

      if (checkout.type == -1) {
        showV2etNotice(context, tr('订单已完成', 'Order completed'));
        ref.invalidate(v2etOrdersProvider);
        return;
      }

      await _showPaymentDialog(context: context, ref: ref, session: session, tradeNo: tradeNo, checkout: checkout);
    } catch (e) {
      if (!context.mounted) return;
      showV2etNotice(context, tr('下单失败: ', 'Checkout failed: ') + e.toString(), error: true);
    }
  }

  Uri? _resolvePaymentUri(String data) {
    final raw = data.trim();
    if (raw.isEmpty) return null;

    final direct = Uri.tryParse(raw);
    if (direct != null && direct.hasScheme) {
      return direct;
    }

    if (raw.startsWith('<')) {
      final html = Uri.encodeComponent(raw);
      return Uri.parse('data:text/html;charset=utf-8,$html');
    }

    final qrData = Uri.encodeComponent(raw);
    return Uri.parse('https://api.qrserver.com/v1/create-qr-code/?size=360x360&data=$qrData');
  }

  Future<void> _showPaymentDialog({
    required BuildContext context,
    required WidgetRef ref,
    required V2boardSession session,
    required String tradeNo,
    required V2etCheckoutResult checkout,
  }) async {
    final raw = checkout.data.trim();
    final isHtml = raw.startsWith('<');
    final paymentUri = _resolvePaymentUri(raw);
    final qrPayload = isHtml ? null : raw;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var checking = false;
        return StatefulBuilder(
          builder: (innerContext, setState) {
            Future<void> checkPaid() async {
              if (checking) return;
              setState(() => checking = true);
              try {
                final status = await ref
                    .read(v2etPortalApiProvider)
                    .checkOrderStatus(session: session, tradeNo: tradeNo);
                if (status == 3) {
                  ref.invalidate(v2etOrdersProvider);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    showV2etNotice(context, tr('支付成功，套餐已生效', 'Payment successful, plan activated'));
                  }
                } else if (innerContext.mounted) {
                  showV2etNotice(innerContext, tr('订单尚未支付完成，请稍后再试', 'Order still unpaid, please retry'));
                }
              } catch (e) {
                if (innerContext.mounted) {
                  showV2etNotice(innerContext, tr('查询订单失败: ', 'Order check failed: ') + e.toString(), error: true);
                }
              } finally {
                if (dialogContext.mounted) {
                  setState(() => checking = false);
                }
              }
            }

            return AlertDialog(
              title: Text(tr('完成支付', 'Complete payment')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tr('订单号', 'Trade No')}: $tradeNo'),
                    const SizedBox(height: 8),
                    if (isHtml)
                      Text(
                        tr(
                          '该支付方式优先请在客户端复制支付信息处理，若无法完成再用浏览器备用。',
                          'Handle payment in-app first. Use browser only as fallback.',
                        ),
                      )
                    else if (paymentUri != null) ...[
                      Text(tr('请扫码或打开链接完成付款', 'Scan QR code or open link to pay')),
                      const SizedBox(height: 10),
                      Center(
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(qrPayload ?? raw)}',
                          width: 220,
                          height: 220,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ] else
                      Text(tr('支付数据无效，请网页支付', 'Invalid payment payload, please pay in web browser')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr('稍后支付', 'Later'))),
                if (raw.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: raw));
                      if (!innerContext.mounted) return;
                      showV2etNotice(innerContext, tr('支付信息已复制', 'Payment info copied'));
                    },
                    child: Text(tr('复制', 'Copy')),
                  ),
                if (paymentUri != null)
                  FilledButton.tonal(
                    onPressed: () async {
                      await launchUrl(paymentUri, mode: LaunchMode.externalApplication);
                    },
                    child: Text(tr('浏览器备用', 'Browser fallback')),
                  ),
                FilledButton(
                  onPressed: checking ? null : checkPaid,
                  child: Text(checking ? tr('检查中...', 'Checking...') : tr('我已支付，检查状态', 'I paid, check status')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _periodField(String key) {
    return switch (key) {
      'month' => 'month_price',
      'quarter' => 'quarter_price',
      'half_year' => 'half_year_price',
      'year' => 'year_price',
      'two_year' => 'two_year_price',
      'three_year' => 'three_year_price',
      'onetime' => 'onetime_price',
      'reset' => 'reset_price',
      _ => 'month_price',
    };
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.icon, required this.selected, required this.onTap});

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
