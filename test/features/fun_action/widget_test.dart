import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/registry.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/fun/action/act_core.dart';
import 'package:be_vui_hoc/features/fun/action/funracer.dart';
import 'package:be_vui_hoc/features/fun/action/funshooter.dart';
import 'package:be_vui_hoc/features/fun/action/funtank.dart';
import 'package:be_vui_hoc/features/fun/action/funvs1.dart';
import 'package:be_vui_hoc/features/fun/action/funvs2.dart';
import 'package:be_vui_hoc/features/fun/action/vs_core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> mount(WidgetTester tester, FunGameModule m, FakeFun f) async {
  tester.view.physicalSize = const Size(900, 600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) => m.build(c, f.ctx)))));
  // Nạp hình (giải mã ảnh thật) ngoài fake async
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pump();
}

Future<void> frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

Future<void> pumpUntil(WidgetTester tester, Future<bool> Function() done, {int max = 4000}) async {
  for (var i = 0; i < max && !await done(); i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Nạp sẵn mọi hình ở zone thật: bộ đệm ảnh/sheet của core giữ Future toàn cục, Future tạo trong fake async
  // của một testWidgets sẽ không chạy tiếp ở test sau.
  setUpAll(() async {
    final ctx = FakeFun().ctx;
    await Gfx.load([
      ...racerImgs(ctx), ...kShooterImgs, ...kTankImgs,
      for (final m in [...funvs1Games.values, ...funvs2Games.values]) ...(m as VsModule).imgs(0),
      'Coin', 'Locked', 'Wrench', 'Hammer and wrench', 'Artist palette', 'Backpack', 'Gear', 'Wind face', 'Fuel pump',
      'Star', 'Crown', 'Satellite', 'Running shoe', 'Stopwatch', 'Bow and arrow', 'Bullseye', 'Basketball',
    ], [
      'racing/racing', 'fxa/fx', 'toon/robot', 'space/space', 'tanks/tanks', 'kenney-platformer/tiles', 'kenney-racing/moto', 'kenney-pirate/ships', 'kenney-board/chips',
    ]);
  });
  setUp(() {
    Motion.enabled = false;
    actSessionsReset();
  });

  test('registry trỏ tới game thật của G', () {
    for (final id in ['racer', 'shooter', 'tank', 'fighter', 'hockey', 'tug', 'soccer', 'volley', 'snowball', 'tron', 'sumo', 'caro', 'connect4']) {
      final m = funGameModuleFor(id);
      expect(m, isNotNull, reason: id);
      expect(m!.id, id);
      expect(m.runtimeType.toString(), isNot(contains('Placeholder')), reason: id);
    }
    expect(funvs1Games.length + funvs2Games.length, 10);
  });

  testWidgets('Kéo co: chọn đấu máy → chơi → finish(FunResult)', (tester) async {
    final f = FakeFun(gameId: 'tug');
    await mount(tester, funvs1Games['tug']!, f);
    expect(find.byKey(const Key('vs-bot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('vs-bot')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.byType(GameWidget<ActGame>), findsOneWidget);
    expect(f.audio.log, contains('sfx:power'));
    await frames(tester, 90);
    final center = tester.getCenter(find.byType(GameWidget<ActGame>));
    await pumpUntil(tester, () async {
      if (f.results.isEmpty) await tester.tapAt(Offset(center.dx - 300, center.dy));
      return f.results.isNotEmpty;
    });
    expect(f.results.single!.win, isTrue);
    expect(f.results.single!.pvp, isFalse);
    // Cấp sau (cùng vé): không hỏi lại chế độ
    final f2 = FakeFun(gameId: 'tug', level: 1);
    await mount(tester, funvs1Games['tug']!, f2);
    expect(find.byKey(const Key('vs-bot')), findsNothing);
    expect(find.byType(GameWidget<ActGame>), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Hai người: kết quả pvp', (tester) async {
    final f = FakeFun(gameId: 'caro');
    await mount(tester, funvs2Games['caro']!, f);
    await tester.tap(find.byKey(const Key('vs-pvp')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await frames(tester, 90);
    final box = tester.getRect(find.byType(GameWidget<ActGame>));
    final g = tester.widget<GameWidget<ActGame>>(find.byType(GameWidget<ActGame>)).game as CaroGame;
    // Xanh đánh cột trái, đỏ cột giữa: xanh thắng hàng dọc
    for (final (x, y) in [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]) {
      await tester.tapAt(box.topLeft + Offset(g.ox + (x + .5) * g.cs, g.oy + (y + .5) * g.cs));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pumpUntil(tester, () async => f.results.isNotEmpty);
    expect(f.results.single!.pvp, isTrue);
    expect(f.results.single!.title, contains('XANH'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Gara đua xe: thiếu xu thì không mua được; chạm xe là vào đua', (tester) async {
    final f = FakeFun(gameId: 'racer', carry: {'coins': 130});
    await mount(tester, funracerGames['racer']!, f);
    expect(find.text('🏎️ Gara'), findsOneWidget);
    await tester.tap(find.byKey(const Key('car-black')));
    await tester.pump();
    expect(f.audio.log.last, 'sfx:wrong');
    await tester.ensureVisible(find.byKey(const Key('buy-up-eng')));
    await tester.tap(find.byKey(const Key('buy-up-eng')));
    await tester.pump();
    expect(f.saved.last['coins'], 10);
    expect((f.saved.last['up'] as Map)['red']['eng'], 1);
    await tester.ensureVisible(find.byKey(const Key('car-blue')));
    await tester.tap(find.byKey(const Key('car-blue')));
    await tester.pump();
    expect(find.byType(GameWidget<ActGame>), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    expect(f.audio.log.where((e) => e.startsWith('sfx:')), isNotEmpty);
  });

  testWidgets('Xưởng phi thuyền + xưởng xe tăng mở được và vào chơi', (tester) async {
    final f = FakeFun(gameId: 'shooter', carry: {'coins': 400});
    await mount(tester, funshooterGames['shooter']!, f);
    expect(find.text('🚀 Xưởng phi thuyền'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gun-spread')));
    await tester.pump();
    expect((f.saved.last['guns'] as Map)['spread'], 1);
    expect(f.saved.last['gun'], 'spread');
    await tester.ensureVisible(find.byKey(const Key('shop-play')));
    await tester.tap(find.byKey(const Key('shop-play')));
    await tester.pump();
    expect(find.byType(GameWidget<ActGame>), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());

    final t = FakeFun(gameId: 'tank', carry: {'coins': 200});
    await mount(tester, funtankGames['tank']!, t);
    expect(find.text('🛠️ Xưởng xe tăng'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('wp-laser')));
    await tester.tap(find.byKey(const Key('wp-laser')));
    await tester.pump();
    expect(t.saved.last['cur'], 'laser');
    await tester.ensureVisible(find.byKey(const Key('shop-play')));
    await tester.tap(find.byKey(const Key('shop-play')));
    await tester.pump();
    expect(find.byType(GameWidget<ActGame>), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}
