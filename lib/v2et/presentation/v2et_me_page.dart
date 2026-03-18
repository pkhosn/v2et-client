import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etMePage extends HookConsumerWidget {
  const V2etMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final counters = ref.watch(v2etCountersProvider).valueOrNull ?? const {'orders': 0, 'tickets': 0};
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final subInfo = activeProfile is RemoteProfileEntity ? activeProfile.subInfo : null;
    final used = subInfo?.consumption ?? 0;
    final total = subInfo?.total ?? sub?.transferEnableBytes ?? 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final days = subInfo?.remaining.inDays ?? 0;

    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;

    final entries = [
      _Entry(icon: Icons.receipt_long_rounded, label: tr('订单记录', 'Orders'), value: counters['orders']),
      _Entry(icon: Icons.donut_large_rounded, label: tr('流量明细', 'Traffic details')),
      _Entry(icon: Icons.confirmation_num_outlined, label: tr('我的工单', 'Tickets'), value: counters['tickets']),
      _Entry(icon: Icons.public_rounded, label: tr('官方网站', 'Official website')),
      _Entry(icon: Icons.groups_rounded, label: tr('加入群组', 'Join group')),
      _Entry(icon: Icons.person_add_alt_1_rounded, label: tr('邀请管理', 'Invites')),
      _Entry(icon: Icons.card_giftcard_rounded, label: tr('礼品卡兑换', 'Gift card')),
      _Entry(icon: Icons.lock_reset_rounded, label: tr('修改密码', 'Change password')),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, 16),
          children: [
            Row(
              children: [
                Text(tr('我的', 'Me'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.public_rounded, color: Color(0xFF342F3E))),
                IconButton(
                  onPressed: () {
                    ref.invalidate(v2etCountersProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF342F3E)),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF634691),
                        child: Icon(Icons.person, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _safeText(savedCredentials?.email, tr('未登录', 'Not logged in')),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.verified, color: Color(0xFF5E438E), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  sub?.planName ?? '--',
                                  style: const TextStyle(color: Color(0xFF5E438E), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF5A5563)),
                              const SizedBox(width: 4),
                              Text(tr('到期时间', 'Expire'), style: const TextStyle(color: Color(0xFF5A5563))),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                        style: const TextStyle(color: Color(0xFF4C3A7A), fontWeight: FontWeight.w700, fontSize: 16),
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
                      color: const Color(0xFF5A3D89),
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
                        backgroundColor: const Color(0xFF573C87),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () {},
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
                      Text(tr('帮助与支持', 'Help & Support'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final item in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileCard(item: item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? date) {
    if (date == null) return '--';
    final d = date.toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _safeText(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
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
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({required this.item});

  final _Entry item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDF5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(item.icon, color: const Color(0xFF3A3545), size: 24),
        title: Text(item.text, style: const TextStyle(fontSize: 16, color: Color(0xFF2D2737))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8795)),
      ),
    );
  }
}

class _Entry {
  const _Entry({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final int? value;

  String get text {
    if (value == null) return label;
    return '$label';
  }
}
