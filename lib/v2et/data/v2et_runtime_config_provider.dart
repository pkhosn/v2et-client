import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hiddify/v2et/config/v2et_bootstrap_config.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etRuntimeConfig {
  const V2etRuntimeConfig({
    required this.enableNoticePopup,
    required this.primaryColorHex,
    required this.surfaceColorHex,
    required this.crispWebsiteId,
    required this.tawktoPropertyId,
    required this.tawktoWidgetId,
    required this.chatwayWidgetId,
    required this.banners,
    required this.builtinProxyEnabled,
    required this.allowCustomPort,
    required this.defaultPort,
    required this.officialSiteUrl,
    required this.groupUrl,
    required this.inviteManageUrl,
    required this.giftCardHelpUrl,
    required this.supportProvider,
    required this.supportUrl,
    required this.supportScriptUrl,
    required this.supportEmbedHtml,
    required this.expiryWarnDays,
    required this.trafficWarnBytes,
  });

  final bool enableNoticePopup;
  final String? primaryColorHex;
  final String? surfaceColorHex;
  final String? crispWebsiteId;
  final String? tawktoPropertyId;
  final String? tawktoWidgetId;
  final String? chatwayWidgetId;
  final List<V2etRuntimeBanner> banners;
  final bool builtinProxyEnabled;
  final bool allowCustomPort;
  final int? defaultPort;
  final String? officialSiteUrl;
  final String? groupUrl;
  final String? inviteManageUrl;
  final String? giftCardHelpUrl;
  final String? supportProvider;
  final String? supportUrl;
  final String? supportScriptUrl;
  final String? supportEmbedHtml;
  final int expiryWarnDays;
  final int trafficWarnBytes;
}

class V2etRuntimeBanner {
  const V2etRuntimeBanner({required this.title, required this.imageUrl, this.targetUrl});

  final String title;
  final String imageUrl;
  final String? targetUrl;
}

final v2etRuntimeConfigProvider = FutureProvider<V2etRuntimeConfig>((ref) async {
  final dio = Dio();
  try {
    final response = await dio.getUri<Object?>(
      Uri.parse(V2etBootstrapConfig.defaultConfigUrl),
      options: Options(headers: const {'Accept': 'application/json,text/plain,*/*'}, responseType: ResponseType.json),
    );

    final map = _asMap(response.data);
    if (map == null) {
      return const V2etRuntimeConfig(
        enableNoticePopup: true,
        primaryColorHex: null,
        surfaceColorHex: null,
        crispWebsiteId: null,
        tawktoPropertyId: null,
        tawktoWidgetId: null,
        chatwayWidgetId: null,
        banners: [],
        builtinProxyEnabled: false,
        allowCustomPort: true,
        defaultPort: null,
        officialSiteUrl: null,
        groupUrl: null,
        inviteManageUrl: null,
        giftCardHelpUrl: null,
        supportProvider: null,
        supportUrl: null,
        supportScriptUrl: null,
        supportEmbedHtml: null,
        expiryWarnDays: 3,
        trafficWarnBytes: 3 * 1024 * 1024 * 1024,
      );
    }

    final enabled = _readBoolByPaths(map, const [
      'features.notice_popup',
      'features.show_notice_popup',
      'features.announcement_popup',
      'announcement.popup_enabled',
      'notice.popup_enabled',
      'show_notice_popup',
      'notice_popup_enabled',
      'v2et.show_notice_popup',
    ]);

    final primaryColor = _readStringByPaths(map, const ['theme.primary', 'v2et.theme.primary', 'colors.primary']);
    final surfaceColor = _readStringByPaths(map, const ['theme.surface', 'v2et.theme.surface', 'colors.surface']);
    final crispId = _readStringByPaths(map, const [
      'crisp.website_id',
      'crisp.id',
      'crispid',
      'crisp_id',
      'crisp.websiteId',
      'support.crisp_id',
      'features.crisp.website_id',
      'features.crispid',
      'features.crisp_id',
      'v2et.crisp.website_id',
      'v2et.crispid',
      'v2et.crisp_id',
    ]);
    final tawktoPropertyId = _readStringByPaths(map, const [
      'support.tawkto_property_id',
      'support.tawk_property_id',
      'support.tawktoPropertyId',
      'support.tawkPropertyId',
      'tawkto.property_id',
      'tawk.property_id',
      'features.support.tawkto_property_id',
      'v2et.support.tawkto_property_id',
    ]);
    final tawktoWidgetId = _readStringByPaths(map, const [
      'support.tawkto_widget_id',
      'support.tawk_widget_id',
      'support.tawktoWidgetId',
      'support.tawkWidgetId',
      'tawkto.widget_id',
      'tawk.widget_id',
      'features.support.tawkto_widget_id',
      'v2et.support.tawkto_widget_id',
    ]);
    final chatwayWidgetId = _readStringByPaths(map, const [
      'support.chatway_widget_id',
      'support.chatwayWidgetId',
      'chatway.widget_id',
      'features.support.chatway_widget_id',
      'v2et.support.chatway_widget_id',
    ]);
    final builtinProxyEnabled =
        _readBoolByPaths(map, const [
          'builtin_proxy.enabled',
          'features.builtin_proxy.enabled',
          'v2et.builtin_proxy.enabled',
        ]) ??
        false;
    final allowCustomPort =
        _readBoolByPaths(map, const ['ports.allow_custom', 'features.ports.allow_custom', 'v2et.ports.allow_custom']) ??
        true;
    final defaultPort = _readIntByPaths(map, const ['ports.default', 'features.ports.default', 'v2et.ports.default']);

    final officialSiteUrl = _readStringByPaths(map, const [
      'links.official_site',
      'links.official_website',
      'official_site',
      'official_website',
    ]);
    final groupUrl = _readStringByPaths(map, const ['links.group', 'links.join_group', 'join_group']);
    final inviteManageUrl = _readStringByPaths(map, const ['links.invite_manage', 'links.invite', 'invite_manage_url']);
    final giftCardHelpUrl = _readStringByPaths(map, const [
      'links.gift_card_help',
      'links.gift_card',
      'gift_card_help_url',
    ]);
    final supportProvider = _readStringByPaths(map, const [
      'support.provider',
      'features.support.provider',
      'v2et.support.provider',
    ]);
    final supportUrl = _readStringByPaths(map, const [
      'support.url',
      'features.support.url',
      'v2et.support.url',
      'links.support',
      'links.customer_service',
      'customer_service_url',
    ]);
    final supportScriptUrl = _readStringByPaths(map, const [
      'support.script_url',
      'features.support.script_url',
      'v2et.support.script_url',
      'support.js_url',
    ]);
    final supportEmbedHtml = _readStringByPaths(map, const [
      'support.embed_html',
      'features.support.embed_html',
      'v2et.support.embed_html',
      'support.html',
    ]);
    final expiryWarnDays =
        _readIntByPaths(map, const [
          'alerts.expiry_warn_days',
          'alerts.expire_warn_days',
          'alerts.expire_days',
          'features.alerts.expiry_warn_days',
          'v2et.alerts.expiry_warn_days',
        ]) ??
        3;
    final trafficWarnBytes =
        _readIntByPaths(map, const [
          'alerts.traffic_warn_bytes',
          'alerts.remaining_traffic_bytes',
          'features.alerts.traffic_warn_bytes',
          'v2et.alerts.traffic_warn_bytes',
        ]) ??
        _readTrafficWarnBytesByGb(map) ??
        (3 * 1024 * 1024 * 1024);

    return V2etRuntimeConfig(
      enableNoticePopup: enabled ?? true,
      primaryColorHex: primaryColor,
      surfaceColorHex: surfaceColor,
      crispWebsiteId: crispId,
      tawktoPropertyId: tawktoPropertyId,
      tawktoWidgetId: tawktoWidgetId,
      chatwayWidgetId: chatwayWidgetId,
      banners: _readBanners(map),
      builtinProxyEnabled: builtinProxyEnabled,
      allowCustomPort: allowCustomPort,
      defaultPort: defaultPort,
      officialSiteUrl: officialSiteUrl,
      groupUrl: groupUrl,
      inviteManageUrl: inviteManageUrl,
      giftCardHelpUrl: giftCardHelpUrl,
      supportProvider: supportProvider,
      supportUrl: supportUrl,
      supportScriptUrl: supportScriptUrl,
      supportEmbedHtml: supportEmbedHtml,
      expiryWarnDays: expiryWarnDays,
      trafficWarnBytes: trafficWarnBytes,
    );
  } catch (_) {
    return const V2etRuntimeConfig(
      enableNoticePopup: true,
      primaryColorHex: null,
      surfaceColorHex: null,
      crispWebsiteId: null,
      tawktoPropertyId: null,
      tawktoWidgetId: null,
      chatwayWidgetId: null,
      banners: [],
      builtinProxyEnabled: false,
      allowCustomPort: true,
      defaultPort: null,
      officialSiteUrl: null,
      groupUrl: null,
      inviteManageUrl: null,
      giftCardHelpUrl: null,
      supportProvider: null,
      supportUrl: null,
      supportScriptUrl: null,
      supportEmbedHtml: null,
      expiryWarnDays: 3,
      trafficWarnBytes: 3 * 1024 * 1024 * 1024,
    );
  }
});

int? _readTrafficWarnBytesByGb(Map<String, dynamic> root) {
  final value = _readPathByPaths(root, const [
    'alerts.traffic_warn_gb',
    'alerts.remaining_traffic_gb',
    'features.alerts.traffic_warn_gb',
    'v2et.alerts.traffic_warn_gb',
  ]);
  if (value is num) {
    return (value * 1024 * 1024 * 1024).toInt();
  }
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    if (parsed != null) {
      return (parsed * 1024 * 1024 * 1024).toInt();
    }
  }
  return null;
}

Object? _readPathByPaths(Map<String, dynamic> root, List<String> paths) {
  for (final path in paths) {
    final value = _readPath(root, path);
    if (value != null) return value;
  }
  return null;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }
  }
  if (value is List<int>) {
    try {
      final text = utf8.decode(value, allowMalformed: true);
      return _asMap(text);
    } catch (_) {
      return null;
    }
  }
  return null;
}

bool? _readBoolByPaths(Map<String, dynamic> root, List<String> paths) {
  for (final path in paths) {
    final found = _readBoolPath(root, path);
    if (found != null) return found;
  }
  return null;
}

bool? _readBoolPath(Map<String, dynamic> root, String path) {
  final parts = path.split('.');
  Object? current = root;
  for (final part in parts) {
    if (current is! Map) return null;
    final map = current.map((k, v) => MapEntry(k.toString(), v));
    if (!map.containsKey(part)) return null;
    current = map[part];
  }
  if (current is bool) return current;
  if (current is num) return current != 0;
  if (current is String) {
    final n = current.trim().toLowerCase();
    if (n == 'true' || n == '1' || n == 'yes' || n == 'on') return true;
    if (n == 'false' || n == '0' || n == 'no' || n == 'off') return false;
  }
  return null;
}

String? _readStringByPaths(Map<String, dynamic> root, List<String> paths) {
  for (final path in paths) {
    final found = _readStringPath(root, path);
    if (found != null) return found;
  }
  return null;
}

String? _readStringPath(Map<String, dynamic> root, String path) {
  final value = _readPath(root, path);
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

int? _readIntByPaths(Map<String, dynamic> root, List<String> paths) {
  for (final path in paths) {
    final found = _readIntPath(root, path);
    if (found != null) return found;
  }
  return null;
}

int? _readIntPath(Map<String, dynamic> root, String path) {
  final value = _readPath(root, path);
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

Object? _readPath(Map<String, dynamic> root, String path) {
  final parts = path.split('.');
  Object? current = root;
  for (final part in parts) {
    if (current is! Map) return null;
    final map = current.map((k, v) => MapEntry(k.toString(), v));
    if (!map.containsKey(part)) return null;
    current = map[part];
  }
  return current;
}

List<V2etRuntimeBanner> _readBanners(Map<String, dynamic> map) {
  final candidates = [_readPath(map, 'banners'), _readPath(map, 'features.banners'), _readPath(map, 'v2et.banners')];
  for (final candidate in candidates) {
    if (candidate is! List) continue;
    final items = <V2etRuntimeBanner>[];
    for (final raw in candidate) {
      if (raw is! Map) continue;
      final m = raw.map((k, v) => MapEntry(k.toString(), v));
      final image = (m['imageUrl'] ?? m['image_url'] ?? m['image'])?.toString().trim();
      if (image == null || image.isEmpty) continue;
      final title = (m['title']?.toString().trim().isNotEmpty ?? false) ? m['title'].toString().trim() : 'Banner';
      final target = m['targetUrl'] ?? m['target_url'] ?? m['link'] ?? m['url'];
      final targetUrl = target?.toString().trim();
      items.add(
        V2etRuntimeBanner(
          title: title,
          imageUrl: image,
          targetUrl: (targetUrl == null || targetUrl.isEmpty) ? null : targetUrl,
        ),
      );
    }
    if (items.isNotEmpty) return items;
  }
  return const [];
}
