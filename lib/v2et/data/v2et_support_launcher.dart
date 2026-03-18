import 'package:hiddify/v2et/data/v2et_runtime_config_provider.dart';

Uri? buildV2etSupportUri(V2etRuntimeConfig? config) {
  if (config == null) return null;

  final direct = _parseUri(config.supportUrl);
  if (direct != null) {
    return direct;
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
