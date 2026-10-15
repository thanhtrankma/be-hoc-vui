// Agent D: phòng thú cưng, tủ đồ, album hình dán, bố con thi tài, học cùng lớp.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/class_plan.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/room/duel.dart';
import 'package:be_vui_hoc/features/room/lop1.dart';
import 'package:be_vui_hoc/features/room/pet.dart';
import 'package:be_vui_hoc/features/room/room.dart';
import 'package:be_vui_hoc/features/room/stickers.dart';
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
  });

  /// Dựng một router nhỏ chỉ gồm màn của agent D (+ chỗ trống cho /map, /play).
  Future<(AppStore, SilentAudio)> pump(WidgetTester tester, String initial,
      {void Function(AppStore s)? setup, Size size = const Size(390, 844), bool settle = true}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addProfile('Na', 'robot');
    setup?.call(store);
    final audio = SilentAudio(voice: bundle.voice, store: store);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: '/map', builder: (c, s) => const Text('MAP')),
      GoRoute(path: '/room', builder: (c, s) => const RoomScreen()),
      GoRoute(path: '/pet', builder: (c, s) => const PetScreen()),
      GoRoute(path: '/album', builder: (c, s) => const StickersScreen()),
      GoRoute(path: '/duel', builder: (c, s) => const DuelScreen()),
      GoRoute(path: '/lop1', builder: (c, s) => const Lop1Screen()),
      GoRoute(path: '/play/:id/:li/:from', builder: (c, s) => Text('PLAY ${s.uri.path}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (store, audio);
  }

  Future<void> frames(WidgetTester tester, int n, [int ms = 50]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(Duration(milliseconds: ms));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  test('petTick: chỉ số giảm theo giờ, không dưới mức sàn', () {
    final now = DateTime(2026, 10, 15, 12);
    final pet = <String, dynamic>{'food': 70.0, 'water': 70.0, 'clean': 80.0, 'happy': 80.0, 'energy': 90.0, 'xp': 0, 'last': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch};
    petTick(pet, now);
    expect(pet['food'], closeTo(52, .01));
    expect(pet['water'], closeTo(48, .01));
    pet['last'] = now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
    petTick(pet, now);
    expect(pet['food'], 8);
    expect(petLevel({'xp': 130}), 3);
  });

  testWidgets('nhận nuôi cún rồi cho ăn', (tester) async {
    final (store, audio) = await pump(tester, '/pet', settle: false);
    await frames(tester, 4);
    expect(find.byKey(const Key('adopt-dog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('adopt-dog')));
    await frames(tester, 4);
    expect(find.byKey(const Key('pet-name-input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pet-name-input')), 'Lu');
    await tester.tap(find.byKey(const Key('pet-adopt-btn')));
    await frames(tester, 10);
    final pet = store.profile!.pet!;
    expect(pet['type'], 'dog');
    expect(pet['name'], 'Lu');
    expect(audio.log, contains('sfx:win'));
    // Phòng thú cưng
    expect(find.byKey(const Key('pet-canvas')), findsOneWidget);
    expect(find.textContaining('Lu', findRichText: true), findsWidgets);
    await frames(tester, 20); // qua lời chào
    await tester.tap(find.byKey(const Key('pact-feed')));
    await frames(tester, 2);
    expect(find.byKey(const Key('food-Bone')), findsOneWidget);
    await tester.tap(find.byKey(const Key('food-Bone')));
    await frames(tester, 140); // đi tới bát và ăn
    expect(audio.log, contains('sfx:eat'));
    expect(asDouble(store.profile!.pet!['food']), greaterThan(75));
    // Đồ đẹp: món chưa mở khoá bị khoá
    await tester.tap(find.byKey(const Key('pact-wear')));
    await frames(tester, 2);
    expect(find.byKey(const Key('pwear-Crown')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tủ đồ: mua, đeo và bỏ đồ cho linh vật', (tester) async {
    final (store, audio) = await pump(tester, '/room', setup: (s) => s.profile!.stars = 20);
    expect(find.byKey(const Key('room-stage')), findsOneWidget);
    expect(audio.log, contains('say:${bundle.voice.phrase('roomIntro', 'vi').key}'));
    await tester.tap(find.byKey(const Key('ward-cap')));
    await tester.pumpAndSettle();
    final p = store.profile!;
    expect(p.owned, contains('cap'));
    expect(p.outfit['hat'], 'cap');
    expect(store.wallet(p), 15);
    // Bấm lại: bỏ ra
    await tester.tap(find.byKey(const Key('ward-cap')));
    await tester.pumpAndSettle();
    expect(store.profile!.outfit['hat'], isNull);
    // Ngăn kính
    await tester.tap(find.byKey(const Key('slot-eyes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ward-cap')), findsNothing);
    await unmount(tester);
  });

  testWidgets('tủ đồ: không đủ sao thì không mua được', (tester) async {
    final (store, audio) = await pump(tester, '/room', size: const Size(1024, 768));
    await tester.tap(find.byKey(const Key('slot-hat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ward-crown')));
    await tester.pumpAndSettle();
    expect(store.profile!.owned, isEmpty);
    expect(audio.log, contains('sfx:wrong'));
    await unmount(tester);
  });

  testWidgets('album hình dán và huy hiệu', (tester) async {
    final first = bundle.data.stickers.first;
    final (store, audio) = await pump(tester, '/album', setup: (s) {
      s.profile!.stickers.add(first);
      s.profile!.badges.add('first');
    });
    expect(find.text('1/${bundle.data.stickers.length}'), findsOneWidget);
    expect(find.byKey(Key('sticker-$first')), findsOneWidget);
    expect(find.byKey(const Key('badge-first')), findsOneWidget);
    await tester.tap(find.byKey(Key('sticker-$first')));
    await tester.pump();
    expect(audio.log.last, 'sfx:pop');
    expect(store.profile!.stickers.length, 1);
    await unmount(tester);
  });

  testWidgets('bố con thi tài: một lượt tính nhẩm', (tester) async {
    final (_, audio) = await pump(tester, '/duel');
    expect(find.byKey(const Key('duel-topic-math')), findsOneWidget);
    await tester.tap(find.byKey(const Key('duel-topic-math')));
    await tester.pump();
    await tester.pump();
    final eq = tester.widget<Text>(find.byKey(const Key('deq-1'))).data!;
    final parts = eq.split(' ');
    final a = int.parse(parts[0]), b = int.parse(parts[2]);
    final ans = parts[1] == '+' ? a + b : a - b;
    // Bố mẹ bấm sai trước → bị khoá
    final wrongFinder = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('dch-0-') && (w.key as ValueKey<String>).value != 'dch-0-$ans');
    await tester.tap(wrongFinder.first);
    await tester.pump();
    expect(audio.log, contains('sfx:wrong'));
    // Bé bấm đúng
    await tester.tap(find.byKey(Key('dch-1-$ans')));
    await tester.pump();
    expect(audio.log, contains('sfx:correct'));
    expect(find.descendant(of: find.byKey(const Key('dscore-1')), matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('dscore-0')), matching: find.text('0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    // Lượt 2: điểm vẫn giữ
    expect(find.descendant(of: find.byKey(const Key('dscore-1')), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('duel-quit')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('duel-topic-math')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('bố con thi tài: đủ 10 lượt → bảng kết quả', (tester) async {
    await pump(tester, '/duel', size: const Size(1024, 768));
    await tester.tap(find.byKey(const Key('duel-topic-count')));
    await tester.pump();
    await tester.pump();
    for (var r = 0; r < kDuelRounds; r++) {
      final n = tester.widgetList(find.descendant(of: find.byKey(const Key('dgroup-1')), matching: find.byType(Image))).length;
      final count = n > 0 ? n : tester.widget<Wrap>(find.byKey(const Key('dgroup-1'))).children.length;
      await tester.tap(find.byKey(Key('dch-1-$count')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('duel-final')), findsOneWidget);
    expect(find.text('🏆 Na'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duel-rematch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('duel-topic-count')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('học cùng lớp: tuần, đổi môn, mở một hoạt động', (tester) async {
    late ClassPlan plan;
    final (store, _) = await pump(tester, '/lop1', setup: (s) {
      plan = ClassPlan(bundle.content, s);
      plan.setClassWeek(s.profile!, 3);
    });
    expect(find.text('Tuần 3'), findsOneWidget);
    expect(find.text('Tuần 3 trên lớp'), findsOneWidget);
    final cur = classGroups(plan.classItems('tv'), 3).cur;
    expect(cur, isNotEmpty);
    expect(find.byKey(Key('cls-card-${cur.first.key}')), findsOneWidget);
    // Đổi sang Toán
    await tester.tap(find.byKey(const Key('cls-tab-toan')));
    await tester.pumpAndSettle();
    final toan = classGroups(plan.classItems('toan'), 3).cur;
    expect(find.byKey(Key('cls-card-${toan.first.key}')), findsOneWidget);
    // Mở bài đã qua
    await tester.tap(find.byKey(const Key('cls-fold-prev')));
    await tester.pumpAndSettle();
    // Mở hoạt động đầu tiên của bài tuần này
    final a = toan.first.acts.first;
    final act = find.byKey(Key('cls-act-${a.$1}-${a.$2}')).first;
    await tester.ensureVisible(act);
    await tester.pumpAndSettle();
    await tester.tap(act);
    await tester.pumpAndSettle();
    expect(find.text('PLAY /play/${a.$1}/${a.$2}/lop1'), findsOneWidget);
    expect(store.profile, isNotNull);
    await unmount(tester);
  });
}
