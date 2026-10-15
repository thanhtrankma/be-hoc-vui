// Thế giới phiêu lưu trên màn hình: vào làng, vùng khoá/mở, chọn màn → trừ vé → chơi (Flame) → thắng → bảng kết quả
// → lưu tiến độ → màn tiếp; cửa hàng mua vũ khí; đồng đội; bố mẹ chơi thử không tốn vé.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/rpg/rpg.dart';
import 'package:be_vui_hoc/features/rpg/rpgcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
    rpgArtLoader = (imgs, sheets) async => RpgArt.empty();
  });

  Future<(AppStore, SilentAudio, GoRouter)> pump(WidgetTester tester, {bool free = false, int tickets = 3, void Function(AppStore s)? prep, Size size = const Size(820, 1180)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addProfile('Na', 'robot');
    store.profile!.json['tickets'] = tickets;
    prep?.call(store);
    final audio = SilentAudio(voice: bundle.voice, store: store);
    final router = GoRouter(navigatorKey: rootNavigatorKey, initialLocation: '/rpg', routes: [
      GoRoute(path: '/map', builder: (c, s) => const Scaffold(body: Text('MAP'))),
      GoRoute(path: '/fun', builder: (c, s) => const Scaffold(body: Text('FUN'))),
      GoRoute(
        path: '/rpg',
        builder: (c, s) => const RpgTownScreen(),
        routes: [GoRoute(path: ':r/:s', builder: (c, s) => RpgStageScreen(key: ValueKey(s.uri.path), zone: int.parse(s.pathParameters['r']!), stage: int.parse(s.pathParameters['s']!)))],
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(audio),
        parentFunProvider.overrideWith((ref) => free),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ));
    await tester.pumpAndSettle();
    return (store, audio, router);
  }

  Future<void> frames(WidgetTester tester, double secs) async {
    for (var t = 0.0; t < secs; t += 1 / 30) {
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('vào làng: thẻ nhân vật, vé, 10 vùng; vùng chưa mở thì báo', (tester) async {
    final (store, audio, _) = await pump(tester);
    expect(find.text('⚔️ Thế giới phiêu lưu'), findsOneWidget);
    expect(find.byKey(const Key('rpg-village')), findsOneWidget);
    expect(find.byKey(const Key('rpg-lv')), findsOneWidget);
    expect(find.text('Cấp 1'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(audio.log, contains('say:${audio.phrase('rpgTown').key}'));
    expect(store.profile!.json['rpg'], isA<Map>());
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-zone-9')), 300);
    for (var r = 0; r < kZones.length; r++) {
      expect(find.byKey(Key('rpg-zone-$r')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('rpg-zone-1')));
    await tester.pump();
    expect(audio.log.last, 'sfx:wrong');
    await tester.pump(const Duration(seconds: 3));
    await unmount(tester);
  });

  testWidgets('chọn màn → trừ vé → chơi → thắng → lưu tiến độ → màn tiếp', (tester) async {
    RpgStage? stage;
    RpgStageScreen.debugOnStage = (s) => stage = s;
    addTearDown(() => RpgStageScreen.debugOnStage = null);
    final (store, audio, router) = await pump(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-zone-0')), 300);
    await tester.tap(find.byKey(const Key('rpg-zone-0')));
    await tester.pumpAndSettle();
    // Màn 2 còn khoá
    await tester.tap(find.byKey(const Key('rpg-stage-1')));
    await tester.pump();
    expect(audio.log.last, 'sfx:wrong');
    await tester.tap(find.byKey(const Key('rpg-stage-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/rpg/0/0');
    await frames(tester, .5);
    expect(store.tickets(store.profile!), 2);
    expect(audio.log, contains('say:${audio.phrase('rpgZ0').key}'));
    expect(stage, isNotNull);
    expect(find.byType(RpgGameView), findsOneWidget);
    // Chơi thật vài giây (Flame chạy vòng lặp), rồi thắng ngay
    await frames(tester, 3);
    expect(stage!.t, greaterThan(1));
    stage!.debugWin();
    await frames(tester, 2.6);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('rpg-result')), findsOneWidget);
    expect(find.text('🏆 Chiến thắng!'), findsOneWidget);
    final R = rpgOf(store.profile!);
    expect(R.progOf(0), 1);
    expect(R.gold, greaterThan(30));
    // Đã ghi xuống máy
    final saved = AppStore(await SharedPreferences.getInstance());
    expect(rpgOf(saved.profile!).progOf(0), 1);
    // Màn tiếp
    await tester.tap(find.byKey(const Key('rpg-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/rpg/0/1');
    await frames(tester, .5);
    expect(store.tickets(store.profile!), 1);
    // Đóng màn → về làng
    await tester.tap(find.byKey(const Key('rpg-quit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/rpg');
    await unmount(tester);
  });

  testWidgets('hết vé thì không vào được màn; bố mẹ chơi thử không tốn vé, không lưu', (tester) async {
    final (store, audio, router) = await pump(tester, tickets: 0);
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-zone-0')), 300);
    await tester.tap(find.byKey(const Key('rpg-zone-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rpg-stage-0')));
    await tester.pump();
    expect(audio.log, contains('say:${audio.phrase('noTicket').key}'));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/rpg');
    await tester.pump(const Duration(seconds: 3));
    await unmount(tester);

    RpgStage? stage;
    RpgStageScreen.debugOnStage = (s) => stage = s;
    addTearDown(() => RpgStageScreen.debugOnStage = null);
    final (store2, _, router2) = await pump(tester, tickets: 0, free: true);
    expect(find.textContaining('Bố mẹ chơi thử'), findsOneWidget);
    router2.go('/rpg/4/2'); // bố mẹ được vào cả vùng chưa mở
    await tester.pump();
    await frames(tester, .5);
    expect(stage, isNotNull);
    stage!.debugWin();
    await frames(tester, 2.6);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('rpg-result')), findsOneWidget);
    expect(find.text('👨‍👩‍👦 Bố mẹ chơi thử nên không lưu'), findsOneWidget);
    expect(rpgOf(store2.profile!).progOf(4), 0);
    expect(store2.tickets(store2.profile!), 0);
    await tester.tap(find.byKey(const Key('rpg-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router2.routerDelegate.currentConfiguration.uri.path, '/rpg');
    await unmount(tester);
    expect(store.tickets(store.profile!), 0);
  });

  testWidgets('cửa hàng: mua dao găm, bình máu; đồng đội chưa mở thì không chọn được', (tester) async {
    final (store, _, _) = await pump(tester, prep: (s) => rpgOf(s.profile!).gold = 100);
    await tester.tap(find.byKey(const Key('rpg-shop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rpg-shop-panel')), findsOneWidget);
    expect(find.text('Bé có 100 vàng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rpg-buy-w1')));
    await tester.pump();
    final R = rpgOf(store.profile!);
    expect(R.w, 1);
    expect(R.gold, 40);
    expect(find.text('Bé có 40 vàng'), findsOneWidget);
    // Chưa đủ vàng mua cung
    await tester.tap(find.byKey(const Key('rpg-buy-w2')));
    await tester.pump();
    expect(R.ownW, [0, 1]);
    await tester.pump(const Duration(seconds: 3));
    // Tab bình máu
    await tester.tap(find.text('🧪 Bình máu'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rpg-buy-pot')));
    await tester.pump();
    expect(R.pot, 3);
    expect(R.gold, 15);
    await tester.tap(find.byKey(const Key('rpg-shop-done')));
    await tester.pumpAndSettle();
    expect(find.text('Cấp 1'), findsOneWidget);
    // Lưu xuống máy
    final saved = AppStore(await SharedPreferences.getInstance());
    expect(rpgOf(saved.profile!).w, 1);
    // Đồng đội
    await tester.tap(find.byKey(const Key('rpg-pets')));
    await tester.pumpAndSettle();
    expect(find.text('Đang đi cùng'), findsOneWidget);
    expect(find.byKey(const Key('rpg-pet-fairy')), findsNothing);
    expect(find.textContaining('Thắng trùm Hang Mỏ'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await unmount(tester);
  });

  testWidgets('qua trùm Rừng Xanh thì mở Biển Ngọc (đi sang vùng mới)', (tester) async {
    final (_, _, router) = await pump(tester, prep: (s) => rpgOf(s.profile!).prog['0'] = kStages);
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-zone-1')), 300);
    await tester.tap(find.byKey(const Key('rpg-zone-1')));
    await tester.pumpAndSettle();
    expect(find.text('Biển Ngọc'), findsWidgets);
    await tester.tap(find.byKey(const Key('rpg-stage-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/rpg/1/0');
    await frames(tester, .5);
    expect(find.byType(RpgGameView), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('điện thoại dọc: làng, cửa hàng, màn chơi không tràn', (tester) async {
    final (_, _, router) = await pump(tester, size: const Size(360, 740));
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-zone-9')), 300);
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-shop')), -300);
    await tester.tap(find.byKey(const Key('rpg-shop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rpg-shop-panel')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('rpg-shop-done')), 300, scrollable: find.ancestor(of: find.byKey(const Key('rpg-shop-panel')), matching: find.byType(Scrollable)).first);
    await tester.tap(find.byKey(const Key('rpg-shop-done')));
    await tester.pumpAndSettle();
    router.go('/rpg/0/0');
    await tester.pump();
    await frames(tester, 3);
    expect(find.byType(RpgGameView), findsOneWidget);
    await unmount(tester);
  });
}
