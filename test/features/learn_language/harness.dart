// Khung test cho trò của agent A: dựng GameContext giả (không cần PlayScreen), SilentAudio, dữ liệu thật.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ContentBundle? _bundle;

Future<ContentBundle> testBundle() async => _bundle ??= await loadContentBundle(rootBundle);

class GameRun {
  GameRun(this.ctx, this.audio, this.store);
  final GameContext ctx;
  final SilentAudio audio;
  final AppStore store;
  int? stars;
  int progressI = 0, progressN = 0;
  final List<QuizRecord> records = [];
  final List<String> buddy = [];
  bool exited = false;
}

/// Dựng trò `module` cho đảo islandId, bài li. size: kích thước màn (logic px).
Future<GameRun> pumpGame(WidgetTester tester, GameModule module, String islandId, int li,
    {Size size = const Size(390, 844), Map<String, Object> prefs = const {}, bool Function()? gate}) async {
  Motion.enabled = false;
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final bundle = await tester.runAsync(testBundle);
  SharedPreferences.setMockInitialValues(prefs);
  final prefsInst = (await tester.runAsync(SharedPreferences.getInstance))!;
  final store = AppStore(prefsInst);
  final p = store.profile ?? store.addProfile('Na', 'robot');
  final audio = SilentAudio(voice: bundle!.voice, store: store);
  final isl = bundle.data.island(islandId)!;
  late GameRun run;
  final levelsKey = {'letters': 'letterLevels', 'english': 'englishLevels', 'spell': 'spellLevels', 'trace': 'traceLevels', 'read': 'readLevels'}[islandId]!;
  final ctx = GameContext(
    island: isl,
    levelIndex: li,
    level: bundle.content.level(levelsKey, li),
    content: bundle.content,
    data: bundle.data,
    profile: p,
    tier: 0,
    audio: audio,
    i18n: const I18n('vi'),
    store: store,
    buddyImg: 'Robot',
    isAborted: () => false,
    onProgress: (i, n) {
      run.progressI = i;
      run.progressN = n;
    },
    onBuddy: (a) => run.buddy.add(a),
    onBuddyVisible: (_) {},
    onRecord: (q) => run.records.add(q),
    onFinish: (r) => run.stars = r.stars,
    onExit: () => run.exited = true,
    onGate: (_) async => gate?.call() ?? true,
  );
  run = GameRun(ctx, audio, store);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentBundleProvider.overrideWithValue(bundle),
      storeProvider.overrideWith((ref) => store),
      audioProvider.overrideWithValue(audio),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light(),
      home: SkyBackground(child: Scaffold(body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 84, 16, 18),
        child: PhotoScope(enabled: true, child: Builder(builder: (c) => module.build(c, ctx))),
      )))),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return run;
}

/// Chạm đáp án đúng của khuôn quiz cho tới khi xong bài (hoặc hết maxSteps câu).
Future<void> answerQuiz(WidgetTester tester, GameRun run, {int maxSteps = 60}) async {
  for (var k = 0; k < maxSteps && run.stars == null; k++) {
    final ans = QuizView.debugAnswer;
    final f = find.byKey(ValueKey('choice-$ans'));
    expect(f, findsWidgets, reason: 'không thấy thẻ đáp án $ans');
    await tester.tap(f.first, warnIfMissed: false);
    await settle(tester);
  }
}

/// Chạy hết các Future.delayed/hoạt ảnh một lần (không dùng pumpAndSettle vì có thể có vòng lặp).
Future<void> settle(WidgetTester tester, [int ms = 3000]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Gỡ widget để huỷ timer.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// Đáp án câu đang hiện của khuôn quiz.
Object? quizAnswer() => QuizView.debugAnswer;
