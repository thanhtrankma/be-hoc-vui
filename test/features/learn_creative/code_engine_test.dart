// Lõi đảo Lập trình: mọi bài trong content.json sinh được đề, lời giải đáp án chạy thắng, bài lặp buộc dùng lặp.
import 'dart:convert';
import 'dart:io';

import 'package:be_vui_hoc/features/learn/creative/code_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final content = jsonDecode(File('assets/data/content.json').readAsStringSync()) as Map<String, dynamic>;
  final levels = (content['codeLevels'] as List).cast<Map<String, dynamic>>();

  test('simulate + shortest trên vườn nhỏ', () {
    final m = Garden(n: 3, start: (0, 0), dir: 1, sprouts: [(2, 0)], rocks: {1});
    final res = shortest(m, ['U', 'R', 'D', 'L', 'W']);
    expect(res, isNotNull);
    expect(res!.len, 5); // D R R U W
    expect(simulate(m, res.prog).win, isTrue);
    final bump = simulate(m, ['R']);
    expect(bump.bump, isTrue);
    expect(bump.win, isFalse);
    // lặp: F W ×2
    final m2 = Garden(n: 4, start: (0, 0), dir: 1, sprouts: [(1, 0), (2, 0)]);
    expect(simulate(m2, [Rep(2, ['F', 'W'])]).win, isTrue);
    expect(progCost([Rep(2, ['F', 'W']), 'TR']), 4);
    expect(flatProg([Rep(2, ['F', 'W'])]).map((s) => s.at).toList(), ['0.0', '0.1', '0.0', '0.1']);
  });

  for (var li = 0; li < levels.length; li++) {
    final lv = levels[li];
    test('bài $li ${lv['kind']} ${lv['name']}', () {
      for (var rep = 0; rep < 4; rep++) {
        switch (lv['kind']) {
          case 'trace':
            final m = genTrace(lv)!;
            expect(m.end, isNotNull);
            final r = simulate(m, m.prog!);
            expect((r.x, r.y), m.end);
          case 'debug':
            final m = genDebug(lv)!;
            expect(simulate(m, m.prog!).win, isFalse);
            expect(simulate(m, m.sol).win, isTrue);
            expect(m.wrong, isNotNull);
          case 'loop':
            final m = genLoop(lv)!;
            expect(simulate(m, m.sol).win, isTrue);
            expect(progCost(m.sol) <= m.cap, isTrue);
            final flat = shortest(m, atoms(m.cmds));
            expect(flat == null || flat.len > m.cap, isTrue);
          default:
            final m = genGarden(lv)!;
            expect(simulate(m, m.sol).win, isTrue);
            expect(m.sol.length, lessThanOrEqualTo(lv['max'] as int));
            expect(m.cap, m.sol.length + (lv['spare'] as int));
        }
      }
    });
  }
}
