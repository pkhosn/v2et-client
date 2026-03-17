class V2boardSubscription {
  const V2boardSubscription({
    required this.subscriptionUrl,
    required this.fetchedAt,
    this.planName,
    this.transferEnableBytes,
    this.expiredAt,
    this.nodeCount,
  });

  final Uri subscriptionUrl;
  final DateTime fetchedAt;
  final String? planName;
  final int? transferEnableBytes;
  final DateTime? expiredAt;
  final int? nodeCount;
}
