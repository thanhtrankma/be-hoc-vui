import 'package:be_vui_hoc/features/learn/language/trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Tô hết các nét của chữ đang hiện bằng ngón tay giả.
Future<void> traceCurrent(WidgetTester tester, {bool reverse = false}) async {
  final board = tester.widget<TraceBoard>(find.byType(TraceBoard));
  final box = tester.renderObject<RenderBox>(find.byKey(const Key('trace-board')));
  final scale = box.size.width / 112;
  Offset toGlobal(Offset p) => box.localToGlobal(Offset((p.dx + 6) * scale, p.dy * scale));
  for (final path in glyphPaths(board.ch)) {
    var pts = strokeSamples(path);
    if (reverse) pts = pts.reversed.toList();
    final gesture = await tester.startGesture(toGlobal(pts.first));
    for (var k = 1; k < pts.length; k += 2) {
      await gesture.moveTo(toGlobal(pts[k]));
    }
    await gesture.moveTo(toGlobal(pts.last));
    await gesture.up();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mọi chữ trong traceLevels có nét, mỗi nét là một đường liền', () async {
    final b = await testBundle();
    for (final lv in b.content.list('traceLevels')) {
      for (final ch in (lv['chars'] as List).cast<String>()) {
        expect(kGlyphs.containsKey(ch), isTrue, reason: ch);
        for (final p in glyphPaths(ch)) {
          expect(p.computeMetrics().length, 1, reason: ch);
          expect(strokeSamples(p).length, greaterThan(2), reason: ch);
        }
      }
    }
  });

  testWidgets('Tập viết bài 1: tô đúng hết các chữ số → 3 sao', (tester) async {
    final run = await pumpGame(tester, traceModule, 'trace', 0);
    final n = run.ctx.level!['chars'].length as int;
    for (var k = 0; k < n; k++) {
      expect(run.stars, isNull);
      await traceCurrent(tester);
      expect(find.byKey(const Key('trace-reward')), findsOneWidget);
      await settle(tester, 1600);
    }
    expect(run.stars, 3);
    expect(run.progressI, n);
    expect(run.audio.log.where((l) => l == 'sfx:star').length, greaterThanOrEqualTo(n));
    await unmount(tester);
  });

  testWidgets('Tập viết: tô ngược chiều không ăn; chạm xa chỗ bắt đầu kêu "pop"', (tester) async {
    final b = await tester.runAsync(testBundle);
    final li = b!.content.list('traceLevels').indexWhere((l) => (l['chars'] as List).first == 'l');
    final run = await pumpGame(tester, traceModule, 'trace', li, size: const Size(844, 390));
    final ch = tester.widget<TraceBoard>(find.byType(TraceBoard)).ch;
    await traceCurrent(tester, reverse: true);
    expect(find.byKey(const Key('trace-reward')), findsNothing);
    expect(run.audio.log, contains('sfx:pop'));
    await traceCurrent(tester);
    expect(find.byKey(const Key('trace-reward')), findsOneWidget, reason: ch);
    await unmount(tester);
  });

  testWidgets('Tập viết: chơi hết một bài chữ cái nhiều nét (tablet)', (tester) async {
    final b = await tester.runAsync(testBundle);
    final levels = b!.content.list('traceLevels');
    final li = levels.length - 1;
    final run = await pumpGame(tester, traceModule, 'trace', li, size: const Size(1024, 768));
    for (var k = 0; k < (levels[li]['chars'] as List).length; k++) {
      await traceCurrent(tester);
      await settle(tester, 1600);
    }
    expect(run.stars, 3);
    await unmount(tester);
  });
}
