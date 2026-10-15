// Đảo Tư duy: chơi hết một bài mỗi kiểu (quiz ghép bóng / khác nhóm / quy luật, mê cung, sudoku, ghép tranh,
// trình tự, tìm điểm khác) với SilentAudio.
import 'dart:collection';

import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/creative/art.dart';
import 'package:be_vui_hoc/features/learn/creative/logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpAll(loadBundle);

  test('makeMaze: mọi ô đi tới được', () {
    for (final n in [5, 7, 11]) {
      final w = makeMaze(n);
      final seen = <(int, int)>{(0, 0)};
      final q = Queue.of([(0, 0)]);
      while (q.isNotEmpty) {
        final (x, y) = q.removeFirst();
        for (final (dx, dy, k) in [(0, -1, 0), (1, 0, 1), (0, 1, 2), (-1, 0, 3)]) {
          if (!w[y][x][k] && seen.add((x + dx, y + dy))) q.add((x + dx, y + dy));
        }
      }
      expect(seen.length, n * n);
    }
  });

  test('makeSudoku: hàng, cột, ô 2×2 đủ 4 hình', () {
    for (var t = 0; t < 30; t++) {
      final s = makeSudoku();
      for (var i = 0; i < 4; i++) {
        expect(s[i].toSet().length, 4);
        expect({for (var r = 0; r < 4; r++) s[r][i]}.length, 4);
        final br = (i ~/ 2) * 2, bc = (i % 2) * 2;
        expect({s[br][bc], s[br][bc + 1], s[br + 1][bc], s[br + 1][bc + 1]}.length, 4);
      }
    }
  });

  test('câu quy luật: đáp án nằm trong lựa chọn và đúng quy luật', () {
    final cats = bundle.content.map('categories').values.map((l) => (l as List).map((e) => e.toString()).toList()).toList();
    for (final q in makeLogicQuestions('pattern', {'patterns': ['ABC', 'AABB']}, cats)) {
      expect(q.choices, contains(q.answer));
      expect(q.choices.length, lessThanOrEqualTo(3));
    }
    for (final q in makeLogicQuestions('odd', {'choices': 5}, cats)) {
      expect(q.choices.length, 5);
      expect(q.choices, contains(q.answer));
    }
  });

  testWidgets('Ghép bóng: chọn đúng hình của bóng 6 câu → 3 sao', (tester) async {
    final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', 'shadow', 'Ghép bóng'));
    for (var q = 0; q < 6; q++) {
      await pumpUntil(tester, () => find.byWidgetPredicate((w) => w is EmojiImage && w.color != null).evaluate().isNotEmpty);
      final shadow = tester.widget<EmojiImage>(find.byWidgetPredicate((w) => w is EmojiImage && w.color != null));
      await tester.tap(find.byKey(ValueKey('choice-${shadow.name}')));
      await pumpUntil(tester, () => p.progress.$1 > q || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    expect(p.audio.log, contains('sfx:correct'));
    await unmount(tester, p);
  });

  testWidgets('Mê cung: đi theo đường tới ngôi sao → 3 sao', (tester) async {
    final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', 'maze', 'Mê cung'));
    final w = MazeView.debugWalls!;
    final n = w.length;
    // BFS tìm đường
    final prev = <(int, int), (int, int)?>{(0, 0): null};
    final q = Queue.of([(0, 0)]);
    while (q.isNotEmpty) {
      final (x, y) = q.removeFirst();
      for (final (dx, dy, k) in [(0, -1, 0), (1, 0, 1), (0, 1, 2), (-1, 0, 3)]) {
        final nb = (x + dx, y + dy);
        if (!w[y][x][k] && !prev.containsKey(nb)) {
          prev[nb] = (x, y);
          q.add(nb);
        }
      }
    }
    final path = <(int, int)>[];
    for ((int, int)? c = (n - 1, n - 1); c != null && c != (0, 0); c = prev[c]) {
      path.insert(0, c);
    }
    final box = tester.getRect(find.byKey(const Key('maze')));
    final k = box.width / (n * 100 + 16);
    // chạm vào tường (ô không kề) → tiếng pop, không đi
    for (final (x, y) in path) {
      await tester.tapAt(box.topLeft + Offset((8 + x * 100 + 50) * k, (8 + y * 100 + 50) * k));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    expect(p.progress, (1, 1));
    await unmount(tester, p);
  });

  testWidgets('Sudoku hình: chọn sai một lần rồi điền đúng → 2 sao', (tester) async {
    final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', 'sudoku', 'Sudoku hình'));
    final sol = SudokuView.debugSolution!;
    var first = true;
    for (var guard = 0; guard < 10 && p.stars == null; guard++) {
      // ô đang chọn: ô trống đầu tiên chưa điền (mỗi lần đúng tự chọn ô kế)
      final empties = [
        for (var i = 0; i < 16; i++)
          if (find.descendant(of: find.byKey(Key('sudoku-cell-$i')), matching: find.byType(EmojiImage)).evaluate().isEmpty)
            i,
      ];
      if (empties.isEmpty) break;
      final i = empties.first;
      await tester.tap(find.byKey(Key('sudoku-cell-$i')));
      await tester.pump();
      final ans = sol[i ~/ 4][i % 4];
      if (first) {
        await tester.tap(find.byKey(Key('sudoku-pal-${(ans + 1) % 4}')));
        await tester.pump();
        first = false;
      }
      await tester.tap(find.byKey(Key('sudoku-pal-$ans')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 2);
    expect(p.audio.log, contains('sfx:wrong'));
    await unmount(tester, p);
  });

  testWidgets('Ghép tranh: kéo một mảnh, chạm-chạm các mảnh còn lại → 3 sao', (tester) async {
    final li = levelOf('logicLevels', 'jigsaw', 'Ghép tranh 4 mảnh');
    final p = await pumpGame(tester, logicModule, 'logic', li);
    await tester.pump();
    expect(p.buddyVisible, isFalse);
    // kéo mảnh 0 vào ô 0
    final from = tester.getCenter(find.byKey(const Key('jpiece-0')));
    final to = tester.getCenter(find.byKey(const Key('jslot-0')));
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(p.progress.$1, 1);
    // chạm sai chỗ một lần (mảnh 1 vào ô 2) — 1 lỗi đầu không trừ sao
    await tester.tap(find.byKey(const Key('jpiece-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('jslot-2')));
    await tester.pump();
    for (final i in [1, 2, 3]) {
      await tester.tap(find.byKey(Key('jpiece-$i')));
      await tester.pump();
      await tester.tap(find.byKey(Key('jslot-$i')));
      await tester.pump();
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  testWidgets('Sắp xếp trình tự: xếp sai rồi đúng 3 bộ → 2 sao', (tester) async {
    final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', 'seq', 'Sắp xếp trình tự'));
    await pumpUntil(tester, () => p.progress == (0, 3));
    for (var r = 0; r < 3; r++) {
      await pumpUntil(tester, () => p.progress.$1 == r);
      if (r == 0) {
        // sai: 1,0,2,3
        for (final k in [1, 0, 2, 3]) {
          await tester.tap(find.byKey(Key('seq-card-$k')));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(p.audio.log, contains('sfx:wrong'));
        await pumpUntil(tester, () => find.descendant(of: find.byKey(const Key('seq-slot-0')), matching: find.byKey(const Key('seq-card-1'))).evaluate().isEmpty);
        // thẻ đúng (2, 3) giữ nguyên; xếp lại 0, 1
        for (final k in [0, 1]) {
          await tester.tap(find.byKey(Key('seq-card-$k')));
          await tester.pump();
        }
      } else {
        for (final k in [0, 1, 2, 3]) {
          await tester.tap(find.byKey(Key('seq-card-$k')));
          await tester.pump();
        }
      }
      await pumpUntil(tester, () => p.progress.$1 > r || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 2);
    await unmount(tester, p);
  });

  testWidgets('Tìm điểm khác: chạm đúng mọi điểm → 3 sao (ngang)', (tester) async {
    final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', 'spot', 'Tìm điểm khác'), size: const Size(900, 600));
    final diffs = SpotView.debugDiffs!;
    final page = 'fish';
    for (final i in diffs.toList()) {
      // một điểm thuộc vùng i nằm trên cùng
      final b = pageRegions(page)[i].bounds;
      Offset? pt;
      for (var y = b.top + 1; y < b.bottom && pt == null; y += 1) {
        for (var x = b.left + 1; x < b.right; x += 1) {
          if (hitRegion(page, Offset(x, y)) == i) {
            pt = Offset(x, y);
            break;
          }
        }
      }
      final r = tester.getRect(find.byKey(const Key('spot-b')));
      await tester.tapAt(r.topLeft + Offset(pt!.dx * r.width / 400, pt.dy * r.height / 300));
      await tester.pump();
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  testWidgets('Khác nhóm và Quy luật dựng được, trả lời đúng câu đầu', (tester) async {
    for (final kind in ['odd', 'pattern']) {
      final p = await pumpGame(tester, logicModule, 'logic', levelOf('logicLevels', kind));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('choice-x')), findsNothing);
      expect(find.byType(EmojiImage), findsWidgets);
      await unmount(tester, p);
    }
  });
}
