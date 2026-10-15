// Game vui nhộn: hứng trái cây, đập quái vật, câu cá, xây tháp, phá gạch, chim bay (port reference/web/js/games/funmore.js).
// CHỦ: agent E. Mỗi lượt là một cấp (ctx.level): đạt mục tiêu thì thắng (khung lên cấp); cấp cao nhanh hơn, mục tiêu cao hơn,
// đổi cảnh mỗi 10 cấp. Vẽ bằng canvas (FunCanvas của funcore.dart), hiệu ứng ở funfx.dart.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/ui/ui.dart' hide lerp, approach;
import 'package:be_vui_hoc/features/learn/creative/figure.dart' show drawFigure, heroOf;

import 'funcore.dart';
import 'funfx.dart';

/// id game → module (khoá trùng FUN_GAMES).
final Map<String, FunGameModule> funmoreGames = {
  'catch': FunCanvasModule('catch', CatchGame.new),
  'whack': FunCanvasModule('whack', WhackGame.new),
  'fishing': FunCanvasModule('fishing', FishingGame.new),
  'stack': FunCanvasModule('stack', StackGame.new),
  'breakout': FunCanvasModule('breakout', BreakoutGame.new),
  'flappy': FunCanvasModule('flappy', FlappyGame.new),
};

const int _hearts = 3;
const _shade = Color(0x47000000);
const _gold = Color(0xFFFFD43B);

void _heartsHud(FunCanvasGame g, Canvas c, int n) {
  for (var i = 0; i < _hearts; i++) {
    g.img.draw(c, 'Red heart', g.W - 40 - i * 36, 32, 30, alpha: i < n ? 1 : .22);
  }
}

void _timerHud(Canvas c, double w, double time) {
  fillRRect(c, w / 2 - 50, 10, 100, 44, 22, _shade);
  FunText.draw(c, '⏱ ${time.ceil()}', w / 2, 42, size: 28);
}

/// Phần chung: kết thúc cấp (end + chờ 2 giây), hiệu ứng.
abstract class _MoreGame extends FunCanvasGame {
  _MoreGame(super.ctx);
  final FunFx F = FunFx();
  final Shaker sh = Shaker();
  FunResult? end;
  double endT = 0, t = 0;

  /// Bước chờ sau khi xong cấp. Trả kết quả sau 2 giây.
  FunResult? endStep(double dt) {
    endT += dt;
    F.update(dt);
    return endT > 2 ? end : null;
  }

  String get themeName => funThemeName(lv, en);
  String pts(int a, [int? b]) => b == null ? tr('$a điểm', '$a points') : tr('$a/$b điểm', '$a/$b points');
}

// =================================================================================================================
// Hứng trái cây: kéo giỏ, hứng trái cây, né bom; sao vàng nhân đôi điểm
// =================================================================================================================

class FunDrop {
  FunDrop(this.k, this.x, this.y, this.w, this.vy, this.rot);
  final String k;
  double x, y, w, vy, rot;
}

class CatchGame extends _MoreGame {
  CatchGame(super.ctx);
  static const fruit = ['Red apple', 'Banana', 'Grapes', 'Strawberry', 'Watermelon', 'Tangerine', 'Cherries', 'Pineapple', 'Peach'];
  static const time = 50.0;
  late final int need = (15 + lv * .95).round();
  final D = Dust(200);
  final B = Booms(null);
  double tilt = 0, squash = 0, spawn = .6, dbl = 0;
  late double meX, meY, meW, meH, meTx;
  final drops = <FunDrop>[];
  int score = 0, lives = _hearts, combo = 0;

  @override
  List<String> get images => [...fruit, 'Bomb', 'Basket', 'Cloud', ...funThemeImgs(lv)];
  @override
  List<String> get sheetNames => ['plat/tiles', 'plat/bg', 'fxa/fx'];

  @override
  void init() {
    meX = meTx = W / 2;
    meY = H * .86;
    meW = S * ramp(lv, .22, .17);
    meH = S * .14;
  }

  @override
  void pointerDown(Offset p, int id) => meTx = p.dx;
  @override
  void pointerMove(Offset p, int id, bool down) {
    if (down) meTx = p.dx;
  }

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    final px = meX;
    meX = approach(meX, meTx, 12, dt);
    tilt = approach(tilt, ((meX - px) / math.max(dt, .001) / 2500).clamp(-.35, .35), 12, dt);
    squash = math.max(0, squash - dt);
    sh.update(dt);
    D.update(dt);
    B.update(dt);
    dbl = math.max(0, dbl - dt);
    spawn -= dt;
    if (spawn <= 0) {
      spawn = math.max(.28, .85 - t / 80) * ramp(lv, 1, .78);
      final r = rng.nextDouble(), sz = S * .1;
      final k = r < .16 + ramp(lv, 0, .1) + t / 400 ? 'Bomb' : (r > .96 ? 'Glowing star' : pick(fruit));
      drops.add(FunDrop(k, rand(sz, W - sz), -sz, sz, (rand(140, 220) + t * 3) * ramp(lv, 1, 1.6), rand(-1, 1)));
    }
    for (var i = drops.length - 1; i >= 0; i--) {
      final d = drops[i];
      d.y += d.vy * dt;
      d.rot += dt;
      if (d.k == 'Bomb' && rng.nextDouble() < .5) D.emit(d.x + d.w * .3, d.y - d.w * .45, rand(-30, 30), rand(-80, -20), life: .25, r: 2, grow: 0, c: _gold, k: 1, a: 1);
      if (d.y > H + 40) {
        if (d.k != 'Bomb' && d.k != 'Glowing star') combo = 0;
        drops.removeAt(i);
        continue;
      }
      if ((d.y - (meY - meH * .3)).abs() < meH * .45 && (d.x - meX).abs() < meW * .5) {
        drops.removeAt(i);
        if (d.k == 'Bomb') {
          lives--;
          combo = 0;
          sfx('boom');
          B.add(d.x, d.y, d.w * 2.2);
          D.puff(d.x, d.y, 8, const Color(0xFF5A5A5A), 90, 12);
          sh.add(12);
          if (lives <= 0) end = FunResult(win: false, score: score);
        } else if (d.k == 'Glowing star') {
          dbl = 8;
          sfx('power');
          F.text(d.x, d.y - 30, tr('NHÂN ĐÔI!', 'DOUBLE!'), _gold);
        } else {
          combo++;
          final p = (combo >= 5 ? 2 : 1) * (dbl > 0 ? 2 : 1);
          score += p;
          sfx('coin');
          F.text(d.x, d.y - 30, '+$p', _gold);
          D.sparks(d.x, d.y, 8, const Color(0xFFFFF3BF), 200);
          squash = .2;
        }
      }
    }
    if (t >= time && end == null) {
      end = FunResult(win: score >= need, score: score);
      sfx(score >= need ? 'win' : 'pop');
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    final tl = sheets['plat/tiles'], bgs = sheets['plat/bg'];
    B.fx = sheets['fxa/fx'];
    c.save();
    sh.apply(c);
    funSky(c, W, H, th.skyTop, th.skyBottom);
    img.draw(c, th.sun, W * .85, H * .13 + math.sin(t * .8) * 4, S * .14);
    backHills(c, bgs, lv, t * 6, H * .9, H * .38, W);
    img.draw(c, th.deco[0], W * .1, H * .62, S * .5, rot: math.sin(t * 1.3) * .03);
    img.draw(c, th.deco[1], W * .9, H * .64, S * .42, rot: math.sin(t * 1.1 + 1) * .03);
    if (tl == null) c.drawRect(Rect.fromLTWH(0, H * .9 - 8, W, H), Paint()..color = th.groundColor);
    groundTiles(c, tl, lv, 0, H * .9 - 8, W, H + 20, math.max(40, S * .07));
    for (final d in drops) {
      final k = (d.y / H).clamp(0.0, 1.0);
      fillEllipse(c, d.x, H * .9, d.w * (.2 + k * .25), 5, Color.fromRGBO(0, 0, 0, .08 + k * .14));
      if (d.k == 'Bomb') {
        if (!spr(c, tl, (t * 8).floor() % 2 == 1 ? 'bomb_active' : 'bomb', d.x, d.y, d.w * 1.3, rot: math.sin(d.rot * 3) * .3)) img.draw(c, 'Bomb', d.x, d.y, d.w);
      } else {
        img.draw(c, d.k, d.x, d.y, d.w, rot: math.sin(d.rot * 2) * .5);
      }
    }
    // Giỏ nghiêng theo hướng kéo, phồng ra khi hứng
    final sq = squash > 0 ? math.sin(squash / .2 * math.pi) * .15 : 0.0;
    fillEllipse(c, meX, H * .9 + 2, meW * .4, 7, const Color(0x2E000000));
    c.save();
    c.translate(meX, meY + meW * .4);
    c.rotate(tilt);
    c.scale(1 + sq, 1 - sq);
    img.draw(c, 'Basket', 0, -meW * .4, meW);
    c.restore();
    if (dbl > 0) img.draw(c, 'Glowing star', meX + meW * .45, meY - meH * .7 + math.sin(t * 6) * 5, 30, rot: t * 2);
    D.draw(c);
    B.draw(c);
    F.draw(c);
    c.restore();
    funHud(c, W, score: score);
    _heartsHud(this, c, lives);
    _timerHud(c, W, math.max(0, time - t));
    funGoalPill(c, W, score, need);
    if (combo >= 5) FunText.draw(c, tr('Chuỗi $combo 🔥', 'Combo $combo 🔥'), 16, 84, size: 24, color: const Color(0xFFFF922B), align: TextAlign.left);
    if (t < 2.6) funLevelBanner(c, W, H, lv, tr('Hứng $need điểm', 'Catch $need points'), tr('$themeName · Kéo giỏ · Né quả bom', '$themeName · Drag the basket · Dodge bombs'), en);
    if (end != null) funBanner(c, W, H, lives <= 0 ? tr('TRÚNG BOM RỒI!', 'BOOM! A BOMB!') : funEnd(end!.win, lv, en), pts(score, need));
  }
}

// =================================================================================================================
// Đập quái vật: quái thò lên từ hang, chạm để đập; đừng đập bạn thỏ
// =================================================================================================================

class _Hole {
  _Hole(this.x, this.y);
  final double x, y;
  String? k;
  double up = 0, life = 0, hitT = 0;
}

class WhackGame extends _MoreGame {
  WhackGame(super.ctx);
  static const bad = ['Alien monster', 'Ghost', 'Goblin', 'Ogre'], good = ['Rabbit face', 'Dog face'];
  static const look = {
    'Alien monster': ['slime', 'slime_normal_flat'],
    'Ghost': ['mouse', 'mouse_rest'],
    'Goblin': ['sslime', 'slime_spike_flat'],
    'Ogre': ['fslime', 'slime_fire_flat'],
  };
  static const friend = {'Rabbit face': 'rabbit', 'Dog face': 'dog'};
  static const time = 45.0;
  late final int need = (15 + lv * .8).round();
  final D = Dust(160);
  late double cw;
  final holes = <_Hole>[];
  int score = 0;
  double spawn = .6;
  ({double x, double y, double t})? hammer;

  @override
  List<String> get images => [...bad, ...good, 'Hole', 'Hammer', 'Collision', 'Seedling'];
  @override
  List<String> get sheetNames => ['plat/enemies', 'animals/round', 'plat/tiles', 'plat/bg'];

  @override
  void init() {
    final cols = W > H ? 4 : 3, rows = 3;
    cw = math.min(W / cols, (H - 120) / rows);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        holes.add(_Hole(W / 2 + (c - (cols - 1) / 2) * cw, 140 + r * cw + cw * .55));
      }
    }
  }

  @override
  void pointerDown(Offset p, int id) {
    if (end != null) return;
    final x = p.dx, y = p.dy;
    hammer = (x: x, y: y, t: .2);
    sh.add(2);
    _Hole? hl;
    for (final o in holes) {
      if (o.k != null && o.up > .4 && (x - o.x).abs() < cw * .4 && y < o.y + cw * .1 && y > o.y - cw * .6) {
        hl = o;
        break;
      }
    }
    if (hl == null) {
      sfx('tap');
      return;
    }
    if (good.contains(hl.k)) {
      score = math.max(0, score - 2);
      sfx('wrong');
      F.text(hl.x, hl.y - cw * .5, tr('Ối! Bạn mà!', 'Oops! A friend!'), const Color(0xFFFF6B6B));
    } else {
      final p = hl.k == 'Ogre' ? 3 : 1;
      score += p;
      sfx('boom');
      D.sparks(hl.x, hl.y - cw * .3, 12, const Color(0xFFFFE066), 280);
      D.debris(hl.x, hl.y, 6, const Color(0xFF8D5524), 200);
      sh.add(hl.k == 'Ogre' ? 7 : 4);
      F.text(hl.x, hl.y - cw * .55, '+$p', _gold);
    }
    hl.hitT = .25;
    hl.life = 0;
  }

  /// Tâm hang có quái đang thò lên (cho kiểm thử).
  List<Offset> get upTargets => [for (final o in holes) if (o.k != null && o.up > .4 && !good.contains(o.k) && o.life > 0) Offset(o.x, o.y - cw * .3)];

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    if (hammer != null) {
      final h = hammer!;
      hammer = h.t - dt <= 0 ? null : (x: h.x, y: h.y, t: h.t - dt);
    }
    sh.update(dt);
    D.update(dt);
    spawn -= dt;
    if (spawn <= 0) {
      spawn = math.max(.3, .9 - t / 70) * ramp(lv, 1, .75);
      final free = holes.where((o) => o.k == null).toList();
      if (free.isNotEmpty) {
        final o = pick(free);
        D.debris(o.x, o.y, 5, const Color(0xFF8D5524), 160);
        o.k = rng.nextDouble() < ramp(lv, .2, .32) ? pick(good) : (rng.nextDouble() < .12 ? 'Ogre' : pick(bad));
        o.life = math.max(.5, 1.5 - t / 60) * ramp(lv, 1, .62);
        o.up = 0;
      }
    }
    for (final o in holes) {
      if (o.k == null) continue;
      o.hitT = math.max(0, o.hitT - dt);
      if (o.life > 0) {
        o.life -= dt;
        o.up = math.min(1, o.up + dt * 6);
      } else {
        o.up -= dt * 6;
        if (o.up <= 0) {
          o.k = null;
          o.up = 0;
        }
      }
    }
    if (t >= time) {
      end = FunResult(win: score >= need, score: score);
      sfx(score >= need ? 'win' : 'pop');
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    final enS = sheets['plat/enemies'], an = sheets['animals/round'], tl = sheets['plat/tiles'], bgs = sheets['plat/bg'];
    c.save();
    sh.apply(c);
    funSky(c, W, H, th.skyTop, th.skyBottom);
    backHills(c, bgs, lv, t * 5, 150, 120, W);
    if (tl == null) c.drawRect(Rect.fromLTWH(0, 130, W, H), Paint()..color = th.groundColor);
    groundTiles(c, tl, lv, 0, 130, W, H + 20, math.max(48, S * .08));
    for (final o in holes) {
      fillEllipse(c, o.x, o.y, cw * .36, cw * .12, const Color(0xFF5C3D1E));
      if (o.k != null) {
        c.save();
        c.clipRect(Rect.fromLTWH(o.x - cw * .5, o.y - cw, cw, cw));
        // Thò lên nảy (easeOutBack), bị đập thì bẹp xuống
        final up = o.life > 0 ? easeOutBack(math.min(1, o.up)) : o.up, sz = cw * .62, hitK = o.hitT > 0 ? o.hitT / .25 : 0.0;
        final y = o.y - up * cw * .38 + cw * .12;
        final fr = friend[o.k];
        if (fr != null) {
          if (!spr(c, an, fr, o.x, y - sz * .1, sz * (hitK > 0 ? .9 : 1), rot: math.sin(t * 6 + o.x) * .08)) img.draw(c, o.k!, o.x, y - sz * .5, sz);
        } else {
          final l = look[o.k] ?? look['Alien monster']!;
          if (hitK > 0) {
            if (!spr(c, enS, l[1], o.x, y + sz * .2, sz * .5)) img.draw(c, o.k!, o.x, y - sz * .2, sz, h: sz * .5);
          } else {
            c.save();
            c.translate(o.x, y + sz * .4);
            final sq = 1 + math.sin(t * 9 + o.x) * .05;
            c.scale(1 / sq, sq);
            if (!anim(c, enS, l[0], t + o.x, 0, -sz * .4, sz * (o.k == 'Ogre' ? 1.1 : 1))) img.draw(c, o.k!, 0, -sz * .9, sz);
            c.restore();
          }
        }
        c.restore();
        if (o.hitT > 0 && !good.contains(o.k)) img.draw(c, 'Collision', o.x, o.y - cw * .4, cw * .4 * (1 + (1 - hitK) * .4), alpha: hitK);
      }
      c.drawArc(Rect.fromCenter(center: Offset(o.x, o.y + 4), width: cw * .76, height: cw * .2), 0, math.pi, true, Paint()..color = const Color(0xFF8D5524));
    }
    D.draw(c);
    c.restore();
    final hm = hammer;
    if (hm != null) {
      final k = 1 - hm.t / .2, sw = k < .4 ? -1.1 + easeOutBack(k / .4) * 1.5 : .4 - (k - .4) * .6;
      img.draw(c, 'Hammer', hm.x + 20, hm.y - 20, S * .14, rot: sw);
    }
    F.draw(c);
    funHud(c, W, score: score, time: math.max(0, time - t));
    funGoalPill(c, W, score, need);
    if (t < 2.6) funLevelBanner(c, W, H, lv, tr('Đập $need điểm', 'Whack $need points'), tr('Đừng đập bạn thỏ, bạn cún nhé', "Don't hit the bunny or the puppy"), en);
    if (end != null) funBanner(c, W, H, funEnd(end!.win, lv, en), pts(score, need));
  }
}

// =================================================================================================================
// Câu cá: chạm chỗ muốn thả lưỡi câu; cá to nhiều điểm, sứa làm rơi cá
// =================================================================================================================

class _Fish {
  _Fish(this.k, this.pts, this.x, this.y, this.dir, this.v, this.w, this.ph);
  final String k;
  final int pts;
  double x, y, dir, v, w, ph;
}

class FishingGame extends _MoreGame {
  FishingGame(super.ctx);
  static const fish = [('Tropical fish', 1), ('Fish', 1), ('Blowfish', 2), ('Octopus', 3), ('Crab', 2), ('Shark', 5), ('Spouting whale', 8)];
  static const flook = {'Tropical fish': ('a', 'fishy'), 'Fish': ('a', 'fishb'), 'Blowfish': ('s', 'fish_brown'), 'Shark': ('a', 'eel')};
  static const weedKinds = ['seaweed_green_a', 'seaweed_green_b', 'seaweed_grass_a', 'seaweed_pink_a', 'seaweed_orange_a', 'rock_a'];
  static const time = 55.0;
  late final int need = (12 + lv * .6).round();
  final D = Dust(160);
  late double sea;
  final weeds = <({double x, String k, double s, double ph})>[];
  final bubbles = <List<double>>[]; // x, y, v, s, ph
  late double boatX, boatTx;
  late double hookX, hookY, hookTy;
  String hookState = 'idle';
  _Fish? _hooked;
  final swim = <_Fish>[];
  int score = 0;
  double spawn = 0;

  @override
  List<String> get images => [...fish.map((f) => f.$1), 'Jellyfish', 'Sailboat', 'Cloud', 'Gem stone', 'Running shoe', ctx.heroImg, th.sun];
  @override
  List<String> get sheetNames => ['plat/enemies', 'fish/fish'];

  @override
  void init() {
    sea = H * .3;
    for (var i = 0; i < (W / 70).ceil(); i++) {
      weeds.add((x: i * 70 + rand(0, 40), k: pick(weedKinds), s: rand(.7, 1.2), ph: rand(0, 6)));
    }
    for (var i = 0; i < 14; i++) {
      bubbles.add([rand(0, W), rand(H * .35, H), rand(30, 70), rand(8, 18), rand(0, 6)]);
    }
    boatX = boatTx = W / 2;
    hookX = W / 2;
    hookY = sea;
    hookTy = sea;
  }

  @override
  void pointerDown(Offset p, int id) {
    if (hookState != 'idle' || end != null) return;
    boatTx = p.dx.clamp(S * .16, W - S * .16);
    hookTy = p.dy.clamp(sea + 40, H - 30);
    hookState = 'move';
  }

  void _add() {
    final deep = rng.nextDouble();
    final pool = deep < .4 ? fish.sublist(0, 3) : (deep < .75 ? fish.sublist(1, 5) : fish.sublist(3));
    final (String k, int pts) = rng.nextDouble() < ramp(lv, .14, .3)
        ? ('Jellyfish', -1)
        : rng.nextDouble() < .05
            ? ('Gem stone', 10)
            : rng.nextDouble() < .05
                ? ('Running shoe', 0)
                : pick(pool);
    final dir = rng.nextDouble() < .5 ? 1.0 : -1.0, sz = S * (pts >= 5 ? .2 : (pts >= 3 ? .14 : .1));
    swim.add(_Fish(k, pts, dir > 0 ? -sz : W + sz, sea + 50 + (pts >= 3 || k == 'Gem stone' ? rand(.45, .95) : rand(.05, .6)) * (H - sea - 90), dir,
        rand(50, 110) * (pts >= 5 ? .7 : 1) * ramp(lv, 1, 1.7), sz, rand(0, 6)));
  }

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    spawn -= dt;
    if (spawn <= 0 && swim.length < 10) {
      spawn = rand(.5, 1.1);
      _add();
    }
    D.update(dt);
    for (final b in bubbles) {
      b[1] -= b[2] * dt;
      b[4] += dt;
      if (b[1] < sea) {
        b[1] = H + 10;
        b[0] = rand(0, W);
      }
    }
    for (var i = swim.length - 1; i >= 0; i--) {
      final f = swim[i];
      f.ph += dt;
      f.x += f.dir * f.v * dt;
      f.y += math.sin(f.ph * 2) * 10 * dt;
      if (f.x < -150 || f.x > W + 150) swim.removeAt(i);
    }
    // Thuyền chạy tới chỗ bé chạm, rồi thả câu
    if (hookState == 'move') {
      boatX = approach(boatX, boatTx, 4, dt);
      if (rng.nextDouble() < .5) D.emit(boatX - (boatTx - boatX).sign * S * .1, sea, rand(-40, 40), rand(-60, -20), life: .5, r: 3, grow: 4, c: const Color(0xFFE7F5FF), k: 2, g: 300, a: .9);
      hookX = boatX;
      if ((boatTx - boatX).abs() < 4) hookState = 'down';
    } else if (hookState == 'down') {
      hookY += 420 * dt;
      _Fish? f;
      for (final q in swim) {
        if (math.sqrt(math.pow(q.x - hookX, 2) + math.pow(q.y - hookY, 2)) < q.w * .5) {
          f = q;
          break;
        }
      }
      if (f != null) {
        if (f.k == 'Jellyfish') {
          sfx('hit');
          F.text(hookX, hookY - 20, tr('Bị sứa chích!', 'Jellyfish sting!'), const Color(0xFFDA77F2));
          hookState = 'up';
        } else {
          _hooked = f;
          swim.remove(f);
          hookState = 'up';
          sfx('pop');
          for (var k = 0; k < 6; k++) {
            D.emit(hookX + rand(-10, 10), hookY, rand(-30, 30), rand(-90, -40), life: .8, r: 3, grow: 3, c: Colors.white, a: .6);
          }
        }
      } else if (hookY >= hookTy) {
        hookState = 'up';
      }
    } else if (hookState == 'up') {
      hookY -= (_hooked != null && _hooked!.pts >= 5 ? 220 : 340) * dt;
      if (_hooked != null) _hooked!.ph += dt;
      if (hookY <= sea) {
        hookY = sea;
        hookState = 'idle';
        final f = _hooked;
        if (f != null) {
          if (f.pts > 0) {
            score += f.pts;
            sfx(f.pts >= 5 ? 'win' : 'coin');
            F.text(hookX, sea - 60, '+${f.pts}', _gold);
            D.sparks(hookX, sea - 30, 12, const Color(0xFFFFE066), 240);
          } else {
            F.text(hookX, sea - 60, tr('Chiếc giày cũ!', 'An old shoe!'), const Color(0xFFADB5BD));
          }
          for (var k = 0; k < 10; k++) {
            D.emit(hookX + rand(-20, 20), sea, rand(-120, 120), rand(-260, -120), life: .7, r: 3, grow: 0, c: const Color(0xFFD0EBFF), k: 2, g: 700, a: 1);
          }
          _hooked = null;
        }
      }
    }
    if (hookState == 'idle') hookX = boatX;
    if (t >= time && hookState == 'idle') {
      end = FunResult(win: score >= need, score: score);
      sfx(score >= need ? 'win' : 'pop');
    }
    F.update(dt);
    return null;
  }

  /// Cá đang bơi (cho kiểm thử).
  List<Offset> get fishSpots => [for (final f in swim) if (f.pts > 0) Offset(f.x, f.y)];

  void _drawFish(Canvas c, _Fish f, double x, double y, [double rot = 0]) {
    final enS = sheets['plat/enemies'], fs = sheets['fish/fish'];
    final l = flook[f.k], wig = math.sin(f.ph * 9) * .08, flip = f.dir > 0;
    if (l != null && l.$1 == 'a') {
      c.save();
      c.translate(x, y);
      c.rotate(rot + wig * .5);
      c.scale(1 + wig * .5, 1);
      final eel = l.$2 == 'eel';
      if (!anim(c, eel ? fs : enS, l.$2, f.ph, 0, 0, f.w * (eel ? .45 : 1), flip: eel ? !flip : flip)) img.draw(c, f.k, 0, 0, f.w, flip: flip);
      c.restore();
    } else if (l != null) {
      final puff = 1 + math.max(0, math.sin(f.ph * 2)) * .15;
      if (!spr(c, fs, l.$2, x, y, f.w * puff, flip: flip, rot: rot)) img.draw(c, f.k, x, y, f.w, flip: flip, rot: rot);
    } else if (f.k == 'Jellyfish') {
      final pk = 1 + math.sin(f.ph * 4) * .1;
      img.draw(c, f.k, x, y + math.sin(f.ph * 4) * 6, f.w * (2 - pk), h: f.w * pk, rot: rot);
    } else {
      img.draw(c, f.k, x, y, f.w * (1 + wig), h: f.w * (1 - wig * .5), flip: flip && f.k != 'Gem stone' && f.k != 'Running shoe', rot: rot + (f.k == 'Gem stone' ? math.sin(f.ph * 3) * .2 : 0));
    }
  }

  @override
  void paint(Canvas c) {
    final fs = sheets['fish/fish'];
    funSky(c, W, sea, th.skyTop, th.skyBottom);
    img.draw(c, th.sun, W * .85, sea * .4, S * .12);
    funSky(c, W, H, const Color(0xFF4DABF7), const Color(0xFF1864AB), sea);
    final wave = Paint()..color = const Color(0x59FFFFFF);
    for (double x = -40; x < W + 40; x += 40) {
      c.drawArc(Rect.fromCircle(center: Offset(x + (t * 30) % 40, sea), radius: 14), math.pi, math.pi, true, wave);
    }
    c.drawArc(Rect.fromCenter(center: Offset(W / 2, H + 20), width: W * 1.4, height: 100), math.pi, math.pi, true, Paint()..color = const Color(0xFFE9C46A));
    // Đáy biển: rong biển đung đưa, bọt nước nổi lên
    for (final w in weeds) {
      if (fs?.frames[w.k] == null) continue;
      final hh = S * .14 * w.s;
      c.save();
      c.translate(w.x, H - 12);
      c.transform(Float64List.fromList([1, 0, 0, 0, math.sin(t * 1.5 + w.ph) * .15, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      spr(c, fs, w.k, 0, -hh / 2, hh);
      c.restore();
    }
    for (final b in bubbles) {
      spr(c, fs, 'bubble_c', b[0] + math.sin(b[4] * 2) * 6, b[1], b[3], alpha: .7);
    }
    for (final f in swim) {
      _drawFish(c, f, f.x, f.y);
    }
    // Dây câu
    c.drawLine(Offset(boatX + S * .08, sea - S * .1), Offset(hookX, hookY), Paint()
      ..color = Colors.white
      ..strokeWidth = 2);
    c.drawArc(Rect.fromCircle(center: Offset(hookX - 6, hookY), radius: 8), 0, math.pi, false, Paint()
      ..color = const Color(0xFFADB5BD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    final hf = _hooked;
    if (hf != null) _drawFish(c, hf, hookX, hookY + hf.w * .4, math.pi / 2 * (hf.dir > 0 ? 1 : -1) + math.sin(t * 14) * .25);
    D.draw(c);
    // Thuyền nhấp nhô theo sóng, nghiêng khi chạy; bé ngồi cầm cần câu
    final bob = math.sin(t * 2.2) * 4, roll = math.sin(t * 1.7) * .05 + (boatTx - boatX) * -.0008;
    c.save();
    c.translate(boatX, sea + bob);
    c.rotate(roll);
    c.translate(-boatX, -sea);
    img.draw(c, 'Sailboat', boatX, sea - S * .08, S * .22);
    drawFigure(c, boatX - S * .04, sea - S * .09, S * .15, heroOf(ctx.heroImg), pose: 'sit', t: t, face: 1);
    c.restore();
    c.drawLine(Offset(boatX - S * .005, sea - S * .14), Offset(boatX + S * .08, sea - S * .1), Paint()
      ..color = const Color(0xFF8D5524)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    F.draw(c);
    funHud(c, W, score: score, time: math.max(0, time - t));
    funGoalPill(c, W, score, need);
    if (t < 2.6) funLevelBanner(c, W, H, lv, tr('Câu $need điểm', 'Fish $need points'), tr('Chạm xuống biển để thả câu · Né con sứa', 'Tap the sea to drop the hook · Avoid jellyfish'), en);
    if (end != null) funBanner(c, W, H, funEnd(end!.win, lv, en), pts(score, need));
  }
}

// =================================================================================================================
// Xây tháp: khối đung đưa, chạm để thả; phần thừa rơi mất
// =================================================================================================================

class _Fall {
  _Fall(this.x, this.y, this.w, this.vy, this.vr, this.c);
  double x, y, w, vy, vr, r = 0;
  final Color c;
}

class StackGame extends _MoreGame {
  StackGame(super.ctx);
  static const cols = [Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B), Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA), Color(0xFFF783AC)];
  static const pzNames = ['rect_red', 'rect_yellow', 'rect_yellow', 'rect_green', 'rect_blue', 'rect_purple', 'rect_red'];
  late final int need = math.min(40, 8 + (lv * .55).floor());
  final D = Dust(160);
  late double bh;
  double land = 0, cam = 0;
  int landI = -1, score = 0, perfect = 0, lives = 2;
  final tower = <({double x, double w})>[];
  ({double x, double w, double v})? _cur;
  double curDir = 1;
  final falling = <_Fall>[];

  @override
  List<String> get images => ['Cloud', 'Crown', th.sun];
  @override
  List<String> get sheetNames => ['puzzle/puzzle', 'plat/tiles', 'plat/bg'];

  /// Số tầng đã xây.
  int get floors => tower.length - 1;

  /// Vị trí khối đang đung đưa + khối trên cùng (cho kiểm thử).
  double? get curX => _cur?.x;
  double get topX => tower.last.x;

  @override
  void init() {
    bh = S * .07;
    tower.add((x: W / 2, w: W * .42));
    _next();
  }

  void _next() {
    final top = tower.last;
    _cur = (x: W * .15, w: top.w, v: math.min(ramp(lv, 520, 680), ramp(lv, 210, 330) + tower.length * 14));
    curDir = 1;
  }

  @override
  void pointerDown(Offset p, int id) {
    final cur = _cur;
    if (cur == null || end != null) return;
    final top = tower.last;
    final l = math.max(cur.x - cur.w / 2, top.x - top.w / 2), r = math.min(cur.x + cur.w / 2, top.x + top.w / 2);
    final yTop = H * .82 - tower.length * bh;
    final col = cols[tower.length % cols.length];
    if (r - l < 8) {
      falling.add(_Fall(cur.x, yTop, cur.w, 0, rand(-3, 3), col));
      sfx('wrong');
      lives--;
      sh.add(6);
      if (lives <= 0) {
        end = FunResult(win: tower.length - 1 >= need, score: score);
      } else {
        F.text(W / 2, H * .3, tr('Thử lại!', 'Try again!'));
        _next();
      }
      return;
    }
    var w = r - l, x = (l + r) / 2;
    if ((cur.x - top.x).abs() < 6) {
      w = top.w;
      x = top.x;
      perfect++;
      sfx('power');
      F.text(x, yTop + cam - 30, tr('HOÀN HẢO!', 'PERFECT!'), _gold);
      score += 2;
      if (perfect % 3 == 0) w = math.min(W * .42, w + 20);
      D.sparks(x - w / 2, yTop + cam, 8, const Color(0xFFFFF3BF), 220);
      D.sparks(x + w / 2, yTop + cam, 8, const Color(0xFFFFF3BF), 220);
    } else {
      perfect = 0;
      sfx('pop');
      final cutX = cur.x > top.x ? r + (cur.w - w) / 2 : l - (cur.w - w) / 2;
      falling.add(_Fall(cutX, yTop, cur.w - w, -120, (cur.x > top.x ? 1 : -1) * rand(2, 4), col));
    }
    land = .3;
    landI = tower.length;
    sh.add(2.5);
    D.puff(x - w / 2, yTop + cam + bh * .4, 3, Colors.white, 50, 5);
    D.puff(x + w / 2, yTop + cam + bh * .4, 3, Colors.white, 50, 5);
    tower.add((x: x, w: w));
    score += 1;
    F.burst(x, yTop + cam, 8);
    _next();
  }

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    final cur = _cur;
    if (cur != null) {
      var x = cur.x + curDir * cur.v * dt;
      if (x > W - cur.w / 2 - 10) curDir = -1;
      if (x < cur.w / 2 + 10) curDir = 1;
      _cur = (x: x, w: cur.w, v: cur.v);
    }
    final want = math.max(0.0, tower.length * bh - H * .45);
    cam += (want - cam) * math.min(1, dt * 4);
    for (var i = falling.length - 1; i >= 0; i--) {
      final f = falling[i];
      f.vy += 1400 * dt;
      f.y += f.vy * dt;
      f.r += f.vr * dt;
      if (f.y > H + cam + 200) falling.removeAt(i);
    }
    land = math.max(0, land - dt);
    sh.update(dt);
    D.update(dt);
    if (tower.length - 1 >= need) {
      end = FunResult(win: true, score: score + 20);
      sfx('win');
    }
    F.update(dt);
    return null;
  }

  void _block(Canvas c, double x, double y, double w, int ci, {double sx = 1, double sy = 1, double rot = 0, double a = 1, Color? color}) {
    final pz = sheets['puzzle/puzzle'];
    c.save();
    c.translate(x, y + bh / 2);
    if (rot != 0) c.rotate(rot);
    c.scale(sx, sy);
    if (pz != null) {
      sprBox(c, pz, pzNames[ci % pzNames.length], 0, -bh / 2, w, bh - 2, a);
    } else {
      fillRRect(c, -w / 2, -bh, w, bh - 2, 8, (color ?? cols[ci % cols.length]).withValues(alpha: a));
    }
    c.restore();
  }

  @override
  void paint(Canvas c) {
    final tl = sheets['plat/tiles'], bgs = sheets['plat/bg'];
    final hgt = math.min(1.0, cam / (H * 3));
    funSky(c, W, H, hgt > .5 ? const Color(0xFF364FC7) : th.skyTop, hgt > .5 ? const Color(0xFF748FFC) : th.skyBottom);
    img.draw(c, th.sun, W * .85, H * .12 + cam * .1, S * .12);
    for (var k = 0; k < 4; k++) {
      img.draw(c, 'Cloud', (k * 230 + 60) % W, ((k * 170 + cam * .5) % (H + 100)) - 50, 110, h: 66);
    }
    c.save();
    sh.apply(c);
    c.translate(0, cam);
    backHills(c, bgs, lv, 0, H * .82 + bh * .5 + 6, H * .3, W);
    if (tl == null) c.drawRect(Rect.fromLTWH(0, H * .82 + bh * .5, W, H), Paint()..color = th.groundColor);
    groundTiles(c, tl, lv, 0, H * .82 + bh * .5, W, H * 1.5, math.max(40, S * .07));
    // Tầng vừa đặt nhún xuống, các tầng dưới nhún theo nhỏ dần
    for (var i = 0; i < tower.length; i++) {
      final b = tower[i], y = H * .82 - i * bh;
      final k = land > 0 && landI >= 0 ? math.sin(land / .3 * math.pi) * .12 * math.max(0, 1 - (landI - i) * .25) : 0.0;
      _block(c, b.x, y, b.w, i, sx: 1 + k * .5, sy: 1 - k);
    }
    final cur = _cur;
    if (cur != null && end == null) {
      final y = H * .82 - tower.length * bh;
      final dash = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 2;
      for (var yy = -cam; yy < y - bh / 2; yy += 12) {
        c.drawLine(Offset(cur.x, yy), Offset(cur.x, math.min(yy + 6, y - bh / 2)), dash);
      }
      _block(c, cur.x, y + math.sin(t * 6) * 3, cur.w, tower.length, rot: curDir * math.sin(t * 3) * .02);
    }
    for (final f in falling) {
      _block(c, f.x, f.y, f.w, cols.indexOf(f.c), rot: f.r, a: .85, color: f.c);
    }
    c.restore();
    D.draw(c);
    F.draw(c);
    funHud(c, W, score: score);
    fillRRect(c, W / 2 - 70, 10, 140, 44, 22, _shade);
    FunText.draw(c, '🏢 ${tower.length - 1}/$need', W / 2, 42, size: 26);
    _heartsHud(this, c, lives);
    if (t < 2.6) funLevelBanner(c, W, H, lv, tr('Xây $need tầng', 'Build $need floors'), tr('Chạm để thả khối thật thẳng', 'Tap to drop each block straight'), en);
    if (end != null) funBanner(c, W, H, funEnd(end!.win, lv, en), tr('${tower.length - 1} tầng · $score điểm', '${tower.length - 1} floors · $score points'));
  }
}

// =================================================================================================================
// Phá gạch: kéo thanh đỡ, bóng phá gạch; gạch rơi quà (nhiều bóng, thanh dài, bóng lửa)
// =================================================================================================================

class _Ball {
  _Ball(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
}

class _Brick {
  _Brick(this.x, this.y, this.w, this.h, this.hp, this.c, this.col);
  final double x, y, w, h;
  int hp;
  Color c;
  final Color col;
  double hitT = 0;
}

class BreakoutGame extends _MoreGame {
  BreakoutGame(super.ctx);
  static const cols = [Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B), Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA)];
  static const _grey2 = Color(0xFFADB5BD), _grey3 = Color(0xFF868E96);
  static final Map<int, String> pz = {
    0xFFFF6B6B: 'rect_red', 0xFFFFA94D: 'rect_yellow', 0xFFFFD43B: 'rect_yellow', 0xFF69DB7C: 'rect_green', 0xFF4DABF7: 'rect_blue', //
    0xFF9775FA: 'rect_purple', 0xFFADB5BD: 'rect_grey', 0xFF868E96: 'rect_grey',
  };
  // 8 kiểu xếp: đầy, ô cờ, kim tự tháp, sọc, kim cương, khung, cột, lỗ ngẫu nhiên
  static final List<bool Function(int r, int c, int rr, int cc)> skip = [
    (r, c, rr, cc) => false,
    (r, c, rr, cc) => (r + c) % 3 == 0,
    (r, c, rr, cc) => (c - (cc - 1) / 2).abs() > rr - r + 1,
    (r, c, rr, cc) => r % 2 == 1,
    (r, c, rr, cc) => (c - (cc - 1) / 2).abs() / (cc / 2) + (r - (rr - 1) / 2).abs() / (rr / 2) > 1.05,
    (r, c, rr, cc) => r > 0 && r < rr - 1 && c > 0 && c < cc - 1 && !(r == rr ~/ 2 && (c - (cc - 1) / 2).abs() < 1.5),
    (r, c, rr, cc) => c % 3 == 1,
    (r, c, rr, cc) => rng.nextDouble() < .28,
  ];
  late final int screens = lv < 10 ? 1 : 2;
  final D = Dust(260);
  final trail = List.generate(8, (_) => [0.0, 0.0]);
  int trailI = 0, score = 0, lives = _hearts, lvl = 0;
  double padSq = 0, fireT = 0;
  late double padX, padY, padW, padTx, R;
  double padH = 18, padBig = 0;
  var balls = <_Ball>[];
  var bricks = <_Brick>[];
  var drops = <({String k, double x, double y})>[];
  bool launched = false;

  @override
  List<String> get images => ['Fire', 'Soccer ball', 'Sparkles'];
  @override
  List<String> get sheetNames => ['puzzle/puzzle', 'fxa/fx'];

  @override
  void init() {
    padX = padTx = W / 2;
    padY = H * .9;
    padW = S * ramp(lv, .26, .19);
    R = math.max(9, S * .016);
    _build();
    _serve();
  }

  void _build() {
    bricks = [];
    final pat = lv < 10 ? lv % skip.length : (lv * 2 + lvl) % skip.length;
    final int cc = W > H ? 10 : 7, rr = 3 + (lv ~/ 8).clamp(0, 5) + (pat == 3 ? 2 : 0);
    final bw = (W - 40) / cc, bhh = math.min(30.0, H * .045);
    final hard = lv ~/ 12;
    for (var r = 0; r < rr; r++) {
      for (var c = 0; c < cc; c++) {
        if (skip[pat](r, c, rr, cc)) continue;
        final hp = r < hard ? (lv >= 30 && r == 0 ? 3 : 2) : 1;
        final col = cols[r % cols.length];
        bricks.add(_Brick(20 + c * bw + bw / 2, 110 + r * (bhh + 6), bw - 6, bhh, hp, hp > 1 ? (hp > 2 ? _grey3 : _grey2) : col, col));
      }
    }
    if (bricks.isEmpty) _build();
  }

  void _serve() {
    balls = [_Ball(padX, padY - 30, 0, 0)];
    launched = false;
  }

  @override
  void pointerDown(Offset p, int id) => padTx = p.dx;
  @override
  void pointerMove(Offset p, int id, bool down) {
    if (down) padTx = p.dx;
  }

  @override
  void pointerUp(Offset p, int id) {
    if (!launched && end == null && balls.isNotEmpty) {
      launched = true;
      final sp = S * .75 * ramp(lv, 1, 1.45);
      balls[0].vx = sp * rand(-.4, .4);
      balls[0].vy = -sp;
      sfx('jump');
    }
  }

  /// Gạch còn lại (cho kiểm thử).
  int get bricksLeft => bricks.length;
  double get ballX => balls.isEmpty ? padX : balls.first.x;

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    padBig = math.max(0, padBig - dt);
    fireT = math.max(0, fireT - dt);
    padSq = math.max(0, padSq - dt);
    sh.update(dt);
    D.update(dt);
    for (final br in bricks) {
      if (br.hitT > 0) br.hitT = math.max(0, br.hitT - dt);
    }
    if (balls.isNotEmpty && launched) {
      trail[trailI][0] = balls[0].x;
      trail[trailI][1] = balls[0].y;
      trailI = (trailI + 1) % trail.length;
    }
    if (fireT > 0) {
      for (final b in balls) {
        if (rng.nextDouble() < .6) D.emit(b.x, b.y, rand(-30, 30), rand(-30, 30), life: .35, r: R * .7, grow: 4, c: rng.nextDouble() < .5 ? const Color(0xFFFF922B) : _gold, a: .8);
      }
    }
    final pw = padW * (padBig > 0 ? 1.6 : 1);
    padX += (padTx.clamp(pw / 2, W - pw / 2) - padX) * math.min(1, dt * 16);
    if (!launched && balls.isNotEmpty) {
      balls[0].x = padX;
      balls[0].y = padY - 26;
    }
    for (var i = balls.length - 1; i >= 0; i--) {
      final b = balls[i];
      for (var k = 0; k < 3; k++) {
        b.x += b.vx * dt / 3;
        b.y += b.vy * dt / 3;
        if (b.x < R) {
          b.x = R;
          b.vx = b.vx.abs();
        }
        if (b.x > W - R) {
          b.x = W - R;
          b.vx = -b.vx.abs();
        }
        if (b.y < 70 + R) {
          b.y = 70 + R;
          b.vy = b.vy.abs();
        }
        if (b.vy > 0 && b.y + R > padY - padH / 2 && b.y < padY + padH && (b.x - padX).abs() < pw / 2 + R) {
          final off = (b.x - padX) / (pw / 2), sp = math.sqrt(b.vx * b.vx + b.vy * b.vy) * 1.01;
          b.vx = sp * off * .8;
          b.vy = -math.sqrt(math.max(1, sp * sp - b.vx * b.vx));
          sfx('tap');
          padSq = .15;
          D.sparks(b.x, padY - padH / 2, 5, const Color(0xFFA5D8FF), 160);
        }
        for (var j = bricks.length - 1; j >= 0; j--) {
          final br = bricks[j];
          if ((b.x - br.x).abs() < br.w / 2 + R && (b.y - br.y).abs() < br.h / 2 + R) {
            if (fireT <= 0) {
              if ((b.x - br.x).abs() / br.w > (b.y - br.y).abs() / br.h) {
                b.vx *= -1;
              } else {
                b.vy *= -1;
              }
            }
            if (--br.hp <= 0 || fireT > 0) {
              bricks.removeAt(j);
              score++;
              sfx('pop');
              D.debris(br.x, br.y, 7, br.col, 240);
              D.sparks(br.x, br.y, 6, Colors.white, 200);
              sh.add(1.8);
              if (rng.nextDouble() < .15) drops.add((k: pick(const ['multi', 'big', 'fire', 'heart', 'multi']), x: br.x, y: br.y));
            } else {
              br.c = br.hp > 1 ? _grey2 : br.col;
              br.hitT = .15;
              sfx('tap');
              D.sparks(b.x, b.y, 4, const Color(0xFFCED4DA), 140);
            }
            break;
          }
        }
      }
      if (b.y > H + 30) balls.removeAt(i);
    }
    if (balls.isEmpty) {
      lives--;
      sfx('hit');
      sh.add(8);
      if (lives <= 0) {
        end = FunResult(win: false, score: score);
      } else {
        _serve();
      }
    }
    for (var i = drops.length - 1; i >= 0; i--) {
      final d = drops[i];
      final ny = d.y + 180 * dt;
      if (ny > H + 30) {
        drops.removeAt(i);
        continue;
      }
      drops[i] = (k: d.k, x: d.x, y: ny);
      if ((ny - padY).abs() < 24 && (d.x - padX).abs() < pw / 2 + 16) {
        drops.removeAt(i);
        sfx('power');
        switch (d.k) {
          case 'multi':
            final add = [for (final b in balls.take(3)) ...[_Ball(b.x, b.y, b.vx + 160, b.vy), _Ball(b.x, b.y, b.vx - 160, b.vy)]];
            balls.addAll(add);
            F.text(d.x, ny - 30, tr('NHIỀU BÓNG!', 'MULTI BALL!'), _gold);
          case 'big':
            padBig = 12;
            F.text(d.x, ny - 30, tr('THANH DÀI!', 'BIG PADDLE!'), const Color(0xFF4DABF7));
          case 'fire':
            fireT = 8;
            F.text(d.x, ny - 30, tr('BÓNG LỬA!', 'FIRE BALL!'), const Color(0xFFFF922B));
          default:
            lives = math.min(_hearts, lives + 1);
            F.text(d.x, ny - 30, '+❤', const Color(0xFFFF6B6B));
        }
      }
    }
    if (bricks.isEmpty) {
      score += 10;
      lvl++;
      sfx('win');
      F.text(W / 2, H * .5, tr('QUA MÀN!', 'STAGE CLEAR!'), _gold);
      if (lvl >= screens) {
        end = FunResult(win: true, score: score);
      } else {
        _build();
        _serve();
        drops = [];
      }
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    final pzS = sheets['puzzle/puzzle'];
    c.save();
    sh.apply(c);
    funSky(c, W, H, const Color(0xFF212529), th.edgeColor);
    for (final br in bricks) {
      final k = br.hitT > 0 ? 1 + br.hitT * 1.2 : 1.0;
      if (pzS != null) {
        sprBox(c, pzS, pz[br.c.toARGB32()] ?? pz[br.col.toARGB32()] ?? 'rect_blue', br.x, br.y, br.w * k, br.h * k);
      } else {
        fillRRect(c, br.x - br.w / 2, br.y - br.h / 2, br.w, br.h, 6, br.c);
      }
      if (br.hp > 1) FunText.draw(c, '${br.hp}', br.x, br.y + br.h * .22, size: br.h * .6, color: const Color(0x59000000));
    }
    for (final d in drops) {
      const ims = {'multi': 'Sparkles', 'big': 'Glowing star', 'fire': 'Fire', 'heart': 'Red heart'};
      fillCircle(c, d.x, d.y, 20 + math.sin(t * 8) * 2, const Color(0x33FFFFFF));
      img.draw(c, ims[d.k]!, d.x, d.y, 32, rot: math.sin(t * 5 + d.x) * .3);
    }
    final pw = padW * (padBig > 0 ? 1.6 : 1), psq = padSq > 0 ? math.sin(padSq / .15 * math.pi) * .25 : 0.0;
    if (pzS != null) {
      sprBox(c, pzS, 'paddleBlu', padX, padY + psq * 4, pw * (1 + psq * .1), padH * 1.5 * (1 - psq));
    } else {
      fillRRect(c, padX - pw / 2, padY - padH / 2, pw, padH, 9, const Color(0xFF4DABF7));
    }
    // Vệt bóng
    if (launched && balls.isNotEmpty && fireT <= 0) {
      for (var i = 0; i < trail.length; i++) {
        final p = trail[(trailI + i) % trail.length];
        fillCircle(c, p[0], p[1], R * (.4 + i / trail.length * .5), const Color(0xFF74C0FC).withValues(alpha: i / trail.length * .35));
      }
    }
    D.draw(c);
    for (final b in balls) {
      if (fireT > 0) {
        img.draw(c, 'Fire', b.x, b.y - 4, R * 3.2);
      } else if (!spr(c, pzS, 'ballBlue', b.x, b.y, R * 2.2)) {
        fillCircle(c, b.x, b.y, R, Colors.white);
      }
    }
    c.restore();
    F.draw(c);
    funHud(c, W, score: score);
    _heartsHud(this, c, lives);
    FunText.draw(c, tr('Cấp ${lv + 1} · Màn ${math.min(lvl + 1, screens)}/$screens', 'Level ${lv + 1} · Stage ${math.min(lvl + 1, screens)}/$screens'), W / 2, 40,
        size: 22, color: const Color(0xCCFFFFFF), fit: W - 300);
    if (!launched && end == null) FunText.draw(c, tr('Kéo thanh rồi thả tay để bắn bóng', 'Drag the paddle, let go to launch'), W / 2, H * .7, size: 24, weight: FontWeight.w700, fit: W - 24);
    if (t < 2.6 && !launched) funLevelBanner(c, W, H, lv, screens > 1 ? tr('Phá hết gạch 2 màn', 'Clear the bricks of 2 stages') : tr('Phá hết gạch', 'Clear all bricks'), themeName, en);
    if (end != null) funBanner(c, W, H, end!.win ? funEnd(true, lv, en) : tr('HẾT BÓNG!', 'OUT OF BALLS!'), pts(score));
  }
}

// =================================================================================================================
// Chim bay: chạm để vỗ cánh, bay qua khe giữa hai thân cây, ăn xu
// =================================================================================================================

class _Pipe {
  _Pipe(this.x, this.gy, this.gh, this.w, this.mv, this.ph) : gy0 = gy;
  double x, gy, ph;
  final double gy0, gh, w, mv;
  bool done = false;
}

class FlappyGame extends _MoreGame {
  FlappyGame(super.ctx);
  late final int need = 10 + lv ~/ 2;
  late final bool wobble = lv >= 15;
  final D = Dust(160);
  late double ground, birdX, birdY, birdW;
  double birdVy = 0, inv = 0, scroll = 0, flapT = 0, spawn = 0;
  final pipes = <_Pipe>[];
  final coins = <List<double>>[]; // x, y
  int score = 0, lives = _hearts, passed = 0;
  bool started = false;

  @override
  List<String> get images => ['Baby chick', 'Cloud', th.sun];
  @override
  List<String> get sheetNames => ['creatures/flyers', 'plat/tiles', 'plat/bg', 'fxa/fx'];

  double get _gapH => math.max(S * ramp(lv, .3, .25), S * ramp(lv, .42, .32) - passed * 3);

  @override
  void init() {
    ground = H * .9;
    birdX = W * .25;
    birdY = H * .45;
    birdW = S * .1;
  }

  /// Khe kế tiếp phía trước chim (cho kiểm thử): tâm khe y, null nếu chưa có.
  double? get nextGapY {
    for (final p in pipes) {
      if (p.x + p.w / 2 > birdX - birdW * .4) return p.gy;
    }
    return null;
  }

  double get bird => birdY;
  double get birdVel => birdVy;

  @override
  void pointerDown(Offset p, int id) => flap();

  /// Vỗ cánh (chạm màn hình).
  void flap() {
    if (end != null) return;
    started = true;
    birdVy = -S * 1.15;
    sfx('jump');
    flapT = .25;
    for (var k = 0; k < 3; k++) {
      D.emit(birdX - birdW * .3, birdY, rand(-120, -40), rand(20, 90), life: .5, r: 3, grow: 3, c: const Color(0xFFFFF3BF), k: 2, g: 200, a: 1);
    }
  }

  void _hurt() {
    lives--;
    inv = 1.5;
    sfx('hit');
    sh.add(9);
    for (var k = 0; k < 8; k++) {
      D.emit(birdX, birdY, rand(-160, 160), rand(-200, 40), life: .9, r: 4, grow: 0, c: pick(const [_gold, Color(0xFFFFF3BF), Color(0xFFFAB005)]), k: 2, g: 500, a: 1);
    }
    if (lives <= 0) end = FunResult(win: false, score: score);
  }

  @override
  FunResult? update(double dt) {
    t += dt;
    if (end != null) return endStep(dt);
    D.update(dt);
    sh.update(dt);
    flapT = math.max(0, flapT - dt);
    if (!started) {
      birdY = H * .45 + math.sin(t * 4) * 10;
      scroll += S * .2 * dt;
      F.update(dt);
      return null;
    }
    birdVy += S * 3 * dt;
    birdY += birdVy * dt;
    inv = math.max(0, inv - dt);
    final v = S * .38 * ramp(lv, 1, 1.45) + passed * 2;
    scroll += v * dt;
    spawn -= dt;
    if (spawn <= 0) {
      spawn = 1.7 * ramp(lv, 1, .85);
      final gh = _gapH, gy = rand(110 + gh / 2, ground - 40 - gh / 2);
      // Từ cấp 16 có khe di chuyển lên xuống
      final mv = wobble && rng.nextDouble() < ramp(lv, .2, .6) ? math.min(math.min(gy - 110 - gh / 2, ground - 40 - gh / 2 - gy), S * .12) : 0.0;
      pipes.add(_Pipe(W + 60, gy, gh, S * .14, mv, rand(0, 6)));
      coins.add([W + 60, gy]);
    }
    for (var i = pipes.length - 1; i >= 0; i--) {
      final p = pipes[i];
      p.x -= v * dt;
      if (p.mv != 0) {
        p.ph += dt * 1.6;
        p.gy = p.gy0 + math.sin(p.ph) * p.mv;
      }
      if (p.x < -100) {
        pipes.removeAt(i);
        continue;
      }
      if (!p.done && p.x < birdX) {
        p.done = true;
        passed++;
        score++;
        sfx('tap');
        D.sparks(birdX, p.gy, 6, const Color(0xFFB2F2BB), 160);
      }
      final inX = (p.x - birdX).abs() < p.w / 2 + birdW * .35;
      final inGap = birdY - birdW * .35 > p.gy - p.gh / 2 && birdY + birdW * .35 < p.gy + p.gh / 2;
      if (inX && !inGap && inv <= 0) _hurt();
      if (end != null) break;
    }
    for (var i = coins.length - 1; i >= 0; i--) {
      final co = coins[i];
      co[0] -= v * dt;
      if (co[0] < -50) {
        coins.removeAt(i);
        continue;
      }
      if (funHit(birdX, birdY, birdW, birdW, co[0], co[1], 36, 36, .9)) {
        score += 2;
        sfx('coin');
        F.text(co[0], co[1] - 20, '+2', _gold);
        D.sparks(co[0], co[1], 6, const Color(0xFFFFE066), 160);
        coins.removeAt(i);
      }
    }
    if (birdY > ground - birdW / 2) {
      birdY = ground - birdW / 2;
      birdVy = -S * .9;
      if (inv <= 0 && end == null) _hurt();
    }
    if (birdY < birdW / 2) {
      birdY = birdW / 2;
      birdVy = 0;
    }
    if (passed >= need && end == null) {
      end = FunResult(win: true, score: score + 10);
      sfx('win');
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    final fl = sheets['creatures/flyers'], tl = sheets['plat/tiles'], bgs = sheets['plat/bg'], fxs = sheets['fxa/fx'];
    c.save();
    sh.apply(c);
    funSky(c, W, H, th.skyTop, th.skyBottom);
    img.draw(c, th.sun, W * .85, H * .13, S * .12);
    // Nền nhiều lớp: mây chậm, đồi vừa, cây/khe nhanh, đất nhanh nhất
    for (var k = 0; k < 4; k++) {
      img.draw(c, 'Cloud', ((k * 260 - scroll * .08) % (W + 200) + W + 200) % (W + 200) - 100, 70 + k * 40.0, 110, h: 66);
    }
    backHills(c, bgs, lv, scroll * .25, ground + 6, H * .32, W);
    for (final p in pipes) {
      final g = Paint()..shader = ui.Gradient.linear(Offset(p.x - p.w / 2, 0), Offset(p.x + p.w / 2, 0), const [Color(0xFF8D5524), Color(0xFFC08552), Color(0xFF8D5524)], const [0, .5, 1]);
      for (final (y0, y1) in [(0.0, p.gy - p.gh / 2), (p.gy + p.gh / 2, ground)]) {
        c.drawRect(Rect.fromLTRB(p.x - p.w / 2, y0, p.x + p.w / 2, y1), g);
        for (var yy = y0 + 20; yy < y1 - 10; yy += 46) {
          c.drawRect(Rect.fromLTWH(p.x - p.w * .3, yy, p.w * .15, 18), Paint()..color = const Color(0x1F000000));
        }
        final cy = y0 == 0 ? y1 : y0;
        fillRRect(c, p.x - p.w * .72, cy - 16, p.w * 1.44, 32, 14, const Color(0xFF2F9E44));
        fillRRect(c, p.x - p.w * .68, cy - 14, p.w * 1.36, 20, 10, const Color(0xFF51CF66));
      }
    }
    for (final co in coins) {
      coin(c, fxs, t + co[0] * .01, co[0], co[1], 36, img['Coin']);
    }
    if (tl == null) c.drawRect(Rect.fromLTWH(0, ground - 4, W, H), Paint()..color = th.groundColor);
    groundTiles(c, tl, lv, scroll, ground - 4, W, H + 20, math.max(40, S * .07));
    D.draw(c);
    final blink = inv > 0 && (inv * 10).floor() % 2 == 0;
    // Chim vỗ cánh nhanh khi vừa chạm, ngóc lên/chúi xuống theo vận tốc
    if (!blink) {
      final rot = (birdVy / (S * 1.6)).clamp(-.5, .9), stretch = flapT > 0 ? 1 + math.sin(flapT / .25 * math.pi) * .1 : 1.0;
      c.save();
      c.translate(birdX, birdY);
      c.rotate(rot);
      c.scale(2 - stretch, stretch);
      if (!anim(c, fl, inv > 1 ? 'hit' : 'fly', t * (flapT > 0 ? 2 : 1), 0, 0, birdW * 1.35)) img.draw(c, 'Baby chick', 0, 0, birdW * 1.3, flip: true);
      c.restore();
    }
    c.restore();
    F.draw(c);
    funHud(c, W, score: score);
    _heartsHud(this, c, lives);
    fillRRect(c, W / 2 - 60, 10, 120, 44, 22, _shade);
    FunText.draw(c, '$passed/$need', W / 2, 42, size: 26);
    if (!started) funLevelBanner(c, W, H, lv, tr('Bay qua $need khe', 'Fly through $need gaps'), tr('Chạm màn hình để vỗ cánh', 'Tap the screen to flap'), en);
    if (end != null) funBanner(c, W, H, end!.win ? funEnd(true, lv, en) : tr('HẾT LƯỢT!', 'OUT OF LIVES!'), pts(score));
  }
}
