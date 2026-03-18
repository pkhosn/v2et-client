import 'package:dio/dio.dart';
import 'package:hiddify/v2et/config/v2et_bootstrap_config.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class V2etRuntimeConfig {
  const V2etRuntimeConfig({
    required this.enableNoticePopup,
    required this.primaryColorHex,
    required this.surfaceColorHex,
    required this.crispWebsiteId,
    required this.banners,
    required this.builtinProxyEnabled,
    required this.allowCustomPort,
    required this.defaultPort,
  });

  final bool enableNoticePopup;
  final String? primaryColorHex;
  final String? surfaceColorHex;
  final String? crispWebsiteId;
  final List<V2etRuntimeBanner> banners;
  final bool builtinProxyEnabled;
  final bool allowCustomPort;
  final int? defaultPort;
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
      options: Options(
        headers: const {'Accept': 'application/json,text/plain,*/*'},
        responseType: ResponseType.json,
      ),
    );

    final map = _asMap(response.data);
    if (map == null) {
      return const V2etRuntimeConfig(
        enableNoticePopup: true,
        primaryColorHex: null,
        surfaceColorHex: null,
        crispWebsiteId: null,
        banners: [],
        builtinProxyEnabled: false,
        allowCustomPort: true,
        defaultPort: null,
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

    final primaryColor = _readStringByPaths(map, const [
      'theme.primary',
      'v2et.theme.primary',
      'colors.primary',
    ]);
    final surfaceColor = _readStringByPaths(map, const [
      'theme.surface',
      'v2et.theme.surface',
      'colors.surface',
    ]);
    final crispId = _readStringByPaths(map, const [
      'crisp.website_id',
      'features.crisp.website_id',
      'v2et.crisp.website_id',
    ]);
    final builtinProxyEnabled = _readBoolByPaths(map, const [
          'builtin_proxy.enabled',
          'features.builtin_proxy.enabled',
          'v2et.builtin_proxy.enabled',
        ]) ??
        false;
    final allowCustomPort = _readBoolByPaths(map, const [
          'ports.allow_custom',
          'features.ports.allow_custom',
          'v2et.ports.allow_custom',
        ]) ??
        true;
    final defaultPort = _readIntByPaths(map, const [
      'ports.default',
      'features.ports.default',
      'v2et.ports.default',
    ]);

    return V2etRuntimeConfig(
      enableNoticePopup: enabled ?? true,
      primaryColorHex: primaryColor,
      surfaceColorHex: surfaceColor,
      crispWebsiteId: crispId,
      banners: _readBanners(map),
      builtinProxyEnabled: builtinProxyEnabled,
      allowCustomPort: allowCustomPort,
      defaultPort: defaultPort,
    );
  } catch (_) {
    return const V2etRuntimeConfig(
      enableNoticePopup: true,
      primaryColorHex: null,
      surfaceColorHex: null,
      crispWebsiteId: null,
      banners: [],
      builtinProxyEnabled: false,
      allowCustomPort: true,
      defaultPort: null,
    );
  }
});

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
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
  final candidates = [
    _readPath(map, 'banners'),
    _readPath(map, 'features.banners'),
    _readPath(map, 'v2et.banners'),
  ];
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
