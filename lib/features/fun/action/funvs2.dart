// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api, constant_identifier_names
// Đối kháng 2: ném tuyết, mô tô ánh sáng, sumo, cờ caro, nối bốn.
// CHỦ: agent G. Port của web js/games/funvs2.js.
// Tường tuyết bằng khối tuyết Kenney, bóng tuyết có bóng đổ + vỡ tung; mô tô Kenney chạy mượt giữa các ô, nổ khi đâm;
// sumo nhìn nghiêng 2.5D trên võ đài đất; cờ caro/nối bốn dùng quân cờ (chip) Kenney rơi có nảy.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'vs_core.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funvs2Games = {
  'snowball': VsModule('snowball', '☃️ Ném tuyết', (lv) => ['Snowman', 'Evergreen tree', 'Snowflake', 'Glowing star', 'Snow-capped mountain'], SnowballGame.new,
      sheets: ['kenney-platformer/tiles']),
  'tron': VsModule('tron', '🏍️ Mô tô ánh sáng', (lv) => ['Glowing star'], TronGame.new, sheets: ['kenney-racing/moto', 'kenney-pirate/ships']),
  'sumo': VsModule('sumo', '🤼 Đấu sumo', (lv) => ['Glowing star'], SumoGame.new),
  'caro': VsModule('caro', '❌⭕ Cờ caro', (lv) => ['Glowing star'], CaroGame.new, sheets: ['kenney-board/chips']),
  'connect4': VsModule('connect4', '🔴🟡 Nối bốn', (lv) => ['Glowing star'], Connect4Game.new, sheets: ['kenney-board/chips']),
};

// ---------- 6. Ném tuyết: kéo ngược rồi thả để ném theo đường cong, trúng đối thủ được điểm ----------
class _SnowP {
  _SnowP(this.x) : hx = x;
  double x, hx, cd = 0, hurt = 0, thr = 9;
}

class _Wall {
  _Wall(this.x, this.h, this.hp) : max = hp;
  final double x, h;
  int hp;
  final int max;
  double sh = 0;
}

class _Snow {
  _Snow(this.x, this.y, this.vx, this.vy, this.k);
  double x, y, vx, vy, rot = 0;
  final int k;
}

class SnowballGame extends VsGame {
  SnowballGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const need = 5;
  late final SpriteSheet? TL = gfx.sh('kenney-platformer/tiles');
  late double ground, G, pw, bs, aiErr, aiRate;
  late List<_SnowP> P;
  final List<_Wall> walls = [];
  final List<_Snow> balls = [];
  final List<(double, double, double, double)> flakes = [];
  int a = 0, b = 0, winner = 0;
  double t = 0, endT = 0, aiT = 1.5;
  VsEnd? end;
  late Prerendered bg;

  @override
  void setup() {
    ground = H * .8;
    G = S * 1.6;
    P = [_SnowP(W * .1), _SnowP(W * .9)];
    pw = S * .15;
    bs = math.max(26, S * .055);
    walls.addAll([_Wall(W * .24, S * .16, 6), _Wall(W * .76, S * .16, 6)]);
    if (lv >= 15) walls.add(_Wall(W / 2, S * ramp(lv, .12, .3), 99));
    for (var i = 0; i < 40; i++) {
      flakes.add((rnd(0, W), rnd(0, H), rnd(20, 60), rnd(1.5, 3.5)));
    }
    aiErr = ramp(lv, .3, .05);
    aiRate = ramp(lv, 2.6, 1.1);
    bg = prerender((g) {
      g.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [hex(0x74c0fc), hex(0xf1f3f5)]).createShader(Rect.fromLTWH(0, 0, W, H)));
      gfx.draw(g, 'Snow-capped mountain', W * .3, ground - S * .22, S * .5, S * .5, false, 0, .7);
      gfx.draw(g, 'Snow-capped mountain', W * .72, ground - S * .26, S * .6, S * .6, false, 0, .7);
      gfx.draw(g, 'Evergreen tree', W * .38, ground - S * .12, S * .26, S * .26, false, 0, .8);
      gfx.draw(g, 'Evergreen tree', W * .62, ground - S * .14, S * .3, S * .3, false, 0, .8);
      gfx.draw(g, 'Snowman', W * .5, ground - S * .09, S * .18, S * .18);
      rect(g, 0, ground, W, H - ground, Colors.white);
      for (var i = 0; i < 9; i++) {
        ellipse(g, (i * 131) % W, ground + 18 + (i % 3) * 22, 60, 10, hex(0xe7f5ff));
      }
    });
  }

  void throwFrom(int k, double vx, double vy) {
    final p = P[k];
    if (p.cd > 0) return;
    p.cd = .7;
    p.thr = 0;
    balls.add(_Snow(p.x + (k > 0 ? -1 : 1) * pw * .4, ground - pw * .9, vx, vy, k));
    sfx('shoot');
  }

  @override
  void up(Ptr p) {
    if (end != null || t < 2.4) return;
    final k = p.sx < W / 2 ? 0 : 1;
    if (k == 1 && !pvp) return;
    final dx = p.sx - p.x, dy = p.sy - p.y, d = hypot(dx, dy);
    if (d < 20) return;
    final pow = math.min(1, d / (S * .35)) * S * 1.6;
    throwFrom(k, dx / d * pow, dy / d * pow);
  }

  void splat(double x, double y) {
    F.burst(x, y, 12, [0xffffff, 0xe7f5ff, 0xd0ebff], 220, 600);
    F.ring(x, y, 26, 0xffffff, 5);
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    decay(pops, rdt);
    for (var i = 0; i < flakes.length; i++) {
      final f = flakes[i];
      var y = f.$2 + f.$3 * dt, x = f.$1 + math.sin(t + f.$3) * 10 * dt;
      if (y > H) {
        y = -5;
        x = rnd(0, W);
      }
      flakes[i] = (x, y, f.$3, f.$4);
    }
    for (final w in walls) {
      w.sh = math.max(0, w.sh - dt);
    }
    for (final p in P) {
      p.cd = math.max(0, p.cd - dt);
      p.hurt = math.max(0, p.hurt - dt);
      p.thr += dt;
      p.x = approach(p.x, p.hx, 5, dt);
    }
    if (end != null) {
      endT += rdt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    if (!pvp) {
      aiT -= dt;
      if (aiT <= 0) {
        aiT = aiRate * rnd(.8, 1.2);
        final dx = P[0].x - P[1].x, ang = -math.pi / 4 - rnd(0, .25);
        final v = math.sqrt(dx.abs() * G / math.sin(-2 * ang)) * (1 + rnd(-aiErr, aiErr));
        throwFrom(1, -math.cos(ang) * v, math.sin(ang) * v);
      }
    }
    for (var i = balls.length - 1; i >= 0; i--) {
      final s = balls[i];
      s.vy += G * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.rot += s.vx * dt * .02;
      if (s.y > ground || s.x < -20 || s.x > W + 20) {
        if (s.y > ground) splat(s.x, ground);
        balls.removeAt(i);
        continue;
      }
      final w = walls.where((w) => w.hp > 0 && (s.x - w.x).abs() < bs * .6 && s.y > ground - w.h * (w.hp / w.max * .5 + .5)).firstOrNull;
      if (w != null) {
        balls.removeAt(i);
        splat(s.x, s.y);
        sfx('pop');
        w.hp--;
        w.sh = .25;
        C.shake(2);
        continue;
      }
      final o = P[1 - s.k];
      if ((s.x - o.x).abs() < pw * .45 && s.y > ground - pw * 1.1) {
        balls.removeAt(i);
        o.hurt = .5;
        o.x += (s.k > 0 ? -1 : 1) * pw * .35;
        sfx('hit');
        splat(s.x, s.y);
        C.shake(5);
        C.stop(.06);
        if (s.k == 0) {
          a++;
          pops[0] = 1;
        } else {
          b++;
          pops[1] = 1;
        }
        F.text(o.x, ground - pw * 1.3, 'TRÚNG!', s.k == 0 ? 0x74c0fc : 0xff8787, 30);
        if (a >= need || b >= need) {
          winner = a >= need ? 1 : 2;
          end = VsEnd(winner, a * 5);
        }
      }
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    C.begin(c);
    for (final w in walls) {
      if (w.hp <= 0) continue;
      final n = math.max(1, (w.h / bs * (w.hp >= 99 ? 1 : .5 + .5 * w.hp / w.max)).round()), jx = math.sin(t * 60) * w.sh * 10;
      for (var i = 0; i < n; i++) {
        if (!gfx.spr(c, TL, i == n - 1 ? 'terrain_snow_block_top' : 'terrain_snow_block_center', w.x + jx, ground - bs * (i + .5), bs)) {
          rect(c, w.x - bs / 2, ground - bs * (i + 1), bs, bs, hex(0xe7f5ff));
        }
      }
    }
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      final aiming = pts.values.any((q) => (q.sx < W / 2 ? 0 : 1) == k && hypot(q.x - q.sx, q.y - q.sy) > 20);
      final ta = p.thr / .35;
      final pose = end != null ? (winner == k + 1 ? 'cheer' : 'hurt') : (p.hurt > 0 ? 'hurt' : (aiming || ta < 1 ? 'throw' : 'idle'));
      drawFigure(c, p.x, ground, pw * 1.25, COS[k], pose: pose, act: aiming ? 0 : outCubic(ta), t: t + k, face: k > 0 ? -1 : 1, team: k > 0 ? kRed : kBlue);
    }
    for (final p in pts.values) {
      final k = p.sx < W / 2 ? 0 : 1;
      if (k == 1 && !pvp) continue;
      final dx = p.sx - p.x, dy = p.sy - p.y, d = hypot(dx, dy);
      if (d < 20) continue;
      final pow = math.min(1, d / (S * .35)) * S * 1.6;
      var x = P[k].x + (k > 0 ? -1 : 1) * pw * .4, y = ground - pw * .9, vx = dx / d * pow, vy = dy / d * pow;
      final col = k > 0 ? rgba(250, 82, 82, .7) : rgba(51, 154, 240, .7);
      for (var i = 0; i < 14; i++) {
        for (var j = 0; j < 3; j++) {
          vy += G * .016;
          x += vx * .016;
          y += vy * .016;
        }
        circle(c, x, y, 5 - i * .25, col);
      }
    }
    for (final s in balls) {
      shadow(c, s.x, ground + 3, 10, ground - s.y, .18);
      circle(c, s.x - s.vx * .02, s.y - s.vy * .02, 8, rgba(255, 255, 255, .35));
      c.drawCircle(Offset(s.x, s.y), 11, Paint()..shader = RadialGradient(center: const Alignment(-.36, -.36), radius: 1, colors: [Colors.white, hex(0xa5d8ff)]).createShader(Rect.fromCircle(center: Offset(s.x, s.y), radius: 11)));
    }
    F.draw(c);
    C.end(c);
    for (final f in flakes) {
      circle(c, f.$1, f.$2, f.$4, Colors.white);
    }
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Ném trúng $need lần trước', 'Kéo ngón tay ngược ra sau rồi thả để ném');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}

// ---------- 7. Mô tô ánh sáng: xe để lại vệt sáng, ai đâm vào vệt hay tường trước là thua ván ----------
class _Bike {
  _Bike(this.x, this.y, this.dir, this.ang)
      : px = x,
        py = y,
        next = dir;
  int x, y, px, py;
  String dir, next;
  double ang;
  bool dead = false;
}

class TronGame extends VsGame {
  TronGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const need = 3;
  static const Map<String, (int, int)> D = {'u': (0, -1), 'd': (0, 1), 'l': (-1, 0), 'r': (1, 0)};
  static const Map<String, String> OPP = {'u': 'd', 'd': 'u', 'l': 'r', 'r': 'l'};
  static const Map<String, double> ANG = {'u': 0, 'r': math.pi / 2, 'd': math.pi, 'l': -math.pi / 2};
  late final SpriteSheet? MOTO = gfx.sh('kenney-racing/moto'), BOOM = gfx.sh('kenney-pirate/ships');
  late double cs, ox, oy, speed;
  late int cols, rows, look;
  late double aiMiss;
  static const top = 96.0;
  late List<List<int>> grid;
  late List<_Bike> P;
  int a = 0, b = 0, winner = 0;
  double t = 0, stepT = 0, endT = 0, roundOver = 0;
  final List<(double, double, double)> booms = [];
  VsEnd? end;
  late Prerendered bg;
  // Vệt sáng: các hình chữ nhật đã tô (màu ngoài + lõi sáng), ghi lại thành Picture khi đổi
  final List<(Rect, Rect, int)> _trail = [];
  ui.Picture? _trailPic;
  bool _dirty = true;

  @override
  void setup() {
    cs = math.max(10, (S / 34).floorToDouble());
    cols = ((W - 20) / cs).floor();
    rows = ((H - top - 10) / cs).floor();
    ox = (W - cols * cs) / 2;
    oy = top;
    look = ramp(lv, 12, 160).round();
    aiMiss = ramp(lv, .25, 0);
    speed = ramp(lv, .11, .055);
    bg = prerender((g) {
      rect(g, 0, 0, W, H, hex(0x0b1026));
      final ls = strokeP(rgba(116, 192, 252, .12), 1);
      for (var x = 0; x <= cols; x++) {
        g.drawLine(Offset(ox + x * cs, oy), Offset(ox + x * cs, oy + rows * cs), ls);
      }
      for (var y = 0; y <= rows; y++) {
        g.drawLine(Offset(ox, oy + y * cs), Offset(ox + cols * cs, oy + y * cs), ls);
      }
      g.drawRect(Rect.fromLTWH(ox, oy, cols * cs, rows * cs), strokeP(hex(0x74c0fc), 3));
    });
    reset();
  }

  void paintCell(int x, int y, int k, [int? px, int? py]) {
    final x0 = math.min(x, px ?? x), y0 = math.min(y, py ?? y), x1 = math.max(x, px ?? x), y1 = math.max(y, py ?? y);
    _trail.add((
      Rect.fromLTWH(ox + x0 * cs + cs * .25, oy + y0 * cs + cs * .25, (x1 - x0 + .5) * cs, (y1 - y0 + .5) * cs),
      Rect.fromLTWH(ox + (x0 + .42) * cs, oy + (y0 + .42) * cs, (x1 - x0 + .16) * cs, (y1 - y0 + .16) * cs),
      k,
    ));
    _dirty = true;
  }

  void reset() {
    grid = List.generate(rows, (_) => List.filled(cols, 0));
    _trail.clear();
    _dirty = true;
    final my = rows ~/ 2;
    P = [_Bike(3, my, 'r', ANG['r']!), _Bike(cols - 4, my, 'l', ANG['l']!)];
    for (var k = 0; k < 2; k++) {
      grid[P[k].y][P[k].x] = k + 1;
      paintCell(P[k].x, P[k].y, k);
    }
    roundOver = 0;
    stepT = 0;
  }

  @override
  void up(Ptr p) {
    final k = p.sx < W / 2 ? 0 : 1;
    if (k == 1 && !pvp) return;
    final dx = p.x - p.sx, dy = p.y - p.sy;
    if (hypot(dx, dy) < 18) return;
    final d = dx.abs() > dy.abs() ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u');
    if (d != OPP[P[k].dir]) {
      P[k].next = d;
      sfx('tap');
    }
  }

  bool free(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows && grid[y][x] == 0;
  int space(int x, int y, int lim) {
    final seen = <int>{y * cols + x};
    final q = <(int, int)>[(x, y)];
    var qi = 0;
    while (qi < q.length && seen.length < lim) {
      final (cx, cy) = q[qi++];
      for (final dv in D.values) {
        final nx = cx + dv.$1, ny = cy + dv.$2, k2 = ny * cols + nx;
        if (free(nx, ny) && !seen.contains(k2)) {
          seen.add(k2);
          q.add((nx, ny));
        }
      }
    }
    return seen.length;
  }

  double cxOf(_Bike p) => ox + (p.px + (p.x - p.px) * math.min(1, stepT / speed) + .5) * cs;
  double cyOf(_Bike p) => oy + (p.py + (p.y - p.py) * math.min(1, stepT / speed) + .5) * cs;

  @override
  Object? step(double dt) {
    t += dt;
    C.update(dt);
    F.update(dt);
    decay(pops, dt);
    for (var i = booms.length - 1; i >= 0; i--) {
      final bm = booms[i];
      if (bm.$3 + dt >= .6) {
        booms.removeAt(i);
      } else {
        booms[i] = (bm.$1, bm.$2, bm.$3 + dt);
      }
    }
    for (final p in P) {
      p.ang += angDiff(ANG[p.dir]!, p.ang) * math.min(1, dt * 18);
    }
    if (end != null) {
      endT += dt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    if (roundOver > 0) {
      roundOver -= dt;
      if (roundOver <= 0) reset();
      return null;
    }
    stepT += dt;
    if (stepT < speed) return null;
    stepT = 0;
    if (!pvp) {
      final p = P[1];
      if (rnd01() >= aiMiss) {
        final opts = D.keys.where((d) => d != OPP[p.dir] && free(p.x + D[d]!.$1, p.y + D[d]!.$2)).toList();
        if (opts.isNotEmpty) {
          var best = opts.first;
          var bs = -1.0;
          for (final d in opts) {
            final sc = space(p.x + D[d]!.$1, p.y + D[d]!.$2, look) + (d == p.dir ? 2 : 0) + rnd(0, 1.5);
            if (sc > bs) {
              bs = sc;
              best = d;
            }
          }
          p.next = best;
        }
      }
    }
    for (final p in P) {
      p.px = p.x;
      p.py = p.y;
      p.dir = p.next;
      p.x += D[p.dir]!.$1;
      p.y += D[p.dir]!.$2;
    }
    final same = P[0].x == P[1].x && P[0].y == P[1].y;
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      if (same || !free(p.x, p.y)) {
        p.dead = true;
        final X = ox + (p.px + .5) * cs, Y = oy + (p.py + .5) * cs;
        F.burst(X, Y, 26, [k > 0 ? 0xfa5252 : 0x339af0, 0xffffff, 0xffd43b], 320);
        F.ring(X, Y, cs * 4, k > 0 ? 0xff8787 : 0x74c0fc, 6);
        booms.add((X, Y, 0));
      } else {
        grid[p.y][p.x] = k + 1;
        paintCell(p.x, p.y, k, p.px, p.py);
      }
    }
    if (P[0].dead || P[1].dead) {
      sfx('boom');
      C.shake(12);
      stepT = speed;
      if (P[0].dead && !P[1].dead) {
        b++;
        pops[1] = 1;
      } else if (P[1].dead && !P[0].dead) {
        a++;
        pops[0] = 1;
      }
      if (a >= need || b >= need) {
        winner = a >= need ? 1 : 2;
        end = VsEnd(winner, a * 5);
      } else {
        roundOver = 1.4;
      }
    }
    return null;
  }

  ui.Picture _trailPicture() {
    if (_dirty || _trailPic == null) {
      _trailPic?.dispose();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final outer = [Paint()..color = rgba(77, 171, 247, .9), Paint()..color = rgba(255, 107, 107, .9)];
      final inner = [Paint()..color = hex(0xe7f5ff), Paint()..color = hex(0xffe3e3)];
      for (final r in _trail) {
        c.drawRect(r.$1, outer[r.$3]);
      }
      for (final r in _trail) {
        c.drawRect(r.$2, inner[r.$3]);
      }
      _trailPic = rec.endRecording();
      _dirty = false;
    }
    return _trailPic!;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    C.begin(c);
    final pic = _trailPicture();
    c.saveLayer(Rect.fromLTWH(0, 0, W, H), Paint()
      ..blendMode = BlendMode.plus
      ..color = Color.fromRGBO(0, 0, 0, .35 + math.sin(t * 6) * .08));
    c.translate(-2, -2);
    c.scale((W + 4) / W, (H + 4) / H);
    c.drawPicture(pic);
    c.restore();
    c.drawPicture(pic);
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      if (p.dead) continue;
      final x = cxOf(p), y = cyOf(p), hgt = cs * 3.2;
      circle(c, x, y, cs * 1.6, k > 0 ? rgba(255, 107, 107, .25) : rgba(77, 171, 247, .25));
      if (!gfx.spr(c, MOTO, k > 0 ? 'red' : 'blue', x, y, hgt, rot: p.ang)) drawHead(c, x, y, cs * .85, COS[k]);
    }
    for (final bm in booms) {
      if (!gfx.anim(c, BOOM, 'explode', bm.$3, bm.$1, bm.$2, cs * 5 * (1 + bm.$3))) circle(c, bm.$1, bm.$2, cs * 2 * (1 + bm.$3), rgba(255, 146, 43, 1 - bm.$3 / .6));
    }
    F.draw(c);
    C.end(c);
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Thắng $need ván trước', 'Vuốt trong nửa màn hình của mình để rẽ · Đừng đâm vào vệt sáng');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}

// ---------- 8. Đấu sumo: kéo trong nửa của mình để lao đi, đẩy đối thủ ra khỏi vòng tròn ----------
class _Sumo {
  _Sumo(this.x, this.y, this.m, this.f);
  double x, y, vx = 0, vy = 0, push = 0, out = 0;
  final double m;
  int f;
}

class SumoGame extends VsGame {
  SumoGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const need = 3, K = .55;
  late final FunTheme th = funTheme(lv);
  late double cx, cy, RING, pr, ACC, aiSkill;
  late List<_Sumo> P;
  int a = 0, b = 0, winner = 0;
  double t = 0, endT = 0, roundOver = 0;
  VsEnd? end;
  late Prerendered bg;

  double sy(double y) => cy + (y - cy) * K;
  void reset() {
    P = [_Sumo(cx - RING * .5, cy, 1, 1), _Sumo(cx + RING * .5, cy, pvp ? 1 : ramp(lv, .8, 1.25), -1)];
    roundOver = 0;
  }

  @override
  void setup() {
    cx = W / 2;
    cy = (H + 100) / 2;
    RING = math.min(W * .42, (H - 150) / (2 * K) * .9);
    pr = math.min(S * .07, RING * .2);
    ACC = S * 2.4;
    aiSkill = ramp(lv, .35, 1);
    reset();
    bg = prerender((g) {
      g.drawRect(
          Rect.fromLTWH(0, 0, W, H),
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(th.sky[0]), Color(th.sky[1]), Color(th.ground), Color(th.ground)], stops: const [0, .45, .45, 1])
                .createShader(Rect.fromLTWH(0, 0, W, H)));
      final pad = RING + pr * 1.4, side = S * .06;
      ellipse(g, cx, cy + side, pad, pad * K, hex(0xb07a3c));
      rect(g, cx - pad, cy, pad * 2, side, hex(0xb07a3c));
      ellipse(g, cx, cy, pad, pad * K, hex(0xe9c46a));
      ellipse(g, cx, cy, RING, RING * K, hex(0xf4dfa6));
      final ov = Rect.fromCenter(center: Offset(cx, cy), width: RING * 2, height: RING * K * 2);
      g.drawOval(ov, strokeP(hex(0xc9a227), 9));
      g.drawOval(ov, strokeP(rgba(255, 255, 255, .5), 2));
      for (final s in [-1.0, 1.0]) {
        line(g, cx + s * RING * .12, cy - RING * K * .2, cx + s * RING * .12, cy + RING * K * .2, hex(0xa0522d), 5);
      }
    });
  }

  (double, double) stick(int k) {
    for (final p in pts.values) {
      if ((p.sx < W / 2 ? 0 : 1) == k) {
        final dx = p.x - p.sx, dy = p.y - p.sy, d = hypot(dx, dy);
        if (d > 6) return (dx / math.max(d, 60), dy / math.max(d, 60));
      }
    }
    return (0, 0);
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    decay(pops, rdt);
    for (final p in P) {
      p.push = math.max(0, p.push - dt);
      if (p.out > 0) {
        p.out += dt;
        p.x += p.vx * dt * .6;
        p.y += p.vy * dt * .6;
      }
    }
    if (end != null) {
      endT += rdt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    if (roundOver > 0) {
      roundOver -= dt;
      if (roundOver <= 0) reset();
      return null;
    }
    final inp = [stick(0), pvp ? stick(1) : (0.0, 0.0)];
    if (!pvp) {
      final me = P[1], o = P[0], dc = hypot(me.x - cx, me.y - cy);
      var tx = o.x + (o.x - cx) * .3 - me.x, ty = o.y + (o.y - cy) * .3 - me.y;
      if (dc > RING * .7 && rnd01() < aiSkill) {
        tx = cx - me.x;
        ty = cy - me.y;
      }
      final d0 = hypot(tx, ty), d = d0 == 0 ? 1 : d0;
      inp[1] = (tx / d * (.55 + aiSkill * .45), ty / d * (.55 + aiSkill * .45));
    }
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      p.vx += inp[k].$1 * ACC * dt;
      p.vy += inp[k].$2 * ACC * dt;
      final fr = math.exp(-dt * 1.6);
      p.vx *= fr;
      p.vy *= fr;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final o = P[1 - k];
      p.f = o.x > p.x ? 1 : -1;
      if (hypot(p.vx, p.vy) > S * .5 && rnd01() < dt * 10) F.dust(p.x, sy(p.y), 1, 0, rgba(160, 82, 45, .45));
    }
    final p = P[0], q = P[1], dx = q.x - p.x, dy = q.y - p.y, d = hypot(dx, dy);
    if (d < pr * 2 && d > 0) {
      final nx = dx / d, ny = dy / d, ov = pr * 2 - d;
      p.x -= nx * ov / 2;
      p.y -= ny * ov / 2;
      q.x += nx * ov / 2;
      q.y += ny * ov / 2;
      final rel = (p.vx - q.vx) * nx + (p.vy - q.vy) * ny;
      if (rel > 0) {
        final j = 2.2 * rel / (1 / p.m + 1 / q.m);
        p.vx -= j / p.m * nx;
        p.vy -= j / p.m * ny;
        q.vx += j / q.m * nx;
        q.vy += j / q.m * ny;
        final pw = math.min(1.0, rel / (S * 1.5));
        p.push = q.push = .3;
        final mx = (p.x + q.x) / 2, my = sy((p.y + q.y) / 2) - pr * 1.6;
        sfx('pop');
        F.ring(mx, my, 20 + pw * 40, 0xffffff, 5);
        F.sparks(mx, my, 3 + (pw * 6).round(), 0xfff3bf);
        C.shake(1 + pw * 7);
        if (pw > .5) C.stop(.06);
      }
    }
    final out = P.map((p) => hypot(p.x - cx, p.y - cy) > RING + pr * .3).toList();
    if (out[0] || out[1]) {
      sfx('boom');
      C.shake(8);
      for (var k = 0; k < 2; k++) {
        if (out[k]) {
          P[k].out = .001;
          F.burst(P[k].x, sy(P[k].y), 14, [0xe9c46a, 0xa0522d, 0xffffff]);
        }
      }
      if (out[1] && !out[0]) {
        a++;
        pops[0] = 1;
        F.text(cx, sy(cy) - RING * K - 20, pvp ? '+1 XANH' : 'GIỎI QUÁ!', 0x74c0fc, 38);
      } else if (out[0] && !out[1]) {
        b++;
        pops[1] = 1;
        F.text(cx, sy(cy) - RING * K - 20, '+1 ĐỎ', 0xff8787, 38);
      }
      if (a >= need || b >= need) {
        winner = a >= need ? 1 : 2;
        end = VsEnd(winner, a * 5);
      } else {
        roundOver = 1.2;
      }
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    C.begin(c);
    final order = [0, 1]..sort((u, v) => P[u].y.compareTo(P[v].y));
    for (final k in order) {
      final p = P[k];
      final X = p.x, Y = sy(p.y) + (p.out > 0 ? inCubic(math.min(1, p.out * 1.5)) * S * .25 : 0), hh = pr * 3.3;
      final sp = hypot(p.vx, p.vy);
      final pose = end != null ? (winner == k + 1 ? 'cheer' : 'hurt') : (p.out > 0 ? 'hurt' : (p.push > 0 ? 'block' : (sp > S * .25 ? 'run' : 'idle')));
      if (p.out <= 0) shadow(c, X, Y, pr * 1.1, 0, .25);
      c.save();
      if (p.out > 0) {
        c.translate(X, Y);
        c.rotate(-p.f * math.min(1.2, p.out * 3));
        c.translate(-X, -Y);
      }
      drawFigure(c, X, Y, hh, COS[k], pose: pose, t: t * (sp > S * .25 ? 1.5 : 1) + k, face: p.f, team: k > 0 ? kRed : kBlue, alpha: p.out > 0 ? math.max(0, 1 - p.out) : 1);
      c.restore();
    }
    F.draw(c);
    C.end(c);
    for (final p in pts.values) {
      final k = p.sx < W / 2 ? 0 : 1;
      if (k == 1 && !pvp) continue;
      final col = k > 0 ? rgba(250, 82, 82, .6) : rgba(51, 154, 240, .6);
      strokeCircle(c, p.sx, p.sy, 50, col, 4);
      circle(c, p.sx + clamp(p.x - p.sx, -50, 50), p.sy + clamp(p.y - p.sy, -50, 50), 20, col);
    }
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Đẩy đối thủ ra ngoài $need lần', 'Đặt tay ở nửa của mình rồi kéo về hướng muốn lao tới');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}

// ---------- Bàn cờ ----------
void woodBoard(Canvas g, double x, double y, double w, double hh, double r) {
  fillRR(g, x + 6, y + 8, w, hh, r, rgba(0, 0, 0, .18));
  g.drawRRect(rr(x, y, w, hh, r), Paint()..shader = LinearGradient(colors: [hex(0xe8b77a), hex(0xc98f4f)]).createShader(Rect.fromLTWH(x, y, w, hh)));
  g.save();
  g.clipRRect(rr(x, y, w, hh, r));
  final ls = strokeP(rgba(120, 70, 30, .18), 2);
  for (var i = 0; i < 18; i++) {
    final yy = y + (i + .5) * hh / 18;
    g.drawPath(Path()
      ..moveTo(x, yy)
      ..cubicTo(x + w * .3, yy + 6, x + w * .6, yy - 6, x + w, yy + 3), ls);
  }
  g.restore();
}

const _chip = ['chipBlueWhite_border', 'chipRedWhite_border'];
void chip(Canvas c, Gfx g, SpriteSheet? ch, double x, double y, double d, int p, [double alpha = 1]) {
  if (!g.spr(c, ch, _chip[p - 1], x, y, d, alpha: alpha)) {
    circle(c, x, y, d / 2, (p == 1 ? kBlue : kRed).withValues(alpha: alpha));
    strokeCircle(c, x, y, d * .36, Colors.white.withValues(alpha: alpha * .8), d * .06);
  }
}

/// Lượt chơi trên HUD (caro, nối bốn).
void turnHud(VsGame g, Canvas c, int turn, String text) {
  fillRR(c, g.W / 2 - 150, 14, 300, 56, 28, rgba(0, 0, 0, .3));
  drawHead(c, g.W / 2 - 112, 44 - (math.sin(g.clock * 4)).abs() * 4, 18, g.COS[turn == 1 ? 0 : 1], t: g.clock);
  Txt.draw(c, text, g.W / 2 + 18, 50, size: 24);
}

// ---------- 9. Cờ caro: cấp thấp 3x3 (3 ô), giữa 6x6 (4 ô), cao 9x9 (5 ô) ----------
class CaroGame extends VsGame {
  CaroGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  late final SpriteSheet? CH = gfx.sh('kenney-board/chips');
  late final int N = lv < 10 ? 3 : (lv < 30 ? 6 : 9), K = lv < 10 ? 3 : (lv < 30 ? 4 : 5);
  late double cs, ox, oy, aiRand;
  late List<List<int>> g;
  late List<List<double>> at;
  int turn = 1, winner = 0;
  double t = 0, endT = 0, lineT = 0;
  List<(int, int)>? ln;
  (int, int)? last;
  bool busy = false;
  VsEnd? end;
  late Prerendered board;

  @override
  void setup() {
    const top = 100.0;
    cs = math.min((W - 30) / N, (H - top - 20) / N).floorToDouble();
    ox = (W - N * cs) / 2;
    oy = top + (H - top - 20 - N * cs) / 2;
    g = List.generate(N, (_) => List.filled(N, 0));
    at = List.generate(N, (_) => List.filled(N, -9));
    aiRand = ramp(lv, .45, 0);
    board = prerender((b) {
      rect(b, 0, 0, W, H, hex(0xfff9db));
      woodBoard(b, ox - 12, oy - 12, N * cs + 24, N * cs + 24, 18);
      final ls = strokeP(rgba(90, 50, 20, .55), 2);
      for (var i = 1; i < N; i++) {
        b.drawLine(Offset(ox + i * cs, oy), Offset(ox + i * cs, oy + N * cs), ls);
        b.drawLine(Offset(ox, oy + i * cs), Offset(ox + N * cs, oy + i * cs), ls);
      }
    });
  }

  List<(int, int)>? lineAt(int x, int y, int p) {
    for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      final cells = [(x, y)];
      for (final s in const [1, -1]) {
        for (var i = 1; i < K; i++) {
          final a = x + dx * i * s, b2 = y + dy * i * s;
          if (a < 0 || b2 < 0 || a >= N || b2 >= N || g[b2][a] != p) break;
          cells.add((a, b2));
        }
      }
      if (cells.length >= K) return cells..sort((u, v) => u.$1 != v.$1 ? u.$1 - v.$1 : u.$2 - v.$2);
    }
    return null;
  }

  bool full() => g.every((r) => r.every((v) => v != 0));

  void place(int x, int y) {
    g[y][x] = turn;
    at[y][x] = t;
    last = (x, y);
    sfx(turn == 1 ? 'tap' : 'pop');
    final l = lineAt(x, y, turn);
    if (l != null) {
      ln = l;
      lineT = t;
      winner = turn;
      end = VsEnd(winner, 20);
      sfx(turn == 1 ? 'win' : 'wrong');
      later(.45, () {
        for (final (cx2, cy2) in l) {
          F.burst(ox + (cx2 + .5) * cs, oy + (cy2 + .5) * cs, 8);
        }
        C.shake(5);
      });
      return;
    }
    if (full()) {
      winner = 0;
      end = const VsEnd(0, 5);
      return;
    }
    turn = 3 - turn;
  }

  double scoreCell(int x, int y, int p) {
    var sc = 0.0;
    for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      var n = 1, open = 0;
      for (final s in const [1, -1]) {
        for (var i = 1; i < K; i++) {
          final a = x + dx * i * s, b2 = y + dy * i * s;
          if (a < 0 || b2 < 0 || a >= N || b2 >= N) break;
          if (g[b2][a] == p) {
            n++;
          } else {
            if (g[b2][a] == 0) open++;
            break;
          }
        }
      }
      sc += n >= K ? 1e6 : math.pow(10, n) * (open + .5);
    }
    return sc;
  }

  (int, int) aiMove() {
    final empty = <(int, int)>[];
    for (var y = 0; y < N; y++) {
      for (var x = 0; x < N; x++) {
        if (g[y][x] == 0) empty.add((x, y));
      }
    }
    if (rnd01() < aiRand) return pickOf(empty);
    var best = empty.first;
    var bs = -1.0;
    for (final (x, y) in empty) {
      final s = scoreCell(x, y, 2) * 1.1 + scoreCell(x, y, 1) + rnd(0, 3);
      if (s > bs) {
        bs = s;
        best = (x, y);
      }
    }
    return best;
  }

  /// Chạm ô (x, y) — cũng dùng cho test.
  void tapCell(int x, int y) {
    if (end != null || busy || t < 2) return;
    if (!pvp && turn == 2) return;
    if (x < 0 || y < 0 || x >= N || y >= N || g[y][x] != 0) return;
    place(x, y);
    if (end == null && !pvp) {
      busy = true;
      later(.55, () {
        final (ax, ay) = aiMove();
        place(ax, ay);
        busy = false;
      });
    }
  }

  @override
  void onDown(Ptr p) => tapCell(((p.x - ox) / cs).floor(), ((p.y - oy) / cs).floor());

  @override
  Object? step(double dt) {
    t += dt;
    C.update(dt);
    F.update(dt);
    if (end != null) {
      endT += dt;
      return endT > 2.6 ? end : null;
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    board.draw(c);
    C.begin(c);
    for (var y = 0; y < N; y++) {
      for (var x = 0; x < N; x++) {
        final v = g[y][x];
        if (v == 0) continue;
        final X = ox + (x + .5) * cs, Y = oy + (y + .5) * cs, k = math.min(1.0, (t - at[y][x]) / .35);
        final s = outBack(k), dy = (1 - outCubic(k)) * -cs * .5;
        if (last == (x, y) && end == null) circle(c, X, Y, cs * .48, rgba(255, 212, 59, .25 + math.sin(t * 5) * .1));
        shadow(c, X + 2, Y + cs * .3, cs * .3 * s, 0, .25);
        final win = ln?.contains((x, y)) ?? false, pulse = win ? 1 + math.sin(t * 8) * .06 : 1.0;
        chip(c, gfx, CH, X, Y + dy, cs * .8 * s * pulse, v);
        final r = cs * .12 * s, ps = strokeP(Colors.white, math.max(3, cs * .06), cap: StrokeCap.round);
        if (v == 1) {
          c.drawLine(Offset(X - r, Y + dy - r), Offset(X + r, Y + dy + r), ps);
          c.drawLine(Offset(X + r, Y + dy - r), Offset(X - r, Y + dy + r), ps);
        } else {
          c.drawCircle(Offset(X, Y + dy), r, ps);
        }
      }
    }
    final l = ln;
    if (l != null) {
      final k = outCubic((t - lineT) / .5), s = l.first, e = l.last;
      final x0 = ox + (s.$1 + .5) * cs, y0 = oy + (s.$2 + .5) * cs, x1 = ox + (e.$1 + .5) * cs, y1 = oy + (e.$2 + .5) * cs;
      line(c, x0, y0, x0 + (x1 - x0) * k, y0 + (y1 - y0) * k, rgba(255, 212, 59, .95), 10);
    }
    F.draw(c);
    C.end(c);
    turnHud(this, c, turn, end != null ? '' : (turn == 1 ? (pvp ? 'Lượt XANH (✕)' : 'Lượt của bé (✕)') : (pvp ? 'Lượt ĐỎ (○)' : 'Máy đang nghĩ…')));
    if (t < 2) vsIntro(c, 'Xếp $K ô liền nhau trước', 'Chạm vào ô trống để đánh');
    if (end != null && endT > .7) endVs(c, winner, '');
  }
}

// ---------- 10. Nối bốn: thả quân vào cột, ai có 4 quân liền nhau trước thì thắng ----------
class _Drop {
  _Drop(this.c, this.y, this.p, this.yy, this.ty);
  final int c, y, p;
  double yy, vy = 0, ty;
  int bounces = 0;
}

class Connect4Game extends VsGame {
  Connect4Game(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const C7 = 7, R = 6;
  late final SpriteSheet? CH = gfx.sh('kenney-board/chips');
  late double cs, ox, oy, aiRand, hx;
  late int depth;
  final List<List<int>> g = List.generate(R, (_) => List.filled(C7, 0));
  int turn = 1, winner = 0, hover = 3;
  double t = 0, endT = 0;
  List<(int, int)>? ln;
  bool busy = false;
  _Drop? drop;
  VoidCallback? _afterDrop;
  VsEnd? end;
  late Prerendered front;

  @override
  void setup() {
    const top = 100.0;
    cs = math.min((W - 30) / C7, (H - top - 40) / (R + .6)).floorToDouble();
    ox = (W - C7 * cs) / 2;
    oy = top + cs * .6;
    hx = ox + 3.5 * cs;
    depth = ramp(lv, 1, 6).round();
    aiRand = ramp(lv, .4, 0);
    front = prerender((b) {
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(rr(ox - 10, oy - 10, C7 * cs + 20, R * cs + 20, 18));
      for (var y = 0; y < R; y++) {
        for (var x = 0; x < C7; x++) {
          path.addOval(Rect.fromCircle(center: Offset(ox + (x + .5) * cs, oy + (y + .5) * cs), radius: cs * .4));
        }
      }
      b.drawPath(path, fillP(hex(0x1971c2)));
      b.save();
      b.clipPath(path);
      fillRR(b, ox - 10, oy - 10, C7 * cs + 20, cs * .4, 18, rgba(255, 255, 255, .12));
      b.restore();
      for (var y = 0; y < R; y++) {
        for (var x = 0; x < C7; x++) {
          strokeCircle(b, ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .4, rgba(0, 0, 0, .25), 3);
        }
      }
    });
  }

  List<(int, int)>? win4(List<List<int>> gg, int p) {
    for (var y = 0; y < R; y++) {
      for (var x = 0; x < C7; x++) {
        for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
          var ok = true;
          for (var i = 0; i < 4 && ok; i++) {
            final a = x + dx * i, b2 = y + dy * i;
            ok = a >= 0 && b2 >= 0 && a < C7 && b2 < R && gg[b2][a] == p;
          }
          if (ok) return [for (var i = 0; i < 4; i++) (x + dx * i, y + dy * i)];
        }
      }
    }
    return null;
  }

  int rowFor(List<List<int>> gg, int c) {
    for (var y = R - 1; y >= 0; y--) {
      if (gg[y][c] == 0) return y;
    }
    return -1;
  }

  double evalBoard(List<List<int>> gg) {
    var s = 0.0;
    const mine = [0, 1, 6, 40, 1000], theirs = [0, 1, 6, 50, 1000];
    for (var y = 0; y < R; y++) {
      for (var x = 0; x < C7; x++) {
        for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
          var m = 0, o = 0;
          var bad = false;
          for (var i = 0; i < 4; i++) {
            final a = x + dx * i, b2 = y + dy * i;
            if (a >= C7 || b2 < 0 || b2 >= R) {
              bad = true;
              break;
            }
            if (gg[b2][a] == 2) {
              m++;
            } else if (gg[b2][a] == 1) {
              o++;
            }
          }
          if (bad) continue;
          if (o == 0) s += mine[m];
          if (m == 0) s -= theirs[o];
        }
      }
    }
    for (var y = 0; y < R; y++) {
      if (gg[y][3] == 2) s += 3;
    }
    return s;
  }

  double mm(List<List<int>> gg, int d, double al, double be, bool maxP) {
    if (win4(gg, 2) != null) return 1e5 + d;
    if (win4(gg, 1) != null) return -1e5 - d;
    if (d == 0) return evalBoard(gg);
    var best = maxP ? -1e9 : 1e9;
    for (final c in const [3, 2, 4, 1, 5, 0, 6]) {
      final y = rowFor(gg, c);
      if (y < 0) continue;
      gg[y][c] = maxP ? 2 : 1;
      final v = mm(gg, d - 1, al, be, !maxP);
      gg[y][c] = 0;
      if (maxP) {
        best = math.max(best, v);
        al = math.max(al, v);
      } else {
        best = math.min(best, v);
        be = math.min(be, v);
      }
      if (be <= al) break;
    }
    return best == 1e9 || best == -1e9 ? 0 : best;
  }

  int aiMove() {
    final cols = [for (var c = 0; c < C7; c++) if (rowFor(g, c) >= 0) c];
    if (rnd01() < aiRand) return pickOf(cols);
    var best = cols.first;
    var bs = -1e9;
    for (final c in cols) {
      final y = rowFor(g, c);
      g[y][c] = 2;
      final v = mm(g, depth - 1, -1e9, 1e9, false) + rnd(0, 2);
      g[y][c] = 0;
      if (v > bs) {
        bs = v;
        best = c;
      }
    }
    return best;
  }

  /// Thả quân vào cột c; then() chạy khi quân đã nằm yên (nếu thả được).
  bool play(int c, [VoidCallback? then]) {
    final y = rowFor(g, c);
    if (y < 0) return false;
    drop = _Drop(c, y, turn, oy - cs, oy + y * cs);
    _afterDrop = then;
    sfx('tap');
    return true;
  }

  void _landed() {
    final d = drop!;
    g[d.y][d.c] = d.p;
    drop = null;
    sfx('pop');
    final l = win4(g, turn);
    final then = _afterDrop;
    _afterDrop = null;
    if (l != null) {
      ln = l;
      winner = turn;
      end = VsEnd(winner, 20);
      sfx(turn == 1 ? 'win' : 'wrong');
      for (final (x2, y2) in l) {
        F.burst(ox + (x2 + .5) * cs, oy + (y2 + .5) * cs, 8);
      }
      C.shake(6);
      busy = false;
      return;
    }
    if (g[0].every((v) => v != 0)) {
      end = const VsEnd(0, 5);
      busy = false;
      return;
    }
    turn = 3 - turn;
    then?.call();
  }

  /// Chạm cột c — cũng dùng cho test.
  void tapCol(int c) {
    if (end != null || busy || t < 2) return;
    if (!pvp && turn == 2) return;
    if (c < 0 || c >= C7) return;
    hover = c;
    busy = true;
    final ok = play(c, () {
      if (end == null && !pvp) {
        later(.3, () {
          hover = aiMove();
          later(.26, () {
            if (!play(hover, () => busy = false)) busy = false;
          });
        });
      } else {
        busy = false;
      }
    });
    if (!ok) busy = false;
  }

  @override
  void move(Ptr p) => hover = clamp(((p.x - ox) / cs).floorToDouble(), 0, C7 - 1).toInt();

  @override
  void onDown(Ptr p) => tapCol(((p.x - ox) / cs).floor());

  @override
  Object? step(double dt) {
    t += dt;
    C.update(dt);
    F.update(dt);
    hx = approach(hx, ox + (hover + .5) * cs, 14, dt);
    final d = drop;
    if (d != null) {
      d.vy += cs * 60 * dt;
      d.yy += d.vy * dt;
      if (d.yy >= d.ty) {
        d.yy = d.ty;
        if (d.bounces < 2 && d.vy > cs * 4) {
          d.vy = -d.vy * .3;
          d.bounces++;
          C.shake(d.bounces == 1 ? 2.5 : 1);
          sfx('tap');
        } else {
          _landed();
        }
      }
    }
    if (end != null) {
      endT += dt;
      return endT > 2.6 ? end : null;
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    rect(c, 0, 0, W, H, hex(0xe7f5ff));
    C.begin(c);
    fillRR(c, ox - 10, oy - 10, C7 * cs + 20, R * cs + 20, 18, hex(0xd0ebff));
    for (var y = 0; y < R; y++) {
      for (var x = 0; x < C7; x++) {
        if (g[y][x] != 0) {
          final win = ln?.contains((x, y)) ?? false;
          chip(c, gfx, CH, ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .84 * (win ? 1 + math.sin(t * 8) * .05 : 1), g[y][x]);
        }
      }
    }
    final d = drop;
    if (d != null) chip(c, gfx, CH, ox + (d.c + .5) * cs, d.yy + cs * .5, cs * .84, d.p);
    front.draw(c);
    if (end == null && !busy && (pvp || turn == 1)) chip(c, gfx, CH, hx, oy - cs * .55 + math.sin(t * 5) * 3, cs * .8, turn, .9);
    final l = ln;
    if (l != null) {
      for (final (x, y) in l) {
        strokeCircle(c, ox + (x + .5) * cs, oy + (y + .5) * cs, cs * .44 + math.sin(t * 8) * 2, Colors.white, 5);
      }
    }
    F.draw(c);
    C.end(c);
    turnHud(this, c, turn, end != null ? '' : (turn == 1 ? (pvp ? 'Lượt XANH' : 'Lượt của bé (xanh)') : (pvp ? 'Lượt ĐỎ' : 'Máy đang nghĩ…')));
    if (t < 2) vsIntro(c, 'Nối 4 quân liền nhau trước', 'Chạm vào cột để thả quân');
    if (end != null && endT > .6) endVs(c, winner, '');
  }
}
