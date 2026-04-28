import 'dart:convert';
import 'dart:math';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? buildV2etSupportUri(V2etRuntimeConfig? config) {
  if (config == null) return null;

  final provider = _normalizeProvider(config.supportProvider);
  final crispId = (config.crispWebsiteId ?? '').trim();
  final tawkPropertyId = (config.tawktoPropertyId ?? '').trim();
  final tawkWidgetId = (config.tawktoWidgetId ?? '').trim();
  final chatwayWidgetId = (config.chatwayWidgetId ?? '').trim();

  if (provider == 'crisp' && crispId.isNotEmpty) {
    return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
  }
  if ((provider == 'tawkto' || provider == 'tawk') && tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
    return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
  }
  if (provider == 'chatway' && chatwayWidgetId.isNotEmpty) {
    return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
  }

  final direct = _parseUri(config.supportUrl);
  if (direct != null) {
    return direct;
  }

  final supportPayload = (config.supportUrl ?? '').trim();
  final payloadUri = _buildEmbedFromRaw(supportPayload);
  if (payloadUri != null) {
    return payloadUri;
  }

  if (crispId.isNotEmpty) {
    return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
  }
  if (tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
    return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
  }
  if (chatwayWidgetId.isNotEmpty) {
    return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
  }

  final scriptUrl = (config.supportScriptUrl ?? '').trim();
  final embedHtml = (config.supportEmbedHtml ?? '').trim();
  if (embedHtml.isNotEmpty) {
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(embedHtml)}');
  }
  final scriptPayloadUri = _buildEmbedFromRaw(scriptUrl);
  if (scriptPayloadUri != null) {
    return scriptPayloadUri;
  }
  if (scriptUrl.isNotEmpty) {
    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>V2ET Support</title>
</head>
<body>
  <script src="$scriptUrl"></script>
</body>
</html>
''';
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');
  }

  return null;
}

Future<bool> openV2etSupport(
  BuildContext context,
  Uri uri, {
  String title = 'Support',
}) async {
  final url = uri.toString().trim();
  if (url.isEmpty) return false;

  final isDesktop =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (isDesktop) {
    final available = await WebviewWindow.isWebviewAvailable();
    if (available) {
      final viewport = MediaQuery.sizeOf(context);
      final maxWidth = viewport.width > 0 ? viewport.width : 1280;
      final maxHeight = viewport.height > 0 ? viewport.height : 720;
      final windowWidth = min(380, maxWidth.round());
      final windowHeight = min(518, maxHeight.round());
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: title,
          titleBarTopPadding: 8,
          windowWidth: windowWidth,
          windowHeight: windowHeight,
        ),
      );
      webview.launch(url);
      return true;
    }
  }

  var opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
  if (!opened) {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return opened;
}

Uri? _parseUri(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return null;
  return uri;
}

Uri? _buildEmbedFromRaw(String raw) {
  if (raw.isEmpty) return null;

  final asUri = _parseUri(raw);
  if (asUri != null) {
    return asUri;
  }

  if (raw.startsWith('{') && raw.endsWith('}')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry(k.toString(), v));
        final direct = _parseUri(map['url']?.toString());
        if (direct != null) return direct;
        final tawkPropertyId =
            map['tawkto_property_id']?.toString().trim() ??
            map['tawk_property_id']?.toString().trim() ??
            map['tawktoPropertyId']?.toString().trim() ??
            '';
        final tawkWidgetId =
            map['tawkto_widget_id']?.toString().trim() ??
            map['tawk_widget_id']?.toString().trim() ??
            map['tawktoWidgetId']?.toString().trim() ??
            '';
        if (tawkPropertyId.isNotEmpty && tawkWidgetId.isNotEmpty) {
          return Uri.parse('https://tawk.to/chat/$tawkPropertyId/$tawkWidgetId');
        }
        final chatwayWidgetId =
            map['chatway_widget_id']?.toString().trim() ?? map['chatwayWidgetId']?.toString().trim() ?? '';
        if (chatwayWidgetId.isNotEmpty) {
          return Uri.parse('https://go.chatway.app/chat/$chatwayWidgetId');
        }
        final crispId =
            map['crisp_website_id']?.toString().trim() ??
            map['crispid']?.toString().trim() ??
            map['website_id']?.toString().trim() ??
            '';
        if (crispId.isNotEmpty) {
          return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
        }
        final scriptUrl = map['script_url']?.toString().trim() ?? '';
        if (scriptUrl.isNotEmpty) {
          return _buildEmbedFromRaw(scriptUrl);
        }
        final embedHtml = map['embed_html']?.toString().trim() ?? '';
        if (embedHtml.isNotEmpty) {
          return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(embedHtml)}');
        }
      }
    } catch (_) {}
  }

  final lower = raw.toLowerCase();
  if (lower.contains('<html') || lower.contains('<script') || lower.contains('<iframe')) {
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(raw)}');
  }

  if (lower.endsWith('.js') && (lower.startsWith('http://') || lower.startsWith('https://'))) {
    final html =
        '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>V2ET Support</title>
</head>
<body>
  <script src="$raw"></script>
</body>
</html>
''';
    return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');
  }

  return null;
}

String _normalizeProvider(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty) return '';
  if (value.contains('crisp')) return 'crisp';
  if (value.contains('tawk')) return 'tawkto';
  if (value.contains('chatway')) return 'chatway';
  return value;
}
