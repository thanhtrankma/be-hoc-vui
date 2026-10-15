import 'package:be_vui_hoc/features/fun/hub/fun.dart';
import 'package:be_vui_hoc/features/fun/hub/funcore.dart';
import 'package:be_vui_hoc/features/fun/hub/funhunt.dart';
import 'package:be_vui_hoc/features/fun/hub/funmore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  testWidgets('mọi game canvas nạp sprite/hình thật rồi vẽ không lỗi (mọi cảnh)', (tester) async {
    final env = (await tester.runAsync(makeEnv))!;
    final makers = <String, FunCanvasGame Function(int lv)>{
      'catch': (lv) => CatchGame(env.ctx('catch', level: lv)),
      'whack': (lv) => WhackGame(env.ctx('whack', level: lv)),
      'fishing': (lv) => FishingGame(env.ctx('fishing', level: lv)),
      'stack': (lv) => StackGame(env.ctx('stack', level: lv)),
      'breakout': (lv) => BreakoutGame(env.ctx('breakout', level: lv)),
      'flappy': (lv) => FlappyGame(env.ctx('flappy', level: lv)),
      'sling': (lv) => SlingGame(env.ctx('sling', level: lv), level: lv),
      'hunt': (lv) => HuntGame(env.ctx('hunt', level: lv, carry: {
            'skills': {for (final k in kHuntSkills.keys) k: 3}
          }), bot: true),
    };
    for (final e in makers.entries) {
      for (final lv in [0, 15, 59]) {
        final g = e.value(lv);
        await tester.runAsync(g.load);
        expect(g.sheets.values.every((s) => s != null), isTrue, reason: '${e.key}: ${g.sheets}');
        expect(g.img.has('Coin'), isTrue);
        g.setSize(lv == 15 ? 390 : 1024, lv == 15 ? 844 : 700);
        for (var i = 0; i < 150; i++) {
          g.update(1 / 30);
          if (e.key == 'flappy' && i % 12 == 0) (g as FlappyGame).flap();
          if (i % 15 == 0) paintOnce(g);
        }
        paintOnce(g);
      }
    }
  });
}
