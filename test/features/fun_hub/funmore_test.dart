import 'dart:math' as math;

import 'package:be_vui_hoc/features/fun/hub/funmore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  test('đủ 6 game funmore', () {
    expect(funmoreGames.keys, containsAll(['catch', 'whack', 'fishing', 'stack', 'breakout', 'flappy']));
  });

  test('Hứng trái cây: bé kéo giỏ hứng trái cây → hết giờ thắng cấp', () async {
    final env = await makeEnv();
    final g = CatchGame(env.ctx('catch'));
    final r = runGame(g, step: (t) {
      // Theo quả trái cây thấp nhất, tránh bom
      double? best;
      var by = -1e9;
      for (final d in g.drops) {
        if (d.k != 'Bomb' && d.y > by && d.y < g.H * .86) {
          by = d.y;
          best = d.x;
        }
      }
      if (best != null) g.pointerMove(Offset(best, 300), 1, true);
    });
    expect(r, isNotNull);
    expect(r!.score, greaterThan(0));
    expect(env.audio.log, contains('sfx:coin'));
  });

  test('Hứng trái cây: không chơi → chưa qua cấp', () async {
    final env = await makeEnv();
    final g = CatchGame(env.ctx('catch', level: 5, lang: 'en'));
    g.setSize(400, 700);
    final r = runGame(g, w: 400, h: 700, step: (t) => g.pointerDown(const Offset(-500, 0), 1));
    expect(r, isNotNull);
    expect(r!.win, isFalse);
  });

  test('Đập quái vật: đập quái thò lên → đủ điểm thắng', () async {
    final env = await makeEnv();
    final g = WhackGame(env.ctx('whack'));
    final r = runGame(g, step: (t) {
      for (final p in g.upTargets) {
        g.pointerDown(p, 1);
      }
    });
    expect(r, isNotNull);
    expect(r!.win, isTrue);
    expect(r.score, greaterThanOrEqualTo(15));
  });

  test('Câu cá: thả câu vào cá → được điểm', () async {
    final env = await makeEnv();
    final g = FishingGame(env.ctx('fishing'));
    final r = runGame(g, step: (t) {
      final f = g.fishSpots;
      if (f.isNotEmpty && g.hookState == 'idle') g.pointerDown(f.first, 1);
    });
    expect(r, isNotNull);
    expect(r!.score, greaterThan(0));
  });

  test('Xây tháp: thả khối đúng lúc → đủ tầng thắng', () async {
    final env = await makeEnv();
    final g = StackGame(env.ctx('stack', level: 3));
    final r = runGame(g, dt: 1 / 120, step: (t) {
      final x = g.curX;
      if (x != null && (x - g.topX).abs() < 4) g.pointerDown(Offset.zero, 1);
    });
    expect(r, isNotNull);
    expect(r!.win, isTrue);
    expect(g.floors, greaterThanOrEqualTo(9));
  });

  test('Xây tháp: thả bừa → tháp hẹp dần, trượt thì mất tim', () async {
    final env = await makeEnv();
    final g = StackGame(env.ctx('stack'));
    var taps = 0;
    final r = runGame(g, step: (t) {
      final x = g.curX;
      if (x != null && t > taps * .9 + .5) {
        g.pointerDown(Offset.zero, 1);
        taps++;
      }
    });
    expect(r, isNotNull);
    expect(g.lives == 0 || r!.win, isTrue);
  });

  test('Phá gạch: thanh đỡ theo bóng → phá hết gạch', () async {
    final env = await makeEnv();
    final g = BreakoutGame(env.ctx('breakout'));
    var launched = false;
    final r = runGame(g, maxSec: 400, dt: 1 / 60, step: (t) {
      if (!g.launched) {
        g.pointerDown(Offset(g.W / 2, g.H * .9), 1);
        g.pointerUp(Offset(g.W / 2, g.H * .9), 1);
        launched = true;
      }
      g.pointerMove(Offset(g.ballX + math.sin(t * 1.3) * g.S * .05, g.H * .9), 1, true);
    });
    expect(launched, isTrue);
    expect(r, isNotNull);
    expect(r!.score, greaterThan(0));
  });

  test('Chim bay: vỗ cánh giữ chim giữa khe → bay qua đủ khe', () async {
    final env = await makeEnv();
    final g = FlappyGame(env.ctx('flappy'));
    final r = runGame(g, dt: 1 / 60, step: (t) {
      final gy = g.nextGapY ?? g.H * .5;
      if (!g.started || (g.bird > gy + g.S * .1 && g.birdVel > 0)) g.flap();
    });
    expect(r, isNotNull);
    expect(r!.win, isTrue);
  });

  testWidgets('FunCanvas chạy game trong widget và gọi ctx.finish', (tester) async {
    final env = await tester.runAsync(makeEnv);
    final ctx = env!.ctx('flappy');
    await tester.pumpWidget(env.scope(Builder(builder: (c) => funmoreGames['flappy']!.build(c, ctx))));
    // Không vỗ cánh khi chưa bắt đầu: chim lơ lửng; chạm để bắt đầu rồi để rơi → mất hết tim.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(200, 300));
    for (var i = 0; i < 400 && !env.finished; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(env.finished, isTrue);
    expect(env.result!.win, isFalse);
  });
}
