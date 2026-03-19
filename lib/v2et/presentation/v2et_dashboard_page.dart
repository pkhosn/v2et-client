import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hiddify/v2et/model/v2board_session.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hiddify/v2et/presentation/v2et_notice.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum _UsageGuard { ok, expired, outOfTraffic }

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
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const <V2etStoreOffer>[];
    final selectedNode = useState<String?>(null);
    final noticeShown = useState(false);
    final statusNotifiedKey = useState<String?>(null);
    final pingOverrides = useState<Map<String, int?>>({});
    final linkOverrides = useState<Map<String, int?>>({});
    final pingLoading = useState<Set<String>>({});
    final linkLoading = useState<Set<String>>({});

    final remoteInfo = activeProfile is RemoteProfileEntity ? activeProfile.subInfo : null;
    final totalBytes = remoteInfo?.total ?? sub?.transferEnableBytes;
    final usedBytes = remoteInfo?.consumption ?? 0;
    final remainingBytes = totalBytes == null ? null : (totalBytes - usedBytes).clamp(0, totalBytes);
    final remainingDays = remoteInfo?.remaining.inDays;
    final warnDays = runtimeConfig?.expiryWarnDays ?? 3;
    final warnTrafficBytes = runtimeConfig?.trafficWarnBytes ?? (3 * 1024 * 1024 * 1024);
    final expired =
        (sub?.expiredAt?.isBefore(DateTime.now()) ?? false) || ((remoteInfo?.remaining.inSeconds ?? 1) <= 0);
    final outOfTraffic = totalBytes != null && totalBytes > 0 && usedBytes >= totalBytes;
    final warnExpirySoon = !expired && remainingDays != null && remainingDays >= 0 && remainingDays <= warnDays;
    final warnTrafficSoon =
        !outOfTraffic && remainingBytes != null && remainingBytes > 0 && remainingBytes <= warnTrafficBytes;
    final guard = expired
        ? _UsageGuard.expired
        : outOfTraffic
        ? _UsageGuard.outOfTraffic
        : _UsageGuard.ok;

    final canToggle = switch (connection) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };
    final isConnected = connection.valueOrNull == const Connected();
    final connectEnabled = canToggle && guard == _UsageGuard.ok;

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

    useEffect(() {
      if (guard == _UsageGuard.ok) {
        statusNotifiedKey.value = null;
        return null;
      }
      final key = guard.name;
      if (statusNotifiedKey.value != key) {
        statusNotifiedKey.value = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showV2etNotice(
            context,
            guard == _UsageGuard.expired
                ? tr('套餐已到期，请续费后使用', 'Plan expired, please renew to continue')
                : tr('流量已耗尽，请重置流量后使用', 'Traffic exhausted, reset traffic to continue'),
            error: true,
          );
        });
      }
      if (isConnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(connectionNotifierProvider.notifier).abortConnection();
        });
      }
      return null;
    }, [guard, isConnected]);

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
                        enabled: connectEnabled,
                        active: isConnected,
                        onTap: () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
                      ),
                      if (guard != _UsageGuard.ok) ...[
                        const SizedBox(height: 8),
                        Text(
                          guard == _UsageGuard.expired
                              ? tr('套餐已到期，请续费后使用', 'Plan expired, please renew to continue')
                              : tr('流量已耗尽，请重置流量后使用', 'Traffic exhausted, reset traffic to continue'),
                          style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        if (guard == _UsageGuard.expired)
                          FilledButton.tonalIcon(
                            onPressed: () => _openRenewDialog(context),
                            icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                            label: Text(tr('续费套餐', 'Renew plan')),
                          )
                        else
                          FilledButton.tonalIcon(
                            onPressed: () => _openResetDialog(context, ref, offers, session, zh),
                            icon: const Icon(Icons.restart_alt_rounded, size: 18),
                            label: Text(tr('重置流量', 'Reset traffic')),
                          ),
                      ] else if (warnExpirySoon || warnTrafficSoon) ...[
                        const SizedBox(height: 8),
                        Text(
                          warnExpirySoon
                              ? tr(
                                  '套餐将在$remainingDays天后到期，请及时续费',
                                  'Plan expires in $remainingDays day(s), please renew',
                                )
                              : tr('剩余流量不足，请及时重置或续费', 'Low remaining traffic, please reset or renew'),
                          style: const TextStyle(color: Color(0xFFB26A00), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.tonalIcon(
                          onPressed: warnExpirySoon
                              ? () => _openRenewDialog(context)
                              : () => _openResetDialog(context, ref, offers, session, zh),
                          icon: Icon(warnExpirySoon ? Icons.shopping_bag_rounded : Icons.restart_alt_rounded, size: 18),
                          label: Text(warnExpirySoon ? tr('去续费', 'Renew') : tr('去重置流量', 'Reset traffic')),
                        ),
                      ],
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
                            if (tags.isEmpty && guard == _UsageGuard.ok) {
                              showV2etNotice(context, tr('当前套餐暂无可用节点', 'No nodes found for this plan'));
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
                                    final maxWidth = isMobileSheet ? MediaQuery.of(ctx).size.width : 560.0;
                                    final sheetHeight = isMobileSheet
                                        ? MediaQuery.of(ctx).size.height * 0.66
                                        : (MediaQuery.of(ctx).size.height * 0.52).clamp(360.0, 460.0);
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
                                                              showV2etNotice(
                                                                context,
                                                                tr('线路列表已刷新', 'Routes refreshed'),
                                                                duration: const Duration(seconds: 1),
                                                              );
                                                            },
                                                            icon: const Icon(Icons.refresh_rounded, size: 15),
                                                            label: Text(tr('刷新线路', 'Refresh routes')),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Expanded(
                                                        child: guard == _UsageGuard.expired
                                                            ? Center(
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      tr(
                                                                        '套餐已到期，请续费后查看可用线路',
                                                                        'Plan expired. Renew to view nodes',
                                                                      ),
                                                                      style: const TextStyle(
                                                                        color: Color(0xFFC62828),
                                                                        fontWeight: FontWeight.w700,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 10),
                                                                    FilledButton.tonalIcon(
                                                                      onPressed: () {
                                                                        Navigator.of(ctx).pop();
                                                                        _openRenewDialog(context);
                                                                      },
                                                                      icon: const Icon(
                                                                        Icons.shopping_bag_rounded,
                                                                        size: 18,
                                                                      ),
                                                                      label: Text(tr('去续费', 'Renew now')),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            : ListView.separated(
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
                                                                              final groupTag =
                                                                                  _readGroupTag(group) ?? 'select';
                                                                              final restoreTag = _readSelectedTag(
                                                                                group,
                                                                              );
                                                                              final wasConnected =
                                                                                  await _prepareTestConnection(
                                                                                    sheetRef,
                                                                                    context: context,
                                                                                    zh: zh,
                                                                                  );
                                                                              if (wasConnected == null) {
                                                                                return;
                                                                              }
                                                                              await sheetRef
                                                                                  .read(proxyRepositoryProvider)
                                                                                  .selectProxy(groupTag, item.testTag)
                                                                                  .run();
                                                                              await sheetRef
                                                                                  .read(
                                                                                    proxiesOverviewNotifierProvider
                                                                                        .notifier,
                                                                                  )
                                                                                  .urlTest(groupTag);
                                                                              final refreshed = sheetRef
                                                                                  .read(proxiesOverviewNotifierProvider)
                                                                                  .valueOrNull;
                                                                              final tested =
                                                                                  _readDelayForTag(
                                                                                    refreshed,
                                                                                    item.testTag,
                                                                                  ) ??
                                                                                  65535;
                                                                              modalPing[item.id] = tested <= 0
                                                                                  ? 65535
                                                                                  : tested;
                                                                              pingOverrides.value = {...modalPing};
                                                                              if (restoreTag != null &&
                                                                                  restoreTag.isNotEmpty) {
                                                                                await sheetRef
                                                                                    .read(proxyRepositoryProvider)
                                                                                    .selectProxy(groupTag, restoreTag)
                                                                                    .run();
                                                                              }
                                                                              await _restoreAfterTest(
                                                                                sheetRef,
                                                                                wasConnected,
                                                                              );
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
                                                                            final groupTag =
                                                                                _readGroupTag(group) ?? 'select';
                                                                            final restoreTag = _readSelectedTag(group);
                                                                            modalLinkLoading.add(item.id);
                                                                            setModalState(() {});
                                                                            try {
                                                                              final wasConnected =
                                                                                  await _prepareTestConnection(
                                                                                    sheetRef,
                                                                                    context: context,
                                                                                    zh: zh,
                                                                                  );
                                                                              if (wasConnected == null) {
                                                                                return;
                                                                              }
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
                                                                              await _restoreAfterTest(
                                                                                sheetRef,
                                                                                wasConnected,
                                                                              );
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
    final currentGroupTag = _readGroupTag(proxyGroup) ?? 'select';
    final autoSelectTag = resolveTag([autoLabel, 'auto select', 'auto', 'urltest', 'url-test', 'select']);
    final failoverTag = resolveTag([failoverLabel, 'failover', 'fallback', '故障转移', '故障转移节点']);

    entries.add(
      _NodeEntry(
        id: '__auto__',
        tag: autoLabel,
        flag: '⚡',
        selectTag: autoSelectTag ?? currentGroupTag,
        testTag: autoSelectTag ?? currentGroupTag,
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
        selectTag: failoverTag ?? currentGroupTag,
        testTag: failoverTag ?? currentGroupTag,
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
      final res = await repo.getCurrentIpInfo(CancelToken()).run().timeout(const Duration(seconds: 8));
      return res.match((_) => null, (_) => timer.elapsedMilliseconds);
    } finally {
      timer.stop();
      if (restoreTag != null && restoreTag.isNotEmpty && restoreTag != outboundTag) {
        await repo.selectProxy(groupTag, restoreTag).run();
      }
    }
  }

  Future<bool?> _prepareTestConnection(WidgetRef ref, {required BuildContext context, required bool zh}) async {
    final beforeConnected = ref.read(connectionNotifierProvider).valueOrNull == const Connected();
    if (beforeConnected) return true;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(zh ? '进入测试模式' : 'Enter test mode'),
            content: Text(
              zh
                  ? '将临时启动线路测试通道，测试后自动关闭，不会保持连接状态。是否继续？'
                  : 'A temporary test tunnel will start and close automatically after testing. Continue?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(zh ? '取消' : 'Cancel')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(zh ? '继续' : 'Continue')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return null;
    }

    await ref.read(connectionNotifierProvider.notifier).mayConnect();
    for (var i = 0; i < 16; i++) {
      final connected = ref.read(connectionNotifierProvider).valueOrNull == const Connected();
      if (connected) return false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (context.mounted) {
      showV2etNotice(context, zh ? '测试通道启动失败' : 'Failed to start test tunnel', error: true);
    }
    return null;
  }

  Future<void> _restoreAfterTest(WidgetRef ref, bool wasConnected) async {
    if (wasConnected) return;
    await ref.read(connectionNotifierProvider.notifier).abortConnection();
  }

  Future<void> _openRenewDialog(BuildContext context) async {
    final zh = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('zh');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(zh ? '套餐已到期' : 'Plan expired'),
        content: Text(zh ? '请续费后再使用连接功能。' : 'Please renew to continue using connection.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(zh ? '取消' : 'Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/store');
            },
            child: Text(zh ? '去续费' : 'Renew now'),
          ),
        ],
      ),
    );
  }

  Future<void> _openResetDialog(
    BuildContext context,
    WidgetRef ref,
    List<V2etStoreOffer> offers,
    V2boardSession? session,
    bool zh,
  ) async {
    var currentSession = session;
    currentSession ??= await ref.read(v2etRepositoryProvider).restoreSession();
    if (currentSession == null || !currentSession.hasToken) {
      if (context.mounted) showV2etNotice(context, zh ? '请先登录账号' : 'Please login first', error: true);
      return;
    }

    final resetPlans = offers.where((o) => (o.prices['reset'] ?? 0) >= 0).toList();
    if (resetPlans.isEmpty) {
      if (context.mounted) {
        showV2etNotice(context, zh ? '当前暂无可重置流量套餐' : 'No reset package available', error: true);
      }
      return;
    }

    final picked = await showDialog<V2etStoreOffer>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(zh ? '选择重置流量套餐' : 'Select reset package'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: ListView.builder(
            itemCount: resetPlans.length,
            itemBuilder: (_, i) {
              final plan = resetPlans[i];
              final price = plan.prices['reset'] ?? 0;
              return ListTile(
                title: Text(plan.name),
                subtitle: Text('¥ ${price.toStringAsFixed(2)}'),
                onTap: () => Navigator.of(dialogContext).pop(plan),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(zh ? '取消' : 'Cancel'))],
      ),
    );
    if (picked == null || picked.id == null) return;

    try {
      final api = ref.read(v2etPortalApiProvider);
      final tradeNo = await api.createOrder(session: currentSession, planId: picked.id!, periodField: 'reset_price');
      final price = picked.prices['reset'] ?? 0;
      if (price <= 0) {
        final result = await api.checkoutOrder(session: currentSession, tradeNo: tradeNo);
        if (result.type == -1 && context.mounted) {
          showV2etNotice(context, zh ? '重置流量成功' : 'Traffic reset successfully');
        }
        return;
      }

      final methods = await api.fetchPaymentMethods(currentSession);
      if (methods.isEmpty) {
        if (context.mounted) {
          showV2etNotice(context, zh ? '暂无可用支付方式' : 'No payment method available', error: true);
        }
        return;
      }
      final method = await showDialog<V2etPaymentMethod>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(zh ? '选择支付方式' : 'Select payment method'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in methods) ListTile(title: Text(m.name), onTap: () => Navigator.of(dialogContext).pop(m)),
              ],
            ),
          ),
        ),
      );
      if (method == null) return;
      final checkout = await api.checkoutOrder(session: currentSession, tradeNo: tradeNo, paymentMethodId: method.id);
      if (checkout.type == -1) {
        if (context.mounted) showV2etNotice(context, zh ? '重置流量成功' : 'Traffic reset successfully');
        return;
      }
      final uri = _resolveCheckoutUri(checkout.data);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          showV2etNotice(context, zh ? '已打开支付页面，完成后可返回客户端' : 'Payment page opened, return after completion');
        }
      }
    } catch (e) {
      if (context.mounted) showV2etNotice(context, (zh ? '下单失败: ' : 'Checkout failed: ') + e.toString(), error: true);
    }
  }

  Uri? _resolveCheckoutUri(String data) {
    final raw = data.trim();
    if (raw.isEmpty) return null;
    final direct = Uri.tryParse(raw);
    if (direct != null && direct.hasScheme) return direct;
    final qrData = Uri.encodeComponent(raw);
    return Uri.parse('https://api.qrserver.com/v1/create-qr-code/?size=360x360&data=$qrData');
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
