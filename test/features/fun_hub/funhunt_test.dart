import 'package:be_vui_hoc/features/fun/hub/funcore.dart';
import 'package:be_vui_hoc/features/fun/hub/funhunt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundle);

  test('carry: đọc phòng thủ, súng nước tối thiểu cấp 1, gộp không làm mất đồ', () {
    final c = readHuntCarry({'coins': 'x', 'skills': {'gun': 0, 'bolt': 9}, 'perm': {'hp': 2}, 'off': ['bolt', 'nope', 'knife']});
    expect(c.coins, 0);
    expect(c.skills['gun'], 1);
    expect(c.skills['bolt'], kHuntSkillMax);
    expect(c.perm['hp'], 2);
    expect(c.off, ['bolt']);
    final cur = readHuntCarry({'coins': 7});
    final m = mergeHuntCarry({'skills': {'fire': 3}, 'perm': {'gem': 1}}, cur);
    expect((m['skills'] as Map)['fire'], 3);
    expect((m['perm'] as Map)['gem'], 1);
    expect(m['coins'], 7);
    expect(huntPrice(0), 80);
  });

  test('Săn quái: lái tự động tới khi xong cấp, có carry', () async {
    final env = await makeEnv();
    final g = HuntGame(env.ctx('hunt'), bot: true);
    final r = runGame(g, maxSec: 600, dt: 1 / 30);
    expect(r, isNotNull);
    expect(r!.carry, isNotNull);
    expect((r.carry!['skills'] as Map)['gun'], greaterThanOrEqualTo(1));
    if (r.win) expect(r.score, greaterThanOrEqualTo(50));
  });

  test('Săn quái: đồ mạnh (cấp 20) → thường hạ được trùm', () async {
    final env = await makeEnv();
    final carry = {
      'coins': 0,
      'skills': {for (final k in kHuntSkills.keys) k: 4},
      'perm': {'hp': 5, 'speed': 5, 'power': 5, 'gem': 0},
    };
    final g = HuntGame(env.ctx('hunt', level: 20, carry: carry), bot: true);
    final r = runGame(g, w: 400, h: 800, maxSec: 900, dt: 1 / 30);
    expect(r, isNotNull);
    expect(g.kills, greaterThan(20));
  });

  test('Săn quái: đầy thanh ngọc → thẻ chọn sức mạnh, chạm thẻ thì lên skill và lưu kho', () async {
    final env = await makeEnv();
    final g = HuntGame(env.ctx('hunt', carry: {
      'perm': {'gem': 5}
    }));
    g.setSize(900, 600);
    g.update(1 / 30);
    expect(g.cardOpen, isTrue);
    expect(g.cardOptions.length, 3);
    for (var i = 0; i < 20; i++) {
      g.update(1 / 30);
    }
    paintOnce(g);
    final pickK = g.cardOptions.first;
    final before = g.C.skills[pickK] ?? 0;
    final coins0 = g.C.coins;
    g.pointerUp(Offset.zero, 1);
    g.pointerDown(g.cardRects.first.center, 1);
    expect(env.gear, isNotNull);
    if (kHuntSkills.containsKey(pickK)) {
      expect(g.C.skills[pickK], before + 1);
    } else {
      expect(g.C.coins, greaterThanOrEqualTo(coins0));
    }
    for (var i = 0; i < 20; i++) {
      g.update(1 / 30);
    }
    expect(g.cardOpen, isFalse);
    // Cần ảo: kéo sang phải → bé chạy sang phải
    final x0 = g.meX;
    g.pointerDown(const Offset(300, 300), 2);
    g.pointerMove(const Offset(400, 300), 2, true);
    for (var i = 0; i < 10; i++) {
      g.update(1 / 30);
    }
    g.pointerUp(const Offset(400, 300), 2);
    expect(g.meX, greaterThan(x0));
  });

  testWidgets('Kho vũ khí: mua nâng cấp, bật/tắt skill, Chơi → game chạy tới kết quả', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = (await tester.runAsync(makeEnv))!;
    final ctx = env.ctx('hunt', carry: {
      'coins': 100,
      'skills': {'gun': 1, 'fire': 1, 'magnet': 1}
    });
    await tester.pumpWidget(env.scope(HuntRun(ctx: ctx, bot: true, turbo: 6)));
    await tester.pump();
    expect(find.byKey(const Key('hunt-shop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hunt-perm-hp')));
    await tester.pump();
    expect(env.gear!['coins'], 20);
    expect((env.gear!['perm'] as Map)['hp'], 1);
    // Không đủ xu
    await tester.tap(find.byKey(const Key('hunt-perm-power')));
    await tester.pump();
    expect(env.audio.log.last, 'sfx:wrong');
    // Tắt cầu lửa; súng nước + cầu lửa: không tắt được vũ khí cuối cùng
    await tester.tap(find.byKey(const Key('hunt-sk-fire')));
    await tester.pump();
    expect(env.gear!['off'], ['fire']);
    await tester.tap(find.byKey(const Key('hunt-sk-gun')));
    await tester.pump();
    expect(env.gear!['off'], ['fire']);
    await tester.tap(find.byKey(const Key('hunt-play')));
    await tester.pump();
    expect(find.byKey(const Key('hunt-shop')), findsNothing);
    for (var i = 0; i < 3000 && !env.finished; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(env.finished, isTrue);
    expect(env.result!.carry, isNotNull);
    expect(((env.result!.carry!['perm']) as Map)['hp'], 1);
  });

  test('funhuntGames có hunt', () {
    expect(funhuntGames['hunt'], isA<FunGameModule>());
  });
}
