import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etDashboardPage extends HookConsumerWidget {
  const V2etDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final appInfo = ref.watch(appInfoProvider).valueOrNull;
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;
    final connection = ref.watch(connectionNotifierProvider);
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final serviceMode = ref.watch(ConfigOptions.serviceMode);

    final subInfo = activeProfile is RemoteProfileEntity ? activeProfile.subInfo : null;
    final used = subInfo?.consumption ?? 0;
    final total = subInfo?.total ?? sub?.transferEnableBytes ?? 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final days = subInfo?.remaining.inDays ?? 0;
    final canToggle = switch (connection) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };

    Future<void> setSmart() async {
      await ref.read(ConfigOptions.serviceMode.notifier).update(
            PlatformUtils.isDesktop ? ServiceMode.systemProxy : ServiceMode.proxy,
          );
    }

    Future<void> setGlobal() async {
      await ref.read(ConfigOptions.serviceMode.notifier).update(ServiceMode.proxy);
    }

    Future<void> toggleTun() async {
      final next = serviceMode == ServiceMode.tun
          ? (PlatformUtils.isDesktop ? ServiceMode.systemProxy : ServiceMode.proxy)
          : ServiceMode.tun;
      await ref.read(ConfigOptions.serviceMode.notifier).update(next);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, compact ? 12 : 20),
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 17, color: Color(0xFF4C3A7A)),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Color(0xFF5A3D89), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text('V${appInfo?.version ?? '--'}', style: const TextStyle(fontSize: 18, color: Color(0xFF2D2737))),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF2D2737))),
                IconButton(onPressed: () {}, icon: const Icon(Icons.menu_rounded, color: Color(0xFF2D2737))),
              ],
            ),
            const SizedBox(height: 10),
            _Card(
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
                      onPressed: () => context.go('/store'),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(tr('续费订阅', 'Renew Subscription')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              onTap: () => context.goNamed('proxies'),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5F438E)),
                    child: const Icon(Icons.public_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('选择节点', 'Select Node'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                        const SizedBox(height: 2),
                        Text(tr('自动选择', 'Auto Select'), style: const TextStyle(color: Color(0xFF4C3A7A), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF4C4755), size: 28),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: _PowerButton(
                enabled: canToggle,
                onTap: () async => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                tr('开始连接', 'Start Connection'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModePill(
                  label: tr('智能分流', 'Smart'),
                  selected: serviceMode != ServiceMode.proxy && serviceMode != ServiceMode.tun,
                  onTap: setSmart,
                ),
                const SizedBox(width: 8),
                _ModePill(
                  label: tr('全局代理', 'Global'),
                  selected: serviceMode == ServiceMode.proxy,
                  onTap: setGlobal,
                ),
                const SizedBox(width: 8),
                _ModePill(
                  label: 'TUN',
                  icon: Icons.visibility_off_outlined,
                  selected: serviceMode == ServiceMode.tun,
                  onTap: toggleTun,
                ),
              ],
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

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F1F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3DEE9)),
          ),
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.selected, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5A3D89) : const Color(0xFFE4DFEA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF4F4A56)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF2D2737),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFF9F7FC), Color(0xFFE2DDE9)],
          radius: 0.78,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x2A3B2A53), blurRadius: 28, offset: Offset(0, 12)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: const Icon(Icons.power_settings_new_rounded, size: 64, color: Color(0xFF5A5562)),
        ),
      ),
    );
  }
}
