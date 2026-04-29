import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hiddify/v2et/data/v2et_support_launcher.dart';
import 'package:hiddify/v2et/data/v2et_theme_provider.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hiddify/v2et/presentation/v2et_notice.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

class V2etMePage extends HookConsumerWidget {
  const V2etMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final counters = ref.watch(v2etCountersProvider).valueOrNull ?? const {'orders': 0, 'tickets': 0};
    final runtimeConfig = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
    final accentColor = ref.watch(v2etAccentColorProvider);
    final session = ref.watch(v2etSessionProvider).valueOrNull;
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final savedCredentialsFuture = useMemoized(() => ref.read(v2etRepositoryProvider).readSavedCredentials());
    final savedCredentials = useFuture(savedCredentialsFuture).data;
    final accountEmail = savedCredentials?.email.trim();
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final subInfo = activeProfile is RemoteProfileEntity ? activeProfile.subInfo : null;
    final used = subInfo?.consumption ?? 0;
    final total = subInfo?.total ?? sub?.transferEnableBytes ?? 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final days = subInfo?.remaining.inDays ?? 0;
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
            showV2etNotice(context, tr('未配置客服入口', 'Support is not configured'), error: true);
            break;
          }
          await openV2etSupport(context, supportUri, title: tr('在线客服', 'Live Support'));
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
            builder: (_) => _ChangePasswordDialog(zh: zh),
          );
          break;
        case 'tickets':
          showV2etNotice(context, tr('工单模块开发中', 'Ticket page is under development'));
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: accentColor,
                        child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sub?.planName ?? tr('套餐信息', 'Plan info'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFE9E5EF),
                        ),
                        child: Text(
                          _date(sub?.expiredAt),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F4A57)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (accountEmail == null || accountEmail.isEmpty)
                              ? tr('账号未读取', 'Account unavailable')
                              : accountEmail,
                          style: const TextStyle(color: Color(0xFF5A5563), fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: (accountEmail == null || accountEmail.isEmpty)
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: accountEmail));
                                if (!context.mounted) return;
                                showV2etNotice(context, tr('账号已复制', 'Account copied'));
                              },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: tr('复制账号', 'Copy account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(tr('已用流量', 'Used Traffic'), style: const TextStyle(fontSize: 18, color: Color(0xFF2D2737))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        '${_bytes(used)} / ${_bytes(total)}',
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 12,
                      backgroundColor: const Color(0xFFE4E0E8),
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF585362)),
                      const SizedBox(width: 4),
                      Text(
                        tr('${days < 0 ? 0 : days}天后重置流量', '${days < 0 ? 0 : days} days to reset'),
                        style: const TextStyle(color: Color(0xFF585362)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => context.go('/store'),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(tr('续费订阅', 'Renew Subscription')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

String _date(DateTime? date) {
  if (date == null) return '--';
  final d = date.toLocal();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String _bytes(int? value) {
  if (value == null || value <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var unitIndex = 0;
  var size = value.toDouble();
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${size.toStringAsFixed(size >= 100 ? 0 : 2)} ${units[unitIndex]}';
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
                                    showV2etNotice(context, tr('邀请码已复制', 'Invite code copied'));
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

  String _apiErrorText(Object error) {
    if (error is StateError) {
      final text = error.message.toString().trim();
      if (text.isNotEmpty) return text;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final candidates = [
          data['message'],
          data['msg'],
          data['error'],
          (data['data'] is Map) ? (data['data'] as Map)['message'] : null,
          (data['data'] is Map) ? (data['data'] as Map)['msg'] : null,
          (data['data'] is Map) ? (data['data'] as Map)['error'] : null,
        ];
        for (final c in candidates) {
          if (c is String && c.trim().isNotEmpty) return c.trim();
        }
      }
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '').trim();
    return raw.isEmpty ? tr('兑换失败，请稍后重试', 'Redeem failed, please retry later') : raw;
  }

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

  String _periodLabel(String key) {
    return switch (key) {
      'month' => tr('月付', 'Month'),
      'quarter' => tr('季付', 'Quarter'),
      'half_year' => tr('半年', 'Half-year'),
      'year' => tr('年付', 'Year'),
      'two_year' => tr('两年', '2-year'),
      'three_year' => tr('三年', '3-year'),
      'onetime' => tr('一次性', 'One-time'),
      'reset' => tr('重置包', 'Reset'),
      _ => tr('周期', 'Period'),
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
                  .map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p))))
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
                  if (s == null || code.isEmpty) return;
                  setState(() => submitting = true);
                  try {
                    final ok = await ref
                        .read(v2etPortalApiProvider)
                        .redeemGiftCard(
                          session: s,
                          code: code,
                          planId: p?.id,
                          periodField: period == null ? null : _periodField(period),
                        );
                    if (!mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                      showV2etNotice(context, tr('兑换成功，已自动生效', 'Redeemed successfully'));
                    } else {
                      showV2etNotice(context, tr('兑换未完成，请检查优惠力度', 'Not fully discounted'));
                    }
                  } catch (e) {
                    if (!mounted) return;
                    showV2etNotice(context, _apiErrorText(e), error: true);
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

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.zh});
  final bool zh;

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool submitting = false;

  String tr(String a, String b) => widget.zh ? a : b;

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('修改密码', 'Change password')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('旧密码', 'Old password')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('新密码', 'New password')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('确认新密码', 'Confirm new password')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: submitting ? null : () => Navigator.of(context).pop(), child: Text(tr('取消', 'Cancel'))),
        FilledButton(
          onPressed: submitting
              ? null
              : () async {
                  final oldPwd = oldPasswordController.text;
                  final newPwd = newPasswordController.text;
                  final confirmPwd = confirmPasswordController.text;
                  if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
                    showV2etNotice(context, tr('请完整填写密码信息', 'Please complete all password fields'), error: true);
                    return;
                  }
                  if (newPwd != confirmPwd) {
                    showV2etNotice(context, tr('两次新密码输入不一致', 'New passwords do not match'), error: true);
                    return;
                  }
                  if (newPwd.length < 6) {
                    showV2etNotice(context, tr('新密码长度至少 6 位', 'New password must be at least 6 characters'), error: true);
                    return;
                  }
                  final session = await ref.read(v2etRepositoryProvider).restoreSession();
                  if (session == null || !session.hasToken) {
                    if (!context.mounted) return;
                    showV2etNotice(context, tr('登录已失效，请重新登录', 'Session expired, please login again'), error: true);
                    return;
                  }
                  setState(() => submitting = true);
                  try {
                    await ref
                        .read(v2etPortalApiProvider)
                        .changePassword(session: session, oldPassword: oldPwd, newPassword: newPwd);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    showV2etNotice(context, tr('密码修改成功', 'Password changed successfully'));
                  } catch (e) {
                    if (!context.mounted) return;
                    showV2etNotice(context, e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), ''), error: true);
                  } finally {
                    if (mounted) setState(() => submitting = false);
                  }
                },
          child: Text(submitting ? tr('提交中...', 'Submitting...') : tr('确认修改', 'Confirm')),
        ),
      ],
    );
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
