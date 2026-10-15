// Tiện ích kiểm thử Khu vui chơi (agent E): dựng FunGameContext/GameContext giả, chạy game canvas không cần widget.
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/fun/hub/funcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FunEnv {
  FunEnv(this.bundle, this.store, this.audio);
  final ContentBundle bundle;
  final AppStore store;
  final SilentAudio audio;
  FunResult? result;
  bool finished = false;
  int levelUps = 0;
  Json? gear;
  bool alive = true;

  FunGameContext ctx(String id, {int level = 0, Json? carry, String lang = 'vi', bool free = false}) => FunGameContext(
        gameId: id,
        heroImg: 'Man superhero',
        level: level,
        content: bundle.content,
        data: bundle.data,
        profile: store.profile!,
        audio: audio,
        i18n: I18n(lang),
        store: store,
        carry: carry ?? {},
        free: free,
        isAlive: () => alive,
        onSaveGear: (c) => gear = c,
        onLevelUp: () => levelUps++,
        onFinish: (r) {
          finished = true;
          result = r;
        },
      );

  int stars = 0;
  final progress = <(int, int)>[];
  final buddy = <String>[];

  GameContext gameCtx(String islandId, int li) {
    final isl = bundle.data.island(islandId)!;
    return GameContext(
      island: isl,
      levelIndex: li,
      level: bundle.content.level('arcadeLevels', li),
      content: bundle.content,
      data: bundle.data,
      profile: store.profile!,
      tier: 2,
      audio: audio,
      i18n: const I18n('vi'),
      store: store,
      buddyImg: 'Robot',
      isAborted: () => !alive,
      onProgress: (i, n) => progress.add((i, n)),
      onBuddy: buddy.add,
      onBuddyVisible: (_) {},
      onRecord: (_) {},
      onFinish: (r) {
        finished = true;
        stars = r.stars;
      },
      onExit: () {},
      onGate: (_) async => true,
    );
  }

  /// ProviderScope cho widget test.
  Widget scope(Widget child, {Size? size}) => ProviderScope(
        overrides: [
          contentBundleProvider.overrideWithValue(bundle),
          storeProvider.overrideWith((ref) => store),
          audioProvider.overrideWithValue(audio),
        ],
        child: MaterialApp(home: Scaffold(body: size == null ? child : Center(child: SizedBox.fromSize(size: size, child: child)))),
      );
}

ContentBundle? _bundle;

/// Gọi trong setUpAll của mỗi file test.
Future<ContentBundle> loadBundle() async {
  Motion.enabled = false;
  return _bundle ??= await loadContentBundle(rootBundle);
}

Future<FunEnv> makeEnv({Map<String, Object> prefs = const {}}) async {
  final bundle = await loadBundle();
  SharedPreferences.setMockInitialValues(prefs);
  final store = AppStore(await SharedPreferences.getInstance());
  store.addProfile('Na', 'robot');
  final audio = SilentAudio(voice: bundle.voice, store: store);
  return FunEnv(bundle, store, audio);
}

/// Chạy game canvas tới khi có kết quả (tối đa maxSec giây mô phỏng). step: điều khiển mỗi bước (t = giây đã chạy).
/// Cứ ~1 giây vẽ thử một khung để kiểm tra mã vẽ không lỗi.
FunResult? runGame(FunCanvasGame g, {double w = 800, double h = 600, double maxSec = 200, double dt = 1 / 30, void Function(double t)? step}) {
  g.setSize(w, h);
  var t = 0.0;
  var nextPaint = 0.0;
  while (t < maxSec) {
    step?.call(t);
    final r = g.update(dt);
    if (t >= nextPaint) {
      paintOnce(g);
      nextPaint += 1;
    }
    if (r != null) {
      paintOnce(g);
      return r;
    }
    t += dt;
  }
  return null;
}

void paintOnce(FunCanvasGame g) {
  final rec = ui.PictureRecorder();
  g.paint(Canvas(rec));
  rec.endRecording().dispose();
}
