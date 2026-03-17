class V2boardSession {
  const V2boardSession({required this.baseUrl, required this.accessToken, required this.createdAt});

  final Uri baseUrl;
  final String accessToken;
  final DateTime createdAt;

  bool get hasToken => accessToken.trim().isNotEmpty;
}
