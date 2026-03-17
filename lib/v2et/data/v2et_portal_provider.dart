import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hiddify/v2et/model/v2et_portal_models.dart';

final v2etNoticesProvider = Provider<List<V2etNotice>>((ref) {
  return const [
    V2etNotice(title: '系统公告', content: '欢迎使用 V2ET 客户端，已支持自动登录同步。'),
  ];
});

final v2etBannersProvider = Provider<List<V2etBanner>>((ref) {
  return const [
    V2etBanner(title: '新品套餐', imageUrl: 'https://dummyimage.com/1200x360/ece8f5/5b3f88&text=V2ET+Banner'),
  ];
});

final v2etSupportEntriesProvider = Provider<List<V2etSupportEntry>>((ref) {
  return const [
    V2etSupportEntry(title: '订单记录', route: 'orders'),
    V2etSupportEntry(title: '流量明细', route: 'traffic'),
    V2etSupportEntry(title: '我的工单', route: 'tickets'),
    V2etSupportEntry(title: '在线客服', route: 'support'),
    V2etSupportEntry(title: '邀请管理', route: 'invites'),
    V2etSupportEntry(title: '礼品卡兑换', route: 'gift-card'),
  ];
});
