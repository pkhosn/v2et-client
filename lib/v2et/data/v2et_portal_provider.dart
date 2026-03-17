import 'package:hiddify/v2et/data/v2et_data_providers.dart';
import 'package:hiddify/v2et/data/v2et_portal_api.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final v2etPortalApiProvider = Provider<V2etPortalApi>((ref) {
  return V2etPortalApi();
});

final v2etNoticesProvider = FutureProvider<List<V2etNotice>>((ref) async {
  final session = await ref.watch(v2etSessionProvider.future);
  if (session == null || !session.hasToken) {
    return const [V2etNotice(title: '系统公告', content: '请先登录后同步公告。')];
  }
  try {
    final notices = await ref.watch(v2etPortalApiProvider).fetchNotices(session);
    if (notices.isEmpty) {
      return const [V2etNotice(title: '系统公告', content: '暂无公告')];
    }
    return notices;
  } catch (_) {
    return const [V2etNotice(title: '系统公告', content: '公告拉取失败，稍后重试。')];
  }
});

final v2etBannersProvider = Provider<List<V2etBanner>>((ref) {
  return const [
    V2etBanner(title: '新品套餐', imageUrl: 'https://dummyimage.com/1200x360/ece8f5/5b3f88&text=V2ET+Banner'),
  ];
});

final v2etStoreOffersProvider = FutureProvider<List<V2etStoreOffer>>((ref) async {
  final session = await ref.watch(v2etSessionProvider.future);
  if (session == null || !session.hasToken) {
    return const [];
  }
  try {
    return await ref.watch(v2etPortalApiProvider).fetchPlans(session);
  } catch (_) {
    return const [];
  }
});

final v2etCountersProvider = FutureProvider<Map<String, int>>((ref) async {
  final session = await ref.watch(v2etSessionProvider.future);
  if (session == null || !session.hasToken) {
    return const {'orders': 0, 'tickets': 0};
  }
  try {
    return await ref.watch(v2etPortalApiProvider).fetchCounters(session);
  } catch (_) {
    return const {'orders': 0, 'tickets': 0};
  }
});

final v2etSupportEntriesProvider = FutureProvider<List<V2etSupportEntry>>((ref) async {
  final counters = await ref.watch(v2etCountersProvider.future);
  return [
    V2etSupportEntry(title: '订单记录 ${counters['orders'] ?? 0}', route: 'orders'),
    const V2etSupportEntry(title: '流量明细', route: 'traffic'),
    V2etSupportEntry(title: '我的工单 ${counters['tickets'] ?? 0}', route: 'tickets'),
    const V2etSupportEntry(title: '在线客服', route: 'support'),
    const V2etSupportEntry(title: '邀请管理', route: 'invites'),
    const V2etSupportEntry(title: '礼品卡兑换', route: 'gift-card'),
  ];
});
