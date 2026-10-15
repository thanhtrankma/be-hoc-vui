import 'package:be_vui_hoc/features/fun/more/funnew5.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(sheetNames: ['play/robot', 'play/items', 'play/critters'],
      imgs: ['Locomotive', 'House', 'Red heart', 'Coin', 'Package', 'Delivery truck', 'Balloon', 'Cloud', 'Robot']);

  test('hình đã nạp thật', () => expect(imgCache.containsKey('Balloon'), isTrue));

  test('đủ 3 game', () => expect(funnew5Games.keys, containsAll(['trains', 'truckload', 'balloons'])));

  testWidgets('trains: chạm bẻ ghi, tự đưa tàu về ga', (t) async {
    final r = await playFun(t, trains, bot: true, input: (t, i, s) async {
      // cấp 0: 2 ga, chỗ bẻ ghi ở (W*.42, giữa hai ga)
      if (i % 8 == 4) await t.tapAt(Offset(s.width * .42, (170 + s.height - 40) / 2));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:flip'));
    expect(r.audio.log, contains('sfx:correct'));
  });

  testWidgets('trains: cấp cao 4 ga, tiếng Anh', (t) async {
    final r = await playFun(t, trains, level: 30, lang: 'en', bot: true, input: (t, i, s) async {
      if (i == 20) await t.tapAt(Offset(s.width * .5, s.height * .9));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
  });

  testWidgets('trains: không bẻ ghi thì có tàu lạc, rồi xong', (t) async {
    final r = await playFun(t, trains, level: 5, input: (t, i, s) async {
      if (i % 6 == 0) await t.tapAt(Offset(s.width * .42, (170 + s.height - 40) / 2));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:wrong'));
  });

  testWidgets('truckload: kéo thử khối hàng, tự xếp kín xe', (t) async {
    final r = await playFun(t, truckload, bot: true, input: (t, i, s) async {
      // cấp 0: khối đầu khay luôn có ô (0,0) ở góc trên-trái khay → kéo lên trời (sai chỗ)
      if (i % 2 == 0) {
        final ts = (s.width - 64) / 6;
        await t.dragFrom(Offset(16 + ts * .4, s.height * .56 + 16 + ts * .4), const Offset(0, -300));
      }
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:tap'));
    expect(r.audio.log, contains('sfx:wrong'));
    expect(r.audio.log, contains('sfx:pop'));
    expect(r.audio.log, contains('sfx:correct'));
  });

  testWidgets('truckload: không xếp thì hết giờ', (t) async {
    final r = await playFun(t, truckload, level: 40, lang: 'en', input: (t, i, s) async {
      if (i % 4 == 0) await t.tapAt(Offset(s.width * .3, s.height * .8));
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isFalse);
  });

  testWidgets('balloons: chạm bóng theo thứ tự', (t) async {
    final r = await playFun(t, balloons, bot: true, input: (t, i, s) async {
      await t.tapAt(Offset(4, s.height * .5)); // chạm chỗ trống
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isTrue);
    expect(r.audio.log, contains('sfx:pop'));
    expect(r.audio.log, contains('sfx:win'));
  });

  testWidgets('balloons: đếm lùi, có ong; chạm bừa thì mất tim', (t) async {
    final r = await playFun(t, balloons, level: 50, lang: 'en', input: (t, i, s) async {
      await t.tapAt(Offset(s.width * (.2 + (i % 7) * .1), s.height * (.3 + (i % 5) * .1)));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
  });
}
