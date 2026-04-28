class V2etApiProxyConfig {
  const V2etApiProxyConfig({
    required this.enabled,
    required this.scheme,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final bool enabled;
  final String scheme;
  final String host;
  final int port;
  final String? username;
  final String? password;

  bool get isUsable => enabled && host.trim().isNotEmpty && port > 0 && port <= 65535;

  String get findProxyRule {
    final upper = scheme.toUpperCase();
    final auth = (username == null || username!.trim().isEmpty)
        ? ''
        : '${username!.trim()}:${password?.trim() ?? ''}@';
    return '$upper $auth$host:$port; DIRECT';
  }
}
