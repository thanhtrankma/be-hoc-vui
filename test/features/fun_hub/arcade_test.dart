import 'package:be_vui_hoc/features/fun/hub/arcade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  Future<FunEnv> pumpArcade(WidgetTester tester, int li) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(makeEnv))!;
    final ctx = env.gameCtx('arcade', li);
    await tester.pumpWidget(env.scope(Builder(builder: (c) => arcadeModule.build(c, ctx)), size: const Size(860, 1000)));
    await tester.pump();
    await tester.pump();
    return env;
  }

  test('raceQ: phép tính trong phạm vi, 3 lựa chọn có đáp án', () async {
    final b = await loadBundle();
    for (final mode in ['add', 'sub', 'mix']) {
      for (var i = 0; i < 20; i++) {
        final q = raceQ({'mode': mode, 'max': 5}, b.content);
        expect(q.choices.length, 3);
        expect(q.choices, contains(q.answer));
        expect(q.answer, inInclusiveRange(0, 10));
      }
    }
  });

  for (final (li, mode) in [(0, 'letters'), (2, 'numbers'), (4, 'tones'), (6, 'english')]) {
    testWidgets('Bóng bay $mode: bắn trúng 8 bóng (có 1 lần sai) → 3 sao', (tester) async {
      final env = await pumpArcade(tester, li);
      final st = tester.state<BalloonViewState>(find.byType(BalloonView));
      expect(st.mode, mode);
      var wrongDone = false;
      for (var i = 0; i < 3000 && !env.finished; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (!st.alive) continue;
        if (!wrongDone && st.wrongKeys.isNotEmpty) {
          await tester.tapAt(tester.getCenter(find.byKey(st.wrongKeys.first)));
          wrongDone = true;
          continue;
        }
        final k = st.targetKeys;
        if (k.isNotEmpty) await tester.tapAt(tester.getCenter(find.byKey(k.first)));
      }
      expect(env.finished, isTrue);
      expect(st.hits, kBalloonGoal);
      // Lần sai đầu tiên được bỏ qua (starsFor(mistakes - 1)); bóng chồng nhau có thể làm chạm trúng/sai thêm.
      expect(env.stars, st.mistakes <= 1 ? 3 : (st.mistakes <= 3 ? 2 : 1));
      expect(env.progress.last, (8, 8));
      expect(env.buddy, contains('cheer'));
      expect(env.audio.log.where((l) => l.startsWith('say:')).length, greaterThanOrEqualTo(8));
    });
  }

  testWidgets('Đua xe: trả lời đúng 10 câu → về nhất 3 sao', (tester) async {
    final env = await pumpArcade(tester, 1);
    final st = tester.state<RaceViewState>(find.byType(RaceView));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(Key('race-choice-${st.q!.answer}')));
    }
    for (var i = 0; i < 20 && !env.finished; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(env.finished, isTrue);
    expect(env.stars, 3);
    expect(env.audio.log, contains('sfx:win'));
  });

  testWidgets('Đua xe: sai một lần thì bị khựng, không trả lời → xe máy về trước, 1 sao', (tester) async {
    final env = await pumpArcade(tester, 3);
    final st = tester.state<RaceViewState>(find.byType(RaceView));
    await tester.pump(const Duration(milliseconds: 100));
    final wrong = st.q!.choices.firstWhere((c) => c != st.q!.answer);
    await tester.tap(find.byKey(Key('race-choice-$wrong')));
    await tester.pump();
    // Đang khựng: đáp án đúng chưa được tính
    await tester.tap(find.byKey(Key('race-choice-${st.q!.answer}')));
    await tester.pump();
    expect(st.kid, 0);
    expect(st.mistakes, 1);
    for (var i = 0; i < 1300 && !env.finished; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(env.finished, isTrue);
    expect(env.stars, 1);
  });
}
