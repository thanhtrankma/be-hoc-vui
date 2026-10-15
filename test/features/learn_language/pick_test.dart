import 'package:be_vui_hoc/features/learn/language/pick.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Chữ cái bài 1: trả lời đúng hết → 3 sao', (tester) async {
    final run = await pumpGame(tester, pickModule, 'letters', 0);
    expect(find.text('Tìm chữ…'), findsOneWidget);
    await answerQuiz(tester, run);
    expect(run.stars, 3);
    expect(run.records.length, kRound);
    expect(run.progressI, kRound);
    expect(run.audio.log, contains('sfx:correct'));
    await unmount(tester);
  });

  testWidgets('Chữ cái: chọn sai một lần → 2 sao; thẻ sai mờ đi', (tester) async {
    final run = await pumpGame(tester, pickModule, 'letters', 3, size: const Size(1024, 768));
    final ans = QuizView.debugAnswer;
    final wrong = find.byWidgetPredicate((w) => w is KeyedSubtree && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('choice-') && (w.key as ValueKey).value != 'choice-$ans');
    await tester.tap(wrong.first);
    await settle(tester, 1000);
    expect(run.audio.log, contains('sfx:wrong'));
    expect(run.buddy, contains('sad'));
    await answerQuiz(tester, run);
    expect(run.stars, 2);
    expect(run.records.first.picks, isNotEmpty);
    await unmount(tester);
  });

  testWidgets('Chữ cái: chữ hoa và chữ đầu', (tester) async {
    final run = await pumpGame(tester, pickModule, 'letters', 12);
    await answerQuiz(tester, run);
    expect(run.stars, 3);
    await unmount(tester);
    final run2 = await pumpGame(tester, pickModule, 'letters', 9, size: const Size(844, 390));
    await answerQuiz(tester, run2);
    expect(run2.stars, 3);
    await unmount(tester);
  });

  testWidgets('Tiếng Anh: mọi bộ dữ liệu dựng được câu hỏi, chơi xong bài màu sắc', (tester) async {
    final run = await pumpGame(tester, pickModule, 'english', 2, size: const Size(844, 390));
    await answerQuiz(tester, run);
    expect(run.stars, 3);
    await unmount(tester);
    final run2 = await pumpGame(tester, pickModule, 'english', 0);
    await answerQuiz(tester, run2);
    expect(run2.stars, 3);
    await unmount(tester);
  });
}
