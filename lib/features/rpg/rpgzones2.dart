// ignore_for_file: non_constant_identifier_names
// Thế giới phiêu lưu: 5 vùng có cách chơi riêng.
// Vùng 3 Hang Mỏ (mê cung), 4 Xứ Tuyết (đánh theo lượt), 5 Sa Mạc (đào kho báu), 7 Rừng Kẹo (giữ bánh), 8 Núi Lửa (nhảy qua dung nham).
// CHỦ: agent H. Port của reference/web/js/games/rpgzones2.js.
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';

import 'rpgcore.dart';

/// Phần riêng của một vùng trong khung chung (init(G) của web trả {update, draw, done, goal, lose}).
abstract class ShellGame {
  void update(double dt);
  void draw(Pen p);
  bool done();
  String? goal();
  bool get lose => false;
}

class ShellCfg {
  const ShellCfg({required this.name, required this.goalText, this.hint, this.pot, this.noPotion = false, this.hp});
  final String name, goalText;
  final String? hint;

  /// Vị trí nút bình máu riêng (W, H, S) → (x, y).
  final (double, double) Function(double W, double H, double S)? pot;
  final bool noPotion;
  final double? hp;
}

/// Khung chung: máu, bình máu, màn mở đầu, kết thúc, hoạt ảnh quái chết.
class Shell extends RpgStage {
  Shell(super.Z, super.art, super.W, super.H, super.audio, this.cfg, ShellGame Function(Shell G) init) {
    final pp = cfg.pot?.call(W, H, S);
    pot = Btn('pot', pp?.$1 ?? W - 44, pp?.$2 ?? 104, 30, '🧪', c: hx(0x69db7c));
    B = Buttons(M, cfg.noPotion ? [] : [pot]);
    final hp = cfg.hp ?? Z.st.maxhp.toDouble();
    hero = HeroState(x: W / 2, y: H / 2, hp: hp, max: hp);
    game = init(this);
  }
  final ShellCfg cfg;
  late final Btn pot;
  late final Buttons B;
  late final HeroState hero;
  late final ShellGame game;
  List<Mob> ghosts = [];
  double flash = 0;

  /// Quái vừa chết: bật lên, xoay, mờ dần.
  void die(Mob v) {
    v
      ..dieT = 0
      ..t = t;
    ghosts.add(v);
    FB.ring(v.x, v.y, v.size * .6, Colors.white, 6);
    C.shake(v.boss ? 14 : 3);
    if (v.boss) C.stop(.25);
  }

  int hurt(double d, [double? x, double? y, bool raw = false]) {
    if (end != null) return 0;
    final v = raw ? d.round() : taken(d, Z.st.def);
    hero.hp -= v;
    hero.inv = .5;
    sfx('hit');
    FB.num(x ?? hero.x, (y ?? hero.y) - 30, '-$v', c: hx(0xff6b6b));
    C.shake(6);
    flash = .35;
    return v;
  }

  void num(double x, double y, int d, [bool crit = false]) {
    FB.num(x, y, crit ? '$d!' : '$d', crit: crit);
    FB.sparks(x, y + 20, crit ? 9 : 5, crit ? hx(0xffe066) : Colors.white);
    C.shake(crit ? 4 : 2);
    C.stop(.04);
  }

  void loot(double g, double x, double y) {
    final v = (g * Z.st.goldMul).round();
    gold += v;
    sfx('coin');
    F.text(x, y - 20, '+$v', hx(0xffd43b));
  }

  void kill([bool boss = false]) {
    kills++;
    xp += ((3 + Z.r * 2) * (boss ? 10 : 1)).round();
  }

  @override
  RunResult? update(double rdt) {
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    flash = math.max(0, flash - rdt);
    t += dt;
    F.update(dt);
    FB.update(dt);
    hero.inv = math.max(0, hero.inv - dt);
    for (final g in ghosts) {
      g.dieT = g.dieT! + dt * 2;
    }
    ghosts.removeWhere((g) => g.dieT! >= 1);
    if (end != null) {
      endT += dt;
      return endT > 2 ? RunResult(win: end == 'win', gold: gold, xp: xp, kills: kills, potions: Z.potions) : null;
    }
    if (introT > 0) {
      introT -= dt;
      return null;
    }
    if (B.hit('pot')) potionUse(Z, hero, F, audio);
    if (Z.st.regen > 0 && !cfg.noPotion) hero.hp = math.min(hero.max, hero.hp + hero.max * Z.st.regen * dt);
    game.update(dt);
    if (hero.hp <= 0) {
      hero.hp = 0;
      end = 'lose';
      sfx('wrong');
    } else if (game.done()) {
      end = 'win';
      sfx('win');
      F.burst(W / 2, H / 2, 60);
    } else if (game.lose) {
      end = 'lose';
      sfx('wrong');
    }
    return null;
  }

  @override
  void render(Canvas c) {
    final p = pen..c = c;
    C.begin(c);
    game.draw(p);
    for (final g in ghosts) {
      drawMob(p, g, sheet: g.sheet != null ? sp(g.sheet!) : null, anim: g.anim, frame: g.frame);
    }
    FB.draw(p);
    C.end(c);
    F.draw(p);
    if (flash > 0) {
      final g = Paint()
        ..shader = ui.Gradient.radial(Offset(W / 2, H / 2), math.max(W, H) * .75, [const Color(0x00FF0000), const Color(0x00FF0000), Color.fromRGBO(255, 30, 30, math.min(1, flash * 1.2))],
            [0, S * .3 / (math.max(W, H) * .75), 1]);
      c.drawRect(Rect.fromLTWH(0, 0, W, H), g);
    }
    topHud(p, W, Z, hero.hp, hero.max, gold, game.goal());
    if (!cfg.noPotion) {
      B.draw(p);
      drawPotionCount(p, pot, Z.potions);
    }
    if (introT > 0) zoneIntro(p, W, H, Z, cfg.name, cfg.goalText, cfg.hint);
    if (end != null) endBanner(p, W, H, end == 'win', gold);
    fade(p, W, H, t, end != null ? endT : 0);
  }
}

// ---------- 3. Hang Mỏ: mê cung, đào đá tìm ngọc, tìm chìa khoá rồi tới cửa; trùm Nhện Chúa canh cửa ----------
class _Cell {
  _Cell(this.x, this.y)
      : px = x,
        py = y;
  int x, y, px, py;
  double mt = 1;
}

class _MineFoe extends _Cell {
  _MineFoe(super.x, super.y, this.img, ({double hp, double dmg}) s, {this.boss = false, this.cd = 1, this.sp = 0})
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg;
  final String img;
  final bool boss;
  double hp, max, dmg, cd, sp, hurt = 0;
  bool dead = false;
  final Mob v = Mob();
}

class _Mine extends ShellGame {
  _Mine(this.G) {
    final Z = G.Z, W = G.W, H = G.H, S = G.S;
    C = Z.s >= 3 ? 15 : 13;
    R = Z.s >= 3 ? 9 : 7;
    if (H > W) {
      // màn dọc: mê cung dựng đứng cho ô to hơn
      final c0 = C;
      C = R;
      R = c0;
    }
    br = math.min(40, S * .07);
    final padW = br * 6.2 + 20, padH = br * 6 + 20;
    land = W > H;
    final topB = !land && Z.boss ? 40.0 : 0.0; // màn dọc: chừa chỗ thanh máu trùm ở trên
    final aw = land ? W - padW - 24 : W - 24, ah = (land ? H - 96 : H - 96 - padH) - topB;
    cs = math.min(aw / C, ah / R).floorToDouble();
    ox = 12 + ((aw - C * cs) / 2).roundToDouble();
    oy = 80 + topB + ((ah - R * cs) / 2).roundToDouble();
    // Mê cung: 0 trống, 1 tường, 2 đá đào được
    g = List.generate(R, (_) => List.filled(C, 1));
    final stack = <(int, int)>[(1, 1)];
    g[1][1] = 0;
    while (stack.isNotEmpty) {
      final (x, y) = stack.last;
      final nb = [(2, 0), (-2, 0), (0, 2), (0, -2)]
          .map((d) => (x + d.$1, y + d.$2, d.$1, d.$2))
          .where((n) => n.$1 > 0 && n.$2 > 0 && n.$1 < C - 1 && n.$2 < R - 1 && g[n.$2][n.$1] == 1)
          .toList();
      if (nb.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (nx, ny, dx, dy) = pick(nb);
      g[y + dy ~/ 2][x + dx ~/ 2] = 0;
      g[ny][nx] = 0;
      stack.add((nx, ny));
    }
    for (var y = 1; y < R - 1; y++) {
      for (var x = 1; x < C - 1; x++) {
        if (g[y][x] == 1 && rnd.nextDouble() < .3) {
          g[y][x] = 2;
          if (rnd.nextDouble() < .45) gems.add('$x,$y');
        }
      }
    }
    d0 = _bfs(1, 1);
    var far = (1, 1);
    for (var y = 0; y < R; y++) {
      for (var x = 0; x < C; x++) {
        if (d0[y][x] > d0[far.$2][far.$1]) far = (x, y);
      }
    }
    key = Z.boss ? null : far;
    final dk = _bfs(far.$1, far.$2);
    var best = -1.0;
    door = (1, 1);
    for (var y = 0; y < R; y++) {
      for (var x = 0; x < C; x++) {
        final v = math.min(dk[y][x].toDouble(), d0[y][x] * 1.2);
        if (dk[y][x] > 0 && d0[y][x] > 3 && v > best) {
          best = v;
          door = (x, y);
        }
      }
    }
    if (Z.boss) door = far;
    // Hang vẽ sẵn bằng ô Tiny Dungeon (pixel): tường gạch đá, nền đất; đá đào được vẽ riêng
    DT = G.sp('kenney-tiny-dungeon/dungeon');
    TL = G.sp('kenney-platformer/tiles');
    if (DT?.image != null) {
      cave = prerender(G.pen, (b) {
        b.rect(0, 0, W, H, hx(0x2b1d16));
        for (var y = 0; y < R; y++) {
          for (var x = 0; x < C; x++) {
            final fr = g[y][x] == 1 ? (y == R - 1 || (y + 1 < R && g[y + 1][x] != 1) ? 't40' : 't57') : ((x * 7 + y * 3) % 5 != 0 ? 't0' : 't12');
            b.tile(DT!, fr, ox + x * cs, oy + y * cs, cs, cs);
          }
        }
      });
    }
    hasKey = Z.boss;
    for (var i = 0; i < (Z.boss ? 1 : 2 + Z.s); i++) {
      final p = _randOpen(5);
      if (p != null) foes.add(_MineFoe(p.$1, p.$2, 'Bat', foeStats(2, Z.s, .8), cd: rand(.5, 1)));
    }
    if (Z.boss) {
      boss = _MineFoe(door.$1, door.$2, 'Spider', foeStats(2, 5, 8), boss: true, cd: 2, sp: 4);
      foes.add(boss!);
    }
    // Điều khiển: nút mũi tên, vuốt, phím
    final bx = W - br * 2.9 - 10, by = H - br * 2.9 - 6;
    pad = Buttons(G.M, [
      Btn('u', bx, by - br * 1.6, br, '⬆'),
      Btn('d', bx, by + br * 1.6, br, '⬇'),
      Btn('l', bx - br * 1.8, by, br, '◀'),
      Btn('r', bx + br * 1.8, by, br, '▶'),
    ]);
    G.M.on('up', (p) {
      if (p.btn != null) return;
      final dx = p.x - p.sx, dy = p.y - p.sy;
      if (hypot(dx, dy) < 25) return;
      tryMove(dx.abs() > dy.abs() ? (dx.sign.toInt(), 0) : (0, dy.sign.toInt()));
    });
  }
  final Shell G;
  late int C, R;
  late double br, cs, ox, oy;
  late bool land;
  late List<List<int>> g;
  final Set<String> gems = {};
  late List<List<int>> d0;
  (int, int)? key;
  late (int, int) door;
  SpriteSheet? DT, TL;
  ui.Picture? cave;
  late bool hasKey;
  double moveT = 0;
  final List<_MineFoe> foes = [];
  _MineFoe? boss;
  late Buttons pad;
  final _Cell me = _Cell(1, 1);
  int face = 1;
  double swing = 0;
  bool won = false;

  List<List<int>> _bfs(int sx, int sy) {
    final d = List.generate(R, (_) => List.filled(C, -1));
    final q = Queue<(int, int)>()..add((sx, sy));
    d[sy][sx] = 0;
    while (q.isNotEmpty) {
      final (x, y) = q.removeFirst();
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (_open(nx, ny) && d[ny][nx] < 0) {
          d[ny][nx] = d[y][x] + 1;
          q.add((nx, ny));
        }
      }
    }
    return d;
  }

  bool _open(int x, int y) => y >= 0 && y < R && x >= 0 && x < C && g[y][x] == 0;
  (int, int)? _randOpen(int minD) {
    for (var k = 0; k < 200; k++) {
      final x = 1 + rnd.nextInt(C - 2), y = 1 + rnd.nextInt(R - 2);
      if (_open(x, y) && d0[y][x] >= minD && !(x == door.$1 && y == door.$2)) return (x, y);
    }
    return null;
  }

  _MineFoe? _at(int x, int y) => foes.where((f) => !f.dead && f.x == x && f.y == y).firstOrNull;
  double _cx(num x) => ox + (x + .5) * cs;
  double _cy(num y) => oy + (y + .5) * cs;

  void tryMove((int, int) d) {
    final (dx, dy) = d;
    final nx = me.x + dx, ny = me.y + dy;
    if (dx != 0) face = dx;
    final f = _at(nx, ny);
    final Z = G.Z, F = G.F;
    if (f != null) {
      final s = strike(Z.st);
      f.hp -= s.d;
      f.hurt = .2;
      swing = .25;
      G.sfx('hit');
      G.FB.slash(_cx(me.x), _cy(me.y), cs * .7, math.atan2(dy.toDouble(), dx.toDouble()), dx < 0 ? -1 : 1);
      G.num(_cx(nx), oy + ny * cs - 10, s.d, s.crit);
      if (f.hp <= 0) {
        f.dead = true;
        G.die(Mob(
            sheet: 'kenney-tiny-dungeon/dungeon', frame: f.img == 'Spider' ? 't122' : 't120', pixel: true, img: f.img, x: _cx(nx), y: _cy(ny), size: cs * (f.boss ? 1.5 : .85), boss: f.boss));
        G.kill(f.boss);
        F.burst(_cx(nx), _cy(ny), f.boss ? 40 : 14);
        G.loot((2 + Z.r * 3) * (f.boss ? 15 : 1), _cx(nx), oy + ny * cs);
        G.sfx(f.boss ? 'boom' : 'pop');
      }
      return;
    }
    if (ny >= 0 && ny < R && nx >= 0 && nx < C && g[ny][nx] == 2) {
      g[ny][nx] = 0;
      swing = .25;
      G.sfx('boom');
      G.C.shake(3);
      G.FB.dust(_cx(nx), oy + (ny + .8) * cs, 5, 0, const Color(0xCCADB5BD));
      F.burst(_cx(nx), _cy(ny), 10, [hx(0x868e96), hx(0xadb5bd), hx(0xced4da)]);
      if (gems.contains('$nx,$ny')) {
        G.loot(4.0 + Z.r * 3, _cx(nx), oy + ny * cs);
        F.star(_cx(nx), oy + ny * cs);
      }
      return;
    }
    if (!_open(nx, ny)) return;
    if (nx == door.$1 && ny == door.$2 && !hasKey) {
      F.text(_cx(nx), oy + ny * cs, Z.boss ? '' : 'Cần 🔑', Colors.white);
      return;
    }
    me
      ..px = me.x
      ..py = me.y
      ..x = nx
      ..y = ny
      ..mt = 0;
    final k = key;
    if (k != null && !hasKey && nx == k.$1 && ny == k.$2) {
      hasKey = true;
      G.sfx('correct');
      F.burst(_cx(nx), _cy(ny), 24);
      F.text(_cx(nx), oy + ny * cs, 'Có chìa khoá!', hx(0xffd43b));
    }
  }

  @override
  void update(double dt) {
    swing = math.max(0, swing - dt);
    me.mt += dt;
    moveT -= dt;
    final K = G.keys;
    final (int, int)? dir = pad.down('u') || K.contains('arrowup') || K.contains('w')
        ? (0, -1)
        : pad.down('d') || K.contains('arrowdown') || K.contains('s')
            ? (0, 1)
            : pad.down('l') || K.contains('arrowleft') || K.contains('a')
                ? (-1, 0)
                : pad.down('r') || K.contains('arrowright') || K.contains('d')
                    ? (1, 0)
                    : null;
    if (dir != null && moveT <= 0) {
      tryMove(dir);
      moveT = .2;
    }
    if (dir == null) moveT = 0;
    for (final f in List.of(foes)) {
      if (f.dead) continue;
      f.hurt = math.max(0, f.hurt - dt);
      f.cd -= dt;
      f.mt += dt;
      if (f.cd > 0) continue;
      final near = (f.x - me.x).abs() + (f.y - me.y).abs();
      if (f.boss) {
        f.cd = 1.3;
        if (near == 1) G.hurt(f.dmg, _cx(me.x), oy + me.y * cs);
        f.sp -= 1.3;
        if (f.sp <= 0 && foes.where((x) => !x.dead).length < 4) {
          f.sp = 5;
          final p = _randOpen(2);
          if (p != null) foes.add(_MineFoe(p.$1, p.$2, 'Spider', foeStats(2, 2, .6), cd: 1));
        }
        continue;
      }
      f.cd = rand(.55, .85);
      final opts = [(1, 0), (-1, 0), (0, 1), (0, -1)].where((o) => _open(f.x + o.$1, f.y + o.$2) && _at(f.x + o.$1, f.y + o.$2) == null && !(f.x + o.$1 == door.$1 && f.y + o.$2 == door.$2)).toList();
      if (near == 1) {
        G.hurt(f.dmg, _cx(me.x), oy + me.y * cs);
        f.cd = 1.1;
        continue;
      }
      if (opts.isEmpty) continue;
      var mv = pick(opts);
      int md((int, int) o) => (f.x + o.$1 - me.x).abs() + (f.y + o.$2 - me.y).abs();
      if (near < 5) mv = opts.reduce((b, o) => md(o) < md(b) ? o : b);
      if (f.x + mv.$1 == me.x && f.y + mv.$2 == me.y) continue;
      f
        ..px = f.x
        ..py = f.y
        ..x = f.x + mv.$1
        ..y = f.y + mv.$2
        ..mt = 0;
    }
    if (boss != null && boss!.dead) hasKey = true;
    if (hasKey && me.x == door.$1 && me.y == door.$2) won = true;
    if (boss != null && boss!.dead) won = true;
  }

  (double, double) _pos(_Cell o) {
    final k = E.outCubic(math.min(1, o.mt / .14));
    return (ox + (o.px + (o.x - o.px) * k + .5) * cs, oy + (o.py + (o.y - o.py) * k + .5) * cs);
  }

  @override
  void draw(Pen p) {
    final t = G.t;
    if (cave != null) {
      p.c.drawPicture(cave!);
      for (var y = 0; y < R; y++) {
        for (var x = 0; x < C; x++) {
          if (g[y][x] != 2) continue;
          final X = _cx(x), Y = _cy(y);
          if (!p.spr(TL, 'rock', X, Y, cs * .95)) p.draw('Rock', X, Y, cs * .95);
          if (gems.contains('$x,$y') && math.sin(t * 4 + x * 3 + y) > .7) p.draw('Sparkles', X + cs * .25, Y - cs * .25, cs * .35);
        }
      }
    } else {
      for (var y = 0; y < R; y++) {
        for (var x = 0; x < C; x++) {
          final X = ox + x * cs, Y = oy + y * cs;
          if (g[y][x] == 1) {
            p.rect(X, Y, cs, cs, hx(0x4e342e));
            p.rect(X + 2, Y + cs * .6, cs - 4, cs * .35, hx(0x3e2723));
          } else {
            p.rect(X, Y, cs, cs, (x + y) % 2 == 1 ? hx(0xa1887f) : hx(0x9c8075));
            if (g[y][x] == 2) p.draw('Rock', X + cs / 2, Y + cs / 2, cs * .95);
          }
          if (g[y][x] == 2 && gems.contains('$x,$y') && math.sin(t * 4 + x * 3 + y) > .7) p.draw('Sparkles', X + cs * .75, Y + cs * .25, cs * .35);
        }
      }
    }
    if (!p.spr(DT, hasKey ? 't46' : 't45', _cx(door.$1), _cy(door.$2), cs, pixel: true)) p.draw('Door', _cx(door.$1), _cy(door.$2), cs * .95);
    final k = key;
    if (k != null && !hasKey) {
      final kx = _cx(k.$1), ky = _cy(k.$2) + math.sin(t * 4) * 4;
      if (!p.spr(TL, 'key_yellow', kx, ky, cs * .8, rot: math.sin(t * 2) * .2)) p.draw('Old key', kx, ky, cs * .8);
    }
    for (final f in foes) {
      if (f.dead) continue;
      final (x, y) = _pos(f);
      final sz = cs * (f.boss ? 1.5 : .85);
      // Dơi + nhện Tiny Dungeon (pixel), bay nhấp nhô, nháy sáng khi trúng đòn
      f.v
        ..x = x
        ..y = y
        ..size = sz
        ..t = t + f.x * .7
        ..hurt = f.hurt
        ..flip = me.x > f.x
        ..fly = f.img == 'Bat'
        ..moving = f.mt < .3
        ..atk = 0
        ..img = f.img
        ..pixel = true;
      drawMob(p, f.v, sheet: DT, frame: DT != null ? (f.img == 'Spider' ? 't122' : 't120') : null);
      if (!f.boss && f.hp < f.max) hpBar(p, x - cs * .4, y - cs * .55, cs * .8, 7, f.hp, f.max);
    }
    final (hx0, hy0) = _pos(me);
    drawHero(p, hx0, hy0 - cs * .05, cs * .9, G.Z, face: face, swing: swing, hurt: G.hero.inv, t: t, moving: me.mt < .2);
    if (hasKey && key != null && !p.spr(TL, 'key_yellow', hx0 + cs * .35, hy0 - cs * .4, cs * .4)) p.draw('Old key', hx0 + cs * .35, hy0 - cs * .4, cs * .4);
    pad.draw(p);
    final b = boss;
    if (b != null && !b.dead) bossBar(p, G.W, G.H, b.hp, b.max, 'Nhện Chúa', land ? G.H - 30 : 98);
  }

  @override
  bool done() => won;
  @override
  String? goal() => G.Z.boss ? null : (hasKey ? '🚪 Tới cửa!' : '🔑 Tìm chìa khoá');
}

final ZoneDef mine = ZoneDef(
  ['Rock', 'Gem stone', 'Old key', 'Door', 'Bat', 'Spider', 'Pick', 'Fire'],
  (Z, art, W, H, AudioService audio) => Shell(
      Z,
      art,
      W,
      H,
      audio,
      ShellCfg(
        name: 'Hang Mỏ',
        goalText: Z.boss ? 'Đánh bại Nhện Chúa canh cửa' : 'Tìm 🔑 chìa khoá rồi tới 🚪 cửa',
        hint: 'Bấm mũi tên hoặc vuốt để đi · đi vào đá để đào · đi vào dơi để đánh',
        pot: (W, H, S) {
          final br = math.min(40.0, S * .07);
          return (W - br * 2.6 - 10 - br * 3.4, H - br * 1.2 - 10);
        },
      ),
      (G) => _Mine(G)),
);

// ---------- 4. Xứ Tuyết: đánh theo lượt; ⚔️ bấm đúng lúc vạch ở giữa để đánh mạnh; trùm Voi Ma Mút ----------
class _SnowFoe extends Mob {
  _SnowFoe({required super.img, required super.boss, required this.name, required ({double hp, double dmg}) s, required super.x, required super.y, required super.size})
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg;
  final String name;
  double hp, max, dmg, lunge = 0;
}

class _Snow extends ShellGame {
  _Snow(this.G) {
    final Z = G.Z, W = G.W, H = G.H, S = G.S;
    waves = Z.boss
        ? [
            ['Wolf', 'Mammoth', 'Wolf']
          ]
        : List.generate(2 + Z.s ~/ 3, (i) => List.generate(math.min(3, 1 + (Z.s + i + 1) ~/ 2), (_) => pick(Z.s >= 2 ? ['Wolf', 'Polar bear', 'Snowman'] : ['Wolf', 'Snowman'])));
    hx0 = W * .24;
    hy = H * .58;
    _spawn();
    br = math.min(50, S * .08);
    by = H - br - 18;
    acts = [
      Btn('atk', W / 2 - br * 3.4, by, br, '⚔️', c: hx(0xff922b)),
      Btn('mag', W / 2 - br * 1.1, by, br, '❄️', c: hx(0x74c0fc)),
      Btn('def', W / 2 + br * 1.2, by, br, '🛡', c: hx(0xadb5bd)),
      Btn('go', W / 2, by, br * 1.3, '👊', c: hx(0xff922b), hidden: true),
    ];
    AB = Buttons(G.M, acts);
    G.M.on('down', (p) {
      if (p.btn != null) return;
      if (state == 'timing') {
        _stopBar();
        return;
      }
      if (state == 'choose') {
        for (var i = 0; i < foes.length; i++) {
          final f = foes[i];
          if (f.hp > 0 && dist(p, f) < f.size * .6) {
            target = i;
            G.sfx('tap');
          }
        }
      }
    });
  }
  final Shell G;
  late List<List<String>> waves;
  int wave = 0, target = 0, turn = 0, mana = 2;
  List<_SnowFoe> foes = [];
  String state = 'choose', msg = '';
  String? act;
  double stT = 0, bar = 0, barDir = 1, mult = 1;
  bool defend = false, won = false, petDone = false;
  List<_SnowFoe> queue = [];
  late double hx0, hy, br, by;
  late List<Btn> acts;
  late Buttons AB;
  PetBuddy? petRig;

  void _spawn() {
    final list = waves[wave], n = list.length;
    foes = [
      for (var i = 0; i < n; i++)
        () {
          final k = list[i], boss = k == 'Mammoth';
          return _SnowFoe(
              img: k,
              boss: boss,
              name: boss ? 'Voi Ma Mút' : '',
              s: foeStats(3, G.Z.s, boss ? 7 : (k == 'Polar bear' ? 2.2 : 1.6)),
              x: G.W * .72 + (i - (n - 1) / 2) * G.W * .07,
              y: hy + (i - (n - 1) / 2) * G.H * .17,
              size: G.S * (boss ? .3 : .15));
        }()
    ];
    target = foes.indexWhere((f) => f.boss);
    if (target < 0) target = 0;
  }

  List<_SnowFoe> get _alive => foes.where((f) => f.hp > 0).toList();

  void _hitFoe(_SnowFoe f, int d, [bool crit = false]) {
    f.hp -= d;
    f.hurt = .3;
    G.num(f.x, f.y - f.size * .6, d, crit);
    if (f.hp <= 0) {
      f.hp = 0;
      G.die(Mob(img: f.img, x: f.x, y: f.y, size: f.size, boss: f.boss));
      G.kill(f.boss);
      G.sfx(f.boss ? 'boom' : 'pop');
      G.F.burst(f.x, f.y, f.boss ? 40 : 16, [Colors.white, hx(0xa5d8ff), hx(0x74c0fc)]);
      G.loot((2 + G.Z.r * 3) * (f.boss ? 15 : 1.5), f.x, f.y);
    }
  }

  void _stopBar() {
    final off = bar.abs();
    mult = off < .18 ? 1.6 : (off < .55 ? 1 : .6);
    msg = off < .18 ? 'TUYỆT VỜI!' : (off < .55 ? 'Tốt!' : 'Hơi lệch');
    state = 'hero';
    stT = 0;
    act = 'atk';
    G.sfx(off < .18 ? 'star' : 'tap');
  }

  void _enemyPhase() {
    queue = _alive;
    state = 'enemy';
    stT = 0;
  }

  void _ensureTarget() {
    if (target < 0 || target >= foes.length || foes[target].hp <= 0) target = foes.indexWhere((f) => f.hp > 0);
  }

  @override
  void update(double dt) {
    final Z = G.Z, F = G.F;
    stT += dt;
    for (final f in foes) {
      f.hurt = math.max(0, f.hurt - dt);
      f.lunge = math.max(0, f.lunge - dt);
    }
    for (final a in acts) {
      a.hidden = a.id == 'go' ? state != 'timing' : state != 'choose';
    }
    if (state == 'choose') {
      _ensureTarget();
      if (AB.hit('atk')) {
        state = 'timing';
        bar = -1;
        barDir = 1;
        G.sfx('tap');
      } else if (AB.hit('mag')) {
        if (mana >= 2) {
          mana -= 2;
          act = 'mag';
          state = 'hero';
          stT = 0;
          G.sfx('power');
        } else {
          G.sfx('wrong');
          F.text(G.W / 2, G.H * .3, 'Cần 2 ❄️', Colors.white);
        }
      } else if (AB.hit('def')) {
        defend = true;
        G.hero.hp = math.min(G.hero.max, G.hero.hp + G.hero.max * .08);
        F.text(hx0, hy - 60, '🛡 Đỡ', Colors.white);
        act = null;
        state = 'pet';
        stT = 0;
      }
    } else if (state == 'timing') {
      bar += barDir * dt * (1.4 + Z.s * .12);
      if (bar > 1) {
        bar = 1;
        barDir = -1;
      }
      if (bar < -1) {
        bar = -1;
        barDir = 1;
      }
      if (AB.hit('go') || G.keys.contains(' ')) _stopBar();
    } else if (state == 'hero') {
      if (stT > .35 && act != null) {
        if (act == 'atk') {
          _ensureTarget();
          if (target >= 0) {
            final s = strike(Z.st, mult);
            _hitFoe(foes[target], s.d, s.crit);
          }
          G.sfx('hit');
          F.text(hx0, hy - 80, msg, hx(0xffd43b));
        } else {
          for (final f in _alive) {
            final s = strike(Z.st, .9);
            _hitFoe(f, s.d, s.crit);
          }
          F.burst(G.W * .72, hy, 50, [Colors.white, hx(0xd0ebff), hx(0x74c0fc)]);
          G.sfx('boom');
        }
        act = null;
      }
      if (stT > .9) {
        state = 'pet';
        stT = 0;
      }
    } else if (state == 'pet') {
      if (stT > .2 && Z.pet != null && !petDone) {
        petDone = true;
        _ensureTarget();
        final f = target >= 0 ? foes[target] : null;
        if (Z.pet == 'dog' && f != null) {
          _hitFoe(f, (Z.st.atk * .4).round());
          G.sfx('bark');
        } else if (Z.pet == 'fairy') {
          G.hero.hp = math.min(G.hero.max, G.hero.hp + G.hero.max * .06);
          F.text(hx0, hy - 60, '+máu', hx(0x69db7c));
        } else if (Z.pet == 'dragon') {
          for (final x in _alive) {
            _hitFoe(x, (Z.st.atk * .3).round());
          }
          F.burst(G.W * .72, hy, 20, [hx(0xff922b), hx(0xffd43b)]);
        }
      }
      if (stT > (Z.pet != null ? .8 : .1)) {
        petDone = false;
        if (_alive.isEmpty) {
          wave++;
          if (wave >= waves.length) {
            won = true;
          } else {
            _spawn();
            state = 'banner';
            stT = 0;
          }
        } else {
          _enemyPhase();
        }
      }
    } else if (state == 'enemy') {
      if (queue.isEmpty) {
        turn++;
        mana = math.min(4, mana + 1);
        defend = false;
        state = 'choose';
        stT = 0;
      } else if (stT > .65) {
        final f = queue.removeAt(0);
        stT = 0;
        if (f.hp > 0) {
          f.lunge = .35;
          final big = f.boss && turn % 3 == 2;
          final d = taken((f.dmg * (big ? 1.6 : 1)).roundToDouble(), Z.st.def) * (defend ? .5 : 1);
          G.hurt(math.max(1, d.round()).toDouble(), hx0, hy, true);
          if (big) {
            F.text(hx0, hy - 90, 'DẬM ĐẤT!', hx(0xff8787));
            G.sfx('boom');
          }
        }
      }
    } else if (state == 'banner') {
      if (stT > 1.4) state = 'choose';
    }
  }

  @override
  void draw(Pen p) {
    final W = G.W, H = G.H, S = G.S, t = G.t, Z = G.Z;
    p.vgrad(W, H, [hx(0xa5d8ff), hx(0xf8f9fa)]);
    p.draw('Snow-capped mountain', W * .3, H * .32, S * .4);
    p.draw('Snow-capped mountain', W * .75, H * .28, S * .5);
    p.rect(0, H * .45, W, H, Colors.white);
    final TL = G.sp('kenney-platformer/tiles'), ts = S * .08;
    if (TL?.image != null) {
      for (var x = 0.0; x < W + ts; x += ts) {
        p.spr(TL, 'terrain_snow_block_top', x, H * .45 + ts / 2, ts);
      }
    }
    for (var i = 0; i < 4; i++) {
      p.draw('Evergreen tree', (i * W / 3.5 + 40) % W, H * .45 - S * .03, S * .1);
    }
    for (var i = 0; i < 30; i++) {
      p.circle((i * 97 + t * 20) % W, (i * 61 + t * 40) % H, 3, const Color(0xE6FFFFFF));
    }
    final lx = state == 'hero' && stT < .7 ? hx0 + math.sin(math.min(1, stT / .7) * pi) * (W * .3) : hx0;
    final dash = state == 'hero' && act == 'atk' && stT < .3;
    drawHero(p, lx, hy, S * .2, Z,
        face: 1,
        swing: state == 'hero' && stT > .3 && stT < .55 ? .25 - (stT - .3) : 0,
        hurt: G.hero.inv,
        t: t,
        pose: dash ? 'run' : (defend ? 'block' : (state == 'hero' && act == 'mag' ? 'cheer' : null)));
    if (defend) p.draw('Shield', hx0 + S * .1, hy, S * .1);
    if (Z.pet != null) {
      petRig ??= petBuddy(kPetRig[Z.pet] ?? 'dog');
      petRig!.update(1 / 60, false);
      petRig!.draw(p.c, hx0 - S * .14, hy + S * .1, S * .045);
    }
    for (var i = 0; i < foes.length; i++) {
      final f = foes[i];
      if (f.hp <= 0) continue;
      if (i == target && state == 'choose') {
        p.c.drawOval(Rect.fromCenter(center: Offset(f.x, f.y + f.size * .42), width: f.size * .9, height: f.size * .26), p.stroke(hx(0xffd43b), 4));
        p.draw('Glowing star', f.x, f.y - f.size * .75 + math.sin(t * 5) * 4, 26);
      }
      // Thở nhẹ khi đứng, co người lấy đà rồi lao tới khi tấn công, dẹt + nháy khi trúng
      final x0 = f.x;
      final view = Mob(x: f.x - E.bump(f.lunge / .35) * W * .12, y: f.y, size: f.size, img: f.img)
        ..t = t + i
        ..hurt = math.min(.15, f.hurt)
        ..moving = false
        ..wind = f.lunge > .25 ? (.35 - f.lunge) / .1 : 0
        ..atk = f.lunge > 0 && f.lunge <= .25 ? 1 - f.lunge / .25 : 0;
      drawMob(p, view);
      if (!f.boss) hpBar(p, x0 - f.size * .4, f.y - f.size * .62, f.size * .8, 10, f.hp, f.max);
    }
    final bs = foes.where((f) => f.boss && f.hp > 0).firstOrNull;
    if (bs != null) bossBar(p, W, H * .82, bs.hp, bs.max, bs.name);
    if (bs != null && turn % 3 == 1 && state == 'choose') p.text('Voi ma mút đang lấy đà! Bấm 🛡 Đỡ', W / 2, H * .25, size: 20, color: hx(0xc92a2a));
    // Năng lượng phép
    p.text('Phép:', 16, H * .25 + 40, size: 18, color: hx(0x1864ab), align: 'left');
    for (var i = 0; i < 4; i++) {
      p.draw('Snowflake', 80 + i * 30, H * .25 + 34, 26, alpha: i < mana ? 1 : .2);
    }
    if (state == 'choose') p.text('Lượt của bé! Chạm quái để chọn', W / 2, by - br - 14, size: 20, color: hx(0x212529));
    if (state == 'timing') {
      final bw = math.min(520.0, W * .8), bx = W / 2 - bw / 2, y = H * .3;
      p.rrect(bx, y, bw, 30, 15, hx(0xff8787));
      p.rect(bx + bw * .225, y, bw * .55, 30, hx(0xffd43b));
      p.rect(bx + bw * .41, y, bw * .18, 30, hx(0x51cf66));
      p.rect(bx + bw * (bar + 1) / 2 - 4, y - 8, 8, 46, hx(0x212529));
      p.text('Bấm 👊 khi vạch ở ô XANH!', W / 2, y - 16, size: 20, color: hx(0x212529));
    }
    if (state == 'banner') {
      p.rect(0, H / 2 - 40, W, 80, const Color(0x59000000));
      p.text('Đợt ${wave + 1}', W / 2, H / 2 + 14, size: 40);
    }
    AB.draw(p);
  }

  @override
  bool done() => won;
  @override
  String? goal() => G.Z.boss ? null : '❄️ Đợt ${math.min(wave + 1, waves.length)}/${waves.length}';
}

final ZoneDef snow = ZoneDef(
  ['Wolf', 'Polar bear', 'Snowman', 'Mammoth', 'Snowflake', 'Evergreen tree', 'Snow-capped mountain', 'Shield'],
  (Z, art, W, H, AudioService audio) => Shell(
      Z,
      art,
      W,
      H,
      audio,
      ShellCfg(
          name: 'Xứ Tuyết', goalText: Z.boss ? 'Đánh bại Voi Ma Mút' : 'Thắng ${2 + Z.s ~/ 3} đợt quái', hint: 'Đến lượt bé: chọn ⚔️ Đánh, ❄️ Phép hoặc 🛡 Đỡ'),
      (G) => _Snow(G)),
);

// ---------- 5. Sa Mạc: đào cát tìm kho báu (ô càng đỏ càng gần), gặp bọ cạp thì chạm để đánh; trùm Bọ Cạp Vua chui lên chui xuống ----------
class _DCell {
  _DCell(this.x, this.y);
  final int x, y;
  bool dug = false;
  String? has;
}

class _Scorp extends Mob {
  _Scorp(double x, double y, ({double hp, double dmg}) s)
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg,
        super(x: x, y: y, img: 'Scorpion');
  double hp, max, dmg, cd = 1, atkT = 0;
}

class _DBoss {
  _DBoss(({double hp, double dmg}) s)
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg;
  double hp, max, dmg, up = 0, upMax = 1, cd = 1.2, hide = 0;
  _DCell? cell;
  int stings = 0;
}

class _Desert extends ShellGame {
  _Desert(this.G) {
    final Z = G.Z, W = G.W, H = G.H;
    C = Z.s >= 3 ? 8 : 7;
    NT = Z.boss ? 0 : 3 + Z.s ~/ 2;
    NS = Z.boss ? 0 : 2 + Z.s ~/ 2;
    cs = math.min((W - 40) / C, (H - 200) / R).floorToDouble();
    ox = ((W - C * cs) / 2).roundToDouble();
    oy = 110 + ((H - 190 - R * cs) / 2).roundToDouble();
    cells = List.generate(R, (y) => List.generate(C, (x) => _DCell(x, y)));
    all = cells.expand((r) => r).toList();
    List<_DCell> free() => all.where((c) => c.has == null).toList();
    for (var i = 0; i < NT; i++) {
      pick(free()).has = pick(['Money bag', 'Gem stone', 'Wrapped gift']);
    }
    for (var i = 0; i < NS; i++) {
      pick(free()).has = 'Scorpion';
    }
    digs = NT * 4 + 5 + NS;
    if (Z.boss) boss = _DBoss(foeStats(4, 5, 9));
    G.M.on('down', (p) {
      if (p.btn != null || G.introT > 0) return;
      final b = boss;
      if (b != null) {
        final c = _cellAt(p);
        if (b.cell != null && b.up > 0 && c == b.cell) {
          final s = strike(Z.st);
          b.hp -= s.d;
          b.up = 0;
          b.hide = .3;
          G.sfx('hit');
          G.num(p.x, p.y - 30, s.d, s.crit);
          G.F.burst(p.x, p.y, 16, [hx(0xffd8a8), hx(0xfab005)]);
          if (b.hp <= 0) {
            G.die(Mob(img: 'Scorpion', x: p.x, y: p.y, size: cs * 1.3, boss: true));
            G.kill(true);
            G.loot((2 + Z.r * 3) * 15, p.x, p.y);
            G.sfx('boom');
          }
        }
        return;
      }
      final f = fight;
      if (f != null) {
        if (dist(p, f) < cs * .8) {
          final s = strike(Z.st);
          f.hp -= s.d;
          f.hurt = .2;
          G.sfx('hit');
          G.num(f.x, f.y - cs * .4, s.d, s.crit);
          if (f.hp <= 0) {
            G.die(Mob(img: 'Scorpion', x: f.x, y: f.y, size: cs * 1.1));
            G.kill();
            G.loot((2 + Z.r * 3) * 1.5, f.x, f.y);
            G.F.burst(f.x, f.y, 16);
            G.sfx('pop');
            fight = null;
          }
        }
        return;
      }
      final c = _cellAt(p);
      if (c == null || c.dug || digT != null || digs <= 0) return;
      digT = c;
      digTime = 0;
      G.sfx('tap');
    });
  }
  final Shell G;
  late int C, NT, NS, digs;
  final int R = 5;
  late double cs, ox, oy;
  late List<List<_DCell>> cells;
  late List<_DCell> all;
  int found = 0;
  _Scorp? fight;
  _DCell? digT;
  double digTime = 0;
  _DBoss? boss;

  _DCell? _cellAt(XY p) {
    final x = ((p.x - ox) / cs).floor(), y = ((p.y - oy) / cs).floor();
    return y >= 0 && y < R && x >= 0 && x < C ? cells[y][x] : null;
  }

  int _heat(_DCell c) {
    var d = 99;
    for (final o in all) {
      if (o.has != null && o.has != 'Scorpion' && !o.dug) d = math.min(d, (o.x - c.x).abs() + (o.y - c.y).abs());
    }
    return d;
  }

  @override
  void update(double dt) {
    final Z = G.Z, F = G.F;
    final b = boss;
    if (b != null) {
      if (b.hp <= 0) return;
      b.cd -= dt;
      if (b.up > 0) {
        b.up -= dt;
        if (b.up <= 0) {
          b.stings++;
          G.hurt(b.dmg, b.cell != null ? ox + (b.cell!.x + .5) * cs : G.W / 2, oy + (b.cell?.y ?? 0) * cs);
          b.cell = null;
          b.cd = .8;
        }
      } else if (b.cd <= 0) {
        b.cell = pick(all);
        b.up = b.upMax = math.max(.9, 1.9 - Z.s * .1 - (1 - b.hp / b.max) * .6);
        b.cd = rand(.5, 1);
        G.sfx('pop');
        G.FB.dust(ox + (b.cell!.x + .5) * cs, oy + (b.cell!.y + .8) * cs, 6, 0, const Color(0xB3FAB005));
      }
      return;
    }
    final f = fight;
    if (f != null) {
      f.hurt = math.max(0, f.hurt - dt);
      f.cd -= dt;
      f.atkT = math.max(0, f.atkT - dt);
      if (f.cd <= 0) {
        f.cd = 1.4;
        f.atkT = .35;
        G.hurt(f.dmg, f.x, f.y);
      }
    }
    final d = digT;
    if (d != null) {
      digTime += dt;
      if (digTime > .3) {
        d.dug = true;
        digs--;
        digT = null;
        final X = ox + (d.x + .5) * cs, Y = oy + (d.y + .5) * cs;
        F.burst(X, Y, 10, [hx(0xffd8a8), hx(0xfab005), hx(0xe8590c)]);
        G.FB.dust(X, Y + cs * .3, 4, 0, const Color(0x99FAB005));
        G.C.shake(1.5);
        if (d.has == 'Scorpion') {
          fight = _Scorp(X, Y, foeStats(4, Z.s, 1.2));
          G.sfx('wrong');
          F.text(X, Y - cs * .5, 'Bọ cạp!', hx(0xff8787));
        } else if (d.has != null) {
          found++;
          G.loot(8.0 + Z.r * 6, X, Y);
          F.star(X, Y);
          G.sfx('correct');
          G.xp += 5;
        } else {
          G.sfx(_heat(d) <= 1 ? 'star' : 'pop');
        }
      }
    }
  }

  @override
  void draw(Pen p) {
    final W = G.W, H = G.H, S = G.S, t = G.t;
    p.vgrad(W, H, [hx(0xffa94d), hx(0xffe8cc), hx(0xffd8a8)], [0, .35, 1]);
    p.draw('Sun with face', W * .9, 100, S * .1);
    p.draw('Cactus', 40, H - 60, S * .1);
    p.draw('Camel', W - 70, H - 60, S * .12);
    final TL = G.sp('kenney-platformer/tiles');
    for (final c in all) {
      final X = ox + c.x * cs, Y = oy + c.y * cs;
      if (!c.dug) {
        // Ô cát Kenney; ô đang đào rung lắc
        final sh = digT == c ? math.sin(t * 60) * 3 : 0.0;
        if (!p.spr(TL, 'terrain_sand_block_center', X + cs / 2 + sh, Y + cs / 2, cs - 4)) {
          p.rrect(X + 3, Y + 3, cs - 6, cs - 6, 10, (c.x + c.y) % 2 == 1 ? hx(0xf6c98a) : hx(0xf0bd78));
        }
        continue;
      }
      p.rrect(X + 3, Y + 3, cs - 6, cs - 6, 10, hx(0xc9a27a));
      p.oval(X + cs / 2, Y + cs * .55, cs * .34, cs * .22, hx(0x8d6e63));
      if (c.has != null && c.has != 'Scorpion') {
        p.draw(c.has, X + cs / 2, Y + cs / 2, cs * .7);
      } else if (c.has == null) {
        final h = _heat(c);
        final col = h <= 1 ? hx(0xfa5252) : (h == 2 ? hx(0xff922b) : (h == 3 ? hx(0xfcc419) : hx(0x74c0fc)));
        p.circle(X + cs / 2, Y + cs / 2, cs * .28, col);
        p.text(h <= 1 ? '🔥' : (h >= 4 && h < 99 ? '❄️' : ''), X + cs / 2, Y + cs * .6, size: cs * .3, weight: FontWeight.w400);
      }
    }
    final d = digT;
    if (d != null) p.draw('Pick', ox + (d.x + .6) * cs, oy + (d.y + .4) * cs, cs * .6, rot: math.sin(digTime * 30) * .5);
    final f = fight;
    if (f != null) {
      final view = Mob(x: f.x, y: f.y, size: cs * 1.1, img: 'Scorpion')
        ..t = t
        ..hurt = math.min(.15, f.hurt)
        ..atk = f.atkT > 0 ? 1 - f.atkT / .35 : 0;
      drawMob(p, view);
      hpBar(p, f.x - cs * .45, f.y - cs * .65, cs * .9, 10, f.hp, f.max);
      p.text('Chạm bọ cạp để đánh!', W / 2, oy - 12, size: 20, color: hx(0xc92a2a));
    }
    final b = boss;
    if (b != null && b.hp > 0) {
      final bc = b.cell;
      if (bc != null && b.up > 0) {
        // Trồi lên khỏi hố (outBack), sắp chích thì rung
        final X = ox + (bc.x + .5) * cs, Y = oy + (bc.y + .5) * cs, age = b.upMax - b.up, k = E.outBack(math.min(1, age / .3));
        final warn = b.up < .35 ? math.sin(t * 50) * 3 : 0.0;
        p.draw('Hole', X, Y + cs * .25, cs * .9);
        p.c.save();
        p.c.clipRect(Rect.fromLTWH(X - cs, Y - cs * 1.4, cs * 2, cs * 1.65));
        p.draw('Scorpion', X + warn, Y - cs * .1 + (1 - k) * cs, cs * 1.3);
        p.draw('Crown', X + warn, Y - cs * .7 + (1 - k) * cs, cs * .4);
        p.c.restore();
      }
      bossBar(p, W, H, b.hp, b.max, 'Bọ Cạp Vua');
    }
    if (b == null) {
      p.rrect(14, H - 54, 170, 40, 20, const Color(0x4D000000));
      p.draw('Pick', 38, H - 34, 28);
      p.text('Còn $digs lượt đào', 56, H - 27, size: 20, align: 'left');
    }
  }

  @override
  bool done() => boss != null ? boss!.hp <= 0 : found >= NT;
  @override
  String? goal() => G.Z.boss ? null : '💰 $found/$NT';

  /// Hết lượt đào mà chưa đủ thì thua.
  @override
  bool get lose => boss == null && digs <= 0 && found < NT && digT == null;
}

final ZoneDef desert = ZoneDef(
  ['Scorpion', 'Money bag', 'Gem stone', 'Wrapped gift', 'Cactus', 'Camel', 'Desert', 'Sun with face', 'Hole', 'Pick'],
  (Z, art, W, H, AudioService audio) => Shell(
      Z,
      art,
      W,
      H,
      audio,
      ShellCfg(
          name: 'Sa Mạc',
          goalText: Z.boss ? 'Chạm Bọ Cạp Vua mỗi khi nó chui lên' : 'Đào được ${3 + Z.s ~/ 2} kho báu',
          hint: 'Chạm ô cát để đào · 🔥 đỏ là gần kho báu, ❄️ xanh là xa'),
      (G) => _Desert(G)),
);

// ---------- 7. Rừng Kẹo: đặt lính kẹo dọc đường giữ chiếc bánh; chạm quái để đánh thêm; trùm Nhện Kẹo ----------
class _Tower {
  const _Tower(this.id, this.img, this.vi, this.cost, this.range, this.rate, this.dmg, this.shot, {this.slow = false, this.splash = 0});
  final String id, img, vi, shot;
  final int cost;
  final double range, rate, dmg, splash;
  final bool slow;
}

const List<_Tower> _towers = [
  _Tower('pop', 'Lollipop', 'Kẹo mút', 30, .26, .7, .45, 'Candy'),
  _Tower('ice', 'Ice cream', 'Kem lạnh', 40, .22, 1.1, .25, 'Snowflake', slow: true),
  _Tower('boom', 'Doughnut', 'Bom bánh', 60, .24, 1.7, .6, 'Doughnut', splash: .1),
];

class _Placed {
  _Placed(this.t);
  final _Tower t;
  int lv = 1;
  double cd = 0;
}

class _Slot extends XY {
  _Slot(super.x, super.y);
  _Placed? t;
}

class _Bug extends Mob {
  _Bug({required super.img, super.anim, required ({double hp, double dmg}) s, required this.spd, required super.size, super.boss, this.name = ''})
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg,
        super(sheet: anim != null ? 'kenney-platformer/enemies' : null);
  double hp, max, dmg, spd, d = 0, slow = 0;
  bool dead = false;
  final String name;
}

class _CShot extends XY {
  _CShot(super.x, super.y, this.tg, this.t, this.sp);
  final _Bug tg;
  final _Placed t;
  final double sp;
  bool done = false;
}

class _Candy extends ShellGame {
  _Candy(this.G) {
    final Z = G.Z, W = G.W, H = G.H, S = G.S;
    top = 120;
    bot = H - 120;
    pts = [(-30.0, top + 20), (W * .3, top + 20), (W * .3, bot), (W * .62, bot), (W * .62, top + 20), (W * .88, top + 20), (W * .88, (top + bot) / 2)]
        .map((p) => XY(p.$1, p.$2))
        .toList();
    for (var i = 0; i < pts.length - 1; i++) {
      final l = dist(pts[i], pts[i + 1]);
      segs.add((pts[i], pts[i + 1], l, total));
      total += l;
    }
    slots = [
      (.15, top + 90),
      (.45, top + 70),
      (.45, bot - 60),
      (.2, (top + bot) / 2),
      (.76, (top + bot) / 2 + 30),
      (.46, (top + bot) / 2),
      (.76, top + 90),
      (.15, bot - 10)
    ].map((p) => _Slot(W * p.$1, p.$2)).toList();
    NW = Z.boss ? 3 : 3 + Z.s ~/ 2;
    candy = 70 + Z.s * 10;
    bw = math.min(110, (W - 40) / 3.4);
    selBtns = [for (var i = 0; i < _towers.length; i++) XY(W / 2 + (i - 1) * (bw + 10), H - bh / 2 - 12)];
    G.M.on('down', (p) {
      if (G.introT > 0) return;
      for (var i = 0; i < selBtns.length; i++) {
        final b = selBtns[i];
        if ((p.x - b.x).abs() < bw / 2 && (p.y - b.y).abs() < bh / 2) {
          sel = i;
          G.sfx('tap');
          return;
        }
      }
      for (final sl in slots) {
        if (dist(p, sl) < S * .055) {
          final pt = sl.t;
          if (pt == null) {
            final T = _towers[sel];
            if (candy >= T.cost) {
              candy -= T.cost;
              sl.t = _Placed(T);
              G.sfx('power');
              G.F.burst(sl.x, sl.y, 14);
            } else {
              G.sfx('wrong');
              G.F.text(sl.x, sl.y - 30, 'Thiếu kẹo', Colors.white);
            }
          } else if (pt.lv < 3) {
            final c = (pt.t.cost * .7 * pt.lv).round();
            if (candy >= c) {
              candy -= c;
              pt.lv++;
              G.sfx('star');
              G.F.text(sl.x, sl.y - 30, 'Cấp ${pt.lv}!', hx(0xffd43b));
            } else {
              G.sfx('wrong');
              G.F.text(sl.x, sl.y - 30, 'Cần $c 🍬', Colors.white);
            }
          }
          return;
        }
      }
      if (tapCd > 0) return;
      for (final f in foes) {
        if (!f.dead && dist(p, f) < f.size * .7) {
          tapCd = .25;
          final s = strike(Z.st, .5);
          _hurtFoe(f, s.d, s.crit);
          G.sfx('hit');
          return;
        }
      }
    });
  }
  final Shell G;
  late double top, bot, bw;
  final double bh = 62;
  late List<XY> pts;
  final List<(XY, XY, double, double)> segs = [];
  double total = 0;
  late List<_Slot> slots;
  late int NW, candy;
  int wave = 0, toSpawn = 0, sel = 0;
  double spT = 0, breakT = 2.5, tapCd = 0;
  bool bossOut = false, won = false;
  List<_Bug> foes = [];
  List<_CShot> shots = [];
  late List<XY> selBtns;

  XY _posAt(double d) {
    for (final (a, b, l, s) in segs) {
      if (d <= s + l) {
        final k = (d - s) / l;
        return XY(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k);
      }
    }
    return pts.last;
  }

  void _startWave() {
    toSpawn = 6 + G.Z.s + wave * 2;
    spT = 0;
  }

  void _hurtFoe(_Bug f, int d, [bool crit = false]) {
    if (f.dead) return;
    f.hp -= d;
    f.hurt = .15;
    G.FB.num(f.x, f.y - f.size * .6, crit ? '$d!' : '$d', crit: crit, size: 20);
    if (f.hp <= 0) {
      f.dead = true;
      G.die(Mob(img: f.img, sheet: f.sheet, anim: f.anim, x: f.x, y: f.y, size: f.size * 1.3, flip: f.flip, boss: f.boss));
      G.kill(f.boss);
      if (!f.boss) candy += 7;
      G.F.burst(f.x, f.y, f.boss ? 40 : 10);
      G.sfx(f.boss ? 'boom' : 'pop');
      if (rnd.nextDouble() < .35 || f.boss) G.loot((2 + G.Z.r * 3) * (f.boss ? 15 : 1), f.x, f.y);
    }
  }

  @override
  void update(double dt) {
    final Z = G.Z, S = G.S;
    tapCd -= dt;
    if (breakT > 0) {
      breakT -= dt;
      if (breakT <= 0) _startWave();
    } else if (toSpawn > 0) {
      spT -= dt;
      if (spT <= 0) {
        spT = math.max(.45, .95 - Z.s * .06);
        toSpawn--;
        final k = pick(Z.s >= 2 ? ['Ant', 'Ant', 'Lady beetle', 'Cockroach'] : ['Ant', 'Ant', 'Lady beetle']);
        final s = foeStats(6, Z.s, k == 'Cockroach' ? .9 : (k == 'Lady beetle' ? .6 : .35));
        foes.add(_Bug(
            img: k,
            anim: k == 'Ant' ? 'mouse' : (k == 'Lady beetle' ? 'ladybug' : 'snail'),
            s: s,
            spd: S * (k == 'Ant' ? .16 : (k == 'Lady beetle' ? .12 : .1)),
            size: S * (k == 'Cockroach' ? .08 : .065))
          ..t = rand(0, 2));
      }
    } else if (!foes.any((f) => !f.dead)) {
      if (Z.boss && wave == NW - 1 && !bossOut) {
        bossOut = true;
        foes.add(_Bug(img: 'Spider', s: foeStats(6, 5, 6), spd: S * .05, size: S * .16, boss: true, name: 'Nhện Kẹo'));
      } else if (wave + 1 >= NW) {
        won = true;
      } else {
        wave++;
        breakT = 2.5;
        candy += 15;
      }
    }
    for (final f in foes) {
      if (f.dead) continue;
      f.hurt = math.max(0, f.hurt - dt);
      f.slow = math.max(0, f.slow - dt);
      f.t += dt;
      final px = f.x;
      f.d += f.spd * (f.slow > 0 ? .5 : 1) * dt;
      final pos = _posAt(f.d);
      f
        ..x = pos.x
        ..y = pos.y;
      if ((f.x - px).abs() > .01) f.flip = f.x > px;
      if (f.d >= total) {
        f.dead = true;
        G.hurt(f.boss ? 5 : 1, G.W * .88, (top + bot) / 2, true);
      }
    }
    for (final sl in slots) {
      final t = sl.t;
      if (t == null) continue;
      t.cd -= dt;
      if (t.cd > 0) continue;
      _Bug? tg;
      final bd = S * t.t.range * (1 + (t.lv - 1) * .15);
      for (final f in foes) {
        if (f.dead) continue;
        final d = dist(f, sl);
        if (d < bd && (tg == null || f.d > tg.d)) tg = f;
      }
      if (tg != null) {
        t.cd = t.t.rate;
        shots.add(_CShot(sl.x, sl.y, tg, t, S * 1.4));
      }
    }
    for (final s in shots) {
      if (s.tg.dead) {
        s.done = true;
        continue;
      }
      final a = math.atan2(s.tg.y - s.y, s.tg.x - s.x);
      s.x += math.cos(a) * s.sp * dt;
      s.y += math.sin(a) * s.sp * dt;
      if (dist(s, s.tg) < 14) {
        s.done = true;
        final d = (Z.st.atk * s.t.t.dmg * (1 + (s.t.lv - 1) * .5)).round();
        if (s.t.t.splash > 0) {
          for (final f in List.of(foes)) {
            if (dist(f, s.tg) < S * s.t.t.splash) _hurtFoe(f, d);
          }
          G.F.burst(s.x, s.y, 10, [hx(0xf783ac), hx(0xffd43b)]);
        } else {
          _hurtFoe(s.tg, d);
        }
        if (s.t.t.slow) s.tg.slow = 1.5;
      }
    }
    shots.removeWhere((s) => s.done);
    foes.removeWhere((f) => f.dead);
  }

  final Path _path = Path();

  @override
  void draw(Pen p) {
    final W = G.W, H = G.H, S = G.S, t = G.t;
    p.rect(0, 0, W, H, hx(0xfff0f6));
    for (var i = 0; i < 16; i++) {
      p.circle((i * 211) % W, 70 + (i * 131) % (H - 70), 40, i % 2 == 1 ? hx(0xffdeeb) : hx(0xfcc2d7));
    }
    _path.reset();
    _path.moveTo(pts[0].x, pts[0].y);
    for (final q in pts.skip(1)) {
      _path.lineTo(q.x, q.y);
    }
    p.c.drawPath(_path, p.stroke(hx(0xe599f7), S * .09)..strokeJoin = StrokeJoin.round);
    // Vạch đứt giữa đường
    final dash = p.stroke(Colors.white, 3);
    for (final m in _path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        p.c.drawPath(m.extractPath(d, math.min(m.length, d + 10)), dash);
      }
    }
    final end = pts.last;
    p.draw('Birthday cake', end.x, end.y + S * .04, S * .16);
    for (final sl in slots) {
      final pt = sl.t;
      if (pt == null) {
        p.circle(sl.x, sl.y, S * .05, const Color(0xD9FFFFFF));
        final ring = p.stroke(hx(0xf06595), 3);
        for (var a = 0.0; a < pi * 2; a += .5) {
          p.c.drawArc(Rect.fromCircle(center: Offset(sl.x, sl.y), radius: S * .05), a, .3, false, ring);
        }
        p.text('+', sl.x, sl.y + 8, size: 22, color: hx(0xf06595));
        continue;
      }
      p.circle(sl.x, sl.y, S * .055, hx(0xf06595));
      p.draw(pt.t.img, sl.x, sl.y, S * .085);
      for (var i = 0; i < pt.lv; i++) {
        p.draw('Glowing star', sl.x - 14 + i * 14, sl.y + S * .06, 14);
      }
    }
    final EN = G.sp('kenney-platformer/enemies');
    for (final f in foes) {
      final sz0 = f.size;
      f.size = sz0 * 1.3;
      f.moving = true;
      drawMob(p, f, sheet: f.anim != null ? EN : null, anim: f.anim);
      f.size = sz0;
      if (f.slow > 0) p.draw('Snowflake', f.x + f.size * .3, f.y - f.size * .3, 16);
      if (!f.boss && f.hp < f.max) hpBar(p, f.x - f.size * .4, f.y - f.size * .6, f.size * .8, 6, f.hp, f.max);
    }
    for (final s in shots) {
      p.draw(s.t.t.shot, s.x, s.y, 22, rot: t * 10);
    }
    for (var i = 0; i < selBtns.length; i++) {
      final b = selBtns[i], T = _towers[i];
      p.rrect(b.x - bw / 2, b.y - bh / 2, bw, bh, 14, i == sel ? hx(0xffd43b) : const Color(0xEBFFFFFF));
      p.rrectStroke(b.x - bw / 2, b.y - bh / 2, bw, bh, 14, hx(0xf06595), i == sel ? 4 : 2);
      p.draw(T.img, b.x - bw * .3, b.y, 38);
      p.text(T.vi, b.x - bw * .1, b.y - 4, size: 15, color: hx(0x212529), align: 'left');
      p.text('${T.cost} 🍬', b.x - bw * .1, b.y + 16, size: 15, color: hx(0x212529), align: 'left');
    }
    p.rrect(W - 118, 62, 106, 40, 20, const Color(0x4D000000));
    p.draw('Candy', W - 94, 82, 28);
    p.text('$candy', W - 74, 91, size: 22, align: 'left');
    if (breakT > 0 && G.introT <= 0) {
      p.rect(0, H / 2 - 34, W, 68, const Color(0x4D000000));
      final s = G.Z.boss && wave == NW - 1 ? 'Đợt cuối: Nhện Kẹo!' : 'Đợt ${wave + 1} sắp tới · đặt lính đi!';
      var size = 32.0;
      while (size > 14 && p.measure(s, size) > W - 20) {
        size -= 2;
      }
      p.text(s, W / 2, H / 2 + 11, size: size);
    }
    final bs = foes.where((f) => f.boss).firstOrNull;
    if (bs != null) bossBar(p, W, H - 80, bs.hp, bs.max, bs.name);
  }

  @override
  bool done() => won;
  @override
  String? goal() => '🎂 Đợt ${math.min(wave + 1, NW)}/$NW';
}

final ZoneDef candy = ZoneDef(
  ['Ant', 'Lady beetle', 'Cockroach', 'Spider', 'Birthday cake', 'Candy', 'Lollipop', 'Ice cream', 'Doughnut', 'Snowflake', 'Cookie', 'Mushroom'],
  (Z, art, W, H, AudioService audio) => Shell(
      Z,
      art,
      W,
      H,
      audio,
      ShellCfg(
          name: 'Rừng Kẹo',
          goalText: Z.boss ? 'Giữ bánh, đánh bại Nhện Kẹo' : 'Giữ bánh qua ${3 + Z.s ~/ 2} đợt sâu bọ',
          hint: 'Chọn lính ở dưới rồi chạm ô tròn để đặt · chạm lính để nâng cấp',
          noPotion: true,
          hp: 10),
      (G) => _Candy(G)),
);

// ---------- 8. Núi Lửa: chạy nhảy qua dung nham, chém thằn lằn, tới cờ; trùm Khủng Long Dung Nham ----------
class _Plat {
  _Plat(this.x, this.y, this.w, {this.float = false});
  final double x, y, w;
  final bool float;
}

class _Lava {
  _Lava(this.x, this.w, this.ft);
  final double x, w;
  double ft;
}

class _Lizard extends Mob {
  _Lizard(double x, double y, this.x0, this.x1, ({double hp, double dmg}) s)
      : hp = s.hp,
        max = s.hp,
        dmg = s.dmg,
        super(x: x, y: y);
  final double x0, x1;
  double hp, max, dmg, dir = 1;
  bool dead = false;
  final Mob v = Mob(img: 'Lizard');
}

class _Fireball extends XY {
  _Fireball(super.x, super.y, this.vy, {this.vx = 0, this.warn = 0, this.arc = false});
  double vy, vx, warn;
  final bool arc;
  bool dead = false;
}

class _Coin extends XY {
  _Coin(super.x, super.y);
  bool got = false;
}

class _Volcano extends ShellGame {
  _Volcano(this.G) {
    final Z = G.Z, W = G.W, H = G.H, S = G.S;
    gy = H * .8;
    grav = S * 3;
    jv = S * 1.35;
    sp = S * .5 * Z.st.spd;
    hs = S * .12;
    final len = Z.boss ? W * 1.6 : W * (2.6 + Z.s * .5);
    plats.add(_Plat(-200, gy, W * .6 + 200));
    var x = W * .6;
    while (x < len - W * .5) {
      final gap = S * rand(.12, .2 + Z.s * .012);
      lavas.add(_Lava(x, gap, rand(1, 3)));
      x += gap;
      final w = S * rand(.35, .7);
      final y = gy - (rnd.nextDouble() < .35 ? S * rand(.06, .14) : 0);
      plats.add(_Plat(x, y, w));
      if (w > S * .5 && rnd.nextDouble() < .4 + Z.s * .08) lizards.add(_Lizard(x + w / 2, y, x + 20, x + w - 20, foeStats(7, Z.s)));
      if (rnd.nextDouble() < .5) plats.add(_Plat(x + w * .2, y - S * .3, S * .2, float: true));
      for (var i = 0; i < 3; i++) {
        coins.add(_Coin(x + w * (.25 + i * .25), y - S * .12));
      }
      x += w;
    }
    plats.add(_Plat(x, gy, W * 1.2));
    flagX = Z.boss ? x + W * .9 : x + S * .4;
    if (Z.boss) {
      final s = foeStats(7, 5, 10);
      boss = _Lizard(x + W * .7, gy, 0, 0, s)
        ..dir = -1
        ..size = S * .3;
      bossCd = 2;
    }
    me = XY(60, gy);
    safe = 60;
    br = math.min(52, S * .085);
    final by = H - br - 16;
    B = Buttons(G.M, [
      Btn('l', br + 16, by, br, '◀'),
      Btn('r', br * 3.4 + 16, by, br, '▶'),
      Btn('j', W - br - 16, by, br * 1.1, '⬆', c: hx(0x4dabf7)),
      Btn('a', W - br * 3.5 - 16, by, br, '⚔️', c: hx(0xff922b)),
    ]);
  }
  final Shell G;
  late double gy, grav, jv, sp, hs, flagX, br, safe;
  final List<_Plat> plats = [];
  final List<_Lava> lavas = [];
  final List<_Lizard> lizards = [];
  final List<_Coin> coins = [];
  final List<_Fireball> fireballs = [];
  _Lizard? boss;
  double bossCd = 0, bossVy = 0, bossAtkT = 0, bossT = 0;
  bool bossJumped = false;
  final Mob bossView = Mob(img: 'T-Rex');
  late XY me;
  double vy = 0, swing = 0, cam = 0, atkCd = 0;
  bool ground = true, won = false;
  int face = 1;
  late Buttons B;

  bool K(String k) => G.keys.contains(k);
  _Plat? _groundAt(double px, double py, double vy) {
    for (final p in plats) {
      if (px > p.x - 10 && px < p.x + p.w + 10 && py >= p.y - 2 && py - vy * .02 <= p.y + 14) return p;
    }
    return null;
  }

  @override
  void update(double dt) {
    final Z = G.Z, W = G.W, S = G.S, F = G.F, hero = G.hero;
    swing = math.max(0, swing - dt);
    atkCd -= dt;
    final dir = (B.down('r') || K('arrowright') || K('d') ? 1 : 0) - (B.down('l') || K('arrowleft') || K('a') ? 1 : 0);
    me.x += dir * sp * dt;
    if (dir != 0) face = dir;
    me.x = math.max(20, me.x);
    final b = boss;
    if (b != null && !b.dead) me.x = math.min(me.x, b.x + W * .4);
    if ((B.hit('j') || K('arrowup') || K('w') || K(' ')) && ground) {
      vy = -jv;
      ground = false;
      G.sfx('jump');
    }
    vy += grav * dt;
    me.y += vy * dt;
    final p = vy >= 0 ? _groundAt(me.x, me.y, vy) : null;
    if (p != null) {
      if (!ground && vy > S * .8) G.FB.dust(me.x - cam, p.y, 5);
      me.y = p.y;
      vy = 0;
      ground = true;
      if (!p.float) safe = math.min(math.max(p.x + 30, me.x), p.x + p.w - 30);
    } else {
      ground = false;
    }
    if (me.y > gy + S * .12) {
      G.hurt((hero.max * .12).roundToDouble(), me.x - cam, gy, true);
      hero.inv = 1.5;
      me.x = safe;
      me.y = gy - S * .4;
      vy = 0;
      G.sfx('wrong');
    }
    if (B.hit('a') && atkCd <= 0) {
      atkCd = .3;
      swing = .25;
      G.sfx('flip');
      G.FB.slash(me.x - cam + face * hs * .2, me.y - hs * .5, hs * .7, face > 0 ? 0 : pi, face.toDouble());
      final tg = [...lizards.where((l) => !l.dead), if (b != null && !b.dead) b];
      for (final l in tg) {
        final isB = l == b;
        if ((l.x - (me.x + face * hs * .5)).abs() < hs * (isB ? 1.6 : 1) && (l.y - me.y).abs() < hs * 1.2) {
          final s = strike(Z.st);
          l.hp -= s.d;
          l.hurt = .2;
          G.sfx('hit');
          l.x += face * 14;
          G.num(l.x - cam, l.y - hs, s.d, s.crit);
          if (l.hp <= 0) {
            l.dead = true;
            G.die(isB
                ? Mob(img: 'T-Rex', x: l.x - cam, y: l.y - b!.size * .45, size: b.size, flip: b.dir > 0, boss: true)
                : Mob(img: 'Lizard', sheet: 'kenney-platformer/enemies', anim: 'slime_fire', x: l.x - cam, y: l.y - hs * .4, size: hs * .9, flip: l.dir > 0));
            G.kill(isB);
            F.burst(l.x - cam, l.y - hs / 2, isB ? 40 : 14);
            G.loot((2 + Z.r * 3) * (isB ? 15 : 1), l.x - cam, l.y - hs);
            G.sfx(isB ? 'boom' : 'pop');
          }
        }
      }
    }
    for (final l in lizards) {
      if (l.dead) continue;
      l.t += dt;
      l.hurt = math.max(0, l.hurt - dt);
      l.x += l.dir * S * .1 * dt;
      if (l.x < l.x0 || l.x > l.x1) l.dir *= -1;
      if ((l.x - me.x).abs() < hs * .6 && (l.y - me.y).abs() < hs * .5 && hero.inv <= 0) G.hurt(l.dmg, me.x - cam, me.y - hs);
    }
    for (final lv in lavas) {
      lv.ft -= dt;
      if (lv.ft <= 0) {
        lv.ft = rand(2.2, 3.6) - Z.s * .15;
        fireballs.add(_Fireball(lv.x + lv.w / 2, gy + 30, -S * rand(1.1, 1.4), warn: .6));
      }
    }
    for (final f in fireballs) {
      if (f.warn > 0) {
        f.warn -= dt;
        continue;
      }
      f.vy += grav * .8 * dt;
      f.y += f.vy * dt;
      if (hero.inv <= 0 && hypot(f.x - me.x, f.y - (me.y - hs / 2)) < hs * .55) {
        f.dead = true;
        G.hurt(foeStats(7, Z.s).dmg, me.x - cam, me.y - hs);
      }
      if (f.y > gy + 60 && f.vy > 0) f.dead = true;
    }
    fireballs.removeWhere((f) => f.dead);
    for (final c in coins) {
      if (!c.got && (c.x - me.x).abs() < hs * .5 && (c.y - (me.y - hs / 2)).abs() < hs * .6) {
        c.got = true;
        G.loot(1.0 + Z.r, c.x - cam, c.y);
      }
    }
    if (b != null && !b.dead) {
      b.hurt = math.max(0, b.hurt - dt);
      bossCd -= dt;
      bossAtkT = math.max(0, bossAtkT - dt);
      bossT += dt;
      bossVy += grav * dt;
      b.y = math.min(gy, b.y + bossVy * dt);
      if (b.y >= gy) {
        bossVy = 0;
        if (bossJumped) {
          bossJumped = false;
          G.C.shake(10);
          G.FB.dust(b.x - cam, gy, 10);
          G.sfx('boom');
        }
      }
      b.dir = me.x < b.x ? -1 : 1;
      b.x += b.dir * S * .08 * dt;
      if (bossCd <= 0) {
        bossCd = b.hp < b.max / 2 ? 1.6 : 2.3;
        bossAtkT = .35;
        if (rnd.nextDouble() < .5) {
          bossVy = -S * 1.1;
          bossJumped = true;
        } else {
          for (final k in [-1, 0, 1]) {
            fireballs.add(_Fireball(b.x, b.y - b.size * .6, -S * (.9 + k * .15), vx: b.dir * S * (.35 + k * .1), arc: true));
          }
          G.sfx('boom');
        }
      }
      if ((b.x - me.x).abs() < b.size * .4 && me.y > b.y - b.size * .7 && hero.inv <= 0) G.hurt(b.dmg, me.x - cam, me.y - hs);
    }
    for (final f in fireballs) {
      if (f.arc) f.x += f.vx * dt;
    }
    cam += (clamp(me.x - W * .35, 0, math.max(0, flagX + W * .3 - W)) - cam) * math.min(1, dt * 6);
    if (!Z.boss && me.x >= flagX) won = true;
    if (b != null && b.dead) won = true;
  }

  @override
  void draw(Pen p) {
    final W = G.W, H = G.H, S = G.S, t = G.t, Z = G.Z, c = p.c;
    p.vgrad(W, H, [hx(0xc92a2a), hx(0xffc078)]);
    for (var i = 0; i < 4; i++) {
      p.draw('Volcano', ((i * W * .45 - cam * .3) % (W * 1.8) + W * 1.8) % (W * 1.8) - W * .2, gy - S * .25, S * .5, alpha: .5);
    }
    c.save();
    c.translate(-cam, 0);
    final TL = G.sp('kenney-platformer/tiles'), EN = G.sp('kenney-platformer/enemies'), ts = (S * .085).roundToDouble(), okT = TL?.image != null;
    // Dung nham: dải sóng lava Kenney trôi ngang + bọt nổi
    p.rect(cam, gy + 10, W, H, hx(0xff6b00));
    if (okT) {
      final x0 = (cam / ts).floor() * ts - ts + (t * 25) % ts;
      for (var x = x0; x < cam + W + ts; x += ts) {
        p.spr(TL, 'lava_top', x + ts / 2, gy + 10 + ts / 2, ts);
        for (var y = gy + 10 + ts; y < H; y += ts) {
          p.spr(TL, 'lava', x + ts / 2, y + ts / 2, ts);
        }
      }
    }
    for (var i = 0; i < 20; i++) {
      p.circle(cam + (i * 97 + t * 30) % W, gy + 26 + math.sin(t * 3 + i) * 6, 5, const Color(0xB3FFE066));
    }
    // Nền đá: ô đất Kenney (mặt trên + thân), bục nổi là mây đá
    for (final pl in plats) {
      if (pl.x > cam + W || pl.x + pl.w < cam) continue;
      if (!okT) {
        p.rrect(pl.x, pl.y, pl.w, pl.float ? 18 : H - pl.y, 8, hx(0x5c3d2e));
        p.rect(pl.x, pl.y, pl.w, 8, hx(0x8d6e63));
        continue;
      }
      c.save();
      c.clipRect(Rect.fromLTWH(pl.x, pl.y - ts, pl.w, H));
      final n = (pl.w / ts).ceil();
      for (var i = 0; i < n; i++) {
        final x = pl.x + i * ts + ts / 2;
        if (x < cam - ts || x > cam + W + ts) continue;
        if (pl.float) {
          p.spr(TL, n == 1 ? 'terrain_stone_cloud_middle' : (i == 0 ? 'terrain_stone_cloud_left' : (i == n - 1 ? 'terrain_stone_cloud_right' : 'terrain_stone_cloud_middle')), x,
              pl.y + ts / 2 - 4, ts);
        } else {
          p.spr(TL, 'terrain_dirt_block_top', x, pl.y + ts / 2, ts);
          for (var y = pl.y + ts; y < H; y += ts) {
            p.spr(TL, 'terrain_dirt_block_center', x, y + ts / 2, ts);
          }
        }
      }
      c.restore();
    }
    for (final co in coins) {
      if (!co.got && co.x > cam - 40 && co.x < cam + W + 40) drawCoin(p, co.x, co.y + math.sin(t * 4 + co.x) * 3, 28, t + co.x * .01);
    }
    for (final l in lizards) {
      if (l.dead) continue;
      l.v
        ..x = l.x
        ..y = l.y - hs * .4
        ..size = hs * .9
        ..t = l.t
        ..hurt = math.min(.15, l.hurt)
        ..flip = l.dir > 0
        ..moving = true;
      drawMob(p, l.v, sheet: EN, anim: EN != null ? 'slime_fire' : null);
      if (l.hp < l.max) hpBar(p, l.x - hs * .4, l.y - hs * .9, hs * .8, 7, l.hp, l.max);
    }
    for (final f in fireballs) {
      if (f.warn > 0) {
        p.circle(f.x, gy + 14 + math.sin(t * 30) * 3, 10, const Color(0xB3FFFFFF));
        continue;
      }
      final a = math.atan2(f.vy, f.vx);
      if (!p.spr(TL, 'fireball', f.x, f.y, hs * .55, rot: a + pi)) p.draw('Fire', f.x, f.y, hs * .6, rot: f.vy > 0 ? pi : 0);
    }
    final b = boss;
    if (!Z.boss || (b != null && b.dead)) {
      if (!p.sprA(TL, 'flag_green', t, flagX, gy - S * .08, S * .18)) p.draw('Chequered flag', flagX, gy - S * .1, S * .16);
    }
    if (b != null && !b.dead) {
      bossView
        ..x = b.x
        ..y = b.y - b.size * .45
        ..size = b.size
        ..t = bossT
        ..hurt = math.min(.15, b.hurt)
        ..flip = b.dir > 0
        ..moving = bossVy == 0
        ..atk = bossAtkT > 0 ? 1 - bossAtkT / .35 : 0;
      drawMob(p, bossView);
      p.draw('Crown', b.x, b.y - b.size * 1.0, b.size * .25);
    }
    final moving = ground && (B.down('l') || B.down('r') || K('arrowleft') || K('arrowright'));
    drawHero(p, me.x, me.y - hs * .45, hs, Z, face: face, swing: swing, hurt: G.hero.inv, t: t, moving: moving, pose: !ground && !(swing > 0) ? 'jump' : null);
    c.restore();
    if (!Z.boss) {
      final k = clamp(me.x / flagX, 0, 1), pw = math.min(300.0, W * .4), py = W < 700 ? 112.0 : 66.0;
      p.rrect(W / 2 - pw / 2, py, pw, 16, 8, const Color(0x4D000000));
      p.rrect(W / 2 - pw / 2 + 2, py + 2, (pw - 4) * k, 12, 6, hx(0xffd43b));
      p.draw('Chequered flag', W / 2 + pw / 2 + 14, py + 8, 24);
    }
    if (b != null && !b.dead) bossBar(p, W, H, b.hp, b.max, 'Khủng Long Dung Nham', W < 700 ? 132 : 90);
    B.draw(p);
  }

  @override
  bool done() => won;
  @override
  String? goal() => null;
}

final ZoneDef volcano = ZoneDef(
  ['Lizard', 'Fire', 'T-Rex', 'Chequered flag', 'Volcano', 'Rock', 'Coin', 'Crown'],
  (Z, art, W, H, AudioService audio) => Shell(
      Z,
      art,
      W,
      H,
      audio,
      ShellCfg(
          name: 'Núi Lửa',
          goalText: Z.boss ? 'Đánh bại Khủng Long Dung Nham' : 'Vượt dung nham tới lá cờ 🏁',
          hint: '◀ ▶ để chạy · ⬆ để nhảy · ⚔️ để chém · rơi vào lửa sẽ mất máu'),
      (G) => _Volcano(G)),
);
