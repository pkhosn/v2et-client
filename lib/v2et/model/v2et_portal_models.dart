class V2etNotice {
  const V2etNotice({required this.title, required this.content});
  final String title;
  final String content;
}

class V2etBanner {
  const V2etBanner({
    required this.title,
    required this.imageUrl,
    this.targetUrl,
  });
  final String title;
  final String imageUrl;
  final String? targetUrl;
}

class V2etSupportEntry {
  const V2etSupportEntry({required this.title, required this.route});
  final String title;
  final String route;
}

class V2etStoreOffer {
  const V2etStoreOffer({
    this.id,
    required this.name,
    required this.prices,
    this.traffic,
    this.speed,
    this.deviceLimit,
    this.features = const [],
    this.raw = const {},
  });

  final int? id;
  final String name;
  final Map<String, double> prices;
  final int? traffic;
  final String? speed;
  final int? deviceLimit;
  final List<String> features;
  final Map<String, dynamic> raw;

  bool get isOnetimeOnly => prices.keys.every((e) => e == 'onetime');
}

class V2etOrderRecord {
  const V2etOrderRecord({
    required this.tradeNo,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.planName,
    this.period,
  });

  final String tradeNo;
  final int status;
  final double totalAmount;
  final DateTime? createdAt;
  final String? planName;
  final String? period;
}

class V2etTrafficRecord {
  const V2etTrafficRecord({
    required this.upload,
    required this.download,
    required this.recordAt,
    required this.serverRate,
  });

  final int upload;
  final int download;
  final DateTime? recordAt;
  final double serverRate;
}

class V2etInviteInfo {
  const V2etInviteInfo({
    required this.codes,
    required this.stat,
  });

  final List<String> codes;
  final List<int> stat;
}
