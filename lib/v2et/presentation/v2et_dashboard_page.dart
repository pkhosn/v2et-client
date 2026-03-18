import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etDashboardPage extends HookConsumerWidget {
  const V2etDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final savedCredentialsFuture = useMemoized(
      () => ref.read(v2etRepositoryProvider).readSavedCredentials(),
    );
    final savedCredentials = useFuture(savedCredentialsFuture).data;
    final connection = ref.watch(connectionNotifierProvider);
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final serviceMode = ref.watch(ConfigOptions.serviceMode);
    final session = ref.watch(v2etSessionProvider).valueOrNull;
    final notices = ref.watch(v2etNoticesProvider).valueOrNull ?? const [];
    final runtimeConfig = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
    final proxyGroup = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;
    final selectedNode = useState<String?>(null);
    final noticeShown = useState(false);
    final pingOverrides = useState<Map<String, int?>>({});
    final linkOverrides = useState<Map<String, int?>>({});
    final pingLoading = useState<Set<String>>({});
    final linkLoading = useState<Set<String>>({});

    final subInfo = activeProfile is RemoteProfileEntity ? activeProfile.subInfo : null;
    final used = subInfo?.consumption ?? 0;
    final total = subInfo?.total ?? sub?.transferEnableBytes ?? 0;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final days = subInfo?.remaining.inDays ?? 0;
    final canToggle = switch (connection) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };
    final isConnected = connection.valueOrNull == const Connected();

    void showNoticesDialog() {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(zh ? '系统公告' : 'Notice'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: notices.isEmpty
                    ? [Text(zh ? '暂无公告' : 'No notice')]
                    : notices
                        .take(5)
                        .map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(n.content),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(zh ? '我知道了' : 'OK'),
            ),
          ],
        ),
      );
    }

    useEffect(() {
      final popupEnabled = runtimeConfig?.enableNoticePopup ?? true;
      if (noticeShown.value || !popupEnabled || !(session?.hasToken ?? false) || notices.isEmpty) {
        return null;
      }
      noticeShown.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => showNoticesDialog());
      return null;
    }, [runtimeConfig?.enableNoticePopup, notices.length, session?.accessToken]);

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
            const SizedBox(height: 18),
            Center(
              child: _PowerButton(
                enabled: canToggle,
                active: isConnected,
                onTap: () async => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                isConnected ? tr('已连接', 'Connected') : tr('开始连接', 'Start Connection'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              onTap: () async {
                final tags = await _readNodeTags(ref, activeProfile);
                if (!context.mounted) return;
                if (tags.isEmpty) {
                  ref
                      .read(inAppNotificationControllerProvider)
                      .showInfoToast(tr('当前套餐暂无可用节点', 'No nodes found for this plan'));
                  return;
                }
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: const Color(0xFFF5F2F8),
                  isScrollControlled: true,
                  builder: (ctx) {
                    return Consumer(
                      builder: (context, sheetRef, _) {
                        final group = sheetRef.watch(proxiesOverviewNotifierProvider).valueOrNull;
                        final entries = _buildNodeEntries(
                          tags,
                          group,
                          pingOverrides: pingOverrides.value,
                          linkOverrides: linkOverrides.value,
                          zh: zh,
                        );
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tr('选择节点', 'Select Node'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                                    ),
                                    const Spacer(),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final groupTag = group?.tag?.toString().trim();
                                        await sheetRef
                                            .read(proxiesOverviewNotifierProvider.notifier)
                                            .urlTest(groupTag == null || groupTag.isEmpty ? 'select' : groupTag);
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: Text(tr('刷新线路', 'Refresh routes')),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: MediaQuery.of(ctx).size.height * 0.6,
                                  child: ListView.separated(
                                    itemCount: entries.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final item = entries[i];
                                      return ListTile(
                                        dense: true,
                                        leading: Text(item.flag, style: const TextStyle(fontSize: 20)),
                                        title: Text(item.tag),
                                        subtitle: item.isSpecial
                                            ? null
                                            : Text(
                                                'PING ${_latencyText(item.pingMs)} | LINK ${_latencyText(item.linkMs)}'
                                                '${item.isTimeout ? (zh ? ' · 超时' : ' · timeout') : ''}',
                                                style: TextStyle(
                                                  color: item.isTimeout ? const Color(0xFFC62828) : const Color(0xFF5A5563),
                                                  fontWeight: item.isTimeout ? FontWeight.w700 : FontWeight.w500,
                                                ),
                                              ),
                                        trailing: item.isSpecial
                                            ? selectedNode.value == item.tag
                                                  ? const Icon(Icons.check_rounded, color: Color(0xFF5A3D89))
                                                  : null
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _LatencyAction(
                                                    label: pingLoading.value.contains(item.tag)
                                                        ? tr('测试中', 'Testing')
                                                        : _latencyText(item.pingMs),
                                                    icon: Icons.network_ping_rounded,
                                                    loading: pingLoading.value.contains(item.tag),
                                                    timeout: item.pingMs == null || item.pingMs == 65535,
                                                    onTap: () async {
                                                      pingLoading.value = {...pingLoading.value, item.tag};
                                                      try {
                                                        await sheetRef
                                                            .read(proxiesOverviewNotifierProvider.notifier)
                                                            .urlTest(item.tag);
                                                        final refreshed =
                                                            sheetRef.read(proxiesOverviewNotifierProvider).valueOrNull;
                                                        final tested = _readDelayForTag(refreshed, item.tag) ?? 65535;
                                                        pingOverrides.value = {
                                                          ...pingOverrides.value,
                                                          item.tag: tested <= 0 ? 65535 : tested,
                                                        };
                                                      } finally {
                                                        final next = {...pingLoading.value};
                                                        next.remove(item.tag);
                                                        pingLoading.value = next;
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _LatencyAction(
                                                    label: linkLoading.value.contains(item.tag)
                                                        ? tr('测试中', 'Testing')
                                                        : _latencyText(item.linkMs),
                                                    icon: Icons.bolt_rounded,
                                                    loading: linkLoading.value.contains(item.tag),
                                                    timeout: item.linkMs == null || item.linkMs == 65535,
                                                    onTap: () async {
                                                      final groupTag = group?.tag?.toString().trim() ?? 'select';
                                                      final restoreTag = group?.selected?.toString().trim();
                                                      linkLoading.value = {...linkLoading.value, item.tag};
                                                      try {
                                                        final tested = await _runLinkProbe(
                                                          sheetRef,
                                                          groupTag: groupTag,
                                                          outboundTag: item.tag,
                                                          restoreTag: restoreTag,
                                                        );
                                                        linkOverrides.value = {
                                                          ...linkOverrides.value,
                                                          item.tag: tested == null || tested <= 0 ? 65535 : tested,
                                                        };
                                                      } finally {
                                                        final next = {...linkLoading.value};
                                                        next.remove(item.tag);
                                                        linkLoading.value = next;
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                        onTap: () => Navigator.of(ctx).pop(item.tag),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
                if (picked != null && picked.isNotEmpty) {
                  selectedNode.value = picked;
                }
              },
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
                        Text(
                          selectedNode.value ?? tr('自动选择', 'Auto Select'),
                          style: const TextStyle(color: Color(0xFF4C3A7A), fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF4C4755), size: 28),
                ],
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
            if (compact) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: showNoticesDialog,
                      icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF3E3947)),
                      tooltip: tr('公告', 'Notices'),
                    ),
                    IconButton(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.settings_rounded, color: Color(0xFF3E3947)),
                      tooltip: tr('设置', 'Settings'),
                    ),
                  ],
                ),
              ),
            ],
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

  Future<List<String>> _readNodeTags(WidgetRef ref, ProfileEntity? activeProfile) async {
    if (activeProfile == null) return const [];
    final repo = await ref.read(profileRepositoryProvider.future);
    final result = await repo.getRawConfig(activeProfile.id).run();
    return result.match((_) => const <String>[], _extractNodeTags);
  }

  List<String> _extractNodeTags(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return const [];
      final outbounds = data['outbounds'];
      if (outbounds is! List) return const [];
      const ignoredTypes = {
        'selector',
        'urltest',
        'direct',
        'block',
        'dns',
      };
      final tags = <String>[];
      for (final item in outbounds) {
        if (item is! Map) continue;
        final type = item['type']?.toString().toLowerCase() ?? '';
        final tag = item['tag']?.toString().trim() ?? '';
        if (tag.isEmpty || ignoredTypes.contains(type)) continue;
        tags.add(tag);
      }
      return tags.toSet().toList();
    } catch (_) {
      return const [];
    }
  }

  List<_NodeEntry> _buildNodeEntries(
    List<String> tags,
    dynamic proxyGroup, {
    required Map<String, int?> pingOverrides,
    required Map<String, int?> linkOverrides,
    required bool zh,
  }) {
    final delayMap = <String, int?>{};
    final lowered = <String>{};
    try {
      final items = proxyGroup?.items as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final tag = item.tag?.toString() ?? '';
          final delay = item.urlTestDelay is int ? item.urlTestDelay as int : 0;
          if (tag.isNotEmpty) {
            delayMap[tag] = delay > 0 ? delay : 65535;
            lowered.add(tag.toLowerCase());
          }
        }
      }
    } catch (_) {}

    final entries = <_NodeEntry>[];
    final autoLabel = zh ? '自动选择' : 'Auto Select';
    final failoverLabel = zh ? '故障转移' : 'Failover';
    if (!lowered.contains(autoLabel.toLowerCase())) {
      entries.add(_NodeEntry(tag: autoLabel, flag: '⚡', pingMs: null, linkMs: null, isSpecial: true));
    }
    if (!lowered.contains(failoverLabel.toLowerCase())) {
      entries.add(_NodeEntry(tag: failoverLabel, flag: '🛡️', pingMs: null, linkMs: null, isSpecial: true));
    }

    entries.addAll(
      tags.map((tag) {
        final pingMs = pingOverrides[tag] ?? delayMap[tag] ?? 65535;
        final linkMs = linkOverrides[tag] ?? 65535;
        return _NodeEntry(tag: tag, flag: _flagForTag(tag), pingMs: pingMs, linkMs: linkMs, isSpecial: false);
      }),
    );
    return entries;
  }

  int? _readDelayForTag(dynamic proxyGroup, String tag) {
    try {
      final items = proxyGroup?.items as List<dynamic>?;
      if (items == null) return null;
      for (final item in items) {
        final currentTag = item.tag?.toString().trim();
        if (currentTag == tag) {
          final delay = item.urlTestDelay is int ? item.urlTestDelay as int : 0;
          return delay > 0 ? delay : 65535;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _runLinkProbe(
    WidgetRef ref, {
    required String groupTag,
    required String outboundTag,
    required String? restoreTag,
  }) async {
    final repo = ref.read(proxyRepositoryProvider);
    final selected = await repo.selectProxy(groupTag, outboundTag).run();
    final canProbe = selected.match((_) => false, (_) => true);
    if (!canProbe) {
      return null;
    }

    final timer = Stopwatch()..start();
    try {
      final res = await repo.getCurrentIpInfo(CancelToken()).run();
      return res.match((_) => null, (_) => timer.elapsedMilliseconds);
    } finally {
      timer.stop();
      if (restoreTag != null && restoreTag.isNotEmpty && restoreTag != outboundTag) {
        await repo.selectProxy(groupTag, restoreTag).run();
      }
    }
  }

  String _latencyText(int? ms) {
    if (ms == null || ms <= 0) return '65535';
    return '${ms}ms';
  }

  String _flagForTag(String tag) {
    final t = tag.toLowerCase();
    final entries = <String, String>{
      'hong kong': '🇭🇰',
      'hk': '🇭🇰',
      'japan': '🇯🇵',
      'jp': '🇯🇵',
      'singapore': '🇸🇬',
      'sg': '🇸🇬',
      'usa': '🇺🇸',
      'us': '🇺🇸',
      'united states': '🇺🇸',
      'korea': '🇰🇷',
      'kr': '🇰🇷',
      'taiwan': '🇹🇼',
      'tw': '🇹🇼',
      'germany': '🇩🇪',
      'de': '🇩🇪',
      'uk': '🇬🇧',
      'united kingdom': '🇬🇧',
      'france': '🇫🇷',
      'fr': '🇫🇷',
      'canada': '🇨🇦',
      'ca': '🇨🇦',
    };
    for (final e in entries.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return '🌐';
  }
}

class _NodeEntry {
  const _NodeEntry({
    required this.tag,
    required this.flag,
    required this.pingMs,
    required this.linkMs,
    required this.isSpecial,
  });

  final String tag;
  final String flag;
  final int? pingMs;
  final int? linkMs;
  final bool isSpecial;

  bool get isTimeout {
    if (isSpecial) return false;
    return (pingMs == null || pingMs == 65535) || (linkMs == null || linkMs == 65535);
  }
}

class _LatencyAction extends StatelessWidget {
  const _LatencyAction({
    required this.label,
    required this.icon,
    required this.loading,
    required this.timeout,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool timeout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = timeout ? const Color(0xFFC62828) : const Color(0xFF1976D2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2DDEA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: fg),
                )
              else
                Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
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

class _PowerButton extends HookWidget {
  const _PowerButton({required this.enabled, required this.active, required this.onTap});

  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(duration: const Duration(milliseconds: 1400));
    useEffect(() {
      if (active) {
        controller.repeat();
      } else {
        controller.stop();
        controller.value = 0;
      }
      return null;
    }, [active]);

    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            for (final begin in [0.0, 0.5])
              AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  final t = ((controller.value + begin) % 1.0);
                  return Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 140 + t * 70,
                      height: 140 + t * 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x665A3D89), width: 2),
                      ),
                    ),
                  );
                },
              ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFF9F7FC), Color(0xFFE2DDE9)],
                radius: 0.78,
              ),
              boxShadow: [
                BoxShadow(
                  color: active ? const Color(0x555A3D89) : const Color(0x2A3B2A53),
                  blurRadius: active ? 40 : 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onTap : null,
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 64,
                  color: active ? const Color(0xFF573C87) : const Color(0xFF5A5562),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
