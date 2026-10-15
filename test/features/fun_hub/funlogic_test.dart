import 'package:be_vui_hoc/features/fun/hub/funlogic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  Future<FunEnv> pumpGame(WidgetTester tester, String id, {int level = 0}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(makeEnv))!;
    final ctx = env.ctx(id, level: level);
    await tester.pumpWidget(env.scope(Builder(builder: (c) => funlogicGames[id]!.build(c, ctx))));
    await tester.pump();
    return env;
  }

  Future<void> settle(WidgetTester tester, [int ms = 2500]) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('sinh đề', () {
    test('codingLevel: đường mẫu hợp lệ, không đi qua đá, đủ chỗ trong chương trình', () {
      for (final lv in [0, 5, 12, 30, 59]) {
        final L = codingLevel(lv);
        final rocks = L.rocks.map((p) => p.join(',')).toSet();
        expect(L.path.first, L.start);
        expect(L.path.last, L.goal);
        expect(L.path.length - 1, lessThanOrEqualTo(L.max));
        for (var i = 1; i < L.path.length; i++) {
          final a = L.path[i - 1], b = L.path[i];
          expect((a[0] - b[0]).abs() + (a[1] - b[1]).abs(), 1);
          expect(rocks.contains(b.join(',')), isFalse);
        }
      }
    });

    test('flowLevel: các đoạn phủ kín lưới, mỗi đoạn ≥ 3 ô liền nhau', () {
      for (final lv in [0, 5, 15, 40, 59]) {
        final L = flowLevel(lv);
        final all = <String>{};
        for (final s in L.segs) {
          expect(s.length, greaterThanOrEqualTo(3));
          for (var i = 1; i < s.length; i++) {
            expect((s[i][0] - s[i - 1][0]).abs() + (s[i][1] - s[i - 1][1]).abs(), 1);
          }
          all.addAll(s.map((p) => p.join(',')));
        }
        expect(all.length, L.n * L.n);
      }
    });

    test('pipeLevel: chưa thông lúc đầu, xoay về đúng thì nước tới đích', () {
      for (final lv in [0, 8, 30, 59]) {
        final L = pipeLevel(lv);
        expect(pipeFlow(L.tiles, L.n, L.sy, L.ey).reached, isFalse);
        for (final t in L.tiles.where((t) => t.path)) {
          for (var r = 0; r < t.need; r++) {
            t.open = t.open.map((d) => const {'u': 'r', 'r': 'd', 'd': 'l', 'l': 'u'}[d]!).toSet();
          }
        }
        expect(pipeFlow(L.tiles, L.n, L.sy, L.ey).reached, isTrue);
      }
    });
  });

  testWidgets('Lập trình robot: lập trình theo đường mẫu → giải 3 câu, lên 3 cấp', (tester) async {
    final env = await pumpGame(tester, 'coding');
    expect(env.audio.log.any((l) => l.startsWith('say:')), isTrue);
    for (var k = 0; k < 3; k++) {
      final st = tester.state<CodingPuzzleState>(find.byType(CodingPuzzle));
      final p = st.L.path;
      for (var i = 1; i < p.length; i++) {
        final dx = p[i][0] - p[i - 1][0], dy = p[i][1] - p[i - 1][1];
        final d = dx == 1 ? 'r' : dx == -1 ? 'l' : dy == 1 ? 'd' : 'u';
        await tester.tap(find.byKey(Key('cbtn-$d')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('code-run')));
      await settle(tester, 250 + p.length * 420 + 2000);
    }
    expect(env.finished, isTrue);
    expect(env.result!.lvUp, isTrue);
    expect(env.result!.ups, 3);
    expect(env.levelUps, 3);
    expect(env.result!.score, greaterThanOrEqualTo(30));
  });

  testWidgets('Lập trình robot: chương trình sai → robot về chỗ cũ, chưa xong', (tester) async {
    final env = await pumpGame(tester, 'coding');
    final st = tester.state<CodingPuzzleState>(find.byType(CodingPuzzle));
    // Đi ra ngoài lưới (cột 0 → trái)
    await tester.tap(find.byKey(const Key('cbtn-l')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('code-run')));
    await settle(tester, 2000);
    expect(st.pos, st.L.start);
    expect(st.busy, isFalse);
    expect(env.finished, isFalse);
    expect(env.audio.log, contains('sfx:wrong'));
    // Xoá chương trình
    await tester.tap(find.byKey(const Key('cslot-0')));
    await tester.pump();
    expect(st.prog, isEmpty);
  });

  testWidgets('Nối dây màu: kéo theo đáp án → giải 3 câu', (tester) async {
    final env = await pumpGame(tester, 'flow');
    for (var k = 0; k < 3; k++) {
      final st = tester.state<FlowPuzzleState>(find.byType(FlowPuzzle));
      final rect = tester.getRect(find.byKey(const Key('flow-grid')));
      final n = st.n, cell = (rect.width - 12) / n;
      Offset at(int i) => rect.topLeft + Offset(6 + (i % n + .5) * cell, 6 + (i ~/ n + .5) * cell);
      for (final seg in st.solution) {
        final g = await tester.startGesture(at(seg.first));
        await tester.pump();
        for (final i in seg.skip(1)) {
          await g.moveTo(at(i));
          await tester.pump();
        }
        await g.up();
        await tester.pump();
      }
      expect(st.solved, isTrue);
      await settle(tester, 2200);
    }
    expect(env.finished, isTrue);
    expect(env.result!.ups, 3);
    expect(env.result!.score, 45);
  });

  testWidgets('Dẫn nước: xoay ống về đúng → nước tới cây, giải 3 câu', (tester) async {
    final env = await pumpGame(tester, 'pipes');
    for (var k = 0; k < 3; k++) {
      final st = tester.state<PipesPuzzleState>(find.byType(PipesPuzzle));
      final need = [for (final (i, t) in st.L.tiles.indexed) if (t.path) (i, t.need)];
      for (final (i, nTaps) in need) {
        for (var r = 0; r < nTaps && !st.solved; r++) {
          await tester.tap(find.byKey(Key('pipe-$i')));
          await tester.pump();
        }
      }
      expect(st.solved, isTrue);
      await settle(tester, 2600);
    }
    expect(env.finished, isTrue);
    expect(env.result!.ups, 3);
    expect(env.audio.log, contains('sfx:win'));
  });

  testWidgets('Bảng số thần tốc: chạm số theo thứ tự (có chạm sai) → giải 2 bảng', (tester) async {
    final env = await pumpGame(tester, 'schulte', level: 8);
    for (var k = 0; k < 2; k++) {
      final st = tester.state<SchultePuzzleState>(find.byType(SchultePuzzle));
      // Một lần chạm sai
      final wrong = st.nums.firstWhere((v) => v != st.target);
      await tester.tap(find.byKey(Key('sgc-$wrong')));
      await tester.pump();
      expect(st.mistakes, 1);
      while (!st.done) {
        await tester.tap(find.byKey(Key('sgc-${st.target}')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester, 2200);
    }
    expect(env.finished, isTrue);
    expect(env.result!.ups, 2);
    expect(env.result!.score, greaterThanOrEqualTo(10));
    expect(env.audio.log.where((l) => l.startsWith('say:')).length, greaterThan(5));
  });
}
