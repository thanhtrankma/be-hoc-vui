import 'package:be_vui_hoc/features/fun/more/funnew3.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(sheetNames: [
    'play/robot', 'play/kidboy', 'play/kidgirl', 'play/woman', 'play/man', 'play/critters', 'play/items', 'play/sea',
  ], imgs: [
    'Red heart', 'Coin', 'Basketball', 'Chequered flag', 'Musical notes', 'Glowing star', 'Flag in hole', ...themeImgs(0),
  ]);

  test('sprite play đã nạp thật', () async {
    final sh = await playSheets(['robot', 'items']);
    expect(sh['robot'], isNotNull);
    expect(sh['items']!.anims.containsKey('coin'), isTrue);
  });

  test('đủ 6 game', () => expect(funnew3Games.keys, containsAll(['lanes', 'swim', 'hoops', 'hurdles', 'dance', 'golf'])));

  testWidgets('lanes: chạy 3 làn, vuốt đổi làn, tự né tới đích', (t) async {
    final r = await playFun(t, lanes, bot: true, input: (t, i, s) async {
      if (i % 12 == 3) await t.dragFrom(Offset(s.width * .5, s.height * .7), const Offset(0, 80)); // vuốt xuống
      if (i % 12 == 9) await t.dragFrom(Offset(s.width * .5, s.height * .8), const Offset(0, -80)); // vuốt lên
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:flip'));
  });

  testWidgets('swim: kéo ngón tay, cá con tự nhặt ngọc', (t) async {
    final r = await playFun(t, swim, bot: true, level: 10, input: (t, i, s) async {
      if (i % 6 == 0) await t.dragFrom(Offset(s.width * .3, s.height * .5), Offset(s.width * .3, -s.height * .1));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:coin'));
  });

  testWidgets('hoops: vuốt ném bóng, bot ném vào rổ', (t) async {
    final r = await playFun(t, hoops, bot: true, input: (t, i, s) async {
      if (i % 8 == 0) await t.dragFrom(Offset(s.width * .2, s.height * .7), Offset(s.width * .3, -s.height * .3));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:shoot'));
  });

  testWidgets('hurdles: chạm để nhảy rào, về đích có hạng', (t) async {
    final r = await playFun(t, hurdles, lang: 'en', input: (t, i, s) async {
      if (i % 2 == 0) await t.tapAt(Offset(s.width * .5, s.height * .5));
    });
    expect(r.finished, isTrue);
    expect(r.result!.pos, isNotNull);
    expect(r.audio.log, contains('sfx:jump'));
  });

  testWidgets('dance: tự chạm đúng nốt, bài hát hết thì thắng', (t) async {
    final r = await playFun(t, dance, bot: true, input: (t, i, s) async {
      if (i % 5 == 0) await t.tapAt(Offset(s.width * .5, s.height * .88));
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log.any((e) => e.startsWith('note:')), isTrue);
  });

  testWidgets('dance: không chạm thì lỡ nhịp, thua', (t) async {
    final r = await playFun(t, dance, level: 59);
    expect(r.finished, isTrue);
    expect(r.result!.win, isFalse);
    expect(r.audio.log, contains('sfx:wrong'));
  });

  testWidgets('golf: kéo ngược thả bóng, bot đưa bóng qua tường vào lỗ', (t) async {
    final r = await playFun(t, golf, bot: true, level: 14, input: (t, i, s) async {
      if (i == 10) await t.dragFrom(Offset(s.width * .5, s.height * .9), const Offset(0, 60));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:shoot'));
  });

  testWidgets('golf: chỉ kéo tay, hết gậy thì kết thúc', (t) async {
    final r = await playFun(t, golf, level: 0, input: (t, i, s) async {
      // kéo ngược xuống từ giữa sân (bóng ở gần đáy, kéo xa → lực tối đa theo hướng lên)
      if (i % 6 == 0) await t.dragFrom(Offset(s.width * .5, s.height * .95), Offset(s.width * .1, 30));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:shoot'));
  });
}
