import 'package:be_vui_hoc/features/fun/more/funhero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpFunMore(sheetNames: ['plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx', 'creatures/flyers'], imgs: [
    'Robot', 'Alien monster', 'Ghost', 'Bat', 'Goblin', 'Spider', 'Ogre', 'Dragon', 'Sun with face', 'Rock', 'Construction', 'Coin', 'Fire',
    'Red heart', 'Cloud', 'Glowing star', 'Snowflake', 'Rocket', 'Shield', 'Magnet', 'High voltage', 'Collision', 'Cloud with lightning',
    'Tornado', 'Volcano', 'Running shoe', 'Wing', 'Flexed biceps', 'Comet',
  ]);

  test('có game hero', () => expect(funheroGames.keys, contains('hero')));

  group('norm() kho đồ', () {
    test('rỗng → mặc định, chưởng thường luôn có', () {
      final n = heroNorm(null);
      expect(n['v'], 1);
      expect(n['coins'], 0);
      expect(n['own'], {'basic': 1, 'fire': 0, 'triple': 0, 'ice': 0, 'thunder': 0, 'tornado': 0, 'quake': 0});
      expect(n['power'], 'basic');
      expect(n['up'], {'hp': 0, 'armor': 0, 'rate': 0, 'super': 0, 'dash': 0, 'jump3': 0, 'pound': 0});
      expect([n['fly'], n['shield'], n['charge']], [0, 0, 0]);
      expect(heroNorm('rác')['coins'], 0);
    });

    test('kẹp giá trị, chuỗi số, chưởng chưa có thì về chưởng thường', () {
      final n = heroNorm({
        'coins': '12.7', 'own': {'fire': 9, 'ice': -2, 'basic': 0, 'quake': 2.9}, 'power': 'fire',
        'up': {'hp': 5, 'dash': 1, 'rate': 'x'}, 'fly': 7, 'shield': 'x', 'charge': 3,
      });
      expect(n['coins'], 12);
      expect(n['own'], containsPair('fire', 5));
      expect(n['own'], containsPair('ice', 0));
      expect(n['own'], containsPair('basic', 1));
      expect(n['own'], containsPair('quake', 2));
      expect(n['power'], 'fire');
      expect(n['up'], containsPair('hp', 3));
      expect(n['up'], containsPair('dash', 1));
      expect(n['up'], containsPair('rate', 0));
      expect([n['fly'], n['shield'], n['charge']], [3, 0, 1]);
      expect(heroNorm({'power': 'ice'})['power'], 'basic');
      expect(heroNorm({'power': 'nope', 'charge': .456})['charge'], .46);
    });
  });

  testWidgets('Kho chưởng: mua chưởng lửa + giáp, chơi bằng nút tới khi xong', (t) async {
    var sawArmory = false, played = false;
    late FunRun run;
    run = await playFun(t, hero, bot: true, carry: {'coins': 1000}, input: (t, i, s) async {
      if (!played) {
        if (find.byKey(const Key('hero-play')).evaluate().isEmpty) return;
        sawArmory = true;
        expect(find.byKey(const Key('hero-armory')), findsOneWidget);
        expect(find.text('🦸 Kho chưởng'), findsOneWidget);
        expect(find.text('1000'), findsOneWidget);
        await t.tap(find.byKey(const Key('hero-buy-fire')));
        await t.pump();
        expect(find.text('800'), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('hero-buy-up-armor')));
        await t.tap(find.byKey(const Key('hero-buy-up-armor')));
        await t.pump();
        await t.ensureVisible(find.byKey(const Key('hero-buy-rocket')));
        await t.tap(find.byKey(const Key('hero-buy-rocket')));
        await t.pump();
        await t.ensureVisible(find.byKey(const Key('hero-power-basic')));
        await t.tap(find.byKey(const Key('hero-power-basic')));
        await t.pump();
        await t.tap(find.byKey(const Key('hero-play')));
        await t.pump();
        played = true;
        return;
      }
      // Trong game: chạm nút bắn, nút đổi chưởng, nút giày tên lửa, giữ nửa trái để nhảy/bay.
      final btnR = (s.width < s.height ? s.width : s.height) * .105, sR = btnR * .72;
      final shot = Offset(s.width - btnR - 24, s.height - btnR - 20);
      final superB = Offset(s.width - btnR - 24, s.height - btnR * 3.4 - 20);
      if (i % 4 == 1) await t.tapAt(shot);
      if (i == 6) await t.tapAt(Offset(shot.dx - btnR * 2.25, shot.dy)); // đổi chưởng
      if (i == 10) await t.tapAt(Offset(superB.dx - btnR * 1.9, superB.dy)); // giày tên lửa
      if (i % 12 == 3) {
        final gst = await t.startGesture(Offset(s.width * .25, s.height * .5));
        await t.pump(const Duration(milliseconds: 200));
        await gst.up();
      }
      expect(sR, greaterThan(0));
    });
    expect(sawArmory, isTrue);
    expect(run.saved, isNotEmpty);
    final first = run.saved.first;
    expect(first['coins'], 800);
    expect((first['own'] as Map)['fire'], 1);
    expect(first['power'], 'fire');
    expect(run.saved.any((c) => (c['up'] as Map)['armor'] == 1), isTrue);
    expect(run.saved.any((c) => c['fly'] == 1), isTrue);
    expect(run.finished, isTrue);
    expect(run.result, isNotNull);
    final carry = run.result!.carry!;
    expect(carry['coins'], greaterThanOrEqualTo(540));
    expect((carry['own'] as Map)['fire'], greaterThanOrEqualTo(1));
    expect((carry['up'] as Map)['armor'], 1);
    expect(run.audio.log, contains('sfx:shoot'));
    expect(run.audio.log, contains('sfx:power'));
  });

  testWidgets('cấp sau trong cùng vé (vừa thắng cấp trước) thì bỏ qua Kho chưởng', (t) async {
    var armory = false;
    final r = await playFun(t, hero, level: 1, bot: true, ticket: {'heroArmory': true}, carry: {'coins': 5, 'own': {'thunder': 3}, 'power': 'thunder', 'up': {'hp': 2, 'dash': 1, 'pound': 1}},
        input: (t, i, s) async {
      if (find.byKey(const Key('hero-armory')).evaluate().isNotEmpty) armory = true;
    });
    expect(armory, isFalse);
    expect(r.finished, isTrue);
    expect(r.result!.carry, isNotNull);
    expect((r.result!.carry!['own'] as Map)['thunder'], greaterThanOrEqualTo(3));
  });

  testWidgets('vé mới thì Kho chưởng hiện lại', (t) async {
    var armory = false;
    await playFun(t, hero, level: 1, maxSeconds: 1, input: (t, i, s) async {
      if (find.byKey(const Key('hero-armory')).evaluate().isNotEmpty) armory = true;
    });
    expect(armory, isTrue);
  });
}
