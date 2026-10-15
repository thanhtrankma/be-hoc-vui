// ignore_for_file: non_constant_identifier_names
// Rắn săn mồi, bắn bia, xếp gạch, nhảy lên mây (tank nằm ở funtank.dart của agent G).
// CHỦ: agent F. Port của reference/web/js/games/funnew1.js. Mỗi lượt một cấp (ctx.level), 60 cấp.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart' as fig;
import 'package:flutter/painting.dart' show Offset;

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funnew1Games = {
  'snake': const FunCanvasModule('snake', snake),
  'gallery': const FunCanvasModule('gallery', gallery),
  'blocks': const FunCanvasModule('blocks', blocks),
  'jumper': const FunCanvasModule('jumper', jumper),
};

void _sky(Ctx2D c, double W, double H, FunTheme th) => skyFill(c, W, H, th);

// ---------- 1. Rắn săn mồi (bò mượt): rắn bò theo ngón tay trong sân lớn, ăn hạt và trái cây để dài ra,
// rắn máy bò quanh; đâm đầu vào thân rắn khác là mất mạng, rắn máy đâm vào thân bé thì hoá thành hạt. Chạm 2 lần để tăng tốc.
const List<List<String>> _snakeSkins = [
  ['#51cf66', '#2f9e44'], ['#ff922b', '#e8590c'], ['#cc5de8', '#9c36b5'], ['#339af0', '#1971c2'],
  ['#ff6b6b', '#e03131'], ['#fcc419', '#f08c00'], ['#20c997', '#0ca678'], ['#f06595', '#c2255c'],
];

class _Food {
  _Food(this.x, this.y, this.big, this.v, this.k, this.c, this.ph);
  final double x, y;
  final bool big;
  final int v;
  final String? k;
  final String c;
  double ph;
}

class _Snake {
  _Snake(this.x, this.y, this.a, this.len, this.path, this.skin, this.bot, this.r) : ta = a;
  double x, y, a, ta, r, boost = 0, think = 0, gulp = 0;
  int len;
  List<Offset> path;
  List<String> skin;
  bool bot, dead = false;
  void assign(_Snake o) {
    x = o.x;
    y = o.y;
    a = o.a;
    ta = o.ta;
    len = o.len;
    path = o.path;
    skin = o.skin;
    bot = o.bot;
    boost = 0;
    dead = false;
    think = 0;
    r = o.r;
  }
}

Future<LoopGame> snake(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 25, 110).round(), tr = g.tr;
  const fruit = ['Red apple', 'Strawberry', 'Grapes', 'Cherries', 'Banana', 'Watermelon'];
  await loadAll([...fruit, 'Red heart', 'Coin', 'High voltage']);
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx();
  final WW = math.max(W, H) * 2.2, WH = math.max(W, H) * 1.8; // kích thước sân
  final r0 = S * .028, sp = S * ramp(lv, .3, .38);
  const turn = 4.2;
  final foods = <_Food>[], sd = dust(200), ssh = shaker();
  void addFood({double? x, double? y, bool? big, int? v}) {
    final b = big ?? random() < .12;
    foods.add(_Food(x ?? rand(40, WW - 40), y ?? rand(40, WH - 40), b, v ?? (b ? 4 : 1), b ? pick(fruit) : null, 'hsl(${rand(0, 360).floor()},85%,62%)', rand(0, 6)));
  }

  for (var i = 0; i < 160; i++) {
    addFood();
  }
  _Snake mkSnake(double x, double y, int len, List<String> skin, bool bot) {
    final a = rand(0, 6.28), path = <Offset>[];
    for (var i = 0; i < len * 4; i++) {
      path.add(Offset(x - math.cos(a) * i * 3, y - math.sin(a) * i * 3));
    }
    return _Snake(x, y, a, len, path, skin, bot, r0);
  }

  final me = mkSnake(WW / 2, WH / 2, 14, _snakeSkins[3], false); // rắn của bé màu xanh dương
  final bots = <_Snake>[];
  final nBots = ramp(lv, 2, 8).round();
  void spawnBot() {
    double x, y;
    do {
      x = rand(100, WW - 100);
      y = rand(100, WH - 100);
    } while (hypot(x - me.x, y - me.y) < S * .8);
    final skins = [for (var i = 0; i < _snakeSkins.length; i++) if (i != 3) _snakeSkins[i]];
    bots.add(mkSnake(x, y, rand(10, 10 + lv * .6).round(), pick(skins), true));
  }

  for (var i = 0; i < nBots; i++) {
    spawnBot();
  }
  var score = 0, lives = 3;
  double t = 0, endT = 0, inv = 2, lastTap = -1;
  FunEnd? end;
  var camX = me.x - W / 2, camY = me.y - H / 2;
  void aim(Ptr e) => me.ta = math.atan2(e.y + camY - me.y, e.x + camX - me.x);
  g.onDown((e) {
    aim(e);
    final now = g.clock;
    if (now - lastTap < .3) {
      me.boost = 1.6;
      g.sfx('power');
    }
    lastTap = now;
  });
  g.onMove((e) {
    if (e.buttons != 0 || !e.mouse) aim(e);
  });
  double angDiff(double a, double b) {
    var d = b - a;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  // Các điểm thân theo khoảng cách đều dọc đường đi
  List<Offset> segs(_Snake sn) {
    final out = <Offset>[sn.path[0]];
    final gap = sn.r * .55;
    var acc = 0.0;
    for (var i = 1; i < sn.path.length && out.length < sn.len; i++) {
      final p0 = sn.path[i - 1], p1 = sn.path[i];
      acc += (p1 - p0).distance;
      if (acc >= gap) {
        out.add(p1);
        acc = 0;
      }
    }
    return out;
  }

  void move(_Snake sn, double dt) {
    sn.boost = math.max(0, sn.boost - dt);
    sn.gulp = math.max(0, sn.gulp - dt);
    if (sn.boost > 0 && random() < .7) {
      final p = sn.path[math.min(sn.path.length - 1, 12)];
      sd.emit(p.dx, p.dy, rand(-30, 30), rand(-30, 30), life: .4, r: sn.r * .4, grow: 4, c: '#ffe066', a: .8);
    }
    sn.a += clamp(angDiff(sn.a, sn.ta), -turn * dt, turn * dt);
    final v = (sn.bot ? sp * ramp(lv, .75, 1) : sp) * (sn.boost > 0 ? 1.7 : 1);
    sn.x += math.cos(sn.a) * v * dt;
    sn.y += math.sin(sn.a) * v * dt;
    sn.path.insert(0, Offset(sn.x, sn.y));
    final keep = sn.len * sn.r * .55 / 2 + 40;
    if (sn.path.length > keep * 2) sn.path.length = (keep * 2).ceil();
    sn.r = r0 * (1 + math.min(.8, sn.len / 160));
  }

  void kill(_Snake sn) {
    sn.dead = true;
    g.sfx('boom');
    ssh.add(5);
    final pts = segs(sn);
    for (var i = 0; i < pts.length; i += 4) {
      sd.sparks(pts[i].dx, pts[i].dy, 3, sn.skin[0], 180);
    }
    for (var i = 0; i < pts.length; i += 2) {
      addFood(x: pts[i].dx + rand(-8, 8), y: pts[i].dy + rand(-8, 8), big: false, v: 2);
    }
    F.burst(sn.x - camX, sn.y - camY, 24);
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      sd.update(dt);
      ssh.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      inv = math.max(0, inv - dt);
      // Tự chơi (test): bò về hạt gần nhất
      if (g.bot && foods.isNotEmpty) {
        var best = foods.first;
        for (final f in foods) {
          if (hypot(f.x - me.x, f.y - me.y) < hypot(best.x - me.x, best.y - me.y)) best = f;
        }
        me.ta = math.atan2(best.y - me.y, best.x - me.x);
      }
      move(me, dt);
      // Rắn máy: tìm hạt gần, tránh tường; cấp cao có lúc lao chặn đầu bé
      for (final b in bots) {
        if (b.dead) continue;
        b.think -= dt;
        if (b.think <= 0) {
          b.think = rand(.3, .8);
          final chase = lv >= 15 && random() < ramp(lv, 0, .35) && hypot(me.x - b.x, me.y - b.y) < S;
          if (chase) {
            b.ta = math.atan2(me.y + math.sin(me.a) * S * .3 - b.y, me.x + math.cos(me.a) * S * .3 - b.x);
          } else {
            _Food? best;
            var bd = 1e9;
            for (final f in foods) {
              final d = hypot(f.x - b.x, f.y - b.y);
              if (d < bd) {
                bd = d;
                best = f;
              }
            }
            if (best != null) b.ta = math.atan2(best.y - b.y, best.x - b.x) + rand(-.3, .3);
          }
        }
        if (b.x < 80 || b.x > WW - 80 || b.y < 80 || b.y > WH - 80) b.ta = math.atan2(WH / 2 - b.y, WW / 2 - b.x);
        move(b, dt);
      }
      // Ăn hạt
      for (final sn in [me, ...bots]) {
        if (sn.dead) continue;
        for (var i = foods.length - 1; i >= 0; i--) {
          final f = foods[i];
          if (hypot(f.x - sn.x, f.y - sn.y) < sn.r + (f.big ? 18 : 7)) {
            foods.removeAt(i);
            sn.len += f.v;
            sn.gulp = .25;
            if (sn == me) {
              score += f.v;
              g.sfx(f.big ? 'coin' : 'count');
              if (f.big) {
                F.text(f.x - camX, f.y - camY - 20, '+${f.v}', '#ffd43b');
                sd.sparks(f.x, f.y, 10, '#ffe066', 220);
              }
            }
          }
        }
      }
      while (foods.length < 140) {
        addFood();
      }
      // Va chạm: đầu chạm thân rắn khác
      final all = [me, ...bots.where((b) => !b.dead)];
      final bodies = [for (final sn in all) (sn: sn, pts: segs(sn))];
      for (final sn in all) {
        if (sn.dead || (sn == me && inv > 0)) continue;
        for (final b in bodies) {
          final o = b.sn, pts = b.pts;
          if (o == sn) continue;
          var touched = false;
          for (var i = 2; i < pts.length; i++) {
            if (hypot(pts[i].dx - sn.x, pts[i].dy - sn.y) < sn.r * .7 + o.r * .8) {
              touched = true;
              break;
            }
          }
          if (touched) {
            if (sn == me) {
              lives--;
              g.sfx('hit');
              ssh.add(10);
              sd.sparks(me.x, me.y, 18, '#ff8787', 300);
              if (lives <= 0) {
                end = FunEnd(win: false, score: score);
                return null;
              }
              final keep = me.len;
              me.assign(mkSnake(rand(200, WW - 200), rand(200, WH - 200), math.max(14, (keep * .6).round()), me.skin, false));
              inv = 2;
            } else {
              kill(sn);
              if (o == me) F.text(W / 2, H * .3, tr('GIỎI QUÁ!', 'GREAT!'), '#ffd43b');
            }
            break;
          }
        }
      }
      for (var i = bots.length - 1; i >= 0; i--) {
        if (bots[i].dead) {
          bots.removeAt(i);
          g.after(2.5, spawnBot);
        }
      }
      // Tường sân: chạm là bị đẩy lại và mất mạng ở cấp cao
      if (me.x < me.r || me.y < me.r || me.x > WW - me.r || me.y > WH - me.r) {
        me.x = clamp(me.x, me.r, WW - me.r);
        me.y = clamp(me.y, me.r, WH - me.r);
        me.a += math.pi;
        me.ta = me.a;
        if (lv >= 20 && inv <= 0) {
          lives--;
          inv = 2;
          g.sfx('hit');
          if (lives <= 0) {
            end = FunEnd(win: false, score: score);
            return null;
          }
        } else {
          g.sfx('pop');
        }
      }
      camX += (me.x - W / 2 - camX) * math.min(1, dt * 5);
      camY += (me.y - H / 2 - camY) * math.min(1, dt * 5);
      if (score >= need) {
        end = FunEnd(win: true, score: score + lives * 5);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      c.fillStyle = hex(th.edge);
      c.fillRect(0, 0, W, H);
      c.save();
      ssh.apply(c);
      c.translate(-camX, -camY);
      c.fillStyle = hex(th.ground);
      roundRect(c, 0, 0, WW, WH, 40);
      c.fill();
      // Hoa văn chấm nhẹ
      c.fillStyle = 'rgba(0,0,0,.06)';
      final x0 = math.max(0.0, (camX / 48).floor() * 48.0), y0 = math.max(0.0, (camY / 42).floor() * 42.0);
      c.beginPath();
      for (var y = y0; y < math.min(WH, camY + H + 42); y += 42) {
        for (var x = x0 + ((y / 42).round() % 2) * 24; x < math.min(WW, camX + W + 48); x += 48) {
          c.moveTo(x + 5, y);
          c.arc(x, y, 5, 0, 7);
        }
      }
      c.fill();
      c.strokeStyle = '#e03131';
      c.lineWidth = 8;
      c.setLineDash([24, 16]);
      roundRect(c, 0, 0, WW, WH, 40);
      c.stroke();
      c.setLineDash([]);
      for (final f in foods) {
        if (f.x < camX - 30 || f.x > camX + W + 30 || f.y < camY - 30 || f.y > camY + H + 30) continue;
        f.ph += .05;
        if (f.k != null) {
          draw(c, f.k!, f.x, f.y + math.sin(f.ph) * 3, 38, 38, false, math.sin(f.ph * .7) * .2);
        } else {
          c.fillStyle = f.c;
          c.globalAlpha = .35;
          c.beginPath();
          c.arc(f.x, f.y, 11, 0, 7);
          c.fill();
          c.globalAlpha = 1;
          c.beginPath();
          c.arc(f.x, f.y, 6 + math.sin(f.ph * 2) * 1.2, 0, 7);
          c.fill();
        }
      }
      void drawSnake(_Snake sn, bool blink) {
        if (blink) return;
        final pts = segs(sn), n = pts.length;
        if (n < 2) return;
        // Thân là ống trơn: bóng đổ, viền đậm, thân sáng, vạch vảy, dải sáng lưng; đuôi thon dần
        void path(int from, int to) {
          c.beginPath();
          c.moveTo(pts[from].dx, pts[from].dy);
          for (var i = from + 1; i <= to; i++) {
            c.lineTo(pts[i].dx, pts[i].dy);
          }
        }

        c.lineCap = 'round';
        c.lineJoin = 'round';
        final parts = [(0, (n * .6).floor(), 1.0), ((n * .6).floor(), (n * .85).floor(), .8), ((n * .85).floor(), n - 1, .6)];
        for (final (a, b, k) in parts) {
          if (b <= a) continue;
          path(a, b);
          c.strokeStyle = 'rgba(0,0,0,.18)';
          c.lineWidth = sn.r * 2.1 * k;
          c.save();
          c.translate(3, 5);
          c.stroke();
          c.restore();
        }
        for (final (a, b, k) in parts) {
          if (b <= a) continue;
          path(a, b);
          c.strokeStyle = sn.skin[1];
          c.lineWidth = sn.r * 2 * k;
          c.stroke();
        }
        for (final (a, b, k) in parts) {
          if (b <= a) continue;
          path(a, b);
          c.strokeStyle = sn.skin[0];
          c.lineWidth = sn.r * 1.5 * k;
          c.stroke();
        }
        // Vảy: chấm đậm xen kẽ dọc thân
        c.fillStyle = sn.skin[1];
        for (var i = 3; i < n - 2; i += 3) {
          final rr = sn.r * (i > n * .85 ? .6 : i > n * .6 ? .8 : 1);
          c.beginPath();
          c.arc(pts[i].dx, pts[i].dy, rr * .38, 0, 7);
          c.fill();
        }
        path(0, (n * .85).floor());
        c.strokeStyle = 'rgba(255,255,255,.35)';
        c.lineWidth = sn.r * .35;
        c.save();
        c.translate(-sn.r * .25, -sn.r * .3);
        c.stroke();
        c.restore();
        // Đầu to hơn thân, nuốt mồi thì phồng
        final gulp = sn.gulp > 0 ? math.sin(sn.gulp / .25 * math.pi) * .25 : 0.0;
        c.fillStyle = sn.skin[1];
        c.beginPath();
        c.ellipse(sn.x, sn.y, sn.r * (1.25 + gulp), sn.r * (1.1 + gulp), sn.a, 0, 7);
        c.fill();
        c.fillStyle = sn.skin[0];
        c.beginPath();
        c.ellipse(sn.x - math.cos(sn.a) * sn.r * .05, sn.y - math.sin(sn.a) * sn.r * .05, sn.r * (1.08 + gulp), sn.r * (.92 + gulp), sn.a, 0, 7);
        c.fill();
        if (sn.boost > 0) {
          c.strokeStyle = 'rgba(255,212,59,.7)';
          c.lineWidth = 4;
          c.beginPath();
          c.arc(sn.x, sn.y, sn.r * 1.4, 0, 7);
          c.stroke();
        }
        // Đầu: mắt to nhìn theo hướng bò, lưỡi thè ra
        final r = sn.r * 1.05, cs = math.cos(sn.a), s2 = math.sin(sn.a);
        if (math.sin(t * 6 + sn.len) > .3) {
          c.strokeStyle = '#ff4d6d';
          c.lineWidth = 3;
          c.beginPath();
          c.moveTo(sn.x + cs * r, sn.y + s2 * r);
          c.lineTo(sn.x + cs * r * 1.7, sn.y + s2 * r * 1.7);
          c.stroke();
        }
        for (final k in const [-1, 1]) {
          final ex = sn.x + cs * r * .35 - s2 * r * .5 * k, ey = sn.y + s2 * r * .35 + cs * r * .5 * k;
          c.fillStyle = '#fff';
          c.beginPath();
          c.arc(ex, ey, r * .42, 0, 7);
          c.fill();
          c.fillStyle = '#212529';
          c.beginPath();
          c.arc(ex + cs * r * .14, ey + s2 * r * .14, r * .24, 0, 7);
          c.fill();
          c.fillStyle = '#fff';
          c.beginPath();
          c.arc(ex + cs * r * .06 - r * .08, ey + s2 * r * .06 - r * .08, r * .08, 0, 7);
          c.fill();
        }
        c.fillStyle = 'rgba(255,110,140,.45)';
        for (final k in const [-1, 1]) {
          c.beginPath();
          c.arc(sn.x - cs * r * .1 - s2 * r * .75 * k, sn.y - s2 * r * .1 + cs * r * .75 * k, r * .18, 0, 7);
          c.fill();
        }
      }

      for (final b in bots) {
        drawSnake(b, false);
      }
      drawSnake(me, inv > 0 && (inv * 8).floor() % 2 == 1);
      sd.draw(c);
      c.restore();
      F.draw(c);
      hud(c, W, score: score);
      for (var i = 0; i < 3; i++) {
        draw(c, 'Red heart', W - 40 - i * 36, 32, 30, 30, false, 0, i < lives ? 1 : .22);
      }
      goalPill(c, W, score, need, 16);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Ăn $need hạt', 'Eat $need dots'),
            tr('Kéo ngón tay để rắn bò theo · Chạm 2 lần để tăng tốc · Đừng đâm vào rắn khác', 'Drag to steer · Double-tap to boost · Don\'t hit other snakes'), tr);
      }
      if (end != null) banner(c, W, H, endText(end!.win, lv, tr), tr('$score/$need hạt', '$score/$need dots'));
    },
  );
}

// ---------- 2. Bắn bia: bia, quái hiện lên di chuyển; chạm để bắn, đừng bắn bạn thỏ ----------
class _Target {
  _Target(this.k, this.x, this.y, this.v, this.s, this.ph, this.wob) : y0 = y;
  final String k;
  double x, y, v, s, ph, dead = 0;
  final double y0;
  final bool wob;
}

class _Hole {
  double x = 0, y = 0, t = 0;
}

Future<LoopGame> gallery(Fun g) async {
  final lv = g.level, th = theme(lv), need = (14 + lv * .9).round(), tr = g.tr;
  const time = 40.0;
  const bad = ['Bullseye', 'Alien monster', 'Ghost', 'Balloon', 'Bat'], good = ['Rabbit face', 'Baby chick'];
  final (sh, _) = await (
    sheets(['gallery/gallery', 'plat/enemies', 'animals/round', 'fxa/fx']),
    loadAll([...bad, ...good, 'Collision', 'Glowing star', 'Coin', 'Alarm clock', ...themeImgs(lv)]),
  ).wait;
  final gs = sh[0], en = sh[1], an = sh[2];
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), D = dust(200), SH = shaker();
  // Quầy bắn bia Kenney: bia tròn, vịt gỗ có hồng tâm, ong bay; bạn thỏ/gà con là hình thú tròn
  const look = {'Bullseye': 'target_red1_outline', 'Alien monster': 'duck_outline_target_yellow', 'Ghost': 'duck_outline_target_white'};
  const friend = {'Rabbit face': 'rabbit', 'Baby chick': 'chick'};
  final holes = List.generate(12, (_) => _Hole());
  var holeI = 0;
  Offset? aim;
  final lanes = [H * .3, H * .5, H * .7];
  final targets = <_Target>[];
  var score = 0, combo = 0;
  double t = 0, spawn = .5, endT = 0, bonusT = 0;
  double? shotT;
  FunEnd? end;
  final sp = ramp(lv, 120, 300);
  void shoot(double x, double y) {
    if (end != null || t < 2) return;
    shotT = .18;
    g.sfx('shoot');
    SH.add(2.5);
    aim = Offset(x, y);
    final hl = holes[holeI];
    holeI = (holeI + 1) % holes.length;
    hl
      ..x = x
      ..y = y
      ..t = 1.2;
    final tg = targets.where((o) => o.dead <= 0 && hypot(o.x - x, o.y - y) < o.s * .55).firstOrNull;
    if (tg == null) {
      combo = 0;
      return;
    }
    tg.dead = .4;
    if (good.contains(tg.k)) {
      score = math.max(0, score - 3);
      combo = 0;
      g.sfx('wrong');
      F.text(tg.x, tg.y - 40, tr('Ối! Bạn mà!', 'Oops! A friend!'), '#ff6b6b');
      return;
    }
    if (tg.k == 'Alarm clock') {
      bonusT += 5;
      g.sfx('power');
      F.text(tg.x, tg.y - 40, tr('+5 giây', '+5 sec'), '#4dabf7');
      return;
    }
    combo++;
    final p = (tg.k == 'Bullseye' ? 3 : tg.k == 'Bat' ? 2 : 1) + (combo >= 5 ? 1 : 0);
    score += p;
    g.sfx('boom');
    D.sparks(tg.x, tg.y, 12, '#ffe066', 260);
    D.debris(tg.x, tg.y, 6, '#c08552', 220);
    F.text(tg.x, tg.y - 40, '+$p', '#ffd43b');
  }

  g.onDown((e) => shoot(e.x, e.y));
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      for (final hl in holes) {
        hl.t = math.max(0, hl.t - dt);
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (shotT != null) {
        shotT = shotT! - dt;
        if (shotT! <= 0) shotT = null;
      }
      spawn -= dt;
      if (spawn <= 0) {
        spawn = rand(.45, .9) * ramp(lv, 1.1, .6);
        final lane = rand(0, 3).floor(), dir = lane % 2 == 1 ? -1 : 1, r = random();
        final k = r < ramp(lv, .12, .25) ? pick(good) : r > .97 ? 'Alarm clock' : pick(bad);
        final s = S * (k == 'Bullseye' ? ramp(lv, .14, .1) : .13);
        targets.add(_Target(k, dir > 0 ? -s : W + s, lanes[lane], dir * sp * rand(.8, 1.3), s, rand(0, 6), lv >= 15 && random() < .5));
      }
      for (var i = targets.length - 1; i >= 0; i--) {
        final o = targets[i];
        o.ph += dt;
        if (o.dead > 0) {
          o.dead -= dt;
          if (o.dead <= 0) targets.removeAt(i);
          continue;
        }
        o.x += o.v * dt;
        if (o.wob) o.y = o.y0 + math.sin(o.ph * 3) * S * .06;
        if (o.x < -S * .3 || o.x > W + S * .3) targets.removeAt(i);
      }
      // Tự chơi (test): bắn bia gần nhất
      if (g.bot && random() < dt * 3) {
        final o = targets.where((o) => o.dead <= 0 && !good.contains(o.k) && o.x > 0 && o.x < W).firstOrNull;
        if (o != null) shoot(o.x, o.y);
      }
      if (t - 2 >= time + bonusT) {
        end = FunEnd(win: score >= need, score: score);
        g.sfx(score >= need ? 'win' : 'pop');
      }
      return null;
    },
    draw: () {
      c.save();
      SH.apply(c);
      // Quầy bắn bia: nền ván gỗ, cây + mây gỗ trôi chậm, mỗi làn là dải cỏ/nước gợn sóng chạy ngang
      if (gs != null) {
        tile(c, gs, 'bg_wood', math.min(256, S * .35), 0, 0, -10, -10, W + 20, H + 20);
      } else {
        _sky(c, W, H, th);
      }
      for (var k = 0; k < 3; k++) {
        spr(c, gs, k.isOdd ? 'cloud2' : 'cloud1', ((k * W * .45 + t * 14) % (W + 300)) - 150, H * .14 + k * 18, S * .1);
      }
      for (var k = 0; k < 5; k++) {
        spr(c, gs, k.isOdd ? 'tree_pine' : 'tree_oak', (k + .5) * W / 5, lanes[0] - S * .02, S * .2, alpha: .9);
      }
      final laneH = S * .09;
      for (var i = 0; i < lanes.length; i++) {
        final wave = math.sin(t * 2 + i) * 4;
        stripX(c, gs, i.isOdd ? 'water1' : 'grass1', (i.isOdd ? -1 : 1) * t * 40, lanes[i] + S * .055 + wave, laneH, W);
      }
      for (final o in targets) {
        final bob = math.sin(o.ph * 5) * 3;
        if (o.dead > 0) {
          // Bị bắn: lật ra sau rồi rơi xuống
          final k = 1 - o.dead / .4;
          if (good.contains(o.k)) {
            spr(c, an, friend[o.k]!, o.x, o.y + bob, o.s, rot: math.sin(k * 30) * .3);
            continue;
          }
          c.save();
          c.translate(o.x, o.y + k * k * S * .15);
          c.scale(math.cos(k * math.pi), 1);
          spr(c, gs, math.cos(k * math.pi) < 0 ? 'target_back_outline' : (look[o.k] ?? 'target_white_outline'), 0, 0, o.s, alpha: 1 - k * .6);
          c.restore();
          continue;
        }
        spr(c, gs, 'stick_wood_outline', o.x, o.y + S * .07 + bob, S * .14);
        if (look[o.k] != null) {
          spr(c, gs, look[o.k]!, o.x, o.y + bob, o.s, flip: o.v < 0 && o.k != 'Bullseye');
        } else if (o.k == 'Bat') {
          anim(c, en, 'bee', o.ph, o.x, o.y + bob, o.s * .9, flip: o.v > 0);
        } else if (friend[o.k] != null) {
          spr(c, an, friend[o.k]!, o.x, o.y + bob, o.s, rot: math.sin(o.ph * 3) * .1);
        } else {
          draw(c, o.k, o.x, o.y + bob, o.s, o.s, false, math.sin(o.ph * 3) * .15);
        }
      }
      // Rèm sân khấu trên và hai bên
      stripX(c, gs, 'curtain_top', 0, -4, S * .1, W);
      spr(c, gs, 'curtain', S * .05, H * .3, H * .6, alpha: .95);
      spr(c, gs, 'curtain', W - S * .05, H * .3, H * .6, flip: true, alpha: .95);
      for (final hl in holes) {
        if (hl.t > 0) spr(c, gs, 'shot_brown_large', hl.x, hl.y, 16, alpha: math.min(1, hl.t * 2));
      }
      D.draw(c);
      if (aim != null) spr(c, gs, 'crosshair', aim!.dx, aim!.dy, 50 * (shotT != null ? 1 + shotT! * 2 : 1), alpha: .85);
      c.restore();
      F.draw(c);
      hud(c, W, score: score, time: math.max(0, time + bonusT - math.max(0, t - 2)));
      goalPill(c, W, score, need);
      if (t < 2) {
        levelBanner(c, W, H, lv, tr('Bắn được $need điểm', 'Score $need points'),
            tr('Chạm vào bia và quái vật · Đừng bắn bạn thỏ, gà con', 'Tap targets and monsters · Don\'t hit the bunny or chick'), tr);
      }
      if (end != null) banner(c, W, H, endText(end!.win, lv, tr), tr('$score/$need điểm', '$score/$need points'));
    },
  );
}

// ---------- 3. Xe tăng: tách sang funtank (agent G) ----------

// ---------- 4. Xếp gạch: khối rơi, nút ← ⟳ → ⤓, xoá hàng ----------
const List<List<List<int>>> _shapes = [
  [[1, 1, 1, 1]],
  [[1, 1], [1, 1]],
  [[0, 1, 0], [1, 1, 1]],
  [[1, 0, 0], [1, 1, 1]],
  [[0, 0, 1], [1, 1, 1]],
  [[1, 1, 0], [0, 1, 1]],
  [[0, 1, 1], [1, 1, 0]],
];
const List<String> _scol = ['#4dabf7', '#ffd43b', '#b197fc', '#ff922b', '#339af0', '#ff6b6b', '#51cf66'];

class _Piece {
  _Piece(this.m, this.c, this.x, this.y);
  List<List<int>> m;
  final String c;
  int x, y;
}

class _Flash {
  _Flash(this.y, this.t);
  final int y;
  double t;
}

Future<LoopGame> blocks(Fun g) async {
  final lv = g.level, th = theme(lv), need = math.min(30, 3 + (lv * .4).floor()), tr = g.tr;
  final (shs, _) = await (sheets(['puzzle/puzzle']), loadAll(['Glowing star', 'Coin'])).wait;
  final pz = shs[0];
  // Ô kẹo bóng Kenney theo màu khối
  const pzOf = {'#4dabf7': 'sq_cyan', '#ffd43b': 'sq_yellow', '#b197fc': 'sq_purple', '#ff922b': 'sq_orange', '#339af0': 'sq_blue', '#ff6b6b': 'sq_red', '#51cf66': 'sq_green', '#adb5bd': 'sq_grey'};
  final D = dust(200), SH = shaker(), flashes = <_Flash>[];
  double lockT = 0;
  var lockCells = <(int, int)>[];
  final c = g.c, W = g.W, H = g.H;
  const C = 10, rr = 18;
  final btnH = math.min(90.0, H * .12), cs = math.min((W * .62) / C, (H - (W < 640 ? 130 : 90) - btnH) / rr).floorToDouble();
  final ox = ((W - C * cs) / 2).roundToDouble(), oy = W < 640 ? 108.0 : 70.0;
  // Cấp thấp chỉ dùng khối dễ (I, O, T, L); có sẵn vài hàng rác ở cấp cao.
  final pool = lv < 6 ? [0, 1, 2, 3] : [0, 1, 2, 3, 4, 5, 6];
  final grid = List.generate(rr, (_) => List<String?>.filled(C, null));
  final junk = lv < 15 ? 0 : math.min(6, ((lv - 10) / 8).floor());
  for (var r = rr - junk; r < rr; r++) {
    final hole = rand(0, C.toDouble()).floor();
    for (var cc = 0; cc < C; cc++) {
      if (cc != hole && random() < .8) grid[r][cc] = '#adb5bd';
    }
  }
  final F = fx();
  _Piece? cur;
  var nextK = pick(pool), lines = 0, score = 0;
  double t = 0, fall = 0, endT = 0;
  var drop = false;
  FunEnd? end;
  bool fits(List<List<int>> m, int x, int y) {
    for (var i = 0; i < m.length; i++) {
      for (var j = 0; j < m[i].length; j++) {
        if (m[i][j] == 0) continue;
        if (!(x + j >= 0 && x + j < C && y + i < rr && (y + i < 0 || grid[y + i][x + j] == null))) return false;
      }
    }
    return true;
  }

  void spawn() {
    final k = nextK;
    nextK = pick(pool);
    cur = _Piece(_shapes[k], _scol[k], ((C - _shapes[k][0].length) / 2).floor(), -1);
    if (!fits(cur!.m, cur!.x, cur!.y + 1)) {
      end = FunEnd(win: false, score: score);
      g.sfx('wrong');
    }
  }

  spawn();
  List<List<int>> rot(List<List<int>> m) => [for (var j = 0; j < m[0].length; j++) [for (var i = m.length - 1; i >= 0; i--) m[i][j]]];
  final btns = <(String, void Function())>[
    ('←', () {
      if (fits(cur!.m, cur!.x - 1, cur!.y)) {
        cur!.x--;
        g.sfx('tap');
      }
    }),
    ('⟳', () {
      final r = rot(cur!.m);
      for (final k in const [0, -1, 1, -2, 2]) {
        if (fits(r, cur!.x + k, cur!.y)) {
          cur!.m = r;
          cur!.x += k;
          g.sfx('tap');
          break;
        }
      }
    }),
    ('→', () {
      if (fits(cur!.m, cur!.x + 1, cur!.y)) {
        cur!.x++;
        g.sfx('tap');
      }
    }),
    ('⬇', () => drop = true),
  ];
  var pressI = -1;
  double pressT = 0;
  final bw = math.min(140.0, (W - 40) / 4 - 12), by = H - btnH - 10;
  double bx(int i) => W / 2 + (i - 1.5) * (bw + 12) - bw / 2;
  g.onDown((e) {
    if (end != null || t < 2 || cur == null) return;
    final x = e.x, y = e.y;
    if (y > by - 10) {
      for (var i = 0; i < btns.length; i++) {
        if (x >= bx(i) && x <= bx(i) + bw) {
          btns[i].$2();
          pressI = i;
          pressT = .15;
          break;
        }
      }
      return;
    }
    // Chạm lên bảng: chạm bên trái/phải khối để dời, chạm vào khối để xoay
    final cx = ox + (cur!.x + cur!.m[0].length / 2) * cs;
    if ((x - cx).abs() < cs * 1.5) {
      btns[1].$2();
    } else if (x < cx) {
      btns[0].$2();
    } else {
      btns[2].$2();
    }
  });
  void lock() {
    final p = cur!;
    lockCells = [];
    for (var i = 0; i < p.m.length; i++) {
      for (var j = 0; j < p.m[i].length; j++) {
        if (p.m[i][j] != 0 && p.y + i >= 0) {
          grid[p.y + i][p.x + j] = p.c;
          lockCells.add((p.x + j, p.y + i));
        }
      }
    }
    lockT = .2;
    if (drop) {
      SH.add(4);
      for (final (x, y) in lockCells) {
        D.puff(ox + (x + .5) * cs, oy + (y + 1) * cs, 1, 'rgba(255,255,255,1)', 50, cs * .2);
      }
    }
    if (p.y < 0) {
      end = FunEnd(win: false, score: score);
      return;
    }
    var n = 0;
    for (var r = rr - 1; r >= 0; r--) {
      if (grid[r].every((v) => v != null)) {
        // Hàng xoá: loé sáng + vụn kẹo bắn ra
        flashes.add(_Flash(r + n, .35));
        for (var cc = 0; cc < C; cc++) {
          D.debris(ox + (cc + .5) * cs, oy + (r + .5) * cs, 2, grid[r][cc]!, 220);
        }
        grid.removeAt(r);
        grid.insert(0, List<String?>.filled(C, null));
        n++;
        r++;
      }
    }
    if (n > 0) {
      SH.add(3 + n * 2.0);
      lockCells = [];
      lines += n;
      score += const [0, 1, 3, 6, 10][n];
      g.sfx(n > 1 ? 'win' : 'coin');
      F.text(W / 2, oy + rr * cs / 2, n > 1 ? tr('$n HÀNG!', '$n LINES!') : tr('+1 hàng', '+1 line'), '#ffd43b');
      F.burst(W / 2, oy + rr * cs / 2, 20);
    } else {
      g.sfx('pop');
    }
    drop = false;
    if (lines >= need) {
      end = FunEnd(win: true, score: score + 10);
      g.sfx('win');
      return;
    }
    spawn();
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      D.update(dt);
      SH.update(dt);
      lockT = math.max(0, lockT - dt);
      pressT = math.max(0, pressT - dt);
      for (var i = flashes.length - 1; i >= 0; i--) {
        flashes[i].t -= dt;
        if (flashes[i].t <= 0) flashes.removeAt(i);
      }
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      fall += dt;
      final sp = drop ? .03 : ramp(lv, .75, .22);
      if (fall >= sp) {
        fall = 0;
        if (fits(cur!.m, cur!.x, cur!.y + 1)) {
          cur!.y++;
        } else {
          lock();
        }
      }
      return null;
    },
    draw: () {
      _sky(c, W, H, th);
      c.save();
      SH.apply(c);
      c.fillStyle = 'rgba(20,30,50,.85)';
      roundRect(c, ox - 8, oy - 8, C * cs + 16, rr * cs + 16, 14);
      c.fill();
      c.fillStyle = 'rgba(255,255,255,.04)';
      for (var x = 1; x < C; x += 2) {
        c.fillRect(ox + x * cs, oy, cs, rr * cs);
      }
      void cell(num x, num y, String col, [double k = 1]) {
        final px = ox + (x + .5) * cs, py = oy + (y + .5) * cs;
        if (pz != null && pzOf[col] != null) {
          sprBox(c, pz, pzOf[col], px, py, (cs - 1) * k, (cs - 1) * k);
        } else {
          c.fillStyle = col;
          roundRect(c, ox + x * cs + 1, oy + y * cs + 1, cs - 2, cs - 2, 5);
          c.fill();
          c.fillStyle = 'rgba(255,255,255,.3)';
          c.fillRect(ox + x * cs + 4, oy + y * cs + 3, cs - 8, 4);
        }
      }

      final lk = lockT > 0 ? 1 + math.sin(lockT / .2 * math.pi) * .1 : 1.0;
      for (var y = 0; y < rr; y++) {
        for (var x = 0; x < C; x++) {
          final col = grid[y][x];
          if (col != null) cell(x, y, col, lockCells.contains((x, y)) ? lk : 1);
        }
      }
      for (final f in flashes) {
        c.fillStyle = 'rgba(255,255,255,${f.t / .35 * .9})';
        final k = 1 + (1 - f.t / .35) * .3;
        c.fillRect(ox - 6 * k, oy + f.y * cs - cs * (k - 1) / 2, C * cs + 12 * k, cs * k);
      }
      final p = cur;
      if (p != null && end == null) {
        var gy = p.y;
        while (fits(p.m, p.x, gy + 1)) {
          gy++;
        }
        // Rơi mượt: vẽ khối lệch dần xuống theo thời gian tới bước rơi kế tiếp (không vượt bóng đổ)
        final sp = drop ? .03 : ramp(lv, .75, .22);
        final fy = math.min(gy.toDouble(), p.y + math.min(1, fall / sp) * (fits(p.m, p.x, p.y + 1) ? 1 : 0));
        for (var i = 0; i < p.m.length; i++) {
          for (var j = 0; j < p.m[i].length; j++) {
            if (p.m[i][j] != 0 && gy + i >= 0) {
              c.strokeStyle = 'rgba(255,255,255,.35)';
              c.lineWidth = 2;
              c.strokeRect(ox + (p.x + j) * cs + 3, oy + (gy + i) * cs + 3, cs - 6, cs - 6);
            }
          }
        }
        for (var i = 0; i < p.m.length; i++) {
          for (var j = 0; j < p.m[i].length; j++) {
            if (p.m[i][j] != 0 && fy + i >= -.5) cell(p.x + j, fy + i, p.c);
          }
        }
      }
      D.draw(c);
      c.restore();
      // Khối kế tiếp
      final nx = ox + C * cs + 24;
      if (nx + 90 < W) {
        c.fillStyle = 'rgba(0,0,0,.25)';
        roundRect(c, nx, oy, 96, 80, 14);
        c.fill();
        final m = _shapes[nextK];
        for (var i = 0; i < m.length; i++) {
          for (var j = 0; j < m[i].length; j++) {
            if (m[i][j] == 0) continue;
            if (pz != null) {
              sprBox(c, pz, pzOf[_scol[nextK]], nx + 20 + j * 18, oy + 26 + i * 18, 17, 17);
            } else {
              c.fillStyle = _scol[nextK];
              c.fillRect(nx + 12 + j * 18, oy + 18 + i * 18, 16, 16);
            }
          }
        }
      }
      for (var i = 0; i < btns.length; i++) {
        final pk = i == pressI && pressT > 0 ? 4.0 : 0.0;
        c.fillStyle = 'rgba(0,0,0,.2)';
        roundRect(c, bx(i), by + 5, bw, btnH, 22);
        c.fill();
        c.save();
        c.translate(0, pk);
        c.fillStyle = '#fff';
        roundRect(c, bx(i), by, bw, btnH, 22);
        c.fill();
        c.fillStyle = '#212529';
        c.font = '800 ${(btnH * .5).round()}px';
        c.textAlign = 'center';
        c.fillText(btns[i].$1, bx(i) + bw / 2, by + btnH * .68);
        c.restore();
      }
      F.draw(c);
      hud(c, W, score: score);
      goalPill(c, W, lines, need, 16);
      if (t < 2) levelBanner(c, W, H, lv, tr('Xoá $need hàng', 'Clear $need lines'), tr('Chạm nút để dời, xoay, thả nhanh', 'Tap the buttons to move, rotate, drop'), tr);
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('ĐẦY RỒI!', 'FULL!'), tr('$lines/$need hàng', '$lines/$need lines'));
    },
  );
}

// ---------- 5. Nhảy mây: tự bật nhảy, kéo trái phải để đáp lên mây, lên thật cao ----------
class _Plat {
  _Plat(this.x, this.y, this.w, this.kind, [this.v = 0]);
  double x, y, w, v, dip = 0;
  final String kind;
  bool gone = false;
}

class _JCoin {
  _JCoin(this.x, this.y, [this.rocket = false]);
  final double x, y;
  final bool rocket;
}

class _JFoe {
  _JFoe(this.x, this.y, this.ph, this.k);
  double x, y, ph;
  final String k;
}

class _Bit {
  _Bit(this.x, this.y, this.vr, this.w);
  double x, y, vy = 0, r = 0;
  final double vr, w;
}

Future<LoopGame> jumper(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 60, 400).round(), tr = g.tr; // mét
  final (sh, _) = await (
    sheets(['plat/tiles', 'plat/enemies', 'fxa/fx']),
    loadAll([g.hero, 'Cloud', 'Glowing star', 'Coin', 'Bat', 'Rocket', 'Ghost', ...themeImgs(lv)]),
  ).wait;
  final tl = sh[0], en = sh[1], fxs = sh[2];
  final c = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), G = S * 2.6, jump = -S * 1.55, D = dust(200), SH = shaker();
  double land = 0;
  final bits = <_Bit>[];
  var meX = W / 2, meY = H * .7, meVy = jump, meTx = W / 2, rocket = 0.0;
  final meW = S * .12;
  final plats = <_Plat>[], coins = <_JCoin>[], foes = <_JFoe>[];
  var camY = 0.0, best = 0, coinN = 0;
  double t = 0, endT = 0, topY = H;
  FunEnd? end;
  double gap() => S * ramp(lv, .16, .27);
  void add(double y) {
    final r = random(), w = S * ramp(lv, .28, .18);
    final kind = lv >= 8 && r < ramp(lv, .1, .35) ? 'move' : lv >= 20 && r > 1 - ramp(lv, 0, .18) ? 'break' : 'cloud';
    plats.add(_Plat(rand(w / 2, W - w / 2), y, w, kind, rand(60, 140) * (random() < .5 ? -1 : 1)));
    if (random() < .3) coins.add(_JCoin(rand(30, W - 30), y - S * .1));
    if (lv >= 12 && random() < ramp(lv, .03, .12)) foes.add(_JFoe(rand(40, W - 40), y - S * .2, rand(0, 6), pick(const ['Bat', 'Ghost'])));
    if (random() < .015) coins.add(_JCoin(rand(30, W - 30), y - S * .15, true));
  }

  plats.add(_Plat(W / 2, H * .85, W, 'ground'));
  _Plat? botT;
  var botY = H * .85;
  for (var y = H * .85 - gap(); y > -H; y -= gap() * rand(.8, 1.1)) {
    add(y);
    topY = y;
  }
  g.onDown((e) => meTx = e.x);
  g.onMove((e) {
    if (e.buttons != 0 || !e.mouse) meTx = e.x;
  });
  int height() => math.max(0, ((H * .7 - meY) / (S * .1)).round());
  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      // Tự chơi (test): chọn bục gần nhất phía trên chỗ vừa đáp, giữ tới lần đáp sau
      if (g.bot) {
        if (botT == null || botT!.gone || !plats.contains(botT)) {
          for (final p in plats) {
            if (!p.gone && p.kind != 'break' && p.y < botY - 10 && (botT == null || p.y > botT!.y)) botT = p;
          }
        }
        if (botT != null) meTx = botT!.x;
      }
      meX += (meTx - meX) * math.min(1, dt * 8);
      D.update(dt);
      SH.update(dt);
      land = math.max(0, land - dt);
      for (final p in plats) {
        if (p.dip > 0) p.dip = math.max(0, p.dip - dt);
      }
      for (var i = bits.length - 1; i >= 0; i--) {
        final b = bits[i];
        b.vy += G * dt;
        b.y += b.vy * dt;
        b.r += b.vr * dt;
        if (b.y > camY + H + 100) bits.removeAt(i);
      }
      if (rocket > 0) {
        rocket -= dt;
        meVy = jump * 1.4;
        if (random() < .9) D.emit(meX + rand(-6, 6), meY + meW * .1, rand(-30, 30), rand(150, 260), life: .35, r: 5, grow: 8, c: random() < .5 ? '#ff922b' : '#ffd43b', a: .9);
      } else {
        meVy += G * dt;
      }
      final prevY = meY;
      meY += meVy * dt;
      if (meVy > 0) {
        for (final p in plats) {
          if (p.gone || (meX - p.x).abs() > p.w / 2 + meW * .2) continue;
          if (prevY <= p.y && meY >= p.y) {
            if (p.kind == 'break') {
              p.gone = true;
              g.sfx('pop');
              D.debris(p.x, p.y, 10, '#c08552', 220);
              bits.add(_Bit(p.x - p.w / 4, p.y, -2, p.w / 2));
              bits.add(_Bit(p.x + p.w / 4, p.y, 2, p.w / 2));
              continue;
            }
            meY = p.y;
            botY = p.y;
            botT = null;
            meVy = jump;
            g.sfx('jump');
            land = .2;
            p.dip = .3;
            D.puff(meX, p.y, 4, 'rgba(255,255,255,1)', 60, 6);
            break;
          }
        }
      }
      for (final p in plats) {
        if (p.kind == 'move') {
          p.x += p.v * dt;
          if (p.x < p.w / 2 || p.x > W - p.w / 2) p.v *= -1;
        }
      }
      for (var i = coins.length - 1; i >= 0; i--) {
        final cn = coins[i];
        if (hypot(cn.x - meX, cn.y - meY + meW / 2) < meW * .7) {
          coins.removeAt(i);
          if (cn.rocket) {
            rocket = 2.5;
            g.sfx('power');
            SH.add(4);
          } else {
            coinN++;
            g.sfx('coin');
            D.sparks(cn.x, cn.y, 6, '#ffe066', 160);
          }
        }
      }
      for (final f in foes) {
        f.ph += dt;
        f.x += math.sin(f.ph) * 60 * dt;
        if (rocket <= 0 && hypot(f.x - meX, f.y - meY + meW / 2) < meW * .6) {
          if (meVy > 0) {
            meVy = jump;
            g.sfx('boom');
            D.sparks(f.x, f.y, 12, '#ffe066', 260);
            SH.add(5);
            land = .2;
            f.y = 1e9;
          } else {
            end = FunEnd(win: false, score: best + coinN);
            g.sfx('hit');
            SH.add(10);
          }
        }
      }
      // Camera theo bé đi lên
      final want = math.min(camY, meY - H * .45);
      camY += (want - camY) * math.min(1, dt * 5);
      while (topY > camY - H * .3) {
        topY -= gap() * rand(.8, 1.1);
        add(topY);
      }
      for (var i = plats.length - 1; i >= 0; i--) {
        if (plats[i].y > camY + H + 80) plats.removeAt(i);
      }
      best = math.max(best, height());
      if (end == null && meY > camY + H + meW) {
        end = FunEnd(win: false, score: best + coinN);
        g.sfx('wrong');
      }
      if (end == null && best >= need) {
        end = FunEnd(win: true, score: best + coinN * 2);
        g.sfx('win');
      }
      return null;
    },
    draw: () {
      final k = math.min(1, best / math.max(need, 1));
      final gr = c.createLinearGradient(0, 0, 0, H);
      gr.addColorStop(0, k > .6 ? '#364fc7' : hex(th.sky[0]));
      gr.addColorStop(1, hex(th.sky[1]));
      c.fillStyle = gr;
      c.fillRect(0, 0, W, H);
      draw(c, th.sun, W * .86, H * .12, S * .12);
      // Mây nền trôi chậm theo độ cao (parallax)
      for (var k = 0; k < 5; k++) {
        final y = ((k * 173 - camY * .3) % (H + 120) + H + 120) % (H + 120) - 60;
        draw(c, 'Cloud', ((k * 211 + t * 8) % (W + 160)) - 80, y, 90 + k * 12.0, (90 + k * 12) * .6, false, 0, .55);
      }
      c.save();
      SH.apply(c);
      c.translate(0, -camY);
      // Bục mây/đảo nổi Kenney: đầu trái + giữa lặp + đầu phải; nhún xuống khi bé đáp
      void plat(_Plat p, String kind) {
        final hh = math.max(26.0, S * .055), n = math.max(0, ((p.w - hh * 2) / hh).round()), w = hh * (n + 2), x0 = p.x - w / 2;
        final y = p.y - hh * .2 + (p.dip > 0 ? math.sin(p.dip / .3 * math.pi) * 8 : 0);
        final gg = kind == 'move' ? 'purple' : kind == 'break' ? 'dirt' : 'grass';
        spr(c, tl, 'terrain_${gg}_cloud_left', x0 + hh / 2, y + hh / 2, hh);
        for (var i = 0; i < n; i++) {
          spr(c, tl, 'terrain_${gg}_cloud_middle', x0 + hh * (i + 1.5), y + hh / 2, hh);
        }
        spr(c, tl, 'terrain_${gg}_cloud_right', x0 + w - hh / 2, y + hh / 2, hh);
      }

      for (final p in plats) {
        if (p.gone) continue;
        if (p.kind == 'ground') {
          c.fillStyle = hex(th.ground);
          c.fillRect(0, p.y, W, H);
          c.fillStyle = hex(th.edge);
          c.fillRect(0, p.y, W, 8);
          continue;
        }
        if (tl != null) {
          plat(p, p.kind);
        } else {
          draw(c, 'Cloud', p.x, p.y + 8, p.w * 1.1, p.w * .45);
        }
      }
      for (final b in bits) {
        c.save();
        c.translate(b.x, b.y);
        c.rotate(b.r);
        spr(c, tl, 'terrain_dirt_cloud_middle', 0, 0, math.max(26, S * .055));
        c.restore();
      }
      for (final cn in coins) {
        if (cn.rocket) {
          draw(c, 'Rocket', cn.x, cn.y + math.sin(t * 4 + cn.x) * 4, 44, 44, false, math.sin(t * 3) * .2);
        } else {
          coin(c, fxs, t + cn.x * .01, cn.x, cn.y, 32);
        }
      }
      for (final f in foes) {
        anim(c, en, f.k == 'Bat' ? 'bee' : 'fly', t + f.ph, f.x, f.y, S * .1, flip: math.cos(f.ph) > 0);
      }
      D.draw(c);
      // Bé: kéo dài khi bật lên, nén lại khi đáp
      final sq = land > 0 ? math.sin(land / .2 * math.pi) * .18 : 0.0, st = meVy < 0 ? math.min(.12, -meVy / (S * 12)) : 0.0;
      c.save();
      c.translate(meX, meY);
      c.scale(1 + sq - st * .5, 1 - sq + st);
      c.translate(-meX, -meY);
      fig.drawFigure(c.canvas, meX, meY, meW * 1.35, fig.heroOf(g.hero), pose: meVy < 0 ? 'jump' : 'cheer', t: t, face: meTx < meX - 2 ? -1 : 1);
      c.restore();
      F.draw(c);
      c.restore();
      hud(c, W, score: coinN);
      c.fillStyle = 'rgba(0,0,0,.28)';
      roundRect(c, W / 2 - 80, 10, 160, 44, 22);
      c.fill();
      c.fillStyle = '#fff';
      c.textAlign = 'center';
      c.font = '800 26px';
      c.fillText('⬆ $best/$need m', W / 2, 42);
      if (t < 2) levelBanner(c, W, H, lv, tr('Lên cao $need mét', 'Climb $need meters'), tr('Kéo ngón tay sang trái, phải để đáp lên mây', 'Drag left and right to land on the clouds'), tr);
      if (end != null) banner(c, W, H, end!.win ? endText(true, lv, tr) : tr('RƠI MẤT RỒI!', 'YOU FELL!'), tr('$best/$need mét', '$best/$need meters'));
    },
  );
}
