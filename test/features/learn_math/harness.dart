// Khung test cho các đảo của agent B: dựng một GameModule trong stage giả (như PlayScreen) và ghi lại kết quả.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/math/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Harness {
  Harness(this.audio, this.store);
  final SilentAudio audio;
  final AppStore store;
  int? stars;
  int progI = 0, progN = 0;
  bool buddyVisible = true;
  final List<String> buddy = [];
  final List<QuizRecord> records = [];
}

Future<Harness> pumpGame(
  WidgetTester tester,
  ContentBundle bundle,
  GameModule module, {
  required String island,
  required int li,
  Size size = const Size(1024, 768),
  String lang = 'vi',
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  store.setSetting('lang', lang);
  final p = store.addProfile('Na', 'robot');
  final audio = SilentAudio(voice: bundle.voice, store: store);
  final h = Harness(audio, store);
  final isl = bundle.data.island(island)!;
  var aborted = false;
  addTearDown(() => aborted = true);
  debugMathQuiz = null;
  final ctx = GameContext(
    island: isl,
    levelIndex: li,
    level: levelData(isl, bundle.content, li),
    content: bundle.content,
    data: bundle.data,
    profile: p,
    tier: 0,
    audio: audio,
    i18n: I18n(lang),
    store: store,
    buddyImg: 'Robot',
    isAborted: () => aborted,
    onProgress: (i, n) {
      h.progI = i;
      h.progN = n;
    },
    onBuddy: h.buddy.add,
    onBuddyVisible: (v) => h.buddyVisible = v,
    onRecord: h.records.add,
    onFinish: (r) => h.stars = r.stars,
    onExit: () {},
    onGate: (_) async => true,
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentBundleProvider.overrideWithValue(bundle),
      storeProvider.overrideWith((ref) => store),
      audioProvider.overrideWithValue(audio),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const SizedBox(height: 90), // thanh trên của PlayScreen
          Expanded(child: PhotoScope(enabled: true, child: Builder(builder: (c) => module.build(c, ctx)))),
        ]),
      ),
    ),
  ));
  await tester.pump();
  return h;
}

/// Trả lời đúng mọi câu quiz (đọc đáp án từ debugMathQuiz) đến khi game gọi finish.
Future<void> playQuiz(WidgetTester tester, Harness h, {int maxSteps = 400}) async {
  for (var k = 0; k < maxSteps && h.stars == null; k++) {
    await tester.pump(const Duration(milliseconds: 100));
    final qs = debugMathQuiz;
    if (qs == null || h.progI >= qs.length) continue;
    final f = find.byKey(ValueKey('mc-${qs[h.progI].answer}')).hitTestable();
    if (f.evaluate().isEmpty) continue;
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 1500));
  }
}

/// Bơm thời gian cho tới khi điều kiện đúng.
Future<void> pumpUntil(WidgetTester tester, bool Function() ok, {int maxMs = 20000, int step = 100}) async {
  for (var t = 0; t < maxMs && !ok(); t += step) {
    await tester.pump(Duration(milliseconds: step));
  }
}

/// Gỡ cây widget và chạy hết timer còn lại.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}
