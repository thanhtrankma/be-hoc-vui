// Khung test chung cho game Khu vui chơi 2 (agent F): dựng FunGameContext giả, chạy game canvas,
// bơm khung hình (dt 50 ms) + giả lập chạm cho tới khi game gọi ctx.finish(FunResult).
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

late ContentBundle bundle;

/// Gọi trong main() của file test: nạp nội dung + hình thật (ngoài fake-async) để game vẽ đủ.
void setUpFunMore({List<String> sheetNames = const [], List<String> imgs = const []}) {
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
    await sheets(sheetNames);
    await loadAll(imgs);
    loadTimeout = const Duration(milliseconds: 20);
  });
}

class FunRun {
  FunResult? result;
  bool finished = false;
  late SilentAudio audio;
  late FunGameContext ctx;
  final saved = <Json>[];
}

/// Chạy game; [input] gọi mỗi 0,25 s game (i = số lần gọi) để chạm/vuốt. Trả về khi game xong hoặc hết [maxSeconds].
Future<FunRun> playFun(WidgetTester tester, FunGameFn run,
    {int level = 0, bool bot = false, String lang = 'vi', Size size = const Size(390, 760), double maxSeconds = 150,
    Json? carry, Future<void> Function(WidgetTester t, int i, Size size)? input, String hero = 'Robot'}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = AppStore(null);
  store.addProfile('Na', 'robot');
  final r = FunRun()..audio = SilentAudio(store: store);
  var alive = true;
  r.ctx = FunGameContext(
    gameId: 'test',
    heroImg: hero,
    level: level,
    content: bundle.content,
    data: bundle.data,
    profile: store.profile!,
    audio: r.audio,
    i18n: I18n(lang),
    store: store,
    carry: carry ?? {},
    free: false,
    isAlive: () => alive,
    onSaveGear: r.saved.add,
    onLevelUp: () {},
    onFinish: (res) {
      r.finished = true;
      r.result = res;
    },
  );
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: FunCanvas(ctx: r.ctx, run: run, bot: bot))));
  var tick = 0;
  for (var ms = 0; ms < maxSeconds * 1000 && !r.finished; ms += 50) {
    await tester.pump(const Duration(milliseconds: 50));
    if (input != null && ms % 250 == 0 && !r.finished) await input(tester, tick++, size);
  }
  alive = false;
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  return r;
}
