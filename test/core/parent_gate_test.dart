// Khoá bố mẹ: phép nhân 2 chữ số × 1 chữ số (12–49 × 3–9), nhập bằng bàn phím số; sai thì xoá ô và hỏi tiếp.
import 'dart:math';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });
  tearDown(() => debugGateRandom = null);

  Future<List<bool?>> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final results = <bool?>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(SilentAudio(voice: bundle.voice, store: store)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(child: TextButton(key: const Key('open'), onPressed: () async => results.add(await parentGate(context, ref)), child: const Text('open'))),
          ),
        ),
      ),
    ));
    return results;
  }

  (int, int) question(WidgetTester tester) {
    final m = RegExp(r'^(\d+) × (\d+) = \?$').firstMatch(tester.widget<Text>(find.textContaining(' × ')).data!)!;
    return (int.parse(m[1]!), int.parse(m[2]!));
  }

  Future<void> type(WidgetTester tester, String s) async {
    for (final ch in RegExp(r'OK|.').allMatches(s).map((m) => m[0]!)) {
      await tester.tap(find.byKey(Key('gate-$ch')));
      await tester.pump();
    }
  }

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: find.byKey(const Key('gate-ans')), matching: find.byType(Text))).data!;

  testWidgets('phép tính luôn là 12–49 × 3–9', (tester) async {
    expect((kGateAMin, kGateAMax, kGateBMin, kGateBMax), (12, 49, 3, 9));
    final results = await pumpGate(tester);
    final seenA = <int>{}, seenB = <int>{};
    for (var seed = 0; seed < 40; seed++) {
      debugGateRandom = Random(seed);
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      final (a, b) = question(tester);
      expect(a, inInclusiveRange(12, 49));
      expect(b, inInclusiveRange(3, 9));
      seenA.add(a);
      seenB.add(b);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
    }
    expect(results, List.filled(40, false));
    expect(seenA.length, greaterThan(15));
    expect(seenB.length, greaterThan(4));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sai → xoá ô, hỏi phép MỚI, vẫn mở; đúng (3 chữ số) → true', (tester) async {
    debugGateRandom = _Fixed([49 - 12, 9 - 3, 22 - 12, 5 - 3]); // 49 × 9 = 441, rồi 22 × 5 = 110
    final results = await pumpGate(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(question(tester), (49, 9));
    await type(tester, '44');
    expect(shown(tester), '44');
    await type(tester, '⌫');
    expect(shown(tester), '4');
    await type(tester, '40OK');
    await tester.pumpAndSettle();
    expect(shown(tester), '?');
    expect(find.text('Dành cho bố mẹ'), findsOneWidget);
    expect(results, isEmpty);
    expect(question(tester), (22, 5)); // phép tính đổi sau khi sai
    await type(tester, '441OK'); // đáp số của phép cũ không còn đúng
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(question(tester), (49, 9));
    await type(tester, '4419'); // tối đa 3 chữ số
    expect(shown(tester), '441');
    await type(tester, 'OK');
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.text('Dành cho bố mẹ'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sai → phép mới luôn khác phép vừa hỏi (kể cả khi nguồn ngẫu nhiên lặp lại)', (tester) async {
    debugGateRandom = _Fixed([49 - 12, 9 - 3]); // luôn ra 49 × 9
    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(question(tester), (49, 9));
    await type(tester, '1OK');
    await tester.pumpAndSettle();
    final (a, b) = question(tester);
    expect((a, b), isNot((49, 9)));
    expect(a, inInclusiveRange(12, 49));
    expect(b, inInclusiveRange(3, 9));
    await tester.pump(const Duration(seconds: 3));
  });
}

/// Trả lần lượt các giá trị cho nextInt.
class _Fixed implements Random {
  _Fixed(this.seq);
  final List<int> seq;
  int i = 0;
  @override
  int nextInt(int max) => seq[i++ % seq.length];
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}
