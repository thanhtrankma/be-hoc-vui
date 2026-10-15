// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api
// Đối kháng 1: võ đài, khúc côn cầu, kéo co, bóng đá đầu to, bóng chuyền (đấu máy hoặc bố/mẹ).
// CHỦ: agent G. Port của reference/web/js/games/funvs1.js.
// "Đấu với máy" (60 cấp, máy giỏi dần) hoặc "Hai người" chung một màn hình (trái/dưới là bé - xanh, phải/trên là đối thủ - đỏ;
// chạm nhiều ngón cùng lúc). Quán tính, đòn có khung lấy đà/ra đòn/thu về, bật lùi, dừng hình + rung màn khi trúng,
// số sát thương nảy, bụi chân, bóng có xoáy/dẹt khi nảy, lưới gôn rung, cảnh nền vẽ sẵn.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'vs_core.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funvs1Games = {
  'fighter': VsModule('fighter', '🥊 Võ đài', (lv) => ['Shield', 'Glowing star', ...funThemeImgs(lv)], FighterGame.new),
  'hockey': VsModule('hockey', '🏒 Khúc côn cầu', (lv) => ['Glowing star'], HockeyGame.new),
  'tug': VsModule('tug', '🪢 Kéo co', (lv) => ['Glowing star', 'Water wave', ...funThemeImgs(lv)], TugGame.new),
  'soccer': VsModule('soccer', '⚽ Bóng đá đầu to', (lv) => ['Soccer ball', 'Glowing star', ...funThemeImgs(lv)], SoccerGame.new),
  'volley': VsModule('volley', '🏐 Bóng chuyền', (lv) => ['Volleyball', 'Glowing star', 'Palm tree', 'Sun with face'], VolleyGame.new),
};

// ---------- 1. Võ đài: đi, nhảy, đấm, đỡ đòn; hết máu là thua ----------
class _Fighter {
  _Fighter(this.x, this.y, this.f, this.w);
  double x, y, vx = 0, kb = 0, vy = 0, hp = 100, shp = 100, cd = 0, atk = -1, hurt = 0, w;
  int f;
  bool hitDone = false, block = false, air = false, ko = false;
}

class FighterGame extends VsGame {
  FighterGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  late final FunTheme th = funTheme(lv);
  late double ground;
  late List<_Fighter> P;
  late Prerendered bg;
  double t = 0, endT = 0;
  VsEnd? end;
  int winner = 0;
  double aiThink = 0;
  Map<String, bool>? aiAct;
  late double react, blockP;
  late int dmgBot;
  static const wind = .09, strike = .2, endA = .36;

  @override
  void setup() {
    ground = H * .68;
    P = [_Fighter(W * .25, ground, 1, S * .2), _Fighter(W * .75, ground, -1, S * .2)];
    final r = math.min(56.0, math.min(S * .085, pvp ? (W / 2 - 24) / 6.8 : 99.0)), by = H - r - 16;
    B = CButtons(this, [
      CBtn('l1', r + 14, by, r, '◀'),
      CBtn('r1', r * 3.4 + 14, by, r, '▶'),
      CBtn('j1', r * 5.8 + 14, by, r, '⬆', kBlue),
      CBtn('p1', r * 2.2 + 14, by - r * 2.2, r, '👊', kBlue),
      CBtn('b1', r * 4.6 + 14, by - r * 2.2, r, '🛡', kBlue),
      if (pvp) ...[
        CBtn('l2', W - r * 3.4 - 14, by, r, '◀'),
        CBtn('r2', W - r - 14, by, r, '▶'),
        CBtn('j2', W - r * 5.8 - 14, by, r, '⬆', kRed),
        CBtn('p2', W - r * 4.6 - 14, by - r * 2.2, r, '👊', kRed),
        CBtn('b2', W - r * 2.2 - 14, by - r * 2.2, r, '🛡', kRed),
      ],
    ]);
    react = ramp(lv, .55, .14);
    blockP = ramp(lv, .1, .6);
    dmgBot = ramp(lv, 7, 13).round();
    bg = prerender((g) {
      sky(g, W, H, th);
      for (var i = 0; i < 2; i++) {
        gfx.draw(g, th.deco[i], W * (i > 0 ? .88 : .12), ground - S * .14, S * .26, S * .26, false, 0, .6);
      }
      rect(g, 0, ground, W, H - ground, Color(th.ground));
      fillRR(g, W * .04, ground - 6, W * .92, 18, 8, hex(0xc08552));
      rect(g, W * .04, ground + 10, W * .92, 10, hex(0xa0522d));
      for (final x in [W * .05, W * .95]) {
        rect(g, x - 6, ground - S * .32, 12, S * .32, hex(0x495057));
        rect(g, x - 8, ground - S * .34, 16, 14, hex(0xe03131));
      }
      const cols = [0xffffff, 0xfa5252, 0xffffff];
      for (var i = 0; i < 3; i++) {
        final path = Path()
          ..moveTo(W * .05, ground - S * (.1 + i * .08))
          ..quadraticBezierTo(W / 2, ground - S * (.08 + i * .08), W * .95, ground - S * (.1 + i * .08));
        g.drawPath(path, strokeP(hex(cols[i]), 4));
      }
    });
  }

  void physics(_Fighter p, double dt) {
    p.kb = approach(p.kb, 0, 5, dt);
    p.x += (p.vx + p.kb) * dt;
    p.vy += S * 4 * dt;
    p.y += p.vy * dt;
    if (p.y >= ground) {
      if (p.air && p.vy > S * .5) {
        F.dust(p.x, ground, 6);
        C.shake(p.ko ? 6 : 1.5);
      }
      p.y = ground;
      p.vy = 0;
      p.air = false;
    } else {
      p.air = true;
    }
    if (p.x < p.w / 2) {
      p.x = p.w / 2;
      if (p.kb < -S * .3) {
        p.kb = -p.kb * .4;
        F.ring(p.x, p.y - p.w * .6, 30, 0xffffff, 4);
        C.shake(2);
      }
    }
    if (p.x > W - p.w / 2) {
      p.x = W - p.w / 2;
      if (p.kb > S * .3) {
        p.kb = -p.kb * .4;
        F.ring(p.x, p.y - p.w * .6, 30, 0xffffff, 4);
        C.shake(2);
      }
    }
  }

  void tryHit(_Fighter p, int k) {
    final o = P[1 - k];
    if (!((o.x - p.x).abs() < p.w * 1.1 && (o.y - p.y).abs() < p.w * .7)) {
      sfx('tap');
      return;
    }
    final hx = (p.x + o.x) / 2 + p.f * p.w * .15, hy = o.y - o.w * .75;
    if (o.block && o.f == -p.f) {
      sfx('pop');
      F.text(o.x, o.y - o.w * 1.15, 'ĐỠ!', 0x74c0fc, 26);
      F.ring(hx, hy, 34, 0x74c0fc, 6);
      F.sparks(hx, hy, 5, 0xd0ebff, p.f > 0 ? math.pi : 0);
      o.kb += p.f * S * .35;
      C.shake(2);
      return;
    }
    final dmg = (k == 1 && !pvp) ? dmgBot : 10, crit = !o.air && p.air;
    final d = crit ? (dmg * 1.4).round() : dmg;
    o.hp = math.max(0, o.hp - d);
    o.hurt = .32;
    o.kb += p.f * S * (crit ? 1.5 : 1.05);
    if (o.air || crit) o.vy = math.min(o.vy, -S * .55);
    o.atk = -1;
    sfx('hit');
    C.stop(crit ? .1 : .065);
    C.shake(crit ? 9 : 6);
    F.sparks(hx, hy, 10, 0xfff3bf, p.f > 0 ? 0 : math.pi);
    F.ring(hx, hy, 36, 0xffe066, 6);
    F.burst(hx, hy, 6, [0xffffff, 0xffd43b]);
    F.num(o.x, o.y - o.w * 1.15, '-$d', crit: crit, c: 0xff6b6b);
  }

  void control(_Fighter p, int k, Map<String, bool> inp, double dt) {
    p.cd = math.max(0, p.cd - dt);
    p.hurt = math.max(0, p.hurt - dt);
    p.block = (inp['block'] ?? false) && !p.air && p.atk < 0 && p.hurt <= 0;
    final dir = ((inp['r'] ?? false) ? 1 : 0) - ((inp['l'] ?? false) ? 1 : 0), lock = p.block || p.hurt > .15 || (p.atk >= 0 && !p.air);
    p.vx = approach(p.vx, lock ? 0 : dir * S * .58, p.air ? 3 : 14, dt);
    if ((inp['j'] ?? false) && !p.air && p.hurt <= 0) {
      p.vy = -S * 1.6;
      p.air = true;
      sfx('jump');
      F.dust(p.x, ground, 5);
    }
    final o = P[1 - k];
    if (p.atk < 0 && p.hurt <= 0) p.f = o.x > p.x ? 1 : -1;
    if ((inp['p'] ?? false) && p.cd <= 0 && !p.block && p.atk < 0 && p.hurt <= 0) {
      p.cd = .42;
      p.atk = 0;
      p.hitDone = false;
      sfx('flip');
    }
    if (p.atk >= 0) {
      p.atk += dt;
      if (!p.hitDone && p.atk >= wind) {
        p.hitDone = true;
        p.kb += p.f * S * .25;
        tryHit(p, k);
      }
      if (p.atk >= endA) p.atk = -1;
    }
    physics(p, dt);
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    for (final p in P) {
      p.shp = approach(p.shp, p.hp, 4, rdt);
    }
    if (end != null) {
      endT += rdt;
      for (final p in P) {
        p.vx = approach(p.vx, 0, 6, dt);
        p.hurt = math.max(0, p.hurt - dt);
        physics(p, dt);
      }
      return endT > 2.4 ? end : null;
    }
    if (t < 2.4) return null;
    final b = B!;
    control(P[0], 0, {'l': b.down('l1'), 'r': b.down('r1'), 'j': b.hit('j1'), 'p': b.hit('p1'), 'block': b.down('b1')}, dt);
    if (pvp) {
      control(P[1], 1, {'l': b.down('l2'), 'r': b.down('r2'), 'j': b.hit('j2'), 'p': b.hit('p2'), 'block': b.down('b2')}, dt);
    } else {
      final me = P[1], o = P[0], d = (o.x - me.x).abs();
      aiThink -= dt;
      if (aiThink <= 0) {
        aiThink = react * rnd(.7, 1.3);
        final a = {'l': false, 'r': false, 'j': false, 'p': false, 'block': false};
        if (d > me.w * .9) {
          a[o.x < me.x ? 'l' : 'r'] = true;
        } else if (rnd01() < .7) {
          a['p'] = true;
        } else {
          a[o.x < me.x ? 'r' : 'l'] = true;
        }
        if (o.atk >= 0 && rnd01() < blockP) a['block'] = true;
        if (rnd01() < .06) a['j'] = true;
        aiAct = a;
      }
      final a = {...?aiAct};
      a['p'] = (a['p'] ?? false) && rnd01() < .5;
      control(me, 1, a, dt);
    }
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      if (p.hp <= 0 && end == null) {
        winner = 2 - k;
        end = VsEnd(winner, P[0].hp.round());
        p.ko = true;
        p.hurt = 3;
        p.vy = -S * 1.1;
        p.kb = (k > 0 ? 1 : -1) * S * 1.6;
        sfx(winner == 1 ? 'win' : 'pop');
        C.stop(.3);
        C.shake(14);
        F.burst(p.x, p.y - p.w / 2, 30);
        F.text(W / 2, H * .3, 'K.O.!', 0xffd43b, 56);
      }
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    clouds(c, W, H, t, 3);
    gfx.draw(c, th.sun, W * .5, H * .16 + math.sin(t * .8) * 4, S * .14);
    C.begin(c);
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      var pose = 'idle';
      var act = 0.0, lean = 0.0;
      if (end != null && !p.ko) {
        pose = 'cheer';
      } else if (p.hurt > 0) {
        pose = 'hurt';
      } else if (p.block) {
        pose = 'block';
      } else if (p.atk >= 0) {
        pose = 'punch';
        act = p.atk < wind ? .05 : (p.atk < strike ? .5 * outCubic((p.atk - wind) / (strike - wind)) : .5 + .5 * (p.atk - strike) / (endA - strike));
        if (p.atk < wind) lean = -p.f * p.w * .06 * outCubic(p.atk / wind);
      } else if (p.air) {
        pose = 'jump';
      } else if (p.vx.abs() > 25) {
        pose = 'run';
      }
      final flash = p.hurt > 0 && p.hurt < .32 && (p.hurt * 30).floor() % 2 == 1 ? .55 : 1.0;
      drawFigure(c, p.x + lean, p.y, p.w * 1.3, COS[k], pose: pose, t: t + k, act: act, face: p.f, team: k > 0 ? kRed : kBlue, alpha: flash);
      if (p.block) gfx.draw(c, 'Shield', p.x + p.f * p.w * .45, p.y - p.w * .7, p.w * .42, p.w * .42, false, 0, .85);
    }
    F.draw(c);
    C.end(c);
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      final bw = math.min(260.0, W * .36), bx = k > 0 ? W - bw - 20 : 20.0, sh = math.max(p.hp, p.shp);
      fillRR(c, bx, 70, bw, 22, 11, rgba(0, 0, 0, .35));
      fillRR(c, k > 0 ? bx + bw * (1 - sh / 100) : bx, 70, bw * sh / 100, 22, 11, Colors.white);
      if (p.hp > 0) fillRR(c, k > 0 ? bx + bw * (1 - p.hp / 100) : bx, 70, bw * p.hp / 100, 22, 11, k > 0 ? kRed : kBlue);
      drawHead(c, k > 0 ? bx + bw + 4 - 34 : bx + 14, 60, 15, COS[k], face: k > 0 ? -1 : 1, hurt: p.hurt > 0);
    }
    B!.draw(c);
    if (t < 2.4) vsIntro(c, 'Đánh hết máu đối thủ', '◀ ▶ đi · ⬆ nhảy · 👊 đấm · 🛡 giữ để đỡ');
    if (end != null && endT > .6) endVs(c, winner, '');
  }
}

// ---------- 2. Khúc côn cầu: kéo vợt trong nửa sân của mình, đánh bóng vào gôn đối thủ ----------
class _Mallet {
  _Mallet(this.x, this.y) : tx = x, ty = y;
  double x, y, vx = 0, vy = 0, tx, ty;
}

class HockeyGame extends VsGame {
  HockeyGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const need = 5;
  late double top, L, Rr, Bt, mr, pr, goalH, cyy, aiSp, aiSkill;
  late List<_Mallet> mal;
  final List<Offset> trail = List.filled(12, Offset.zero);
  int ti = 0, a = 0, b = 0, winner = 0;
  double px = 0, py = 0, pvx = 0, pvy = 0, prot = 0, pborn = 0;
  double t = 0, endT = 0, pause = 0;
  final List<double> goalFlash = [0, 0];
  VsEnd? end;
  late Prerendered rink;

  void serve(int side) {
    px = side == 1 ? W * .38 : W * .62;
    py = cyy;
    pvx = pvy = prot = pborn = 0;
    pause = .8;
    for (var i = 0; i < trail.length; i++) {
      trail[i] = Offset(px, py);
    }
  }

  @override
  void setup() {
    top = 90;
    L = 16;
    Rr = W - 16;
    Bt = H - 16;
    mr = S * .07;
    pr = S * .04;
    goalH = (Bt - top) * .36;
    cyy = (top + Bt) / 2;
    mal = [_Mallet(W * .2, cyy), _Mallet(W * .8, cyy)];
    serve(1);
    aiSp = S * ramp(lv, 1.2, 3.2);
    aiSkill = ramp(lv, .3, .95);
    rink = prerender((g) {
      rect(g, 0, 0, W, H, hex(0xd0ebff));
      final rr0 = rr(L, top, Rr - L, Bt - top, 40);
      g.drawRRect(rr0, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, hex(0xe7f5ff)]).createShader(Rect.fromLTWH(L, top, Rr - L, Bt - top)));
      g.save();
      g.clipRRect(rr0);
      for (var i = 0; i < 60; i++) {
        final x = (i * 157) % W, y = top + (i * 89) % (Bt - top), l = 20.0 + (i % 5) * 12, an = (i % 7) * .4;
        line(g, x, y, x + math.cos(an) * l, y + math.sin(an) * l, rgba(116, 192, 252, .18), 1.5, StrokeCap.butt);
      }
      g.restore();
      g.drawRRect(rr0, strokeP(hex(0x74c0fc), 8));
      line(g, W / 2, top, W / 2, Bt, hex(0xff8787), 5, StrokeCap.butt);
      strokeCircle(g, W / 2, cyy, S * .12, hex(0xff8787), 5);
      circle(g, W / 2, cyy, 8, hex(0xff8787));
      for (final (x, s, col) in [(L, 1, kBlue), (Rr, -1, kRed)]) {
        final rect0 = Rect.fromCircle(center: Offset(x, cyy), radius: goalH * .42);
        g.drawArc(rect0, s > 0 ? -math.pi / 2 : math.pi / 2, math.pi, true, fillP(col.withValues(alpha: .13)));
        g.drawArc(rect0, s > 0 ? -math.pi / 2 : math.pi / 2, math.pi, false, strokeP(col, 3));
      }
    });
  }

  @override
  void onDown(Ptr p) => p.side = p.x < W / 2 ? 0 : 1;

  void goal(int side) {
    if (side == 2) {
      b++;
      pops[1] = 1;
      sfx('wrong');
      F.text(W / 2, H / 2, pvp ? 'ĐỎ GHI BÀN!' : 'MÁY GHI BÀN!', 0xff8787, 40);
      goalFlash[0] = 1;
      F.burst(L, cyy, 24, [0xffffff, 0x74c0fc, 0xff8787]);
      serve(1);
    } else {
      a++;
      pops[0] = 1;
      sfx('win');
      F.burst(Rr, cyy, 34);
      F.text(W / 2, H / 2, 'VÀO!', 0xffd43b, 46);
      goalFlash[1] = 1;
      serve(2);
    }
    C.shake(10);
    C.stop(.12);
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    decay(pops, rdt);
    decay(goalFlash, rdt, 1.5);
    if (end != null) {
      endT += rdt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    for (final p in pts.values) {
      if (p.side == 0) {
        mal[0].tx = p.x;
        mal[0].ty = p.y;
      } else if (pvp && p.side == 1) {
        mal[1].tx = p.x;
        mal[1].ty = p.y;
      }
    }
    if (!pvp) {
      final m = mal[1];
      double tx, ty;
      if (px > W / 2) {
        tx = px + pr * 1.5 * aiSkill;
        ty = py + (py - cyy) * .2;
      } else {
        tx = Rr - mr * 3;
        ty = cyy + (py - cyy) * .5 * aiSkill;
      }
      final dx = tx - m.x, dy = ty - m.y, d = hypot(dx, dy), st = math.min(d, aiSp * dt * 1.6);
      if (d > 1) {
        m.tx = m.x + dx / d * st;
        m.ty = m.y + dy / d * st;
      } else {
        m.tx = tx;
        m.ty = ty;
      }
    }
    for (var k = 0; k < 2; k++) {
      final m = mal[k];
      final minX = k > 0 ? W / 2 + mr : L + mr, maxX = k > 0 ? Rr - mr : W / 2 - mr;
      final gx = clamp(m.tx, minX, maxX), gy = clamp(m.ty, top + mr, Bt - mr);
      final nx = approach(m.x, gx, 30, dt), ny = approach(m.y, gy, 30, dt);
      m.vx = (nx - m.x) / math.max(dt, .001);
      m.vy = (ny - m.y) / math.max(dt, .001);
      m.x = nx;
      m.y = ny;
      final dx = px - m.x, dy = py - m.y, d = hypot(dx, dy);
      if (d < mr + pr && d > 0) {
        final nx2 = dx / d, ny2 = dy / d;
        px = m.x + nx2 * (mr + pr);
        py = m.y + ny2 * (mr + pr);
        final rel = (pvx - m.vx) * nx2 + (pvy - m.vy) * ny2;
        if (rel < 0) {
          pvx -= 1.9 * rel * nx2;
          pvy -= 1.9 * rel * ny2;
          sfx('tap');
          final pw = math.min(1.0, -rel / (S * 2));
          F.ring(m.x + nx2 * mr, m.y + ny2 * mr, 20 + pw * 30, k > 0 ? 0xffc9c9 : 0xd0ebff, 5);
          if (pw > .4) {
            F.sparks(px, py, 6, 0xffffff, math.atan2(ny2, nx2));
            C.shake(pw * 4);
          }
        }
        final sp = hypot(pvx, pvy), mx = S * 3.2;
        if (sp > mx) {
          pvx *= mx / sp;
          pvy *= mx / sp;
        }
      }
    }
    pborn += dt;
    if (pause > 0) {
      pause -= dt;
      return null;
    }
    px += pvx * dt;
    py += pvy * dt;
    final fr = math.exp(-dt * .35);
    pvx *= fr;
    pvy *= fr;
    prot += (pvx + pvy) * dt * .02;
    ti = (ti + 1) % trail.length;
    trail[ti] = Offset(px, py);
    void wall(double x, double y) {
      sfx('pop');
      F.ring(x, y, 18, 0xa5d8ff, 4);
      F.sparks(x, y, 4, 0xe7f5ff);
    }

    if (py < top + pr) {
      py = top + pr;
      pvy = pvy.abs();
      wall(px, top);
    }
    if (py > Bt - pr) {
      py = Bt - pr;
      pvy = -pvy.abs();
      wall(px, Bt);
    }
    final inGoal = (py - cyy).abs() < goalH / 2;
    if (px < L + pr) {
      if (inGoal) {
        goal(2);
      } else {
        px = L + pr;
        pvx = pvx.abs();
        wall(L, py);
      }
    }
    if (px > Rr - pr) {
      if (inGoal) {
        goal(1);
      } else {
        px = Rr - pr;
        pvx = -pvx.abs();
        wall(Rr, py);
      }
    }
    if (a >= need || b >= need) {
      winner = a >= need ? 1 : 2;
      end = VsEnd(winner, a * 5);
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    C.begin(c);
    rink.draw(c);
    for (final (k, x) in [(0, L - 6), (1, Rr - 6)]) {
      rect(c, x, cyy - goalH / 2, 12, goalH, k > 0 ? kRed : kBlue);
      if (goalFlash[k] > 0) rect(c, k > 0 ? Rr - 80 : L, cyy - goalH / 2 - 20, 80, goalH + 40, rgba(255, 224, 102, goalFlash[k] * .6));
    }
    final sp = hypot(pvx, pvy);
    if (sp > S * .4) {
      for (var i = 1; i < trail.length; i++) {
        final p = trail[(ti - i + trail.length * 2) % trail.length], k = 1 - i / trail.length;
        circle(c, p.dx, p.dy, pr * (.4 + k * .55), rgba(33, 37, 41, k * .18 * math.min(1, sp / (S * 2))));
      }
    }
    final ps = pause > 0 ? outBack(math.min(1, pborn / .45)) : 1.0;
    shadow(c, px + 3, py + pr * .5, pr * 1.05, 0, .2);
    c.save();
    c.translate(px, py);
    c.scale(ps, ps);
    c.rotate(prot);
    circle(c, 0, 0, pr, hex(0x212529));
    circle(c, 0, 0, pr * .68, hex(0x495057));
    c.drawArc(Rect.fromCircle(center: Offset.zero, radius: pr * .45), 0, 2.2, false, strokeP(hex(0xffd43b), 3));
    c.restore();
    for (var k = 0; k < 2; k++) {
      final m = mal[k];
      final col = k > 0 ? kRed : kBlue, sp2 = math.min(1.0, hypot(m.vx, m.vy) / (S * 3));
      shadow(c, m.x + 5, m.y + mr * .55, mr * 1.05, 0, .25);
      final r = mr * (1 + sp2 * .06);
      c.drawCircle(Offset(m.x, m.y), r,
          Paint()..shader = RadialGradient(center: const Alignment(-.3, -.35), radius: 1, colors: [k > 0 ? hex(0xffa8a8) : hex(0xa5d8ff), col]).createShader(Rect.fromCircle(center: Offset(m.x, m.y), radius: r)));
      strokeCircle(c, m.x, m.y, r, rgba(0, 0, 0, .25), 3);
      circle(c, m.x, m.y, mr * .7, rgba(255, 255, 255, .3));
      drawHead(c, m.x, m.y - mr * .05, mr * .56, COS[k], face: k > 0 ? -1 : 1, t: t);
    }
    F.draw(c);
    C.end(c);
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Ghi $need bàn trước', 'Kéo vợt trong nửa sân của mình');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}

// ---------- 3. Kéo co: chạm thật nhanh vào nửa màn hình của mình ----------
class TugGame extends VsGame {
  TugGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  late final FunTheme th = funTheme(lv);
  late List<Costume> team1, team2;
  late double ground, goal, botRate, sz;
  double pos = 0, shown = 0, t = 0, endT = 0, botAcc = 0, wob = 0;
  final List<int> taps = [0, 0];
  final List<double> pulse = [0, 0];
  int winner = 0;
  VsEnd? end;
  late Prerendered bg;

  @override
  void setup() {
    team1 = [COS[0], kFriends[0], kFriends[1]];
    team2 = [COS[1], withShirt(kFriends[2], kRed), withShirt(kFriends[3], hex(0xe03131))];
    ground = H * .66;
    goal = W * .22;
    botRate = ramp(lv, 3.2, 8.5);
    sz = S * .15;
    bg = prerender((g) {
      sky(g, W, H, th);
      for (var i = 0; i < 3; i++) {
        gfx.draw(g, th.deco[i], W * (.1 + i * .4), ground - S * .12, S * .22, S * .22, false, 0, .55);
      }
      rect(g, 0, ground, W, H - ground, Color(th.ground));
      rect(g, 0, ground, W, 8, Color(th.edge));
      ellipse(g, W / 2, ground + 14, W * .09, 22, hex(0x8d5524));
      ellipse(g, W / 2, ground + 16, W * .065, 14, hex(0x6f4518));
      for (final x in [W / 2 - goal, W / 2 + goal]) {
        for (var y = ground - S * .3; y < ground + 30; y += 18) {
          line(g, x, y, x, math.min(y + 10, ground + 30), Colors.white, 4, StrokeCap.butt);
        }
      }
    });
  }

  void pull(int side) {
    pos += side > 0 ? 6 : -6;
    taps[side]++;
    pulse[side] = .14;
    wob = math.min(1, wob + .35);
    final fx = side > 0 ? W / 2 + shown + S * .2 + sz * 1.7 : W / 2 + shown - S * .2 - sz * 1.7;
    F.dust(fx, ground + sz * .05, 2, side > 0 ? 1 : -1, rgba(141, 85, 36, .6));
  }

  @override
  void onDown(Ptr p) {
    if (end != null || t < 2.4) return;
    final side = p.x < W / 2 ? 0 : 1;
    if (side == 1 && !pvp) return;
    pull(side);
    sfx('tap');
  }

  @override
  Object? step(double dt) {
    t += dt;
    C.update(dt);
    F.update(dt);
    decay(pulse, dt, 1);
    shown = approach(shown, pos, 9, dt);
    wob = math.max(0, wob - dt * 1.6);
    if (end != null) {
      endT += dt;
      return endT > 2.4 ? end : null;
    }
    if (t < 2.4) return null;
    if (!pvp) {
      botAcc += dt * botRate * (1 + math.sin(t * 1.7) * .25);
      while (botAcc >= 1) {
        botAcc -= 1;
        pull(1);
      }
    }
    if (pos <= -goal || pos >= goal) {
      winner = pos < 0 ? 1 : 2;
      end = VsEnd(winner, taps[0]);
      sfx(winner == 1 ? 'win' : 'pop');
      F.burst(W / 2, ground + 10, 30, [0x8d5524, 0x6f4518, 0xa0522d, 0xffffff]);
      C.shake(10);
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    clouds(c, W, H, t, 4);
    gfx.draw(c, th.sun, W * .5, H * .14, S * .13);
    C.begin(c);
    final cx = W / 2 + shown, ry = ground - S * .12;
    final sag = 10 + math.sin(t * 38) * 9 * wob;
    final rope = Path()
      ..moveTo(W * .03, ry + 4)
      ..quadraticBezierTo(cx, ry + sag * 2, W * .97, ry + 4);
    c.drawPath(rope, strokeP(hex(0xa0522d), 10, cap: StrokeCap.round));
    c.drawPath(rope, strokeP(hex(0xd9a066), 3));
    final ky = ry + sag;
    final bow = Path()
      ..moveTo(cx, ky)
      ..lineTo(cx - 10 + math.sin(t * 9) * 3, ky + 34)
      ..lineTo(cx + 2, ky + 28)
      ..lineTo(cx + 12 + math.sin(t * 9 + 1) * 3, ky + 36)
      ..close();
    c.drawPath(bow, fillP(hex(0xfa5252)));
    circle(c, cx, ky, 8, hex(0xfa5252));
    for (final (side, team) in [(0, team1), (1, team2)]) {
      final dir = side > 0 ? 1.0 : -1.0, jerk = bump(pulse[side] / .14) * S * .025;
      for (var i = 0; i < team.length; i++) {
        final x = cx + dir * (S * .2 + i * sz * .85) + dir * jerk;
        final lose = end != null && winner != side + 1, win = end != null && winner == side + 1;
        final fall = lose ? math.min(1.0, endT * 2) : 0.0;
        drawFigure(c, x - dir * fall * S * .15, ground + sz * .05 + fall * 6, sz * 1.25, team[i],
            pose: win ? 'cheer' : (lose ? 'hurt' : 'pull'), t: t * (pulse[side] > 0 ? 2.2 : .6) + i, face: (-dir).round(), team: side > 0 ? kRed : kBlue);
      }
    }
    F.draw(c);
    C.end(c);
    rect(c, 0, 0, W / 2, H, rgba(51, 154, 240, .1));
    if (pvp) rect(c, W / 2, 0, W / 2, H, rgba(250, 82, 82, .1));
    Txt.draw(c, 'CHẠM THẬT NHANH!', W * .25, H * .9, size: (math.min(26, W * .04) * (1 + bump(pulse[0] / .14) * .15)).roundToDouble(), color: hex(0x1971c2));
    if (pvp) Txt.draw(c, 'CHẠM THẬT NHANH!', W * .75, H * .9, size: (math.min(26, W * .04) * (1 + bump(pulse[1] / .14) * .15)).roundToDouble(), color: hex(0xc92a2a));
    if (t < 2.4) vsIntro(c, 'Kéo dây qua vạch bên mình', 'Chạm liên tục vào nửa màn hình của mình');
    if (end != null && endT > .5) endVs(c, winner, '');
  }
}

// ---------- 4. Bóng đá đầu to: chạy, nhảy, húc bóng vào gôn đối thủ ----------
class SoccerGame extends VsGame {
  SoccerGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  late final FunTheme th = funTheme(lv);
  static const need = 3;
  late double ground, G, gw, gh, aiSp, aiJump;
  late List<Runner> P;
  late Ball ball;
  int a = 0, b = 0, winner = 0;
  double t = 0, endT = 0, pause = 0;
  final List<double> net = [0, 0];
  VsEnd? end;
  late Prerendered bg;

  void kick() {
    ball = Ball(W / 2, ground - S * .55, rnd(-60, 60), 0, S * .045);
    P[0].x = W * .3;
    P[1].x = W * .7;
    P[0].vx = P[1].vx = 0;
    pause = .9;
  }

  @override
  void setup() {
    ground = H * .74;
    G = S * 3.4;
    final r = math.min(52.0, math.min(S * .08, pvp ? (W / 2 - 24) / 6.8 : 99.0));
    B = sideControls(r);
    gw = S * .12;
    gh = S * .34;
    P = [Runner(W * .3, ground, S * .17), Runner(W * .7, ground, S * .17)];
    kick();
    aiSp = ramp(lv, .45, 1);
    aiJump = ramp(lv, .2, .8);
    bg = prerender((g) {
      sky(g, W, H, th);
      for (var i = 0; i < 2; i++) {
        gfx.draw(g, th.deco[i], W * (i > 0 ? .78 : .22), ground - S * .1, S * .2, S * .2, false, 0, .5);
      }
      for (var i = 0; i < 3; i++) {
        rect(g, 0, ground - S * (.06 + i * .05), W, S * .05, i % 2 == 1 ? rgba(73, 80, 87, .28) : rgba(73, 80, 87, .4));
      }
      rect(g, 0, ground - S * .07, W, 3, Colors.white);
      rect(g, 0, ground, W, H - ground, hex(0x51cf66));
      for (var x = 0.0; x < W; x += 80) {
        rect(g, x, ground, 40, H - ground, rgba(0, 0, 0, .06));
      }
      line(g, W / 2, ground, W / 2, H, Colors.white, 4, StrokeCap.butt);
      g.drawOval(Rect.fromCenter(center: Offset(W / 2, ground + (H - ground) * .45), width: S * .32, height: (H - ground) * .6), strokeP(Colors.white, 4));
    });
  }

  void scored(int side) {
    if (side == 1) {
      a++;
      pops[0] = 1;
      net[1] = 1;
      sfx('win');
      F.burst(W - gw / 2, ground - gh / 2, 34);
      F.text(W / 2, H * .4, 'VÀO!', 0xffd43b, 50);
    } else {
      b++;
      pops[1] = 1;
      net[0] = 1;
      sfx('wrong');
      F.text(W / 2, H * .4, pvp ? 'ĐỎ GHI BÀN!' : 'MÁY GHI BÀN!', 0xff8787, 40);
    }
    C.shake(10);
    C.stop(.12);
    later(.7, () {
      if (end == null) kick();
    });
    pause = 99;
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    decay(pops, rdt);
    decay(net, rdt, 1.2);
    if (end != null) {
      endT += rdt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    final bt = B!;
    runStep(this, P[0], bt.down('l1'), bt.down('r1'), bt.hit('j1'), dt, ground, G, F);
    if (pvp) {
      runStep(this, P[1], bt.down('l2'), bt.down('r2'), bt.hit('j2'), dt, ground, G, F);
    } else {
      final p = P[1], want = ball.x + S * .06;
      final go = (want - p.x).abs() > 10 && rnd01() < aiSp + .2;
      runStep(this, p, go && want < p.x, go && want > p.x, ball.y < p.y - p.w && (ball.x - p.x).abs() < p.w && rnd01() < aiJump * dt * 8, dt, ground, G, F, sp: .62 * aiSp);
    }
    for (final p in P) {
      p.x = clamp(p.x, gw + p.w * .3, W - gw - p.w * .3);
    }
    ball.born += dt;
    ball.sq = math.max(0, ball.sq - dt * 2.5);
    if (pause > 0) {
      pause -= dt;
      return null;
    }
    ball.vy += G * .55 * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.rot += ball.vx * dt / ball.r;
    if (ball.y > ground - ball.r) {
      ball.y = ground - ball.r;
      if (ball.vy > S * .5) {
        ball.sq = math.min(.3, ball.vy / (S * 6));
        F.dust(ball.x, ground, 3);
      }
      ball.vy = -ball.vy.abs() * .68;
      ball.vx *= math.exp(-dt * 3);
    }
    if (ball.y < 90 + ball.r) {
      ball.y = 90 + ball.r;
      ball.vy = ball.vy.abs();
    }
    for (final gx in [0.0, W - gw]) {
      if (ball.x > gx && ball.x < gx + gw && (ball.y - (ground - gh)).abs() < ball.r) {
        ball.vy = -ball.vy * .8;
        ball.y += ball.vy > 0 ? ball.r : -ball.r;
        sfx('tap');
        F.sparks(ball.x, ground - gh, 5);
        C.shake(3);
      }
    }
    for (final p in P) {
      headHit(this, ball, p.x, p.y - p.w * .55, p.w * .48 + ball.r, p, S * 1.1, S * .3, F);
    }
    if (ball.x < ball.r) {
      if (ball.y > ground - gh) {
        scored(2);
      } else {
        ball.x = ball.r;
        ball.vx = ball.vx.abs() * .8;
      }
    }
    if (ball.x > W - ball.r) {
      if (ball.y > ground - gh) {
        scored(1);
      } else {
        ball.x = W - ball.r;
        ball.vx = -ball.vx.abs() * .8;
      }
    }
    if (a >= need || b >= need) {
      winner = a >= need ? 1 : 2;
      end = VsEnd(winner, a * 5);
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    clouds(c, W, H, t, 3, .1);
    C.begin(c);
    for (final (k, gx) in [(0, 0.0), (1, W - gw)]) {
      final bulge = bump(1 - net[k]) * net[k] * gw * .5 * (k > 0 ? 1 : -1);
      final ns = strokeP(rgba(255, 255, 255, .55), 1.5);
      final netP = Path();
      for (var y = ground - gh; y <= ground; y += 12) {
        final q = math.sin((y - (ground - gh)) / gh * math.pi);
        netP
          ..moveTo(gx, y)
          ..lineTo(gx + gw / 2 + bulge * q, y)
          ..lineTo(gx + gw, y);
      }
      for (var x = 0.0; x <= gw; x += 12) {
        netP
          ..moveTo(gx + x, ground - gh)
          ..quadraticBezierTo(gx + x + bulge, ground - gh / 2, gx + x, ground);
      }
      c.drawPath(netP, ns);
      final post = Path()
        ..moveTo(k > 0 ? gx : gx + gw, ground)
        ..lineTo(k > 0 ? gx : gx + gw, ground - gh)
        ..lineTo(k > 0 ? gx + gw : gx, ground - gh);
      c.drawPath(post, strokeP(Colors.white, 7, cap: StrokeCap.round));
      rect(c, gx, ground - gh - 10, gw, 8, k > 0 ? kRed : kBlue);
    }
    shadow(c, ball.x, ground + 4, ball.r * 1.1, ground - ball.y, .25);
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      shadow(c, p.x, ground + 4, p.w * .35, ground - p.y, .2);
      final pose = end != null ? (winner == k + 1 ? 'cheer' : 'hurt') : (p.y < ground - 2 ? 'jump' : (p.vx.abs() > 25 ? 'run' : 'idle'));
      drawFigure(c, p.x, p.y, p.w * .62, withShirt(COS[k], k > 0 ? kRed : kBlue), pose: pose, t: t + k, face: k > 0 ? -1 : 1, noHead: true);
      drawHead(c, p.x, p.y - p.w * .55, p.w * .42, COS[k], face: k > 0 ? -1 : 1, t: t);
    }
    final bs = pause > 0 ? outBack(math.min(1, ball.born / .45)) : 1.0;
    if (bs > 0) drawBall(c, gfx, 'Soccer ball', ball, bs);
    F.draw(c);
    C.end(c);
    B!.draw(c);
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Ghi $need bàn trước', '◀ ▶ chạy · ⬆ nhảy · húc bóng vào gôn bên phải');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}

// ---------- 5. Bóng chuyền: đánh bóng qua lưới, bóng rơi sân bên nào thì bên kia được điểm ----------
class VolleyGame extends VsGame {
  VolleyGame(FunGameContext ctx, Gfx gfx, String mode) : super(ctx: ctx, gfx: gfx, mode: mode);
  static const need = 5;
  late double ground, G, netH, netX, aiSp, aiRead;
  late List<Runner> P;
  late Ball ball;
  int a = 0, b = 0, winner = 0;
  double t = 0, endT = 0, pause = 0, netWob = 0;
  VsEnd? end;
  late Prerendered bg;

  void serve(int side) {
    ball = Ball(side == 1 ? W * .25 : W * .75, ground - S * .55, 0, 0, S * .04);
    pause = .9;
  }

  @override
  void setup() {
    ground = H * .76;
    G = S * 2.2;
    final r = math.min(52.0, math.min(S * .08, pvp ? (W / 2 - 24) / 6.8 : 99.0));
    B = sideControls(r);
    netH = S * .26;
    netX = W / 2;
    P = [Runner(W * .25, ground, S * .16), Runner(W * .75, ground, S * .16)];
    serve(1);
    aiSp = ramp(lv, .5, 1.05);
    aiRead = ramp(lv, .4, 1);
    bg = prerender((g) {
      g.drawRect(Rect.fromLTWH(0, 0, W, H),
          Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [hex(0x4dabf7), hex(0xd0ebff), hex(0xe7f5ff)], stops: const [0, .6, 1]).createShader(Rect.fromLTWH(0, 0, W, H)));
      rect(g, 0, ground - S * .08, W, S * .08, hex(0x1c7ed6));
      for (var i = 0; i < 14; i++) {
        rect(g, (i * 97) % W, ground - S * .06 + (i % 3) * 8, 30, 3, rgba(255, 255, 255, .5));
      }
      gfx.draw(g, 'Palm tree', W * .06, ground - S * .18, S * .36);
      gfx.draw(g, 'Palm tree', W * .94, ground - S * .18, S * .36, S * .36, true);
      rect(g, 0, ground, W, H - ground, hex(0xffe8a3));
      for (var i = 0; i < 70; i++) {
        circle(g, (i * 61.7) % W, ground + 6 + (i * 37) % math.max(1, H - ground - 6), 2, i % 2 == 1 ? rgba(201, 162, 122, .35) : rgba(255, 255, 255, .4));
      }
    });
  }

  void point(int side) {
    if (side == 2) {
      b++;
      pops[1] = 1;
      sfx('wrong');
      F.text(W * .25, H * .4, '+1 bên đỏ', 0xff8787, 32);
    } else {
      a++;
      pops[0] = 1;
      sfx('win');
      F.text(W * .75, H * .4, '+1 bên xanh', 0x74c0fc, 32);
    }
    F.burst(ball.x, ground, 16, [0xffe8a3, 0xe9c46a, 0xffffff]);
    F.ring(ball.x, ground, 40, 0xffffff, 5);
    C.shake(6);
    pause = 99;
    later(.65, () {
      if (end == null) serve(side);
    });
  }

  @override
  Object? step(double rdt) {
    t += rdt;
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    F.update(dt);
    decay(pops, rdt);
    netWob = math.max(0, netWob - rdt * 1.5);
    if (end != null) {
      endT += rdt;
      return endT > 2.2 ? end : null;
    }
    if (t < 2.4) return null;
    final bt = B!;
    runStep(this, P[0], bt.down('l1'), bt.down('r1'), bt.hit('j1'), dt, ground, G * 1.6, F, sp: .7, jump: 1.35);
    if (pvp) {
      runStep(this, P[1], bt.down('l2'), bt.down('r2'), bt.hit('j2'), dt, ground, G * 1.6, F, sp: .7, jump: 1.35);
    } else {
      final p = P[1];
      var land = ball.x + ball.vx * aiRead * .9;
      if (ball.x < netX) land = W * .75;
      final want = math.max(netX + p.w * .6, land + p.w * .18);
      runStep(this, p, want < p.x - 8, want > p.x + 8, ball.x > netX && ball.y < p.y - p.w * 1.2 && (ball.x - p.x).abs() < p.w * .8 && rnd01() < .2, dt, ground, G * 1.6, F, sp: .7 * aiSp, jump: 1.35);
    }
    P[0].x = clamp(P[0].x, P[0].w * .4, netX - P[0].w * .5);
    P[1].x = clamp(P[1].x, netX + P[1].w * .5, W - P[1].w * .4);
    ball.born += dt;
    ball.sq = math.max(0, ball.sq - dt * 2.5);
    if (pause > 0) {
      pause -= dt;
      return null;
    }
    ball.vy += G * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.rot += (ball.vx * .6 / ball.r + ball.spin * 20) * dt;
    if (ball.x < ball.r || ball.x > W - ball.r) {
      ball.vx = -ball.vx;
      ball.x = clamp(ball.x, ball.r, W - ball.r);
    }
    if ((ball.x - netX).abs() < ball.r + 4 && ball.y > ground - netH) {
      ball.vx = -ball.vx * .6;
      ball.x = netX + (ball.x < netX ? -1 : 1) * (ball.r + 5);
      netWob = 1;
      sfx('tap');
    }
    for (final p in P) {
      final hy = p.y - p.w * .5;
      if (ball.y - hy < p.w * .3 && headHit(this, ball, p.x, hy, p.w * .5 + ball.r, p, S * 1.25, 0, F)) {
        final sp = S * 1.25, d = hypot(ball.vx, ball.vy);
        final dd = d == 0 ? 1 : d;
        ball.vx = ball.vx / dd * sp * .8;
        ball.vy = math.min(-S * .9, ball.vy / dd * sp);
        if (p.y < ground - p.w * .4) {
          F.sparks(ball.x, ball.y, 8, 0xfff3bf);
          C.shake(3);
        }
      }
    }
    if (ball.y > ground - ball.r) point(ball.x < netX ? 2 : 1);
    if (a >= need || b >= need) {
      winner = a >= need ? 1 : 2;
      end = VsEnd(winner, a * 5);
    }
    return null;
  }

  @override
  void paint(Canvas c) {
    bg.draw(c);
    clouds(c, W, H, t, 3, .08);
    gfx.draw(c, 'Sun with face', W * .5, H * .14, S * .12, S * .12, false, math.sin(t) * .05);
    C.begin(c);
    if (pause <= 0 && ball.vy > -S * .2) {
      final dy = ground - ball.r - ball.y, tt = (-ball.vy + math.sqrt(math.max(0, ball.vy * ball.vy + 2 * G * dy))) / G, lx = ball.x + ball.vx * tt;
      if (lx > 0 && lx < W) c.drawOval(Rect.fromCenter(center: Offset(lx, ground + 6), width: ball.r * 2.6, height: ball.r * .8), strokeP(rgba(250, 82, 82, .5), 3));
    }
    rect(c, netX - 4, ground - netH - 6, 8, netH + 6, hex(0x868e96));
    final wob = math.sin(t * 40) * netWob * 6;
    final ns = strokeP(rgba(255, 255, 255, .95), 2);
    for (var y = ground - netH; y < ground - netH * .45; y += 10) {
      final k = (y - (ground - netH)) / (netH * .55);
      c.drawLine(Offset(netX - 12 + wob * k, y), Offset(netX + 12 + wob * k, y), ns);
    }
    for (final dx in [-12.0, 0.0, 12.0]) {
      c.drawLine(Offset(netX + dx, ground - netH), Offset(netX + dx + wob, ground - netH * .45), ns);
    }
    rect(c, netX - 14, ground - netH - 4, 28, 5, Colors.white);
    shadow(c, ball.x, ground + 4, ball.r * 1.1, ground - ball.y, .25);
    for (var k = 0; k < 2; k++) {
      final p = P[k];
      shadow(c, p.x, ground + 4, p.w * .35, ground - p.y, .2);
      final pose = end != null ? (winner == k + 1 ? 'cheer' : 'hurt') : (p.y < ground - 2 ? 'cheer' : (p.vx.abs() > 25 ? 'run' : 'idle'));
      drawFigure(c, p.x, p.y, p.w * .7, withShirt(COS[k], k > 0 ? kRed : kBlue), pose: pose, t: t + k, face: k > 0 ? -1 : 1, noHead: true);
      drawHead(c, p.x, p.y - p.w * .5, p.w * .36, COS[k], face: k > 0 ? -1 : 1, t: t);
    }
    if (ball.y < 100) {
      final path = Path()
        ..moveTo(ball.x, 96)
        ..lineTo(ball.x - 10, 110)
        ..lineTo(ball.x + 10, 110)
        ..close();
      c.drawPath(path, fillP(hex(0xffd43b)));
    }
    final bs = pause > 0 ? outBack(math.min(1, ball.born / .45)) : 1.0;
    if (bs > 0) drawBall(c, gfx, 'Volleyball', ball, bs);
    F.draw(c);
    C.end(c);
    B!.draw(c);
    scoreBar(c, a, b, need);
    if (t < 2.4) vsIntro(c, 'Được $need điểm trước', '◀ ▶ chạy · ⬆ nhảy · đỡ bóng sang sân bên kia');
    if (end != null) endVs(c, winner, '$a : $b');
  }
}
