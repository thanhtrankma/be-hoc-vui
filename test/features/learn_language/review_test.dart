import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';
import 'package:be_vui_hoc/features/learn/language/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

const _keys = ['letters:b', 'vnwords:bò', 'tone:sắc', 'twoWords:t0', 'sentences:s0', 'ruleWords:r0', 'addFacts:0,1', 'en_animals:cat'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppStore, SilentAudio)> pumpReview(WidgetTester tester, {bool seed = true, String path = '/review'}) async {
    Motion.enabled = false;
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final bundle = (await tester.runAsync(testBundle))!;
    SharedPreferences.setMockInitialValues({});
    final store = AppStore((await tester.runAsync(SharedPreferences.getInstance))!);
    store.addProfile('Na', 'robot');
    if (seed) {
      for (final k in _keys) {
        store.recordAnswer('x', [k], false, const []);
      }
    }
    final audio = SilentAudio(voice: bundle.voice, store: store);
    final router = GoRouter(initialLocation: path, navigatorKey: rootNavigatorKey, routes: [
      GoRoute(path: '/map', builder: (c, s) => const Scaffold(body: Text('MAP'))),
      GoRoute(path: '/review', builder: (c, s) => const ReviewScreen(), routes: [
        GoRoute(path: ':mode', builder: (c, s) => ReviewScreen(mode: s.pathParameters['mode'])),
        GoRoute(path: ':mode/:item', builder: (c, s) => ReviewScreen(mode: s.pathParameters['mode'], item: s.pathParameters['item'])),
      ]),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return (store, audio);
  }

  test('mọi loại mục ôn đều dựng được câu hỏi', () async {
    final b = await testBundle();
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final p = store.addProfile('Na', 'robot');
    final tracker = LearnTracker(content: b.content, data: b.data, voice: b.voice, store: store);
    final audio = SilentAudio(voice: b.voice, store: store);
    for (final k in _keys) {
      final q = reviewQuestion(key: k, content: b.content, audio: audio, i18n: const I18n('vi'), tracker: tracker, learn: store.learn(p));
      expect(q, isNotNull, reason: k);
      expect(q!.choices.map((c) => c.id), contains(q.answer), reason: k);
      expect(q.choices.map((c) => c.id).toSet().length, q.choices.length, reason: k);
    }
  });

  testWidgets('Ôn tập: trả lời đúng hết → +sao, +1 vé, bảng Ôn xong', (tester) async {
    final (store, audio) = await pumpReview(tester);
    final stars0 = store.profile!.stars;
    final tickets0 = store.tickets(store.profile!);
    for (var k = 0; k < 10 && find.byKey(const Key('review-result')).evaluate().isEmpty; k++) {
      await tester.tap(find.byKey(ValueKey('choice-${QuizView.debugAnswer}')).first);
      await settle(tester);
    }
    expect(find.byKey(const Key('review-result')), findsOneWidget);
    expect(store.profile!.stars, stars0 + 3);
    expect(store.tickets(store.profile!), tickets0 + 1);
    expect(audio.log, contains('sfx:win'));
    await tester.tap(find.byKey(const Key('review-map')));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('Ôn tập: không có gì cần ôn → bảng thông báo rồi về bản đồ', (tester) async {
    await pumpReview(tester, seed: false);
    await tester.pumpAndSettle();
    expect(find.text('Không có gì cần ôn!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-map')));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
  });

  testWidgets('Ôn một mục (/review/x/<mục>)', (tester) async {
    await pumpReview(tester, seed: false, path: '/review/x/${Uri.encodeComponent('en_animals:cat')}');
    expect(QuizView.debugAnswer, 'cat');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
