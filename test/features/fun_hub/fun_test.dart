import 'dart:math' as math;

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/features/fun/hub/fun.dart';
import 'package:be_vui_hoc/features/fun/hub/funcore.dart' show FunCanvas;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

/// Tìm lực kéo ná để bóng trúng mục tiêu (mô phỏng cùng vật lý, né tường).
Offset? aim(SlingGame g, Offset target) {
  final r = g.R, half = g.S * .05 + r;
  for (var mag = g.maxPull; mag > g.maxPull * .25; mag -= g.maxPull * .05) {
    for (var a = 0.0; a < math.pi * 2; a += .01) {
      final d = Offset(math.cos(a), math.sin(a)) * mag;
      var x = g.ax + d.dx, y = g.ay + d.dy, vx = -d.dx * SlingGame.power, vy = -d.dy * SlingGame.power;
      const dt = 1 / 240;
      var ok = true;
      for (var t = 0.0; t < 4 && ok; t += dt) {
        vy += g.G * dt;
        x += vx * dt;
        y += vy * dt;
        for (final w in g.walls) {
          if (x + r > w.x && x - r < w.x + w.w && y + r > w.y && y - r < w.y + w.h) ok = false;
        }
        if (y + r > g.ground || x > g.W + 60) ok = false;
        if ((x - target.dx).abs() < half * .8 && (y - target.dy).abs() < half * .8) return d;
      }
    }
  }
  return null;
}

/// Bắn một phát vào mục tiêu đầu tiên; trả false nếu không ngắm được.
bool shoot(SlingGame g) {
  final ts = g.aliveTargets;
  if (ts.isEmpty) return false;
  for (final tg in ts) {
    final d = aim(g, tg);
    if (d == null) continue;
    g.pointerDown(Offset(g.ax, g.ay), 1);
    g.pointerMove(Offset(g.ax, g.ay) + d, 1, true);
    g.pointerUp(Offset(g.ax, g.ay) + d, 1);
    return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  test('Ná thần kỳ: ngắm trúng hết mục tiêu → thắng cấp, điểm thưởng bóng dư', () async {
    for (final lv in [0, 1, 2]) {
      final env = await makeEnv();
      final g = SlingGame(env.ctx('sling', level: lv), level: lv);
      final r = runGame(g, dt: 1 / 60, maxSec: 120, step: (t) {
        if (t > 2.6 && !g.flying && g.aliveTargets.isNotEmpty) shoot(g);
      });
      expect(r, isNotNull, reason: 'lv $lv');
      expect(r!.win, isTrue, reason: 'lv $lv');
      expect(r.score, greaterThanOrEqualTo(30));
      expect(env.audio.log, contains('sfx:shoot'));
    }
  });

  test('Ná thần kỳ: bắn xuống đất hết bóng → thua', () async {
    final env = await makeEnv();
    final g = SlingGame(env.ctx('sling', lang: 'en'), level: 0);
    final r = runGame(g, dt: 1 / 60, maxSec: 200, step: (t) {
      if (!g.flying) {
        g.pointerDown(Offset(g.ax, g.ay), 1);
        g.pointerMove(Offset(g.ax, g.ay - g.maxPull), 1, true); // kéo lên → bắn xuống
        g.pointerUp(Offset(g.ax, g.ay - g.maxPull), 1);
      }
    });
    expect(r, isNotNull);
    expect(r!.win, isFalse);
  });

  testWidgets('Ná thần kỳ (widget): 3 cấp liên tiếp → lvUp 3, ctx.levelUp 3 lần', (tester) async {
    final env = (await tester.runAsync(makeEnv))!;
    final ctx = env.ctx('sling');
    await tester.pumpWidget(env.scope(Builder(builder: (c) => funGames['sling']!.build(c, ctx)), size: const Size(800, 600)));
    for (var i = 0; i < 6000 && !env.finished; i++) {
      await tester.pump(const Duration(milliseconds: 17));
      final g = tester.widget<FunCanvas>(find.byType(FunCanvas)).game as SlingGame;
      if (g.t > 2.6 && !g.flying && g.aliveTargets.isNotEmpty) shoot(g);
    }
    expect(env.finished, isTrue);
    expect(env.result!.lvUp, isTrue);
    expect(env.result!.ups, 3);
    expect(env.levelUps, 3);
  });

  group('Màn Khu vui chơi', () {
    Future<(FunEnv, GoRouter, ProviderContainer)> pumpHub(WidgetTester tester, {int? tickets, Size size = const Size(390, 844)}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final env = (await tester.runAsync(makeEnv))!;
      if (tickets != null) env.store.profile!.json['tickets'] = tickets;
      final router = GoRouter(initialLocation: '/fun', routes: [
        GoRoute(path: '/fun', builder: (c, s) => const FunHubScreen(), routes: [GoRoute(path: ':game', builder: (c, s) => Text('PLAY ${s.pathParameters['game']}'))]),
        GoRoute(path: '/map', builder: (c, s) => const Text('MAP')),
        GoRoute(path: '/rpg', builder: (c, s) => const Text('RPG')),
      ]);
      final container = ProviderContainer(overrides: [
        contentBundleProvider.overrideWithValue(env.bundle),
        storeProvider.overrideWith((ref) => env.store),
        audioProvider.overrideWithValue(env.audio),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      return (env, router, container);
    }

    Future<void> scrollTo(WidgetTester tester, Finder f) async {
      await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    testWidgets('đủ thẻ game theo nhóm, lời chào, vé', (tester) async {
      final (env, _, _) = await pumpHub(tester);
      expect(env.audio.log.any((l) => l.startsWith('say:')), isTrue);
      expect(find.text('Khu vui chơi'), findsOneWidget);
      expect(find.byKey(const Key('lookcard')), findsOneWidget);
      expect(find.byKey(const Key('fungame-rpg'), skipOffstage: false), findsOneWidget);
      for (final g in kFunGames) {
        expect(find.byKey(Key('fungame-${g.id}'), skipOffstage: false), findsOneWidget, reason: g.id);
      }
      expect(find.text('Cấp 1/60 · 🏆 0', skipOffstage: false), findsWidgets);
    });

    testWidgets('có vé → mở game; hết vé → báo hết vé; bố mẹ chơi không cần vé', (tester) async {
      final (env, router, container) = await pumpHub(tester, tickets: 0);
      await scrollTo(tester, find.byKey(const Key('fungame-catch')));
      await tester.tap(find.byKey(const Key('fungame-catch')));
      await tester.pump();
      expect(env.audio.log, contains('sfx:wrong'));
      expect(find.text('Hết vé rồi! Học thêm một bài để có vé nhé.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      // Bố mẹ
      container.read(parentFunProvider.notifier).state = true;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fungame-catch')));
      await tester.pumpAndSettle();
      expect(find.text('PLAY catch'), findsOneWidget);
      router.go('/fun');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('parentfun-exit')));
      await tester.tap(find.byKey(const Key('parentfun-exit')));
      await tester.pumpAndSettle();
      expect(container.read(parentFunProvider), isFalse);
    });

    testWidgets('khoá bố mẹ: trả lời đúng phép nhân → chơi miễn phí', (tester) async {
      final (_, _, container) = await pumpHub(tester, tickets: 0);
      await scrollTo(tester, find.byKey(const Key('parentfun-btn')));
      await tester.tap(find.byKey(const Key('parentfun-btn')));
      await tester.pumpAndSettle();
      final q = tester.widget<Text>(find.textContaining(' × ')).data!;
      final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
      final ans = int.parse(m[1]!) * int.parse(m[2]!);
      for (final ch in '$ans'.split('')) {
        await tester.tap(find.byKey(Key('gate-$ch')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('gate-OK')));
      await tester.pumpAndSettle();
      expect(container.read(parentFunProvider), isTrue);
      expect(find.byKey(const Key('parentfun-on')), findsOneWidget);
    });

    testWidgets('thẻ Nhân vật: chọn bé gái, màu áo, mũ → lưu p.look', (tester) async {
      final (env, _, _) = await pumpHub(tester, size: const Size(1024, 768));
      await tester.tap(find.text('👧 Bé gái'));
      await tester.pumpAndSettle();
      expect(env.store.profile!.look!['base'], 'girl');
      await tester.tap(find.byKey(const Key('shirt-#2f9e44')));
      await tester.pumpAndSettle();
      expect(env.store.profile!.look!['shirt'], '#2f9e44');
      await tester.tap(find.byKey(const Key('hat-Crown')));
      await tester.pumpAndSettle();
      expect(env.store.profile!.look!['hat'], 'Crown');
      expect(env.store.profile!.look!['base'], 'girl');
    });

    for (final size in const [Size(320, 568), Size(768, 1024), Size(1366, 1024)]) {
      testWidgets('vẽ không tràn ở cỡ $size', (tester) async {
        await pumpHub(tester, size: size);
        await tester.scrollUntilVisible(find.byKey(const Key('fungame-truckload')), 400, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('mở Thế giới phiêu lưu, quay về bản đồ', (tester) async {
      final (_, router, _) = await pumpHub(tester, size: const Size(1024, 768));
      await tester.tap(find.byKey(const Key('fungame-rpg')));
      await tester.pumpAndSettle();
      expect(find.text('RPG'), findsOneWidget);
      router.go('/fun');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('MAP'), findsOneWidget);
    });
  });
}
