// Chơi hết một bài của Số đếm, Toán vui (mọi dạng) và các bài quiz của Đời sống: trả lời đúng → finish(3 sao).
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/learn/math/common.dart';
import 'package:be_vui_hoc/features/learn/math/count.dart';
import 'package:be_vui_hoc/features/learn/math/life.dart';
import 'package:be_vui_hoc/features/learn/math/math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });

  group('helpers', () {
    test('near() gives distinct choices in range incl. answer', () {
      for (var i = 0; i < 50; i++) {
        final c = near(3, 4, 0, 10);
        expect(c.length, 4);
        expect(c.toSet().length, 4);
        expect(c, contains(3));
        expect(c.every((k) => k >= 0 && k <= 10), isTrue);
      }
      expect(near(1, 4, 1, 2).toSet(), {1, 2});
    });
    test('near100() two-digit distractors', () {
      for (var i = 0; i < 50; i++) {
        final c = near100(47);
        expect(c, contains(47));
        expect(c.length, 4);
        expect(c.every((k) => k > 0 && k < 100), isTrue);
      }
    });
  });

  testWidgets('Số đếm 1–3: chạm đếm rồi chọn đúng → 3 sao', (tester) async {
    final h = await pumpGame(tester, bundle, countModule, island: 'count', li: 0);
    final qs = debugMathQuiz!;
    expect(qs.length, 6);
    // Đếm: chạm hình đầu → gắn số 1, kêu "count".
    await tester.tap(find.byKey(const ValueKey('count-item-0')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.audio.log, contains('sfx:count'));
    expect(find.text('1'), findsWidgets);
    await playQuiz(tester, h);
    expect(h.stars, 3);
    expect(h.progI, 6);
    expect(h.records.length, 6);
    await unmount(tester);
  });

  testWidgets('Số đếm theo chục: chạm thanh chục, chọn đúng', (tester) async {
    final count = bundle.content.list('countLevels');
    final li = count.indexWhere((l) => l['tens'] == true && l['round'] != true);
    final h = await pumpGame(tester, bundle, countModule, island: 'count', li: li, size: const Size(390, 844));
    // Chạm hình lẻ trước khi đếm hết chục → báo sai.
    final one = find.byKey(const ValueKey('one-0'));
    if (one.evaluate().isNotEmpty) {
      await tester.tap(one.first);
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.audio.log, contains('sfx:wrong'));
    }
    await tester.tap(find.byKey(const ValueKey('ten-bar-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('10'), findsWidgets);
    await playQuiz(tester, h);
    expect(h.stars, 3);
    await unmount(tester);
  });

  testWidgets('Toán vui: mọi dạng bài chơi hết, đúng hết → 3 sao', (tester) async {
    final levels = bundle.content.list('mathLevels');
    final seen = <String>{};
    for (var li = 0; li < levels.length; li++) {
      final kind = levels[li]['kind'] as String;
      if (!seen.add(kind)) continue;
      final h = await pumpGame(tester, bundle, mathModule, island: 'math', li: li, size: li.isEven ? const Size(1024, 768) : const Size(390, 844));
      expect(debugMathQuiz, isNotEmpty, reason: kind);
      await playQuiz(tester, h);
      expect(h.stars, 3, reason: 'kind $kind');
      expect(tester.takeException(), isNull, reason: kind);
      await unmount(tester);
    }
    expect(seen.length, 21);
  });

  testWidgets('Toán vui: chọn sai → bớt sao', (tester) async {
    final h = await pumpGame(tester, bundle, mathModule, island: 'math', li: 0);
    await tester.pump(const Duration(milliseconds: 200));
    final q = debugMathQuiz!.first;
    final wrong = q.choices.firstWhere((c) => c.id != q.answer);
    await tester.tap(find.byKey(ValueKey('mc-${wrong.id}')).hitTestable().first);
    await tester.pump(const Duration(seconds: 1));
    expect(h.audio.log, contains('sfx:wrong'));
    await playQuiz(tester, h);
    expect(h.stars, 2);
    await unmount(tester);
  });

  testWidgets('Đời sống: dài–ngắn, cao–thấp, kẹp giấy, thước', (tester) async {
    final levels = bundle.content.list('lifeLevels');
    for (final kind in ['length', 'height', 'clips', 'ruler']) {
      final li = levels.indexWhere((l) => l['kind'] == kind);
      final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: li, size: kind == 'ruler' ? const Size(390, 844) : const Size(1024, 768));
      expect(debugMathQuiz!.length, 6);
      await playQuiz(tester, h);
      expect(h.stars, 3, reason: kind);
      expect(tester.takeException(), isNull, reason: kind);
      await unmount(tester);
    }
  });

  testWidgets('Tiếng Anh: chữ giờ đồng hồ theo ngôn ngữ', (tester) async {
    final li = bundle.content.list('mathLevels').indexWhere((l) => l['kind'] == 'clock');
    final h = await pumpGame(tester, bundle, mathModule, island: 'math', li: li, lang: 'en');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining("o'clock"), findsWidgets);
    await playQuiz(tester, h);
    expect(h.stars, 3);
    await unmount(tester);
  });
}
