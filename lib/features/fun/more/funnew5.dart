// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Bẻ ghi tàu hoả, xếp hàng lên xe, bong bóng số.
// CHỦ: agent F. Port của reference/web/js/games/funnew5.js. Mỗi lượt một cấp (ctx.level), 60 cấp.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:flutter/painting.dart' show Color;

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funnew5Games = {
  'trains': const FunCanvasModule('trains', trains),
  'truckload': const FunCanvasModule('truckload', truckload),
  'balloons': const FunCanvasModule('balloons', balloons),
};

// ---------- 11. Bẻ ghi tàu hoả: tàu mang cờ màu chạy từ trái sang, chạm vào chỗ rẽ để bẻ ghi, đưa tàu về ga cùng màu. ----------
const List<List<String>> _TCOL = [['flagR', '#fa5252'], ['flagB', '#339af0'], ['flagG', '#40c057'], ['flagY', '#fab005']];

/// Nút cây rẽ nhánh: chỗ bẻ ghi {x, y, kids:[a,b], sw:0|1} hoặc lá (ga) {station:i}.
class _TNode {
  _TNode.j(this.x, _TNode a, _TNode b)
      : y = 0,
        kids = [a, b],
        station = null;
  _TNode.leaf(int i, this.x, this.y)
      : kids = null,
        station = i;
  double x, y;
  final List<_TNode>? kids;
  final int? station;
  int sw = 0;
}

class _Train {
  _Train(this.c, this.node, this.pts, this.x, this.y);
  final int c;
  _TNode node;
  List<List<double>> pts;
  int i = 0;
  double x, y, ang = 0, gone = 0;
}

Future<LoopGame> trains(Fun g) async {
  final lv = g.level, th = theme(lv), need = ramp(lv, 6, 20).round(), kid = kidOf(g.hero), tr = g.tr;
  final nSt = lv < 10 ? 2 : (lv < 30 ? 3 : 4);
  final (SH, _) = await (playSheets([kid, 'items']), loadAll(['Locomotive', 'House', 'Red heart', 'Coin', 'Deciduous tree', 'Evergreen tree'])).wait;
  final ctx = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final top = W < 640 ? 130.0 : 90.0, y0 = top + 40, y1 = H - 40;
  final xs = W * .1, xe = W - math.min(110, W * .17);
  final leafY = List.generate(nSt, (i) => y0 + (y1 - y0) * (i + .5) / nSt);
  _TNode J(double x, _TNode a, _TNode b) => _TNode.j(x, a, b);
  _TNode Lf(int i) => _TNode.leaf(i, xe, leafY[i]);
  final _TNode root;
  if (nSt == 2) {
    root = J(W * .42, Lf(0), Lf(1));
  } else if (nSt == 3) {
    root = J(W * .32, Lf(0), J(W * .58, Lf(1), Lf(2)));
  } else {
    root = J(W * .3, J(W * .58, Lf(0), Lf(1)), J(W * .58, Lf(2), Lf(3)));
  }
  double fixY(_TNode n) {
    final k = n.kids;
    if (k != null) {
      k.forEach(fixY);
      n.y = (k[0].y + k[1].y) / 2;
    }
    return n.y;
  }

  fixY(root);
  final juncs = <_TNode>[];
  void walkJ(_TNode n) {
    if (n.kids != null) {
      juncs.add(n);
      n.kids!.forEach(walkJ);
    }
  }

  walkJ(root);
  // Đường đi từ điểm a tới b: ngang rồi chéo rồi ngang.
  List<List<double>> seg(_TNode a, _TNode b) {
    final mx = a.x + (b.x - a.x) * .25, nx = a.x + (b.x - a.x) * .7;
    return [[a.x, a.y], [mx, a.y], [nx, b.y], [b.x, b.y]];
  }

  final colors = shuffleInPlace(List.of(_TCOL)).sublist(0, nSt);
  final speed = S * ramp(lv, .2, .36), every = ramp(lv, 5.5, 2.4);
  final trainsA = <_Train>[];
  var done = 0, lives = 3;
  double t = 0, endT = 0, spawn = 1.2;
  FunEnd? end;
  final startX = xs - 60, startY = root.y;
  void newTrain() => trainsA.add(_Train(rnd.nextInt(nSt), root, [[startX, startY], [root.x, root.y]], startX, startY));
  g.taps(onTap: (x, y) {
    if (t < 2 || end != null) return;
    for (final j in juncs) {
      if (hypot(j.x - x, j.y - y) < S * .09) {
        j.sw ^= 1;
        g.sfx('flip');
        return;
      }
    }
  });
  void arrive(_Train tn) {
    final n = tn.node;
    if (n.station != null) {
      tn.gone = 1;
      if (n.station == tn.c) {
        done++;
        g.sfx('correct');
        F.burst(n.x, n.y, 18, [colors[tn.c][1], '#fff']);
        F.text(n.x - 40, n.y - 40, '$done/$need', '#ffd43b');
        if (done >= need) {
          end = FunEnd(win: true, score: done * 8 + lives * 5);
          g.sfx('win');
        }
      } else {
        lives--;
        g.sfx('wrong');
        F.text(n.x - 40, n.y - 40, tr('Sai ga!', 'Wrong station!'), '#ff8787');
        if (lives <= 0) end = FunEnd(win: false, score: done * 8);
      }
      return;
    }
    final next = n.kids![n.sw];
    tn.pts = seg(n, next);
    tn.i = 0;
    tn.node = next;
  }

  void rail(List<List<double>> pts) {
    void path() {
      ctx.beginPath();
      ctx.moveTo(pts[0][0], pts[0][1]);
      for (final p in pts.skip(1)) {
        ctx.lineTo(p[0], p[1]);
      }
    }

    ctx.strokeStyle = 'rgba(206,212,218,.85)';
    ctx.lineWidth = 26;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    path();
    ctx.stroke();
    ctx.strokeStyle = '#5c3d2e';
    ctx.lineWidth = 18;
    ctx.lineCap = 'butt';
    ctx.setLineDash([6, 10]);
    path();
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.strokeStyle = '#495057';
    ctx.lineWidth = 5;
    path();
    ctx.stroke();
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      spawn -= dt;
      if (spawn <= 0) {
        spawn = every * rand(.9, 1.15);
        newTrain();
      }
      for (var k = trainsA.length - 1; k >= 0; k--) {
        final tn = trainsA[k];
        if (tn.gone > 0) {
          tn.gone += dt;
          if (tn.gone > 1.2) trainsA.removeAt(k);
          continue;
        }
        var mv = speed * dt;
        while (mv > 0 && tn.gone == 0) {
          final b = tn.pts[tn.i + 1], bx = b[0], by = b[1], dx = bx - tn.x, dy = by - tn.y, d = hypot(dx, dy);
          if (d > .01) tn.ang = math.atan2(dy, dx);
          if (d <= mv) {
            tn.x = bx;
            tn.y = by;
            mv -= d;
            tn.i++;
            if (tn.i >= tn.pts.length - 1) arrive(tn);
          } else {
            tn.x += dx / d * mv;
            tn.y += dy / d * mv;
            mv = 0;
          }
        }
      }
      if (bot) {
        for (final tn in trainsA) {
          if (tn.gone == 0 && tn.node.kids != null) {
            // tìm nhánh dẫn tới ga đúng màu
            bool has(_TNode n) => n.station != null ? n.station == tn.c : has(n.kids![0]) || has(n.kids![1]);
            tn.node.sw = has(tn.node.kids![0]) ? 0 : 1;
          }
        }
      }
      return null;
    },
    draw: () {
      skyFill(ctx, W, H, th);
      ctx.fillStyle = hex(th.ground);
      ctx.fillRect(0, y0 - 30, W, H - y0 + 30);
      for (var i = 0; i < 5; i++) {
        drawO(ctx, i.isOdd ? 'Evergreen tree' : 'Deciduous tree', W * (.3 + i * .12), y0 - 10, S * .07, alpha: .7);
      }
      // Đường ray
      rail([[0, root.y], [root.x, root.y]]);
      void walkR(_TNode n) {
        for (final ch in n.kids ?? const <_TNode>[]) {
          rail(seg(n, ch));
          walkR(ch);
        }
      }

      walkR(root);
      // Ga: nhà + cờ màu
      void walkS(_TNode n) {
        if (n.kids != null) {
          n.kids!.forEach(walkS);
          return;
        }
        final fk = colors[n.station!][0], col = colors[n.station!][1];
        ctx.fillStyle = col;
        roundRect(ctx, n.x - 8, n.y - S * .06, W - n.x, S * .12, 14);
        ctx.fill();
        draw(ctx, 'House', n.x + S * .06, n.y - S * .01, S * .1);
        drawAnimC(ctx, SH['items'], fk, t, n.x + S * .03, n.y - S * .075, S * .07);
      }

      walkS(root);
      // Chỗ bẻ ghi: vòng tròn + mũi tên chỉ nhánh đang mở
      for (final j in juncs) {
        final ch = j.kids![j.sw], a = math.atan2(ch.y - j.y, (ch.x - j.x) * .45);
        ctx.fillStyle = 'rgba(255,255,255,.9)';
        ctx.beginPath();
        ctx.arc(j.x, j.y, S * .05, 0, 7);
        ctx.fill();
        ctx.strokeStyle = '#212529';
        ctx.lineWidth = 3;
        ctx.stroke();
        ctx.save();
        ctx.translate(j.x, j.y);
        ctx.rotate(a);
        ctx.fillStyle = '#e8590c';
        ctx.beginPath();
        ctx.moveTo(S * .035, 0);
        ctx.lineTo(-S * .015, -S * .022);
        ctx.lineTo(-S * .015, S * .022);
        ctx.fill();
        ctx.fillRect(-S * .03, -S * .008, S * .03, S * .016);
        ctx.restore();
      }
      for (final tn in trainsA) {
        final a = tn.gone > 0 ? math.max(0.0, 1 - tn.gone) : 1.0, s = S * .11;
        drawO(ctx, 'Locomotive', tn.x, tn.y - s * .3, s, h: s, flip: true, rot: tn.ang * .8, alpha: a);
        drawAnimC(ctx, SH['items'], colors[tn.c][0], t, tn.x - s * .1, tn.y - s * .9, s * .5, alpha: a);
      }
      final kh = math.min(S * .24, 190.0);
      shadow(ctx, W * .1, root.y - 12, kh * .45);
      drawAnimC(ctx, SH[kid], end?.win == true ? 'cheer' : 'work', t, W * .1, root.y - 12, kh);
      F.draw(ctx);
      hud(ctx, W, score: done, lives: 0, time: null);
      hearts(ctx, W, lives);
      goalPill(ctx, W, done, need);
      if (t < 2) {
        levelBanner(ctx, W, H, lv, tr('Đưa $need tàu về đúng ga', 'Bring $need trains to the right station'),
            tr('Chạm vòng tròn để bẻ ghi · Tàu cờ màu nào về ga màu đó', 'Tap the circles to switch tracks · Each train goes to its flag color'), tr);
      }
      if (end != null) {
        banner(ctx, W, H, end!.win ? endText(true, lv, tr) : tr('TÀU ĐI LẠC RỒI!', 'TRAINS GOT LOST!'), tr('$done/$need tàu', '$done/$need trains'));
      }
    },
  );
}

// ---------- 12. Xếp hàng lên xe tải: kéo các khối hàng vào thùng xe cho kín chỗ, xe chạy đi giao hàng. ----------
const List<String> _CARGO = ['Package', 'Wrapped gift', 'Watermelon', 'Pineapple', 'Teddy bear', 'Soccer ball', 'Basket', 'Books', 'Potted plant', 'Red apple', 'Basketball', 'Guitar'];
const List<String> _PCOL = ['#ffd8a8', '#d0ebff', '#d3f9d8', '#ffe3e3', '#f3d9fa', '#fff3bf', '#c5f6fa', '#e9ecef'];

class _Piece {
  _Piece(this.cells, this.w, this.h, this.home);
  final List<(int, int)> cells;
  final int w, h;
  final (int, int) home;
  String img = '';
  String col = '';
  (int, int)? placed;
  double tx = 0, ty = 0;
}

/// Chia lưới thành các khối liền nhau (luôn xếp kín được).
List<_Piece> _partition(int cols, int rows, int maxSz) {
  final id = List.generate(rows, (_) => List.filled(cols, -1));
  final pieces = <_Piece>[];
  final cells = shuffleInPlace(List.generate(cols * rows, (i) => (i % cols, i ~/ cols)));
  for (final (c, r) in cells) {
    if (id[r][c] >= 0) continue;
    final k = pieces.length, want = 1 + rnd.nextInt(maxSz);
    final pc = <(int, int)>[(c, r)];
    id[r][c] = k;
    while (pc.length < want) {
      final opts = <(int, int)>[];
      for (final (x, y) in pc) {
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = x + dx, ny = y + dy;
          if (nx >= 0 && ny >= 0 && nx < cols && ny < rows && id[ny][nx] < 0) opts.add((nx, ny));
        }
      }
      if (opts.isEmpty) break;
      final (nx, ny) = pick(opts);
      id[ny][nx] = k;
      pc.add((nx, ny));
    }
    final mx = pc.map((p) => p.$1).reduce(math.min), my = pc.map((p) => p.$2).reduce(math.min);
    pieces.add(_Piece([for (final (x, y) in pc) (x - mx, y - my)], pc.map((p) => p.$1).reduce(math.max) - mx + 1,
        pc.map((p) => p.$2).reduce(math.max) - my + 1, (mx, my)));
  }
  return pieces;
}

class _Drag {
  _Drag(this.p, this.ox, this.oy, this.x, this.y);
  final _Piece p;
  final double ox, oy;
  double x, y;
}

Future<LoopGame> truckload(Fun g) async {
  final lv = g.level, kid = kidOf(g.hero), tr = g.tr;
  final cols = math.min(7, 3 + lv ~/ 12), rows = lv < 8 ? 2 : (lv < 30 ? 3 : 4), maxSz = lv < 5 ? 2 : (lv < 25 ? 3 : 4);
  final needTrucks = lv < 10 ? 2 : 3;
  final (SH, _) = await (playSheets([kid, 'items']), loadAll([..._CARGO, 'Delivery truck', 'Coin', 'Factory', 'Deciduous tree'])).wait;
  final ctx = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final top = W < 640 ? 112.0 : 70.0;
  final trayTop = H * .56;
  final cs = math.min(math.min((W * .66) / cols, (trayTop - top - 70) / rows), 96.0);
  final bedX = W * .08, bedY = trayTop - 40 - cs * rows, bedW = cs * cols, bedH = cs * rows;
  var pieces = <_Piece>[];
  var grid = <List<bool>>[];
  var trucks = 0;
  double t = 0, endT = 0, leave = 0, arrive = 1, botT = 0;
  FunEnd? end;
  _Drag? drag;
  double time = (ramp(lv, 75, 100) * needTrucks / 2).roundToDouble();
  final ts = math.min(math.min(cs, 84.0), (W - 64) / 6), kh = math.min(S * .24, 170.0);
  void layoutTray() {
    // Xếp khay: các khối chưa đặt, theo hàng
    double x = 16, y = trayTop + 16, rowH = 0;
    for (final p in pieces) {
      if (p.placed != null) continue;
      final pw = p.w * ts, phh = p.h * ts;
      if (x + pw > W - 16 - kh * .7) {
        x = 16;
        y += rowH + 14;
        rowH = 0;
      }
      p.tx = x;
      p.ty = y;
      x += pw + 16;
      rowH = math.max(rowH, phh);
    }
  }

  void newLoad() {
    pieces = shuffleInPlace(_partition(cols, rows, maxSz));
    for (var i = 0; i < pieces.length; i++) {
      pieces[i]
        ..img = _CARGO[i % _CARGO.length]
        ..col = _PCOL[i % _PCOL.length];
    }
    grid = List.generate(rows, (_) => List.filled(cols, false));
    layoutTray();
  }

  newLoad();
  bool fits(_Piece p, int gx, int gy) =>
      p.cells.every((c) => gx + c.$1 >= 0 && gy + c.$2 >= 0 && gx + c.$1 < cols && gy + c.$2 < rows && !grid[gy + c.$2][gx + c.$1]);
  void place(_Piece p, int gx, int gy) {
    p.placed = (gx, gy);
    for (final (x, y) in p.cells) {
      grid[gy + y][gx + x] = true;
    }
    g.sfx('pop');
    layoutTray();
    if (grid.every((r) => r.every((v) => v))) {
      trucks++;
      leave = .001;
      g.sfx('correct');
      F.burst(bedX + bedW / 2, bedY, 24);
      F.text(bedX + bedW / 2, bedY - 30, '$trucks/$needTrucks', '#ffd43b');
    }
  }

  _Piece? pieceAt(double x, double y) {
    for (final p in pieces.reversed) {
      if (p.placed == null &&
          p.cells.any((c) => x >= p.tx + c.$1 * ts && x <= p.tx + (c.$1 + 1) * ts && y >= p.ty + c.$2 * ts && y <= p.ty + (c.$2 + 1) * ts)) {
        return p;
      }
    }
    return null;
  }

  int gridX(_Drag d) => ((d.x - d.ox - bedX) / cs).round();
  int gridY(_Drag d) => ((d.y - d.oy - bedY) / cs).round();
  g.taps(
    onDownXY: (x, y) {
      if (t < 2 || end != null || leave > 0 || arrive > 0) return;
      final p = pieceAt(x, y);
      if (p != null) {
        drag = _Drag(p, (x - p.tx) / ts * cs, (y - p.ty) / ts * cs, x, y);
        g.sfx('tap');
      }
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
      final p = d.p, gx = gridX(d), gy = gridY(d);
      drag = null;
      if (fits(p, gx, gy)) {
        place(p, gx, gy);
      } else {
        g.sfx('wrong');
      }
    },
  );
  void cell(double x, double y, double s, _Piece p) {
    ctx.fillStyle = p.col;
    roundRect(ctx, x + 2, y + 2, s - 4, s - 4, 8);
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,.2)';
    ctx.lineWidth = 2;
    ctx.stroke();
    draw(ctx, p.img, x + s / 2, y + s / 2, s * .72);
  }

  void drawPiece(double x, double y, double s, _Piece p) {
    for (final (cx, cy) in p.cells) {
      cell(x + cx * s, y + cy * s, s, p);
    }
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      F.update(dt);
      if (end != null) {
        endT += dt;
        return endT > 2 ? end : null;
      }
      if (t < 2) return null;
      if (arrive > 0) {
        arrive = math.max(0, arrive - dt * 1.4);
        return null;
      }
      if (leave > 0) {
        leave += dt;
        if (leave > 1.3) {
          leave = 0;
          if (trucks >= needTrucks) {
            end = FunEnd(win: true, score: trucks * 20 + time.round());
            g.sfx('win');
          } else {
            newLoad();
            arrive = 1;
          }
        }
        return null;
      }
      time -= dt;
      if (bot && (botT += dt) > .4) {
        botT = 0;
        final p = pieces.where((p) => p.placed == null).firstOrNull;
        if (p != null && fits(p, p.home.$1, p.home.$2)) place(p, p.home.$1, p.home.$2);
      }
      if (time <= 0 && end == null) {
        time = 0;
        end = FunEnd(win: false, score: trucks * 20);
        g.sfx('wrong');
      }
      return null;
    },
    draw: () {
      final gr = ctx.createLinearGradient(0, 0, 0, trayTop);
      gr.addColorStop(0, const Color(0xFFA5D8FF));
      gr.addColorStop(1, const Color(0xFFE7F5FF));
      ctx.fillStyle = gr;
      ctx.fillRect(0, 0, W, trayTop);
      draw(ctx, 'Factory', W * .86, bedY - 10, S * .2);
      draw(ctx, 'Deciduous tree', W * .66, bedY + 10, S * .14);
      ctx.fillStyle = '#868e96';
      ctx.fillRect(0, bedY + bedH + cs * .35, W, trayTop - bedY - bedH - cs * .35);
      // Xe tải: thùng (lưới) + đầu xe hình Fluent, chạy vào/ra
      final off = leave > 0 ? math.pow(leave / 1.3, 2) * W : (arrive > 0 ? -arrive * W : 0.0);
      final bx = bedX + off;
      ctx.fillStyle = '#5c3d2e';
      roundRect(ctx, bx - 8, bedY - 8, bedW + 16, bedH + 22, 10);
      ctx.fill();
      ctx.fillStyle = '#8d5524';
      ctx.fillRect(bx, bedY, bedW, bedH);
      ctx.strokeStyle = 'rgba(255,255,255,.18)';
      ctx.lineWidth = 2;
      for (var c = 0; c <= cols; c++) {
        ctx.beginPath();
        ctx.moveTo(bx + c * cs, bedY);
        ctx.lineTo(bx + c * cs, bedY + bedH);
        ctx.stroke();
      }
      for (var r = 0; r <= rows; r++) {
        ctx.beginPath();
        ctx.moveTo(bx, bedY + r * cs);
        ctx.lineTo(bx + bedW, bedY + r * cs);
        ctx.stroke();
      }
      final tk = math.min(math.max(cs * 1.6, bedH * .9), (W - bedX - bedW - 6) / .92);
      drawO(ctx, 'Delivery truck', bx + bedW + tk * .42, bedY + bedH + 14 - tk * .4, tk, h: tk * .85, flip: true);
      for (final wx in [bx + cs * .6, bx + bedW - cs * .6]) {
        ctx.fillStyle = '#212529';
        ctx.beginPath();
        ctx.arc(wx, bedY + bedH + 16, cs * .3, 0, 7);
        ctx.fill();
        ctx.fillStyle = '#adb5bd';
        ctx.beginPath();
        ctx.arc(wx, bedY + bedH + 16, cs * .12, 0, 7);
        ctx.fill();
      }
      for (final p in pieces) {
        final pl = p.placed;
        if (pl != null) drawPiece(bx + pl.$1 * cs, bedY + pl.$2 * cs, cs, p);
      }
      // Bóng xem trước chỗ thả
      final d = drag;
      if (d != null) {
        final gx = gridX(d), gy = gridY(d), ok = fits(d.p, gx, gy);
        ctx.fillStyle = ok ? 'rgba(64,192,87,.45)' : 'rgba(250,82,82,.3)';
        for (final (cx, cy) in d.p.cells) {
          final x = bedX + (gx + cx) * cs, y = bedY + (gy + cy) * cs;
          if (gx + cx >= 0 && gy + cy >= 0 && gx + cx < cols && gy + cy < rows) ctx.fillRect(x + 2, y + 2, cs - 4, cs - 4);
        }
      }
      ctx.fillStyle = '#e9ecef';
      ctx.fillRect(0, trayTop, W, H - trayTop);
      ctx.fillStyle = '#ced4da';
      ctx.fillRect(0, trayTop, W, 6);
      for (final p in pieces) {
        if (p.placed == null && (d == null || d.p != p)) drawPiece(p.tx, p.ty, ts, p);
      }
      drawAnimC(ctx, SH[kid], end?.win == true || leave > 0 ? 'cheer' : (d != null ? 'hold' : 'idle'), t, W - kh * .4, H - 6, kh);
      if (d != null) drawPiece(d.x - d.ox, d.y - d.oy, cs, d.p);
      F.draw(ctx);
      hud(ctx, W, score: trucks, lives: 0, time: time);
      goalPill(ctx, W, trucks, needTrucks);
      if (t < 2) {
        levelBanner(ctx, W, H, lv, tr('Xếp kín $needTrucks xe tải', 'Fill $needTrucks trucks'),
            tr('Kéo khối hàng thả vào thùng xe cho kín chỗ', 'Drag the cargo into the truck until it is full'), tr);
      }
      if (end != null) {
        banner(ctx, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT GIỜ!', 'TIME\'S UP!'), tr('$trucks/$needTrucks xe', '$trucks/$needTrucks trucks'));
      }
    },
  );
}

// ---------- 13. Bong bóng số: bóng bay mang số bay lên, chạm vỡ theo thứ tự 1, 2, 3... (cấp cao đếm cách 2, 5, 10
// hoặc đếm lùi). Ong và bọ rùa bay ngang, chạm nhầm thì mất tim. Bé đứng dưới vỗ tay. ----------
class _Up {
  _Up(this.n, this.x, this.y, this.c, this.ph, this.v);
  final int n;
  double x, y, ph, pop = 0, shake = 0;
  final String c;
  final double v;
}

class _Bug {
  _Bug(this.k, this.x, this.y, this.vx);
  final String k;
  double x;
  final double y, vx;
}

Future<LoopGame> balloons(Fun g) async {
  final lv = g.level, th = theme(lv), kid = kidOf(g.hero), tr = g.tr;
  final (int a, int d) mode = lv < 15 ? (1, 1) : (lv < 30 ? (2, 2) : (lv < 45 ? (5, 5) : (20, -1)));
  final ma = mode.$1, md = mode.$2;
  final len = math.min(lv < 15 ? 5 + lv ~/ 3 : 10, md < 0 ? 20 : 10);
  final seq = List.generate(len, (i) => md < 0 ? ma - i : ma + i * md);
  final (SH, _) = await (playSheets([kid, 'critters']), loadAll(['Balloon', 'Red heart', 'Coin', 'Cloud', th.sun])).wait;
  final ctx = g.c, W = g.W, H = g.H;
  final S = math.min(W, H), F = fx(), bot = g.bot;
  final bs = S * ramp(lv, .15, .11), ground = H * .92;
  const HUES = ['#ff6b6b', '#4dabf7', '#51cf66', '#fcc419', '#cc5de8', '#ff922b'];
  final ups = <_Up>[], bugs = <_Bug>[];
  var idx = 0, lives = 3;
  double t = 0, endT = 0, spawn = 0, cheer = 0, botT = 0;
  FunEnd? end;
  final H0 = [H * .35, H * .55, H * .75];
  int pool() {
    // số đang cần luôn có mặt; thêm số nhiễu trong dãy
    final want = seq[idx];
    final on = ups.where((u) => u.pop == 0);
    if (!on.any((u) => u.n == want)) return want;
    final later = seq.sublist(idx + 1, math.min(seq.length, idx + 4));
    return later.isNotEmpty && random() < .7 ? pick(later) : want + pick(const [1, -1, 3]) * math.max(1, md.abs());
  }

  final vy = S * ramp(lv, .1, .2);
  void onTap(double x, double y) {
    if (t < 2 || end != null) return;
    for (final b in bugs) {
      if (hypot(b.x - x, b.y - y) < S * .06) {
        lives--;
        g.sfx('hit');
        F.text(x, y, tr('Ối!', 'Oops!'), '#ff8787');
        if (lives <= 0) end = FunEnd(win: false, score: idx * 5);
        return;
      }
    }
    final u = ups.where((u) => u.pop == 0 && hypot(u.x - x, u.y - y) < bs * .55).firstOrNull;
    if (u == null) return;
    if (u.n == seq[idx]) {
      u.pop = .001;
      idx++;
      cheer = .8;
      g.sfx('pop');
      F.burst(u.x, u.y, 16, [u.c, '#fff']);
      if (idx >= seq.length) {
        end = FunEnd(win: true, score: idx * 5 + lives * 5);
        g.sfx('win');
      }
    } else {
      lives--;
      g.sfx('wrong');
      u.shake = .4;
      F.text(u.x, u.y - bs * .6, tr('Tìm số ${seq[idx]}', 'Find ${seq[idx]}'), '#fff');
      if (lives <= 0) end = FunEnd(win: false, score: idx * 5);
    }
  }

  g.taps(onTap: onTap);
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
      spawn -= dt;
      if (spawn <= 0 && ups.where((u) => u.pop == 0).length < ramp(lv, 4, 7).round()) {
        spawn = rand(.6, 1.1);
        ups.add(_Up(pool(), rand(bs, W - bs), H0.isNotEmpty ? H0.removeLast() : H + bs, pick(HUES), rand(0, 6), vy * rand(.85, 1.2)));
      }
      for (var i = ups.length - 1; i >= 0; i--) {
        final u = ups[i];
        u.ph += dt;
        u.shake = math.max(0, u.shake - dt);
        if (u.pop > 0) {
          u.pop += dt;
          if (u.pop > .3) ups.removeAt(i);
          continue;
        }
        u.y -= u.v * dt;
        u.x += math.sin(u.ph * 1.3) * 18 * dt;
        if (u.y < -bs) {
          ups.removeAt(i);
          // Từ cấp 6: để bóng đang cần bay mất thì mất một tim.
          if (lv >= 5 && u.n == seq[idx] && !ups.any((o) => o.pop == 0 && o.n == u.n)) {
            lives--;
            g.sfx('wrong');
            F.text(W / 2, 90, tr('Bóng bay mất rồi!', 'It flew away!'), '#fff');
            if (lives <= 0) {
              end = FunEnd(win: false, score: idx * 5);
              return null;
            }
          }
        }
      }
      if (lv >= 8 && random() < dt * ramp(lv, .15, .45) && bugs.length < 3) {
        final l = random() < .5;
        bugs.add(_Bug(pick(const ['bee', 'ladyfly']), l ? -40 : W + 40, rand(H * .25, H * .7), (l ? 1 : -1) * S * rand(.2, .35)));
      }
      for (var i = bugs.length - 1; i >= 0; i--) {
        final b = bugs[i];
        b.x += b.vx * dt;
        if (b.x < -60 || b.x > W + 60) bugs.removeAt(i);
      }
      if (bot && (botT += dt) > .5) {
        botT = 0;
        final u = ups.where((u) => u.pop == 0 && u.n == seq[idx] && u.y < H - bs).firstOrNull;
        if (u != null) onTap(u.x, u.y); // web: giả lập pointerdown/pointerup tại quả bóng
      }
      return null;
    },
    draw: () {
      skyFill(ctx, W, H, th);
      draw(ctx, th.sun, W * .86, H * .14, S * .12);
      drawO(ctx, 'Cloud', (t * 12) % (W + 200) - 100, H * .2, S * .2, h: S * .12, alpha: .8);
      ctx.fillStyle = hex(th.ground);
      ctx.fillRect(0, ground, W, H - ground);
      ctx.fillStyle = hex(th.edge);
      ctx.fillRect(0, ground, W, 6);
      for (final u in ups) {
        final sx = u.shake > 0 ? math.sin(u.shake * 60) * 6 : 0.0, k = u.pop > 0 ? 1 + u.pop * 3 : 1.0, a = u.pop > 0 ? 1 - u.pop / .3 : 1.0;
        ctx.strokeStyle = 'rgba(0,0,0,.35)';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(u.x + sx, u.y + bs * .48);
        ctx.quadraticCurveTo(u.x + sx + math.sin(u.ph * 2) * 10, u.y + bs * .8, u.x + sx, u.y + bs * 1.1);
        ctx.stroke();
        drawO(ctx, 'Balloon', u.x + sx, u.y, bs * k, h: bs * 1.1 * k, alpha: math.max(0, a));
        if (u.pop == 0) {
          ctx.font = '800 ${(bs * .36).round()}px';
          ctx.textAlign = 'center';
          ctx.lineWidth = 6;
          ctx.strokeStyle = 'rgba(0,0,0,.45)';
          ctx.strokeText('${u.n}', u.x + sx, u.y + bs * .03);
          ctx.fillStyle = '#fff';
          ctx.fillText('${u.n}', u.x + sx, u.y + bs * .03);
        }
      }
      for (final b in bugs) {
        drawAnimC(ctx, SH['critters'], b.k, t, b.x, b.y, S * .08, flip: b.vx > 0);
      }
      final kh = math.min(S * .22, H * .16);
      shadow(ctx, W * .5, ground + 4, kh * .5);
      drawAnimC(ctx, SH[kid], end?.win == true || cheer > 0 ? 'cheer' : 'idle', t, W * .5, ground + 4, kh);
      F.draw(ctx);
      hud(ctx, W, score: idx, lives: 0, time: null);
      hearts(ctx, W, lives);
      pill(ctx, W, end != null ? '✔ ${seq.length}/${seq.length}' : tr('🎈 Tìm số ${seq[idx]}', '🎈 Find ${seq[idx]}'), W < 640 ? 62 : 10, 200);
      // Dãy số đã chạm
      final dw = math.min(40.0, (W - 40) / seq.length), dy = W < 640 ? 112.0 : 60.0;
      for (var i = 0; i < seq.length; i++) {
        ctx.fillStyle = i < idx ? '#2f9e44' : 'rgba(0,0,0,.2)';
        roundRect(ctx, W / 2 - dw * seq.length / 2 + i * dw + 2, dy, dw - 4, 26, 8);
        ctx.fill();
        ctx.fillStyle = '#fff';
        ctx.font = '800 15px';
        ctx.textAlign = 'center';
        ctx.fillText(i < idx ? '${seq[i]}' : '?', W / 2 - dw * seq.length / 2 + i * dw + dw / 2, dy + 19);
      }
      if (t < 2) {
        levelBanner(
            ctx,
            W,
            H,
            lv,
            md < 0
                ? tr('Đếm lùi từ $ma', 'Count down from $ma')
                : md > 1
                    ? tr('Đếm cách $md: ${seq.take(3).join(', ')}...', 'Count by $md: ${seq.take(3).join(', ')}...')
                    : tr('Chạm bóng theo thứ tự 1 → ${seq.last}', 'Pop balloons in order 1 → ${seq.last}'),
            tr('Chạm đúng số bóng bay · Đừng chạm vào ong', 'Tap the right number · Don\'t tap the bees'),
            tr);
      }
      if (end != null) {
        banner(ctx, W, H, end!.win ? endText(true, lv, tr) : tr('HẾT TIM RỒI!', 'OUT OF HEARTS!'), tr('$idx/${seq.length} quả bóng', '$idx/${seq.length} balloons'));
      }
    },
  );
}
