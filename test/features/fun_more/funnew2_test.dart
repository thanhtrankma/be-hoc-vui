import 'package:be_vui_hoc/features/fun/more/funnew2.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(
    sheetNames: ['creatures/dino', 'plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx', 'racing/racing', 'puzzle/puzzle'],
    imgs: [
      'T-Rex', 'Coin', 'Bird', 'Bat', 'Cloud', 'Red heart', 'Cactus', 'Rock', 'Fire', 'Frog', 'Wood', 'Lotus', 'Glowing star', //
      'Robot', 'Ghost', 'Cherries', 'Red apple', 'Banana', 'Grapes', 'Strawberry', 'Collision',
    ],
  );

  test('hình đã nạp thật', () => expect(imgCache.containsKey('Ghost'), isTrue));

  test('đủ 5 game', () => expect(funnew2Games.keys, containsAll(['runner', 'frogger', 'pong', 'pacman', 'match3'])));

  testWidgets('runner: chạm để nhảy, tự né tới đích', (t) async {
    final r = await playFun(t, runner, bot: true, input: (t, i, s) async {
      if (i == 9) await t.tapAt(Offset(s.width * .5, s.height * .5));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:jump'));
  });

  testWidgets('runner: không chơi thì vấp ngã', (t) async {
    final r = await playFun(t, runner, level: 30, lang: 'en');
    expect(r.finished, isTrue);
    expect(r.result!.win, isFalse);
    expect(r.audio.log, contains('sfx:hit'));
  });

  testWidgets('frogger: vuốt lên, tự qua đường', (t) async {
    final r = await playFun(t, frogger, bot: true, input: (t, i, s) async {
      if (i == 9) await t.dragFrom(Offset(s.width * .5, s.height * .8), const Offset(0, -80));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:jump'));
  });

  testWidgets('frogger: cấp cao có sông, chạm liên tục', (t) async {
    final r = await playFun(t, frogger, level: 40, lang: 'en', input: (t, i, s) async {
      if (i >= 8) await t.tapAt(Offset(s.width * .5, 130));
    });
    expect(r.finished, isTrue);
    expect(r.audio.log, contains('sfx:hit'));
  });

  testWidgets('pong: kéo vợt, tự đánh tới khi xong', (t) async {
    final r = await playFun(t, pong, bot: true, input: (t, i, s) async {
      if (i % 5 == 0) await t.dragFrom(Offset(s.width * .3, s.height * .8), Offset(s.width * .3, 0));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:pop'));
  });

  testWidgets('pong: không đỡ thì máy thắng', (t) async {
    final r = await playFun(t, pong, level: 25, lang: 'en', input: (t, i, s) async {
      if (i % 4 == 0) await t.tapAt(Offset(10, s.height * .9));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
  });

  testWidgets('pacman: chạm/vuốt, tự ăn hết đậu', (t) async {
    final r = await playFun(t, pacman, bot: true, input: (t, i, s) async {
      if (i == 9) await t.dragFrom(Offset(s.width * .5, s.height * .5), const Offset(60, 0));
      if (i == 10) await t.tapAt(Offset(s.width * .5, s.height * .9));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:count'));
  });

  testWidgets('match3: vuốt đổi chỗ, tự ghép tới khi xong', (t) async {
    final r = await playFun(t, match3, bot: true, input: (t, i, s) async {
      // Bảng 7×7, cs = 52 khi rộng 390: vuốt ô (1,1) sang phải
      if (i == 9) await t.dragFrom(const Offset(13 + 52 * 1.5, 160 + 52 * 1.5), const Offset(52, 0));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:tap'));
    expect(r.audio.log, contains('sfx:coin'));
  });
}
