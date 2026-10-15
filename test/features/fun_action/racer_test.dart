import 'package:be_vui_hoc/features/fun/action/act_core.dart';
import 'package:be_vui_hoc/features/fun/action/funracer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gara: đọc kho đồ phòng thủ, không hạ cấp', () {
    final g = RacerGear.from({'coins': '120', 'own': ['green', 'nope'], 'up': {'red': {'eng': 9, 'bag': 1}}, 'items': ['rocket', 'x', 'zap', 'gold', 'fly'], 'car': 'green'});
    expect(g.coins, 120);
    expect(g.own, containsAll(['red', 'blue', 'yellow', 'purple', 'green']));
    expect(g.own, isNot(contains('nope')));
    expect(g.up['red']!['eng'], 5);
    expect(g.up['red']!['bag'], 1);
    expect(g.items, ['rocket', 'zap', 'gold']);
    expect(g.car, 'green');
    expect(RacerGear.from(null).car, 'red');
    expect(RacerGear.from(g.toJson()).toJson(), g.toJson());
  });

  test('đua hết đường, xếp hạng và trả kho đồ', () {
    final f = FakeFun(level: 0, carry: {'coins': 50, 'items': ['rocket', 'zap']});
    final game = RacerGame(ctx: f.ctx, gfx: Gfx(), gear: RacerGear.from(f.ctx.carry), carId: 'red');
    game.layout(800, 600);
    var used = false;
    final r = game.runFor(200, each: () {
      // Lái theo tim đường, dùng đồ + nitro
      game.tx = game.cx(game.d);
      if (!used && game.t > 1) {
        used = true;
        game.useItem(0);
        game.useNitro();
      }
      game.paintOnce();
    }) as RaceEnd?;
    expect(r, isNotNull);
    expect(r!.pos, inInclusiveRange(1, 6));
    expect(r.carry['coins'], greaterThanOrEqualTo(50));
    expect(f.audio.log, contains('sfx:power'));
  });

  test('thoát giữa chừng thì dừng, không có kết quả', () {
    final f = FakeFun();
    final game = RacerGame(ctx: f.ctx, gfx: Gfx(), gear: RacerGear.from({}), carId: 'blue');
    var alive = true;
    game.alive = () => alive;
    game.layout(400, 700);
    game.runFor(5);
    alive = false;
    expect(game.runFor(5), isNull);
    expect(game.ended, isTrue);
  });
}
