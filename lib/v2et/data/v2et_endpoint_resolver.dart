import 'package:dio/dio.dart';

class V2etEndpointResolver {
  V2etEndpointResolver({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _configPathCandidates = <String>[
    '/config.json',
    '/v2et-config.json',
    '/client-config.json',
    '/app-config.json',
  ];

  static const _directKeys = <String>[
    'api',
    'apiUrl',
    'api_url',
    'baseUrl',
    'base_url',
    'panelUrl',
    'panel_url',
    'endpoint',
    'server',
  ];

  Future<Uri> resolveBaseUrl(Uri input) async {
    final normalized = _normalizeBase(input);

    final directUrl = await _tryExtractApiUrl(normalized);
    if (directUrl != null) {
      return _normalizeBase(directUrl);
    }

    for (final path in _configPathCandidates) {
      final candidate = normalized.replace(path: path, query: null, fragment: null);
      final extracted = await _tryExtractApiUrl(candidate);
      if (extracted != null) {
        return _normalizeBase(extracted);
      }
    }

    return normalized;
  }

  Future<Uri?> _tryExtractApiUrl(Uri uri) async {
    try {
      final response = await _dio.getUri<Object?>(uri, options: Options(headers: {'Accept': 'application/json'}));
      final map = _asStringMap(response.data);
      if (map == null) {
        return null;
      }
      final found = _findUrl(map);
      return found == null ? null : Uri.tryParse(found);
    } catch (_) {
      return null;
    }
  }

  String? _findUrl(Map<String, dynamic> map) {
    for (final key in _directKeys) {
      final value = map[key];
      if (value is String && value.trim().startsWith('http')) {
        return value.trim();
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map) {
        final nested = _findUrl(value.map((k, v) => MapEntry(k.toString(), v)));
        if (nested != null) {
          return nested;
        }
      }
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final nested = _findUrl(item.map((k, v) => MapEntry(k.toString(), v)));
            if (nested != null) {
              return nested;
            }
          }
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Uri _normalizeBase(Uri uri) {
    return uri.replace(path: '', query: null, fragment: null);
  }
}
