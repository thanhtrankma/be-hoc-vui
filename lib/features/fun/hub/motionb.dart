// Chuyển động dùng chung cho game đối kháng / phiêu lưu (port web js/games/motionb.js).
// CHỦ: agent E. API công khai, ổn định (agent G/H có thể dùng hoặc tự viết bản riêng).
//
// - Ease.outCubic/inCubic/inOut/outBack/outElastic/bump (E của web), clamp01, motionLerp, motionApproach.
// - MotionCamera: rung màn (shake), dừng hình khi trúng đòn (stop → scale(dt) trả .08 khi đang dừng), begin/end bọc phần vẽ.
// - Fxb: hạt có trọng lực, bụi, tia, vòng sóng, số sát thương nảy, chữ, vệt chém (giới hạn 260 hạt).
// - drawShadow, drawMob (quái từ hình tĩnh/sprite có hoạt ảnh thủ tục: đi nhún, lấy đà, lao, choáng, chết).
// - loadSheetMap (sheetsB), sprPx/sprAnimPx (tắt làm mịn cho pixel art), tileImage (lát ô), prerender (Picture tĩnh).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:be_vui_hoc/core/ui/ui.dart';

import 'funcore.dart' show FunText;

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double motionLerp(double a, double b, double k) => a + (b - a) * k;

/// Tiến tới đích theo hàm mũ, không phụ thuộc FPS (k = tốc độ / giây).
double motionApproach(double a, double b, double k, double dt) => b + (a - b) * math.exp(-k * dt);

/// Easing (E của motionb.js), đầu vào tự kẹp 0..1.
class Ease {
  Ease._();
  static double outCubic(double t) => 1 - math.pow(1 - clamp01(t), 3).toDouble();
  static double inCubic(double t) => math.pow(clamp01(t), 3).toDouble();
  static double inOut(double t) {
    t = clamp01(t);
    return t < .5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
  }

  static double outBack(double t) {
    t = clamp01(t);
    const c = 1.70158;
    return 1 + (c + 1) * math.pow(t - 1, 3) + c * math.pow(t - 1, 2);
  }

  static double outElastic(double t) {
    t = clamp01(t);
    return t == 0 || t == 1 ? t : math.pow(2, -10 * t) * math.sin((t * 10 - .75) * 2.0944) + 1;
  }

  static double bump(double t) => math.sin(clamp01(t) * math.pi);
}

/// Rung màn + dừng hình (camera()).
class MotionCamera {
  double _mag = 0, _ox = 0, _oy = 0, _hold = 0, _ph = 0;
  void shake(double v) => _mag = math.min(22, _mag + v);
  void stop(double s) => _hold = math.max(_hold, s);

  /// Hệ số thời gian: .08 khi đang dừng hình, còn lại 1. Nhân dt của cảnh với số này.
  double scale(double dt) {
    if (_hold > 0) {
      _hold -= dt;
      return .08;
    }
    return 1;
  }

  void update(double dt) {
    _ph += dt * 60;
    _mag *= math.exp(-dt * 9);
    if (_mag < .25) _mag = 0;
    _ox = math.sin(_ph * 1.7) * _mag;
    _oy = math.cos(_ph * 2.3) * _mag * .8;
  }

  void begin(Canvas c) {
    c.save();
    if (_mag != 0) c.translate(_ox, _oy);
  }

  void end(Canvas c) => c.restore();
  double get mag => _mag;
}

class _Fp {
  _Fp(this.k, this.x, this.y, {this.vx, this.vy, this.g = 0, required this.life, required this.l0, this.c = const Color(0xFFFFFFFF), this.r = 4, this.w = 6, this.s, this.size = 26, this.a0 = 0, this.face = 1});
  final int k;
  double x, y, life, r;
  double? vx, vy;
  final double g, l0, w, size, a0, face;
  final Color c;
  final String? s;
}

/// Lớp hiệu ứng (fxb()): burst, dust, sparks, ring, num, text, slash.
class Fxb {
  final List<_Fp> _p = [];
  void _add(_Fp p) {
    if (_p.length > 260) _p.removeAt(0);
    _p.add(p);
  }

  static const _burstColors = [Color(0xFFFFD43B), Color(0xFFFF922B), Color(0xFFFF6B6B), Color(0xFF74C0FC)];

  void burst(double x, double y, [int n = 12, List<Color> colors = _burstColors, double sp = 260, double g = 500]) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * 6.283, v = rand(.35, 1) * sp;
      _add(_Fp(0, x, y, vx: math.cos(a) * v, vy: math.sin(a) * v - sp * .25, g: g, life: rand(.35, .75), l0: .75, c: colors[i % colors.length], r: rand(2.5, 6)));
    }
  }

  /// Bụi dưới chân: tròn mờ lớn dần.
  void dust(double x, double y, [int n = 5, double dir = 0, Color c = const Color(0xBFFFFFFF)]) {
    for (var i = 0; i < n; i++) {
      _add(_Fp(1, x + rand(-8, 8), y - rand(0, 6), vx: (dir != 0 ? dir : rand(-1, 1)) * rand(30, 110), vy: -rand(10, 50), g: -20, life: rand(.35, .6), l0: .6, c: c, r: rand(5, 10)));
    }
  }

  /// Tia sáng lúc đánh trúng (dir null = mọi hướng).
  void sparks(double x, double y, [int n = 8, Color c = const Color(0xFFFFF3BF), double? dir]) {
    for (var i = 0; i < n; i++) {
      final a = dir == null ? rng.nextDouble() * 6.283 : dir + rand(-.9, .9), v = rand(280, 560);
      _add(_Fp(2, x, y, vx: math.cos(a) * v, vy: math.sin(a) * v, life: rand(.12, .25), l0: .25, c: c));
    }
  }

  void ring(double x, double y, [double r = 40, Color c = const Color(0xFFFFFFFF), double w = 6, double life = .35]) => _add(_Fp(3, x, y, r: r, c: c, w: w, life: life, l0: life));

  /// Số sát thương: nảy to rồi bay lên, chí mạng to + vàng.
  void num(double x, double y, Object v, {bool crit = false, Color c = const Color(0xFFFFFFFF), double size = 26}) =>
      _add(_Fp(4, x + rand(-10, 10), y, vx: rand(-30, 30), vy: -150, g: 260, life: .9, l0: .9, s: '$v', c: crit ? const Color(0xFFFFD43B) : c, size: crit ? size * 1.35 : size));

  void text(double x, double y, String s, [Color c = const Color(0xFFFFFFFF), double size = 30]) => _add(_Fp(4, x, y, vx: 0, vy: -70, life: 1.1, l0: 1.1, s: s, c: c, size: size));

  /// Vệt chém hình cung.
  void slash(double x, double y, double r, double a0, [double face = 1, Color c = const Color(0xF2FFFFFF)]) => _add(_Fp(5, x, y, r: r, a0: a0, face: face, c: c, life: .2, l0: .2));

  void update(double dt) {
    for (var i = _p.length - 1; i >= 0; i--) {
      final p = _p[i];
      p.life -= dt;
      if (p.life <= 0) {
        _p.removeAt(i);
        continue;
      }
      if (p.vx != null) {
        p.vy = p.vy! + p.g * dt;
        p.x += p.vx! * dt;
        p.y += p.vy! * dt;
        if (p.k == 1) {
          p.vx = p.vx! * (1 - dt * 3);
          p.r += dt * 14;
        }
      }
    }
  }

  void draw(Canvas c) {
    final paint = Paint();
    for (final p in _p) {
      final k = p.life / p.l0;
      var al = math.min(1.0, k * 1.8);
      switch (p.k) {
        case 0:
          c.drawCircle(Offset(p.x, p.y), p.r * (.4 + k * .6), paint..color = p.c.withValues(alpha: p.c.a * al));
        case 1:
          al = k * .7;
          c.drawCircle(Offset(p.x, p.y), p.r, paint..color = p.c.withValues(alpha: p.c.a * al));
        case 2:
          c.drawLine(
              Offset(p.x, p.y),
              Offset(p.x - p.vx! * .04, p.y - p.vy! * .04),
              Paint()
                ..color = p.c.withValues(alpha: p.c.a * al)
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round);
        case 3:
          final e = Ease.outCubic(1 - k);
          c.drawCircle(
              Offset(p.x, p.y),
              p.r * (.3 + e),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = p.w * k + .5
                ..color = p.c.withValues(alpha: p.c.a * al));
        case 4:
          final age = (p.l0 - p.life) / .25, sc = age < 1 ? .3 + Ease.outBack(age) * .7 : 1.0;
          FunText.draw(c, p.s!, p.x, p.y, size: (p.size * sc).roundToDouble().clamp(1, 200), weight: FontWeight.w900, color: p.c, stroke: const Color(0x8C000000), strokeWidth: 5, alpha: al);
        case 5:
          final e = Ease.outCubic(1 - k), a1 = p.a0 + (-1.9 + e * 3.2) * p.face, a0 = a1 - 1.4 * p.face;
          final lo = math.min(a0, a1), hi = math.max(a0, a1);
          c.drawArc(
              Rect.fromCircle(center: Offset(p.x, p.y), radius: p.r),
              lo,
              hi - lo,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round
                ..strokeWidth = 10 * k + 2
                ..color = p.c.withValues(alpha: p.c.a * al));
      }
    }
  }

  int get n => _p.length;
}

/// Bóng đổ elip dưới chân (nhỏ lại khi vật ở trên cao).
void drawShadow(Canvas c, double x, double y, double w, [double lift = 0, double a = .22]) {
  final k = 1 / (1 + math.max(0, lift) / 120);
  c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * k * 2, height: w * .28 * k * 2), Paint()..color = Color.fromRGBO(0, 0, 0, a * k));
}

/// Tư thế một con quái cho [drawMob]: f của web.
class MobPose {
  MobPose({required this.x, required this.y, required this.size, this.t = 0, this.hurt = 0, this.flip = false, this.atk = 0, this.wind = 0, this.dieT, this.fly = false, this.stun = false, this.moving = true});
  double x, y, size, t, hurt, atk, wind;
  double? dieT;
  bool flip, fly, stun, moving;
}

/// Vẽ quái từ hình tĩnh (img) hoặc sprite (sheet + anim/frame), có hoạt ảnh thủ tục.
/// Đi: nhún + nghiêng; lấy đà: co người lùi; ra đòn: vươn tới; trúng đòn: dẹt + nháy sáng; chết: bật lên, xoay, nhỏ dần.
void drawMob(Canvas c, ui.Image? img, MobPose f, {SpriteSheet? sheet, String? anim, String? frame, double alpha = 1}) {
  final s = f.size, t = f.t, face = f.flip ? 1.0 : -1.0;
  double sx = 1, sy = 1, rot = 0, dx = 0, dy = 0, a = alpha;
  if (f.dieT != null) {
    final k = clamp01(f.dieT!);
    dy = -math.sin(k * math.pi) * s * .35;
    rot = k * 2.4 * face;
    sx = sy = 1 - k * .7;
    a *= 1 - k;
  } else {
    if (f.fly) {
      dy = math.sin(t * 5) * s * .06;
      rot = math.sin(t * 2.5) * .08;
    } else if (f.moving) {
      final st = math.sin(t * 9);
      sy = 1 + st * .06;
      sx = 1 - st * .05;
      dy = -math.sin(t * 9).abs() * s * .05;
      rot = math.sin(t * 9) * .07;
    } else {
      final b = math.sin(t * 3);
      sy = 1 + b * .03;
      sx = 1 - b * .02;
    }
    if (f.wind > 0) {
      final w = Ease.outCubic(f.wind);
      sx *= 1 + w * .12;
      sy *= 1 - w * .14;
      dx -= face * w * s * .12;
      rot -= face * w * .2;
    }
    if (f.atk > 0) {
      final k = Ease.bump(f.atk);
      dx += face * k * s * .28;
      sx *= 1 + k * .1;
      rot += face * k * .15;
    }
    if (f.hurt > 0) {
      final k = math.min(1.0, f.hurt / .15);
      sx *= 1 + k * .18;
      sy *= 1 - k * .16;
      dx -= face * k * s * .06;
    }
    if (f.stun) rot += math.sin(t * 14) * .12;
  }
  drawShadow(c, f.x, f.y + s * .44, s * .34, f.fly ? s * .5 - dy : -dy);
  a = a.clamp(0.0, 1.0);
  if (a <= 0) return;
  c.save();
  c.translate(f.x + dx, f.y + s * .45 + dy);
  if (rot != 0) c.rotate(rot);
  c.scale(sx * (f.flip ? -1 : 1), sy);
  final fr = sheet != null ? (frame ?? frameAt(sheet, anim ?? 'idle', t)) : null;
  void body(double al) {
    if (sheet != null) {
      drawFrame(c, sheet, fr!, 0, sheet.anchor.dy < .9 ? -s * .45 : 0, s * .9, alpha: al);
    } else {
      drawImageCentered(c, img, 0, -s * .45, s, s, false, 0, al);
    }
  }

  body(a);
  // Nháy sáng khi trúng đòn: vẽ chồng chế độ cộng sáng
  if (f.hurt > 0 && f.dieT == null) {
    c.saveLayer(null, Paint()..blendMode = BlendMode.plus);
    body(a * math.min(.85, f.hurt * 6));
    c.restore();
  }
  c.restore();
}

/// Tải nhiều sheet một lần → map tên → sheet (sheetsB()).
Future<Map<String, SpriteSheet?>> loadSheetMap(List<String> names) async {
  final arr = await Future.wait(names.map(loadSheet));
  return {for (var i = 0; i < names.length; i++) names[i]: arr[i]};
}

/// Vẽ khung theo tâm (anchor), cao h. pixel: tắt làm mịn (ô pixel art). Trả false khi chưa có sheet.
bool sprPx(Canvas c, SpriteSheet? sheet, String frame, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1, bool pixel = false}) {
  if (sheet == null) return false;
  if (!pixel) return drawFrame(c, sheet, frame, x, y, h, flip: flip, rot: rot, alpha: alpha);
  final f = sheet.frames[frame];
  final im = sheet.image;
  if (f == null || im == null) return false;
  final fw = sheet.size?.width ?? f[2], fh = sheet.size?.height ?? f[3], k = h / fh;
  final ox = f.length > 4 ? f[4] : 0.0, oy = f.length > 5 ? f[5] : 0.0;
  c.save();
  c.translate(x, y);
  if (rot != 0) c.rotate(rot);
  if (flip) c.scale(-1, 1);
  final p = Paint()..filterQuality = FilterQuality.none;
  if (alpha < 1) p.color = Color.fromRGBO(0, 0, 0, alpha);
  c.drawImageRect(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH((ox - fw * sheet.anchor.dx) * k, (oy - fh * sheet.anchor.dy) * k, f[2] * k, f[3] * k), p);
  c.restore();
  return true;
}

/// Hoạt ảnh theo t (sprA()).
bool sprAnimPx(Canvas c, SpriteSheet? sheet, String animName, double t, double x, double y, double h, {bool flip = false, double rot = 0, double alpha = 1, bool pixel = false}) =>
    sheet != null && sprPx(c, sheet, frameAt(sheet, animName, t), x, y, h, flip: flip, rot: rot, alpha: alpha, pixel: pixel);

/// Ảnh một ô cỡ size×size (dùng làm ImageShader lặp: tilePattern()).
ui.Image? tileImage(SpriteSheet? sheet, String frame, double size, {bool pixel = false}) {
  final f = sheet?.frames[frame];
  final im = sheet?.image;
  if (f == null || im == null) return null;
  final n = math.max(4, size.round());
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(0, 0, n.toDouble(), n.toDouble()), Paint()..filterQuality = pixel ? FilterQuality.none : FilterQuality.medium);
  return rec.endRecording().toImageSync(n, n);
}

/// Paint lát kín bằng ảnh ô (createPattern 'repeat').
Paint tilePaint(ui.Image tileImg) => Paint()..shader = ui.ImageShader(tileImg, TileMode.repeated, TileMode.repeated, _identity);

final Float64List _identity = Float64List(16)
  ..[0] = 1
  ..[5] = 1
  ..[10] = 1
  ..[15] = 1;

/// Vẽ sẵn cảnh tĩnh một lần (prerender()); mỗi khung chỉ canvas.drawPicture(p).
ui.Picture prerender(void Function(Canvas c) fn) {
  final rec = ui.PictureRecorder();
  fn(Canvas(rec));
  return rec.endRecording();
}
