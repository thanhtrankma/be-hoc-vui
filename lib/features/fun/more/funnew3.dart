// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Chạy 3 làn, cá con, bóng rổ, vượt rào, nhảy theo nhạc, golf mini (sprite Kenney).
// CHỦ: agent F. Port của web js/games/funnew3.js. Mỗi lượt một cấp (ctx.level 0..59).
// Nhân vật/con vật là sprite Kenney CC0 có khung hoạt ảnh (assets/sprites/play), vẽ bằng drawFrame/drawAnimC.
// g.bot = tự chơi (chỉ dùng khi test).
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:flutter/painting.dart' show Offset;

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funnew3Games = {
  'lanes': const FunCanvasModule('lanes', lanes),
  'swim': const FunCanvasModule('swim', swim),
  'hoops': const FunCanvasModule('hoops', hoops),
  'hurdles': const FunCanvasModule('hurdles', hurdles),
  'dance': const FunCanvasModule('dance', dance),
  'golf': const FunCanvasModule('golf', golf),
};

double _sign(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

// ---------- 1. Chạy 3 làn: bé chạy trên 3 làn đường, vuốt lên/xuống (hoặc chạm làn) để đổi làn, chạm vào bé để nhảy.
// Sên, bọ rùa, chuột thì nhảy qua được; thùng gỗ và ong thì phải đổi làn. Ăn xu, chạy đủ số mét. ----------
class _LObs {
  _LObs(this.lane, this.x, this.k, {this.hard = false, this.ph = 0});
  final int lane;
  double x;
  final String k;
  final bool hard;
  final double ph;
}

class _LCoin {
  _LCoin(this.lane, this.x, this.z);
  final int lane;
  double x;
  final double z;
}

class _Deco {
  _Deco(this.x, this.k, this.s);
  double x;
  String k;
  final double s;
}

Future<LoopGame> lanes(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 250, 1100).round(), kid = kidOf(g.hero), tr = g.tr, bot = g.bot;
  final SH = await playSheets([kid, 'critters', 'items']);
  await loadAll(['Red heart', 'Coin', ...themeImgs(lv)]);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final LY = [H * .58, H * .73, H * .88], LS = [.8, .9, 1.0], ph = math.min(S * .32, H * .17);
  var meLane = 1;
  double meLf = 1, meZ = 0, meVz = 0, meInv = 0, meHurt = 0;
  final meX = W * .24;
  final G = ph * 9, JV = math.sqrt(2 * G * ph * .62);
  final obs = <_LObs>[], coins = <_LCoin>[];
  final deco = List.generate(6, (i) => _Deco(i * W / 5 + rand(0, 60), pick(th.deco), rand(.7, 1.1)));
  double dist = 0, t = 0, spawn = 1.4, endT = 0;
  var lives = 3, coinN = 0;
  FunEnd? end;
  const GROUND = ['slime', 'snail', 'ladybug', 'mouse'];
  int laneAt(double y) {
    var b = 0;
    for (var i = 1; i < 3; i++) {
      if ((y - (LY[i] - ph * .4)).abs() < (y - (LY[b] - ph * .4)).abs()) b = i;
    }
    return b;
  }

  void jump() {
    if (meZ <= 0 && end == null) {
      meVz = JV;
      g.sfx('jump');
    }
  }

  void toLane(int d) {
    final n = math.max(0, math.min(2, meLane + d));
    if (n != meLane) {
      meLane = n;
      g.sfx('flip');
    }
  }

  g.taps(
    onTap: (x, y) {
      if (t < 2 || end != null) return;
      final l = laneAt(y);
      if (l == meLane) {
        jump();
      } else {
        toLane(l > meLane ? 1 : -1);
      }
    },
    onSwipe: (dx, dy, _, _) {
      if (t < 2 || end != null) return;
      if (dy.abs() > dx.abs()) {
        toLane(dy > 0 ? 1 : -1);
      } else {
        jump();
      }
    },
  );
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      final v = S * ramp(lv, .62, 1.0) * (1 + math.min(.2, dist / 4000));
      dist += v * dt / (S * .1);
      meLf += (meLane - meLf) * math.min(1, dt * 14);
      if (meZ > 0 || meVz > 0) {
        meVz -= G * dt;
        meZ += meVz * dt;
        if (meZ <= 0) {
          meZ = 0;
          meVz = 0;
        }
      }
      meInv = math.max(0, meInv - dt);
      meHurt = math.max(0, meHurt - dt);
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.9, 1.4) * ramp(lv, 1.35, .72);
        // Làn chặn cứng (thùng/ong) tối đa 2 làn, luôn chừa 1 làn đi được.
        final hard = lv >= 6 ? (random() < ramp(lv, .35, .6) ? (lv >= 30 && random() < .4 ? 2 : 1) : 0) : 0;
        final ls = shuffleInPlace([0, 1, 2]);
        if (hard == 2) spawn += .55; // chặn 2 làn thì chừa thời gian đổi làn
        for (var i = 0; i < hard; i++) {
          obs.add(lv >= 15 && random() < .4 ? _LObs(ls[i], W + 80, 'bee', hard: true, ph: rand(0, 6)) : _LObs(ls[i], W + 80, 'crate', hard: true));
        }
        final soft = random() < ramp(lv, .55, .9) ? 1 : 0;
        if (soft != 0 && hard < 3) {
          obs.add(_LObs(hard == 0 && random() < .5 ? meLane : ls[hard], W + 80 + rand(0, S * .3), pick(GROUND.sublist(0, 2 + math.min(2, lv ~/ 8)))));
        }
        if (random() < .55) {
          final l = ls[2];
          for (var i = 0; i < 5; i++) {
            coins.add(_LCoin(l, W + S * .5 + i * S * .09, lv >= 10 && i > 0 && i < 4 ? ph * .35 : 0));
          }
        }
      }
      final cur = meLf.round();
      for (var i = obs.length - 1; i >= 0; i--) {
        final o = obs[i];
        o.x -= v * dt * (o.k == 'snail' ? .9 : o.k == 'mouse' ? 1.15 : 1);
        if (o.x < -100) {
          obs.removeAt(i);
          continue;
        }
        if (meInv <= 0 && o.lane == cur && (o.x - meX).abs() < ph * .28 * LS[o.lane] && (o.hard || meZ < ph * .2)) {
          lives--;
          meInv = 1.5;
          meHurt = .5;
          g.sfx('hit');
          F.burst(meX, LY[cur] - ph * .5, 14, ['#ff6b6b', '#ffd43b']);
          if (lives <= 0) {
            end = FunEnd(win: false, score: (dist / 10).round() + coinN);
            g.sfx('wrong');
          }
        }
      }
      for (var i = coins.length - 1; i >= 0; i--) {
        final co = coins[i];
        co.x -= v * dt;
        if (co.x < -40) {
          coins.removeAt(i);
          continue;
        }
        if (co.lane == cur && (co.x - meX).abs() < ph * .25 && (co.z - meZ).abs() < ph * .4) {
          coins.removeAt(i);
          coinN++;
          g.sfx('coin');
          F.text(meX, LY[cur] - ph * 1.1, '+1', '#ffd43b');
        }
      }
      for (final d in deco) {
        d.x -= v * dt * .25;
        if (d.x < -120) {
          d.x = W + 120;
          d.k = pick(th.deco);
        }
      }
      if (bot) {
        // tự chơi khi test: né thùng/ong bằng đổi làn, nhảy qua sên
        for (final o in obs) {
          if (o.lane == meLane && o.x > meX && o.x - meX < ph * (o.hard ? 2.6 : .7)) {
            if (o.hard) {
              final free = [0, 1, 2].where((l) => !obs.any((p) => p.hard && p.lane == l && (p.x - o.x).abs() < ph * 1.5)).toList()
                ..sort((a, b) => (a - meLane).abs() - (b - meLane).abs());
              if (free.isNotEmpty) toLane(_sign((free[0] - meLane).toDouble()).toInt());
            } else {
              jump();
            }
          }
        }
      }
      if (dist >= need && end == null) {
        end = FunEnd(win: true, score: (need / 10).round() + coinN * 2 + lives * 5);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      skyFill(c, W, H, th);
      draw(c, th.sun, W * .86, H * .12, S * .12);
      final top = LY[0] - ph * .95;
      for (final d in deco) {
        drawO(c, d.k, d.x, top - S * .1 * d.s, S * .22 * d.s, h: S * .22 * d.s, alpha: .8);
      }
      // Mặt đường 3 làn
      c.fillStyle = hex(th.edge);
      c.fillRect(0, top, W, H - top);
      final band = LY[1] - LY[0];
      for (var i = 0; i < 3; i++) {
        c.fillStyle = i % 2 == 1 ? hex(th.ground) : 'rgba(255,255,255,.18)';
        c.fillRect(0, LY[i] - band * .78, W, band * .9);
        c.fillStyle = 'rgba(255,255,255,.55)';
        final off = (dist * S * .1) % 80;
        for (var x = -off; x < W; x += 80) {
          c.fillRect(x, LY[i] + band * .1, 40, 4);
        }
      }
      final cur = meLf.round();
      for (var l = 0; l < 3; l++) {
        final sc = LS[l];
        for (final co in coins) {
          if (co.lane == l) drawAnimC(c, SH['items'], 'coin', t + co.x * .002, co.x, LY[l] - ph * .22 * sc - co.z, ph * .26 * sc);
        }
        for (final o in obs) {
          if (o.lane != l) continue;
          final y = LY[l];
          shadow(c, o.x, y, ph * .4 * sc);
          if (o.k == 'crate') {
            drawFrame(c, SH['items'], 'block_planks', o.x, y - ph * .2 * sc, ph * .4 * sc);
            drawFrame(c, SH['items'], 'block_planks', o.x, y - ph * .6 * sc, ph * .4 * sc);
          } else if (o.k == 'bee') {
            drawAnimC(c, SH['critters'], 'bee', t, o.x, y - ph * .55 * sc + math.sin(t * 6 + o.ph) * 6, ph * .38 * sc);
          } else {
            drawAnimC(c, SH['critters'], o.k, t, o.x, y - ph * .16 * sc, ph * (o.k == 'mouse' ? .3 : .34) * sc);
          }
        }
        if (l == cur) {
          final sc2 = LS[0] + (LS[2] - LS[0]) * meLf / 2, y = LY[0] + (LY[2] - LY[0]) * meLf / 2;
          shadow(c, meX, y, ph * .45 * sc2 * (1 - math.min(.5, meZ / ph)));
          final blink = meInv > 0 && (meInv * 10).floor() % 2 == 1;
          final an = end?.win == true ? 'cheer' : meHurt > 0 ? 'hurt' : meZ > 0 ? (meVz > 0 ? 'jump' : 'fall') : 'run';
          if (!blink) drawAnimC(c, SH[kid], an, t, meX, y - meZ, ph * sc2);
        }
      }
      F.draw(c);
      hud(c, W, score: coinN);
      hearts(c, W, lives);
      final m = math.min(need, dist.floor());
      pill(c, W, '🏃 $m/$need m', W < 640 ? 62 : 10);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Chạy $need mét', 'Run $need meters'),
            tr('Vuốt lên/xuống đổi làn · Chạm vào bé để nhảy', 'Swipe up/down to change lanes · Tap your runner to jump'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('VẤP NGÃ RỒI!', 'YOU TRIPPED!'), tr('$m/$need mét', '$m/$need meters'));
    },
  );
}

// ---------- 2. Cá con đại dương: kéo ngón tay để cá vàng bơi theo, nhặt ngọc, né cá gai, lươn, cá nóc, cá đỏ to ----------
class _Gem {
  _Gem(this.x, this.y, this.k, this.ph);
  final double x, y;
  final String k;
  double ph;
}

class _Foe {
  _Foe(this.k, this.x, this.y, this.s, {this.vx = 0, this.ph = 0, this.wait = 0});
  final String k;
  double x, y, vx, vy = 0, ph, s, wait, cd = 0;
  double? cur;
}

class _Swimmer {
  _Swimmer(this.k, this.x, this.y, this.v, this.s);
  final String k;
  double x;
  final double y, v, s;
}

class _Bubble {
  _Bubble(this.x, this.y, this.v, this.k, this.s);
  double x, y;
  final double v, s;
  final String k;
}

class _Weed {
  _Weed(this.x, this.k, this.s, this.ph);
  final double x, s, ph;
  final String k;
}

Future<LoopGame> swim(Fun g) async {
  final lv = g.level, need = ramp(lv, 10, 26).round(), tr = g.tr, bot = g.bot;
  final SH = await playSheets(['critters', 'sea', 'items']);
  await loadAll(['Red heart', 'Coin']);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), fs = S * .13;
  double meX = W * .3, meY = H * .5, meVx = 0, meVy = 0, meFace = 1, meInv = 0;
  Offset? target;
  var got = 0, lives = 3;
  double t = 0, endT = 0;
  FunEnd? end;
  const GEMS = ['gem_blue', 'gem_green', 'gem_red', 'gem_yellow', 'star'];
  final gems = <_Gem>[], foes = <_Foe>[];
  void addGem() => gems.add(_Gem(rand(W * .08, W * .92), rand(H * .2, H * .82), pick(GEMS), rand(0, 6)));
  for (var i = 0; i < 4; i++) {
    addGem();
  }
  final nP = math.min(4, 1 + lv ~/ 12);
  for (var i = 0; i < nP; i++) {
    foes.add(_Foe('fishP', rand(W * .55, W * .95), rand(H * .2, H * .85), fs * .9, ph: rand(0, 6)));
  }
  if (lv >= 8) foes.add(_Foe('eel', -200, rand(H * .3, H * .8), fs * 1.3, vx: S * ramp(lv, .3, .55), wait: rand(1, 3)));
  if (lv >= 15) foes.add(_Foe('puffer', rand(W * .4, W * .8), rand(H * .3, H * .7), fs));
  if (lv >= 25) foes.add(_Foe('big', W + 150, H * .5, fs * 1.8));
  final friends = List.generate(5, (_) => _Swimmer(pick(['fish_blue', 'fish_pink', 'fish_orange', 'fish_green']), rand(0, W), rand(H * .15, H * .7), rand(20, 50) * (random() < .5 ? 1 : -1), rand(.5, .8)));
  final bubbles = List.generate(14, (_) => _Bubble(rand(0, W), rand(0, H), rand(30, 70), pick(['bubble_a', 'bubble_b', 'bubble_c']), rand(.15, .35)));
  final weeds = List.generate((W / 70).ceil(),
      (i) => _Weed(i * 70 + rand(-10, 10), pick(['seaweed_green_a', 'seaweed_green_b', 'seaweed_pink_a', 'seaweed_orange_a', 'seaweed_grass_a']), rand(.8, 1.4), rand(0, 6)));
  final SP = S * ramp(lv, .75, .95);
  g.taps(onDownXY: (x, y) => target = Offset(x, y), onMoveXY: (x, y, _) => target = Offset(x, y), onUpXY: (_, _, _) => target = null);
  bool hitR(double ax, double ay, double r) => hypot(ax - meX, ay - meY) < r;
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      for (final b in bubbles) {
        b.y -= b.v * dt;
        if (b.y < -20) {
          b.y = H + 20;
          b.x = rand(0, W);
        }
      }
      for (final f in friends) {
        f.x += f.v * dt;
        if (f.x < -80) f.x = W + 80;
        if (f.x > W + 80) f.x = -80;
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (bot) {
        // tự chơi khi test: bơi tới ngọc gần nhất, né cá dữ ở gần
        final gm = gems.reduce((a, b) => hypot(b.x - meX, b.y - meY) < hypot(a.x - meX, a.y - meY) ? b : a);
        var tx = gm.x - meX, ty = gm.y - meY;
        final d0 = hypot(tx, ty) == 0 ? 1.0 : hypot(tx, ty);
        tx /= d0;
        ty /= d0;
        for (final f in foes) {
          if (f.wait > 0) continue;
          final dx = meX - f.x, dy = meY - f.y, d = hypot(dx, dy) == 0 ? 1.0 : hypot(dx, dy), R = (f.cur ?? f.s) + fs * 1.6;
          if (d < R) {
            tx += dx / d * 2.5 * (R - d) / R * 2;
            ty += dy / d * 2.5 * (R - d) / R * 2;
          }
        }
        target = Offset(meX + tx * 100, meY + ty * 100);
      }
      final tg = target;
      if (tg != null) {
        final dx = tg.dx - meX, dy = tg.dy - meY, d = hypot(dx, dy);
        if (d > 6) {
          meVx += (dx / d * SP - meVx) * math.min(1, dt * 5);
          meVy += (dy / d * SP - meVy) * math.min(1, dt * 5);
        }
        if (d < 30) {
          meVx *= .9;
          meVy *= .9;
        }
      } else {
        meVx *= math.pow(.2, dt);
        meVy *= math.pow(.2, dt);
      }
      meX = math.max(fs / 2, math.min(W - fs / 2, meX + meVx * dt));
      meY = math.max(fs / 2 + 60, math.min(H - fs / 2, meY + meVy * dt));
      if (meVx.abs() > 20) meFace = meVx > 0 ? 1 : -1;
      meInv = math.max(0, meInv - dt);
      for (var i = gems.length - 1; i >= 0; i--) {
        final gm = gems[i];
        gm.ph += dt;
        if (hitR(gm.x, gm.y, fs * .55)) {
          gems.removeAt(i);
          got++;
          g.sfx('coin');
          F.burst(gm.x, gm.y, 10, ['#ffd43b', '#74c0fc', '#fff']);
          F.text(gm.x, gm.y - 30, '$got/$need', '#ffd43b');
          addGem();
          if (got >= need) {
            end = FunEnd(win: true, score: got * 5 + lives * 5);
            g.sfx('win');
          }
        }
      }
      final sp = ramp(lv, .14, .28) * S;
      for (final f in foes) {
        if (f.k == 'fishP') {
          f.ph += dt * .7;
          f.vx = math.cos(f.ph) * sp;
          f.vy = math.sin(f.ph * 1.3) * sp * .7;
        } else if (f.k == 'eel') {
          if (f.wait > 0) {
            f.wait -= dt;
            continue;
          }
          f.x += f.vx * dt;
          if (f.x > W + 200) {
            f.x = -200;
            f.y = rand(H * .25, H * .85);
            f.wait = rand(1.5, 4);
          }
          continue;
        } else if (f.k == 'puffer') {
          f.ph += dt;
          f.vx = math.cos(f.ph * .5) * sp * .5;
          f.vy = math.sin(f.ph * .4) * sp * .4;
        } else if (f.k == 'big') {
          // cá đỏ to: đuổi 3 giây rồi nghỉ (bơi chậm ra xa) 3 giây, cắn trúng thì lùi ra xa
          f.cd -= dt;
          if (f.cd < -3) f.cd = 3;
          final dx = meX - f.x, dy = meY - f.y, d = hypot(dx, dy) == 0 ? 1.0 : hypot(dx, dy), k = f.cd > 0 ? -.25 : ramp(lv, .3, .45);
          f.vx = dx / d * SP * k;
          f.vy = dy / d * SP * k;
        }
        f.x = math.max(f.s / 2, math.min(W - f.s / 2, f.x + f.vx * dt));
        f.y = math.max(80, math.min(H - f.s / 2, f.y + f.vy * dt));
        if (f.k == 'puffer') f.cur = f.s * (1 + .35 * math.max(0, math.sin(t * 1.6)));
      }
      if (meInv <= 0) {
        for (final f in foes) {
          final r = (f.cur ?? f.s) * (f.k == 'eel' ? .3 : .32) + fs * .25;
          final hx = f.k == 'eel' ? (f.x - meX).abs() < f.s * .5 && (f.y - meY).abs() < f.s * .2 : hypot(f.x - meX, f.y - meY) < r;
          if (hx) {
            lives--;
            meInv = 2;
            for (final b in foes) {
              if (b.k == 'big') b.cd = 3;
            }
            g.sfx('hit');
            F.burst(meX, meY, 12, ['#ff8787', '#fff']);
            if (lives <= 0) {
              end = FunEnd(win: false, score: got * 5);
              g.sfx('wrong');
            }
            break;
          }
        }
      }
      return null;
    },
    draw: () {
      final gr = c.createLinearGradient(0, 0, 0, H);
      gr.addColorStop(0, '#4dabf7');
      gr.addColorStop(.55, '#1c7ed6');
      gr.addColorStop(1, '#0b4f8a');
      c.fillStyle = gr;
      c.fillRect(0, 0, W, H);
      c.fillStyle = 'rgba(255,255,255,.07)';
      for (var i = 0; i < 5; i++) {
        final x = i * W / 4 + math.sin(t * .3 + i) * 40;
        c.beginPath();
        c.moveTo(x - 30, 0);
        c.lineTo(x + 30, 0);
        c.lineTo(x + 140, H);
        c.lineTo(x + 40, H);
        c.fill();
      }
      for (final f in friends) {
        drawFrame(c, SH['sea'], f.k, f.x, f.y, fs * f.s, flip: f.v < 0, alpha: .45);
      }
      c.fillStyle = '#f1d9a6';
      c.fillRect(0, H - 26, W, 26);
      for (final w in weeds) {
        c.save();
        c.translate(w.x, H - 18);
        c.rotate(math.sin(t * 1.5 + w.ph) * .12);
        drawFrame(c, SH['sea'], w.k, 0, -fs * .45 * w.s, fs * .9 * w.s);
        c.restore();
      }
      drawFrame(c, SH['sea'], 'rock_a', W * .15, H - 40, fs * .9);
      drawFrame(c, SH['sea'], 'rock_b', W * .72, H - 36, fs * .8);
      for (final b in bubbles) {
        drawFrame(c, SH['sea'], b.k, b.x, b.y, fs * b.s, alpha: .7);
      }
      for (final gm in gems) {
        final s = fs * .5 * (1 + math.sin(gm.ph * 4) * .08);
        drawFrame(c, SH['items'], gm.k, gm.x, gm.y + math.sin(gm.ph * 2) * 6, s);
      }
      for (final f in foes) {
        if (f.k == 'fishP') {
          drawAnimC(c, SH['critters'], 'fishP', t, f.x, f.y, f.s);
        } else if (f.k == 'eel') {
          if (f.wait <= 0) drawAnimC(c, SH['sea'], 'eel', t, f.x, f.y, f.s);
        } else if (f.k == 'puffer') {
          drawFrame(c, SH['sea'], 'fish_brown', f.x, f.y, f.cur ?? f.s, flip: f.vx < 0);
        } else if (f.k == 'big') {
          drawFrame(c, SH['sea'], 'fish_red', f.x, f.y + math.sin(t * 3) * 4, f.s, flip: f.vx < 0);
        }
      }
      final blink = meInv > 0 && (meInv * 10).floor() % 2 == 1;
      if (!blink) {
        drawAnimC(c, SH['critters'], 'fishY', t * (1 + hypot(meVx, meVy) / SP), meX, meY, fs,
            flip: meFace > 0, rot: math.max(-.4, math.min(.4, meVy / SP * .5)) * meFace);
      }
      F.draw(c);
      hud(c, W, score: got);
      hearts(c, W, lives);
      goalPill(c, W, got, need, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Nhặt $need viên ngọc', 'Collect $need gems'),
            tr('Giữ và kéo ngón tay, cá con bơi theo · Né cá gai', 'Hold and drag, the little fish follows · Avoid the spiky fish'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT LƯỢT BƠI!', 'OUT OF LIVES!'), tr('$got/$need viên ngọc', '$got/$need gems'));
    },
  );
}

// ---------- 3. Ném bóng rổ: vuốt từ quả bóng về phía rổ (vuốt dài = ném mạnh). Rổ di chuyển ở cấp cao. ----------
class _Ball {
  _Ball(this.x, this.y);
  double x, y, vx = 0, vy = 0, life = 0, rot = 0;
  bool fly = false, scored = false;
}

class _Drag {
  _Drag(this.x0, this.y0) : x = x0, y = y0;
  final double x0, y0;
  double x, y;
}

Future<LoopGame> hoops(Fun g) async {
  final lv = g.level, th = theme(lv), need = math.min(12, 3 + lv ~/ 7), kid = kidOf(g.hero), tr = g.tr, bot = g.bot;
  final SH = await playSheets([kid]);
  await loadAll(['Basketball', 'Red heart', 'Coin', ...themeImgs(lv)]);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final ground = H * .86, ph = math.min(S * .3, H * .26), kx = W * .16, G = S * 2.4, br = S * .042;
  final rr = S * ramp(lv, .085, .062);
  final hx0 = W * rand(.62, .8), hy0 = H * rand(.36, .5);
  double hoopX = 0, hoopY = 0, hoopPh = rand(0, 6), hoopNet = 0;
  final mvY = lv >= 8 ? S * ramp(lv, .05, .14) : 0.0, mvX = lv >= 28 ? S * ramp(lv, .03, .12) : 0.0, mvSp = ramp(lv, .8, 1.6);
  double time = ramp(lv, 70, 55).roundToDouble(), t = 0, endT = 0, throwT = 9, cheerT = 0;
  var score = 0;
  FunEnd? end;
  _Drag? drag;
  Offset hand() => Offset(kx + ph * .2, ground - ph * .78);
  late _Ball ball;
  void rest() {
    final h = hand();
    ball = _Ball(h.dx, h.dy);
  }

  rest();
  void placeHoop() {
    hoopX = hx0 + math.cos(hoopPh * mvSp * .7) * mvX;
    hoopY = hy0 + math.sin(hoopPh * mvSp) * mvY;
  }

  placeHoop();
  void shoot(double vx, double vy) {
    ball.vx = vx;
    ball.vy = vy;
    ball.fly = true;
    ball.life = 0;
    throwT = 0;
    g.sfx('shoot');
  }

  final maxV = S * 3.2;
  (double, double) velOf(double dx, double dy) {
    var vx = dx * 4.2, vy = dy * 4.2;
    final m = hypot(vx, vy);
    if (m > maxV) {
      vx *= maxV / m;
      vy *= maxV / m;
    }
    return (vx, vy);
  }

  g.taps(
    onDownXY: (x, y) {
      if (!ball.fly && end == null && t >= 2) drag = _Drag(x, y);
    },
    onMoveXY: (x, y, _) {
      final d = drag;
      if (d != null) {
        d.x = x;
        d.y = y;
      }
    },
    onUpXY: (x, y, _) {
      final d = drag;
      if (d == null) return;
      final dx = x - d.x0, dy = y - d.y0;
      drag = null;
      if (hypot(dx, dy) < 25 || dy > 0) return;
      final (vx, vy) = velOf(dx, dy);
      shoot(vx, vy);
    },
  );
  List<Offset> rimPts() => [Offset(hoopX - rr, hoopY), Offset(hoopX + rr, hoopY)];
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      throwT += dt;
      cheerT = math.max(0, cheerT - dt);
      hoopNet = math.max(0, hoopNet - dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      time -= dt;
      hoopPh += dt;
      placeHoop();
      if (bot && !ball.fly && throwT > .5) {
        const T = .95;
        final h = hand();
        shoot((hoopX - h.dx) / T, (hoopY - br * 1.2 - h.dy - .5 * G * T * T) / T);
      }
      if (ball.fly) {
        for (var k = 0; k < 3; k++) {
          final d = dt / 3, py = ball.y;
          ball.vy += G * d;
          ball.x += ball.vx * d;
          ball.y += ball.vy * d;
          ball.rot += ball.vx * d * .02;
          for (final p in rimPts()) {
            final dx = ball.x - p.dx, dy = ball.y - p.dy, dd = hypot(dx, dy);
            if (dd < br && dd > 0) {
              final nx = dx / dd, ny = dy / dd, vn = ball.vx * nx + ball.vy * ny;
              if (vn < 0) {
                ball.vx -= 1.6 * vn * nx;
                ball.vy -= 1.6 * vn * ny;
                g.sfx('pop');
              }
              ball.x = p.dx + nx * br;
              ball.y = p.dy + ny * br;
            }
          }
          final bx = hoopX + rr + S * .03;
          if (ball.x + br > bx && ball.x < bx + 10 && ball.y > hoopY - S * .22 && ball.y < hoopY + S * .04 && ball.vx > 0) {
            ball.vx = -ball.vx.abs() * .55;
            ball.x = bx - br;
            g.sfx('pop');
          }
          if (!ball.scored && py < hoopY && ball.y >= hoopY && ball.vy > 0 && (ball.x - hoopX).abs() < rr - br * .4) {
            ball.scored = true;
            score++;
            hoopNet = .6;
            cheerT = 1.2;
            g.sfx('coin');
            F.burst(hoopX, hoopY + 20, 18);
            F.text(hoopX, hoopY - 40, '$score/$need', '#ffd43b');
            ball.vx *= .3;
            if (score >= need) {
              end = FunEnd(win: true, score: score * 10 + time.round());
              g.sfx('win');
            }
          }
          if (ball.y + br > ground) {
            ball.y = ground - br;
            ball.vy = -ball.vy.abs() * .5;
            ball.vx *= .7;
          }
        }
        ball.life += dt;
        if (ball.life > 3.2 || (ball.scored && ball.life > 1.5) || ball.x > W + 80 || ball.x < -80) rest();
      } else {
        final h = hand();
        ball.x = h.dx;
        ball.y = h.dy + math.sin(t * 3) * 2;
      }
      if (time <= 0 && end == null) {
        time = 0;
        end = FunEnd(win: false, score: score * 10);
        g.sfx('wrong');
      }
      return null;
    },
    draw: () {
      skyFill(c, W, H, th);
      draw(c, th.sun, W * .5, H * .12, S * .1);
      c.fillStyle = 'rgba(255,255,255,.3)';
      for (var i = 0; i < 3; i++) {
        drawO(c, th.deco[i], W * (.3 + i * .22), ground - S * .12, S * .22, h: S * .22, alpha: .45);
      }
      c.fillStyle = '#d9a066';
      c.fillRect(0, ground, W, H - ground);
      c.fillStyle = '#c08552';
      for (double x = 0; x < W; x += 46) {
        c.fillRect(x, ground, 3, H - ground);
      }
      c.fillStyle = '#fff';
      c.fillRect(0, ground, W, 4);
      // Cột + bảng rổ
      final bx = hoopX + rr + S * .03;
      c.fillStyle = '#868e96';
      c.fillRect(bx + 14, hoopY - S * .1, 12, ground - hoopY + S * .1);
      c.fillStyle = '#495057';
      roundRect(c, bx + 6, ground - 14, 28, 14, 4);
      c.fill();
      c.fillStyle = '#f8f9fa';
      c.strokeStyle = '#495057';
      c.lineWidth = 3;
      roundRect(c, bx, hoopY - S * .22, 12, S * .26, 4);
      c.fill();
      c.stroke();
      // Lưới
      final sway = math.sin(hoopNet * 20) * hoopNet * 6;
      c.strokeStyle = 'rgba(255,255,255,.95)';
      c.lineWidth = 2;
      final nh = S * .09;
      for (var i = 0; i <= 4; i++) {
        final x0 = hoopX - rr + i * rr / 2;
        c.beginPath();
        c.moveTo(x0, hoopY);
        c.lineTo(hoopX - rr * .55 + i * rr * .275 + sway, hoopY + nh + hoopNet * 10);
        c.stroke();
      }
      for (var j = 1; j <= 2; j++) {
        final f = j / 2.5;
        c.beginPath();
        c.moveTo(hoopX - rr * (1 - f * .45) + sway * f, hoopY + nh * f);
        c.lineTo(hoopX + rr * (1 - f * .45) + sway * f, hoopY + nh * f);
        c.stroke();
      }
      // Bé ném bóng
      shadow(c, kx, ground, ph * .5);
      final an = end?.win == true || cheerT > 0 ? 'cheer' : throwT < .35 ? 'throw' : drag != null || !ball.fly ? 'hold' : 'idle';
      drawAnimC(c, SH[kid], an, an == 'throw' ? throwT : t, kx, ground, ph);
      final dr = drag;
      if (dr != null) {
        final (vx0, vy0) = velOf(dr.x - dr.x0, dr.y - dr.y0);
        if (dr.y < dr.y0 - 10) {
          var px = ball.x, py = ball.y, vx = vx0, vy = vy0;
          final dots = math.max(5, 26 - lv * .35).round();
          c.fillStyle = 'rgba(255,255,255,.95)';
          for (var i = 0; i < dots; i++) {
            for (var k = 0; k < 3; k++) {
              vy += G * .014;
              px += vx * .014;
              py += vy * .014;
            }
            c.beginPath();
            c.arc(px, py, math.max(2, 6 - i * .18), 0, 7);
            c.fill();
          }
        }
      }
      // Bóng: khi rơi qua vành thì vẽ sau vành trước để như lọt rổ
      drawO(c, 'Basketball', ball.x, ball.y, br * 2.2, h: br * 2.2, rot: ball.rot);
      c.strokeStyle = '#f03e3e';
      c.lineWidth = 6;
      c.lineCap = 'round';
      c.beginPath();
      c.moveTo(hoopX - rr, hoopY);
      c.lineTo(hoopX + rr, hoopY);
      c.lineTo(bx, hoopY);
      c.stroke();
      F.draw(c);
      hud(c, W, score: score, time: time);
      goalPill(c, W, score, need);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Ném vào rổ $need quả', 'Make $need baskets'),
            tr('Vuốt từ dưới lên về phía rổ · Vuốt dài ném xa', 'Swipe up toward the hoop · Longer swipes throw farther'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT GIỜ!', "TIME'S UP!"), tr('$score/$need quả', '$score/$need baskets'));
    },
  );
}

// ---------- 4. Chạy vượt rào: 4 bạn chạy đua, bé tự chạy, chạm để nhảy qua rào; nhảy sát rào được tăng tốc.
// Vấp rào thì chậm lại. Cấp thấp về nhì/ba vẫn qua, cấp cao phải về nhất. ----------
class _Racer {
  _Racer(this.k, this.me, this.lane, this.skill, this.miss);
  final String k;
  final bool me;
  final int lane;
  final double skill, miss;
  double x = 0, v = 0, z = 0, vz = 0, trip = 0, boost = 0;
  int next = 0, done = 0;
  bool decided = false, hitH = false;
}

Future<LoopGame> hurdles(Fun g) async {
  final lv = g.level, th = theme(lv), kid = kidOf(g.hero), tr = g.tr, bot = g.bot;
  final others = ['kidgirl', 'kidboy', 'robot', 'woman', 'man'].where((k) => k != kid).take(3).toList();
  final SH = await playSheets([kid, ...others, 'items']);
  await loadAll(['Red heart', 'Coin', 'Chequered flag', ...themeImgs(lv)]);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final L = ramp(lv, 50, 130).round(), U = S * .14, gap = math.max(7, ramp(lv, 12, 8));
  final placeNeed = lv < 15 ? 3 : lv < 35 ? 2 : 1;
  final hs = <double>[];
  for (double m = 10; m < L - 4; m += gap * rand(.85, 1.15)) {
    hs.add(m);
  }
  final port = H > W * 1.2;
  final LY = port ? [H * .42, H * .58, H * .74, H * .9] : [H * .5, H * .63, H * .76, H * .89], LS = [.78, .86, .94, 1.0];
  final ph = math.min(S * (port ? .32 : .22), (LY[1] - LY[0]) * 1.4);
  const base = 6.2, G = 34.0;
  final all = [kid, ...others];
  final racers = [
    for (var i = 0; i < all.length; i++) _Racer(all[i], i == 0, [3, 0, 1, 2][i], i == 0 ? 1 : ramp(lv, .86, 1.02) * rand(.96, 1.04), ramp(lv, .3, .06)),
  ];
  final me = racers[0];
  double t = 0, endT = 0;
  var place = 0;
  FunEnd? end;
  final finishOrder = <_Racer>[];
  void jump(_Racer r) {
    if (r.z <= 0 && r.trip <= 0) {
      r.vz = 9.5;
      r.z = .001;
      if (r.me) g.sfx('jump');
      final h = r.next < hs.length ? hs[r.next] : null;
      if (r.me && h != null && h - r.x > 0 && h - r.x < 1.6) {
        r.boost = 1;
        F.text(W * .3, LY[r.lane] - ph * 1.2, tr('Tuyệt!', 'Great!'), '#ffd43b');
      }
    }
  }

  g.taps(onTap: (_, _) {
    if (t >= 2.5 && end == null) jump(me);
  }, onSwipe: (_, _, _, _) {
    if (t >= 2.5 && end == null) jump(me);
  });
  String needTxt() => placeNeed == 1 ? tr('nhất', '1st') : tr('top $placeNeed', 'top $placeNeed');
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        for (final r in racers) {
          if (r.x < L + 6) r.x += math.max(2, r.v) * dt;
        }
        return endT > 2.5 ? end : null;
      }
      if (t < 2.5) return null;
      for (final r in racers) {
        if (r.done != 0) {
          r.x += r.v * .5 * dt;
          continue;
        }
        final target = r.trip > 0 ? base * .3 : base * r.skill * (1 + (r.boost > 0 ? .25 : 0)) * (r.me ? ramp(lv, 1.02, 1) : 1);
        r.v += (target - r.v) * math.min(1, dt * 2.5);
        r.x += r.v * dt;
        r.trip = math.max(0, r.trip - dt);
        r.boost = math.max(0, r.boost - dt);
        if (r.z > 0) {
          r.vz -= G * dt;
          r.z += r.vz * dt;
          if (r.z <= 0) {
            r.z = 0;
            r.vz = 0;
          }
        }
        while (r.next < hs.length && hs[r.next] < r.x - .5) {
          r.next++;
          r.decided = false;
          r.hitH = false;
        }
        if (r.next < hs.length) {
          final h = hs[r.next];
          if (!r.me || bot) {
            final d = h - r.x;
            if (d > 0 && d < .9 + (r.me ? .3 : 0) && r.z <= 0 && !r.decided) {
              r.decided = true;
              if (r.me || random() > r.miss) jump(r);
            }
          }
          if ((h - r.x).abs() < .35 && r.z < .45 && r.trip <= 0 && !r.hitH) {
            r.trip = .8;
            r.hitH = true;
            r.v *= .4;
            if (r.me) {
              g.sfx('hit');
              F.burst(W * .3, LY[r.lane] - ph * .3, 10, ['#ff8787', '#ffd43b']);
            }
          }
        }
        if (r.x >= L && r.done == 0) {
          finishOrder.add(r);
          r.done = finishOrder.length;
          if (r.me) {
            place = r.done;
            final win = place <= placeNeed;
            end = FunEnd(win: win, score: math.max(0, 50 - place * 10) + ramp(lv, 10, 40).round(), pos: place);
            g.sfx(win ? 'win' : 'wrong');
          }
        }
      }
      return null;
    },
    draw: () {
      skyFill(c, W, H, th);
      final camX = me.x * U - W * .3, top = LY[0] - (LY[1] - LY[0]) * .9;
      // Khán đài + cảnh xa
      for (var i = 0; i < 7; i++) {
        final x = ((i * W / 5 - camX * .3) % (W * 1.4) + W * 1.4) % (W * 1.4) - W * .2;
        drawO(c, th.deco[i % 4], x, top - S * .09, S * .2, h: S * .2, alpha: .85);
      }
      c.fillStyle = '#c2410c';
      c.fillRect(0, top, W, H - top);
      for (var i = 0; i < 4; i++) {
        c.fillStyle = i % 2 == 1 ? '#e8590c' : '#d9480f';
        c.fillRect(0, LY[i] - (LY[1] - LY[0]) * .82, W, (LY[1] - LY[0]) * .82);
        c.fillStyle = '#fff';
        c.fillRect(0, LY[i] + 1, W, 3);
      }
      // Vạch mét + đích
      c.fillStyle = 'rgba(255,255,255,.5)';
      c.font = '700 16px';
      c.textAlign = 'center';
      for (var m = (camX / U / 10).ceil() * 10; m * U - camX < W + 20; m += 10) {
        if (m > 0 && m < L) c.fillText('$m m', m * U - camX, top + 18);
      }
      final fx0 = L * U - camX;
      if (fx0 < W + 40) {
        for (var y = top; y < H; y += 14) {
          for (var k = 0; k < 2; k++) {
            c.fillStyle = (((y - top) / 14).floor() + k) % 2 == 1 ? '#fff' : '#212529';
            c.fillRect(fx0 + k * 10, y, 10, 14);
          }
        }
        draw(c, 'Chequered flag', fx0 + 10, top - S * .07, S * .12);
      }
      for (var l = 0; l < 4; l++) {
        final sc = LS[l];
        for (final h in hs) {
          final x = h * U - camX;
          if (x > -60 && x < W + 60) drawFrame(c, SH['items'], 'fence', x, LY[l] - ph * .17 * sc, ph * .36 * sc);
        }
        for (final r in racers) {
          if (r.lane != l) continue;
          final x = r.x * U - camX, zz = r.z * U * .55;
          shadow(c, x, LY[l], ph * .45 * sc);
          final an = end != null && r.done != 0
              ? (r.done == 1 ? 'cheer' : 'idle')
              : r.trip > .3
                  ? 'hurt'
                  : r.z > 0
                      ? (r.vz > 0 ? 'jump' : 'fall')
                      : t < 2.5
                          ? 'idle'
                          : 'run';
          drawAnimC(c, SH[r.k], an, t * (.6 + r.v / base * .6), x, LY[l] - zz, ph * sc);
          if (r.me) {
            c.fillStyle = '#ffd43b';
            c.beginPath();
            final ay = LY[l] - zz - ph * sc - 8;
            c.moveTo(x - 10, ay - 14);
            c.lineTo(x + 10, ay - 14);
            c.lineTo(x, ay);
            c.fill();
          }
        }
      }
      F.draw(c);
      // Bảng xếp hạng nhỏ: thứ tự hiện tại
      final order = [...racers]..sort((a, b) {
          final d = (a.done == 0 ? 99 : a.done) - (b.done == 0 ? 99 : b.done);
          return d != 0 ? d : b.x.compareTo(a.x);
        });
      final myPos = order.indexOf(me) + 1;
      // Thanh tiến độ cuộc đua: mỗi bạn một hình nhỏ, cờ đích bên phải
      final py = W < 640 ? 128.0 : 84.0, px0 = 30.0, px1 = W - 60;
      c.fillStyle = 'rgba(255,255,255,.75)';
      roundRect(c, px0 - 10, py - 4, px1 - px0 + 50, 8, 4);
      c.fill();
      draw(c, 'Chequered flag', px1 + 22, py - 16, 34);
      for (final r in racers.reversed) {
        drawAnimC(c, SH[r.k], 'run', t, px0 + (px1 - px0) * math.min(1, r.x / L), py + 4, r.me ? 52 : 40);
      }
      hud(c, W, score: math.min(L, me.x.floor()));
      pill(c, W, tr('🏁 Hạng $myPos · cần ${needTxt()}', '🏁 Place $myPos · need ${needTxt()}'), W < 640 ? 62 : 10, 260);
      if (t < 2.5) {
        levelBanner(c, W, H, lv, tr('Về ${needTxt()} · $L mét', 'Finish ${needTxt()} · $L meters'),
            tr('Chạm để nhảy qua rào · Nhảy sát rào được chạy nhanh', 'Tap to jump the hurdles · Jump close to a hurdle to speed up'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('CHƯA ĐƯỢC HẠNG!', 'NOT PLACED!'), tr('Bé về hạng $place', 'You finished #$place'));
    },
  );
}

// ---------- 5. Nhảy theo nhạc: viên ngọc rơi theo bài hát, chạm đúng cột khi ngọc chạm vạch, bạn nhỏ nhảy múa. ----------
const List<List<int>> _songs = [
  [0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0, 4, 4, 3, 3, 2, 2, 1, 4, 4, 3, 3, 2, 2, 1, 0, 0, 4, 4, 5, 5, 4, 3, 3, 2, 2, 1, 1, 0], // Sao lấp lánh
  [0, 1, 2, 0, 0, 1, 2, 0, 2, 3, 4, 2, 3, 4, 4, 5, 4, 3, 2, 0, 4, 5, 4, 3, 2, 0, 0, 4, 0, 0, 4, 0], // Kìa con bướm vàng
  [2, 1, 0, 1, 2, 2, 2, 1, 1, 1, 2, 4, 4, 2, 1, 0, 1, 2, 2, 2, 2, 1, 1, 2, 1, 0], // Mary có chú cừu non
];

class _Note {
  _Note(this.p, this.c, this.at);
  final int p, c;
  final double at;
  bool hit = false, miss = false;
}

Future<LoopGame> dance(Fun g) async {
  final lv = g.level, kid = kidOf(g.hero), nc = lv < 20 ? 3 : 4, tr = g.tr, bot = g.bot;
  final crew = ['robot', kid == 'kidgirl' ? 'kidboy' : 'kidgirl'];
  final SH = await playSheets([kid, ...crew, 'items']);
  await loadAll(['Red heart', 'Coin', 'Musical notes', 'Glowing star']);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final song = _songs[lv % _songs.length], beat = ramp(lv, .62, .34), win = ramp(lv, .24, .13), fallT = ramp(lv, 2.2, 1.3);
  const GEMS = ['gem_red', 'gem_blue', 'gem_green', 'gem_yellow'], COLS = ['#fa5252', '#339af0', '#40c057', '#fab005'];
  // Cấp cao: thêm nốt đôi (2 cột cùng lúc).
  final notes = [for (var i = 0; i < song.length; i++) _Note(song[i], song[i] % nc, 2.6 + i * beat)];
  if (lv >= 40) {
    for (var i = 4; i < song.length; i += 6) {
      notes.add(_Note(song[i] + 2, (song[i] + 1) % nc, notes[i].at));
    }
  }
  final allowed = ramp(lv, 10, 4).round();
  final top = H * .4, hitY = H * .88, colW = math.min(W / nc, 190.0), x0 = W / 2 - colW * nc / 2;
  double t = 0, poseT = 0, endT = 0;
  var hits = 0, miss = 0, combo = 0, best = 0;
  var pose = 'idle';
  FunEnd? end;
  final flash = List.filled(nc, 0.0);
  const POSES = ['cheer0', 'wide', 'kick', 'cheer1', 'show', 'jump', 'switch1', 'attack1'];
  void press(int col) {
    flash[col] = .15;
    _Note? bestN;
    for (final n in notes) {
      if (!n.hit && !n.miss && n.c == col && (n.at - t).abs() < win && (bestN == null || (n.at - t).abs() < (bestN.at - t).abs())) bestN = n;
    }
    if (bestN != null) {
      bestN.hit = true;
      hits++;
      combo++;
      best = math.max(best, combo);
      g.note(bestN.p, .5);
      pose = POSES[hits % POSES.length];
      poseT = .4;
      final x = x0 + (col + .5) * colW;
      F.burst(x, hitY, 10, [COLS[col], '#fff']);
      if ((bestN.at - t).abs() < win * .4) F.text(x, hitY - 50, tr('Tuyệt!', 'Great!'), '#ffd43b');
    } else {
      combo = 0;
    }
  }

  g.taps(onDownXY: (x, _) {
    if (t < 2 || end != null) return;
    final col = ((x - x0) / colW).floor();
    if (col >= 0 && col < nc) press(col);
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      poseT = math.max(0, poseT - dt);
      for (var i = 0; i < nc; i++) {
        flash[i] = math.max(0, flash[i] - dt);
      }
      if (end != null) {
        endT += dt;
        return endT > 2.2 ? end : null;
      }
      if (bot) {
        for (final n in notes) {
          if (!n.hit && !n.miss && t >= n.at - .02) press(n.c);
        }
      }
      for (final n in notes) {
        if (!n.hit && !n.miss && t - n.at > win) {
          n.miss = true;
          miss++;
          combo = 0;
          pose = 'hurt';
          poseT = .3;
        }
      }
      if (miss > allowed && end == null) {
        end = FunEnd(win: false, score: hits * 5);
        g.sfx('wrong');
      } else if (end == null && notes.every((n) => n.hit || n.miss)) {
        end = FunEnd(win: true, score: hits * 5 + best * 2);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      // Sân khấu
      final gr = c.createLinearGradient(0, 0, 0, H);
      gr.addColorStop(0, '#3b1d6e');
      gr.addColorStop(1, '#14082b');
      c.fillStyle = gr;
      c.fillRect(0, 0, W, H);
      for (var i = 0; i < 3; i++) {
        final a = math.sin(t * .8 + i * 2) * .35;
        c.save();
        c.translate(W * (.25 + i * .25), 0);
        c.rotate(a);
        c.fillStyle = 'rgba(${const ['255,212,59', '116,192,252', '247,131,172'][i]},.12)';
        c.beginPath();
        c.moveTo(-10, 0);
        c.lineTo(10, 0);
        c.lineTo(90, top);
        c.lineTo(-90, top);
        c.fill();
        c.restore();
      }
      c.fillStyle = '#7c4a1e';
      c.fillRect(0, top - 14, W, 14);
      final dh = math.min(top * .7, S * .3);
      if (combo >= 5) drawAnimC(c, SH[crew[0]], 'dance', t + .3, W * .25, top - 14, dh * .8, flip: true);
      if (combo >= 10) drawAnimC(c, SH[crew[1]], 'dance', t + .7, W * .75, top - 14, dh * .8);
      shadow(c, W / 2, top - 14, dh * .5, .3);
      if (end?.win == true) {
        drawAnimC(c, SH[kid], 'cheer', t, W / 2, top - 14, dh);
      } else if (poseT > 0) {
        drawFrame(c, SH[kid], pose == 'hurt' ? 'hurt' : pose, W / 2, top - 14, dh, flip: hits % 2 == 1);
      } else {
        drawAnimC(c, SH[kid], 'idle', t, W / 2, top - 14 - math.sin(t * math.pi / beat).abs() * 6, dh);
      }
      // Cột nốt
      for (var col = 0; col < nc; col++) {
        final x = x0 + col * colW;
        c.fillStyle = col % 2 == 1 ? 'rgba(255,255,255,.06)' : 'rgba(255,255,255,.1)';
        c.fillRect(x + 3, top, colW - 6, H - top);
        c.fillStyle = flash[col] > 0 ? COLS[col] : 'rgba(255,255,255,.18)';
        roundRect(c, x + 8, hitY - colW * .3, colW - 16, colW * .6, 18);
        c.fill();
        drawFrame(c, SH['items'], GEMS[col], x + colW / 2, hitY, colW * .32, alpha: .45);
      }
      for (final n in notes) {
        if (n.hit || n.miss) continue;
        final k = 1 - (n.at - t) / fallT;
        if (k < 0) continue;
        final y = top + (hitY - top) * k, x = x0 + (n.c + .5) * colW;
        drawFrame(c, SH['items'], GEMS[n.c], x, y, colW * .44);
      }
      F.draw(c);
      hud(c, W, score: hits);
      for (var i = 0; i < math.min(allowed, 12); i++) {
        drawO(c, 'Red heart', W - 30 - i * 22, 30, 20, h: 20, alpha: i < allowed - miss ? 1 : .2);
      }
      if (combo >= 3) pill(c, W, tr('🔥 $combo liên tiếp', '🔥 $combo in a row'), W < 640 ? 62 : 10, 200);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Chạm đúng ${notes.length} nốt nhạc', 'Hit ${notes.length} notes'),
            tr('Ngọc rơi tới ô sáng thì chạm vào cột đó', 'Tap the column when its gem reaches the glowing pad'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('LỠ NHỊP RỒI!', 'MISSED THE BEAT!'), tr('$hits/${notes.length} nốt', '$hits/${notes.length} notes'));
      }
    },
  );
}

// ---------- 6. Golf mini: kéo ngược từ bóng để ngắm (như ná), thả để đánh, đưa bóng vào lỗ cờ trong số gậy cho phép. ----------
class _Wall {
  _Wall(this.x, this.y, this.w, this.h, this.gap, this.under, this.inGap, this.passed);
  final double x, y, w, h;

  /// gap: tâm khe hở của tường (để bot test ngắm); under: điểm trước tường thẳng khe.
  final Offset gap, under;
  final bool Function(double bx, double by) inGap, passed;
}

class _Sand {
  _Sand(this.x, this.y, this.r);
  final double x, y, r;
}

class _Bug {
  _Bug(this.k, this.x, this.y, this.vx, this.s);
  final String k;
  double x, vx;
  final double y, s;
}

Future<LoopGame> golf(Fun g) async {
  final lv = g.level, kid = kidOf(g.hero), tr = g.tr, bot = g.bot;
  final SH = await playSheets([kid, 'items', 'critters']);
  await loadAll(['Red heart', 'Coin', 'Flag in hole']);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final top = W < 640 ? 112.0 : 70.0;
  const M = 16.0;
  final Ax = M, Ay = top, Aw = W - M * 2, Ah = H - top - M;
  final br = S * .022, hr = S * .036;
  final port = Ah > Aw;
  final startP = port ? Offset(Ax + Aw * rand(.3, .7), Ay + Ah * .88) : Offset(Ax + Aw * .1, Ay + Ah * rand(.3, .7));
  final hole = port ? Offset(Ax + Aw * rand(.25, .75), Ay + Ah * .12) : Offset(Ax + Aw * .9, Ay + Ah * rand(.2, .8));
  // Tường so le (như mê cung đơn giản), luôn chừa khe ở một đầu.
  final walls = <_Wall>[];
  final nW = math.min(4, lv ~/ 12 + (lv >= 2 ? 1 : 0)), th = S * .045;
  for (var i = 0; i < nW; i++) {
    final f = (i + 1) / (nW + 1), len = (port ? Aw : Ah) * ramp(lv, .45, .62), left = i % 2 == 0;
    if (port) {
      final y = Ay + Ah * (.88 - .76 * f) - th / 2;
      final gx = left ? Ax + (len + Aw) / 2 : Ax + (Aw - len) / 2, gr = (Aw - len) / 2 - br * 3;
      walls.add(_Wall(left ? Ax : Ax + Aw - len, y, len, th, Offset(gx, y - th * 1.5), Offset(gx, y + th * 2.5), (bx, by) => (bx - gx).abs() < gr,
          (bx, by) => by < y - th * .5));
    } else {
      final x = Ax + Aw * (.1 + .8 * f) - th / 2;
      final gy = left ? Ay + (len + Ah) / 2 : Ay + (Ah - len) / 2, gr = (Ah - len) / 2 - br * 3;
      walls.add(_Wall(x, left ? Ay : Ay + Ah - len, th, len, Offset(x + th * 2.5, gy), Offset(x - th * 2.5, gy), (bx, by) => (by - gy).abs() < gr,
          (bx, by) => bx > x + th * 1.5));
    }
  }
  final sands = lv >= 20
      ? List.generate(math.min(3, 1 + (lv - 20) ~/ 15), (_) => _Sand(Ax + Aw * rand(.2, .8), Ay + Ah * rand(.25, .75), S * rand(.06, .09)))
      : <_Sand>[];
  final bugs = lv >= 10
      ? List.generate(math.min(3, 1 + (lv - 10) ~/ 16),
          (i) => _Bug(pick(['slime', 'ladybug', 'snail']), Ax + Aw * rand(.3, .7), Ay + Ah * (.3 + .4 * i / 3), S * ramp(lv, .12, .3) * (random() < .5 ? -1 : 1), S * .07))
      : <_Bug>[];
  final par = 1 + nW, allowed = par + ramp(lv, 5, 3).round();
  double ballX = startP.dx, ballY = startP.dy, ballVx = 0, ballVy = 0, t = 0, endT = 0, sink = 0, swingT = 9;
  var strokes = 0;
  Offset? drag;
  FunEnd? end;
  final maxPull = S * .26;
  const POW = 7.5;
  bool moving() => hypot(ballVx, ballVy) > 4;
  void hitWall(_Wall w) {
    final cx = math.max(w.x, math.min(ballX, w.x + w.w)), cy = math.max(w.y, math.min(ballY, w.y + w.h)), dx = ballX - cx, dy = ballY - cy, d = hypot(dx, dy);
    if (d < br) {
      final nx = d != 0 ? dx / d : 0.0, ny = d != 0 ? dy / d : -1.0, vn = ballVx * nx + ballVy * ny;
      if (vn < 0) {
        ballVx -= 1.8 * vn * nx;
        ballVy -= 1.8 * vn * ny;
        g.sfx('pop');
      }
      ballX = cx + nx * br;
      ballY = cy + ny * br;
    }
  }

  void hitBall(double vx, double vy) {
    ballVx = vx;
    ballVy = vy;
    strokes++;
    swingT = 0;
    g.sfx('shoot');
  }

  g.taps(
    onDownXY: (x, y) {
      if (!moving() && end == null && t >= 2 && sink == 0) drag = Offset(x, y);
    },
    onMoveXY: (x, y, _) {
      if (drag != null) drag = Offset(x, y);
    },
    onUpXY: (_, _, _) {
      final dr = drag;
      if (dr == null) return;
      var dx = ballX - dr.dx, dy = ballY - dr.dy;
      drag = null;
      final d = hypot(dx, dy);
      if (d < 14) return;
      if (d > maxPull) {
        dx *= maxPull / d;
        dy *= maxPull / d;
      }
      hitBall(dx * POW, dy * POW);
    },
  );
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      swingT += dt;
      for (final b in bugs) {
        b.x += b.vx * dt;
        if (b.x < Ax + b.s || b.x > Ax + Aw - b.s) b.vx *= -1;
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (sink != 0) {
        sink += dt;
        if (sink > .7) {
          end = FunEnd(win: true, score: math.max(5, (allowed - strokes + 1) * 10));
          g.sfx('win');
        }
        return null;
      }
      if (bot && !moving() && swingT > .8) {
        _Wall? w;
        for (final ww in walls) {
          if (!ww.passed(ballX, ballY)) {
            w = ww;
            break;
          }
        }
        final gp = w != null ? (w.inGap(ballX, ballY) ? w.gap : w.under) : hole;
        final dx = gp.dx - ballX, dy = gp.dy - ballY, d = hypot(dx, dy);
        final sp = math.min(maxPull * POW, d * 1.3 + 60);
        hitBall(dx / d * sp, dy / d * sp);
      }
      for (var k = 0; k < 4; k++) {
        final d = dt / 4;
        ballX += ballVx * d;
        ballY += ballVy * d;
        final inSand = sands.any((s) => hypot(ballX - s.x, ballY - s.y) < s.r);
        final fr = math.exp(-(inSand ? 2.2 : 1.05) * d);
        ballVx *= fr;
        ballVy *= fr;
        final sp = hypot(ballVx, ballVy);
        if (sp < 18) {
          ballVx = 0;
          ballVy = 0;
        }
        if (ballX < Ax + br) {
          ballX = Ax + br;
          ballVx = ballVx.abs() * .8;
        }
        if (ballX > Ax + Aw - br) {
          ballX = Ax + Aw - br;
          ballVx = -ballVx.abs() * .8;
        }
        if (ballY < Ay + br) {
          ballY = Ay + br;
          ballVy = ballVy.abs() * .8;
        }
        if (ballY > Ay + Ah - br) {
          ballY = Ay + Ah - br;
          ballVy = -ballVy.abs() * .8;
        }
        for (final w in walls) {
          hitWall(w);
        }
        for (final b in bugs) {
          final dx = ballX - b.x, dy = ballY - b.y, dd = hypot(dx, dy);
          if (dd < b.s * .45 + br && dd > 0) {
            final nx = dx / dd, ny = dy / dd, vn = ballVx * nx + ballVy * ny;
            if (vn < 0) {
              ballVx -= 2 * vn * nx;
              ballVy -= 2 * vn * ny;
            }
            ballX = b.x + nx * (b.s * .45 + br);
            ballY = b.y + ny * (b.s * .45 + br);
            g.sfx('squeak');
          }
        }
        final dh = hypot(ballX - hole.dx, ballY - hole.dy);
        if (dh < hr * .8 && sp < S * 1.6) {
          sink = .001;
          ballVx = ballVy = 0;
          g.sfx('coin');
          F.burst(hole.dx, hole.dy, 22);
          F.star(hole.dx, hole.dy);
          break;
        }
        if (dh < hr * 1.6 && dh > 0) {
          // lỗ hút nhẹ
          ballVx += (hole.dx - ballX) / dh * S * .9 * d;
          ballVy += (hole.dy - ballY) / dh * S * .9 * d;
        }
      }
      if (!moving() && sink == 0 && strokes >= allowed && end == null) {
        end = const FunEnd(win: false, score: 0);
        g.sfx('wrong');
      }
      return null;
    },
    draw: () {
      c.fillStyle = '#2b8a3e';
      c.fillRect(0, 0, W, H);
      c.fillStyle = '#69db7c';
      roundRect(c, Ax, Ay, Aw, Ah, 24);
      c.fill();
      c.fillStyle = 'rgba(255,255,255,.08)';
      for (var x = Ax; x < Ax + Aw; x += 60) {
        c.fillRect(x, Ay, 30, Ah);
      }
      for (final s in sands) {
        c.fillStyle = '#ffe8a3';
        c.beginPath();
        c.ellipse(s.x, s.y, s.r * 1.2, s.r, 0, 0, 7);
        c.fill();
      }
      for (final w in walls) {
        final n = math.max(1, (math.max(w.w, w.h) / th).round()), hz = w.w > w.h;
        for (var i = 0; i < n; i++) {
          drawFrame(c, SH['items'], 'block_planks', hz ? w.x + (i + .5) * w.w / n : w.x + w.w / 2, hz ? w.y + w.h / 2 : w.y + (i + .5) * w.h / n, th * 1.05);
        }
      }
      c.fillStyle = '#1b4332';
      c.beginPath();
      c.arc(hole.dx, hole.dy, hr, 0, 7);
      c.fill();
      drawAnimC(c, SH['items'], 'flagR', t, hole.dx + S * .028, hole.dy - S * .045, S * .1);
      for (final b in bugs) {
        drawAnimC(c, SH['critters'], b.k, t, b.x, b.y, b.s, flip: b.vx > 0);
      }
      final dr = drag;
      if (dr != null) {
        var dx = ballX - dr.dx, dy = ballY - dr.dy;
        final d = hypot(dx, dy);
        if (d > maxPull) {
          dx *= maxPull / d;
          dy *= maxPull / d;
        }
        final len = math.max(3, 12 - lv * .15).round();
        for (var i = 1; i <= len; i++) {
          c.fillStyle = 'rgba(255,255,255,${1 - i / (len + 2)})';
          c.beginPath();
          c.arc(ballX + dx * i * .28, ballY + dy * i * .28, 5, 0, 7);
          c.fill();
        }
        c.strokeStyle = 'rgba(0,0,0,.25)';
        c.lineWidth = 3;
        c.beginPath();
        c.moveTo(ballX, ballY);
        c.lineTo(ballX - dx * .5, ballY - dy * .5);
        c.stroke();
      }
      // Bé cầm gậy đứng cạnh bóng khi bóng dừng
      final ph = S * .17;
      if (!moving() && sink == 0) {
        drawAnimC(c, SH[kid], end != null && !end!.win ? 'hurt' : swingT < .3 ? 'throw' : 'hold', swingT < .3 ? swingT : t, ballX - ph * .32, ballY + br, ph, alpha: .95);
      }
      if (sink != 0 && end == null) drawAnimC(c, SH[kid], 'cheer', t, ballX - ph * .32, ballY + br, ph);
      if (end?.win == true) drawAnimC(c, SH[kid], 'cheer', t, hole.dx - ph * .4, hole.dy + ph * .5, ph);
      if (sink == 0) {
        shadow(c, ballX + 3, ballY + br * .8, br * 2.4, .25);
        c.fillStyle = '#fff';
        c.beginPath();
        c.arc(ballX, ballY, br, 0, 7);
        c.fill();
        c.fillStyle = 'rgba(0,0,0,.12)';
        c.beginPath();
        c.arc(ballX + br * .3, ballY + br * .3, br * .6, 0, 7);
        c.fill();
      }
      F.draw(c);
      hud(c, W, score: strokes);
      pill(c, W, tr('⛳ Gậy $strokes/$allowed', '⛳ Shots $strokes/$allowed'), W < 640 ? 62 : 10, 190);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Đưa bóng vào lỗ trong $allowed gậy', 'Sink the ball in $allowed shots'),
            tr('Kéo ngược từ quả bóng rồi thả tay', 'Pull back from the ball, then let go'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT LƯỢT ĐÁNH!', 'OUT OF SHOTS!'), tr('$strokes gậy', '$strokes shots'));
    },
  );
}
