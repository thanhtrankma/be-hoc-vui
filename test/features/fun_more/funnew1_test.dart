import 'package:be_vui_hoc/features/fun/more/funnew1.dart';
import 'package:be_vui_hoc/features/fun/more/kit/funkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(sheetNames: ['gallery/gallery', 'plat/enemies', 'animals/round', 'fxa/fx', 'puzzle/puzzle', 'plat/tiles'],
      imgs: ['Red apple', 'Coin', 'Red heart', 'Bullseye', 'Glowing star', 'Cloud', 'Robot']);

  test('hình đã nạp thật', () => expect(imgCache.containsKey('Coin'), isTrue));

  test('đủ 4 game', () => expect(funnew1Games.keys, containsAll(['snake', 'gallery', 'blocks', 'jumper'])));

  testWidgets('snake: tự bò ăn hạt tới khi xong', (t) async {
    final r = await playFun(t, snake, bot: true, input: (t, i, s) async {
      if (i % 8 == 0) await t.tapAt(Offset(s.width * .7, s.height * .4));
    });
    expect(r.finished, isTrue);
    expect(r.result, isNotNull);
    expect(r.audio.log, contains('sfx:count'));
  });

  testWidgets('gallery: bắn bia 40 giây rồi xong', (t) async {
    final r = await playFun(t, gallery, bot: true, input: (t, i, s) async => t.tapAt(Offset(s.width * .5, s.height * .5)));
    expect(r.finished, isTrue);
    expect(r.result!.score, greaterThan(0));
    expect(r.audio.log, contains('sfx:shoot'));
  });

  testWidgets('blocks: chạm nút, khối chồng đầy là thua', (t) async {
    final r = await playFun(t, blocks, level: 20, lang: 'en', input: (t, i, s) async {
      if (i % 3 == 0) await t.tapAt(Offset(s.width * .62, s.height - 40)); // nút →
    });
    expect(r.finished, isTrue);
    expect(r.result!.win, isFalse);
    expect(r.audio.log, contains('sfx:tap'));
  });

  testWidgets('jumper: tự nhảy lên mây', (t) async {
    final r = await playFun(t, jumper, bot: true);
    expect(r.result!.win, isTrue);
    expect(r.finished, isTrue);
    expect(r.audio.log, contains('sfx:jump'));
  });
}
