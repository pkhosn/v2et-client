import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

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
  GlobalKey? anchorKey,
}) async {
  final url = uri.toString().trim();
  if (url.isEmpty) return false;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'support-popup',
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (_, __, ___) => _SupportPopupLayer(uri: uri, title: title, anchorKey: anchorKey),
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curve), child: child),
        );
      },
    );
    return true;
  }

  var opened = await launchUrl(uri, mode: LaunchMode.inAppWebView);
  if (!opened) {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return opened;
}

class _SupportPopupLayer extends StatelessWidget {
  const _SupportPopupLayer({required this.uri, required this.title, required this.anchorKey});
  final Uri uri;
  final String title;
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    const popupSize = Size(380, 518);
    final screen = MediaQuery.sizeOf(context);
    final anchorBox = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
    final anchorTopLeft = anchorBox?.localToGlobal(Offset.zero) ?? Offset(screen.width - 56, screen.height - 56);
    final anchorSize = anchorBox?.size ?? const Size(40, 40);
    final desiredLeft = anchorTopLeft.dx + anchorSize.width - popupSize.width;
    final desiredTop = anchorTopLeft.dy - popupSize.height - 10;
    final left = desiredLeft.clamp(8.0, screen.width - popupSize.width - 8);
    final top = desiredTop.clamp(8.0, screen.height - popupSize.height - 8);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: popupSize.width,
            height: popupSize.height,
            child: _SupportPopupCard(uri: uri, title: title),
          ),
        ],
      ),
    );
  }
}

class _SupportPopupCard extends StatefulWidget {
  const _SupportPopupCard({required this.uri, required this.title});
  final Uri uri;
  final String title;

  @override
  State<_SupportPopupCard> createState() => _SupportPopupCardState();
}

class _SupportPopupCardState extends State<_SupportPopupCard> {
  final _controller = WebviewController();
  bool _loading = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.loadUrl(widget.uri.toString());
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = false;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              height: 46,
              color: const Color(0xFF0665D0),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(99),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _ready
                        ? Webview(_controller)
                        : const Center(
                            child: Text('客服加载失败，请稍后重试', style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                          ),
                  ),
                  if (_loading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
