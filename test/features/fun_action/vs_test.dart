import 'dart:math' as math;

import 'package:be_vui_hoc/features/fun/action/act_core.dart';
import 'package:be_vui_hoc/features/fun/action/funvs1.dart';
import 'package:be_vui_hoc/features/fun/action/funvs2.dart';
import 'package:be_vui_hoc/features/fun/action/vs_core.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

T mk<T extends VsGame>(T Function(dynamic ctx, Gfx g, String mode) f, String id, {String mode = 'bot', int level = 0, Size size = const Size(800, 500)}) {
  final ff = FakeFun(gameId: id, level: level);
  final g = f(ff.ctx, Gfx(), mode);
  g.layout(size.width, size.height);
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kết quả: hai người không lên cấp, đấu máy thắng khi bé thắng', () {
    final p = vsResult(const VsEnd(2, 0), 'pvp');
    expect(p.pvp, isTrue);
    expect(p.title, contains('ĐỎ'));
    expect(vsResult(const VsEnd(1, 15), 'bot').win, isTrue);
    expect(vsResult(const VsEnd(0, 5), 'bot').win, isFalse);
  });

  test('Võ đài: đấm bằng nút, hạ hết máu là K.O.', () {
    for (final mode in ['bot', 'pvp']) {
      final g = mk((c, gf, m) => FighterGame(c, gf, m), 'fighter', mode: mode);
      var i = 0;
      final r = g.runFor(60, each: () {
        i++;
        final p1 = g.B!.list.firstWhere((b) => b.id == 'p1');
        if (i % 10 == 0) {
          g.pointerDown(1, Offset(p1.x, p1.y));
          g.pointerUp(1);
        }
        if (i == 150) g.P[1].hp = 1;
        if (i % 4 == 0) g.paintOnce();
      }) as VsEnd?;
      expect(r, isNotNull, reason: mode);
      expect(r!.winner, inInclusiveRange(1, 2));
    }
  });

  test('Khúc côn cầu: 5 bàn là thắng', () {
    final g = mk((c, gf, m) => HockeyGame(c, gf, m), 'hockey');
    final r = g.runFor(120, each: () {
      if (g.pause <= 0 && g.t > 2.4) {
        g.px = g.Rr - g.pr - 1;
        g.py = g.cyy;
        g.pvx = 400;
        g.pvy = 0;
      }
      g.paintOnce();
    }) as VsEnd?;
    expect(r!.winner, 1);
    expect(r.score, 25);
  });

  test('Kéo co: chạm nhanh thắng máy cấp 1', () {
    final g = mk((c, gf, m) => TugGame(c, gf, m), 'tug');
    var i = 0;
    final r = g.runFor(60, each: () {
      g.pointerDown(++i, const Offset(100, 300));
      g.pointerUp(i);
      g.pointerDown(++i, const Offset(120, 300));
      g.pointerUp(i);
      g.paintOnce();
    }) as VsEnd?;
    expect(r!.winner, 1);
  });

  test('Bóng đá + bóng chuyền: chạy tới kết thúc', () {
    final s = mk((c, gf, m) => SoccerGame(c, gf, m), 'soccer');
    final r1 = s.runFor(200, each: () {
      if (s.pause <= 0 && s.t > 2.4) {
        s.ball.x = s.W - s.ball.r - 2;
        s.ball.y = s.ground - s.ball.r - 2;
        s.ball.vx = 300;
      }
      s.paintOnce();
    }) as VsEnd?;
    expect(r1!.winner, 1);
    final v = mk((c, gf, m) => VolleyGame(c, gf, m), 'volley', mode: 'pvp');
    var i = 0;
    final r2 = v.runFor(300, each: () {
      // Bên đỏ đứng sát lưới, bên xanh đứng góc trái: bóng giao bên nào rơi bên đó
      final rb = v.B!.list.firstWhere((b) => b.id == 'l1'), lb = v.B!.list.firstWhere((b) => b.id == 'l2');
      if (i++ == 0) {
        v.pointerDown(8, Offset(rb.x, rb.y));
        v.pointerDown(9, Offset(lb.x, lb.y));
      }
      v.paintOnce();
    }) as VsEnd?;
    expect(r2, isNotNull);
    expect(r2!.winner, isIn([1, 2]));
  });

  test('Ném tuyết: ném trúng 5 lần', () {
    final g = mk((c, gf, m) => SnowballGame(c, gf, m), 'snowball', level: 20);
    var i = 0;
    final r = g.runFor(200, each: () {
      i++;
      if (g.t > 2.4 && i % 3 == 0) {
        // Ném vòng cung qua tường (góc 60°) theo tầm xa của trọng lực
        final dx = g.P[1].x - g.P[0].x, ang = -math.pi / 3;
        final v = math.sqrt(dx.abs() * g.G / math.sin(-2 * ang).abs());
        g.throwFrom(0, math.cos(ang) * v, math.sin(ang) * v);
      }
      g.paintOnce();
    }) as VsEnd?;
    expect(r, isNotNull);
  });

  test('Mô tô ánh sáng: đâm tường là thua ván, ai 3 ván trước thắng', () {
    final g = mk((c, gf, m) => TronGame(c, gf, m), 'tron');
    final r = g.runFor(300, each: () {
      // Bé rẽ lên ngay đầu ván (vuốt lên ở nửa trái)
      if (g.P[0].dir == 'r' && g.P[0].x > 4) {
        g.pointerDown(1, const Offset(100, 400));
        g.pointerMove(1, const Offset(100, 300));
        g.pointerUp(1);
      }
      g.paintOnce();
    }) as VsEnd?;
    expect(r, isNotNull);
    expect(r!.winner, isIn([1, 2]));
  });

  test('Sumo: lao vào đối thủ tới khi có người ra ngoài', () {
    final g = mk((c, gf, m) => SumoGame(c, gf, m), 'sumo', mode: 'pvp');
    g.pointerDown(1, const Offset(200, 300));
    g.pointerMove(1, const Offset(300, 300));
    final r = g.runFor(300, each: g.paintOnce) as VsEnd?;
    expect(r!.winner, 1);
  });

  test('Cờ caro + nối bốn: chơi với máy tới hết ván', () {
    for (final lv in [0, 15, 40]) {
      final g = mk((c, gf, m) => CaroGame(c, gf, m), 'caro', level: lv);
      final r = g.runFor(400, each: () {
        if (!g.busy && g.turn == 1 && g.end == null) {
          for (var y = 0; y < g.N && g.turn == 1 && !g.busy; y++) {
            for (var x = 0; x < g.N && g.turn == 1 && !g.busy; x++) {
              if (g.g[y][x] == 0) g.tapCell(x, y);
            }
          }
        }
        g.paintOnce();
      }) as VsEnd?;
      expect(r, isNotNull, reason: 'caro lv $lv');
    }
    for (final lv in [0, 59]) {
      final g = mk((c, gf, m) => Connect4Game(c, gf, m), 'connect4', level: lv);
      var col = 0;
      final r = g.runFor(400, each: () {
        if (!g.busy && g.turn == 1) g.tapCol(col++ % 7);
        g.paintOnce();
      }) as VsEnd?;
      expect(r, isNotNull, reason: 'connect4 lv $lv');
    }
  });
}
