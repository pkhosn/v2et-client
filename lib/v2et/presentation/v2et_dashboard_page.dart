import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:hiddify/v2et/data/v2et_support_launcher.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class V2etDashboardPage extends HookConsumerWidget {
  const V2etDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    final compact = MediaQuery.sizeOf(context).width < 900;
    String tr(String a, String b) => zh ? a : b;

    final connection = ref.watch(connectionNotifierProvider);
    final activeProfile = ref.watch(activeProfileProvider).asData?.value;
    final session = ref.watch(v2etSessionProvider).valueOrNull;
    final notices = ref.watch(v2etNoticesProvider).valueOrNull ?? const [];
    final runtimeConfig = ref.watch(v2etRuntimeConfigProvider).valueOrNull;
    final supportUri = buildV2etSupportUri(runtimeConfig);
    final noticeTrigger = ref.watch(v2etNoticeDialogTriggerProvider);
    final selectedNode = useState<String?>(null);
    final noticeShown = useState(false);
    final pingOverrides = useState<Map<String, int?>>({});
    final linkOverrides = useState<Map<String, int?>>({});
    final pingLoading = useState<Set<String>>({});
    final linkLoading = useState<Set<String>>({});

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
            width: 360,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: notices.isEmpty
                      ? [Text(zh ? '暂无公告' : 'No notice')]
                      : notices
                            .take(5)
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 3),
                                    Text(n.content, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                ),
              ),
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(zh ? '我知道了' : 'OK'))],
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

    useEffect(() {
      if (noticeTrigger <= 0 || notices.isEmpty) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => showNoticesDialog());
      return null;
    }, [noticeTrigger]);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
      floatingActionButton: supportUri == null
          ? null
          : FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFF5A3D89),
              foregroundColor: Colors.white,
              onPressed: () async {
                await launchUrl(supportUri, mode: LaunchMode.externalApplication);
              },
              child: const Icon(Icons.support_agent_rounded),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, compact ? 8 : 14, compact ? 12 : 20, compact ? 12 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight - (compact ? 20 : 28)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PowerButton(
                        enabled: canToggle,
                        active: isConnected,
                        onTap: () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConnected ? tr('已连接', 'Connected') : tr('开始连接', 'Start Connection'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? 360 : 420),
                        child: _Card(
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
                                    final isMobileSheet = MediaQuery.of(ctx).size.width < 700;
                                    final maxWidth = isMobileSheet ? MediaQuery.of(ctx).size.width : 700.0;
                                    final sheetHeight = MediaQuery.of(ctx).size.height * (isMobileSheet ? 0.66 : 0.56);
                                    final modalPing = <String, int?>{...pingOverrides.value};
                                    final modalLink = <String, int?>{...linkOverrides.value};
                                    final modalPingLoading = <String>{...pingLoading.value};
                                    final modalLinkLoading = <String>{...linkLoading.value};

                                    return StatefulBuilder(
                                      builder: (context, setModalState) {
                                        final entries = _buildNodeEntries(
                                          tags,
                                          group,
                                          pingOverrides: modalPing,
                                          linkOverrides: modalLink,
                                          zh: zh,
                                        );
                                        return SafeArea(
                                          child: Center(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: maxWidth),
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                                child: SizedBox(
                                                  height: sheetHeight,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            tr('选择节点', 'Select Node'),
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 17,
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          OutlinedButton.icon(
                                                            onPressed: () {
                                                              modalPing.clear();
                                                              modalLink.clear();
                                                              modalPingLoading.clear();
                                                              modalLinkLoading.clear();
                                                              pingOverrides.value = {};
                                                              linkOverrides.value = {};
                                                              pingLoading.value = {};
                                                              linkLoading.value = {};
                                                              sheetRef.invalidate(proxiesOverviewNotifierProvider);
                                                              setModalState(() {});
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(tr('线路列表已刷新', 'Routes refreshed')),
                                                                  duration: const Duration(seconds: 1),
                                                                ),
                                                              );
                                                            },
                                                            icon: const Icon(Icons.refresh_rounded, size: 15),
                                                            label: Text(tr('刷新线路', 'Refresh routes')),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Expanded(
                                                        child: ListView.separated(
                                                          itemCount: entries.length,
                                                          separatorBuilder: (_, _) => const Divider(height: 1),
                                                          itemBuilder: (_, i) {
                                                            final item = entries[i];
                                                            final pingBusy = modalPingLoading.contains(item.id);
                                                            final linkBusy = modalLinkLoading.contains(item.id);
                                                            return ListTile(
                                                              dense: true,
                                                              leading: Text(
                                                                item.flag,
                                                                style: const TextStyle(fontSize: 20),
                                                              ),
                                                              title: Text(item.tag),
                                                              trailing: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  _LatencyAction(
                                                                    icon: Icons.network_ping_rounded,
                                                                    loading: pingBusy,
                                                                    valueMs: item.pingMs,
                                                                    timeoutText: tr('超时', 'timeout'),
                                                                    onTap: () async {
                                                                      modalPingLoading.add(item.id);
                                                                      setModalState(() {});
                                                                      try {
                                                                        await sheetRef
                                                                            .read(
                                                                              proxiesOverviewNotifierProvider.notifier,
                                                                            )
                                                                            .urlTest(item.testTag);
                                                                        final refreshed = sheetRef
                                                                            .read(proxiesOverviewNotifierProvider)
                                                                            .valueOrNull;
                                                                        final tested =
                                                                            _readDelayForTag(refreshed, item.testTag) ??
                                                                            65535;
                                                                        modalPing[item.id] = tested <= 0
                                                                            ? 65535
                                                                            : tested;
                                                                        pingOverrides.value = {...modalPing};
                                                                      } finally {
                                                                        modalPingLoading.remove(item.id);
                                                                        pingLoading.value = {...modalPingLoading};
                                                                        setModalState(() {});
                                                                      }
                                                                    },
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  _LatencyAction(
                                                                    icon: Icons.bolt_rounded,
                                                                    loading: linkBusy,
                                                                    valueMs: item.linkMs,
                                                                    timeoutText: tr('超时', 'timeout'),
                                                                    onTap: () async {
                                                                      final groupTag = _readGroupTag(group) ?? 'select';
                                                                      final restoreTag = _readSelectedTag(group);
                                                                      modalLinkLoading.add(item.id);
                                                                      setModalState(() {});
                                                                      try {
                                                                        final tested = await _runLinkProbe(
                                                                          sheetRef,
                                                                          groupTag: groupTag,
                                                                          outboundTag: item.testTag,
                                                                          restoreTag: restoreTag,
                                                                        );
                                                                        modalLink[item.id] =
                                                                            tested == null || tested <= 0
                                                                            ? 65535
                                                                            : tested;
                                                                        linkOverrides.value = {...modalLink};
                                                                      } finally {
                                                                        modalLinkLoading.remove(item.id);
                                                                        linkLoading.value = {...modalLinkLoading};
                                                                        setModalState(() {});
                                                                      }
                                                                    },
                                                                  ),
                                                                  if (selectedNode.value == item.selectTag) ...[
                                                                    const SizedBox(width: 8),
                                                                    const Icon(
                                                                      Icons.check_rounded,
                                                                      color: Color(0xFF5A3D89),
                                                                      size: 20,
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                              onTap: () => Navigator.of(ctx).pop(item.selectTag),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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
                                    Text(
                                      tr('选择节点', 'Select Node'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                                    ),
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
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
      const ignoredTypes = {'selector', 'urltest', 'direct', 'block', 'dns'};
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
    final groupTags = <String, String>{};
    try {
      final items = proxyGroup?.items as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          final tag = item.tag?.toString().trim() ?? '';
          if (tag.isNotEmpty) {
            groupTags[tag.toLowerCase()] = tag;
          }
        }
      }
    } catch (_) {}

    String? resolveTag(List<String> candidates) {
      for (final raw in candidates) {
        final found = groupTags[raw.toLowerCase()];
        if (found != null && found.isNotEmpty) return found;
      }
      return null;
    }

    final entries = <_NodeEntry>[];
    final autoLabel = zh ? '自动选择' : 'Auto Select';
    final failoverLabel = zh ? '故障转移' : 'Failover';
    final autoSelectTag = resolveTag([autoLabel, 'auto select', 'auto', 'urltest', 'url-test', 'select']);
    final failoverTag = resolveTag([failoverLabel, 'failover', 'fallback', '故障转移', '故障转移节点']);

    entries.add(
      _NodeEntry(
        id: '__auto__',
        tag: autoLabel,
        flag: '⚡',
        selectTag: autoSelectTag ?? autoLabel,
        testTag: autoSelectTag ?? autoLabel,
        pingMs: pingOverrides['__auto__'],
        linkMs: linkOverrides['__auto__'],
        isSpecial: true,
      ),
    );
    entries.add(
      _NodeEntry(
        id: '__failover__',
        tag: failoverLabel,
        flag: '🛡️',
        selectTag: failoverTag ?? failoverLabel,
        testTag: failoverTag ?? failoverLabel,
        pingMs: pingOverrides['__failover__'],
        linkMs: linkOverrides['__failover__'],
        isSpecial: true,
      ),
    );

    entries.addAll(
      tags.map((tag) {
        return _NodeEntry(
          id: tag,
          tag: tag,
          flag: _flagForTag(tag),
          selectTag: tag,
          testTag: tag,
          pingMs: pingOverrides[tag],
          linkMs: linkOverrides[tag],
          isSpecial: false,
        );
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

  String? _readGroupTag(dynamic proxyGroup) {
    try {
      final value = proxyGroup.tag?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  String? _readSelectedTag(dynamic proxyGroup) {
    try {
      final value = proxyGroup.selected?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
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
    required this.id,
    required this.tag,
    required this.flag,
    required this.selectTag,
    required this.testTag,
    required this.pingMs,
    required this.linkMs,
    required this.isSpecial,
  });

  final String id;
  final String tag;
  final String flag;
  final String selectTag;
  final String testTag;
  final int? pingMs;
  final int? linkMs;
  final bool isSpecial;
}

class _LatencyAction extends StatelessWidget {
  const _LatencyAction({
    required this.icon,
    required this.loading,
    required this.valueMs,
    required this.timeoutText,
    required this.onTap,
  });

  final IconData icon;
  final bool loading;
  final int? valueMs;
  final String timeoutText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueMs != null;
    final timedOut = hasValue && (valueMs == null || valueMs == 65535 || valueMs! <= 0);
    final fg = timedOut ? const Color(0xFFC62828) : const Color(0xFF1976D2);
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
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
              else
                Icon(icon, size: 14, color: fg),
              if (hasValue) ...[
                const SizedBox(width: 4),
                Text(
                  timedOut ? timeoutText : '${valueMs}ms',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                ),
              ],
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
              gradient: const RadialGradient(colors: [Color(0xFFF9F7FC), Color(0xFFE2DDE9)], radius: 0.78),
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
