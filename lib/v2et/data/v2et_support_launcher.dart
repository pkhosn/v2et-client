import 'dart:convert';

import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';

Uri? buildV2etSupportUri(V2etRuntimeConfig? config) {
  if (config == null) return null;

  final direct = _parseUri(config.supportUrl);
  if (direct != null) {
    return direct;
  }

  final supportPayload = (config.supportUrl ?? '').trim();
  final payloadUri = _buildEmbedFromRaw(supportPayload);
  if (payloadUri != null) {
    return payloadUri;
  }

  final crispId = (config.crispWebsiteId ?? '').trim();
  if (crispId.isNotEmpty) {
    return Uri.parse('https://go.crisp.chat/chat/embed/?website_id=$crispId');
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
