// Điều hướng (thay route() theo #hash của app.js). Đường dẫn giống web: /map, /island/<id>, /play/<đảo>/<bài>[/lop1]...
// Màn của agent khác (phòng, thú cưng, khu vui chơi, RPG, góc bố mẹ...) nằm ở thư mục của họ; router chỉ trỏ tới.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'core/store/store.dart';
import 'core/ui/ui.dart';
import 'features/fun/hub/fun.dart';
import 'features/home/buddies_screen.dart';
import 'features/home/kids_screen.dart';
import 'features/home/new_kid_screen.dart';
import 'features/home/rest_screen.dart';
import 'features/home/start_screen.dart';
import 'features/learn/language/review.dart';
import 'features/map/island_screen.dart';
import 'features/map/map_screen.dart';
import 'features/parents/parents.dart';
import 'features/parents/report.dart';
import 'features/play/fun_play_screen.dart';
import 'features/play/play_screen.dart';
import 'features/room/duel.dart';
import 'features/room/lop1.dart';
import 'features/room/pet.dart';
import 'features/room/room.dart';
import 'features/room/stickers.dart';
import 'features/rpg/rpg.dart';

/// Bé đã bấm Bắt đầu chưa (lần chạm đầu mở âm thanh). Chưa thì mọi đường dẫn về màn Bắt đầu.
final startedProvider = StateProvider<bool>((ref) => false);

/// Tên màn từ đường dẫn: '/play/count/2' → 'play'.
String routeName(String path) {
  final parts = path.replaceFirst(RegExp(r'^/'), '').split('/');
  return parts.isEmpty ? '' : parts.first;
}

/// Màn không cần có bé đang chơi.
const _noKid = ['', 'kids', 'new', 'parent', 'report'];

final routerProvider = Provider<GoRouter>((ref) {
  String? guard(BuildContext context, GoRouterState state) {
    final store = ref.read(storeProvider);
    final name = routeName(state.uri.path);
    if (!ref.read(startedProvider)) return name == '' ? null : '/';
    final needKid = !_noKid.contains(name);
    if (needKid && store.profile == null) return store.profiles.isNotEmpty ? '/kids' : '/new';
    if (needKid && name != 'rest' && store.overLimit()) return '/rest';
    if (name == 'kids' && store.profiles.isEmpty) return '/new';
    if (name == 'rest' && !store.overLimit()) return '/map';
    if (name == 'rpg' && !store.funOn) return '/map';
    return null;
  }

  int intParam(GoRouterState s, String k) => int.tryParse(s.pathParameters[k] ?? '') ?? -1;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: guard,
    routes: [
      GoRoute(path: '/', builder: (c, s) => const StartScreen()),
      GoRoute(path: '/kids', builder: (c, s) => const KidsScreen()),
      GoRoute(path: '/new', builder: (c, s) => const NewKidScreen()),
      GoRoute(path: '/map', builder: (c, s) => const MapScreen()),
      GoRoute(path: '/island/:id', builder: (c, s) => IslandScreen(islandId: s.pathParameters['id']!)),
      GoRoute(
        path: '/play/:id/:li',
        builder: (c, s) => PlayScreen(key: ValueKey(s.uri.path), islandId: s.pathParameters['id']!, levelIndex: intParam(s, 'li')),
        routes: [
          GoRoute(path: ':from', builder: (c, s) => PlayScreen(key: ValueKey(s.uri.path), islandId: s.pathParameters['id']!, levelIndex: intParam(s, 'li'), from: s.pathParameters['from'])),
        ],
      ),
      GoRoute(path: '/buddies', builder: (c, s) => const BuddiesScreen()),
      GoRoute(path: '/rest', builder: (c, s) => const RestScreen()),
      // ----- Agent D: phòng của bé, thú cưng, album, bố con thi tài, học cùng lớp -----
      GoRoute(path: '/room', builder: (c, s) => const RoomScreen()),
      GoRoute(path: '/pet', builder: (c, s) => const PetScreen()),
      GoRoute(path: '/album', builder: (c, s) => const StickersScreen()),
      GoRoute(path: '/duel', builder: (c, s) => const DuelScreen()),
      GoRoute(path: '/lop1', builder: (c, s) => const Lop1Screen()),
      // ----- Agent E: Khu vui chơi (danh sách); khung chơi /fun/<id> của Foundation -----
      GoRoute(
        path: '/fun',
        builder: (c, s) => const FunHubScreen(),
        routes: [GoRoute(path: ':game', builder: (c, s) => FunPlayScreen(key: ValueKey(s.uri.toString()), gameId: s.pathParameters['game']!))],
      ),
      // ----- Agent H: Thế giới phiêu lưu -----
      GoRoute(
        path: '/rpg',
        builder: (c, s) => const RpgTownScreen(),
        routes: [GoRoute(path: ':r/:s', builder: (c, s) => RpgStageScreen(key: ValueKey(s.uri.path), zone: intParam(s, 'r'), stage: intParam(s, 's')))],
      ),
      // ----- Agent I: Góc bố mẹ, báo cáo -----
      GoRoute(path: '/parent', builder: (c, s) => const ParentsScreen()),
      GoRoute(path: '/report/:id', builder: (c, s) => ReportScreen(kidId: s.pathParameters['id']!)),
      // ----- Agent A: ôn tập -----
      GoRoute(
        path: '/review',
        builder: (c, s) => const ReviewScreen(),
        routes: [
          GoRoute(path: ':mode', builder: (c, s) => ReviewScreen(mode: s.pathParameters['mode'])),
          GoRoute(path: ':mode/:item', builder: (c, s) => ReviewScreen(mode: s.pathParameters['mode'], item: s.pathParameters['item'])),
        ],
      ),
    ],
    errorBuilder: (c, s) => const StartScreen(),
  );
});
