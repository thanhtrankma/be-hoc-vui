// Khung test cho game đảo học của agent C: dựng GameContext giả, ghi lại tiến độ/kết quả.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late ContentBundle bundle;

Future<void> loadBundle() async {
  Motion.enabled = false;
  bundle = await loadContentBundle(rootBundle);
}

class Played {
  Played(this.store, this.audio);
  final AppStore store;
  final SilentAudio audio;
  int? stars;
  (int, int) progress = (0, 0);
  final List<String> buddy = [];
  bool buddyVisible = true;
  bool aborted = false;
}

/// Dựng game của đảo (island.game == gameId) ở bài li.
Future<Played> pumpGame(WidgetTester tester, GameModule module, String gameId, int li, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance());
  store.addProfile('Na', 'robot');
  final audio = SilentAudio(voice: bundle.voice, store: store);
  final played = Played(store, audio);
  final island = bundle.data.islands.firstWhere((i) => i.game == gameId);
  final ctx = GameContext(
    island: island,
    levelIndex: li,
    level: levelData(island, bundle.content, li),
    content: bundle.content,
    data: bundle.data,
    profile: store.profile!,
    tier: 1,
    audio: audio,
    i18n: const I18n('vi'),
    store: store,
    buddyImg: 'Robot',
    isAborted: () => played.aborted,
    onProgress: (i, n) => played.progress = (i, n),
    onBuddy: played.buddy.add,
    onBuddyVisible: (v) => played.buddyVisible = v,
    onRecord: (_) {},
    onFinish: (r) => played.stars = r.stars,
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
        body: SafeArea(child: PhotoScope(enabled: true, child: Builder(builder: (context) => module.build(context, ctx)))),
      ),
    ),
  ));
  await tester.pump();
  return played;
}

/// Bơm khung hình tới khi cond đúng (tối đa ~maxMs mili giây giả).
Future<void> pumpUntil(WidgetTester tester, bool Function() cond, {int maxMs = 60000, int stepMs = 50}) async {
  for (var t = 0; t < maxMs && !cond(); t += stepMs) {
    await tester.pump(Duration(milliseconds: stepMs));
  }
  expect(cond(), isTrue, reason: 'pumpUntil hết giờ');
}

/// Gỡ widget, chờ timer còn lại chạy hết.
Future<void> unmount(WidgetTester tester, Played p) async {
  p.aborted = true;
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

int levelOf(String key, String kind, [String? name]) {
  final l = bundle.content.list(key);
  return l.indexWhere((x) => x['kind'] == kind && (name == null || x['name'] == name));
}
