class V2etNotice {
  const V2etNotice({required this.title, required this.content});
  final String title;
  final String content;
}

class V2etBanner {
  const V2etBanner({required this.title, required this.imageUrl, this.targetUrl});
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
    required this.name,
    required this.price,
    this.cycleLabel,
    this.traffic,
    this.speed,
    this.deviceLimit,
  });

  final String name;
  final double price;
  final String? cycleLabel;
  final int? traffic;
  final String? speed;
  final int? deviceLimit;
}
