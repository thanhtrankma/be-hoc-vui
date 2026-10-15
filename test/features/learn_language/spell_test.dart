import 'package:be_vui_hoc/features/learn/language/spell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('placeTone như web', () {
    expect(placeTone('o', 'huyền'), 'ò');
    expect(placeTone('ương', 'sắc'), 'ướng');
    expect(placeTone('oa', 'huyền'), 'oà');
    expect(placeTone('ai', 'hỏi'), 'ải');
  });

  const kinds = ['tone', 'onset', 'rime', 'build', 'listen', 'readword', 'sentence', 'rule', 'readsent', 'cloze'];
  for (final kind in kinds) {
    testWidgets('Ghép vần "$kind": chơi đúng hết → 3 sao (dọc + ngang)', (tester) async {
      final bundle = await tester.runAsync(testBundle);
      final levels = bundle!.content.list('spellLevels');
      final idx = [for (var i = 0; i < levels.length; i++) if (levels[i]['kind'] == kind) i];
      expect(idx, isNotEmpty);
      // Bài đầu và bài cuối của loại (bài cuối thường có know/words/rimes của Học cùng lớp).
      for (final (k, li) in [idx.first, idx.last].indexed) {
        final run = await pumpGame(tester, spellModule, 'spell', li, size: k == 0 ? const Size(390, 844) : const Size(844, 390));
        await answerQuiz(tester, run, maxSteps: 80);
        expect(run.stars, 3, reason: 'bài $li');
        expect(run.records, isNotEmpty);
        await unmount(tester);
      }
    });
  }

  testWidgets('Ghép vần: 3 câu đúng liền hiện huy hiệu 🔥', (tester) async {
    final bundle = await tester.runAsync(testBundle);
    final levels = bundle!.content.list('spellLevels');
    final li = levels.indexWhere((l) => l['kind'] == 'onset');
    final run = await pumpGame(tester, spellModule, 'spell', li);
    // 3 câu đúng liền → huy hiệu chuỗi.
    for (var k = 0; k < 3; k++) {
      await tester.tap(find.byKey(ValueKey('choice-${quizAnswer()}')).first);
      await tester.pump(const Duration(milliseconds: 200));
      if (k == 2) expect(find.byKey(const Key('quiz-combo')), findsOneWidget);
      await settle(tester);
    }
    expect(run.audio.log, contains('sfx:power'));
    await unmount(tester);
  });
}
