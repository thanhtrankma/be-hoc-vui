// ignore_for_file: non_constant_identifier_names
// Thế giới phiêu lưu: 5 vùng kiểu đấu trường (động cơ Arena trong rpgcore.dart).
// Vùng 1 Rừng Xanh, 2 Biển Ngọc, 6 Thành Mây, 9 Đầm Lầy Ma, 10 Lâu Đài Rồng.
// CHỦ: agent H. Port của reference/web/js/games/rpgzones1.js.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/ui/sprite_sheet.dart' show flattenPicture;
import 'package:be_vui_hoc/features/learn/creative/figure.dart';

import 'rpgcore.dart';

int _need(ZoneCtx Z) => Z.boss ? 1 : 6 + Z.s * 2;

/// Sinh quái dần: tối đa `live` con cùng lúc, tổng `need` con.
class Spawner {
  int spawned = 0;
  double spT = .5;
  void run(Arena G, double dt, int need, int live, double every, void Function() make) {
    spT -= dt;
    if (spawned < need && G.foes.length < live && spT <= 0) {
      spT = every;
      spawned++;
      make();
    }
  }
}

String? _killsGoal(Arena G) => G.Z.boss ? null : '⚔️ ${math.min(G.kills, _need(G.Z))}/${_need(G.Z)}';

/// Nền lát ô (Kenney Tiny Town / Tiny Dungeon, pixel) vẽ sẵn một lần. base: các ô nền (ô đầu nhiều nhất),
/// deco: (ô, số lượng, cỡ) rải ngẫu nhiên (tránh dải HUD trên cùng). null nếu chưa có sprite.
class TileBg {
  ui.Picture? _pic;
  ui.Picture? get(Arena G, String sheet, List<String> base, List<(String, int, double)> deco, {double? ts, List<String>? top}) {
    final T = G.sp(sheet);
    if (T == null || T.image == null) return null;
    if (_pic != null) return _pic;
    final size = ts ?? math.max(32.0, (G.S / 13 / 8).round() * 8.0);
    var seed = 7;
    double rd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    return _pic = flattenPicture(prerender(G.pen, (g) {
      for (var y = 0.0; y < G.H; y += size) {
        for (var x = 0.0; x < G.W; x += size) {
          final fr = rd() < .8 ? base[0] : base[1 + (rd() * (base.length - 1)).floor()];
          g.tile(T, fr, x, y, size, size);
        }
      }
      if (top != null) {
        for (var x = 0.0; x < G.W; x += size) {
          g.tile(T, top[(rd() * top.length).floor()], x, 56, size, size);
        }
      }
      final items = <(String, double, double, double)>[];
      for (final (fr, n, k) in deco) {
        for (var i = 0; i < n; i++) {
          items.add((fr, rd() * G.W, 110 + rd() * (G.H - 130), k));
        }
      }
      items.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (fr, x, y, k) in items) {
        final s = size * k;
        g.tile(T, fr, x - s / 2, y - s, s, s);
      }
    }), G.W, G.H);
  }

  void dispose() => _pic?.dispose();
}

class Deco {
  Deco(this.img, this.x, this.y, this.s);
  final String img;
  final double x, y, s;
}

List<Deco> sceneDeco(Arena G, List<String> imgs, int n) =>
    List.generate(n, (_) => Deco(pick(imgs), rand(0, G.W), rand(90, G.H), rand(.8, 1.3)))..sort((a, b) => a.y.compareTo(b.y));

/// Quái đuổi theo bé.
void chase(Foe f, Arena G, double dt) {
  final h = G.hero, a = math.atan2(h.y - f.y, h.x - f.x);
  f.x += math.cos(a) * f.spd * dt;
  f.y += math.sin(a) * f.spd * dt;
  f.flip = h.x > f.x;
}

/// Lao tới: đứng nhắm rồi lao thẳng.
void charger(Foe f, Arena G, double dt) {
  f.pt += dt;
  f.wind = f.ph == 'aim' ? f.pt / .5 : 0;
  if (f.ph == 'walk') {
    chase(f, G, dt * .6);
    if (f.pt > 2.2) {
      f.ph = 'aim';
      f.pt = 0;
    }
  } else if (f.ph == 'aim') {
    if (f.pt > .5) {
      f.ph = 'dash';
      f.pt = 0;
      final a = math.atan2(G.hero.y - f.y, G.hero.x - f.x);
      f.ddx = math.cos(a);
      f.ddy = math.sin(a);
    }
  } else {
    f.x += f.ddx * f.spd * 3 * dt;
    f.y += f.ddy * f.spd * 3 * dt;
    f.x = clamp(f.x, 20, G.W - 20);
    f.y = clamp(f.y, 80, G.H - 20);
    if (f.pt > .6) {
      f.ph = 'walk';
      f.pt = 0;
    }
  }
}

Foe _foe(String img, ({double hp, double dmg}) s,
        {double size = 0,
        double spd = 0,
        String? sheet,
        String? anim,
        bool fly = false,
        bool? flip,
        bool boss = false,
        String? name,
        double gold = 1,
        bool noTouch = false,
        bool crown = false,
        bool shield = false,
        double x = 0,
        double y = 0,
        FoeAi? ai,
        ShootSpec? shoot,
        void Function(Pen p, Foe f, Arena G)? drawFn}) =>
    Foe(
        img: img,
        hp: s.hp,
        dmg: s.dmg,
        size: size,
        spd: spd,
        sheet: sheet,
        anim: anim,
        fly: fly,
        flip: flip,
        boss: boss,
        name: name,
        gold: gold,
        noTouch: noTouch,
        crown: crown,
        shield: shield,
        x: x,
        y: y,
        ai: ai,
        shoot: shoot,
        drawFn: drawFn);

// ---------- 1. Rừng Xanh: chém yêu tinh, heo rừng, nhện; trùm Quỷ Đá ----------
class _Forest extends ArenaCfg {
  _Forest(super.Z);
  final Spawner sp = Spawner();
  final TileBg tb = TileBg();
  List<Deco>? deco;
  @override
  String get name => 'Rừng Xanh';
  @override
  String get goalText => Z.boss ? 'Đánh bại Quỷ Đá' : 'Đánh bại ${_need(Z)} con quái';
  @override
  String get hint => 'Kéo bên trái để đi · bấm ⚔️ để chém · ✨ chiêu xoáy';
  @override
  void bg(Pen p, Arena G) {
    final bgc = tb.get(G, 'kenney-tiny-town/town', ['t0', 't1', 't2', 't1'],
        [('t16', 5, 1.6), ('t28', 4, 1.4), ('t5', 4, 1.1), ('t15', 2, 1.6), ('t27', 2, 1.4), ('t29', 4, .8), ('t17', 4, .8)]);
    if (bgc != null) {
      p.c.drawPicture(bgc);
      return;
    }
    p.vgrad(G.W, G.H, [hx(0xb2f2bb), hx(0x69db7c)]);
    for (var i = 0; i < 18; i++) {
      p.oval((i * 137) % G.W, 90 + (i * 89) % (G.H - 90), 40, 14, const Color(0x2EFFFFFF));
    }
    for (final d in deco ??= sceneDeco(G, ['Deciduous tree', 'Evergreen tree', 'Mushroom', 'Herb', 'Sunflower', 'Rock'], 12)) {
      p.draw(d.img, d.x, d.y, G.S * .09 * d.s);
    }
  }

  @override
  void start(Arena G) {
    if (!Z.boss) return;
    G.add(_foe('Troll', foeStats(0, 5, 10), name: 'Quỷ Đá', boss: true, x: G.W * .8, y: G.H * .45, size: G.S * .3, spd: G.S * .1, ai: (f, G, dt) {
      chase(f, G, dt);
      if (f.cd <= 0) {
        f.cd = 2.6;
        G.tele(Tele(G.hero.x, G.hero.y, r: G.S * .14, dmg: f.dmg * 1.4));
        if (f.hp < f.max * .6 && G.foes.length < 4) {
          G.add(_foe('Spider', foeStats(0, 2), sheet: 'kenney-platformer/enemies', anim: 'slime_spike', x: f.x, y: f.y, size: G.S * .08, spd: G.S * .25, gold: .5, ai: chase));
        }
      }
    }));
  }

  @override
  void tick(Arena G, double dt) {
    if (Z.boss) return;
    sp.run(G, dt, _need(Z), 2 + Z.s ~/ 2, 1.4, () {
      final k = pick(Z.s >= 2 ? ['Goblin', 'Spider', 'Boar'] : ['Goblin', 'Spider']);
      final s = foeStats(0, Z.s, k == 'Spider' ? .6 : (k == 'Boar' ? 1.3 : 1));
      // Nhện thường đổi thành chú nhớt xanh (sprite Kenney có khung đi), yêu tinh + heo rừng giữ hình
      final spider = k == 'Spider';
      G.edge(_foe(k, s,
          sheet: spider ? 'kenney-platformer/enemies' : null,
          anim: spider ? 'slime_normal' : null,
          size: G.S * (spider ? .09 : .11),
          spd: G.S * (spider ? .26 : .16),
          ai: k == 'Boar' ? charger : chase));
    });
  }

  @override
  bool done(Arena G) => Z.boss ? G.foes.every((f) => !f.boss) : G.kills >= _need(Z);
  @override
  String? goal(Arena G) => _killsGoal(G);
}

final ZoneDef forest = ZoneDef(
  ['Goblin', 'Boar', 'Spider', 'Troll', 'Deciduous tree', 'Evergreen tree', 'Mushroom', 'Herb', 'Sunflower', 'Rock'],
  (Z, art, W, H, audio) => Arena(Z, art, W, H, audio, _Forest(Z)),
);

// ---------- 2. Biển Ngọc: lái thuyền, đại bác tự bắn; trùm Mực Khổng Lồ ----------
class _Sea extends ArenaCfg {
  _Sea(super.Z);
  final Spawner sp = Spawner();
  ui.Picture? water;
  @override
  String get name => 'Biển Ngọc';
  @override
  String get goalText => Z.boss ? 'Đánh chìm Mực Khổng Lồ' : 'Bắn chìm ${_need(Z)} kẻ địch';
  @override
  String get hint => 'Kéo bên trái để lái thuyền · đại bác tự bắn · né đạn nhé';
  @override
  bool get melee => false;
  @override
  String get mount => 'Sailboat';
  @override
  (String, String) get mountSpr => ('kenney-pirate/ships', 'ship5');
  @override
  AutoFire get autoFire => const AutoFire(rate: .55, img: 'Bomb', speed: 1.2, mul: .9, size: .045);
  @override
  Rect bounds(Arena G) => Rect.fromLTRB(40, G.H * .35, G.W - 40, G.H - 50);

  @override
  void start(Arena G) {
    G.hero.y = G.H * .78;
    if (!Z.boss) return;
    G.add(_foe('Squid', foeStats(1, 5, 10),
        name: 'Mực Khổng Lồ',
        boss: true,
        x: G.W / 2,
        y: G.H * .22,
        size: G.S * .3,
        noTouch: true,
        shoot: const ShootSpec(rate: 1.6, img: 'Droplet', speed: .45), ai: (f, G, dt) {
      f.x = G.W / 2 + math.sin(f.t * .7) * G.W * .3;
      if (f.t % 4 < dt) {
        final w = G.W / 5, c = (G.hero.x / w).floor();
        G.tele(Tele((c + .5) * w, G.H * .66, w: w, h: G.H * .68, dmg: f.dmg * 1.3, t: 1.4));
      }
    }));
  }

  @override
  void bg(Pen p, Arena G) {
    p.vgrad(G.W, G.H, [hx(0x1971c2), hx(0x4dabf7)]);
    final wt = G.sp('kenney-pirate/tiles');
    if (wt?.image != null) {
      water ??= prerender(p, (g) {
        for (var y = -96.0; y < G.H + 96; y += 96) {
          for (var x = 0.0; x < G.W; x += 96) {
            g.tile(wt!, 'tile_73', x, y, 96, 96, .55);
          }
        }
      });
      p.c.save();
      p.c.translate(0, (G.t * 30) % 96);
      p.c.drawPicture(water!);
      p.c.restore();
    }
    final st = p.stroke(const Color(0x4DFFFFFF), 3);
    for (var i = 0; i < 14; i++) {
      final y = ((i * 70 + G.t * 60) % (G.H + 70)) - 35, x = (i * 173) % G.W;
      p.c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 18), pi * 1.1, pi * .8, false, st);
    }
    for (var i = 0; i < 3; i++) {
      p.draw(i % 2 == 1 ? 'Desert island' : 'Spiral shell', (i * 311) % G.W, ((i * 260 + G.t * 40) % (G.H + 200)) - 100, G.S * (i % 2 == 1 ? .14 : .06));
    }
  }

  static void _shipDraw(Pen p, Foe f, Arena G) {
    final a = pi + math.sin(f.t * 1.5) * .12;
    if (!p.spr(G.sp('kenney-pirate/ships'), 'ship14', f.x, f.y, f.size * 1.5, rot: a, alpha: f.hurt > 0 ? .6 : 1)) p.draw('Ship', f.x, f.y, f.size);
    if (f.hp < f.max) {
      p.rect(f.x - f.size * .35, f.y - f.size * .8, f.size * .7, 7, const Color(0x66000000));
      p.rect(f.x - f.size * .35, f.y - f.size * .8, f.size * .7 * f.hp / f.max, 7, hx(0xff6b6b));
    }
    if (f.atkT > .2) p.sprA(G.sp('kenney-pirate/ships'), 'explode', .35 - f.atkT, f.x, f.y + f.size * .6, f.size * .5);
  }

  @override
  void tick(Arena G, double dt) {
    if (Z.boss) {
      if (G.foes.length < 3 && G.t % 5 < dt) {
        G.edge(
            _foe('Shark', foeStats(1, 2), size: G.S * .1, spd: G.S * .2, gold: .5, ai: (f, G, dt) {
              f.y += f.spd * dt;
              f.x += math.sin(f.t * 3) * 60 * dt;
            }),
            side: 0);
      }
      return;
    }
    sp.run(G, dt, _need(Z), 3 + Z.s ~/ 2, 1.2, () {
      final k = pick(Z.s >= 1 ? ['Shark', 'Octopus', 'Ship'] : ['Shark', 'Octopus']);
      final s = foeStats(1, Z.s, k == 'Ship' ? 1.6 : 1);
      if (k == 'Shark') {
        G.edge(
            _foe(k, s, size: G.S * .11, spd: G.S * .18, flip: false, fly: true, ai: (f, G, dt) {
              f.y += f.spd * dt;
              f.x += math.sin(f.t * 2.5) * G.S * .2 * dt;
              if (f.y > G.H + 30) f.y = -30;
            }),
            side: 0);
      } else {
        G.edge(
            _foe(k, s,
                size: G.S * (k == 'Ship' ? .14 : .1),
                spd: G.S * .07,
                noTouch: k == 'Ship',
                fly: true,
                // Tàu cướp biển: sprite Kenney nhìn từ trên, mũi hướng xuống, lắc theo sóng
                drawFn: k == 'Ship' ? _shipDraw : null,
                shoot: ShootSpec(rate: k == 'Ship' ? 2.2 : 2.8, img: k == 'Ship' ? 'Bomb' : 'Droplet', speed: .42), ai: (f, G, dt) {
              if (f.y < G.H * .3) f.y += f.spd * dt * 2;
              f.x += math.sin(f.t + f.max) * G.S * .15 * dt;
              f.flip = false;
            }),
            side: 0);
      }
    });
  }

  @override
  bool done(Arena G) => Z.boss ? G.foes.every((f) => !f.boss) : G.kills >= _need(Z);
  @override
  String? goal(Arena G) => _killsGoal(G);
}

final ZoneDef sea = ZoneDef(
  ['Sailboat', 'Shark', 'Octopus', 'Ship', 'Pirate flag', 'Squid', 'Bomb', 'Droplet', 'Desert island', 'Spiral shell', 'Water wave'],
  (Z, art, W, H, audio) => Arena(Z, art, W, H, audio, _Sea(Z)),
);

// ---------- 6. Thành Mây: cưỡi đại bàng bay, tự bắn sao chổi; trùm Mây Sấm ----------
class _Sky extends ArenaCfg {
  _Sky(super.Z);
  final Spawner sp = Spawner();
  @override
  String get name => 'Thành Mây';
  @override
  String get goalText => Z.boss ? 'Đánh tan Mây Sấm' : 'Hạ ${_need(Z)} kẻ địch trên trời';
  @override
  String get hint => 'Kéo bên trái để bay · đại bàng tự bắn về phía trước';
  @override
  bool get melee => false;
  @override
  String get mount => 'Eagle';
  @override
  AutoFire get autoFire => const AutoFire(rate: .32, img: 'Comet', dir: 'right', speed: 1.6, mul: .6, size: .055);
  @override
  Rect bounds(Arena G) => Rect.fromLTRB(50, 90, G.W * .55, G.H - 60);

  @override
  void start(Arena G) {
    G.hero
      ..x = G.W * .2
      ..y = G.H * .5;
    if (!Z.boss) return;
    G.add(_foe('Cloud with lightning', foeStats(5, 5, 10),
        name: 'Mây Sấm',
        boss: true,
        fly: true,
        x: G.W * .82,
        y: G.H * .5,
        size: G.S * .32,
        noTouch: true,
        flip: false,
        shoot: const ShootSpec(rate: 1.4, img: 'High voltage', speed: .5), ai: (f, G, dt) {
      f.y = G.H * .5 + math.sin(f.t * .8) * G.H * .28;
      if (f.t % 3.5 < dt) {
        final w = G.W * .12;
        G.tele(Tele(math.min(G.W * .5, math.max(w, G.hero.x)), G.H / 2 + 35, w: w, h: G.H - 70, dmg: f.dmg * 1.3, t: 1.3));
      }
    }));
  }

  @override
  void bg(Pen p, Arena G) {
    p.vgrad(G.W, G.H, [hx(0x91a7ff), hx(0xe5dbff)]);
    p.draw('Rainbow', G.W * .7, G.H * .3, G.S * .5, alpha: .4);
    for (var i = 0; i < 8; i++) {
      final x = G.W - ((i * 190 + G.t * (40 + i * 12)) % (G.W + 240)) + 120;
      p.draw('Cloud', x, 100 + (i * 97) % (G.H - 120), G.S * (.12 + (i % 3) * .05), h: G.S * (.08 + (i % 3) * .03), alpha: .85);
    }
    p.draw('Classical building', G.W - ((G.t * 25) % (G.W + 300)) + 150, G.H - G.S * .08, G.S * .18);
  }

  @override
  void tick(Arena G, double dt) {
    if (Z.boss) {
      if (G.foes.length < 4 && G.t % 3 < dt) {
        G.edge(
            _foe('Bat', foeStats(5, 2), sheet: 'kenney-platformer/enemies', anim: 'bee', fly: true, size: G.S * .08, spd: G.S * .25, gold: .5, flip: false, ai: (f, G, dt) {
              f.x -= f.spd * dt;
              f.y += math.sin(f.t * 4) * 120 * dt;
            }),
            side: 1);
      }
      return;
    }
    sp.run(G, dt, _need(Z), 3 + Z.s ~/ 2, 1.1, () {
      final k = pick(Z.s >= 2 ? ['Bat', 'Owl', 'Cloud with lightning', 'Tornado'] : ['Bat', 'Owl', 'Cloud with lightning']);
      final s = foeStats(5, Z.s, k == 'Tornado' ? 1.8 : (k == 'Bat' ? .7 : 1));
      G.edge(
          _foe(k, s,
              sheet: k == 'Bat' ? 'kenney-platformer/enemies' : null,
              anim: k == 'Bat' ? 'fly' : null,
              fly: true,
              size: G.S * (k == 'Tornado' ? .13 : .1),
              spd: G.S * (k == 'Tornado' ? .14 : .2),
              flip: false,
              shoot: k == 'Cloud with lightning' ? const ShootSpec(rate: 2.2, img: 'High voltage', speed: .45) : null, ai: (f, G, dt) {
            if (!(k == 'Cloud with lightning' && f.x < G.W * .78)) f.x -= f.spd * dt;
            f.y += math.sin(f.t * (k == 'Bat' ? 4 : 1.5)) * 90 * dt;
            if (f.x < -40) f.x = G.W + 40;
          }),
          side: 1);
    });
  }

  @override
  bool done(Arena G) => Z.boss ? G.foes.every((f) => !f.boss) : G.kills >= _need(Z);
  @override
  String? goal(Arena G) => _killsGoal(G);
}

final ZoneDef sky = ZoneDef(
  ['Eagle', 'Comet', 'Bat', 'Cloud with lightning', 'Tornado', 'High voltage', 'Cloud', 'Rainbow', 'Classical building', 'Owl'],
  (Z, art, W, H, audio) => Arena(Z, art, W, H, audio, _Sky(Z)),
);

// ---------- 9. Đầm Lầy Ma: trời tối, đèn quanh bé; nhặt đốm sáng, 💡 chớp sáng làm ma choáng; trùm Vua Ma ----------
int _orbsN(ZoneCtx Z) => Z.boss ? 0 : 5 + Z.s;

class _Orb extends XY {
  _Orb(super.x, super.y, this.ph);
  double ph;
  bool got = false;
}

class _Swamp extends ArenaCfg {
  _Swamp(super.Z);
  List<_Orb> orbs = [];
  List<(double, double, double)> pools = [];
  List<Deco>? deco;
  int got = 0;
  double flashV = 0, spT = 1;
  @override
  String get name => 'Đầm Lầy Ma';
  @override
  String get goalText => Z.boss ? 'Chớp sáng ✨ cho Vua Ma choáng rồi chém' : 'Nhặt ${_orbsN(Z)} đốm sáng';
  @override
  String get hint => 'Trời tối! Bấm ✨ để chớp sáng, ma sẽ bị choáng';
  @override
  double get skillCd => 4;
  @override
  String get skillLabel => '💡';
  @override
  bool get customSkill => true;
  @override
  double dark(Arena G) => G.S * (.26 + flashV * .9);
  @override
  void skill(Arena G) {
    flashV = 1;
    G.F.burst(G.hero.x, G.hero.y, 30, [hx(0xfff9db), hx(0xffe066), Colors.white]);
    for (final f in List.of(G.foes)) {
      if (dist(f, G.hero) < G.S * .5) {
        f.stun = 2.5;
        if (f.boss) f.shield = false;
        final s = strike(G.Z.st, 1.2);
        G.hit(f, s.d, s.crit);
      }
    }
  }

  @override
  void start(Arena G) {
    orbs = List.generate(_orbsN(Z), (_) => _Orb(rand(60, G.W - 60), rand(110, G.H - 60), rand(0, 6)));
    pools = List.generate(4, (_) => (rand(0, G.W), rand(100, G.H), rand(40, 80)));
    if (!Z.boss) return;
    G.add(_foe('Ghost', foeStats(8, 5, 9),
        name: 'Vua Ma', boss: true, crown: true, shield: true, fly: true, x: G.W * .75, y: G.H * .4, size: G.S * .26, spd: G.S * .09, ai: (f, G, dt) {
      f.stun = math.max(0, f.stun - dt);
      if (f.stun <= 0) f.shield = true;
      if (f.stun <= 0) {
        final h = G.hero, a = math.atan2(h.y - f.y, h.x - f.x);
        f.x += math.cos(a) * f.spd * dt;
        f.y += math.sin(a) * f.spd * dt;
      }
      if (f.cd <= 0 && f.stun <= 0) {
        f.cd = 3.2;
        G.F.burst(f.x, f.y, 16, [hx(0xe5dbff), hx(0xb197fc)]);
        f.x = rand(80, G.W - 80);
        f.y = rand(120, G.H - 80);
        if (G.foes.length < 4) G.add(_foe('Bat', foeStats(8, 1, .5), x: f.x, y: f.y, size: G.S * .07, spd: G.S * .2, gold: .5));
      }
    }));
  }

  @override
  void bg(Pen p, Arena G) {
    p.rect(0, 0, G.W, G.H, hx(0x2b8a3e));
    for (var i = 0; i < 30; i++) {
      p.circle((i * 151) % G.W, 80 + (i * 113) % G.H, 22, hx(0x1b5e20));
    }
    for (final (x, y, r) in pools) {
      p.oval(x, y, r, r * .5, hx(0x495057));
    }
    for (final d in deco ??= sceneDeco(G, ['Mushroom', 'Fallen leaf', 'Frog'], 9)) {
      if (d.img == 'Frog' && p.sprA(G.sp('kenney-platformer/enemies'), 'frog', G.t + d.x, d.x, d.y + G.S * .03, G.S * .07 * d.s)) continue;
      p.draw(d.img, d.x, d.y, G.S * .06 * d.s);
    }
  }

  @override
  void tick(Arena G, double dt) {
    flashV = math.max(0, flashV - dt * 1.2);
    for (final o in orbs) {
      o.ph += dt;
      if (!o.got && dist(o, G.hero) < 40) {
        o.got = true;
        got++;
        G.sfx('star');
        G.F.star(o.x, o.y);
        G.xp += 4;
      }
    }
    G.lights = [for (final o in orbs) if (!o.got) Light(o.x, o.y, 34 + math.sin(o.ph * 3) * 6)];
    if (Z.boss) return;
    final live = 2 + Z.s ~/ 2;
    if (G.foes.length < live && (spT -= dt) <= 0) {
      spT = 2.4;
      final k = pick(Z.s >= 2 ? ['Ghost', 'Ghost', 'Woman zombie', 'Bat'] : ['Ghost', 'Bat']);
      G.edge(_foe(k, foeStats(8, Z.s, k == 'Woman zombie' ? 1.4 : .9),
          fly: k != 'Woman zombie', size: G.S * (k == 'Bat' ? .07 : .1), spd: G.S * (k == 'Woman zombie' ? .07 : (k == 'Bat' ? .2 : .12)), ai: (f, G, dt) {
        f.stun = math.max(0, f.stun - dt);
        if (f.stun > 0) return;
        final h = G.hero, near = dist(f, h) < G.S * .38;
        if (near) {
          final a = math.atan2(h.y - f.y, h.x - f.x);
          f.x += math.cos(a) * f.spd * dt;
          f.y += math.sin(a) * f.spd * dt;
        } else {
          f.wa = (f.wa ?? rand(0, 6)) + rand(-1, 1) * dt;
          f.x += math.cos(f.wa!) * f.spd * .5 * dt;
          f.y += math.sin(f.wa!) * f.spd * .5 * dt;
          if (f.x < 30 || f.x > G.W - 30 || f.y < 90 || f.y > G.H - 30) f.wa = f.wa! + pi;
        }
      }));
    }
  }

  @override
  void afterDark(Pen p, Arena G) {
    for (final o in orbs) {
      if (!o.got) p.draw('Sparkles', o.x, o.y, 30 + math.sin(o.ph * 3) * 4);
    }
    for (final f in G.foes) {
      if (f.stun > 0) p.text('💫', f.x, f.y - f.size * .5, size: 22, color: hx(0xffe066));
    }
    final b = G.foes.where((f) => f.boss).firstOrNull;
    if (b != null) {
      p.draw('Ghost', b.x, b.y, b.size, alpha: .55);
      p.draw('Crown', b.x, b.y - b.size * .55, b.size * .35, alpha: .55);
      if (b.shield) p.ring(b.x, b.y, b.size * .6, hx(0xb197fc, .8), 5);
    }
  }

  @override
  bool done(Arena G) => Z.boss ? G.foes.every((f) => !f.boss) : got >= _orbsN(Z);
  @override
  String? goal(Arena G) => Z.boss ? null : '✨ $got/${_orbsN(Z)}';
}

final ZoneDef swamp = ZoneDef(
  ['Ghost', 'Woman zombie', 'Bat', 'Sparkles', 'Frog', 'Crocodile', 'Fallen leaf', 'Mushroom'],
  (Z, art, W, H, audio) => Arena(Z, art, W, H, audio, _Swamp(Z)),
);

// ---------- 10. Lâu Đài Rồng: cùng 3 bạn phiêu lưu đánh lính lâu đài; trùm Rồng Lửa ----------
/// Ba bạn phiêu lưu: pháp sư (áo tím, đũa phép), cung thủ (áo xanh lá, cung), ninja (dao). Cũng là bạn trong làng.
class Ally {
  const Ally(this.c, this.wp, this.name, {this.shot, this.ranged = false});
  final Costume c;
  final String wp, name;
  final String? shot;
  final bool ranged;
}

final List<Ally> kAllies = [
  Ally(Costume(base: 'girl', shirt: hx(0x7048e8), pants: hx(0x5f3dc4), hair: hx(0xced4da)), 'Magic wand', 'Bé Mây', shot: 'Sparkles', ranged: true),
  Ally(Costume(base: 'girl', shirt: hx(0x40c057), pants: hx(0x2b8a3e), hair: hx(0xfab005)), 'Bow and arrow', 'Bé Lá', shot: 'Bow and arrow', ranged: true),
  Ally(kCostumes['Ninja'] ?? costumeOf('Ninja'), 'Dagger', 'Bé Gió'),
];

class _AllyState extends XY {
  _AllyState(this.a, super.x, super.y, this.ox, this.oy) : cd = rand(.3, 1);
  final Ally a;
  final double ox, oy;
  double cd, sw = 0;
  bool mv = false;
  int face = 1;
}

class _Castle extends ArenaCfg {
  _Castle(super.Z);
  final Spawner sp = Spawner();
  final TileBg tb = TileBg();
  List<_AllyState> allies = [];
  @override
  String get name => 'Lâu Đài Rồng';
  @override
  String get goalText => Z.boss ? 'Cả đội đánh bại Rồng Lửa' : 'Đánh bại ${_need(Z) + 2} lính lâu đài';
  @override
  String get hint => 'Đi cùng 3 bạn phiêu lưu · né vòng đỏ · ⚔️ chém, ✨ chiêu xoáy';

  @override
  void start(Arena G) {
    const ox = [-70.0, 70.0, 0.0], oy = [40.0, 40.0, -70.0];
    allies = [for (var i = 0; i < kAllies.length; i++) _AllyState(kAllies[i], G.hero.x - 60 + i * 50, G.hero.y + 60, ox[i], oy[i])];
    if (!Z.boss) return;
    G.add(_foe('Dragon', foeStats(9, 5, 14), name: 'Rồng Lửa', boss: true, x: G.W * .78, y: G.H * .45, size: G.S * .36, spd: G.S * .06, ai: (f, G, dt) {
      final h = G.hero, rage = f.hp < f.max * .5;
      f.x += (G.W * .72 - f.x).sign * f.spd * dt;
      f.y += (h.y - f.y) * .4 * dt;
      f.flip = h.x > f.x;
      if (f.cd <= 0) {
        f.cd = rage ? 2 : 2.8;
        final m = rnd.nextInt(3);
        if (m == 0) {
          for (var i = 0; i < (rage ? 5 : 3); i++) {
            G.tele(Tele(rand(80, G.W - 80), rand(120, G.H - 60), r: G.S * .1, dmg: f.dmg, t: 1.3 + i * .15));
          }
          G.tele(Tele(h.x, h.y, r: G.S * .11, dmg: f.dmg, t: 1.3));
        } else if (m == 1) {
          G.tele(Tele((f.x - G.S * .2) / 2, h.y, w: f.x - G.S * .2, h: G.S * .16, dmg: f.dmg * 1.3, t: 1.4));
        } else {
          for (var k = -2; k <= 2; k++) {
            final a = math.atan2(h.y - f.y, h.x - f.x) + k * .25;
            G.eshots.add(Shot(f.x, f.y, math.cos(a) * G.S * .45, math.sin(a) * G.S * .45, d: f.dmg.round(), img: 'Fire', size: G.S * .07, life: 4));
          }
          G.sfx('boom');
        }
        if (rage && G.foes.length < 4) G.add(_foe('Bat', foeStats(9, 1, .5), x: f.x, y: f.y, size: G.S * .07, spd: G.S * .2, gold: .5));
      }
    }));
  }

  @override
  void bg(Pen p, Arena G) {
    final bgc = tb.get(G, 'kenney-tiny-dungeon/dungeon', ['t48', 't49', 't50'], [('t64', 2, 1), ('t65', 2, 1), ('t82', 3, 1), ('t63', 2, 1)],
        top: ['t40', 't40', 't57', 't58']);
    if (bgc != null) {
      p.c.drawPicture(bgc);
      p.rect(G.W * .42, 100, G.W * .16, G.H, hx(0xc92a2a, .75));
      p.rect(G.W * .42, 100, 4, G.H, hx(0xffd43b));
      p.rect(G.W * .58 - 4, 100, 4, G.H, hx(0xffd43b));
      final T = G.sp('kenney-tiny-dungeon/dungeon');
      for (final x in [G.W * .12, G.W * .3, G.W * .7, G.W * .88]) {
        p.spr(T, 't29', x, 80 + math.sin(G.t * 9 + x) * 1.5, 40, pixel: true);
      }
      p.draw('Castle', G.W * .5, 92, G.S * .12);
      return;
    }
    p.rect(0, 0, G.W, G.H, hx(0x495057));
    const t = 64.0;
    for (var y = 70.0; y < G.H; y += t) {
      for (var x = ((y / t).floor() % 2) * t / 2 - t; x < G.W; x += t) {
        p.rect(x + 2, y + 2, t - 4, t - 4, (x / t + y / t) % 2 < 1 ? hx(0x5c636a) : hx(0x545b62));
      }
    }
    p.rect(G.W * .4, 70, G.W * .2, G.H, hx(0xc92a2a));
    p.draw('Castle', G.W * .5, 110, G.S * .16);
    for (final x in [G.W * .1, G.W * .9]) {
      p.draw('Fire', x, 110 + math.sin(G.t * 6) * 3, G.S * .06);
    }
  }

  @override
  void tick(Arena G, double dt) {
    // Bạn phiêu lưu (máy điều khiển): đi theo bé, tự đánh quái gần nhất
    for (final a in allies) {
      final h = G.hero, tx = h.x + a.ox, ty = h.y + a.oy;
      Foe? tg;
      var bd = G.S * (a.a.ranged ? .7 : .45);
      for (final f in G.foes) {
        final d = dist(f, a);
        if (!f.dead && d < bd) {
          bd = d;
          tg = f;
        }
      }
      final gx = !a.a.ranged && tg != null ? tg.x : tx, gy = !a.a.ranged && tg != null ? tg.y : ty;
      final ax = a.x, ay = a.y;
      a.x += (gx - a.x) * math.min(1, dt * 2.5);
      a.y += (gy - a.y) * math.min(1, dt * 2.5);
      a.cd -= dt;
      a.mv = hypot(a.x - ax, a.y - ay) > dt * 25;
      if ((a.x - ax).abs() > dt * 8) a.face = a.x > ax ? 1 : -1;
      if (tg != null) a.face = tg.x > a.x ? 1 : -1;
      a.sw = math.max(0, a.sw - dt);
      if (tg != null && a.cd <= 0) {
        a.cd = a.a.ranged ? 1.1 : .8;
        a.sw = .25;
        final d = (G.Z.st.atk * .35).round();
        if (a.a.ranged) {
          final an = math.atan2(tg.y - a.y, tg.x - a.x);
          G.shots.add(Shot(a.x, a.y, math.cos(an) * G.S * 1.2, math.sin(an) * G.S * 1.2,
              d: d, img: a.a.shot!, size: G.S * .05, life: 1.5, rot: a.a.shot == 'Bow and arrow' ? an : null));
        } else if (dist(a, tg) < tg.size * .6 + 30) {
          G.hit(tg, d);
        }
      }
    }
    if (Z.boss) return;
    sp.run(G, dt, _need(Z) + 2, 3 + Z.s ~/ 2, 1.1, () {
      final k = pick(Z.s >= 2 ? ['Skull', 'Man vampire', 'Ogre', 'Bat'] : ['Skull', 'Bat', 'Man vampire']);
      final s = foeStats(9, Z.s, k == 'Ogre' ? 1.8 : (k == 'Bat' ? .6 : 1));
      G.edge(_foe(k, s,
          size: G.S * (k == 'Ogre' ? .14 : (k == 'Bat' ? .08 : .11)),
          spd: G.S * (k == 'Bat' ? .24 : (k == 'Ogre' ? .1 : .15)),
          ai: k == 'Ogre' ? charger : chase,
          shoot: k == 'Man vampire' ? const ShootSpec(rate: 2.6, img: 'Bat', speed: .4, size: .05) : null));
    });
  }

  @override
  void after(Pen p, Arena G) {
    for (final a in allies) {
      drawFigure(p.c, a.x, a.y + G.S * .05, G.S * .12, a.a.c,
          pose: a.sw > 0 ? (a.a.ranged ? 'throw' : 'swing') : (a.mv ? 'run' : 'idle'), act: 1 - a.sw / .25, t: G.t + a.ox, face: a.face, weaponImage: p.art.imgs[a.a.wp]);
      final tw = p.measure(a.a.name, 13) + 12;
      p.rrect(a.x - tw / 2, a.y - G.S * .08 - 16, tw, 18, 9, const Color(0x73000000));
      p.text(a.a.name, a.x, a.y - G.S * .08 - 3, size: 13, color: hx(0xb2f2bb));
    }
  }

  @override
  bool done(Arena G) => Z.boss ? G.foes.every((f) => !f.boss) : G.kills >= _need(Z) + 2;
  @override
  String? goal(Arena G) => Z.boss ? null : '⚔️ ${math.min(G.kills, _need(Z) + 2)}/${_need(Z) + 2}';
}

final ZoneDef castle = ZoneDef(
  ['Skull', 'Man vampire', 'Ogre', 'Bat', 'Dragon', 'Fire', 'Castle', 'Crossed swords', for (final a in kAllies) ...[a.wp, a.shot ?? 'Dagger']],
  (Z, art, W, H, audio) => Arena(Z, art, W, H, audio, _Castle(Z)),
);
