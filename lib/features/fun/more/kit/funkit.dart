// Bộ khung game canvas cho Khu vui chơi 2 (agent F): bản port riêng của funcore.js + funfx.js + phần dùng chung
// của funnew1/funnew3 (dirInput, taps, pill, hearts, shadow, kidOf...). README của core cấm import helper của agent khác,
// nên đây là bản sao riêng (E có bản của mình ở fun/hub).
//
// Cách port một game web `export async function snake(box, opts) {... return loop({update, draw}, opts.alive)}`:
//   Future<LoopGame> snake(Fun g) async { ... await g.loadAll([...]); final c = g.c; ...
//     g.onDown((e) {...});  return LoopGame(update: (dt) {...; return null|FunEnd(...)}, draw: () {...}); }
// rồi `FunCanvasModule('snake', snake)`. g.W/g.H = kích thước canvas, c = Ctx2D (API giống CanvasRenderingContext2D).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/models.dart' show Json;
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/store/store.dart' show kFunMax;
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'canvas2d.dart';

export 'package:be_vui_hoc/core/ui/sprite_sheet.dart' show SpriteSheet;

export 'canvas2d.dart';

// ---------- Tiện ích số (funcore/funfx) ----------
final math.Random rnd = math.Random();
const double pi = math.pi;
const int lives0 = 5; // LIVES
double rand(double a, double b) => a + rnd.nextDouble() * (b - a);
T pick<T>(List<T> a) => a[rnd.nextInt(a.length)];
double random() => rnd.nextDouble();
double ramp(int lv, double a, double b) => a + (b - a) * math.min(1, math.max(0, lv) / (kFunMax - 1));
double clamp(double v, [double a = 0, double b = 1]) => v < a ? a : (v > b ? b : v);
double lerp(double a, double b, double k) => a + (b - a) * k;
double easeOut(double k) => 1 - (1 - k) * (1 - k) * (1 - k);
double easeIn(double k) => k * k * k;
double easeOutBack(double k) {
  const c = 1.70158;
  return 1 + (c + 1) * math.pow(k - 1, 3) + c * math.pow(k - 1, 2);
}

double easeOutElastic(double k) => k <= 0 ? 0 : k >= 1 ? 1 : math.pow(2, -10 * k) * math.sin((k * 10 - .75) * 2.094) + 1;
double approach(double v, double target, double rate, double dt) => target + (v - target) * math.exp(-rate * dt);
double popScale(double a) => a < .25 ? easeOutBack(a / .25) : 1;
double hypot(double x, double y) => math.sqrt(x * x + y * y);
double sin(double a) => math.sin(a);
double cos(double a) => math.cos(a);
double atan2(double y, double x) => math.atan2(y, x);
double sqrt(double v) => math.sqrt(v);
double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;
int floor(double v) => v.floor();

/// hit(a, b, s) của funcore: hai hộp tâm (x, y) rộng w cao h.
bool hitBox(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh, [double s = .7]) =>
    (ax - bx).abs() < (aw + bw) / 2 * s && (ay - by).abs() < (ah + bh) / 2 * s;

/// Xáo trộn tại chỗ.
List<T> shuffleInPlace<T>(List<T> a) {
  for (var i = a.length - 1; i > 0; i--) {
    final j = rnd.nextInt(i + 1);
    final t = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

// ---------- Cảnh theo cấp ----------
FunTheme theme(int lv) => funTheme(lv);
List<String> themeImgs(int lv) => funThemeImgs(lv);
String hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

// ---------- Hình emoji (imgCache) ----------
final Map<String, ui.Image> imgCache = {};

/// Thời gian chờ tối đa khi nạp hình (lỗi/chậm thì game vẫn chạy, hình thiếu bỏ qua như web).
Duration loadTimeout = const Duration(seconds: 4);

Future<void> loadAll(Iterable<String> names) async {
  final want = names.toSet().where((n) => !imgCache.containsKey(n)).toList();
  if (want.isEmpty) return;
  try {
    final m = await loadEmojiUiImages(want).timeout(loadTimeout);
    imgCache.addAll(m);
  } catch (_) {/* thiếu hình: bỏ qua */}
}

/// draw(ctx, name, x, y, w, h, {flip, rot, alpha}) của funcore.
void draw(Ctx2D c, String name, double x, double y, double w, [double? h, bool flip = false, double rot = 0, double alpha = 1]) {
  final im = imgCache[name];
  if (im == null) return;
  final hh = h ?? w;
  c.save();
  c.globalAlpha = alpha * c.globalAlpha;
  c.translate(x, y);
  if (rot != 0) c.rotate(rot);
  if (flip) c.scale(-1, 1);
  c.drawImage(im, -w / 2, -hh / 2, w, hh);
  c.restore();
}

/// Bí danh của draw (dùng trong lớp có hàm draw riêng).
void drawImg(Ctx2D c, String name, double x, double y, double w, [double? h, bool flip = false, double rot = 0, double alpha = 1]) =>
    draw(c, name, x, y, w, h, flip, rot, alpha);

/// Như draw nhưng tham số đặt tên (dễ đọc khi port {flip, rot, alpha}).
void drawO(Ctx2D c, String name, double x, double y, double w, {double? h, bool flip = false, double rot = 0, double alpha = 1}) =>
    draw(c, name, x, y, w, h, flip, rot, alpha);

// ---------- Sprite sheet (funfx) ----------
Future<SpriteSheet?> sheet(String name) async {
  try {
    return await loadSheet(name).timeout(loadTimeout);
  } catch (_) {
    return null;
  }
}

Future<List<SpriteSheet?>> sheets(List<String> names) => Future.wait(names.map(sheet));

/// sheets() của funnew3: tên trong gói play/ → map tên → sheet.
Future<Map<String, SpriteSheet?>> playSheets(List<String> names) async {
  final a = await sheets(names.map((n) => 'play/$n').toList());
  return {for (var i = 0; i < names.length; i++) names[i]: a[i]};
}

/// drawFrame của sheets.js (áp globalAlpha hiện tại).
void drawFrame(Ctx2D c, SpriteSheet? sh, String? frame, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1, double sy = 1}) {
  if (sh == null || frame == null) return;
  final f = sh.frames[frame];
  final im = sh.image;
  if (f == null || im == null) return;
  final sx = f[0], sy0 = f[1], sw = f[2], shh = f[3];
  final ox = f.length > 4 ? f[4] : 0.0, oy = f.length > 5 ? f[5] : 0.0;
  final fw = sh.size?.width ?? sw, fh = sh.size?.height ?? shh, k = h / fh;
  c.save();
  if (alpha != 1) c.globalAlpha *= alpha;
  c.translate(x, y);
  if (rot != 0) c.rotate(rot);
  if (flip) c.scale(-1, 1);
  if (sy != 1) c.scale(1, sy);
  c.drawImageRect(im, sx, sy0, sw, shh, (ox - fw * sh.anchor.dx) * k, (oy - fh * sh.anchor.dy) * k, sw * k, shh * k);
  c.restore();
}

String? frameOf(SpriteSheet? sh, String anim, double t) => sh == null || sh.frames.isEmpty ? null : frameAt(sh, anim, t);
void drawAnimC(Ctx2D c, SpriteSheet? sh, String anim, double t, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1, double sy = 1}) =>
    drawFrame(c, sh, frameOf(sh, anim, t), x, y, h, flip: flip, rot: rot, alpha: alpha, sy: sy);

/// spr / anim của funfx.
void spr(Ctx2D c, SpriteSheet? sh, String frame, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1}) =>
    drawFrame(c, sh, frame, x, y, h, flip: flip, rot: rot, alpha: alpha);
void anim(Ctx2D c, SpriteSheet? sh, String name, double t, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1}) =>
    drawAnimC(c, sh, name, t, x, y, h, flip: flip, rot: rot, alpha: alpha);

/// Vẽ khung theo bề rộng w.
void sprW(Ctx2D c, SpriteSheet? sh, String frame, double x, double y, double w, {bool flip = false, double rot = 0, double alpha = 1}) {
  final f = sh?.frames[frame];
  if (f == null) return;
  drawFrame(c, sh, frame, x, y, w * f[3] / f[2], flip: flip, rot: rot, alpha: alpha);
}

/// Vẽ khung kéo giãn đúng w×h, tâm (x, y).
void sprBox(Ctx2D c, SpriteSheet? sh, String? frame, double x, double y, double w, double h, [double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final ga = c.globalAlpha;
  if (alpha != 1) c.globalAlpha = ga * alpha;
  c.drawImageRect(im, f[0], f[1], f[2], f[3], x - w / 2, y - h / 2, w, h);
  c.globalAlpha = ga;
}

double aspect(SpriteSheet? sh, String frame) {
  final f = sh?.frames[frame];
  return f == null ? 1 : f[2] / f[3];
}

/// Dải ảnh lặp ngang (nền cuộn).
void stripX(Ctx2D c, SpriteSheet? sh, String frame, double off, double y, double h, double W, [double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final w = h * f[2] / f[3];
  var x = -(((off % w) + w) % w);
  final ga = c.globalAlpha;
  if (alpha != 1) c.globalAlpha = ga * alpha;
  for (; x < W; x += w - 1) {
    c.drawImageRect(im, f[0], f[1], f[2], f[3], x, y, w, h);
  }
  c.globalAlpha = ga;
}

/// Lát kín một vùng bằng ô vuông.
void tile(Ctx2D c, SpriteSheet? sh, String frame, double size, double offX, double offY, double x0, double y0, double W, double H) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final sx = -(((offX % size) + size) % size), sy = -(((offY % size) + size) % size);
  for (var y = y0 + sy; y < y0 + H; y += size - .5) {
    for (var x = x0 + sx; x < x0 + W; x += size - .5) {
      c.drawImageRect(im, f[0], f[1], f[2], f[3], x, y, size, size);
    }
  }
}

/// Dải ảnh lặp ngang, chỉ lấy phần dưới của khung từ tỉ lệ top.
void stripPart(Ctx2D c, SpriteSheet? sh, String frame, double off, double y, double h, double W, [double top = 0, double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final sy = f[1] + f[3] * top, sh2 = f[3] * (1 - top), w = h * f[2] / sh2;
  var x = -(((off % w) + w) % w);
  final ga = c.globalAlpha;
  if (alpha != 1) c.globalAlpha = ga * alpha;
  for (; x < W; x += w - 1) {
    c.drawImageRect(im, f[0], sy, f[2], sh2, x, y, w, h);
  }
  c.globalAlpha = ga;
}

const List<String> platBg = ['color_hills', 'color_desert', 'color_trees', 'color_trees', 'color_mushrooms', 'color_desert'];
const List<String> platGround = ['grass', 'sand', 'snow', 'stone', 'purple', 'dirt'];
const Map<String, String> _groundFill = {'grass': '#e0895a', 'sand': '#e0895a', 'snow': '#b9c0ca', 'stone': '#b6bcc6', 'purple': '#b9c0ca', 'dirt': '#b9c0ca'};

/// Mặt đất lát gạch Kenney.
void groundTiles(Ctx2D c, SpriteSheet? tiles, int lv, double off, double y, double W, double H, [double size = 64]) {
  final g = platGround[(lv ~/ 10) % platGround.length];
  stripX(c, tiles, 'terrain_${g}_block_top', off, y, size, W);
  if (y + size < H) stripX(c, tiles, 'terrain_${g}_block_center', off, y + size - 1, size, W);
  if (y + size * 2 < H && tiles != null) {
    c.fillStyle = _groundFill[g]!;
    c.fillRect(0, y + size * 2 - 2, W, H - y - size * 2 + 2);
  }
}

/// Đồi/cây xa phía sau mặt đất.
void backHills(Ctx2D c, SpriteSheet? bg, int lv, double off, double groundY, double h, double W, [double alpha = 1]) =>
    stripPart(c, bg, platBg[(lv ~/ 10) % platBg.length], off, groundY - h, h, W, .3, alpha);

/// Đồng xu xoay (fxa/fx khung 'coin').
void coin(Ctx2D c, SpriteSheet? fxs, double t, double x, double y, double s) {
  final f = fxs?.frames['coin'];
  final im = fxs?.image;
  if (f == null || im == null) return;
  final k = math.cos(t * 4), w = s * math.max(.18, k.abs());
  c.drawImageRect(im, f[0], f[1], f[2], f[3], x - w / 2, y - s / 2, w, s);
}

// ---------- Rung màn ----------
class Shaker {
  double _p = 0, _t = 0;
  void add(double k) => _p = math.min(18, _p + k);
  void update(double dt) {
    _t += dt;
    _p = math.max(0, _p - dt * (_p * 4 + 8));
  }

  void apply(Ctx2D c) {
    if (_p > .2) c.translate(math.sin(_t * 61) * _p, math.cos(_t * 47) * _p * .8);
  }

  double get power => _p;
}

Shaker shaker() => Shaker();

// ---------- Hạt bụi/khói/tia lửa ----------
class _Part {
  bool on = false;
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, r = 4, grow = 0, g = 0, a = 1;
  String c = '#fff';
  int k = 0;
}

class Dust {
  Dust([int n = 220]) : _p = List.generate(n, (_) => _Part());
  final List<_Part> _p;
  int _next = 0;
  void emit(double x, double y, double vx, double vy, {double life = .6, double r = 5, double grow = 20, String c = 'rgba(200,200,200,1)', int k = 0, double g = 0, double a = .7}) {
    final p = _p[_next];
    _next = (_next + 1) % _p.length;
    p
      ..on = true
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..life = life
      ..max = life
      ..r = r
      ..grow = grow
      ..c = c
      ..k = k
      ..g = g
      ..a = a;
  }

  void sparks(double x, double y, [int n = 12, String c = '#ffd43b', double sp = 260]) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 6.283, v = sp * (.4 + rnd.nextDouble() * .8);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .25 + rnd.nextDouble() * .3, r: 2.5, grow: 0, c: c, k: 1, a: 1);
    }
  }

  void puff(double x, double y, [int n = 6, String c = 'rgba(230,230,230,1)', double sp = 60, double r = 8]) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 6.283, v = sp * rnd.nextDouble();
      emit(x, y, math.cos(a) * v, math.sin(a) * v - 20, life: .5 + rnd.nextDouble() * .4, r: r * (.6 + rnd.nextDouble() * .6), grow: r * 3, c: c, a: .55);
    }
  }

  void debris(double x, double y, [int n = 10, String c = '#8d5524', double sp = 300]) {
    for (var i = 0; i < n; i++) {
      final a = -rnd.nextDouble() * 3.14, v = sp * (.4 + rnd.nextDouble() * .7);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .6 + rnd.nextDouble() * .4, r: 3 + rnd.nextDouble() * 3, grow: 0, c: c, k: 2, g: 900, a: 1);
    }
  }

  void update(double dt) {
    for (final p in _p) {
      if (!p.on) continue;
      p.life -= dt;
      if (p.life <= 0) {
        p.on = false;
        continue;
      }
      p.vy += p.g * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.k == 0) {
        p.vx *= 1 - dt * 2;
        p.vy *= 1 - dt * 2;
      }
    }
  }

  void draw(Ctx2D c, [double ox = 0, double oy = 0]) {
    final ga = c.globalAlpha;
    for (final p in _p) {
      if (!p.on) continue;
      final k = p.life / p.max;
      c.globalAlpha = ga * p.a * (p.k == 0 ? k : math.min(1, k * 2));
      c.fillStyle = p.c;
      if (p.k == 1) {
        c.strokeStyle = p.c;
        c.lineWidth = p.r;
        c.beginPath();
        c.moveTo(p.x - ox, p.y - oy);
        c.lineTo(p.x - ox - p.vx * .04, p.y - oy - p.vy * .04);
        c.stroke();
      } else {
        c.beginPath();
        c.arc(p.x - ox, p.y - oy, p.r + p.grow * (1 - k), 0, 6.283);
        c.fill();
      }
    }
    c.globalAlpha = ga;
  }

  void clear() {
    for (final p in _p) {
      p.on = false;
    }
  }
}

Dust dust([int n = 220]) => Dust(n);

/// Nổ bằng sprite (fxa/fx: boom, smoke).
class Booms {
  Booms(this.fxs, [int n = 24]) : _b = List.generate(n, (_) => _Boom());
  final SpriteSheet? fxs;
  final List<_Boom> _b;
  int _next = 0;
  void add(double x, double y, [double s = 90, String k = 'boom']) {
    final b = _b[_next];
    _next = (_next + 1) % _b.length;
    b
      ..on = true
      ..x = x
      ..y = y
      ..s = s
      ..t = 0
      ..k = k
      ..rot = rnd.nextDouble() * 6.28;
  }

  void update(double dt) {
    for (final b in _b) {
      if (b.on) {
        b.t += dt;
        if (b.t > .36) b.on = false;
      }
    }
  }

  void draw(Ctx2D c, [double ox = 0, double oy = 0]) {
    for (final b in _b) {
      if (!b.on) continue;
      final k = b.t / .36;
      anim(c, fxs, b.k, b.t, b.x - ox, b.y - oy, b.s * (.7 + easeOut(math.min(1, k * 1.6)) * .5), rot: b.rot, alpha: k > .7 ? (1 - k) / .3 : 1);
    }
  }
}

class _Boom {
  bool on = false;
  double x = 0, y = 0, s = 0, t = 0, rot = 0;
  String k = 'boom';
}

Booms booms(SpriteSheet? fxs, [int n = 24]) => Booms(fxs, n);

// ---------- Hạt lấp lánh + chữ bay (fx của funcore) ----------
class _Fx {
  _Fx(this.x, this.y, this.vx, this.vy, this.life, {this.c = '#fff', this.r = 0, this.text, this.star = false});
  double x, y, vx, vy, life;
  final String c;
  final double r;
  final String? text;
  final bool star;
}

class Fx {
  final List<_Fx> _parts = [];
  static const _colors = ['#ffd43b', '#ff922b', '#ff6b6b', '#74c0fc', '#b197fc'];
  void burst(double x, double y, [int n = 14, List<String> colors = _colors]) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2, v = rand(120, 320);
      _parts.add(_Fx(x, y, math.cos(a) * v, math.sin(a) * v, rand(.4, .8), c: pick(colors), r: rand(3, 7)));
    }
  }

  void text(double x, double y, String s, [String c = '#fff']) => _parts.add(_Fx(x, y, 0, -70, .9, text: s, c: c));
  void star(double x, double y) => _parts.add(_Fx(x, y, rand(-40, 40), -160, .9, star: true));
  void update(double dt) {
    for (var i = _parts.length - 1; i >= 0; i--) {
      final p = _parts[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += (p.text != null || p.star ? 0 : 300) * dt;
      p.life -= dt;
      if (p.life <= 0) _parts.removeAt(i);
    }
  }

  void draw(Ctx2D c) {
    for (final p in _parts) {
      c.globalAlpha = math.max(0, math.min(1, p.life * 1.6));
      if (p.text != null) {
        c.fillStyle = p.c;
        c.font = '800 26px';
        c.textAlign = 'center';
        c.strokeStyle = 'rgba(0,0,0,.35)';
        c.lineWidth = 4;
        c.strokeText(p.text!, p.x, p.y);
        c.fillText(p.text!, p.x, p.y);
      } else if (p.star) {
        drawImg(c, 'Glowing star', p.x, p.y, 34);
      } else {
        c.fillStyle = p.c;
        c.beginPath();
        c.arc(p.x, p.y, p.r, 0, 7);
        c.fill();
      }
    }
    c.globalAlpha = 1;
  }
}

Fx fx() => Fx();

// ---------- HUD ----------
void roundRect(Ctx2D c, double x, double y, double w, double h, double r) => c.roundRectPath(x, y, w, h, r);

/// hud(ctx, W, {score, lives, time, boss}).
void hud(Ctx2D c, double W, {required num score, int lives = 0, double? time, double? bossHp, double? bossMax}) {
  c.font = '800 28px';
  c.textAlign = 'left';
  final narrow = W < 520, hs = narrow ? 22.0 : 30.0, hg = narrow ? 25.0 : 36.0, tw = narrow ? 90.0 : 100.0;
  c.fillStyle = 'rgba(0,0,0,.28)';
  roundRect(c, 12, 10, narrow ? 112 : 150, 44, 22);
  c.fill();
  draw(c, 'Coin', 38, 32, 30);
  c.fillStyle = '#fff';
  c.fillText('$score', 60, 42);
  if (lives > 0) {
    for (var i = 0; i < lives0; i++) {
      draw(c, 'Red heart', W - (narrow ? 30 : 40) - i * hg, 32, hs, hs, false, 0, i < lives ? 1 : .22);
    }
  }
  if (time != null) {
    c.fillStyle = 'rgba(0,0,0,.28)';
    roundRect(c, W / 2 - tw / 2, 10, tw, 44, 22);
    c.fill();
    c.fillStyle = '#fff';
    c.textAlign = 'center';
    c.fillText('⏱ ${time.ceil()}', W / 2, 42);
  }
  if (bossHp != null && bossMax != null) {
    final bw = math.min(360.0, W * .5);
    c.fillStyle = 'rgba(0,0,0,.35)';
    roundRect(c, W / 2 - bw / 2, 62, bw, 18, 9);
    c.fill();
    c.fillStyle = '#ff6b6b';
    roundRect(c, W / 2 - bw / 2 + 3, 65, (bw - 6) * math.max(0, bossHp / bossMax), 12, 6);
    c.fill();
  }
}

void banner(Ctx2D c, double W, double H, String text, [String? sub]) {
  c.fillStyle = 'rgba(0,0,0,.35)';
  c.fillRect(0, H / 2 - 70, W, 140);
  c.textAlign = 'center';
  c.fillStyle = '#fff';
  _fit(c, text, 54, 800, W);
  c.fillText(text, W / 2, H / 2 + (sub != null ? 0 : 18));
  if (sub != null) {
    _fit(c, sub, 26, 700, W);
    c.fillText(sub, W / 2, H / 2 + 42);
  }
}

void _fit(Ctx2D c, String txt, double size, int weight, double W) {
  var px = size;
  do {
    c.font = '$weight ${px.toStringAsFixed(0)}px';
    px -= 1;
  } while (px > 11 && c.measureText(txt) > W - 24);
}

/// Chữ giao diện song ngữ theo i18n của khung (core I18n.lang).
class Tr {
  const Tr(this.en);
  final bool en;
  String call(String vi, String enText) => en ? enText : vi;
}

/// Màn mở đầu: cấp + mục tiêu + hướng dẫn.
void levelBanner(Ctx2D c, double W, double H, int lv, String goal, [String? hint, Tr tr = const Tr(false)]) {
  c.fillStyle = 'rgba(0,0,0,.4)';
  c.fillRect(0, H / 2 - 90, W, 180);
  c.textAlign = 'center';
  c.fillStyle = '#ffd43b';
  c.font = '800 50px';
  c.fillText('${tr('CẤP', 'LEVEL')} ${lv + 1}', W / 2, H / 2 - 22);
  c.fillStyle = '#fff';
  _fit(c, '🎯 $goal', 28, 800, W);
  c.fillText('🎯 $goal', W / 2, H / 2 + 20);
  if (hint != null) {
    _fit(c, hint, 20, 700, W);
    c.fillStyle = 'rgba(255,255,255,.85)';
    c.fillText(hint, W / 2, H / 2 + 58);
  }
}

/// Ô mục tiêu điểm trên HUD.
void goalPill(Ctx2D c, double W, num now, num need, [double y = 62]) {
  if (W < 640) y = math.max(y, 62);
  final ok = now >= need;
  c.fillStyle = ok ? 'rgba(47,158,68,.85)' : 'rgba(0,0,0,.28)';
  roundRect(c, W / 2 - 70, y, 140, 36, 18);
  c.fill();
  c.fillStyle = '#fff';
  c.textAlign = 'center';
  c.font = '800 22px';
  c.fillText(ok ? '🎯 $need ✔' : '🎯 $now/$need', W / 2, y + 26);
}

/// endText của funcore (song ngữ).
String endText(bool win, int lv, [Tr tr = const Tr(false)]) => win
    ? (lv + 1 >= kFunMax ? tr('🏆 CẤP CAO NHẤT!', '🏆 TOP LEVEL!') : tr('⭐ LÊN CẤP ${lv + 2}!', '⭐ LEVEL ${lv + 2}!'))
    : tr('CHƯA QUA CẤP', 'NOT CLEARED');

// ---------- Dùng chung funnew3/4/5 ----------
/// Nhân vật của bé theo linh vật: bạn gái / bạn trai / robot.
String kidOf(String? hero) =>
    RegExp(r'Woman|Princess|Unicorn|fairy|Cat face|Rabbit face').hasMatch(hero ?? '') ? 'kidgirl' : (hero == 'Robot' ? 'robot' : 'kidboy');

void skyFill(Ctx2D c, double W, double H, FunTheme th) {
  final g = c.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, Color(th.sky[0]));
  g.addColorStop(1, Color(th.sky[1]));
  c.fillStyle = g;
  c.fillRect(0, 0, W, H);
}

void hearts(Ctx2D c, double W, int n, [int max = 3]) {
  for (var i = 0; i < max; i++) {
    draw(c, 'Red heart', W - 40 - i * 36, 32, 30, 30, false, 0, i < n ? 1 : .22);
  }
}

/// Ô giữa trên cùng: chữ tiến độ.
void pill(Ctx2D c, double W, String text, [double y = 10, double w = 190]) {
  c.fillStyle = 'rgba(0,0,0,.28)';
  roundRect(c, W / 2 - w / 2, y, w, 44, 22);
  c.fill();
  c.fillStyle = '#fff';
  c.textAlign = 'center';
  c.font = '800 25px';
  c.fillText(text, W / 2, y + 32);
}

/// Đổ bóng hình bầu dục dưới chân.
void shadow(Ctx2D c, double x, double y, double w, [double a = .18]) {
  c.fillStyle = 'rgba(0,0,0,$a)';
  c.beginPath();
  c.ellipse(x, y, w / 2, w / 7, 0, 0, 7);
  c.fill();
}

// ---------- Môi trường chạy game ----------
/// Một lần chạm (PointerEvent rút gọn): toạ độ trong canvas.
class Ptr {
  const Ptr(this.x, this.y, {this.id = 0, this.mouse = false, this.buttons = 1});
  final double x, y;
  final int id;
  final bool mouse;
  final int buttons;
}

/// Kết quả loop (resolve của loop() web).
class FunEnd {
  const FunEnd({required this.win, this.score = 0, this.pos, this.title, this.carry});
  final bool win;
  final int score;
  final int? pos;
  final String? title;
  final Json? carry;
}

class LoopGame {
  LoopGame({required this.update, required this.draw});

  /// Trả về FunEnd khi xong.
  final FunEnd? Function(double dt) update;
  final void Function() draw;
}

class _Timer {
  _Timer(this.at, this.fn);
  final double at;
  final VoidCallback fn;
}

/// opts + box của web: mọi thứ một game canvas cần.
class Fun {
  Fun._(this.ctx, this.W, this.H, this._state) : tr = Tr(ctx.i18n.isEn);
  final FunGameContext ctx;
  final double W, H;
  final _FunCanvasState _state;
  final Tr tr;
  final Ctx2D c = Ctx2D();

  /// Tự chơi (opts.bot của web) — chỉ dùng khi test.
  bool get bot => _state.widget.bot;
  int get level => ctx.level;
  String get hero => ctx.heroImg;
  bool get alive => ctx.alive && _state.mounted;
  AudioService get audio => ctx.audio;
  void sfx(String name) => ctx.audio.sfx(name);
  void note(num i, [double dur = .9]) => ctx.audio.note(i, dur);

  final List<void Function(Ptr)> _down = [], _move = [], _up = [], _cancel = [];
  void onDown(void Function(Ptr e) f) => _down.add(f);
  void onMove(void Function(Ptr e) f) => _move.add(f);
  void onUp(void Function(Ptr e) f) => _up.add(f);
  void onCancel(void Function(Ptr e) f) => _cancel.add(f);

  /// Đồng hồ game (giây, chỉ chạy khi loop chạy): setTimeout của web.
  double clock = 0;
  final List<_Timer> _timers = [];
  void after(double sec, VoidCallback fn) => _timers.add(_Timer(clock + sec, fn));

  /// Hiện một lớp Flutter phủ trên canvas (màn DOM của web); close(v) đóng và trả kết quả.
  Future<T?> overlay<T>(Widget Function(BuildContext context, void Function(T? v) close) build) {
    final done = Completer<T?>();
    void close(T? v) {
      if (done.isCompleted) return;
      _state._setOverlay(null);
      done.complete(v);
    }

    _state._setOverlay((context) => build(context, close));
    return done.future;
  }

  /// taps() của funnew3: chạm/vuốt (vuốt khi đi quá 28px).
  void taps({void Function(double x, double y)? onTap, void Function(double dx, double dy, double x0, double y0)? onSwipe,
      void Function(double x, double y)? onDownXY, void Function(double x, double y, Offset st)? onMoveXY, void Function(double x, double y, Offset st)? onUpXY}) {
    Offset? st;
    onDown((e) {
      st = Offset(e.x, e.y);
      onDownXY?.call(e.x, e.y);
    });
    onMove((e) {
      if (st == null) return;
      onMoveXY?.call(e.x, e.y, st!);
    });
    onUp((e) {
      if (st == null) return;
      final s = st!;
      st = null;
      final dx = e.x - s.dx, dy = e.y - s.dy;
      onUpXY?.call(e.x, e.y, s);
      if (hypot(dx, dy) > 28) {
        onSwipe?.call(dx, dy, s.dx, s.dy);
      } else {
        onTap?.call(e.x, e.y);
      }
    });
    onCancel((_) => st = null);
  }

  /// dirInput() của funnew1: vuốt theo hướng, hoặc chạm: hướng từ nhân vật (ref()) tới chỗ chạm. 'u'|'d'|'l'|'r'.
  void dirInput(Offset Function() ref, void Function(String dir) onDir) {
    Offset? st;
    onDown((e) => st = Offset(e.x, e.y));
    onUp((e) {
      if (st == null) return;
      var dx = e.x - st!.dx, dy = e.y - st!.dy;
      if (hypot(dx, dy) < 24) {
        final p = ref();
        dx = e.x - p.dx;
        dy = e.y - p.dy;
      }
      st = null;
      onDir(dx.abs() > dy.abs() ? (dx > 0 ? 'r' : 'l') : (dy > 0 ? 'd' : 'u'));
    });
  }
}

typedef FunGameFn = Future<LoopGame> Function(Fun g);

/// FunGameModule chạy một game canvas kiểu web.
class FunCanvasModule extends FunGameModule {
  const FunCanvasModule(this.id, this.run);
  @override
  final String id;
  final FunGameFn run;
  @override
  Widget build(BuildContext context, FunGameContext ctx) => FunCanvas(key: ValueKey('fun-canvas-$id-${ctx.level}'), ctx: ctx, run: run);
}

/// Widget chứa canvas + vòng lặp (canvasIn + loop của funcore).
class FunCanvas extends StatefulWidget {
  const FunCanvas({super.key, required this.ctx, required this.run, this.bot = false});
  final FunGameContext ctx;
  final FunGameFn run;

  /// Tự chơi (test).
  final bool bot;
  @override
  State<FunCanvas> createState() => _FunCanvasState();
}

class _FunCanvasState extends State<FunCanvas> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Fun? _g;
  LoopGame? _game;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool _paused = false, _ended = false;
  final _repaint = ValueNotifier<int>(0);
  WidgetBuilder? _overlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
  }

  void _setOverlay(WidgetBuilder? b) {
    if (mounted) setState(() => _overlay = b);
  }

  Future<void> _start(Size size) async {
    final g = _g!;
    final LoopGame game;
    try {
      game = await widget.run(g);
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'fun/more'));
      return;
    }
    if (!mounted || !g.alive) return;
    _game = game;
    _ticker = createTicker(_tick)..start();
    setState(() {});
  }

  void _tick(Duration now) {
    final g = _g, game = _game;
    if (g == null || game == null || _ended) return;
    if (!g.alive) {
      _ticker?.stop();
      return;
    }
    final dt = math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (_paused || _overlay != null) return;
    g.clock += dt;
    if (g._timers.isNotEmpty) {
      final due = g._timers.where((t) => t.at <= g.clock).toList();
      g._timers.removeWhere(due.contains);
      for (final t in due) {
        t.fn();
      }
    }
    final r = game.update(dt);
    _repaint.value++;
    if (r != null) {
      _ended = true;
      _ticker?.stop();
      widget.ctx.finish(FunResult(score: r.score, win: r.win, pos: r.pos, title: r.title, carry: r.carry));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  Ptr _ptr(PointerEvent e, Size size) {
    final g = _g!;
    final kx = g.W / size.width, ky = g.H / size.height;
    return Ptr(e.localPosition.dx * kx, e.localPosition.dy * ky, id: e.pointer, mouse: e.kind == PointerDeviceKind.mouse, buttons: e.buttons);
  }

  void _emit(List<void Function(Ptr)> fs, PointerEvent e, Size size) {
    if (_g == null || _game == null || _ended || _overlay != null) return;
    final p = _ptr(e, size);
    for (final f in List.of(fs)) {
      f(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final size = Size(cons.maxWidth.isFinite ? cons.maxWidth : 400, cons.maxHeight.isFinite ? cons.maxHeight : 700);
      if (_g == null) {
        _g = Fun._(widget.ctx, math.max(320, size.width), math.max(320, size.height), this);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _start(size);
        });
      }
      final g = _g!;
      return Stack(fit: StackFit.expand, children: [
        ColoredBox(color: Color(theme(widget.ctx.level).sky[0])),
        if (_game != null)
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _emit(g._down, e, size),
            onPointerMove: (e) => _emit(g._move, e, size),
            onPointerUp: (e) => _emit(g._up, e, size),
            onPointerCancel: (e) => _emit(g._cancel, e, size),
            child: CustomPaint(key: const Key('fun-canvas'), size: size, painter: _Painter(this, g, _repaint)),
          ),
        if (_overlay != null) Positioned.fill(child: Builder(builder: _overlay!)),
      ]);
    });
  }
}

class _Painter extends CustomPainter {
  _Painter(this.s, this.g, Listenable repaint) : super(repaint: repaint);
  final _FunCanvasState s;
  final Fun g;
  @override
  void paint(Canvas canvas, Size size) {
    final game = s._game;
    if (game == null) return;
    final n = canvas.getSaveCount();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / g.W, size.height / g.H);
    g.c.canvas = canvas;
    try {
      game.draw();
    } finally {
      g.c.reset();
      canvas.restoreToCount(n);
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
