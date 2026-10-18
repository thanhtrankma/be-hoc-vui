// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Khủng long chạy, ếch qua đường, bóng bàn, ăn đậu né ma, ghép 3.
// CHỦ: agent F. Port của web js/games/funnew2.js. Mỗi lượt một cấp (ctx.level), 60 cấp.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart' as fig;
import 'package:flutter/painting.dart' show Offset;

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funnew2Games = {
  'runner': const FunCanvasModule('runner', runner),
  'frogger': const FunCanvasModule('frogger', frogger),
  'pong': const FunCanvasModule('pong', pong),
  'pacman': const FunCanvasModule('pacman', pacman),
  'match3': const FunCanvasModule('match3', match3),
};

const Map<String, List<int>> _DIRS = {'u': [0, -1], 'd': [0, 1], 'l': [-1, 0], 'r': [1, 0]};
void _sky(Ctx2D c, double W, double H, FunTheme th) => skyFill(c, W, H, th);

/// Phần dư kiểu JS (giữ dấu số bị chia).
double _jsMod(double a, double b) => a.remainder(b);

double _v0(int lv) => lv / 120; // chân chạy nhanh hơn ở cấp cao

// ---------- 6. Khủng long chạy: chạm để nhảy (chạm 2 lần nhảy cao), né xương rồng, chim; ăn xu ----------
class _Obs {
  _Obs(this.k, this.x, this.y, this.s, {this.fly = false});
  final String k;
  double x, y, ph = 0;
  final double s;
  final bool fly;
}

class _Pt {
  _Pt(this.x, this.y);
  double x, y;
}

class _Deco {
  _Deco(this.x, this.k, this.s);
  double x;
  String k;
  final double s;
}

Future<LoopGame> runner(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 150, 900).round(), tr = g.tr;
  const OBS = ['Cactus', 'Rock', 'Fire'];
  final (shs, _) = await (
    sheets(['creatures/dino', 'plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx']),
    loadAll(['T-Rex', 'Coin', 'Bird', 'Bat', 'Cloud', 'Red heart', ...OBS, ...themeImgs(lv)]),
  ).wait;
  final dino = shs[0], en = shs[1], tl = shs[2], bgs = shs[3], fxs = shs[4];
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), ground = H * .78, G = S * 4.2, D = dust(200), SH = shaker();
  double scroll = 0, land = 0, jumpT = 0, stepT = 0;
  var wasAir = false;
  final meX = W * .2, meW = S * .17;
  double meY = ground, meVy = 0, meInv = 0;
  var meJumps = 0;
  final obs = <_Obs>[], coins = <_Pt>[], deco = <_Deco>[];
  double dist = 0, t = 0, spawn = 1.2, endT = 0;
  var lives = 3, coinN = 0;
  FunEnd? end;
  for (var i = 0; i < 6; i++) {
    deco.add(_Deco(rand(0, W), pick(th.deco), rand(.7, 1.1)));
  }
  void jump() {
    if (meJumps < 2) {
      meVy = -math.sqrt(2 * G * S * (meJumps > 0 ? .22 : .3));
      meJumps++;
      g.sfx('jump');
      jumpT = 0;
      D.puff(meX, meY, 4, 'rgba(230,220,200,1)', 60, 6);
    }
  }

  g.onDown((_) {
    if (end != null || t < 2) return;
    jump();
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      land = math.max(0, land - dt);
      jumpT += dt;
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      final v = S * ramp(lv, .55, 1.05) * (1 + math.min(.3, dist / 3000));
      // Tự chơi (test): nhảy khi vật cản dưới đất tới gần
      if (g.bot && meJumps == 0) {
        for (final o in obs) {
          final dx = o.x - meX;
          if (!o.fly && dx > 0 && dx < v * .3 + S * .1) {
            jump();
            break;
          }
        }
      }
      dist += v * dt / (S * .1);
      scroll += v * dt;
      meVy += G * dt;
      meY += meVy * dt;
      meInv = math.max(0, meInv - dt);
      if (meY >= ground) {
        if (wasAir) {
          land = .16;
          D.puff(meX, ground, 5, 'rgba(230,220,200,1)', 80, 7);
        }
        meY = ground;
        meVy = 0;
        meJumps = 0;
      }
      wasAir = meY < ground - 1;
      stepT -= dt;
      if (!wasAir && stepT <= 0) {
        stepT = .14;
        D.emit(meX - meW * .2, ground - 3, -v * .4, rand(-50, -20), life: .35, r: 3, grow: 8, c: 'rgba(230,220,200,1)', a: .6);
      }
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.9, 1.6) * ramp(lv, 1.25, .7);
        if (lv >= 6 && random() < ramp(lv, .1, .35)) {
          obs.add(_Obs(pick(['Bird', 'Bat']), W + 60, ground - S * rand(.25, .4), S * .1, fly: true));
        } else {
          final k = pick(OBS), n = lv >= 25 && random() < .3 ? 2 : 1;
          for (var i = 0; i < n; i++) {
            obs.add(_Obs(k, W + 60 + i * S * .09, ground - S * .05, S * .1));
          }
        }
        if (random() < .5) {
          for (var i = 0; i < 4; i++) {
            coins.add(_Pt(W + 220 + i * 50, ground - S * (.12 + .18 * math.sin(i / 3 * math.pi))));
          }
        }
      }
      final mbx = meX, mby = meY - meW * .45;
      for (var i = obs.length - 1; i >= 0; i--) {
        final o = obs[i];
        o.x -= v * dt;
        if (o.fly) {
          o.ph += dt;
          o.y += math.sin(o.ph * 5) * 30 * dt;
        }
        if (o.x < -80) {
          obs.removeAt(i);
          continue;
        }
        if (meInv <= 0 && (o.x - mbx).abs() < (o.s + meW) * .32 && (o.y - mby).abs() < (o.s + meW) * .35) {
          lives--;
          meInv = 1.4;
          g.sfx('hit');
          SH.add(9);
          D.sparks(meX, mby, 14, '#ff8787', 280);
          D.debris(o.x, o.y, 6, o.k == 'Cactus' ? '#2f9e44' : '#868e96', 240);
          if (lives <= 0) end = FunEnd(win: false, score: (dist / 10).round() + coinN);
        }
      }
      for (var i = coins.length - 1; i >= 0; i--) {
        final cn = coins[i];
        cn.x -= v * dt;
        if (cn.x < -40) {
          coins.removeAt(i);
          continue;
        }
        if (hypot(cn.x - mbx, cn.y - mby) < meW * .5) {
          coins.removeAt(i);
          coinN++;
          g.sfx('coin');
          D.sparks(cn.x, cn.y, 6, '#ffe066', 160);
          F.text(cn.x, cn.y - 20, '+1', '#ffd43b');
        }
      }
      for (final d in deco) {
        d.x -= v * dt * .3;
        if (d.x < -100) {
          d.x = W + 100;
          d.k = pick(th.deco);
        }
      }
      if (dist >= need && end == null) {
        end = FunEnd(win: true, score: (need / 10).round() + coinN * 2 + lives * 5);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      c.save();
      SH.apply(c);
      _sky(c, W, H, th);
      draw(c, th.sun, W * .86, H * .14, S * .13);
      // Nền nhiều lớp: đồi xa (chậm), cảnh theo chủ đề (vừa), mặt đất gạch (nhanh)
      backHills(c, bgs, lv, scroll * .1, ground + 6, H * .3, W);
      for (final d in deco) {
        draw(c, d.k, d.x, ground - S * .13 * d.s, S * .24 * d.s, S * .24 * d.s, false, 0, .7);
      }
      groundTiles(c, tl, lv, scroll, ground - 4, W, H + 20, math.max(44, S * .075));
      for (final cn in coins) {
        coin(c, fxs, t + cn.x * .01, cn.x, cn.y, 30);
      }
      const OBS_LOOK = {'Cactus': 'cactus', 'Rock': 'rock'};
      for (final o in obs) {
        if (o.fly) {
          anim(c, en, o.k == 'Bird' ? 'bee' : 'fly', t + o.ph, o.x, o.y, o.s * 1.1);
        } else if (OBS_LOOK[o.k] != null) {
          spr(c, tl, OBS_LOOK[o.k]!, o.x, o.y - o.s * .2, o.s * 1.5);
        } else {
          final fl = 1 + math.sin(t * 18 + o.x) * .08;
          draw(c, o.k, o.x, o.y - o.s * .1 * fl, o.s * (2 - fl), o.s * fl);
        }
      }
      D.draw(c);
      final blink = meInv > 0 && (meInv * 10).floor() % 2 == 1;
      if (!blink) {
        // Khủng long có hoạt ảnh chạy/nhảy; nén khi tiếp đất
        final sq = land > 0 ? math.sin(land / .16 * math.pi) * .14 : 0.0, hh = meW * 1.05;
        c.save();
        c.translate(meX, meY);
        c.scale(1 + sq, 1 - sq);
        if (dino != null) {
          anim(c, dino, meY < ground - 1 ? 'jump' : 'run', meY < ground - 1 ? jumpT : t * (1 + _v0(lv)), 0, -hh / 2 + hh * .04, hh);
        } else {
          draw(c, 'T-Rex', 0, -meW * .45, meW, meW, true);
        }
        c.restore();
      }
      F.draw(c);
      c.restore();
      hud(c, W, score: coinN);
      hearts(c, W, lives);
      c.fillStyle = 'rgba(0,0,0,.28)';
      roundRect(c, W / 2 - 90, 10, 180, 44, 22);
      c.fill();
      c.fillStyle = '#fff';
      c.textAlign = 'center';
      c.font = '800 26px';
      c.fillText('🏃 ${dist.floor()}/$need m', W / 2, 42);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Chạy $need mét', 'Run $need meters'), tr('Chạm để nhảy · Chạm 2 lần để nhảy cao', 'Tap to jump · Tap twice to jump higher'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('VẤP NGÃ RỒI!', 'YOU TRIPPED!'), tr('${dist.floor()}/$need mét', '${dist.floor()}/$need meters'));
      }
    },
  );
}

// ---------- 7. Ếch qua đường: nhảy qua đường xe chạy và sông có khúc gỗ, về tới bờ bên kia ----------
class _Item {
  _Item(this.x, this.len, this.img, this.ph);
  double x;
  final int len;
  final String img;
  final double ph;
}

class _Lane {
  _Lane(this.k, [this.v = 0, this.items = const [], this.span = 0]);
  final String k;
  final double v, span;
  final List<_Item> items;
}

Future<LoopGame> frogger(Fun g) async {
  final lv = g.level, th = theme(lv), need = math.min(8, 2 + lv ~/ 10), tr = g.tr;
  const CARS = ['Automobile', 'Bus', 'Racing car', 'Police car', 'Delivery truck', 'Taxi'];
  final (shs, _) = await (sheets(['racing/racing', 'plat/enemies']), loadAll(['Frog', 'Wood', 'Lotus', 'Red heart', 'Glowing star', ...CARS])).wait;
  final rs = shs[0], en = shs[1];
  final c = g.c, W = g.W, H = g.H;
  final F = fx(), D = dust(200), SH = shaker();
  // Xe nhìn từ trên (Kenney Racing) thay hình xe nghiêng
  const CAR_SPR = ['car_red_1', 'car_blue_3', 'car_green_5', 'car_yellow_1', 'car_black_3', 'car_purple_5', 'car_blue_1', 'car_yellow_3'];
  // Hàng từ dưới lên: 0 bờ, đường (xe), dải cỏ, sông (gỗ), đích. Cấp cao nhiều làn hơn.
  final roadN = math.min(5, 2 + lv ~/ 12), riverN = lv < 5 ? 0 : math.min(4, 1 + (lv - 5) ~/ 14);
  final kinds = ['safe', for (var i = 0; i < roadN; i++) 'road', 'safe', for (var i = 0; i < riverN; i++) 'river', 'goal'];
  // bàn lấp màn dọc (tối thiểu 5 cột), căn giữa phần dư
  final R = kinds.length, top0 = W < 640 ? 110.0 : 70.0, cs = math.min((H - top0 - 10) / R, W / 5), cols = (W / cs).floor();
  final top = top0 + math.max(0, (H - top0 - 10 - R * cs) / 2);
  double rowY(num r) => top + (R - 1 - r) * cs;
  final lanes = <_Lane>[];
  for (var r = 0; r < R; r++) {
    final k = kinds[r];
    if (k != 'road' && k != 'river') {
      lanes.add(_Lane(k));
      continue;
    }
    final dir = r % 2 == 1 ? 1 : -1, v = dir * cs * ramp(lv, 1.3, 3.2) * rand(.8, 1.25);
    final items = <_Item>[], len = k == 'river' ? ramp(lv, 3, 2).round() : 1, n = k == 'river' ? 3 : ramp(lv, 2, 4).round();
    final span = W + cs * 4;
    for (var i = 0; i < n; i++) {
      items.add(_Item(i * span / n + rand(0, cs), len, k == 'road' ? pick(CAR_SPR) : 'Wood', rand(0, 6)));
    }
    lanes.add(_Lane(k, v, items, span));
  }
  var meR = 0, meFace = 1, crossed = 0, lives = 3;
  double meX = 0, meDx = 0, meDr = 0, t = 0, endT = 0, hop = 0, botT = 0;
  FunEnd? end;
  meX = meDx = ((cols / 2).floor() + .5) * cs;
  void die() {
    final L0 = lanes[meR], y0 = rowY(meR) + cs / 2;
    if (L0.k == 'river') {
      for (var k = 0; k < 14; k++) {
        D.emit(meX, y0, rand(-120, 120), rand(-220, -80), life: .7, r: 4, grow: 0, c: '#d0ebff', k: 2, g: 600, a: 1);
      }
    } else {
      D.sparks(meX, y0, 14, '#ffe066', 260);
      SH.add(8);
    }
    lives--;
    g.sfx('hit');
    if (lives <= 0) end = FunEnd(win: false, score: crossed * 10);
    meR = 0;
    meX = ((cols / 2).floor() + .5) * cs;
  }

  void onDir(String d) {
    if (end != null || t < 2) return;
    final dx = _DIRS[d]![0], dy = _DIRS[d]![1];
    meX = math.max(cs / 2, math.min(W - cs / 2, meX + dx * cs));
    meR = math.max(0, math.min(R - 1, meR - dy));
    if (dx != 0) meFace = dx;
    hop = .18;
    g.sfx('jump');
    if (kinds[meR] == 'goal') {
      crossed++;
      g.sfx('win');
      F.burst(meX, rowY(meR) + cs / 2, 24);
      for (var k = 0; k < 10; k++) {
        D.emit(meX, rowY(meR) + cs / 2, rand(-150, 150), rand(-200, -50), life: .8, r: 4, grow: 0, c: '#d0ebff', k: 2, g: 500, a: 1);
      }
      F.text(meX, rowY(meR), '$crossed/$need', '#ffd43b');
      if (crossed >= need) {
        end = FunEnd(win: true, score: crossed * 10 + lives * 5);
        return;
      }
      meR = 0;
    }
  }

  g.dirInput(() => Offset(meX, rowY(meR) + cs / 2), onDir);
  // Tự chơi (test): nhảy lên khi hàng trên an toàn
  bool safeAhead(int r) {
    final L = lanes[r];
    if (L.k == 'road') {
      for (final it in L.items) {
        for (var k = 0; k <= 5; k++) {
          if ((it.x + cs * .5 + L.v * k * .1 - meX).abs() < cs * 1.1) return false;
        }
      }
      return true;
    }
    if (L.k == 'river') return L.items.any((it) => meX > it.x + cs * .1 && meX < it.x + it.len * cs - cs * .1);
    return true;
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      hop = math.max(0, hop - dt);
      D.update(dt);
      SH.update(dt);
      // Vị trí vẽ đuổi theo vị trí thật (nhảy mượt từ ô này sang ô kia)
      meDx = (meDx - meX).abs() > cs * 2.5 ? meX : approach(meDx, meX, 22, dt);
      meDr = (meDr - meR).abs() > 1.5 ? meR.toDouble() : approach(meDr, meR.toDouble(), 22, dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (g.bot) {
        botT -= dt;
        if (botT <= 0 && meR + 1 < R && safeAhead(meR + 1)) {
          botT = .3;
          onDir('u');
        }
      }
      for (final L in lanes) {
        for (final it in L.items) {
          it.x += L.v * dt;
          if (L.v > 0 && it.x > W + cs * 2) it.x -= L.span;
          if (L.v < 0 && it.x < -cs * 2 - it.len * cs) it.x += L.span;
        }
      }
      if (end != null) return null;
      final L = lanes[meR];
      if (L.k == 'road' && L.items.any((it) => (it.x + cs * .5 - meX).abs() < cs * .8)) {
        die();
      } else if (L.k == 'river') {
        final onLog = L.items.any((it) => meX > it.x - cs * .2 && meX < it.x + it.len * cs + cs * .2);
        if (!onLog) {
          die();
        } else {
          meX += L.v * dt;
          if (meX < 0 || meX > W) die();
        }
      }
      return null;
    },
    draw: () {
      c.save();
      SH.apply(c);
      _sky(c, W, H, th);
      for (var r = 0; r < R; r++) {
        final k = kinds[r], y = rowY(r);
        c.fillStyle = k == 'road' ? '#495057' : k == 'river' ? '#339af0' : k == 'goal' ? '#8ce99a' : hex(th.ground);
        c.fillRect(0, y, W, cs);
        if (k == 'road') {
          c.fillStyle = 'rgba(255,255,255,.6)';
          for (var x = 0.0; x < W; x += 60) {
            c.fillRect(x, y + cs - 3, 30, 3);
          }
          c.fillStyle = 'rgba(0,0,0,.12)';
          c.fillRect(0, y, W, 4);
        }
        if (k == 'river') {
          c.strokeStyle = 'rgba(255,255,255,.35)';
          c.lineWidth = 2;
          final v = lanes[r].v;
          for (var x = -40.0; x < W + 40; x += 46) {
            final xx = x + _jsMod(t * v * .3, 46);
            c.beginPath();
            c.arc(xx, y + cs * (.3 + _jsMod(x / 46, 2) * .4), 8, math.pi * 1.1, math.pi * 1.9);
            c.stroke();
          }
        }
        if (k == 'goal') {
          for (var x = cs / 2; x < W; x += cs * 1.6) {
            draw(c, 'Lotus', x, y + cs / 2 + math.sin(t * 2 + x) * 2, cs * .7);
          }
        }
      }
      for (var r = 0; r < R; r++) {
        final L = lanes[r], y = rowY(r);
        for (final it in L.items) {
          if (L.k == 'road') {
            // Xe nhìn từ trên, quay đầu theo chiều chạy, rung nhẹ thân xe; khói xả phía sau
            final cxx = it.x + cs * .5, jig = math.sin(t * 20 + it.ph) * .6;
            spr(c, rs, it.img, cxx, y + cs / 2 + jig, cs * 1.35, rot: L.v > 0 ? math.pi / 2 : -math.pi / 2);
            if (random() < .08) D.emit(cxx - L.v.sign * cs * .7, y + cs / 2, -L.v * .2, rand(-20, 20), life: .5, r: 3, grow: 8, c: 'rgba(200,200,200,1)', a: .5);
          } else {
            final bob = math.sin(t * 2 + it.ph) * 2, lw = it.len * cs;
            c.fillStyle = 'rgba(0,0,0,.15)';
            roundRect(c, it.x + 4, y + cs * .2 + 5, lw, cs * .66, cs * .3);
            c.fill();
            c.fillStyle = '#8d5524';
            roundRect(c, it.x, y + cs * .15 + bob, lw, cs * .7, cs * .3);
            c.fill();
            c.fillStyle = '#a0522d';
            c.fillRect(it.x + 8, y + cs * .32 + bob, lw - 16, 4);
            c.fillRect(it.x + 14, y + cs * .58 + bob, lw - 30, 3);
            c.fillStyle = '#e0a96d';
            c.beginPath();
            c.ellipse(it.x + lw - cs * .12, y + cs / 2 + bob, cs * .1, cs * .3, 0, 0, 7);
            c.fill();
            c.strokeStyle = '#a0522d';
            c.lineWidth = 2;
            c.beginPath();
            c.ellipse(it.x + lw - cs * .12, y + cs / 2 + bob, cs * .05, cs * .16, 0, 0, 7);
            c.stroke();
          }
        }
      }
      D.draw(c);
      // Ếch Kenney: đang nhảy dùng khung bật, cao lên theo vòng cung
      final hk = hop > 0 ? math.sin((1 - hop / .18) * math.pi) : 0.0, fy = top + (R - 1 - meDr) * cs + cs / 2;
      c.fillStyle = 'rgba(0,0,0,.18)';
      c.beginPath();
      c.ellipse(meDx, fy + cs * .3, cs * .3 * (1 - hk * .3), cs * .1, 0, 0, 7);
      c.fill();
      if (en != null) {
        spr(c, en, hop > 0 ? 'frog_jump' : (math.sin(t * 3) > .9 ? 'frog_rest' : 'frog_idle'), meDx, fy - hk * cs * .45, cs * .85, flip: meFace > 0);
      } else {
        draw(c, 'Frog', meDx, fy - hk * 60, cs * .85);
      }
      F.draw(c);
      c.restore();
      hud(c, W, score: crossed);
      hearts(c, W, lives);
      goalPill(c, W, crossed, need, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Qua đường $need lần', 'Cross $need times'),
            tr('Chạm hoặc vuốt để ếch nhảy · Né xe · Đứng trên khúc gỗ', 'Tap or swipe to hop · Dodge cars · Ride the logs'), tr);
      }
      if (end != null) banner(c, W, H, endText(end!.win, lv, tr), tr('$crossed/$need lần', '$crossed/$need times'));
    },
  );
}

// ---------- 8. Bóng bàn: kéo vợt dưới, đánh thắng máy ----------
class _Ball {
  _Ball(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy;
}

Future<LoopGame> pong(Fun g) async {
  final lv = g.level, th = theme(lv), need = lv < 20 ? 3 : 5, tr = g.tr;
  final (shs, _) = await (sheets(['puzzle/puzzle']), loadAll(['Robot', 'Glowing star', g.hero])).wait;
  final pz = shs[0];
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), D = dust(160), SH = shaker();
  const top = 80.0;
  final bot = H - 20;
  final trail = List.generate(10, (_) => [0.0, 0.0]);
  var trailI = 0;
  double squash = 0, sqA = 0, meHit = 0, aiHit = 0, spin = 0;
  final pw = S * ramp(lv, .3, .2), R = S * .025;
  const ph = 18.0;
  double meX = W / 2, meTx = W / 2, aiX = W / 2;
  late _Ball ball;
  var mine = 0, his = 0, rally = 0;
  double t = 0, endT = 0, serveT = 1;
  FunEnd? end;
  void serve(bool dirDown) {
    ball = _Ball(W / 2, (top + bot) / 2, rand(-.5, .5) * S, (dirDown ? 1 : -1) * S * ramp(lv, .55, .95));
    serveT = .8;
    rally = 0;
  }

  serve(true);
  g.onDown((e) => meTx = e.x);
  g.onMove((e) {
    if (e.buttons != 0 || !e.mouse) meTx = e.x;
  });
  final aiSpeed = S * ramp(lv, .45, 1.15), aiErr = ramp(lv, .35, .08);
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      squash = math.max(0, squash - dt);
      meHit = math.max(0, meHit - dt);
      aiHit = math.max(0, aiHit - dt);
      trail[trailI][0] = ball.x;
      trail[trailI][1] = ball.y;
      trailI = (trailI + 1) % trail.length;
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (g.bot) meTx = ball.x + (aiX > W / 2 ? 1 : -1) * pw * .35; // tự chơi (test): vợt theo bóng, đánh chéo xa máy
      meX = approach(meX, math.max(pw / 2, math.min(W - pw / 2, meTx)), 16, dt);
      // Máy đuổi theo bóng, có độ trễ và sai số
      final aim = ball.vy < 0 ? ball.x + math.sin(t * 1.3) * pw * aiErr : W / 2;
      aiX += math.max(-aiSpeed * dt, math.min(aiSpeed * dt, aim - aiX));
      if (serveT > 0) {
        serveT -= dt;
        return null;
      }
      void hitPad(double px, double py, bool down) {
        if ((ball.y - py).abs() < ph / 2 + R && (ball.x - px).abs() < pw / 2 + R && (down ? ball.vy > 0 : ball.vy < 0)) {
          final off = (ball.x - px) / (pw / 2), sp = math.min(S * 1.9, hypot(ball.vx, ball.vy) * 1.05);
          ball.vx = sp * off * .75;
          ball.vy = (down ? -1 : 1) * math.sqrt(math.max(1, sp * sp - ball.vx * ball.vx));
          g.sfx('pop');
          D.sparks(ball.x, ball.y, 8, down ? '#ffe066' : '#ff8787', 220);
          rally++;
          squash = .12;
          sqA = 0;
          spin = off * 12;
          if (down) {
            meHit = .15;
          } else {
            aiHit = .15;
          }
          if (rally > 4) SH.add(1.5);
        }
      }

      for (var k = 0; k < 3; k++) {
        ball.x += ball.vx * dt / 3;
        ball.y += ball.vy * dt / 3;
        if (ball.x < R || ball.x > W - R) {
          ball.vx *= -1;
          ball.x = math.max(R, math.min(W - R, ball.x));
          g.sfx('tap');
          squash = .1;
          sqA = math.pi / 2;
          D.sparks(ball.x, ball.y, 4, '#fff', 140);
        }
        hitPad(meX, bot - 40, true);
        hitPad(aiX, top + 30, false);
      }
      if (ball.y > bot + 20) {
        his++;
        g.sfx('wrong');
        SH.add(7);
        if (his >= need) {
          end = FunEnd(win: false, score: mine * 5);
        } else {
          serve(true);
        }
      }
      if (ball.y < top - 20) {
        mine++;
        g.sfx('win');
        F.burst(ball.x, top, 24);
        SH.add(5);
        F.text(W / 2, H / 2, tr('GHI ĐIỂM!', 'SCORE!'), '#ffd43b');
        if (mine >= need) {
          end = FunEnd(win: true, score: mine * 5 + 10);
        } else {
          serve(false);
        }
      }
      return null;
    },
    draw: () {
      c.save();
      SH.apply(c);
      _sky(c, W, H, th);
      c.fillStyle = 'rgba(0,0,0,.2)';
      roundRect(c, 16, top - 2, W - 20, bot - top + 20, 24);
      c.fill();
      c.fillStyle = '#1971c2';
      roundRect(c, 10, top - 10, W - 20, bot - top + 20, 24);
      c.fill();
      c.strokeStyle = 'rgba(255,255,255,.9)';
      c.lineWidth = 4;
      roundRect(c, 20, top, W - 40, bot - top, 16);
      c.stroke();
      c.strokeStyle = 'rgba(255,255,255,.7)';
      c.setLineDash([14, 12]);
      c.beginPath();
      c.moveTo(10, (top + bot) / 2);
      c.lineTo(W - 10, (top + bot) / 2);
      c.stroke();
      c.setLineDash([]);
      // Vợt sprite Kenney, lún xuống khi đánh trúng
      final ak = aiHit > 0 ? math.sin(aiHit / .15 * math.pi) * 6 : 0.0, mk = meHit > 0 ? math.sin(meHit / .15 * math.pi) * 6 : 0.0;
      if (pz != null) {
        sprBox(c, pz, 'paddleRed', aiX, top + 30 - ak, pw, ph * 1.5);
      } else {
        c.fillStyle = '#ff6b6b';
        roundRect(c, aiX - pw / 2, top + 30 - ph / 2, pw, ph, 9);
        c.fill();
      }
      fig.drawHead(c.canvas, aiX, top + 2 - ak, 18, fig.kBot);
      if (pz != null) {
        sprBox(c, pz, 'paddleBlu', meX, bot - 40 + mk, pw, ph * 1.5);
      } else {
        c.fillStyle = '#ffd43b';
        roundRect(c, meX - pw / 2, bot - 40 - ph / 2, pw, ph, 9);
        c.fill();
      }
      fig.drawHead(c.canvas, meX, bot - 10 + mk, 18, fig.heroOf(g.hero));
      for (var i = 0; i < trail.length; i++) {
        final p = trail[(trailI + i) % trail.length];
        c.globalAlpha = i / trail.length * .3;
        c.fillStyle = '#fff';
        c.beginPath();
        c.arc(p[0], p[1], R * (.3 + i / trail.length * .6), 0, 7);
        c.fill();
      }
      c.globalAlpha = 1;
      D.draw(c);
      // Bóng méo khi nảy, xoay theo cú đánh
      final sq = squash > 0 ? math.sin(squash / .12 * math.pi) * .3 : 0.0;
      c.save();
      c.translate(ball.x, ball.y);
      c.rotate(sqA);
      c.scale(1 + sq, 1 - sq);
      c.rotate(t * spin);
      if (pz != null) {
        spr(c, pz, 'ballGrey', 0, 0, R * 2.3);
      } else {
        c.fillStyle = '#fff';
        c.beginPath();
        c.arc(0, 0, R, 0, 7);
        c.fill();
      }
      c.restore();
      F.draw(c);
      c.restore();
      c.fillStyle = 'rgba(0,0,0,.3)';
      roundRect(c, W / 2 - 80, 10, 160, 50, 25);
      c.fill();
      c.fillStyle = '#fff';
      c.textAlign = 'center';
      c.font = '800 32px';
      c.fillText('$mine : $his', W / 2, 46);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Ghi $need điểm trước máy', 'Score $need points before the robot'),
            tr('Kéo ngón tay để di chuyển vợt vàng', 'Drag your finger to move the yellow paddle'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('MÁY THẮNG RỒI!', 'THE ROBOT WON!'), '$mine : $his');
    },
  );
}

// ---------- 9. Ăn đậu: đi trong mê cung ăn hết hạt, tránh ma; ăn sao thì ma sợ ----------
List<List<int>> _makeMaze(int cols, int rows) {
  // Mê cung có nhiều lối vòng: đào kiểu DFS rồi đục thêm tường.
  final g = List.generate(rows, (_) => List.filled(cols, 1));
  final st = <List<int>>[
    [1, 1]
  ];
  g[1][1] = 0;
  while (st.isNotEmpty) {
    final x = st.last[0], y = st.last[1];
    final nb = [
      for (final d in const [
        [2, 0],
        [-2, 0],
        [0, 2],
        [0, -2]
      ])
        [x + d[0], y + d[1], d[0], d[1]]
    ].where((p) => p[0] > 0 && p[1] > 0 && p[0] < cols - 1 && p[1] < rows - 1 && g[p[1]][p[0]] == 1).toList();
    if (nb.isEmpty) {
      st.removeLast();
      continue;
    }
    final p = pick(nb), a = p[0], b = p[1], dx = p[2], dy = p[3];
    g[y + dy ~/ 2][x + dx ~/ 2] = 0;
    g[b][a] = 0;
    st.add([a, b]);
  }
  for (var i = 0; i < cols * rows / 6; i++) {
    final x = rand(1, cols - 1).floor(), y = rand(1, rows - 1).floor();
    if ((x + y) % 2 == 1 && g[y][x] == 1) g[y][x] = 0;
  }
  return g;
}

class _Actor {
  _Actor(this.x, this.y, this.px, this.py, {this.dir});
  int x, y, px, py;
  double k = 0;
  String? dir, next;
}

Future<LoopGame> pacman(Fun g) async {
  final lv = g.level, th = theme(lv), tr = g.tr;
  final (shs, _) = await (sheets(['puzzle/puzzle', 'fxa/fx']), loadAll(['Ghost', 'Glowing star', 'Cherries', 'Red heart', g.hero])).wait;
  final pz = shs[0];
  final c = g.c, W = g.W, H = g.H;
  final F = fx(), top = W < 640 ? 110.0 : 70.0, D = dust(160), SH = shaker();
  final WALL = const ['sq_green', 'sq_yellow', 'sq_blue', 'sq_purple', 'sq_red', 'sq_orange'][(lv ~/ 10) % 6];
  final cols = ramp(lv, 11, 19).round() | 1, rows = (cols * math.min(1.2, (H - top) / W * 1.0)).round() | 1;
  final cs = math.min(W / cols, (H - top - 10) / rows).floorToDouble(), ox = (W - cols * cs) / 2, oy = top;
  final gr = _makeMaze(cols, rows);
  int key(int x, int y) => y * cols + x;
  final dots = <int>{}, stars = <int>{};
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      if (gr[y][x] == 0 && !(x == 1 && y == 1)) dots.add(key(x, y));
    }
  }
  for (final p in [
    [1, rows - 2],
    [cols - 2, 1],
    [cols - 2, rows - 2]
  ]) {
    if (gr[p[1]][p[0]] == 0) {
      dots.remove(key(p[0], p[1]));
      stars.add(key(p[0], p[1]));
    }
  }
  final total = dots.length;
  bool open(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows && gr[y][x] == 0;
  final me = _Actor(1, 1, 1, 1);
  final nG = math.min(5, 1 + lv ~/ 10);
  final ghosts = List.generate(nG, (i) {
    final x = cols - 2, y = rows - 2 - (i % 2) * 2;
    final ok = open(x, y);
    return _Actor(ok ? x : cols - 2, ok ? y : rows - 2, x, y, dir: 'l');
  });
  var lives = 3, eaten = 0;
  double t = 0, endT = 0, scared = 0;
  FunEnd? end;
  g.dirInput(() => Offset(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs), (d) => me.next = d);
  final meSp = ramp(lv, 4.2, 6), gSp = ramp(lv, 2.4, 5.4);
  void moveActor(_Actor a, double sp, double dt, String? Function(_Actor a) choose) {
    a.k += sp * dt;
    while (a.k >= 1) {
      a.k -= 1;
      a.px = a.x;
      a.py = a.y;
      final d = choose(a);
      if (d != null && open(a.x + _DIRS[d]![0], a.y + _DIRS[d]![1])) {
        a.dir = d;
        a.x += _DIRS[d]![0];
        a.y += _DIRS[d]![1];
      } else {
        a.dir = null;
        a.k = 0;
      }
    }
  }

  // Tự chơi (test): đường ngắn nhất (BFS) tới hạt gần nhất, tránh ô có ma
  String? botDir() {
    final from = <int, int>{key(me.x, me.y): -1};
    final q = <int>[key(me.x, me.y)];
    final block = scared > 0 ? <int>{} : {for (final gh in ghosts) key(gh.x, gh.y)};
    for (var i = 0; i < q.length; i++) {
      final k0 = q[i], x = k0 % cols, y = k0 ~/ cols;
      if (i > 0 && (dots.contains(k0) || stars.contains(k0))) {
        var k = k0;
        while (from[k] != key(me.x, me.y)) {
          k = from[k]!;
        }
        final nx = k % cols, ny = k ~/ cols;
        return nx > me.x ? 'r' : nx < me.x ? 'l' : ny > me.y ? 'd' : 'u';
      }
      for (final d in _DIRS.values) {
        final nx = x + d[0], ny = y + d[1], nk = key(nx, ny);
        if (open(nx, ny) && !from.containsKey(nk) && !block.contains(nk)) {
          from[nk] = k0;
          q.add(nk);
        }
      }
    }
    return null;
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      scared = math.max(0, scared - dt);
      if (g.bot) me.next = botDir() ?? me.next;
      moveActor(me, meSp, dt, (a) => (a.next != null && open(a.x + _DIRS[a.next]![0], a.y + _DIRS[a.next]![1])) ? a.next : a.dir);
      final k = key(me.x, me.y);
      if (dots.remove(k)) {
        eaten++;
        if (eaten % 3 == 0) g.sfx('count');
        D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 3, '#ffe066', 90);
      }
      if (stars.remove(k)) {
        scared = 6;
        g.sfx('power');
        SH.add(4);
        D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 16, '#74c0fc', 260);
        F.text(ox + me.x * cs, oy + me.y * cs, tr('MA SỢ RỒI!', 'GHOSTS ARE SCARED!'), '#4dabf7');
      }
      for (final gh in ghosts) {
        moveActor(gh, scared > 0 ? gSp * .6 : gSp, dt, (a) {
          final opts2 = _DIRS.keys
              .where((d) => open(a.x + _DIRS[d]![0], a.y + _DIRS[d]![1]) && !(a.dir != null && _DIRS[d]![0] == -_DIRS[a.dir]![0] && _DIRS[d]![1] == -_DIRS[a.dir]![1]))
              .toList();
          if (opts2.isEmpty) {
            for (final d in _DIRS.keys) {
              if (open(a.x + _DIRS[d]![0], a.y + _DIRS[d]![1])) return d;
            }
            return null;
          }
          // Đuổi theo bé (hoặc chạy trốn khi sợ), có ngẫu nhiên để không quá khó
          if (random() < ramp(lv, .45, .8)) {
            opts2.sort((p, q) {
              final dp = (a.x + _DIRS[p]![0] - me.x).abs() + (a.y + _DIRS[p]![1] - me.y).abs(),
                  dq = (a.x + _DIRS[q]![0] - me.x).abs() + (a.y + _DIRS[q]![1] - me.y).abs();
              return scared > 0 ? dq - dp : dp - dq;
            });
          } else {
            shuffleInPlace(opts2);
          }
          return opts2[0];
        });
        if (gh.x == me.x && gh.y == me.y) {
          if (scared > 0) {
            g.sfx('boom');
            F.burst(ox + (gh.x + .5) * cs, oy + (gh.y + .5) * cs, 18);
            D.puff(ox + (gh.x + .5) * cs, oy + (gh.y + .5) * cs, 6, 'rgba(255,255,255,1)', 80, cs * .2);
            SH.add(4);
            gh.x = cols - 2;
            gh.y = rows - 2;
            if (!open(gh.x, gh.y)) gh.x = me.x;
            gh.k = 0;
          } else {
            lives--;
            g.sfx('hit');
            SH.add(9);
            D.sparks(ox + (me.x + .5) * cs, oy + (me.y + .5) * cs, 16, '#ff8787', 260);
            me.x = me.y = 1;
            me.k = 0;
            me.dir = me.next = null;
            if (lives <= 0) end = FunEnd(win: false, score: eaten);
          }
        }
      }
      if (dots.isEmpty && end == null) {
        end = FunEnd(win: true, score: eaten + lives * 10);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      c.fillStyle = '#10153a';
      c.fillRect(0, 0, W, H);
      c.save();
      SH.apply(c);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          if (gr[y][x] == 1) {
            if (pz != null) {
              sprBox(c, pz, WALL, ox + (x + .5) * cs, oy + (y + .5) * cs, cs - 2, cs - 2);
            } else {
              c.fillStyle = hex(th.edge);
              roundRect(c, ox + x * cs + 2, oy + y * cs + 2, cs - 4, cs - 4, cs * .25);
              c.fill();
            }
          }
        }
      }
      // Hạt đậu lấp lánh theo sóng
      c.fillStyle = '#ffe066';
      for (final d in dots) {
        final x = d % cols, y = d ~/ cols;
        c.beginPath();
        c.arc(ox + (x + .5) * cs, oy + (y + .5) * cs, cs * (.11 + math.max(0, math.sin(t * 4 - (x + y) * .5)) * .04), 0, 7);
        c.fill();
      }
      for (final s in stars) {
        final x = s % cols, y = s ~/ cols;
        draw(c, 'Glowing star', ox + (x + .5) * cs, oy + (y + .5) * cs, cs * (.8 + math.sin(t * 6) * .1));
      }
      (double, double) pos(_Actor a) =>
          (ox + (a.px + (a.x - a.px) * math.min(1, a.k) + .5) * cs, oy + (a.py + (a.y - a.py) * math.min(1, a.k) + .5) * cs);
      const GC = ['#ff6b6b', '#cc5de8', '#ff922b', '#20c997', '#f06595'];
      for (var i = 0; i < ghosts.length; i++) {
        final gh = ghosts[i];
        final (x, y) = pos(gh);
        // Vòng màu dưới chân ma; khi sợ thì ma mờ, vòng xanh nhấp nháy.
        c.fillStyle = scared > 0 ? ((t * 6).floor() % 2 == 1 ? '#4dabf7' : '#d0ebff') : GC[i % GC.length];
        c.globalAlpha = .55;
        c.beginPath();
        c.arc(x, y, cs * .48, 0, 7);
        c.fill();
        c.globalAlpha = 1;
        // Ma bồng bềnh: phập phồng, nghiêng theo hướng đi; khi sợ thì run
        final wob = math.sin(t * 8 + i), lean = gh.dir == 'l' ? -.15 : gh.dir == 'r' ? .15 : 0.0, shiver = scared > 0 ? math.sin(t * 60) * 1.5 : 0.0;
        c.save();
        c.translate(x + shiver, y + math.sin(t * 6 + i) * 3);
        c.rotate(lean);
        c.scale(1 + wob * .05, 1 - wob * .05);
        draw(c, 'Ghost', 0, 0, cs * .9, cs * .9, gh.dir == 'r', 0, scared > 0 ? .6 : 1);
        c.restore();
      }
      final (mx, my) = pos(me);
      final bobk = (math.sin(t * 12)).abs() * (me.dir != null ? 1 : 0);
      // Web: `me.dir[0] < 0` so sánh chữ với số nên luôn quay phải; giữ nguyên.
      fig.drawHead(c.canvas, mx, my - bobk * cs * .06, cs * .42, fig.heroOf(g.hero), face: 1, t: t);
      D.draw(c);
      c.restore();
      F.draw(c);
      hud(c, W, score: eaten);
      hearts(c, W, lives);
      goalPill(c, W, total - dots.length, total, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Ăn hết $total hạt đậu', 'Eat all $total dots'),
            tr('Vuốt hoặc chạm để đi · Ăn ngôi sao thì ma sợ', 'Swipe or tap to move · Eat a star to scare the ghosts'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('MA BẮT MẤT RỒI!', 'THE GHOST CAUGHT YOU!'),
            tr('${total - dots.length}/$total hạt', '${total - dots.length}/$total dots'));
      }
    },
  );
}

// ---------- 10. Ghép 3: đổi chỗ 2 ô cạnh nhau để có 3 hình giống nhau thẳng hàng ----------
class _Gem {
  _Gem(this.k, this.y);
  String k;
  double y, vy = 0, ox = 0, oy = 0;
}

class _Pop {
  _Pop(this.k, this.x, this.y);
  final String k;
  final double x, y;
  double t = .3;
}

Future<LoopGame> match3(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 20, 90).round(), moves0 = ramp(lv, 22, 18).round(), tr = g.tr;
  const GEM = ['Red apple', 'Banana', 'Grapes', 'Strawberry', 'Tangerine', 'Watermelon', 'Cherries'];
  final kinds = GEM.sublist(0, ramp(lv, 4, 7).round());
  await loadAll([...kinds, 'Glowing star', 'Collision']);
  final c = g.c, W = g.W, H = g.H;
  const N = 7;
  final top = W < 640 ? 160.0 : 80.0, cs = math.min((W - 20) / N, (H - top - 20) / N).floorToDouble(), ox = (W - N * cs) / 2, oy = top;
  final F = fx(), D = dust(220), SH = shaker(), pops = <_Pop>[];
  // rơi vào bảng lúc mở màn
  final gr = List.generate(N, (_) => List<_Gem?>.generate(N, (_) => _Gem(pick(kinds), -rand(2, 6) * cs)));
  Set<(int, int)> matches() {
    final m = <(int, int)>{};
    String? k(int x, int y) => gr[y][x]?.k;
    for (var y = 0; y < N; y++) {
      for (var x = 0; x < N - 2; x++) {
        if (k(x, y) != null && k(x, y) == k(x + 1, y) && k(x, y) == k(x + 2, y)) {
          for (var i = 0; i < 3; i++) {
            m.add((x + i, y));
          }
        }
      }
    }
    for (var x = 0; x < N; x++) {
      for (var y = 0; y < N - 2; y++) {
        if (k(x, y) != null && k(x, y) == k(x, y + 1) && k(x, y) == k(x, y + 2)) {
          for (var i = 0; i < 3; i++) {
            m.add((x, y + i));
          }
        }
      }
    }
    return m;
  }

  // Bảng mở đầu không có sẵn hàng 3
  for (var m = matches(); m.isNotEmpty; m = matches()) {
    for (final (x, y) in m) {
      gr[y][x]!.k = pick(kinds);
    }
  }
  var score = 0, moves = moves0, combo = 0;
  double t = 0, endT = 0, botT = 0;
  FunEnd? end;
  (int, int)? sel, down;
  var busy = false;
  (int, int)? cell(Ptr e) {
    final cx = ((e.x - ox) / cs).floor(), cy = ((e.y - oy) / cs).floor();
    return cx >= 0 && cy >= 0 && cx < N && cy < N ? (cx, cy) : null;
  }

  // Đổi chỗ có trượt mượt: ô mới mang độ lệch về vị trí cũ rồi trượt về 0
  void swap((int, int) a, (int, int) b) {
    final A = gr[a.$2][a.$1], B2 = gr[b.$2][b.$1];
    gr[a.$2][a.$1] = B2;
    gr[b.$2][b.$1] = A;
    if (A != null) {
      A.ox = (a.$1 - b.$1) * cs;
      A.oy = (a.$2 - b.$2) * cs;
    }
    if (B2 != null) {
      B2.ox = (b.$1 - a.$1) * cs;
      B2.oy = (b.$2 - a.$2) * cs;
    }
  }

  // async tryMove của web: các await wait(ms) thành g.after(giây)
  void cascade() {
    final m = matches();
    if (m.isEmpty) {
      if (score >= need) {
        end = FunEnd(win: true, score: score + moves * 2);
        g.sfx('win');
      } else if (moves <= 0) {
        end = FunEnd(win: false, score: score);
      }
      busy = false;
      return;
    }
    combo++;
    final pts = m.length * combo;
    score += pts;
    for (final (x, y) in m) {
      final px = ox + (x + .5) * cs, py = oy + (y + .5) * cs;
      pops.add(_Pop(gr[y][x]!.k, px, py));
      D.sparks(px, py, 6, '#fff3bf', 200);
      gr[y][x] = null;
    }
    SH.add(1.5 + combo * 1.5);
    g.sfx(combo > 1 ? 'win' : 'coin');
    F.text(W / 2, oy - 10, combo > 1 ? 'x$combo +$pts' : '+$pts', '#ffd43b');
    g.after(.22, () {
      // Cột dồn xuống: mỗi ô nhớ độ lệch (y âm) bằng quãng phải rơi, rơi có trọng lực rồi nảy nhẹ
      for (var x = 0; x < N; x++) {
        final col = <(_Gem, int)>[];
        for (var y = N - 1; y >= 0; y--) {
          if (gr[y][x] != null) col.add((gr[y][x]!, y));
        }
        for (var y = N - 1, i = 0; y >= 0; y--, i++) {
          if (i < col.length) {
            final (cc, y0) = col[i];
            cc.y += (y0 - y) * cs;
            gr[y][x] = cc;
          } else {
            gr[y][x] = _Gem(pick(kinds), -(i - col.length + 1) * cs - cs * .5);
          }
        }
      }
      g.after(.26, cascade);
    });
  }

  void tryMove((int, int) a, (int, int) b) {
    busy = true;
    swap(a, b);
    g.sfx('tap');
    g.after(.16, () {
      if (matches().isEmpty) {
        swap(a, b);
        g.sfx('wrong');
        busy = false;
        return;
      }
      moves--;
      combo = 0;
      cascade();
    });
  }

  // Tự chơi (test): tìm một nước đổi chỗ tạo được hàng 3
  ((int, int), (int, int))? findMove() {
    for (var y = 0; y < N; y++) {
      for (var x = 0; x < N; x++) {
        for (final b in [(x + 1, y), (x, y + 1)]) {
          if (b.$1 >= N || b.$2 >= N) continue;
          final A = gr[y][x], B = gr[b.$2][b.$1];
          gr[y][x] = B;
          gr[b.$2][b.$1] = A;
          final ok = matches().isNotEmpty;
          gr[y][x] = A;
          gr[b.$2][b.$1] = B;
          if (ok) return ((x, y), b);
        }
      }
    }
    return null;
  }

  g.onDown((e) {
    if (busy || end != null || t < 2) return;
    down = cell(e);
  });
  g.onUp((e) {
    if (down == null || busy || end != null) return;
    final up = cell(e), a = down!;
    down = null;
    if (up != null && (up.$1 != a.$1 || up.$2 != a.$2)) {
      final dx = (up.$1 - a.$1).sign, dy = (up.$2 - a.$2).sign;
      final b = (up.$1 - a.$1).abs() > (up.$2 - a.$2).abs() ? (a.$1 + dx, a.$2) : (a.$1, a.$2 + dy);
      sel = null;
      tryMove(a, b);
      return;
    }
    final s = sel;
    if (s != null && (s.$1 - a.$1).abs() + (s.$2 - a.$2).abs() == 1) {
      sel = null;
      tryMove(s, a);
    } else {
      sel = a;
      g.sfx('tap');
    }
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      for (var i = pops.length - 1; i >= 0; i--) {
        pops[i].t -= dt;
        if (pops[i].t <= 0) pops.removeAt(i);
      }
      for (final row in gr) {
        for (final cc in row) {
          if (cc == null) continue;
          if (cc.y < 0 || cc.vy != 0) {
            cc.vy += cs * 70 * dt;
            cc.y += cc.vy * dt;
            if (cc.y >= 0) {
              cc.y = 0;
              cc.vy = cc.vy > cs * 4 ? -cc.vy * .25 : 0;
            }
          }
          if (cc.ox != 0) cc.ox = cc.ox.abs() < .5 ? 0 : approach(cc.ox, 0, 18, dt);
          if (cc.oy != 0) cc.oy = cc.oy.abs() < .5 ? 0 : approach(cc.oy, 0, 18, dt);
        }
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (g.bot && t >= 2 && !busy) {
        botT -= dt;
        if (botT <= 0) {
          botT = .4;
          final mv = findMove();
          if (mv != null) {
            sel = null;
            tryMove(mv.$1, mv.$2);
          }
        }
      }
      return null;
    },
    draw: () {
      _sky(c, W, H, th);
      c.save();
      SH.apply(c);
      c.fillStyle = 'rgba(255,255,255,.55)';
      roundRect(c, ox - 8, oy - 8, N * cs + 16, N * cs + 16, 20);
      c.fill();
      for (var y = 0; y < N; y++) {
        for (var x = 0; x < N; x++) {
          if ((x + y) % 2 == 1) {
            c.fillStyle = 'rgba(0,0,0,.05)';
            c.fillRect(ox + x * cs, oy + y * cs, cs, cs);
          }
          final cc = gr[y][x];
          if (cc == null) continue;
          final isSel = sel != null && sel!.$1 == x && sel!.$2 == y;
          if (isSel) {
            c.fillStyle = 'rgba(255,212,59,.6)';
            roundRect(c, ox + x * cs + 2, oy + y * cs + 2, cs - 4, cs - 4, 12);
            c.fill();
          }
          // Ô chọn phập phồng; các ô thở nhẹ lệch pha cho bảng sinh động
          final br = isSel ? .86 + math.sin(t * 10) * .06 : .8 + math.sin(t * 2 + x * .7 + y * .5) * .015;
          if (cc.y < -cs * .3 && oy + (y + .5) * cs + cc.y < oy - cs * .3) continue;
          draw(c, cc.k, ox + (x + .5) * cs + cc.ox, oy + (y + .5) * cs + cc.y + cc.oy, cs * br, cs * br, false, isSel ? math.sin(t * 8) * .12 : 0);
        }
      }
      for (final p in pops) {
        final k = p.t / .3, s = cs * .8 * (k < .6 ? k / .6 : 1 + (1 - k) * 1.2);
        draw(c, p.k, p.x, p.y, s, s, false, 0, math.min(1, k * 2));
      }
      D.draw(c);
      c.restore();
      F.draw(c);
      hud(c, W, score: score);
      final mx = W < 640 ? 12.0 : W - 170, my = W < 640 ? 104.0 : 10.0;
      c.fillStyle = 'rgba(0,0,0,.28)';
      roundRect(c, mx, my, 158, 44, 22);
      c.fill();
      c.fillStyle = '#fff';
      c.textAlign = 'center';
      c.font = '800 24px';
      c.fillText(tr('Còn $moves lượt', '$moves moves left'), mx + 79, my + 31);
      goalPill(c, W, score, need, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Được $need điểm trong $moves0 lượt', 'Get $need points in $moves0 moves'),
            tr('Vuốt một hình sang ô bên cạnh để xếp 3 hình giống nhau', 'Swipe a picture to the next cell to line up 3 alike'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT LƯỢT RỒI!', 'OUT OF MOVES!'), tr('$score/$need điểm', '$score/$need points'));
      }
    },
  );
}
