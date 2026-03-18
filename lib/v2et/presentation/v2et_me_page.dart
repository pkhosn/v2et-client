import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hiddify/v2et/data/v2et_support_launcher.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class V2etMePage extends HookConsumerWidget {
  const V2etMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final counters = ref.watch(v2etCountersProvider).valueOrNull ?? const {'orders': 0, 'tickets': 0};
    final runtimeConfig = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
    final session = ref.watch(v2etSessionProvider).valueOrNull;
    final supportUri = buildV2etSupportUri(runtimeConfig);

    final entries = [
      _Entry(id: 'orders', icon: Icons.receipt_long_rounded, label: tr('订单记录', 'Orders'), value: counters['orders']),
      _Entry(id: 'traffic', icon: Icons.donut_large_rounded, label: tr('流量明细', 'Traffic details')),
      _Entry(
        id: 'tickets',
        icon: Icons.confirmation_num_outlined,
        label: tr('我的工单', 'Tickets'),
        value: counters['tickets'],
      ),
      _Entry(id: 'support', icon: Icons.support_agent_rounded, label: tr('在线客服', 'Live support')),
      _Entry(id: 'official', icon: Icons.public_rounded, label: tr('官方网站', 'Official website')),
      _Entry(id: 'group', icon: Icons.groups_rounded, label: tr('加入群组', 'Join group')),
      _Entry(id: 'invite', icon: Icons.person_add_alt_1_rounded, label: tr('邀请管理', 'Invites')),
      _Entry(id: 'gift', icon: Icons.card_giftcard_rounded, label: tr('礼品卡兑换', 'Gift card')),
      _Entry(id: 'password', icon: Icons.lock_reset_rounded, label: tr('修改密码', 'Change password')),
      _Entry(id: 'logout', icon: Icons.logout_rounded, label: tr('退出登录', 'Logout')),
    ];

    Future<void> launchConfiguredUrl(String? url) async {
      if (url == null || url.trim().isEmpty) return;
      final uri = Uri.tryParse(url.trim());
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> onEntryTap(_Entry item) async {
      switch (item.id) {
        case 'orders':
          await showDialog<void>(
            context: context,
            builder: (_) => _OrdersDialog(zh: zh),
          );
          break;
        case 'traffic':
          await showDialog<void>(
            context: context,
            builder: (_) => _TrafficDialog(zh: zh),
          );
          break;
        case 'official':
          await launchConfiguredUrl(runtimeConfig?.officialSiteUrl ?? session?.baseUrl.toString());
          break;
        case 'support':
          if (supportUri == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr('未配置客服入口', 'Support is not configured'))));
            break;
          }
          await launchUrl(supportUri, mode: LaunchMode.externalApplication);
          break;
        case 'group':
          await launchConfiguredUrl(runtimeConfig?.groupUrl);
          break;
        case 'invite':
          await showDialog<void>(
            context: context,
            builder: (_) => _InviteDialog(zh: zh, fallbackUrl: runtimeConfig?.inviteManageUrl),
          );
          break;
        case 'gift':
          await showDialog<void>(
            context: context,
            builder: (_) => _GiftCardDialog(zh: zh, fallbackUrl: runtimeConfig?.giftCardHelpUrl),
          );
          break;
        case 'password':
          await showDialog<void>(
            context: context,
            builder: (_) => _ChangePasswordTipDialog(zh: zh),
          );
          break;
        case 'tickets':
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr('工单模块开发中', 'Ticket page is under development'))));
          break;
        case 'logout':
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(tr('退出登录', 'Logout')),
              content: Text(tr('确认退出当前账号？', 'Are you sure you want to logout?')),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('取消', 'Cancel'))),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('确定', 'Confirm'))),
              ],
            ),
          );
          if (shouldLogout != true) break;
          await ref.read(v2etRepositoryProvider).logout();
          ref.read(v2etSessionUnlockedProvider.notifier).state = false;
          ref.invalidate(v2etSessionProvider);
          ref.invalidate(v2etNoticesProvider);
          if (context.mounted) {
            context.go('/v2et-login');
          }
          break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, 16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1F8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3DEE9)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_center_rounded, color: Color(0xFF5B438B), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        tr('帮助与支持', 'Help & Support'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final item in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileCard(item: item, onTap: () => onEntryTap(item)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({required this.item, required this.onTap});

  final _Entry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1EDF5), borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(item.icon, color: const Color(0xFF3A3545), size: 24),
        title: Text(item.text, style: const TextStyle(fontSize: 16, color: Color(0xFF2D2737))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8795)),
      ),
    );
  }
}

class _Entry {
  const _Entry({required this.id, required this.icon, required this.label, this.value});

  final String id;
  final IconData icon;
  final String label;
  final int? value;

  String get text {
    if (value == null) return label;
    return '$label ($value)';
  }
}

class _OrdersDialog extends ConsumerWidget {
  const _OrdersDialog({required this.zh});
  final bool zh;

  String tr(String a, String b) => zh ? a : b;

  String _statusText(int status) {
    return switch (status) {
      0 => tr('待支付', 'Pending'),
      1 => tr('已取消', 'Cancelled'),
      2 => tr('关闭', 'Closed'),
      3 => tr('已完成', 'Paid'),
      _ => '$status',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(v2etOrdersProvider).valueOrNull ?? const <V2etOrderRecord>[];
    return AlertDialog(
      title: Text(tr('订单记录', 'Orders')),
      content: SizedBox(
        width: 560,
        height: 420,
        child: orders.isEmpty
            ? Center(child: Text(tr('暂无订单', 'No orders')))
            : ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = orders[i];
                  return ListTile(
                    title: Text('${o.planName ?? '--'}  ¥${o.totalAmount.toStringAsFixed(2)}'),
                    subtitle: Text('${o.tradeNo} · ${o.createdAt?.toString() ?? '--'}'),
                    trailing: Text(_statusText(o.status)),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('关闭', 'Close')))],
    );
  }
}

class _TrafficDialog extends ConsumerWidget {
  const _TrafficDialog({required this.zh});
  final bool zh;

  String tr(String a, String b) => zh ? a : b;

  String _size(int value) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var unitIndex = 0;
    var size = value.toDouble();
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 2)} ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(v2etTrafficLogsProvider).valueOrNull ?? const <V2etTrafficRecord>[];
    return AlertDialog(
      title: Text(tr('流量明细', 'Traffic details')),
      content: SizedBox(
        width: 560,
        height: 420,
        child: logs.isEmpty
            ? Center(child: Text(tr('暂无流量记录', 'No traffic logs')))
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = logs[i];
                  return ListTile(
                    title: Text('↑ ${_size(item.upload)}   ↓ ${_size(item.download)}'),
                    subtitle: Text(item.recordAt?.toString() ?? '--'),
                    trailing: Text('x${item.serverRate.toStringAsFixed(2)}'),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('关闭', 'Close')))],
    );
  }
}

class _InviteDialog extends ConsumerWidget {
  const _InviteDialog({required this.zh, this.fallbackUrl});
  final bool zh;
  final String? fallbackUrl;

  String tr(String a, String b) => zh ? a : b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(v2etInviteInfoProvider).valueOrNull;
    final session = ref.watch(v2etSessionProvider).valueOrNull;
    return AlertDialog(
      title: Text(tr('邀请管理', 'Invite management')),
      content: SizedBox(
        width: 560,
        height: 420,
        child: info == null
            ? Center(child: Text(tr('暂无数据', 'No data')))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statChip(tr('注册用户', 'Users'), '${info.stat[0]}'),
                      _statChip(tr('累计佣金', 'Commission'), '${info.stat[1]}'),
                      _statChip(tr('确认中', 'Pending'), '${info.stat[2]}'),
                      _statChip(tr('比例(%)', 'Rate'), '${info.stat[3]}'),
                      _statChip(tr('可用佣金', 'Available'), '${info.stat[4]}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final s = session;
                          if (s == null) return;
                          await ref.read(v2etPortalApiProvider).generateInviteCode(s);
                          ref.invalidate(v2etInviteInfoProvider);
                        },
                        child: Text(tr('生成邀请码', 'Generate code')),
                      ),
                      const SizedBox(width: 8),
                      if (fallbackUrl != null && fallbackUrl!.trim().isNotEmpty)
                        OutlinedButton(
                          onPressed: () async {
                            final uri = Uri.tryParse(fallbackUrl!.trim());
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          child: Text(tr('网页管理', 'Web manage')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: info.codes.isEmpty
                        ? Center(child: Text(tr('暂无可用邀请码', 'No invite code yet')))
                        : ListView.separated(
                            itemCount: info.codes.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final code = info.codes[i];
                              return ListTile(
                                title: Text(code),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy_rounded),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: code));
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(SnackBar(content: Text(tr('邀请码已复制', 'Invite code copied'))));
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('关闭', 'Close')))],
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFEDE8F3), borderRadius: BorderRadius.circular(999)),
      child: Text('$label: $value'),
    );
  }
}

class _GiftCardDialog extends ConsumerStatefulWidget {
  const _GiftCardDialog({required this.zh, this.fallbackUrl});
  final bool zh;
  final String? fallbackUrl;

  @override
  ConsumerState<_GiftCardDialog> createState() => _GiftCardDialogState();
}

class _GiftCardDialogState extends ConsumerState<_GiftCardDialog> {
  final codeController = TextEditingController();
  V2etStoreOffer? selectedPlan;
  String? selectedPeriod;
  bool submitting = false;

  String tr(String a, String b) => widget.zh ? a : b;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const <V2etStoreOffer>[];
    final session = ref.watch(v2etSessionProvider).valueOrNull;

    selectedPlan ??= offers.isNotEmpty ? offers.first : null;
    selectedPeriod ??= selectedPlan?.prices.keys.toList().firstOrNull;

    return AlertDialog(
      title: Text(tr('礼品卡兑换', 'Gift card redeem')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(labelText: tr('优惠码 / 礼品卡', 'Coupon / Gift code')),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<V2etStoreOffer>(
              value: selectedPlan,
              decoration: InputDecoration(labelText: tr('选择套餐', 'Select plan')),
              items: offers
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedPlan = v;
                  selectedPeriod = v?.prices.keys.toList().firstOrNull;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedPeriod,
              decoration: InputDecoration(labelText: tr('购买周期', 'Billing period')),
              items: (selectedPlan?.prices.keys.toList() ?? const <String>[])
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => selectedPeriod = v),
            ),
            if (widget.fallbackUrl != null && widget.fallbackUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final uri = Uri.tryParse(widget.fallbackUrl!.trim());
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Text(tr('查看兑换说明', 'View redeem guide')),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('取消', 'Cancel'))),
        FilledButton(
          onPressed: submitting
              ? null
              : () async {
                  final s = session;
                  final p = selectedPlan;
                  final period = selectedPeriod;
                  final code = codeController.text.trim();
                  if (s == null || p?.id == null || period == null || code.isEmpty) return;
                  setState(() => submitting = true);
                  try {
                    final ok = await ref
                        .read(v2etPortalApiProvider)
                        .redeemCouponPlan(
                          session: s,
                          planId: p!.id!,
                          periodField: _periodField(period),
                          couponCode: code,
                        );
                    if (!mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(tr('兑换成功，已自动生效', 'Redeemed successfully'))));
                    } else {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(tr('兑换未完成，请检查优惠力度', 'Not fully discounted'))));
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(tr('兑换失败: ', 'Redeem failed: ') + e.toString())));
                  } finally {
                    if (mounted) setState(() => submitting = false);
                  }
                },
          child: Text(tr('立即兑换', 'Redeem now')),
        ),
      ],
    );
  }
}

class _ChangePasswordTipDialog extends StatelessWidget {
  const _ChangePasswordTipDialog({required this.zh});
  final bool zh;

  String tr(String a, String b) => zh ? a : b;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('修改密码', 'Change password')),
      content: Text(tr('请在登录页使用“忘记密码”流程重置密码。', 'Please use "Forgot Password" on login page.')),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('知道了', 'OK')))],
    );
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
