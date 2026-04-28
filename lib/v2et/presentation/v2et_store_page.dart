import 'dart:math';

import 'package:dio/dio.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
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
  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 720;
    String tr(String a, String b) => zh ? a : b;

    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const [];
    final visibleOffers = offers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, 16),
          children: [
            Row(
              children: [Text(tr('商店', 'Store'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))],
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
    final description = _descriptionText(offer);
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
                        style: TextStyle(color: Color(0xFF2F2A39), fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: mainPrice == null ? '0.00' : mainPrice.$2.toStringAsFixed(2),
                        style: const TextStyle(color: Color(0xFF1D2636), fontSize: 36, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mainPrice == null ? tr('未定义周期', 'Undefined period') : _periodLabel(mainPrice.$1),
                  style: const TextStyle(color: Color(0xFF4E4957), fontSize: 20, fontWeight: FontWeight.w500),
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
                Text(description, style: const TextStyle(color: Color(0xFF2D2737), fontSize: 15, height: 1.5)),
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
                      V2boardSession? session = ref.read(v2etSessionProvider).valueOrNull;
                      session ??= await ref.read(v2etRepositoryProvider).restoreSession();
                      if (session == null || !session.hasToken || offer.id == null) {
                        if (!context.mounted) return;
                        showV2etNotice(context, tr('请先登录后购买', 'Please login before purchase'), error: true);
                        return;
                      }

                      final input = await _openPurchaseDialog(
                        context: context,
                        ref: ref,
                        session: session,
                        offer: offer,
                        prices: allPrices,
                      );
                      if (input == null || !context.mounted) return;

                      final refreshed = await ref.read(v2etRepositoryProvider).restoreSession();
                      if (refreshed != null && refreshed.hasToken) {
                        session = refreshed;
                      }

                      await _startCheckout(
                        context: context,
                        ref: ref,
                        session: session,
                        planId: offer.id!,
                        period: input.period,
                        paymentMethod: input.paymentMethod,
                        couponCode: input.couponCode,
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

  String _descriptionText(V2etStoreOffer offer) {
    final lines = <String>[];
    for (final item in offer.features) {
      final raw = item.trim();
      if (raw.isEmpty) continue;

      if (raw.startsWith('✓ ') || raw.startsWith('✗ ')) {
        lines.add(raw);
        continue;
      }
      if (raw.startsWith('- ')) {
        lines.add('✗ ${raw.substring(2).trim()}');
        continue;
      }
      lines.add('✓ $raw');
    }
    if (lines.isEmpty) {
      return tr('高速稳定网络服务，适配多终端场景。', 'Fast and stable network service for multi-device usage.');
    }
    return lines.join('\n');
  }

  String _humanBytes(int value) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var unit = 0;
    var size = value.toDouble();
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 2)} ${units[unit]}';
  }

  String _inlineErrorText(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('未登录或登陆已过期') ||
        lower.contains('未登录') ||
        lower.contains('登录已过期') ||
        lower.contains('login expired') ||
        lower.contains('unauthorized')) {
      return tr('无效优惠码或不能用于此套餐', 'Invalid coupon or not applicable for this plan');
    }
    if (error is StateError) {
      final text = error.message.toString().trim();
      if (text.isNotEmpty) return text;
    }
    if (error is DioException) {
      if (error.response?.statusCode == 403) {
        return tr('不能用于此套餐或账户无权限使用此优惠码', 'This coupon is not valid for this plan or account.');
      }
      if (error.response?.statusCode == 422) {
        return tr('无效优惠码', 'Invalid coupon code');
      }
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '').trim();
    if (raw.isNotEmpty) return raw;
    return tr('优惠码验证失败', 'Coupon check failed');
  }

  Future<_PurchaseInput?> _openPurchaseDialog({
    required BuildContext context,
    required WidgetRef ref,
    required V2boardSession session,
    required V2etStoreOffer offer,
    required List<(String, double)> prices,
  }) async {
    if (prices.isEmpty || offer.id == null) return null;
    var currentSession = session;
    final methods = await ref.read(v2etPortalApiProvider).fetchPaymentMethods(currentSession);
    if (!context.mounted) return null;
    if (methods.isEmpty) {
      showV2etNotice(context, tr('暂无可用支付方式', 'No payment method available'), error: true);
      return null;
    }

    final couponController = TextEditingController();
    try {
      return await showDialog<_PurchaseInput>(
        context: context,
        builder: (dialogContext) {
          String selectedPeriod = prices.first.$1;
          V2etPaymentMethod selectedMethod = methods.first;
          bool checkingCoupon = false;
          bool? couponValid;
          String? couponMessage;

          return StatefulBuilder(
            builder: (ctx, setState) {
              final selectedPrice = prices.firstWhere((e) => e.$1 == selectedPeriod, orElse: () => prices.first);

              Future<void> verifyCoupon() async {
                final code = couponController.text.trim();
                if (code.isEmpty) {
                  setState(() {
                    couponValid = false;
                    couponMessage = tr('请输入优惠码', 'Enter coupon code');
                  });
                  return;
                }
                setState(() => checkingCoupon = true);
                try {
                  final restored = await ref.read(v2etRepositoryProvider).restoreSession();
                  if (restored != null && restored.hasToken) {
                    currentSession = restored;
                  }
                  final ok = await ref
                      .read(v2etPortalApiProvider)
                      .checkCoupon(session: currentSession, planId: offer.id!, couponCode: code);
                  setState(() {
                    couponValid = ok;
                    couponMessage = ok
                        ? tr('优惠码可用', 'Coupon is valid')
                        : tr('无效优惠码或不能用于此套餐', 'Invalid coupon or not applicable for this plan');
                  });
                } catch (e) {
                  if (_isAuthExpiredError(e)) {
                    try {
                      final restored = await ref.read(v2etRepositoryProvider).restoreSession();
                      if (restored != null && restored.hasToken) {
                        currentSession = restored;
                        final ok = await ref
                            .read(v2etPortalApiProvider)
                            .checkCoupon(session: currentSession, planId: offer.id!, couponCode: code);
                        setState(() {
                          couponValid = ok;
                          couponMessage = ok
                              ? tr('优惠码可用', 'Coupon is valid')
                              : tr('无效优惠码或不能用于此套餐', 'Invalid coupon or not applicable for this plan');
                        });
                        return;
                      }
                    } catch (_) {}
                  }
                  setState(() {
                    couponValid = false;
                    couponMessage = _inlineErrorText(e);
                  });
                } finally {
                  if (ctx.mounted) setState(() => checkingCoupon = false);
                }
              }

              final featureLines = <(bool, String)>[];
              for (final item in offer.features) {
                final raw = item.trim();
                if (raw.isEmpty) continue;
                if (raw.startsWith('✓ ')) {
                  featureLines.add((true, raw.substring(2).trim()));
                } else if (raw.startsWith('✗ ')) {
                  featureLines.add((false, raw.substring(2).trim()));
                } else if (raw.startsWith('- ')) {
                  featureLines.add((false, raw.substring(2).trim()));
                } else {
                  featureLines.add((true, raw));
                }
              }
              if (featureLines.isEmpty) {
                featureLines.add((true, tr('以官网套餐说明为准', 'Follow plan description from panel')));
              }

              return AlertDialog(
                titlePadding: const EdgeInsets.fromLTRB(18, 14, 8, 4),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(offer.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded, size: 30),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                content: SizedBox(
                  width: 640,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE3DEE9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final row in featureLines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        row.$1 ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                                        size: 20,
                                        color: row.$1 ? const Color(0xFF1E88E5) : const Color(0xFFB0B7C3),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          row.$2,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: row.$1 ? const Color(0xFF2B2B33) : const Color(0xFF9AA1AB),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(tr('付款周期', 'Billing period'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in prices)
                              ChoiceChip(
                                selected: selectedPeriod == entry.$1,
                                label: Text('${_periodLabel(entry.$1)}  ¥${entry.$2.toStringAsFixed(2)}'),
                                onSelected: (_) {
                                  setState(() => selectedPeriod = entry.$1);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: couponController,
                                decoration: InputDecoration(
                                  hintText: tr('输入优惠码', 'Coupon code'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.tonalIcon(
                              onPressed: checkingCoupon ? null : verifyCoupon,
                              icon: const Icon(Icons.verified_outlined),
                              label: Text(checkingCoupon ? tr('验证中', 'Checking') : tr('验证', 'Verify')),
                            ),
                          ],
                        ),
                        if (couponMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              couponMessage!,
                              style: TextStyle(
                                color: (couponValid ?? false) ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9E6EC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${tr('套餐价格', 'Package')}: ¥${selectedPrice.$2.toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFF494556), fontSize: 18),
                              ),
                              const Spacer(),
                              Text(
                                '${tr('总计', 'Total')}: ¥${selectedPrice.$2.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF1BA64B),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(tr('选择支付方式', 'Payment method'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final m in methods)
                              SizedBox(
                                width: 180,
                                child: FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: selectedMethod.id == m.id
                                        ? const Color(0xFF48BFF1)
                                        : const Color(0xFFE4F5FC),
                                    foregroundColor: selectedMethod.id == m.id ? Colors.white : const Color(0xFF207AA0),
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  onPressed: () {
                                    setState(() => selectedMethod = m);
                                  },
                                  icon: const Icon(Icons.lock_outline_rounded),
                                  label: Text(m.name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(tr('取消', 'Cancel'))),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(124, 40)),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _PurchaseInput(
                          period: selectedPeriod,
                          paymentMethod: selectedMethod,
                          couponCode: couponController.text.trim(),
                        ),
                      );
                    },
                    child: Text(tr('确认购买', 'Confirm order')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      couponController.dispose();
    }
  }

  Future<void> _startCheckout({
    required BuildContext context,
    required WidgetRef ref,
    required V2boardSession session,
    required int planId,
    required String period,
    required V2etPaymentMethod paymentMethod,
    String? couponCode,
  }) async {
    try {
      final api = ref.read(v2etPortalApiProvider);
      final tradeNo = await api.createOrder(
        session: session,
        planId: planId,
        periodField: _periodField(period),
        couponCode: couponCode,
      );
      final checkout = await api.checkoutOrder(session: session, tradeNo: tradeNo, paymentMethodId: paymentMethod.id);
      if (!context.mounted) return;

      if (checkout.type == -1) {
        showV2etNotice(context, tr('订单已完成', 'Order completed'));
        await _refreshAfterPayment(ref);
        ref.invalidate(v2etOrdersProvider);
        return;
      }

      await _showPaymentDialog(context: context, ref: ref, session: session, tradeNo: tradeNo, checkout: checkout);
    } catch (e) {
      if (!context.mounted) return;
      if (e is DioException && e.response?.statusCode == 403) {
        showV2etNotice(
          context,
          tr(
            '下单被面板拒绝(403)，请检查套餐购买权限、支付方式或站点风控设置',
            'Order rejected with 403. Check plan permission, payment method, or panel security settings.',
          ),
          error: true,
        );
        return;
      }
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
    var paymentWindowOpened = false;
    var paymentWindowOpening = false;
    var autoOpenAttempted = false;
    String? paymentWindowHint;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var checking = false;
        var cancelling = false;
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
                  await _refreshAfterPayment(ref);
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

            Future<void> openPaymentWindow() async {
              if (paymentUri == null || paymentWindowOpening) return;
              setState(() {
                paymentWindowOpening = true;
                paymentWindowHint = null;
              });
              try {
                final opened = await _openPaymentWindow(innerContext, paymentUri);
                setState(() {
                  paymentWindowOpened = opened;
                  paymentWindowHint = opened
                      ? tr('支付窗口已打开，请在弹出的窗口完成付款', 'Payment window opened. Complete payment in the opened window.')
                      : tr('无法打开内置支付窗口，请使用浏览器备用', 'Failed to open embedded payment window. Use browser fallback.');
                });
              } catch (e) {
                setState(() {
                  paymentWindowOpened = false;
                  paymentWindowHint = tr('打开支付窗口失败: ', 'Failed to open payment window: ') + e.toString();
                });
              } finally {
                if (dialogContext.mounted) {
                  setState(() => paymentWindowOpening = false);
                }
              }
            }

            Future<void> cancelPayment() async {
              if (cancelling) return;
              setState(() => cancelling = true);
              try {
                await ref.read(v2etPortalApiProvider).cancelOrder(session: session, tradeNo: tradeNo);
                ref.invalidate(v2etOrdersProvider);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  showV2etNotice(context, tr('订单已取消', 'Order cancelled'));
                }
              } catch (e) {
                if (innerContext.mounted) {
                  showV2etNotice(innerContext, tr('取消订单失败: ', 'Cancel order failed: ') + e.toString(), error: true);
                }
              } finally {
                if (dialogContext.mounted) {
                  setState(() => cancelling = false);
                }
              }
            }

            if (paymentUri != null && !paymentWindowOpened && !paymentWindowOpening && !autoOpenAttempted) {
              autoOpenAttempted = true;
              Future<void>.microtask(openPaymentWindow);
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
                      Text(tr('请在弹出的支付窗口内完成付款', 'Please complete payment in the opened payment window')),
                      const SizedBox(height: 10),
                      Center(
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(qrPayload ?? raw)}',
                          width: 220,
                          height: 220,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      if (paymentWindowHint != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          paymentWindowHint!,
                          style: TextStyle(
                            color: paymentWindowOpened ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ] else
                      Text(tr('支付数据无效，请网页支付', 'Invalid payment payload, please pay in web browser')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: cancelling || checking ? null : cancelPayment,
                  child: Text(cancelling ? tr('取消中...', 'Cancelling...') : tr('取消支付', 'Cancel payment')),
                ),
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
                    onPressed: paymentWindowOpening ? null : openPaymentWindow,
                    child: Text(
                      paymentWindowOpening ? tr('打开中...', 'Opening...') : tr('重新打开支付窗口', 'Reopen payment window'),
                    ),
                  ),
                if (paymentUri != null)
                  TextButton(
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

  Future<void> _refreshAfterPayment(WidgetRef ref) async {
    try {
      final repo = ref.read(v2etRepositoryProvider);
      await repo.warmup();
      final subUrl = repo.readLastSubscription()?.subscriptionUrl.toString().trim();
      if (subUrl != null && subUrl.isNotEmpty) {
        await ref.read(addProfileNotifierProvider.notifier).addClipboard(subUrl).catchError((_) {});
      }
      ref.invalidate(v2etSessionProvider);
      ref.invalidate(v2etStoreOffersProvider);
      ref.invalidate(v2etCountersProvider);
      ref.invalidate(v2etTrafficLogsProvider);
      ref.invalidate(v2etNoticesProvider);
    } catch (_) {}
  }

  bool _isAuthExpiredError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return true;
      final body = error.response?.data?.toString().toLowerCase() ?? '';
      if (body.contains('未登录') || body.contains('过期') || body.contains('login expired')) {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('未登录或登陆已过期') ||
        text.contains('未登录') ||
        text.contains('登录已过期') ||
        text.contains('login expired') ||
        text.contains('unauthorized');
  }

  Future<bool> _openPaymentWindow(BuildContext context, Uri uri) async {
    final url = uri.toString();
    if (url.isEmpty) return false;

    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (isDesktop) {
      final available = await WebviewWindow.isWebviewAvailable();
      if (available) {
        final viewport = MediaQuery.sizeOf(context);
        final maxWidth = viewport.width > 0 ? viewport.width : 1280;
        final maxHeight = viewport.height > 0 ? viewport.height : 720;
        final windowWidth = min(max((maxWidth * 0.98).round(), 760), maxWidth.round());
        final windowHeight = min(max((maxHeight * 0.96).round(), 560), maxHeight.round());
        final webview = await WebviewWindow.create(
          configuration: CreateConfiguration(
            title: tr('支付窗口', 'Payment Window'),
            titleBarTopPadding: 8,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
          ),
        );
        webview.addScriptToExecuteOnDocumentCreated(_responsiveWebviewScript);
        webview.launch(url);
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          webview.evaluateJavaScript(_responsiveWebviewScript).catchError((_) => null);
        });
        return true;
      }
    }

    final opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    if (opened) return true;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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

const String _responsiveWebviewScript = '''
(function() {
  try {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head && document.head.appendChild(meta);
    }
    meta.content = 'width=device-width,initial-scale=1,maximum-scale=1';

    var applyScale = function() {
      var root = document.documentElement;
      if (!root) return;
      root.style.transformOrigin = '0 0';
      root.style.width = '100%';
      var contentWidth = Math.max(root.scrollWidth || 0, document.body ? document.body.scrollWidth : 0);
      var viewportWidth = window.innerWidth || 0;
      if (!contentWidth || !viewportWidth) return;
      var scale = viewportWidth / contentWidth;
      if (scale >= 1) {
        root.style.transform = 'scale(1)';
        root.style.height = 'auto';
        return;
      }
      if (scale < 0.72) scale = 0.72;
      root.style.transform = 'scale(' + scale + ')';
      root.style.height = (100 / scale) + '%';
    };

    window.addEventListener('load', applyScale);
    window.addEventListener('resize', applyScale);
    setTimeout(applyScale, 300);
    setTimeout(applyScale, 1000);
  } catch (e) {}
})();
''';

class _PurchaseInput {
  const _PurchaseInput({required this.period, required this.paymentMethod, required this.couponCode});

  final String period;
  final V2etPaymentMethod paymentMethod;
  final String couponCode;
}
