import 'dart:ui' as ui;

import 'package:be_vui_hoc/features/fun/hub/funcore.dart';
import 'package:be_vui_hoc/features/fun/hub/funfx.dart';
import 'package:be_vui_hoc/features/fun/hub/motionb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Canvas _canvas() => Canvas(ui.PictureRecorder());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('funcore: hit, hexColor, chữ, HUD, băng chữ, FunFx', () {
    expect(funHit(0, 0, 10, 10, 6, 0, 10, 10), isTrue);
    expect(funHit(0, 0, 10, 10, 8, 0, 10, 10), isFalse);
    expect(hexColor('#ff0000'), const Color(0xFFFF0000));
    expect(hexColor('#0f0'), const Color(0xFF00FF00));
    expect(funEnd(true, 3), '⭐ LÊN CẤP 5!');
    expect(funEnd(true, 59, true), '🏆 TOP LEVEL!');
    expect(funEnd(false, 2, true), 'LEVEL NOT CLEARED');
    expect(funThemeName(25, true), 'Snowland');
    final c = _canvas();
    FunText.draw(c, 'Xin chào', 10, 10, stroke: Colors.black, fit: 20, alpha: .5);
    FunText.draw(c, '', 10, 10);
    funHud(c, 400, score: 3, lives: 2, time: 9.2, bossHp: 5, bossMax: 10);
    funBanner(c, 400, 600, 'A', 'b');
    funLevelBanner(c, 400, 600, 0, 'goal', 'hint', true);
    funGoalPill(c, 400, 3, 5);
    funSky(c, 400, 600, Colors.blue, Colors.white);
    final f = FunFx();
    f.burst(10, 10);
    f.text(10, 10, '+1');
    f.star(10, 10);
    expect(f.count, 16);
    f.draw(c);
    for (var i = 0; i < 60; i++) {
      f.update(1 / 30);
    }
    expect(f.count, 0);
  });

  test('funfx: Shaker, Dust, Booms, sheet null an toàn', () {
    final c = _canvas();
    final s = Shaker()..add(30);
    expect(s.power, 18);
    for (var i = 0; i < 60; i++) {
      s.update(1 / 30);
    }
    expect(s.power, 0);
    s.apply(c);
    final d = Dust(10)
      ..sparks(0, 0)
      ..puff(0, 0)
      ..debris(0, 0);
    expect(d.active, 10);
    d.draw(c);
    for (var i = 0; i < 60; i++) {
      d.update(1 / 30);
    }
    expect(d.active, 0);
    final b = Booms(null)..add(5, 5);
    b.draw(c);
    b.update(1);
    expect(spr(c, null, 'x', 0, 0, 10), isFalse);
    expect(anim(c, null, 'x', 0, 0, 0, 10), isFalse);
    sprBox(c, null, 'x', 0, 0, 1, 1);
    stripX(c, null, 'x', 0, 0, 10, 100);
    groundTiles(c, null, 12, 0, 0, 100, 100);
    backHills(c, null, 0, 0, 0, 10, 100);
    coin(c, null, 0, 0, 0, 10);
    expect(aspect(null, 'x'), 1);
    expect(popScale(1), 1);
  });

  test('motionb: Ease, camera dừng hình, Fxb, drawMob', () {
    expect(Ease.outCubic(1), 1);
    expect(Ease.bump(.5), closeTo(1, 1e-9));
    expect(Ease.outElastic(0), 0);
    expect(clamp01(2), 1);
    final cam = MotionCamera()
      ..shake(50)
      ..stop(.1);
    expect(cam.mag, 22);
    expect(cam.scale(.05), .08);
    expect(cam.scale(.06), .08);
    expect(cam.scale(.01), 1);
    final c = _canvas();
    cam.update(1 / 60);
    cam.begin(c);
    cam.end(c);
    final fx = Fxb()
      ..burst(0, 0)
      ..dust(0, 0)
      ..sparks(0, 0)
      ..ring(0, 0)
      ..num(0, 0, 12, crit: true)
      ..text(0, 0, 'Hi')
      ..slash(0, 0, 30, 0);
    fx.draw(c);
    expect(fx.n, greaterThan(20));
    for (var i = 0; i < 90; i++) {
      fx.update(1 / 30);
    }
    expect(fx.n, 0);
    for (final p in [
      MobPose(x: 0, y: 0, size: 40, hurt: .1, atk: .5, wind: .3, stun: true),
      MobPose(x: 0, y: 0, size: 40, fly: true),
      MobPose(x: 0, y: 0, size: 40, dieT: .5),
    ]) {
      drawMob(c, null, p);
    }
    drawShadow(c, 0, 0, 20, 30);
    final pic = prerender((g) => g.drawCircle(Offset.zero, 4, Paint()));
    c.drawPicture(pic);
    expect(tileImage(null, 'x', 10), isNull);
  });
}
