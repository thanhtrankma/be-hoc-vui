import 'package:be_vui_hoc/features/fun/more/funnew4.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(
      sheetNames: ['play/robot', 'play/kidboy', 'play/kidgirl', 'play/woman', 'play/man', 'play/items', 'play/critters'],
      imgs: ['Coin', 'Red heart', 'Mushroom', 'Tomato', 'Olive', 'Bell pepper', 'Carrot', 'Seedling', 'Droplet', 'Fire', 'Fire engine', 'Glowing star']);

  test('hình đã nạp thật', () => expect(imgCache.containsKey('Coin'), isTrue));

  test('đủ 4 game', () => expect(funnew4Games.keys, containsAll(['pizza', 'farm', 'firefight', 'hidden'])));

  testWidgets('pizza: tự rắc đủ nguyên liệu rồi giao bánh', (t) async {
    final r = await playFun(t, pizza, bot: true, input: (t, i, s) async {
      if (i % 6 == 0) await t.tapAt(Offset(s.width * .05, s.height * .2)); // chạm tường: không làm gì
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, containsAll(['sfx:pop', 'sfx:correct', 'sfx:win']));
  });

  testWidgets('pizza: chạm khay + Giao sai số thì mất tim', (t) async {
    final r = await playFun(t, pizza, lang: 'en', input: (t, i, s) async {
      if (i.isOdd) {
        await t.tapAt(Offset(s.width * .14, s.height * .92)); // ô nguyên liệu đầu tiên
      } else {
        await t.tapAt(Offset(s.width * .78, s.height * .74)); // nút Giao
      }
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, containsAll(['sfx:pop', 'sfx:wrong']));
  });

  testWidgets('farm: chạm ô đất gieo → tưới → hái', (t) async {
    final r = await playFun(t, farm, input: (t, i, s) async {
      if (i % 3 == 0) await t.tapAt(Offset(s.width * .5, s.height * .535));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, containsAll(['sfx:pop', 'sfx:splash']));
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:coin'));
  });

  testWidgets('farm: tự chơi cấp 20 có sâu bọ', (t) async {
    final r = await playFun(t, farm, level: 20, bot: true, hero: 'Princess', input: (t, i, s) async {
      if (i % 10 == 0) await t.tapAt(Offset(s.width * .5, s.height * .1));
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:coin'));
  });

  testWidgets('firefight: xe cứu hoả tự dập lửa', (t) async {
    final r = await playFun(t, firefight, bot: true, input: (t, i, s) async {
      if (i == 3) await t.tapAt(Offset(s.width * .3, s.height * .95)); // chạm đường (trước khi vào game)
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, containsAll(['sfx:correct', 'sfx:win']));
  });

  testWidgets('firefight: chỉ chạy xe trên đường, lửa cháy lâu là mất tim', (t) async {
    final r = await playFun(t, firefight, lang: 'en', input: (t, i, s) async {
      if (i % 4 == 0) await t.tapAt(Offset(s.width * (i % 8 == 0 ? .2 : .8), s.height * .95));
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isFalse);
    expect(r.audio.log, contains('sfx:hit'));
  });

  testWidgets('hidden: tự tìm đủ đồ', (t) async {
    final r = await playFun(t, hidden, bot: true, input: (t, i, s) async {
      if (i == 2) await t.tapAt(Offset(s.width * .5, s.height * .5));
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, containsAll(['sfx:correct', 'sfx:win']));
  });

  testWidgets('hidden: chạm lung tung bị trừ giây tới hết giờ', (t) async {
    final r = await playFun(t, hidden, lang: 'en', level: 30, input: (t, i, s) async {
      await t.tapAt(Offset(s.width * (.1 + (i % 9) * .1), s.height * (.2 + (i % 5) * .1)));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:wrong'));
  });
}
