// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Tiệm pizza, nông trại, lính cứu hoả, tìm đồ vật.
// CHỦ: agent F. Port của web js/games/funnew4.js. Mỗi lượt một cấp (ctx.level), 60 cấp.
// Người/con vật là sprite Kenney CC0 có hoạt ảnh (gói play/), đồ vật là hình Fluent Emoji 3D.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funnew4Games = {
  'pizza': const FunCanvasModule('pizza', pizza),
  'farm': const FunCanvasModule('farm', farm),
  'firefight': const FunCanvasModule('firefight', firefight),
  'hidden': const FunCanvasModule('hidden', hidden),
};

/// Hộp chữ nhật góc trên trái (x, y), rộng w cao h (inBox của web).
class _Box {
  _Box(this.x, this.y, this.w, this.h, [this.k = '']);
  double x, y, w, h;
  final String k;
  bool has(double px, double py) => px >= x && px <= x + w && py >= y && py <= y + h;
}

void _button(Ctx2D c, _Box b, String text, String color, [bool on = true]) {
  c.fillStyle = on ? color : 'rgba(0,0,0,.25)';
  roundRect(c, b.x, b.y, b.w, b.h, b.h / 2);
  c.fill();
  c.fillStyle = '#fff';
  c.textAlign = 'center';
  c.font = '800 ${(b.h * .45).round()}px';
  c.fillText(text, b.x + b.w / 2, b.y + b.h * .66);
}

// ---------- 7. Tiệm pizza: khách vào gọi món (mấy cái nấm, mấy quả cà chua...), bé chạm nguyên liệu để rắc lên bánh
// cho ĐỦ SỐ LƯỢNG rồi bấm Giao. Chạm vào miếng trên bánh để bỏ bớt. Rèn đếm số. ----------
const List<String> _TOPS = ['Mushroom', 'Tomato', 'Olive', 'Bell pepper', 'Cheese wedge', 'Shrimp', 'Pineapple', 'Onion'];

class _Order {
  _Order(this.k, this.n);
  final String k;
  final int n;
}

class _Cust {
  _Cust(this.k, this.x, this.tx, this.wait, this.order);
  final String k;
  double x, tx, wait, mood = 0;
  String st = 'in';
  bool sad = false;
  final List<_Order> order;
}

class _Top {
  _Top(this.k, this.x, this.y, this.r, this.pop);
  final String k;
  final double x, y, r;
  double pop;
}

Future<LoopGame> pizza(Fun g) async {
  final lv = g.level, need = math.min(8, 3 + lv ~/ 10), tr = g.tr;
  final nT = math.min(_TOPS.length, 4 + lv ~/ 12), tops = _TOPS.sublist(0, nT);
  const PEOPLE = ['woman', 'man', 'kidgirl', 'kidboy', 'robot'];
  final (SH, _) = await (playSheets(PEOPLE), loadAll([..._TOPS, 'Red heart', 'Coin', 'Cook', 'Pizza', 'Potted plant', 'Thought balloon'])).wait;
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final counterY = H * .44, ph = math.min(S * .3, counterY * .62);
  final pzx = W / 2, pzy = H * (W < 640 ? .6 : .64), pzr = math.min(W * .3, H * .15);
  // Khay nguyên liệu: màn hẹp nhiều món thì xếp 2 hàng cho ô đủ to để bé chạm.
  final perRow = W / nT < 72 ? (nT / 2).ceil() : nT, tw = math.min((W - 16) / perRow, 110.0), nRows = (nT / perRow).ceil();
  final trayY = H - 12 - tw * nRows / 2;
  final trayB = [
    for (var i = 0; i < nT; i++)
      () {
        final r = i ~/ perRow, cc = i % perRow, n = math.min(perRow, nT - r * perRow);
        return _Box(W / 2 - tw * n / 2 + cc * tw, trayY - tw * .45 + (r - (nRows - 1) / 2) * tw, tw, tw * .9, tops[i]);
      }(),
  ];
  final goB = _Box(W - math.min(170, W * .32) - 14, pzy - 30, math.min(170, W * .32), 60);
  if (W < 640) {
    goB.w = math.min(150, W * .42);
    goB.h = 50;
    goB.x = W - goB.w - 10;
    goB.y = math.min(pzy + pzr * .66 + 6, trayB.map((b) => b.y).reduce(math.min) - goB.h - 8);
  }
  final maxN = ramp(lv, 3, 6).round(), kinds = lv < 6 ? 1 : (lv < 25 ? 2 : 3);
  final patience = ramp(lv, 40, 18);
  var served = 0, lives = 3;
  double t = 0, endT = 0, botT = 0;
  FunEnd? end;
  _Cust? cust;
  var placed = <_Top>[];
  void newCust() {
    final ks = shuffleInPlace([...tops]).sublist(0, kinds);
    cust = _Cust(pick(PEOPLE), W + 80, W * .5, patience, [for (final k in ks) _Order(k, 1 + (random() * maxN).floor())]);
    placed = [];
  }

  newCust();
  int count(String k) => placed.where((p) => p.k == k).length;
  void addTop(String k) {
    if (placed.length >= 18) return;
    final a = rand(0, math.pi * 2), d = math.sqrt(random()) * pzr * .72;
    placed.add(_Top(k, pzx + math.cos(a) * d, pzy + math.sin(a) * d * .62, rand(-.5, .5), .25));
    g.sfx('pop');
  }

  void serve() {
    final cu = cust;
    if (cu == null || cu.st != 'wait') return;
    final ok = cu.order.every((o) => count(o.k) == o.n) && placed.every((p) => cu.order.any((o) => o.k == p.k));
    if (ok) {
      served++;
      cu.st = 'happy';
      cu.mood = 1.2;
      g.sfx('correct');
      F.burst(pzx, pzy, 24);
      F.text(pzx, pzy - pzr, '$served/$need', '#ffd43b');
      if (served >= need) {
        end = FunEnd(win: true, score: served * 10 + lives * 5);
        g.sfx('win');
      }
    } else {
      g.sfx('wrong');
      cu.mood = -1;
      lives--;
      F.text(pzx, pzy - pzr, tr('Chưa đúng số!', 'Wrong count!'), '#ff8787');
      if (lives <= 0) end = FunEnd(win: false, score: served * 10);
    }
  }

  g.taps(onTap: (x, y) {
    if (t < 2 || end != null || cust == null || cust!.st != 'wait') return;
    for (final b in trayB) {
      if (b.has(x, y)) return addTop(b.k);
    }
    if (goB.has(x, y)) return serve();
    for (var i = placed.length - 1; i >= 0; i--) {
      if (hypot(placed[i].x - x, placed[i].y - y) < pzr * .2) {
        placed.removeAt(i);
        g.sfx('flip');
        return;
      }
    }
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      for (final p in placed) {
        p.pop = math.max(0, p.pop - dt);
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      final cu = cust;
      if (t < 2 || cu == null) return null;
      if (cu.st == 'in') {
        cu.x -= S * .5 * dt;
        if (cu.x <= cu.tx) {
          cu.x = cu.tx;
          cu.st = 'wait';
        }
      } else if (cu.st == 'wait') {
        cu.wait -= dt;
        cu.mood = math.max(-1, cu.mood - dt);
        if (cu.mood < 0) cu.mood = math.min(0, cu.mood + dt);
        if (cu.wait <= 0) {
          lives--;
          g.sfx('wrong');
          cu.st = 'out';
          cu.sad = true;
          if (lives <= 0) end = FunEnd(win: false, score: served * 10);
        }
        if (bot && (botT += dt) > .25) {
          botT = 0;
          final o = cu.order.where((o) => count(o.k) < o.n).firstOrNull;
          if (o != null) {
            addTop(o.k);
          } else {
            serve();
          }
        }
      } else if (cu.st == 'happy') {
        cu.mood -= dt;
        if (cu.mood <= 0) cu.st = 'out';
      } else if (cu.st == 'out') {
        cu.x -= S * .6 * dt;
        if (cu.x < -80) newCust();
      }
      return null;
    },
    draw: () {
      // Tường tiệm + quầy
      c.fillStyle = '#ffe8cc';
      c.fillRect(0, 0, W, counterY);
      c.fillStyle = '#ffd8a8';
      for (double x = 0; x < W; x += 60) {
        c.fillRect(x, 0, 30, counterY);
      }
      draw(c, 'Potted plant', W * .08, counterY - S * .07, S * .12);
      draw(c, 'Cook', W * .92, counterY - S * .08, S * .12);
      final cu = cust;
      if (cu != null) {
        final anim = cu.st == 'in' || cu.st == 'out'
            ? 'walk'
            : cu.st == 'happy'
                ? 'cheer'
                : (cu.mood < 0 || cu.wait < patience * .25 ? 'think' : 'idle');
        drawAnimC(c, SH[cu.k], anim, t, cu.x, counterY + ph * .1, ph, flip: cu.st == 'in' || cu.st == 'out');
        if (cu.st == 'wait') {
          // Bóng nói: món gọi. Cấp thấp vẽ đủ từng cái để bé đếm; cấp cao ghi "× số".
          final bw = math.min(W * .94, 90 + cu.order.length * 190.0), bh = 92.0, bx = W / 2 - bw / 2, by = 64.0 + (W < 640 ? 48 : 0);
          c.fillStyle = '#fff';
          roundRect(c, bx, by, bw, bh, 22);
          c.fill();
          c.beginPath();
          c.moveTo(cu.x - 10, by + bh);
          c.lineTo(cu.x + 10, by + bh);
          c.lineTo(cu.x, by + bh + 16);
          c.fill();
          final seg = bw / cu.order.length;
          for (var i = 0; i < cu.order.length; i++) {
            final o = cu.order[i];
            final cx = bx + seg * (i + .5), have = count(o.k);
            if (lv < 12 && o.n <= 4) {
              final s = math.min(54.0, seg / (o.n + .3));
              for (var j = 0; j < o.n; j++) {
                drawO(c, o.k, cx + (j - (o.n - 1) / 2) * s, by + bh / 2 - 4, s, alpha: j < have ? .35 : 1);
              }
            } else {
              draw(c, o.k, cx - 32, by + bh / 2 - 4, 56);
              c.fillStyle = have == o.n ? '#2f9e44' : '#212529';
              c.font = '800 32px';
              c.textAlign = 'left';
              c.fillText('× ${o.n}', cx, by + bh / 2 + 8);
            }
          }
          // Thanh kiên nhẫn
          final k = math.max(0.0, cu.wait / patience);
          c.fillStyle = 'rgba(0,0,0,.15)';
          roundRect(c, bx + 12, by + bh - 12, bw - 24, 7, 4);
          c.fill();
          c.fillStyle = k > .4 ? '#40c057' : (k > .2 ? '#fab005' : '#fa5252');
          roundRect(c, bx + 12, by + bh - 12, (bw - 24) * k, 7, 4);
          c.fill();
        }
      }
      c.fillStyle = '#a0522d';
      c.fillRect(0, counterY, W, H - counterY);
      c.fillStyle = '#8b4513';
      c.fillRect(0, counterY, W, 14);
      // Bánh pizza: đế + sốt + phô mai
      shadow(c, pzx, pzy + pzr * .5, pzr * 2.05, .2);
      c.fillStyle = '#e8a75d';
      c.beginPath();
      c.ellipse(pzx, pzy, pzr, pzr * .66, 0, 0, 7);
      c.fill();
      c.fillStyle = '#d9480f';
      c.beginPath();
      c.ellipse(pzx, pzy, pzr * .86, pzr * .56, 0, 0, 7);
      c.fill();
      c.fillStyle = 'rgba(255,224,102,.75)';
      for (var i = 0; i < 7; i++) {
        c.beginPath();
        c.ellipse(pzx + math.cos(i * 2.4) * pzr * .45, pzy + math.sin(i * 2.4) * pzr * .28, pzr * .22, pzr * .13, i.toDouble(), 0, 7);
        c.fill();
      }
      for (final p in placed) {
        drawO(c, p.k, p.x, p.y, pzr * .32 * (1 + p.pop * 1.5), rot: p.r);
      }
      // Khay nguyên liệu
      for (final b in trayB) {
        c.fillStyle = 'rgba(0,0,0,.18)';
        c.fillRect(b.x, b.y - tw * .05, b.w, tw);
      }
      for (final b in trayB) {
        c.fillStyle = '#fff4e6';
        roundRect(c, b.x + 4, b.y, b.w - 8, b.h, 16);
        c.fill();
        draw(c, b.k, b.x + b.w / 2, b.y + b.h / 2, b.h * .7);
      }
      _button(c, goB, tr('✔ Giao', '✔ Serve'), '#2f9e44', cu != null && cu.st == 'wait');
      F.draw(c);
      hud(c, W, score: served, lives: 0);
      hearts(c, W, lives);
      goalPill(c, W, served, need, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Làm bánh cho $need khách', 'Make pizza for $need customers'),
            tr('Rắc đúng số nguyên liệu khách gọi rồi bấm Giao', 'Add exactly the toppings ordered, then tap Serve'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('TIỆM ĐÓNG CỬA!', 'SHOP CLOSED!'), tr('$served/$need khách', '$served/$need customers'));
      }
    },
  );
}

// ---------- 8. Nông trại vui vẻ: chạm ô đất để bé đi tới gieo hạt → tưới nước → chờ lớn → thu hoạch.
// Chuột, sâu, ốc bò vào ăn cây: chạm vào để đuổi. Thu đủ nông sản trước khi hết giờ. ----------
const List<String> _CROPS = ['Carrot', 'Ear of corn', 'Tomato', 'Strawberry', 'Eggplant', 'Broccoli', 'Potato'];

class _Plot {
  _Plot(this.x, this.y);
  final double x, y;

  /// 0 đất trống, 1 đã gieo, 2 đã tưới (đang lớn), 3 chín, 4 héo.
  int st = 0;
  double g = 0, ripe = 0;
}

class _Pest {
  _Pest(this.k, this.x, this.y, this.p);
  final String k;
  double x, vx = 0, eat = 0;
  final double y;
  final _Plot p;
  bool run = false;
}

Future<LoopGame> farm(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 6, 18).round(), kid = kidOf(g.hero), tr = g.tr;
  final crop = _CROPS[(lv ~/ 3) % _CROPS.length];
  final (SH, _) = await (
    playSheets([kid, 'critters', 'items']),
    loadAll([..._CROPS, 'Seedling', 'Droplet', 'Basket', 'Red heart', 'Coin', 'House', 'Wilted flower', th.sun])
  ).wait;
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final cols = lv < 10 ? 3 : 4, rows = lv < 20 ? 2 : 3;
  final fy0 = H * .4, fy1 = H * .94, cw = math.min((W - 40) / cols, (fy1 - fy0) / rows * 1.25), chh = (fy1 - fy0) / rows;
  final fx0 = W / 2 - cw * cols / 2;
  final plots = <_Plot>[
    for (var r = 0; r < rows; r++)
      for (var cc = 0; cc < cols; cc++) _Plot(fx0 + (cc + .5) * cw, fy0 + (r + .5) * chh),
  ];
  final grow = ramp(lv, 4.5, 6.5), wilt = lv >= 20 ? ramp(lv, 14, 8) : 1e9;
  final ph = math.min(S * .2, chh * 1.15);
  var meX = W / 2, meY = fy0 - 10, meWork = 0.0, meFace = 1;
  _Pt? meTx;
  _Plot? mePlot;
  final pests = <_Pest>[];
  double time = ramp(lv, 80, 95).roundToDouble(), t = 0, endT = 0, pestT = rand(6, 9), botT = 0;
  var got = 0;
  FunEnd? end;
  void actOn(_Plot p) {
    if (p.st == 0) {
      p.st = 1;
      p.g = 0;
      g.sfx('pop');
    } else if (p.st == 1) {
      p.st = 2;
      p.g = 0;
      g.sfx('splash');
      F.burst(p.x, p.y, 10, ['#74c0fc', '#a5d8ff']);
    } else if (p.st == 3) {
      p.st = 0;
      got++;
      g.sfx('coin');
      F.text(p.x, p.y - 40, '$got/$need', '#ffd43b');
      F.star(p.x, p.y);
      if (got >= need) {
        end = FunEnd(win: true, score: got * 5 + time.round());
        g.sfx('win');
      }
    } else if (p.st == 4) {
      p.st = 0;
      g.sfx('flip');
    }
  }

  void goTo(_Plot p) {
    mePlot = p;
    meTx = _Pt(p.x - cw * .32, p.y + chh * .3);
  }

  g.taps(onTap: (x, y) {
    if (t < 2 || end != null) return;
    for (final z in pests) {
      if (!z.run && hypot(z.x - x, z.y - y) < S * .08) {
        z.run = true;
        z.vx = (z.x < W / 2 ? -1 : 1) * S * .7;
        g.sfx('squeak');
        return;
      }
    }
    final p = plots.where((p) => (p.x - x).abs() < cw / 2 && (p.y - y).abs() < chh / 2).firstOrNull;
    if (p != null && p.st != 2) goTo(p);
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      time -= dt;
      for (final p in plots) {
        if (p.st == 2) {
          p.g += dt / grow;
          if (p.g >= 1) {
            p.st = 3;
            p.ripe = 0;
            g.sfx('star');
          }
        } else if (p.st == 3) {
          p.ripe += dt;
          if (p.ripe > wilt) p.st = 4;
        }
      }
      final tx = meTx;
      if (tx != null) {
        final dx = tx.x - meX, dy = tx.y - meY, d = hypot(dx, dy), sp = S * .9;
        if (dx.abs() > 2) meFace = dx > 0 ? 1 : -1;
        if (d < sp * dt) {
          meX = tx.x;
          meY = tx.y;
          meTx = null;
          meWork = .45;
        } else {
          meX += dx / d * sp * dt;
          meY += dy / d * sp * dt;
        }
      } else if (meWork > 0) {
        meWork -= dt;
        if (meWork <= 0 && mePlot != null) {
          actOn(mePlot!);
          mePlot = null;
        }
      }
      if (lv >= 6) {
        pestT -= dt;
        if (pestT <= 0) {
          pestT = rand(5, 8) * ramp(lv, 1.3, .55);
          final ok = plots.where((p) => p.st >= 2 && p.st <= 3).toList();
          if (ok.isNotEmpty) {
            final p = pick(ok), side = random() < .5 ? -1 : 1;
            pests.add(_Pest(pick(['mouse', 'worm', 'snail']), side < 0 ? -40 : W + 40, p.y + chh * .15, p));
          }
        }
      }
      for (var i = pests.length - 1; i >= 0; i--) {
        final z = pests[i];
        if (z.run) {
          z.x += z.vx * dt;
          if (z.x < -60 || z.x > W + 60) pests.removeAt(i);
          continue;
        }
        if (z.p.st < 2 || z.p.st > 3) {
          z.run = true;
          z.vx = (z.x < W / 2 ? -1 : 1) * S * .5;
          continue;
        }
        final dx = z.p.x - z.x;
        z.vx = dx.sign * S * ramp(lv, .1, .2);
        if (dx.abs() > 8) {
          z.x += z.vx * dt;
        } else {
          z.eat += dt;
          if (z.eat > 1.6) {
            z.p.st = 0;
            g.sfx('eat');
            F.text(z.p.x, z.p.y - 30, tr('Bị ăn mất!', 'Eaten!'), '#ff8787');
            z.run = true;
            z.vx = (z.x < W / 2 ? -1 : 1) * S * .5;
          }
        }
      }
      if (bot && meTx == null && meWork <= 0 && (botT += dt) > .2) {
        botT = 0;
        for (final z in pests) {
          if (!z.run) {
            z.run = true;
            z.vx = S * .7;
          }
        }
        final p = plots.where((p) => p.st == 3 || p.st == 4).firstOrNull ?? plots.where((p) => p.st == 1).firstOrNull ?? plots.where((p) => p.st == 0).firstOrNull;
        if (p != null) goTo(p);
      }
      if (time <= 0 && end == null) {
        time = 0;
        end = FunEnd(win: false, score: got * 5);
        g.sfx('wrong');
      }
      return null;
    },
    draw: () {
      skyFill(c, W, H, th);
      draw(c, th.sun, W * .88, H * .1, S * .12);
      draw(c, 'House', W * .12, fy0 - S * .13, S * .24);
      for (var x = W * .28; x < W; x += S * .1) {
        drawFrame(c, SH['items'], 'fence', x, fy0 - S * .055, S * .1);
      }
      c.fillStyle = '#8ce99a';
      c.fillRect(0, fy0 - 14, W, H - fy0 + 14);
      draw(c, 'Basket', W - 70, fy0 - S * .06, S * .1);
      for (final p in plots) {
        final x = p.x - cw / 2 + 6, y = p.y - chh / 2 + 6, w = cw - 12, h = chh - 12;
        c.fillStyle = p.st == 0 ? '#a9714b' : '#7b4a2a';
        roundRect(c, x, y, w, h, 14);
        c.fill();
        c.fillStyle = 'rgba(0,0,0,.12)';
        for (var k = 1; k < 4; k++) {
          c.fillRect(x + 8, y + h * k / 4, w - 16, 4);
        }
        final s = math.min(w, h);
        if (p.st == 1) {
          draw(c, 'Seedling', p.x, p.y, s * .35);
          draw(c, 'Droplet', p.x + s * .3, p.y - s * .3 + math.sin(t * 5) * 4, s * .25);
        } else if (p.st == 2) {
          draw(c, 'Seedling', p.x, p.y + s * .1 * (1 - p.g), s * (.35 + .35 * p.g));
          c.fillStyle = 'rgba(0,0,0,.25)';
          roundRect(c, p.x - s * .3, p.y + h * .36, s * .6, 7, 4);
          c.fill();
          c.fillStyle = '#69db7c';
          roundRect(c, p.x - s * .3, p.y + h * .36, s * .6 * p.g, 7, 4);
          c.fill();
        } else if (p.st == 3) {
          draw(c, crop, p.x, p.y - math.sin(t * 4).abs() * 5, s * .62);
        } else if (p.st == 4) {
          draw(c, 'Wilted flower', p.x, p.y, s * .5);
        }
      }
      for (final z in pests) {
        drawAnimC(c, SH['critters'], z.k, t, z.x, z.y, S * .075, flip: z.vx > 0);
      }
      shadow(c, meX, meY, ph * .45);
      drawAnimC(c, SH[kid], end?.win == true ? 'cheer' : (meTx != null ? 'walk' : (meWork > 0 ? 'work' : 'idle')), t, meX, meY, ph, flip: meFace < 0);
      F.draw(c);
      hud(c, W, score: got, lives: 0, time: time);
      goalPill(c, W, got, need);
      if (t < 2) {
        levelBanner(
            c,
            W,
            H,
            lv,
            crop == 'Ear of corn' ? tr('Thu hoạch $need bắp ngô', 'Harvest $need ears of corn') : tr('Thu hoạch $need nông sản', 'Harvest $need crops'),
            tr('Chạm ô đất: gieo hạt → tưới nước → hái · Chạm con vật để đuổi', 'Tap a plot: plant → water → pick · Tap critters to shoo them'),
            tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT GIỜ!', 'TIME UP!'), '$got/$need');
    },
  );
}

/// Điểm (x, y) đơn giản (tránh phụ thuộc dart:ui ở logic game).
class _Pt {
  const _Pt(this.x, this.y);
  final double x, y;
}

// ---------- 9. Lính cứu hoả nhí: lửa bùng ở các ô cửa sổ, chạm vào ô cháy để xe cứu hoả chạy tới phun nước.
// Dập xong thì người trong nhà vẫy tay cảm ơn. Lửa cháy quá lâu là mất một tim. ----------
class _Win {
  _Win(this.x, this.y, this.who);
  final double x, y;
  final String who;
  double fire = 0, burn = 0, thanks = 0, black = 0;
}

class _Drop {
  _Drop(this.x, this.y, this.tx, this.ty);
  final double x, y, tx, ty;
  double t = 0;
}

Future<LoopGame> firefight(Fun g) async {
  final lv = g.level, need = ramp(lv, 6, 22).round(), kid = kidOf(g.hero), tr = g.tr;
  const PEOPLE = ['woman', 'man', 'kidgirl', 'kidboy'];
  final (SH, _) = await (
    playSheets([kid, ...PEOPLE.where((k) => k != kid), 'items']),
    loadAll(['Fire', 'Fire engine', 'Droplet', 'Red heart', 'Coin', 'Cloud', 'Deciduous tree'])
  ).wait;
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final cols = math.min(5, 3 + lv ~/ 20 + (W > 700 ? 1 : 0)), rows = lv < 12 ? 2 : 3;
  final road = H * .88, bTop = math.max(H * .2, 150.0), bw = math.min(W * .86, cols * 150.0), bx = W / 2 - bw / 2;
  final cw = bw / cols, chh = (road - S * .26 - bTop) / rows;
  final wins = <_Win>[
    for (var r = 0; r < rows; r++)
      for (var cc = 0; cc < cols; cc++) _Win(bx + (cc + .5) * cw, bTop + (r + .5) * chh, pick(PEOPLE)),
  ];
  final growR = ramp(lv, .1, .22), dryR = ramp(lv, .75, .55), maxBurn = ramp(lv, 9, 5);
  var truckX = W / 2, truckTx = W / 2, truckSpray = 0;
  _Win? truckTarget;
  var out = 0, lives = 3;
  double t = 0, endT = 0, spawnT = 1;
  FunEnd? end;
  final drops = <_Drop>[];
  g.taps(onTap: (x, y) {
    if (t < 2 || end != null) return;
    final w = wins.where((w) => (w.x - x).abs() < cw / 2 && (w.y - y).abs() < chh / 2).firstOrNull;
    if (w != null && w.fire > 0) {
      truckTarget = w;
      truckTx = w.x;
      g.sfx('tap');
    } else if (y > road - S * .2) {
      truckTx = math.max(60, math.min(W - 60, x));
    }
  });
  _Pt nozzle() => _Pt(truckX - S * .02, road - S * .17);
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      for (final w in wins) {
        w.thanks = math.max(0, w.thanks - dt);
        w.black = math.max(0, w.black - dt);
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      spawnT -= dt;
      final burning = wins.where((w) => w.fire > 0).length;
      if (spawnT <= 0 && burning < math.min(wins.length - 1, 1 + lv ~/ 12)) {
        spawnT = rand(1.6, 3) * ramp(lv, 1.3, .6);
        final free = wins.where((w) => w.fire <= 0 && w.black <= 0).toList();
        if (free.isNotEmpty) {
          final w = pick(free);
          w.fire = .3;
          w.burn = 0;
        }
      }
      if (bot && (truckTarget == null || truckTarget!.fire <= 0)) {
        final ws = wins.where((w) => w.fire > 0).toList()..sort((a, b) => b.burn.compareTo(a.burn));
        if (ws.isNotEmpty) {
          truckTarget = ws.first;
          truckTx = ws.first.x;
        }
      }
      final d = truckTx - truckX, sp = S * 1.1;
      truckX += d.abs() < sp * dt ? d : d.sign * sp * dt;
      final tg = truckTarget;
      truckSpray = 0;
      if (tg != null && tg.fire > 0 && (truckX - truckTx).abs() < 4) {
        truckSpray = 1;
        tg.fire -= dryR * dt;
        if (random() < dt * 30) {
          final n = nozzle();
          drops.add(_Drop(n.x, n.y, tg.x + rand(-15, 15), tg.y + rand(-10, 10)));
        }
        if (tg.fire <= 0) {
          tg.fire = 0;
          out++;
          tg.thanks = 1.8;
          g.sfx('correct');
          F.burst(tg.x, tg.y, 16, ['#dee2e6', '#f8f9fa', '#74c0fc']);
          F.text(tg.x, tg.y - 40, '$out/$need', '#ffd43b');
          truckTarget = null;
          if (out >= need) {
            end = FunEnd(win: true, score: out * 8 + lives * 5);
            g.sfx('win');
          }
        }
      }
      for (final w in wins) {
        if (w.fire > 0 && w != (truckSpray != 0 ? tg : null)) {
          w.fire = math.min(1, w.fire + growR * dt);
          w.burn += dt;
          if (w.burn > maxBurn) {
            w.fire = 0;
            w.black = 4;
            lives--;
            g.sfx('hit');
            F.burst(w.x, w.y, 14, ['#495057', '#868e96']);
            if (truckTarget == w) truckTarget = null;
            if (lives <= 0) {
              end = FunEnd(win: false, score: out * 8);
              g.sfx('wrong');
            }
          }
        }
      }
      for (var i = drops.length - 1; i >= 0; i--) {
        drops[i].t += dt * 2.2;
        if (drops[i].t >= 1) drops.removeAt(i);
      }
      return null;
    },
    draw: () {
      final gr = c.createLinearGradient(0, 0, 0, H);
      gr.addColorStop(0, '#74c0fc');
      gr.addColorStop(1, '#e7f5ff');
      c.fillStyle = gr;
      c.fillRect(0, 0, W, H);
      draw(c, 'Cloud', W * .15, H * .1, S * .18, S * .11);
      draw(c, 'Cloud', W * .8, H * .08, S * .14, S * .09);
      draw(c, 'Deciduous tree', bx - S * .07, road - S * .11, S * .22);
      draw(c, 'Deciduous tree', bx + bw + S * .07, road - S * .11, S * .22);
      // Toà nhà
      c.fillStyle = '#e0a370';
      roundRect(c, bx - 14, bTop - chh * .45, bw + 28, road - bTop + chh * .45, 12);
      c.fill();
      c.fillStyle = 'rgba(0,0,0,.12)';
      for (var y = bTop - chh * .45 + 16; y < road; y += 22) {
        c.fillRect(bx - 14, y, bw + 28, 3);
      }
      c.fillStyle = '#7b4a2a';
      c.fillRect(bx - 24, bTop - chh * .5 - 12, bw + 48, 16);
      drawFrame(c, SH['items'], 'door_open', W / 2, road - S * .1, S * .2);
      final ws = math.min(cw, chh) * .8;
      for (final w in wins) {
        drawFrame(c, SH['items'], 'window', w.x, w.y, ws);
        if (w.thanks > 0) drawAnimC(c, SH[w.who], 'cheer', t, w.x, w.y + ws * .4, ws * .85); // người trong nhà vẫy tay cảm ơn
        if (w.black > 0) {
          c.fillStyle = 'rgba(52,58,64,${math.min(.8, w.black)})';
          roundRect(c, w.x - ws * .42, w.y - ws * .42, ws * .84, ws * .84, 8);
          c.fill();
        }
        if (w.fire > 0) {
          final s = ws * (.45 + .6 * w.fire);
          for (var k = 0; k < 3; k++) {
            drawO(c, 'Fire', w.x + (k - 1) * s * .28, w.y + ws * .3 - s * .5 * (1 + .08 * math.sin(t * 14 + k * 2)), s * (k == 1 ? 1 : .7), alpha: .95);
          }
          if (w.burn > maxBurn * .6) {
            c.fillStyle = 'rgba(250,82,82,.9)';
            c.font = '800 26px';
            c.textAlign = 'center';
            c.fillText('!', w.x + ws * .45, w.y - ws * .3);
          }
        }
      }
      c.fillStyle = '#495057';
      c.fillRect(0, road, W, H - road);
      c.fillStyle = '#fff';
      for (double x = 0; x < W; x += 70) {
        c.fillRect(x, road + (H - road) / 2, 36, 4);
      }
      // Tia nước
      for (final d in drops) {
        final k = d.t, x = d.x + (d.tx - d.x) * k, y = d.y + (d.ty - d.y) * k - math.sin(k * math.pi) * S * .12;
        draw(c, 'Droplet', x, y, S * .035);
      }
      final tw = S * .32;
      drawO(c, 'Fire engine', truckX, road - tw * .3, tw, h: tw * .8, flip: true);
      drawAnimC(c, SH[kid], truckSpray != 0 ? 'hold' : 'idle', t, truckX - tw * .05, road - tw * .48, S * .14);
      F.draw(c);
      hud(c, W, score: out, lives: 0);
      hearts(c, W, lives);
      goalPill(c, W, out, need);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Dập $need đám lửa', 'Put out $need fires'),
            tr('Chạm vào cửa sổ đang cháy để xe tới phun nước', 'Tap a burning window to send the fire truck'), tr);
      }
      if (end != null) {
        banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('LỬA LỚN QUÁ!', 'TOO MUCH FIRE!'), tr('$out/$need đám lửa', '$out/$need fires'));
      }
    },
  );
}

// ---------- 10. Tìm đồ vật: căn phòng đầy đồ, tìm đủ các món ở khay dưới. Chạm sai bị trừ 3 giây. ----------
const List<String> _FIND = [
  'Teddy bear', 'Kite', 'Umbrella', 'Alarm clock', 'Crayon', 'Basketball', 'Red apple', 'Banana', 'Rocket', 'Bicycle', 'Guitar', 'Drum', //
  'Soccer ball', 'Balloon', 'Books', 'Scissors', 'Key', 'Light bulb', 'Glasses', 'Backpack', 'Billed cap', 'Socks', 'Yo-yo', 'Magnet', 'Pencil',
  'Hammer', 'Wrench', 'Paintbrush', 'Bell', 'Candle', 'Teapot', 'Cupcake', 'Lollipop', 'Doughnut', 'Watermelon', 'Grapes', 'Carrot', 'Pear',
  'Snail', 'Butterfly', 'Turtle', 'Octopus', 'Duck', 'Penguin', 'Owl', 'Frog', 'Fish', 'Crab', 'Spiral shell', 'Sunflower', 'Tulip', 'Rose',
  'Mushroom', 'Cactus', 'Crown', 'Ribbon', 'Wrapped gift', 'Game die', 'Puzzle piece', 'Joystick', 'Trumpet', 'Violin', 'Telephone', 'Camera', 'Laptop',
];

class _Item {
  _Item(this.k, this.x, this.y, this.s, this.r);
  final String k;
  final double x, y, s, r;
  bool found = false;
  double wig = 0;
}

class _Bush {
  _Bush(this.x, this.y, this.s);
  final double x, y, s;
}

Future<LoopGame> hidden(Fun g) async {
  final lv = g.level, th = theme(lv), kid = kidOf(g.hero), tr = g.tr;
  final nItems = ramp(lv, 14, 46).round(), nFind = math.min(6, 3 + lv ~/ 15);
  final pool = shuffleInPlace([..._FIND]).sublist(0, nItems), find = pool.sublist(0, nFind);
  final (SH, _) = await (playSheets([kid, 'items']), loadAll([...pool, 'Coin', 'Magnifying glass tilted left', th.sun])).wait;
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final top = W < 640 ? 112.0 : 70.0, trayH = math.min(110.0, H * .13);
  final Ax = 14.0, Ay = top, Aw = W - 28, Ah = H - top - trayH - 20;
  final sz = math.sqrt(Aw * Ah / nItems) * ramp(lv, .72, .5);
  // Rải đồ vật: thử nhiều vị trí, tránh chồng nhau quá nhiều (cấp cao cho chồng nhiều hơn).
  var items = <_Item>[];
  final minD = sz * ramp(lv, .95, .6);
  for (final k in pool) {
    double? bx, by, bd;
    for (var tries = 0; tries < 40; tries++) {
      final px = Ax + sz / 2 + random() * (Aw - sz), py = Ay + sz / 2 + random() * (Ah - sz);
      var d = 1e9;
      for (final o in items) {
        d = math.min(d, hypot(o.x - px, o.y - py));
      }
      if (bd == null || d > bd) {
        bx = px;
        by = py;
        bd = d;
      }
      if (d > minD) break;
    }
    items.add(_Item(k, bx!, by!, sz * rand(.8, 1.15), lv >= 10 ? rand(-.6, .6) : rand(-.15, .15)));
  }
  // Món cần tìm vẽ trước để có thể bị che một phần ở cấp cao (sort ổn định như web).
  items = [...items.where((o) => find.contains(o.k)), ...items.where((o) => !find.contains(o.k))];
  final bushes = lv >= 20 ? List.generate(ramp(lv, 3, 8).round(), (_) => _Bush(Ax + random() * Aw, Ay + random() * Ah, sz * rand(.8, 1.2))) : <_Bush>[];
  double time = ramp(lv, 75, 60).roundToDouble(), t = 0, endT = 0, idle = 0, cheer = 0, botT = 0;
  var gotN = 0;
  FunEnd? end;
  void tap(double x, double y) {
    final hitIt = items.reversed.where((o) => !o.found && hypot(o.x - x, o.y - y) < o.s * .5).firstOrNull;
    if (hitIt != null && find.contains(hitIt.k)) {
      hitIt.found = true;
      gotN++;
      idle = 0;
      cheer = 1;
      g.sfx('correct');
      F.burst(hitIt.x, hitIt.y, 16);
      F.star(hitIt.x, hitIt.y);
      if (gotN >= nFind) {
        end = FunEnd(win: true, score: gotN * 10 + time.round());
        g.sfx('win');
      }
    } else {
      time = math.max(0, time - 3);
      g.sfx('wrong');
      F.text(x, y, tr('-3 giây', '-3 sec'), '#ff8787');
    }
  }

  g.taps(onTap: (x, y) {
    if (t >= 2 && end == null) tap(x, y);
  });
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      cheer = math.max(0, cheer - dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      time -= dt;
      idle += dt;
      for (final o in items) {
        o.wig = idle > 14 && !o.found && find.contains(o.k) ? math.sin(t * 12) * .25 : 0; // gợi ý: món cần tìm lắc nhẹ
      }
      if (bot && (botT += dt) > 1) {
        botT = 0;
        final o = items.where((o) => !o.found && find.contains(o.k)).firstOrNull;
        if (o != null) tap(o.x, o.y);
      }
      if (time <= 0 && end == null) {
        time = 0;
        end = FunEnd(win: false, score: gotN * 10);
        g.sfx('wrong');
      }
      return null;
    },
    draw: () {
      skyFill(c, W, H, th);
      c.fillStyle = 'rgba(255,255,255,.55)';
      roundRect(c, Ax, Ay, Aw, Ah, 22);
      c.fill();
      c.fillStyle = 'rgba(0,0,0,.04)';
      for (var y = Ay + 30; y < Ay + Ah; y += 60) {
        c.fillRect(Ax, y, Aw, 30);
      }
      for (final o in items) {
        if (!o.found) drawO(c, o.k, o.x, o.y, o.s, h: o.s, rot: o.r + o.wig);
      }
      for (final b in bushes) {
        drawFrame(c, SH['items'], 'bush', b.x, b.y, b.s * .8, alpha: .92);
      }
      // Khay: món cần tìm
      final ty = H - trayH - 8, slot = math.min(trayH, (W - 150) / nFind);
      c.fillStyle = 'rgba(0,0,0,.25)';
      roundRect(c, 10, ty, W - 20, trayH, 20);
      c.fill();
      for (var i = 0; i < find.length; i++) {
        final k = find[i];
        final x = 20 + (i + .5) * slot, done = items.any((o) => o.k == k && o.found);
        c.fillStyle = done ? 'rgba(64,192,87,.85)' : 'rgba(255,255,255,.9)';
        roundRect(c, x - slot * .45, ty + 8, slot * .9, trayH - 16, 14);
        c.fill();
        drawO(c, k, x, ty + trayH / 2, math.min(slot, trayH) * .62, alpha: done ? .5 : 1);
        if (done) {
          c.fillStyle = '#fff';
          c.font = '800 28px';
          c.textAlign = 'center';
          c.fillText('✔', x + slot * .28, ty + 34);
        }
      }
      final kh = math.min(trayH * 1.25, S * .2);
      drawAnimC(c, SH[kid], end?.win == true || cheer > 0 ? 'cheer' : 'think', t, W - 60, H - 8, kh);
      F.draw(c);
      hud(c, W, score: gotN, lives: 0, time: time);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Tìm $nFind món đồ ở khay dưới', 'Find the $nFind items in the tray'),
            tr('Nhìn kỹ rồi chạm vào món đồ · Chạm sai trừ 3 giây', 'Look closely and tap the item · Wrong tap: -3 seconds'), tr);
      }
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT GIỜ!', 'TIME UP!'), tr('$gotN/$nFind món', '$gotN/$nFind items'));
    },
  );
}
