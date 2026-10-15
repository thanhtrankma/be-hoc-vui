import 'package:be_vui_hoc/features/fun/action/act_core.dart';
import 'package:be_vui_hoc/features/fun/action/funshooter.dart';
import 'package:be_vui_hoc/features/fun/action/funtank.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phi thuyền', () {
    test('kho đồ: mặc định + giới hạn', () {
      final g = ShipGear.from({'guns': {'spread': 9, 'bad': 2}, 'up': {'drone': 2, 'bomb': 3}, 'gun': 'spread', 'coins': 40, 'en': {'shield': 3}});
      expect(g.own, {'laser': 1, 'spread': 5});
      expect(g.gun, 'spread');
      expect(g.drones, 2);
      expect(g.bombs, 4);
      expect(g.en['shield'], 1);
      expect(ShipGear.from(null).toJson()['gun'], 'laser');
    });

    test('mọi loại súng bắn được; hạ trùm giữa + trùm cuối là thắng', () {
      final f = FakeFun(gameId: 'shooter', level: 12);
      final gear = ShipGear.from({'guns': {for (final g in kGunIds) g: 5}, 'drones': 2, 'en': {'shield': 1, 'meteor': 1, 'giant': 1}});
      final game = ShooterGame(ctx: f.ctx, gfx: Gfx(), gear: gear);
      game.layout(390, 800);
      var i = 0;
      final r = game.runFor(200, each: () {
        i++;
        if (i % 40 == 0) game.nextGun();
        if (i == 100) {
          game.useSkill('shield');
          game.useSkill('meteor');
          game.useSkill('giant');
          game.useBomb();
        }
        game.inv = 1;  // bất tử để chắc chắn tới trùm cuối
        game.boss?.hp = 0.5;
        if (i % 3 == 0) game.paintOnce();
      }) as ShootEnd?;
      expect(r, isNotNull);
      expect(r!.win, isTrue);
      expect(r.carry['wins'], 1);
      expect(f.saved, isNotEmpty);
    });

    test('hết máu là thua, kho đồ vẫn trả về', () {
      final f = FakeFun(gameId: 'shooter');
      final game = ShooterGame(ctx: f.ctx, gfx: Gfx(), gear: ShipGear.from({'coins': 7}));
      game.layout(800, 600);
      final r = game.runFor(30, each: () {
        game.inv = 0;
        game.shield = 0;
        game.hurt();
      }) as ShootEnd?;
      expect(r!.win, isFalse);
      expect(r.carry['coins'], greaterThanOrEqualTo(7));
    });
  });

  group('Xe tăng', () {
    test('kho đồ phòng thủ', () {
      final g = TankGear.from({'wp': {'laser': 7, 'x': 1}, 'cur': 'laser', 'up': {'ally': 5}, 'allies': 9, 'body': 'pink'});
      expect(g.wp, {'norm': 1, 'laser': 5});
      expect(g.cur, 'laser');
      expect(g.up['ally'], 2);
      expect(g.allies, 2);
      expect(g.body, 'green');
    });

    test('hạ đủ xe tăng + trùm (cấp 5) là thắng; mọi loại đạn', () {
      final f = FakeFun(gameId: 'tank', level: 4);
      final gear = TankGear.from({'wp': {for (final w in kTkWeapons) w.id: 5}, 'en': 100, 'up': {'ally': 2}});
      final game = TankGame(ctx: f.ctx, gfx: Gfx(), gear: gear);
      game.layout(800, 600);
      var i = 0;
      final r = game.runFor(400, each: () {
        i++;
        game.inv = 1;
        game.tx = 400 + 200 * (i % 100 < 50 ? 1 : -1);
        game.ty = 300;
        if (i % 60 == 0) game.cur = kTkWeapons[(i ~/ 60) % kTkWeapons.length].id;
        if (i == 90) {
          for (final s in kTkSkills) {
            game.en = 100;
            game.useSkill(s);
          }
        }
        // Đạn thật bắn chậm: giúp hạ nhanh
        if (i % 20 == 0) {
          for (final fo in [...game.foes]) {
            game.hurtFoe(fo, 3, fo.x, fo.y);
          }
        }
        if (i % 3 == 0) game.paintOnce();
      }) as TankEnd?;
      expect(r, isNotNull);
      expect(r!.win, isTrue);
      expect(game.bossDone, isTrue);
      expect(r.carry['coins'], greaterThan(0));
    });

    test('hỏng xe là thua', () {
      final f = FakeFun(gameId: 'tank');
      final game = TankGame(ctx: f.ctx, gfx: Gfx(), gear: TankGear.from({}));
      game.layout(400, 800);
      final r = game.runFor(60, each: () {
        game.inv = 0;
        game.hurt();
      }) as TankEnd?;
      expect(r!.win, isFalse);
    });
  });
}
