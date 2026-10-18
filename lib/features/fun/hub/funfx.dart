// Hiệu ứng chuyển động dùng chung cho game Khu vui chơi (port web js/games/funfx.js).
// CHỦ: agent E. API CÔNG KHAI, ỔN ĐỊNH — agent F/G có thể import.
//
// - Sprite sheet an toàn (null = bỏ qua): spr / anim / sprW / sprBox / aspect, stripX / stripPart / tile.
// - Rung màn mượt: Shaker (add, update, apply(canvas), power).
// - Hạt bụi/khói/tia lửa/vụn trong bể cấp sẵn: Dust (emit, sparks, puff, debris, update, draw, clear).
// - Nổ bằng sprite 'fxa/fx' (boom, smoke): Booms(fxSheet).
// - Nền platformer theo cảnh: groundTiles, backHills (sheet 'plat/tiles', 'plat/bg'); đồng xu xoay: coin().
// - Easing: lấy từ core/ui/utils.dart (clampD, lerp, easeOut, easeIn, easeOutBack, easeOutElastic, approach) + popScale.
// Nạp sheet: `final sh = await loadSheet('plat/tiles')` (core) — hoặc khai báo FunCanvasGame.sheetNames.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:be_vui_hoc/core/ui/ui.dart';

import 'funcore.dart' show fillCircle;

export 'package:be_vui_hoc/core/ui/sprite_sheet.dart' show SpriteSheet, loadSheet, loadSheets, frameAt, drawFrame, drawAnim;
export 'package:be_vui_hoc/core/ui/utils.dart' show clampD, lerp, easeOut, easeIn, easeOutBack, easeOutElastic, approach;

/// Vẽ khung theo chiều cao h (rộng theo tỉ lệ). sheet null → bỏ qua.
bool spr(Canvas c, SpriteSheet? sh, String frame, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1}) =>
    sh != null && drawFrame(c, sh, frame, x, y, h, flip: flip, rot: rot, alpha: alpha);

/// Vẽ hoạt ảnh theo thời gian t.
bool anim(Canvas c, SpriteSheet? sh, String name, double t, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1}) =>
    sh != null && sh.frames.isNotEmpty && drawFrame(c, sh, frameAt(sh, name, t), x, y, h, flip: flip, rot: rot, alpha: alpha);

/// Vẽ khung theo bề rộng w.
void sprW(Canvas c, SpriteSheet? sh, String frame, double x, double y, double w, {bool flip = false, double rot = 0, double alpha = 1}) {
  final f = sh?.frames[frame];
  if (f == null) return;
  drawFrame(c, sh, frame, x, y, w * f[3] / f[2], flip: flip, rot: rot, alpha: alpha);
}

/// Vẽ khung kéo giãn đúng w×h, tâm (x, y) (gạch, thanh đỡ).
void sprBox(Canvas c, SpriteSheet? sh, String frame, double x, double y, double w, double h, [double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null || w <= 0 || h <= 0) return;
  final p = Paint()..filterQuality = FilterQuality.medium;
  if (alpha < 1) p.color = Color.fromRGBO(0, 0, 0, alpha);
  c.drawImageRect(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(x - w / 2, y - h / 2, w, h), p);
}

/// Tỉ lệ rộng/cao của khung.
double aspect(SpriteSheet? sh, String frame) {
  final f = sh?.frames[frame];
  return f == null ? 1 : f[2] / f[3];
}

/// Chữ/hình nảy khi hiện theo tuổi a (0..1).
double popScale(double a) => a < .25 ? easeOutBack(a / .25) : 1;

// ---------------------------------------------------------------------------------------------------------------

/// Rung màn: add(lực) cộng dồn, tắt dần mượt, rung theo sóng sin (shaker()).
class Shaker {
  double _p = 0, _t = 0;
  void add(double k) => _p = math.min(18, _p + k);
  void update(double dt) {
    _t += dt;
    _p = math.max(0, _p - dt * (_p * 4 + 8));
  }

  /// Dịch canvas (gọi sau canvas.save()).
  void apply(Canvas c) {
    if (_p > .2) c.translate(math.sin(_t * 61) * _p, math.cos(_t * 47) * _p * .8);
  }

  double get power => _p;
}

class _Dp {
  bool on = false;
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, r = 4, grow = 0, g = 0, a = 1;
  Color c = const Color(0xFFFFFFFF);
  int k = 0;
}

/// Hạt bụi/khói/tia lửa: bể N hạt cấp sẵn (dust()).
/// k: 0 tròn mờ dần to ra (khói, bụi), 1 tia (vệt theo vận tốc), 2 vụn rơi theo trọng lực.
class Dust {
  Dust([int n = 220]) : _p = List.generate(n, (_) => _Dp());
  final List<_Dp> _p;
  int _next = 0;

  void emit(double x, double y, double vx, double vy, {double life = .6, double r = 5, double grow = 20, Color c = const Color(0xFFC8C8C8), int k = 0, double g = 0, double a = .7}) {
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

  /// Vòng nổ tia lửa.
  void sparks(double x, double y, [int n = 12, Color c = const Color(0xFFFFD43B), double sp = 260]) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * 6.283, v = sp * (.4 + rng.nextDouble() * .8);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .25 + rng.nextDouble() * .3, r: 2.5, grow: 0, c: c, k: 1, a: 1);
    }
  }

  void puff(double x, double y, [int n = 6, Color c = const Color(0xFFE6E6E6), double sp = 60, double r = 8]) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * 6.283, v = sp * rng.nextDouble();
      emit(x, y, math.cos(a) * v, math.sin(a) * v - 20, life: .5 + rng.nextDouble() * .4, r: r * (.6 + rng.nextDouble() * .6), grow: r * 3, c: c, a: .55);
    }
  }

  void debris(double x, double y, [int n = 10, Color c = const Color(0xFF8D5524), double sp = 300]) {
    for (var i = 0; i < n; i++) {
      final a = -rng.nextDouble() * 3.14, v = sp * (.4 + rng.nextDouble() * .7);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .6 + rng.nextDouble() * .4, r: 3 + rng.nextDouble() * 3, grow: 0, c: c, k: 2, g: 900, a: 1);
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

  void draw(Canvas c, [double ox = 0, double oy = 0]) {
    final paint = Paint()..strokeCap = StrokeCap.butt;
    for (final p in _p) {
      if (!p.on) continue;
      final k = p.life / p.max;
      final al = (p.a * (p.k == 0 ? k : math.min(1, k * 2))).clamp(0.0, 1.0);
      paint.color = p.c.withValues(alpha: p.c.a * al);
      if (p.k == 1) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.r;
        c.drawLine(Offset(p.x - ox, p.y - oy), Offset(p.x - ox - p.vx * .04, p.y - oy - p.vy * .04), paint);
      } else {
        paint.style = PaintingStyle.fill;
        c.drawCircle(Offset(p.x - ox, p.y - oy), math.max(0, p.r + p.grow * (1 - k)), paint);
      }
    }
  }

  void clear() {
    for (final p in _p) {
      p.on = false;
    }
  }

  int get active => _p.where((p) => p.on).length;
}

class _Boom {
  bool on = false;
  double x = 0, y = 0, s = 0, t = 0, rot = 0;
  String k = 'boom';
}

/// Nổ bằng sprite (fxa/fx: boom, smoke) — bể cấp sẵn (booms()). Không có sheet: vẽ quả cầu cam mờ dần.
class Booms {
  Booms(this.fx, [int n = 24]) : _b = List.generate(n, (_) => _Boom());
  SpriteSheet? fx;
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
      ..rot = rng.nextDouble() * 6.28;
  }

  void update(double dt) {
    for (final b in _b) {
      if (b.on) {
        b.t += dt;
        if (b.t > .36) b.on = false;
      }
    }
  }

  void draw(Canvas c, [double ox = 0, double oy = 0]) {
    for (final b in _b) {
      if (!b.on) continue;
      final k = b.t / .36;
      final s = b.s * (.7 + easeOut(math.min(1, k * 1.6)) * .5), a = k > .7 ? (1 - k) / .3 : 1.0;
      if (!anim(c, fx, b.k, b.t, b.x - ox, b.y - oy, s, rot: b.rot, alpha: a.clamp(0.0, 1.0))) {
        fillCircle(c, b.x - ox, b.y - oy, s * .4, Color.fromRGBO(255, 146, 43, .7 * a.clamp(0.0, 1.0)));
      }
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------

Paint _imgPaint(double alpha) {
  final p = Paint()..filterQuality = FilterQuality.medium;
  if (alpha < 1) p.color = Color.fromRGBO(0, 0, 0, alpha);
  return p;
}

/// Dải ảnh lặp ngang (nền cuộn parallax): khung frame cao h, lặp theo x, dịch theo off.
void stripX(Canvas c, SpriteSheet? sh, String frame, double off, double y, double h, double w, [double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final fw = h * f[2] / f[3];
  if (fw <= 1) return;
  var x = -(((off % fw) + fw) % fw);
  final p = _imgPaint(alpha), src = Rect.fromLTWH(f[0], f[1], f[2], f[3]);
  for (; x < w; x += fw - 1) {
    c.drawImageRect(im, src, Rect.fromLTWH(x, y, fw, h), p);
  }
}

/// Lát kín một vùng bằng ô vuông, dịch theo offX/offY.
void tile(Canvas c, SpriteSheet? sh, String frame, double size, double offX, double offY, double x0, double y0, double w, double h) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null || size <= 1) return;
  final sx = -(((offX % size) + size) % size), sy = -(((offY % size) + size) % size);
  final p = _imgPaint(1), src = Rect.fromLTWH(f[0], f[1], f[2], f[3]);
  for (var y = y0 + sy; y < y0 + h; y += size - .5) {
    for (var x = x0 + sx; x < x0 + w; x += size - .5) {
      c.drawImageRect(im, src, Rect.fromLTWH(x, y, size, size), p);
    }
  }
}

/// Dải ảnh lặp ngang, chỉ phần dưới của khung từ tỉ lệ top (0..1) — đồi/cây nền bỏ phần trời.
void stripPart(Canvas c, SpriteSheet? sh, String frame, double off, double y, double h, double w, [double top = 0, double alpha = 1]) {
  final f = sh?.frames[frame];
  final im = sh?.image;
  if (f == null || im == null) return;
  final sy = f[1] + f[3] * top, sh2 = f[3] * (1 - top), fw = h * f[2] / sh2;
  if (fw <= 1) return;
  var x = -(((off % fw) + fw) % fw);
  final p = _imgPaint(alpha), src = Rect.fromLTWH(f[0], sy, f[2], sh2);
  for (; x < w; x += fw - 1) {
    c.drawImageRect(im, src, Rect.fromLTWH(x, y, fw, h), p);
  }
}

/// Nền platformer theo cảnh THEMES (Đồng cỏ, Sa mạc, Xứ tuyết, Thành phố đêm, Rừng kẹo, Núi lửa).
const List<String> kPlatBg = ['color_hills', 'color_desert', 'color_trees', 'color_trees', 'color_mushrooms', 'color_desert'];
const List<String> kPlatGround = ['grass', 'sand', 'snow', 'stone', 'purple', 'dirt'];
const Map<String, Color> _groundFill = {
  'grass': Color(0xFFE0895A),
  'sand': Color(0xFFE0895A),
  'snow': Color(0xFFB9C0CA),
  'stone': Color(0xFFB6BCC6),
  'purple': Color(0xFFB9C0CA),
  'dirt': Color(0xFFB9C0CA),
};

/// Mặt đất lát gạch Kenney ('plat/tiles'): hàng mặt trên + phần đất bên dưới, cuộn theo off.
void groundTiles(Canvas c, SpriteSheet? tiles, int lv, double off, double y, double w, double h, [double size = 64]) {
  final g = kPlatGround[(lv ~/ 10) % kPlatGround.length];
  stripX(c, tiles, 'terrain_${g}_block_top', off, y, size, w);
  if (y + size < h) stripX(c, tiles, 'terrain_${g}_block_center', off, y + size - 1, size, w);
  if (y + size * 2 < h && tiles?.image != null) c.drawRect(Rect.fromLTWH(0, y + size * 2 - 2, w, h - y - size * 2 + 2), Paint()..color = _groundFill[g]!);
}

/// Đồi/cây xa (parallax) sau mặt đất ('plat/bg').
void backHills(Canvas c, SpriteSheet? bg, int lv, double off, double groundY, double h, double w, [double alpha = 1]) =>
    stripPart(c, bg, kPlatBg[(lv ~/ 10) % kPlatBg.length], off, groundY - h, h, w, .3, alpha);

/// Đồng xu xoay (co giãn ngang theo cos) — khung 'coin' của fxa/fx. Không có sheet: hình 'Coin' của [images].
void coin(Canvas c, SpriteSheet? fxs, double t, double x, double y, double s, [ui.Image? fallback]) {
  final k = math.cos(t * 4), w = s * math.max(.18, k.abs());
  final f = fxs?.frames['coin'];
  final im = fxs?.image;
  if (f == null || im == null) {
    if (fallback != null) drawImageCentered(c, fallback, x, y, w, s);
    return;
  }
  c.drawImageRect(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(x - w / 2, y - s / 2, w, s), _imgPaint(1));
}
