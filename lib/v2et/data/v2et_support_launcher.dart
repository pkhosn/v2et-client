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
  Offset? preferredTopLeft,
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
      final posX = preferredTopLeft?.dx.round() ?? ((maxWidth - windowWidth) / 2).round();
      final posY = preferredTopLeft?.dy.round() ?? ((maxHeight - windowHeight) / 2).round();
      final launchUrl = _buildDesktopBootstrapPage(url).toString();
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: title,
          titleBarTopPadding: 0,
          titleBarHeight: 0,
          windowWidth: windowWidth,
          windowHeight: windowHeight,
          useWindowPositionAndSize: true,
          windowPosX: max(0, posX),
          windowPosY: max(0, posY),
        ),
      );
      webview.launch(launchUrl);
      return true;
    }
  }

  var opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
  if (!opened) {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return opened;
}

Uri _buildDesktopBootstrapPage(String targetUrl) {
  final safeTarget = targetUrl.replaceAll("'", r"\'");
  final html = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <style>
    html, body { margin:0; height:100%; background:transparent; overflow:hidden; font-family: -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif; }
    .shell { position:fixed; inset:0; border-radius:14px; overflow:hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.22); background:#fff; border:1px solid #d7dbe6; }
    .top { height:48px; background:#1e64d8; color:#fff; display:flex; align-items:center; justify-content:space-between; padding:0 12px; font-weight:700; font-size:18px; }
    .title { display:flex; align-items:center; gap:8px; }
    .title .dot1 { width:10px; height:10px; border-radius:999px; background:#fff; opacity:0.92; }
    .actions { display:flex; gap:8px; }
    .btn { width:24px; height:24px; border-radius:999px; border:0; background:rgba(255,255,255,0.18); color:#fff; font-size:14px; cursor:pointer; }
    .body { position:absolute; top:48px; left:0; right:0; bottom:0; background:#fff; }
    #loading { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; color:#1e64d8; gap:10px; background:#fff; z-index:2; }
    .dot { width:24px; height:24px; border-radius:999px; border:3px solid #d6e3fb; border-top-color:#1e64d8; animation:spin 1s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    iframe { border:0; width:100%; height:100%; display:none; background:#fff; }
  </style>
</head>
<body>
  <div class="shell">
    <div class="top">
      <div class="title"><div class="dot1"></div><span>在线客服</span></div>
      <div class="actions">
        <button class="btn" id="refreshBtn" title="刷新">↻</button>
      </div>
    </div>
    <div class="body">
      <div id="loading"><div class="dot"></div><div>正在连接客服...</div></div>
      <iframe id="frame" src="$safeTarget"></iframe>
    </div>
  </div>
  <script>
    const frame = document.getElementById('frame');
    const loading = document.getElementById('loading');
    const refreshBtn = document.getElementById('refreshBtn');
    frame.addEventListener('load', () => {
      loading.style.display = 'none';
      frame.style.display = 'block';
    });
    refreshBtn.addEventListener('click', () => {
      loading.style.display = 'flex';
      frame.style.display = 'none';
      frame.src = '$safeTarget';
    });
    setTimeout(() => {
      loading.style.display = 'none';
      frame.style.display = 'block';
    }, 7000);
  </script>
</body>
</html>
''';
  return Uri.parse('data:text/html;charset=utf-8,${Uri.encodeComponent(html)}');
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
