import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_provider.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
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
    final noticeTrigger = ref.watch(v2etNoticeDialogTriggerProvider);
    final sub = ref.watch(v2etRepositoryProvider).readLastSubscription();
    final offers = ref.watch(v2etStoreOffersProvider).valueOrNull ?? const <V2etStoreOffer>[];
    final serviceMode = ref.watch(ConfigOptions.serviceMode);
    final selectedNode = useState<String?>(null);
    final noticeShown = useState(false);
    final statusNotifiedKey = useState<String?>(null);
    final linkOverrides = useState<Map<String, int?>>({});
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

    useEffect(() {
      if (guard == _UsageGuard.ok && !warnExpirySoon && !warnTrafficSoon) {
        return null;
      }
      unawaited(_syncSubscriptionAndProfile(ref));
      final timer = Timer.periodic(const Duration(seconds: 20), (_) {
        unawaited(_syncSubscriptionAndProfile(ref));
      });
      return timer.cancel;
    }, [guard, warnExpirySoon, warnTrafficSoon]);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2F8),
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
                      _ConnectionHero(
                        compact: compact,
                        button: _PowerButton(
                          enabled: connectEnabled,
                          active: isConnected,
                          onTap: () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
                        ),
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
                            final meta = await _readNodeMeta(ref, activeProfile);
                            var tags = meta.tags;
                            var nodeTargets = meta.targets;
                            if (!context.mounted) return;
                            if (tags.isEmpty && guard == _UsageGuard.ok) {
                              await _syncSubscriptionAndProfile(ref);
                              final refreshedMeta = await _readNodeMeta(ref, activeProfile);
                              tags = refreshedMeta.tags;
                              nodeTargets = refreshedMeta.targets;
                            }
                            if (tags.isEmpty && guard == _UsageGuard.ok) {
                              showV2etNotice(
                                context,
                                tr('当前账号暂无有效套餐，请先购买套餐', 'No active plan found. Please purchase a plan first.'),
                                error: true,
                              );
                              return;
                            }
                            final picked = await showDialog<String>(
                              context: context,
                              barrierDismissible: true,
                              builder: (ctx) {
                                final isMobileSheet = MediaQuery.of(ctx).size.width < 700;
                                final maxWidth = isMobileSheet ? MediaQuery.of(ctx).size.width : 860.0;
                                final estimatedRows = tags.length + 2;
                                final estimatedHeight = 122.0 + (estimatedRows * 56.0);
                                final maxAllowed = isMobileSheet
                                    ? MediaQuery.of(ctx).size.height * 0.9
                                    : MediaQuery.of(ctx).size.height * 0.86;
                                final sheetHeight = estimatedHeight.clamp(430.0, maxAllowed);
                                return Dialog(
                                  backgroundColor: const Color(0xFFF5F2F8),
                                  insetPadding: EdgeInsets.symmetric(
                                    horizontal: isMobileSheet ? 12 : 120,
                                    vertical: isMobileSheet ? 64 : 66,
                                  ),
                                  child: Consumer(
                                    builder: (context, sheetRef, _) {
                                      final group = sheetRef.watch(proxiesOverviewNotifierProvider).valueOrNull;
                                      final modalLink = <String, int?>{...linkOverrides.value};
                                      final modalLinkLoading = <String>{...linkLoading.value};
                                      return StatefulBuilder(
                                        builder: (context, setModalState) {
                                          final entries = _buildNodeEntries(
                                            tags,
                                            group,
                                            linkOverrides: modalLink,
                                            zh: zh,
                                          );
                                          return ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: maxWidth),
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
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
                                                        IconButton(
                                                          tooltip: tr('刷新线路', 'Refresh routes'),
                                                          onPressed: () {
                                                            modalLink.clear();
                                                            modalLinkLoading.clear();
                                                            linkOverrides.value = {};
                                                            linkLoading.value = {};
                                                            sheetRef.invalidate(proxiesOverviewNotifierProvider);
                                                            setModalState(() {});
                                                            showV2etNotice(
                                                              context,
                                                              tr('线路列表已刷新', 'Routes refreshed'),
                                                              duration: const Duration(seconds: 1),
                                                            );
                                                          },
                                                          icon: const Icon(Icons.refresh_rounded, size: 20),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
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
                                                                      if (selectedNode.value == item.selectTag) ...[
                                                                        const Icon(
                                                                          Icons.check_rounded,
                                                                          color: Color(0xFF5A3D89),
                                                                          size: 20,
                                                                        ),
                                                                        const SizedBox(width: 8),
                                                                      ],
                                                                      _LatencyAction(
                                                                        icon: Icons.bolt_rounded,
                                                                        loading: linkBusy,
                                                                        valueMs: item.linkMs,
                                                                        timeoutText: tr('超时', 'timeout'),
                                                                        unavailableText: tr('需连接', 'connect first'),
                                                                        onTap: () async {
                                                                          modalLinkLoading.add(item.id);
                                                                          setModalState(() {});
                                                                          try {
                                                                            final tested = await _runLightningProbe(
                                                                              sheetRef,
                                                                              item: item,
                                                                              nodeTargets: nodeTargets,
                                                                              currentGroup: group,
                                                                            );
                                                                            modalLink[item.id] = tested ?? 65535;
                                                                            linkOverrides.value = {...modalLink};
                                                                          } finally {
                                                                            modalLinkLoading.remove(item.id);
                                                                            linkLoading.value = {...modalLinkLoading};
                                                                            setModalState(() {});
                                                                          }
                                                                        },
                                                                      ),
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
                                          );
                                        },
                                      );
                                    },
                                  ),
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
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? 360 : 420),
                        child: _Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Row(
                              children: [
                                for (final key in const ['smart', 'global', 'tun']) ...[
                                  Expanded(
                                    child: _ModeChip(
                                      label: switch (key) {
                                        'smart' => tr('智能', 'Smart'),
                                        'global' => tr('全局', 'Global'),
                                        _ => 'TUN',
                                      },
                                      selected: _serviceModeKey(serviceMode) == key,
                                      onTap: () async {
                                        await ref
                                            .read(ConfigOptions.serviceMode.notifier)
                                            .update(_serviceModeFromKey(key));
                                      },
                                    ),
                                  ),
                                  if (key != 'tun') const SizedBox(width: 8),
                                ],
                              ],
                            ),
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

  String _serviceModeKey(ServiceMode mode) {
    if (mode == ServiceMode.tun) return 'tun';
    if (mode == ServiceMode.proxy) return 'global';
    return 'smart';
  }

  ServiceMode _serviceModeFromKey(String key) {
    return switch (key) {
      'tun' => ServiceMode.tun,
      'global' => ServiceMode.proxy,
      _ => Platform.isDesktop ? ServiceMode.systemProxy : ServiceMode.proxy,
    };
  }

  Future<void> _syncSubscriptionAndProfile(WidgetRef ref) async {
    try {
      final repo = ref.read(v2etRepositoryProvider);
      final session = await repo.restoreSession();
      if (session == null || !session.hasToken) {
        return;
      }
      await repo.warmup();
      final sub = repo.readLastSubscription();
      final nodeCount = sub?.nodeCount;
      final transferEnableBytes = sub?.transferEnableBytes;
      final noPlan = (nodeCount != null && nodeCount <= 0) || (transferEnableBytes != null && transferEnableBytes <= 0);
      final url = sub?.subscriptionUrl.toString().trim();
      if (!noPlan && url != null && url.isNotEmpty) {
        await ref.read(addProfileNotifierProvider.notifier).addClipboard(url).catchError((_) {});
      }
      ref.invalidate(v2etSessionProvider);
      ref.invalidate(v2etStoreOffersProvider);
      ref.invalidate(v2etCountersProvider);
      ref.invalidate(v2etNoticesProvider);
    } catch (_) {}
  }

  Future<_NodeMeta> _readNodeMeta(WidgetRef ref, ProfileEntity? activeProfile) async {
    if (activeProfile == null) return const _NodeMeta(tags: [], targets: {});
    final repo = await ref.read(profileRepositoryProvider.future);
    final result = await repo.getRawConfig(activeProfile.id).run();
    return result.match((_) => const _NodeMeta(tags: [], targets: {}), _extractNodeMeta);
  }

  _NodeMeta _extractNodeMeta(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return const _NodeMeta(tags: [], targets: {});
      final outbounds = data['outbounds'];
      if (outbounds is! List) return const _NodeMeta(tags: [], targets: {});
      const ignoredTypes = {'selector', 'urltest', 'direct', 'block', 'dns'};
      final tags = <String>[];
      final targets = <String, _NodeTarget>{};
      for (final item in outbounds) {
        if (item is! Map) continue;
        final type = item['type']?.toString().toLowerCase() ?? '';
        final tag = item['tag']?.toString().trim() ?? '';
        if (tag.isEmpty || ignoredTypes.contains(type)) continue;
        tags.add(tag);

        String? host = item['server']?.toString().trim();
        int? port = _parsePort(item['server_port']) ?? _parsePort(item['port']);
        final peer = item['peer']?.toString().trim();
        host ??= item['address']?.toString().trim();
        if ((host == null || host.isEmpty) && item['server'] != null) {
          final serverText = item['server'].toString().trim();
          final idx = serverText.lastIndexOf(':');
          if (idx > 0 && idx < serverText.length - 1) {
            host = serverText.substring(0, idx);
            port ??= _parsePort(serverText.substring(idx + 1));
          }
        }
        if ((host == null || host.isEmpty) && peer != null && peer.isNotEmpty) {
          final peerText = peer.trim();
          final ipv6 = RegExp(r'^\[(.*)\]:(\d+)$').firstMatch(peerText);
          if (ipv6 != null) {
            host = ipv6.group(1);
            port ??= _parsePort(ipv6.group(2));
          } else {
            final idx = peerText.lastIndexOf(':');
            if (idx > 0 && idx < peerText.length - 1) {
              host = peerText.substring(0, idx);
              port ??= _parsePort(peerText.substring(idx + 1));
            } else {
              host = peerText;
            }
          }
        }
        if (host != null && host.contains(':') && !host.contains(']') && port == null) {
          final idx = host.lastIndexOf(':');
          if (idx > 0 && idx < host.length - 1) {
            port = _parsePort(host.substring(idx + 1));
            host = host.substring(0, idx);
          }
        }
        if (host != null && host.isNotEmpty && port != null && port > 0 && port <= 65535) {
          targets[tag] = _NodeTarget(host: host, port: port, protocol: type);
        }
      }
      return _NodeMeta(tags: tags.toSet().toList(), targets: targets);
    } catch (_) {
      return const _NodeMeta(tags: [], targets: {});
    }
  }

  int? _parsePort(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Future<int?> _runLinkProbe(
    WidgetRef ref, {
    required String groupTag,
    required String outboundTag,
    required String? restoreTag,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final repo = ref.read(proxyRepositoryProvider);
    bool canProbe = false;
    try {
      final selected = await repo.selectProxy(groupTag, outboundTag).run().timeout(const Duration(seconds: 4));
      canProbe = selected.match((_) => false, (_) => true);
    } catch (_) {
      canProbe = false;
    }
    if (!canProbe) {
      return 65535;
    }

    final timer = Stopwatch()..start();
    try {
      final res = await repo.getCurrentIpInfo(CancelToken()).run().timeout(timeout);
      final ms = res.match((_) => 65535, (_) => timer.elapsedMilliseconds);
      return ms > 0 ? ms : 65535;
    } catch (_) {
      return 65535;
    } finally {
      timer.stop();
      if (restoreTag != null && restoreTag.isNotEmpty && restoreTag != outboundTag) {
        try {
          await repo.selectProxy(groupTag, restoreTag).run().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
  }

  List<_NodeEntry> _buildNodeEntries(
    List<String> tags,
    dynamic proxyGroup, {
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
          linkMs: linkOverrides[tag],
          isSpecial: false,
        );
      }),
    );
    return entries;
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

  Future<int?> _runTcpProbe(_NodeTarget target, {Duration timeout = const Duration(milliseconds: 4500)}) async {
    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(target.host, target.port, timeout: timeout).timeout(timeout);
      return watch.elapsedMilliseconds;
    } catch (_) {
      return 65535;
    } finally {
      watch.stop();
      await socket?.close();
    }
  }

  Future<int?> _runOfflineTargetProbe(_NodeTarget target) {
    if (target.protocol == 'tuic') {
      return Future<int?>.value(65535);
    }
    if (target.protocol == 'hysteria' || target.protocol == 'hysteria2') {
      return _runTcpProbe(target, timeout: const Duration(milliseconds: 1800));
    }
    if (target.tcpProbeAllowed) {
      return _runTcpProbe(target, timeout: const Duration(milliseconds: 2200));
    }
    return _runTcpProbe(target, timeout: const Duration(milliseconds: 1800));
  }

  Future<int?> _runLightningProbe(
    WidgetRef ref, {
    required _NodeEntry item,
    required Map<String, _NodeTarget> nodeTargets,
    required dynamic currentGroup,
  }) async {
    final connected = ref.read(connectionNotifierProvider).valueOrNull == const Connected();
    final groupTag = _readGroupTag(currentGroup) ?? 'select';
    final restoreTag = _readSelectedTag(currentGroup);

    if (item.isSpecial) {
      if (!connected) {
        return _runSpecialModeProbe(item, nodeTargets, currentSelectedTag: restoreTag);
      }
      final linkProbe = await _runLinkProbe(
        ref,
        groupTag: groupTag,
        outboundTag: item.selectTag,
        restoreTag: restoreTag,
        timeout: connected ? const Duration(seconds: 8) : const Duration(seconds: 15),
      );
      if (linkProbe != null && linkProbe > 0 && linkProbe < 65535) {
        return linkProbe;
      }
      return _runSpecialModeProbe(item, nodeTargets, currentSelectedTag: restoreTag);
    }

    final directTarget = nodeTargets[item.testTag];

    if (!connected) {
      if (directTarget == null) {
        return 65535;
      }
      if (directTarget.protocol == 'tuic') {
        final realProbe = await _runLinkProbe(
          ref,
          groupTag: groupTag,
          outboundTag: item.selectTag,
          restoreTag: restoreTag,
          timeout: const Duration(seconds: 6),
        );
        return realProbe;
      }
      return _runOfflineTargetProbe(directTarget);
    }

    final probeTimeout = (directTarget != null && !directTarget.tcpProbeAllowed)
        ? const Duration(seconds: 15)
        : const Duration(seconds: 8);
    final linkProbe = await _runLinkProbe(
      ref,
      groupTag: groupTag,
      outboundTag: item.selectTag,
      restoreTag: restoreTag,
      timeout: probeTimeout,
    );
    if (linkProbe != null && linkProbe > 0 && linkProbe < 65535) {
      return linkProbe;
    }

    if (directTarget != null && directTarget.tcpProbeAllowed) {
      return _runTcpProbe(directTarget);
    }
    return 65535;
  }

  Future<int?> _runSpecialModeProbe(
    _NodeEntry item,
    Map<String, _NodeTarget> nodeTargets, {
    String? currentSelectedTag,
  }) async {
    if (nodeTargets.isEmpty) return 65535;

    if (item.id == '__failover__' && currentSelectedTag != null && currentSelectedTag.isNotEmpty) {
      final currentTarget = nodeTargets[currentSelectedTag];
      if (currentTarget != null) {
        final currentMs = await _runTcpProbe(currentTarget);
        if (currentMs != null && currentMs > 0 && currentMs < 65535) {
          return currentMs;
        }
      }
    }

    final candidates = nodeTargets.entries.toList();
    if (candidates.isEmpty) return 65535;
    final cap = min(6, candidates.length);
    final checks = candidates.take(cap).map((e) => _runOfflineTargetProbe(e.value));
    List<int?> results;
    try {
      results = await Future.wait(checks).timeout(const Duration(seconds: 5));
    } catch (_) {
      return 65535;
    }
    final good = results.whereType<int>().where((ms) => ms > 0 && ms < 65535).toList();
    if (good.isEmpty) {
      return 65535;
    }
    good.sort();
    return good.first;
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
      '香港': '🇭🇰',
      'hk': '🇭🇰',
      'japan': '🇯🇵',
      '日本': '🇯🇵',
      'jp': '🇯🇵',
      'singapore': '🇸🇬',
      '新加坡': '🇸🇬',
      'sg': '🇸🇬',
      'usa': '🇺🇸',
      '美国': '🇺🇸',
      'us': '🇺🇸',
      'united states': '🇺🇸',
      'korea': '🇰🇷',
      '韩国': '🇰🇷',
      'kr': '🇰🇷',
      'taiwan': '🇹🇼',
      '台湾': '🇹🇼',
      'tw': '🇹🇼',
      'germany': '🇩🇪',
      '德国': '🇩🇪',
      'de': '🇩🇪',
      'uk': '🇬🇧',
      '英国': '🇬🇧',
      'united kingdom': '🇬🇧',
      'france': '🇫🇷',
      '法国': '🇫🇷',
      'fr': '🇫🇷',
      'canada': '🇨🇦',
      '加拿大': '🇨🇦',
      'ca': '🇨🇦',
    };
    for (final e in entries.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return '🌐';
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? const Color(0xFF5A3D89) : const Color(0xFFD4CEDD)),
          color: selected ? const Color(0xFFECE6F7) : const Color(0xFFF7F4FA),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF4A2E79) : const Color(0xFF585362),
          ),
        ),
      ),
    );
  }
}

class _NodeEntry {
  const _NodeEntry({
    required this.id,
    required this.tag,
    required this.flag,
    required this.selectTag,
    required this.testTag,
    required this.linkMs,
    required this.isSpecial,
  });

  final String id;
  final String tag;
  final String flag;
  final String selectTag;
  final String testTag;
  final int? linkMs;
  final bool isSpecial;
}

class _NodeTarget {
  const _NodeTarget({required this.host, required this.port, required this.protocol});

  final String host;
  final int port;
  final String protocol;

  bool get tcpProbeAllowed {
    return protocol != 'tuic' && protocol != 'hysteria' && protocol != 'hysteria2';
  }
}

class _NodeMeta {
  const _NodeMeta({required this.tags, required this.targets});

  final List<String> tags;
  final Map<String, _NodeTarget> targets;
}

class _LatencyAction extends StatelessWidget {
  const _LatencyAction({
    required this.icon,
    required this.loading,
    required this.valueMs,
    required this.timeoutText,
    required this.unavailableText,
    required this.onTap,
  });

  final IconData icon;
  final bool loading;
  final int? valueMs;
  final String timeoutText;
  final String unavailableText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueMs != null;
    final unavailable = hasValue && valueMs == -2;
    final timedOut = hasValue && (valueMs == null || valueMs == 65535 || valueMs! <= 0);
    final fg = unavailable ? const Color(0xFF8D95A3) : (timedOut ? const Color(0xFFC62828) : const Color(0xFF1976D2));
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
              else if (!hasValue)
                Icon(icon, size: 14, color: fg),
              if (hasValue) ...[
                Text(
                  unavailable ? unavailableText : (timedOut ? timeoutText : '${valueMs}ms'),
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

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.compact, required this.button});

  final bool compact;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 340.0 : 620.0;
    final height = compact ? 190.0 : 240.0;
    final mapScale = compact ? 1.8 : 2.0;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8),
                child: Opacity(
                  opacity: 0.38,
                  child: Transform.scale(
                    scale: mapScale,
                    child: Image.asset(
                      'assets/images/world_map.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
          button,
        ],
      ),
    );
  }
}

class _WorldMapSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFFB8AEC9).withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2;

    final accent = Paint()
      ..color = const Color(0xFFE1DCEA).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;

    Path p(double x, double y) => Path()..moveTo(size.width * x, size.height * y);

    final northAmerica = p(0.06, 0.39)
      ..quadraticBezierTo(size.width * 0.11, size.height * 0.26, size.width * 0.20, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.26, size.height * 0.33, size.width * 0.24, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.47, size.width * 0.11, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.08, size.height * 0.42, size.width * 0.06, size.height * 0.39);

    final southAmerica = p(0.23, 0.50)
      ..quadraticBezierTo(size.width * 0.27, size.height * 0.58, size.width * 0.24, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.21, size.height * 0.76, size.width * 0.18, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.20, size.height * 0.72, size.width * 0.19, size.height * 0.61)
      ..quadraticBezierTo(size.width * 0.18, size.height * 0.55, size.width * 0.23, size.height * 0.50);

    final europeAfrica = p(0.44, 0.33)
      ..quadraticBezierTo(size.width * 0.49, size.height * 0.29, size.width * 0.53, size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.54, size.height * 0.40, size.width * 0.49, size.height * 0.44)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.56, size.width * 0.51, size.height * 0.66)
      ..quadraticBezierTo(size.width * 0.47, size.height * 0.73, size.width * 0.43, size.height * 0.66)
      ..quadraticBezierTo(size.width * 0.41, size.height * 0.54, size.width * 0.42, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.40, size.height * 0.37, size.width * 0.44, size.height * 0.33);

    final asia = p(0.56, 0.36)
      ..quadraticBezierTo(size.width * 0.64, size.height * 0.24, size.width * 0.77, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.34, size.width * 0.86, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.80, size.height * 0.47, size.width * 0.73, size.height * 0.46)
      ..quadraticBezierTo(size.width * 0.66, size.height * 0.50, size.width * 0.61, size.height * 0.46)
      ..quadraticBezierTo(size.width * 0.57, size.height * 0.42, size.width * 0.56, size.height * 0.36);

    final australia = p(0.79, 0.66)
      ..quadraticBezierTo(size.width * 0.84, size.height * 0.62, size.width * 0.89, size.height * 0.66)
      ..quadraticBezierTo(size.width * 0.91, size.height * 0.71, size.width * 0.87, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.76, size.width * 0.79, size.height * 0.70)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.68, size.width * 0.79, size.height * 0.66);

    canvas.drawPath(northAmerica, outline);
    canvas.drawPath(southAmerica, outline);
    canvas.drawPath(europeAfrica, outline);
    canvas.drawPath(asia, outline);
    canvas.drawPath(australia, outline);

    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.03, size.height * 0.19, size.width * 0.95, size.height * 0.62),
      0.3,
      pi - 0.6,
      false,
      accent,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.10, size.height * 0.26, size.width * 0.82, size.height * 0.50),
      0.28,
      pi - 0.56,
      false,
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
