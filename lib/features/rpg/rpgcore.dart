// ignore_for_file: non_constant_identifier_names
// Lõi RPG: vẽ (Pen), hiệu ứng, rung màn, cảm ứng nhiều ngón, nút tròn, joystick, HUD, thú đồng đội,
// động cơ đấu trường (arena) và khung Flame chạy một màn.
// CHỦ: agent H. Port của reference/web/js/games/rpgcore.js (+ phần cần dùng của funcore.js, funvs1.js, motionb.js:
// bản sao riêng trong thư mục này theo luật "không import helper của agent khác").
//
// Z (ngữ cảnh một màn, ZoneCtx) do rpg.dart truyền vào: chỉ số nhân vật, hình linh vật, vũ khí, đồng đội, bình máu, vùng/màn.
// Mỗi vùng trả RunResult {win, gold, xp, kills, potions} (potions = số bình còn lại).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:be_vui_hoc/core/ui/theme.dart' show kFontFamily;
import 'package:be_vui_hoc/features/learn/creative/figure.dart';

// ---------- Tiện ích ----------
final math.Random rnd = math.Random();
double rand(double a, double b) => a + rnd.nextDouble() * (b - a);
T pick<T>(List<T> a) => a[rnd.nextInt(a.length)];
double clamp(double v, double a, double b) => v < a ? a : (v > b ? b : v);
double clamp01(double v) => clamp(v, 0, 1);
double hypot(double a, double b) => math.sqrt(a * a + b * b);
const double pi = math.pi;

/// Màu từ 0xRRGGBB (đục) hoặc kèm độ trong suốt a.
Color hx(int rgb, [double a = 1]) => Color(0xFF000000 | rgb).withValues(alpha: a);

class XY {
  XY(this.x, this.y);
  double x, y;
}

double dist(XY a, XY b) => hypot(a.x - b.x, a.y - b.y);

/// Easing (E của motionb.js).
abstract final class E {
  static double outCubic(double t) => 1 - math.pow(1 - clamp01(t), 3).toDouble();
  static double outBack(double t) {
    t = clamp01(t);
    const c = 1.70158;
    return 1 + (c + 1) * math.pow(t - 1, 3) + c * math.pow(t - 1, 2);
  }

  static double bump(double t) => math.sin(clamp01(t) * pi);
}

/// Số vùng/màn: 5 màn + trùm.
const int kStages = 6;

// ---------- Hình & sprite ----------
/// Sprite Kenney dùng chung cho các vùng (quái có khung hoạt ảnh, ô cảnh, xu).
const List<String> kRpgSheets = [
  'kenney-platformer/enemies',
  'kenney-platformer/tiles',
  'kenney-tiny-dungeon/dungeon',
  'kenney-tiny-town/town',
  'kenney-pirate/ships',
  'kenney-pirate/tiles',
];
const List<String> kBaseImgs = ['Coin', 'Red heart', 'Test tube', 'Collision', 'Glowing star', 'Sparkles', 'Crown', 'Fire'];

/// Hình emoji + sprite sheet đã tải cho một màn.
class RpgArt {
  RpgArt(this.imgs, this.sheets);
  RpgArt.empty()
      : imgs = {},
        sheets = {};
  final Map<String, ui.Image> imgs;
  final Map<String, SpriteSheet?> sheets;
}

typedef RpgArtLoader = Future<RpgArt> Function(Iterable<String> imgs, Iterable<String> sheets);

Future<RpgArt> _loadArt(Iterable<String> imgs, Iterable<String> sheets) async {
  final names = sheets.toList();
  final r = await Future.wait([loadEmojiUiImages(imgs), loadSheets(names)]);
  final sh = r[1] as List<SpriteSheet?>;
  return RpgArt(r[0] as Map<String, ui.Image>, {for (var i = 0; i < names.length; i++) names[i]: sh[i]});
}

/// Bộ nạp hình (test thay bằng bản trả RpgArt.empty() để không phải giải mã ảnh).
RpgArtLoader rpgArtLoader = _loadArt;

// ---------- Bút vẽ (thay ctx 2D của canvas web) ----------
class _TextCache {
  final Map<String, TextPainter> _m = {};
  TextPainter get(String s, double size, FontWeight w, Color color, double strokeW) {
    final key = '$s|$size|${w.value}|${color.toARGB32()}|$strokeW';
    final hit = _m[key];
    if (hit != null) return hit;
    // Đầy thì bỏ hết (không dispose: painter vừa trả ra có thể còn đang được vẽ).
    if (_m.length > 400) _m.clear();
    final style = strokeW > 0
        ? TextStyle(
            fontFamily: kFontFamily,
            fontSize: size,
            fontWeight: w,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeW
              ..strokeJoin = StrokeJoin.round
              ..color = color)
        : TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: w, color: color);
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return _m[key] = tp;
  }
}

final _TextCache _texts = _TextCache();

/// Bút vẽ: hình emoji theo tên, khung sprite, chữ (căn theo đường chân chữ như fillText), hình cơ bản.
class Pen {
  Pen(this.art, [Canvas? canvas]) {
    if (canvas != null) c = canvas;
  }
  final RpgArt art;
  late Canvas c;
  final Paint _p = Paint();
  final Paint _ip = Paint()..filterQuality = FilterQuality.medium;

  /// Bút vẽ lên canvas khác (vẽ sẵn nền), dùng chung hình.
  Pen on(Canvas canvas) => Pen(art, canvas);

  SpriteSheet? sheet(String name) => art.sheets[name];
  bool has(String name) => art.imgs.containsKey(name);

  void _img(ui.Image im, Rect src, Rect dst, double alpha, double flash, bool pixel) {
    _ip
      ..color = Color.fromRGBO(0, 0, 0, clamp01(alpha))
      ..colorFilter = null
      ..filterQuality = pixel ? FilterQuality.none : FilterQuality.medium;
    c.drawImageRect(im, src, dst, _ip);
    if (flash > 0) {
      _ip.colorFilter = ColorFilter.mode(Color.fromRGBO(255, 255, 255, clamp01(flash)), BlendMode.srcATop);
      c.drawImageRect(im, src, dst, _ip);
      _ip.colorFilter = null;
    }
  }

  /// draw(ctx, name, x, y, w, h) của funcore.js: hình tâm (x, y). Trả false khi chưa có hình.
  bool draw(String? name, double x, double y, double w, {double? h, bool flip = false, double rot = 0, double alpha = 1, double flash = 0}) {
    final im = name == null ? null : art.imgs[name];
    if (im == null || alpha <= 0) return false;
    final hh = h ?? w;
    final src = Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
    if (rot == 0 && !flip) {
      _img(im, src, Rect.fromCenter(center: Offset(x, y), width: w, height: hh), alpha, flash, false);
      return true;
    }
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    if (flip) c.scale(-1, 1);
    _img(im, src, Rect.fromCenter(center: Offset.zero, width: w, height: hh), alpha, flash, false);
    c.restore();
    return true;
  }

  /// Khung sprite theo điểm neo của sheet (drawFrame của sheets.js), cao h.
  bool frame(SpriteSheet? sh, String? frame, double x, double y, double h,
      {bool flip = false, double rot = 0, double alpha = 1, double flash = 0, bool pixel = false}) {
    final f = frame == null ? null : sh?.frames[frame];
    final im = sh?.image;
    if (sh == null || f == null || im == null) return false;
    final ox = f.length > 4 ? f[4] : 0.0, oy = f.length > 5 ? f[5] : 0.0;
    final fw = sh.size?.width ?? f[2], fh = sh.size?.height ?? f[3];
    final k = h / fh;
    final needT = rot != 0 || flip;
    if (needT) {
      c.save();
      c.translate(x, y);
      if (rot != 0) c.rotate(rot);
      if (flip) c.scale(-1, 1);
    }
    final bx = needT ? 0.0 : x, by = needT ? 0.0 : y;
    _img(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(bx + (ox - fw * sh.anchor.dx) * k, by + (oy - fh * sh.anchor.dy) * k, f[2] * k, f[3] * k), alpha, flash,
        pixel);
    if (needT) c.restore();
    return true;
  }

  /// spr(): khung theo tên; false nếu chưa có sheet.
  bool spr(SpriteSheet? sh, String frameName, double x, double y, double h, {double rot = 0, double alpha = 1, bool flip = false, bool pixel = false}) =>
      sh != null && frame(sh, frameName, x, y, h, rot: rot, alpha: alpha, flip: flip, pixel: pixel);

  /// sprA(): khung theo hoạt ảnh + thời gian.
  bool sprA(SpriteSheet? sh, String anim, double t, double x, double y, double h, {double rot = 0, double alpha = 1}) {
    if (sh == null || sh.frames.isEmpty) return false;
    if (!sh.anims.containsKey(anim) && !sh.frames.containsKey(anim)) return false;
    final fr = sh.anims.containsKey(anim) ? frameAt(sh, anim, t) : anim;
    return frame(sh, fr, x, y, h, rot: rot, alpha: alpha);
  }

  /// Ô lát (góc trên-trái), dùng khi vẽ sẵn nền.
  void tile(SpriteSheet sh, String name, double x, double y, double w, double h, [double alpha = 1]) {
    final f = sh.frames[name];
    final im = sh.image;
    if (f == null || im == null) return;
    _img(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(x, y, w, h), alpha, 0, true);
  }

  /// fillText: (x, y) = đường chân chữ; align 'center' | 'left' | 'right'.
  void text(String s, double x, double y,
      {double size = 18, FontWeight weight = FontWeight.w800, Color color = Colors.white, String align = 'center', Color? stroke, double strokeW = 4, double alpha = 1}) {
    if (s.isEmpty || alpha <= 0) return;
    final sz = size.roundToDouble();
    final a = (clamp01(alpha) * 10).round() / 10;
    final col = a < 1 ? color.withValues(alpha: color.a * a) : color;
    final tp = _texts.get(s, sz, weight, col, 0);
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = align == 'center' ? -tp.width / 2 : (align == 'right' ? -tp.width : 0.0);
    if (stroke != null) {
      final sc = a < 1 ? stroke.withValues(alpha: stroke.a * a) : stroke;
      _texts.get(s, sz, weight, sc, strokeW).paint(c, Offset(x + dx, y - base));
    }
    tp.paint(c, Offset(x + dx, y - base));
  }

  double measure(String s, double size, [FontWeight weight = FontWeight.w800]) => _texts.get(s, size.roundToDouble(), weight, Colors.white, 0).width;

  Paint fill(Color col) => _p
    ..style = PaintingStyle.fill
    ..shader = null
    ..color = col;
  Paint stroke(Color col, double w) => _p
    ..style = PaintingStyle.stroke
    ..shader = null
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = col;

  void rect(double x, double y, double w, double h, Color col) => c.drawRect(Rect.fromLTWH(x, y, w, h), fill(col));
  void rrect(double x, double y, double w, double h, double r, Color col) =>
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.max(0, r))), fill(col));
  void rrectStroke(double x, double y, double w, double h, double r, Color col, double sw) =>
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.max(0, r))), stroke(col, sw));
  void circle(double x, double y, double r, Color col) => c.drawCircle(Offset(x, y), math.max(0, r), fill(col));
  void ring(double x, double y, double r, Color col, double w) => c.drawCircle(Offset(x, y), math.max(0, r), stroke(col, w));
  void oval(double x, double y, double rx, double ry, Color col) => c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), fill(col));
  void vgrad(double w, double h, List<Color> cols, [List<double>? stops]) {
    _p
      ..style = PaintingStyle.fill
      ..color = Colors.black
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), cols, stops);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
    _p.shader = null;
  }
}

/// Vẽ sẵn cảnh tĩnh một lần (prerender của motionb.js).
ui.Picture prerender(Pen pen, void Function(Pen p) fn) {
  final rec = ui.PictureRecorder();
  fn(pen.on(Canvas(rec)));
  return rec.endRecording();
}

// ---------- Quái từ hình tĩnh (drawMob của motionb.js) ----------
class Mob extends XY {
  Mob({double x = 0, double y = 0, this.size = 40, this.img, this.sheet, this.anim, this.frame, this.fly = false, this.boss = false, this.flip = false, this.pixel = false})
      : super(x, y);
  double size;
  String? img, sheet, anim, frame;
  bool fly, boss, flip, pixel;
  double t = 0, hurt = 0, atk = 0, wind = 0, stun = 0;
  double? dieT;
  bool moving = true;
}

void shadow(Pen p, double x, double y, double w, [double lift = 0, double a = .22]) {
  final k = 1 / (1 + math.max(0, lift) / 120);
  p.oval(x, y, w * k, w * .28 * k, Color.fromRGBO(0, 0, 0, a * k));
}

/// Đi: nhún + nghiêng; lấy đà: co người; ra đòn: vươn tới; trúng đòn: dẹt + nháy sáng; chết: bật lên, xoay, nhỏ dần.
void drawMob(Pen p, Mob f, {SpriteSheet? sheet, String? anim, String? frame, double alpha = 1}) {
  final s = f.size, t = f.t, face = f.flip ? 1.0 : -1.0;
  double sx = 1, sy = 1, rot = 0, dx = 0, dy = 0, a = alpha;
  if (f.dieT != null) {
    final k = clamp01(f.dieT!);
    dy = -math.sin(k * pi) * s * .35;
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
      final w = E.outCubic(f.wind);
      sx *= 1 + w * .12;
      sy *= 1 - w * .14;
      dx -= face * w * s * .12;
      rot -= face * w * .2;
    }
    if (f.atk > 0) {
      final k = E.bump(f.atk);
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
    if (f.stun > 0) rot += math.sin(t * 14) * .12;
  }
  shadow(p, f.x, f.y + s * .44, s * .34, f.fly ? s * .5 - dy : -dy);
  final flash = f.hurt > 0 && f.dieT == null ? math.min(.85, f.hurt * 6) : 0.0;
  p.c.save();
  p.c.translate(f.x + dx, f.y + s * .45 + dy);
  if (rot != 0) p.c.rotate(rot);
  p.c.scale(sx * (f.flip ? -1 : 1), sy);
  if (sheet != null && (frame != null || anim != null)) {
    final fr = frame ?? frameAt(sheet, anim!, t);
    if (!p.frame(sheet, fr, 0, sheet.anchor.dy < .9 ? -s * .45 : 0, s * .9, alpha: a, flash: flash, pixel: f.pixel)) {
      p.draw(f.img, 0, -s * .45, s, alpha: a, flash: flash);
    }
  } else {
    p.draw(f.img, 0, -s * .45, s, alpha: a, flash: flash);
  }
  p.c.restore();
}

// ---------- Hiệu ứng ----------
class _Part {
  _Part(this.x, this.y, this.vx, this.vy, this.life, {this.c = Colors.white, this.r = 4, this.text, this.star = false});
  double x, y, vx, vy, life, r;
  Color c;
  String? text;
  bool star;
}

/// Hạt lấp lánh + chữ bay lên (fx() của funcore.js).
class Fx {
  final List<_Part> _parts = [];
  static final List<Color> _cols = [hx(0xffd43b), hx(0xff922b), hx(0xff6b6b), hx(0x74c0fc), hx(0xb197fc)];
  void burst(double x, double y, [int n = 14, List<Color>? colors]) {
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * pi * 2, v = rand(120, 320);
      _parts.add(_Part(x, y, math.cos(a) * v, math.sin(a) * v, rand(.4, .8), c: pick(colors ?? _cols), r: rand(3, 7)));
    }
    if (_parts.length > 400) _parts.removeRange(0, _parts.length - 400);
  }

  void text(double x, double y, String s, [Color c = Colors.white]) => _parts.add(_Part(x, y, 0, -70, .9, text: s, c: c));
  void star(double x, double y) => _parts.add(_Part(x, y, rand(-40, 40), -160, .9, star: true));
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

  void draw(Pen pen) {
    for (final p in _parts) {
      final a = clamp01(p.life * 1.6);
      if (p.text != null) {
        pen.text(p.text!, p.x, p.y, size: 26, color: p.c, stroke: const Color(0x59000000), alpha: a);
      } else if (p.star) {
        pen.draw('Glowing star', p.x, p.y, 34, alpha: a);
      } else {
        pen.circle(p.x, p.y, p.r, p.c.withValues(alpha: a));
      }
    }
  }
}

class _BP {
  _BP(this.k, this.x, this.y, {this.vx = 0, this.vy = 0, this.g = 0, required this.life, this.c = Colors.white, this.r = 4, this.w = 6, this.s = '', this.size = 26, this.a0 = 0, this.face = 1})
      : l0 = life;
  final int k;
  double x, y, vx, vy, g, life, r, w, size, a0, face;
  final double l0;
  Color c;
  String s;
}

/// Lớp hiệu ứng có trọng lực, bụi, tia, vòng sóng, số nảy, vệt chém (fxb() của motionb.js).
class FxB {
  final List<_BP> _ps = [];
  void _add(_BP p) {
    if (_ps.length > 260) _ps.removeAt(0);
    _ps.add(p);
  }

  void burst(double x, double y, [int n = 12, List<Color>? colors, double sp = 260, double g = 500]) {
    final cs = colors ?? [hx(0xffd43b), hx(0xff922b), hx(0xff6b6b), hx(0x74c0fc)];
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 6.283, v = rand(.35, 1) * sp;
      _add(_BP(0, x, y, vx: math.cos(a) * v, vy: math.sin(a) * v - sp * .25, g: g, life: rand(.35, .75), c: cs[i % cs.length], r: rand(2.5, 6)));
    }
  }

  void dust(double x, double y, [int n = 5, double dir = 0, Color c = const Color(0xBFFFFFFF)]) {
    for (var i = 0; i < n; i++) {
      _add(_BP(1, x + rand(-8, 8), y - rand(0, 6), vx: (dir != 0 ? dir : rand(-1, 1)) * rand(30, 110), vy: -rand(10, 50), g: -20, life: rand(.35, .6), c: c, r: rand(5, 10)));
    }
  }

  void sparks(double x, double y, [int n = 8, Color c = const Color(0xFFFFF3BF), double? dir]) {
    for (var i = 0; i < n; i++) {
      final a = dir == null ? rnd.nextDouble() * 6.283 : dir + rand(-.9, .9), v = rand(280, 560);
      _add(_BP(2, x, y, vx: math.cos(a) * v, vy: math.sin(a) * v, life: rand(.12, .25), c: c));
    }
  }

  void ring(double x, double y, [double r = 40, Color c = Colors.white, double w = 6, double life = .35]) => _add(_BP(3, x, y, r: r, c: c, w: w, life: life));
  void num(double x, double y, String v, {bool crit = false, Color c = Colors.white, double size = 26}) =>
      _add(_BP(4, x + rand(-10, 10), y, vx: rand(-30, 30), vy: -150, g: 260, life: .9, s: v, c: crit ? hx(0xffd43b) : c, size: crit ? size * 1.35 : size));
  void text(double x, double y, String s, [Color c = Colors.white, double size = 30]) => _add(_BP(4, x, y, vy: -70, life: 1.1, s: s, c: c, size: size));
  void slash(double x, double y, double r, double a0, double face, [Color c = const Color(0xF2FFFFFF)]) => _add(_BP(5, x, y, r: r, a0: a0, face: face, c: c, life: .2));

  void update(double dt) {
    for (var i = _ps.length - 1; i >= 0; i--) {
      final p = _ps[i];
      p.life -= dt;
      if (p.life <= 0) {
        _ps.removeAt(i);
        continue;
      }
      if (p.k != 3 && p.k != 5) {
        p.vy += p.g * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        if (p.k == 1) {
          p.vx *= 1 - dt * 3;
          p.r += dt * 14;
        }
      }
    }
  }

  void draw(Pen pen) {
    for (final p in _ps) {
      final k = p.life / p.l0;
      final a = math.min(1.0, k * 1.8);
      switch (p.k) {
        case 0:
          pen.circle(p.x, p.y, p.r * (.4 + k * .6), p.c.withValues(alpha: p.c.a * a));
        case 1:
          pen.circle(p.x, p.y, p.r, p.c.withValues(alpha: p.c.a * k * .7));
        case 2:
          pen.c.drawLine(Offset(p.x, p.y), Offset(p.x - p.vx * .04, p.y - p.vy * .04), pen.stroke(p.c.withValues(alpha: p.c.a * a), 3));
        case 3:
          final e = E.outCubic(1 - k);
          pen.ring(p.x, p.y, p.r * (.3 + e), p.c.withValues(alpha: p.c.a * a), p.w * k + .5);
        case 4:
          final age = (p.l0 - p.life) / .25, sc = age < 1 ? .3 + E.outBack(age) * .7 : 1.0;
          pen.c.save();
          pen.c.translate(p.x, p.y);
          pen.c.scale(sc);
          pen.text(p.s, 0, 0, size: p.size, weight: FontWeight.w900, color: p.c, stroke: const Color(0x8C000000), strokeW: 5, alpha: a);
          pen.c.restore();
        case 5:
          final e = E.outCubic(1 - k), a1 = p.a0 + (-1.9 + e * 3.2) * p.face, a0 = a1 - 1.4 * p.face;
          final lo = math.min(a0, a1), hi = math.max(a0, a1);
          pen.c.drawArc(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.r), lo, hi - lo, false, pen.stroke(p.c.withValues(alpha: p.c.a * a), 10 * k + 2));
      }
    }
  }
}

/// Rung màn + dừng hình khi trúng đòn (camera() của motionb.js).
class Cam {
  double _mag = 0, _ox = 0, _oy = 0, _hold = 0, _ph = 0;
  void shake(double v) => _mag = math.min(22, _mag + v);
  void stop(double s) => _hold = math.max(_hold, s);
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

// ---------- Cảm ứng ----------
class Ptr extends XY {
  Ptr(this.id, double x, double y)
      : sx = x,
        sy = y,
        super(x, y);
  final int id;
  final double sx, sy;
  String? btn;
}

/// Cảm ứng nhiều ngón (multi() của funvs1.js): mỗi ngón một điểm {x, y, sx, sy}.
class Pointers {
  final Map<int, Ptr> pts = {};
  final List<void Function(Ptr)> _down = [], _move = [], _up = [];
  void on(String type, void Function(Ptr) f) => (type == 'down' ? _down : (type == 'move' ? _move : _up)).add(f);
  void down(int id, double x, double y) {
    final p = Ptr(id, x, y);
    pts[id] = p;
    for (final f in List.of(_down)) {
      f(p);
    }
  }

  void move(int id, double x, double y) {
    final p = pts[id];
    if (p == null) return;
    p
      ..x = x
      ..y = y;
    for (final f in List.of(_move)) {
      f(p);
    }
  }

  void up(int id) {
    final p = pts.remove(id);
    if (p == null) return;
    for (final f in List.of(_up)) {
      f(p);
    }
  }

  void clear() {
    pts.clear();
    _down.clear();
    _move.clear();
    _up.clear();
  }
}

class Btn extends XY {
  Btn(this.id, double x, double y, this.r, this.label, {this.c, this.hidden = false}) : super(x, y);
  final String id;
  double r;
  final String label;
  final Color? c;
  bool hidden;
}

/// Nút tròn vẽ trên canvas: down(id) đang giữ, hit(id) vừa bấm (một lần). Nút lún xuống khi giữ.
class Buttons {
  Buttons(this.M, this.list) {
    M.on('down', (p) {
      for (final b in list) {
        if (!b.hidden && hypot(p.x - b.x, p.y - b.y) < b.r * 1.15) {
          _hits.add(b.id);
          p.btn = b.id;
        }
      }
    });
  }
  final Pointers M;
  final List<Btn> list;
  final Set<String> _hits = {};
  bool down(String id) {
    final b = list.where((q) => q.id == id).firstOrNull;
    if (b == null) return false;
    return M.pts.values.any((p) => hypot(p.x - b.x, p.y - b.y) < b.r * 1.25);
  }

  bool hit(String id) => _hits.remove(id);
  void draw(Pen pen) {
    for (final b in list) {
      if (b.hidden) continue;
      final on = down(b.id), r = b.r * (on ? .92 : 1);
      pen.circle(b.x, b.y + (on ? 2 : 5), r, const Color(0x2E000000));
      pen.circle(b.x, b.y + (on ? 2 : 0), r, on ? (b.c ?? hx(0xffd43b)) : const Color(0xCCFFFFFF));
      pen.ring(b.x, b.y + (on ? 2 : 0), r, b.c ?? Colors.white, 4);
      pen.text(b.label, b.x, b.y + (on ? 2 : 0) + r * .32, size: r * .9, color: hx(0x212529));
    }
  }
}

/// Tên phím kiểu web (e.key.toLowerCase()): 'arrowup', 'w', ' '...
String keyName(LogicalKeyboardKey k) {
  if (k == LogicalKeyboardKey.space) return ' ';
  if (k == LogicalKeyboardKey.arrowUp) return 'arrowup';
  if (k == LogicalKeyboardKey.arrowDown) return 'arrowdown';
  if (k == LogicalKeyboardKey.arrowLeft) return 'arrowleft';
  if (k == LogicalKeyboardKey.arrowRight) return 'arrowright';
  return k.keyLabel.toLowerCase();
}

/// Cần điều khiển: chạm vùng trống (zoneFn) để đẩy. Có cả phím mũi tên / WASD.
class Joystick {
  Joystick(this.M, this.keys, this.W, this.H, [bool Function(Ptr p)? zoneFn]) {
    final zf = zoneFn ?? (p) => p.x < W * .5 && p.y > 70;
    M.on('down', (p) {
      if (_id == null && p.btn == null && zf(p)) {
        _id = p.id;
        _cx = p.x;
        _cy = p.y;
        _dx = _dy = 0;
      }
    });
    M.on('move', (p) {
      if (p.id != _id) return;
      const R = 60.0;
      var ax = p.x - _cx, ay = p.y - _cy;
      final d = hypot(ax, ay);
      if (d > R) {
        _cx += ax * (1 - R / d);
        _cy += ay * (1 - R / d);
        ax = p.x - _cx;
        ay = p.y - _cy;
      }
      _dx = ax / R;
      _dy = ay / R;
    });
    M.on('up', (p) {
      if (p.id == _id) {
        _id = null;
        _dx = _dy = 0;
      }
    });
  }
  final Pointers M;
  final Set<String> keys;
  final double W, H;
  int? _id;
  double _cx = 0, _cy = 0, _dx = 0, _dy = 0;

  XY get() {
    final kx = (keys.contains('arrowright') || keys.contains('d') ? 1.0 : 0.0) - (keys.contains('arrowleft') || keys.contains('a') ? 1.0 : 0.0);
    final ky = (keys.contains('arrowdown') || keys.contains('s') ? 1.0 : 0.0) - (keys.contains('arrowup') || keys.contains('w') ? 1.0 : 0.0);
    if (kx != 0 || ky != 0) {
      final d = hypot(kx, ky);
      return XY(kx / d, ky / d);
    }
    final d = hypot(_dx, _dy);
    return d > 1 ? XY(_dx / d, _dy / d) : XY(_dx, _dy);
  }

  bool key(String k) => keys.contains(k);

  void draw(Pen p) {
    if (_id == null) {
      p.circle(90, H - 100, 56, const Color(0x73FFFFFF));
      p.circle(90, H - 100, 24, hx(0x495057, .45));
      p.text('kéo để đi', 90, H - 30, size: 14, weight: FontWeight.w700);
      return;
    }
    p.circle(_cx, _cy, 60, const Color(0x80FFFFFF));
    p.circle(_cx + _dx * 60, _cy + _dy * 60, 26, hx(0x339af0, .5));
  }
}

// ---------- Chỉ số ----------
class RpgStats {
  const RpgStats({required this.lv, required this.atk, required this.def, required this.maxhp, this.spd = 1, this.crit = .05, this.goldMul = 1, this.xpMul = 1, this.regen = 0});
  final int lv, atk, def, maxhp;
  final double spd, crit, goldMul, xpMul, regen;
}

/// Ngữ cảnh một màn (Z của web).
class ZoneCtx {
  ZoneCtx({required this.st, required this.heroImg, required this.weaponImg, this.pet, required this.potions, required this.r, required this.s, Costume? cos})
      : boss = s == kStages - 1,
        cos = cos ?? heroOf(heroImg);
  final RpgStats st;
  final String heroImg, weaponImg;
  final String? pet;
  int potions;
  final int r, s;
  final bool boss;
  final Costume cos;
}

class RunResult {
  const RunResult({required this.win, required this.gold, required this.xp, required this.kills, required this.potions});
  final bool win;
  final int gold, xp, kills, potions;
}

/// Quái theo vùng r, màn s (0-5), k = hệ số (trùm lớn hơn).
({double hp, double dmg}) foeStats(int r, int s, [double k = 1]) => (
      hp: ((18 + r * r * 4 + r * 16) * (1 + s * .12) * k).roundToDouble(),
      dmg: ((5 + r * 5) * (1 + s * .08) * math.sqrt(k)).roundToDouble(),
    );

/// Sát thương nhận vào sau giáp.
int taken(double dmg, int def) => math.max(1, (dmg * 100 / (100 + def * 4)).round());

/// Đòn của bé: có tỉ lệ chí mạng.
({int d, bool crit}) strike(RpgStats st, [double mult = 1]) {
  final c = rnd.nextDouble() < st.crit;
  return (d: (st.atk * mult * (c ? 2 : 1) * rand(.9, 1.1)).round(), crit: c);
}

/// Đồng đội vẽ bằng bộ thú cưng có chân bước: id lưu cũ giữ nguyên (fairy = Mèo thần, dragon = Cáo lửa).
const Map<String, String> kPetRig = {'dog': 'dog', 'fairy': 'cat', 'dragon': 'fox'};

// ---------- HUD ----------
/// Chuyển cảnh: hiện dần từ tối khi vào màn, tối dần trước khi sang bảng kết quả.
void fade(Pen p, double W, double H, double t, double endT) {
  final a = [0.0, 1 - t / .45, endT > 0 ? (endT - 1.55) / .45 : 0.0].reduce(math.max);
  if (a > 0) p.rect(0, 0, W, H, Color.fromRGBO(16, 18, 40, math.min(1, a)));
}

void hpBar(Pen p, double x, double y, double w, double h, double v, double max, [Color? c]) {
  p.rrect(x, y, w, h, h / 2, const Color(0x73000000));
  p.rrect(x + 2, y + 2, math.max(0, (w - 4) * clamp01(v / max)), h - 4, (h - 4) / 2, c ?? hx(0xff6b6b));
}

void topHud(Pen p, double W, ZoneCtx Z, double hp, double max, int gold, String? goal) {
  const x = 64.0;
  final w = math.min(220.0, W * .3);
  p.rrect(x - 6, 8, w + 70, 46, 23, const Color(0x4D000000));
  p.draw('Red heart', x + 14, 31, 26);
  hpBar(p, x + 32, 20, w - 10, 22, hp, max);
  p.text('${hp.ceil()}/${max.round()}', x + 32 + (w - 10) / 2, 36, size: 14);
  p.text('Cấp ${Z.st.lv}', x + w + 36, 37, size: 18, color: hx(0xffd43b));
  p.rrect(W - 132, 8, 120, 46, 23, const Color(0x4D000000));
  p.draw('Coin', W - 108, 31, 28);
  p.text('$gold', W - 88, 40, size: 24, align: 'left');
  if (goal != null) {
    final tw = p.measure(goal, 18) + 28, gy = W < 700 ? 62.0 : 8.0;
    final gx = W < 700 ? W / 2 : clamp(W / 2, x + w + 80 + tw / 2, math.max(x + w + 80 + tw / 2, W - 140 - tw / 2));
    p.rrect(gx - tw / 2, gy, tw, 40, 20, const Color(0x4D000000));
    p.text(goal, gx, gy + 27, size: 18);
  }
}

void bossBar(Pen p, double W, double H, double hp, double max, String name, [double? y]) {
  final yy = y ?? H - 30;
  final bw = math.min(420.0, W * .6);
  p.text('👑 $name', W / 2, yy - 6, size: 16, stroke: const Color(0x99000000));
  hpBar(p, W / 2 - bw / 2, yy, bw, 18, hp, max, hx(0xe64980));
}

/// Màn mở đầu: tên vùng, màn, mục tiêu.
void zoneIntro(Pen p, double W, double H, ZoneCtx Z, String name, String goal, String? hint) {
  p.rect(0, H / 2 - 95, W, 190, const Color(0x73000000));
  double fit(String txt, double size, FontWeight w) {
    var px = size;
    while (px > 11 && p.measure(txt, px, w) > W - 24) {
      px -= 1;
    }
    return px;
  }

  final title = Z.boss ? '👑 $name · TRÙM' : '$name · Màn ${Z.s + 1}';
  p.text(title, W / 2, H / 2 - 28, size: fit(title, 44, FontWeight.w800), color: hx(0xffd43b));
  final g = '🎯 $goal';
  p.text(g, W / 2, H / 2 + 14, size: fit(g, 26, FontWeight.w800));
  if (hint != null) p.text(hint, W / 2, H / 2 + 52, size: fit(hint, 19, FontWeight.w700), weight: FontWeight.w700, color: const Color(0xE0FFFFFF));
}

void banner(Pen p, double W, double H, String text, String? sub) {
  p.rect(0, H / 2 - 70, W, 140, const Color(0x59000000));
  var size = 54.0;
  while (size > 20 && p.measure(text, size) > W - 20) {
    size -= 2;
  }
  p.text(text, W / 2, H / 2 + (sub != null ? 0 : 18), size: size);
  if (sub != null) p.text(sub, W / 2, H / 2 + 42, size: 26, weight: FontWeight.w700);
}

void endBanner(Pen p, double W, double H, bool win, int gold) =>
    banner(p, W, H, win ? '🏆 CHIẾN THẮNG!' : '💫 HẾT MÁU RỒI!', win ? '+$gold vàng' : 'Mua đồ mạnh hơn rồi thử lại nhé');

/// Nhân vật: người que mặc trang phục theo linh vật, cầm vũ khí; (x, y) là tâm, chân ở y + size * .45.
void drawHero(Pen p, double x, double y, double size, ZoneCtx Z,
    {int face = 1, double swing = 0, double hurt = 0, double t = 0, bool moving = false, String? pose}) {
  final ps = pose ?? (swing > 0 ? 'swing' : (hurt > .55 ? 'hurt' : (moving ? 'run' : 'idle')));
  drawFigure(p.c, x, y + size * .45, size * 1.15, Z.cos,
      pose: ps, t: t, act: swing > 0 ? 1 - swing / .25 : .9, face: face, weaponImage: p.art.imgs[Z.weaponImg], alpha: hurt > 0 && (hurt * 20).floor() % 2 == 1 ? .45 : 1);
}

/// Xu vàng xoay (sprite), không có thì hình Coin.
void drawCoin(Pen p, double x, double y, double size, double t) {
  if (!p.sprA(p.sheet('kenney-platformer/tiles'), 'coin', t, x, y, size)) p.draw('Coin', x, y, size);
}

class HeroState extends XY {
  HeroState({required double x, required double y, required this.hp, required this.max, this.size = 0}) : super(x, y);
  double hp, max, inv = 0, swing = 0, size;
  int face = 1;
  bool mv = false;
  double ang = 0;
}

/// Nút bình máu dùng chung.
bool potionUse(ZoneCtx Z, HeroState hero, Fx F, AudioService audio) {
  if (Z.potions <= 0 || hero.hp >= hero.max) {
    audio.sfx('wrong');
    return false;
  }
  Z.potions--;
  hero.hp = math.min(hero.max, hero.hp + hero.max * .5);
  audio.sfx('power');
  F.text(hero.x, hero.y - 50, '+máu', hx(0x69db7c));
  F.burst(hero.x, hero.y, 14, [hx(0x69db7c), hx(0xb2f2bb), Colors.white]);
  return true;
}

void drawPotionCount(Pen p, Btn b, int n) {
  p.circle(b.x + b.r * .7, b.y - b.r * .7, 14, hx(0xe03131));
  p.text('$n', b.x + b.r * .7, b.y - b.r * .7 + 6, size: 16);
}

// ---------- Màn chơi (chung cho đấu trường và khung riêng) ----------
abstract class RpgStage {
  RpgStage(this.Z, this.art, this.W, this.H, this.audio)
      : S = math.min(W, H),
        pen = Pen(art);
  final ZoneCtx Z;
  final RpgArt art;
  final double W, H, S;
  final AudioService audio;
  final Pen pen;
  final Pointers M = Pointers();
  final Set<String> keys = {};
  final Fx F = Fx();
  final FxB FB = FxB();
  final Cam C = Cam();
  double t = 0;
  int gold = 0, xp = 0, kills = 0;

  /// 'win' | 'lose' | null
  String? end;
  double endT = 0, introT = 2.4;
  SpriteSheet? sp(String name) => art.sheets[name];
  void sfx(String name) => audio.sfx(name);

  /// Một bước; trả kết quả khi màn xong (sau 2 giây bảng kết thúc).
  RunResult? update(double dt);
  void render(Canvas c);
  void dispose() => M.clear();

  /// Thắng ngay (dùng cho test / gỡ lỗi).
  @visibleForTesting
  void debugWin() {
    end = 'win';
    introT = 0;
  }
}

/// Một vùng: ảnh cần tải + hàm tạo màn.
class ZoneDef {
  const ZoneDef(this.imgs, this.make);
  final List<String> imgs;
  final RpgStage Function(ZoneCtx Z, RpgArt art, double W, double H, AudioService audio) make;
}

// ---------- Thú đồng đội ----------
class PetState extends XY {
  PetState(this.kind) : rig = petBuddy(kPetRig[kind] ?? 'dog'), super(0, 0);
  final String kind;
  final PetBuddy rig;
  double cd = 1, t = 0;
  int f = 1;
}

PetState? makePet(ZoneCtx Z) => Z.pet == null ? null : PetState(Z.pet!);

/// Cún: chạy tới cắn quái. Mèo thần: hồi máu. Cáo lửa: phun lửa.
void petUpdate(PetState? P, Arena G, double dt) {
  if (P == null) return;
  final h = G.hero, st = G.Z.st;
  P.t += dt;
  P.cd -= dt;
  Foe? tgt;
  if (P.kind != 'fairy') {
    var bd = 1e9;
    for (final f in G.foes) {
      final d = dist(f, h);
      if (d < bd && d < G.S * .6) {
        bd = d;
        tgt = f;
      }
    }
  }
  final gx = P.kind == 'dog' && tgt != null ? tgt.x : h.x - h.face * G.S * .1;
  final gy = P.kind == 'dog' && tgt != null ? tgt.y : h.y - G.S * .06 + (P.kind == 'dog' ? G.S * .05 : math.sin(P.t * 3) * 10);
  final ox = P.x;
  P.x += (gx - P.x) * math.min(1, dt * (P.kind == 'dog' ? 4 : 3));
  P.y += (gy - P.y) * math.min(1, dt * 4);
  final vx = (P.x - ox) / math.max(dt, .001);
  if (vx.abs() > 8) P.f = vx > 0 ? 1 : -1;
  P.rig.update(dt, vx.abs() > 15 || (gy - P.y).abs() > 6);
  if (P.kind == 'fairy') {
    if (P.cd <= 0) {
      P.cd = 1;
      if (h.hp < h.max) {
        h.hp = math.min(h.max, h.hp + h.max * .025);
        G.F.text(h.x + 20, h.y - 40, '+', hx(0x69db7c));
      }
    }
  } else if (P.kind == 'dog' && tgt != null && dist(P, tgt) < tgt.size * .6 + 20 && P.cd <= 0) {
    P.cd = 1;
    G.hit(tgt, (st.atk * .4).round());
    G.sfx('bark');
  } else if (P.kind == 'dragon' && tgt != null && P.cd <= 0) {
    P.cd = 1.2;
    final a = math.atan2(tgt.y - P.y, tgt.x - P.x), v = G.S * 1.4;
    G.shots.add(Shot(P.x, P.y, math.cos(a) * v, math.sin(a) * v, d: (st.atk * .6).round(), img: 'Fire', size: G.S * .06, life: 1.5));
  }
}

void petDraw(Pen p, PetState? P, Arena G) {
  if (P != null) P.rig.draw(p.c, P.x, P.y + G.S * .05, G.S * .042, P.f);
}

// ---------- Động cơ đấu trường (Rừng Xanh, Biển Ngọc, Thành Mây, Đầm Lầy Ma, Lâu Đài Rồng) ----------
class ShootSpec {
  const ShootSpec({required this.rate, required this.img, this.speed = .5, this.size = .05, this.dir});
  final double rate, speed, size;
  final String img;
  final double? dir;
}

typedef FoeAi = void Function(Foe f, Arena G, double dt);

class Foe extends Mob {
  Foe({
    super.x,
    super.y,
    super.size = 0,
    super.img,
    super.sheet,
    super.anim,
    super.fly,
    super.boss,
    bool? flip,
    required this.hp,
    required this.dmg,
    this.spd = 0,
    this.name,
    this.crown = false,
    this.shield = false,
    this.noTouch = false,
    this.gold = 1,
    this.ai,
    this.shoot,
    this.drawFn,
    this.onDie,
  })  : autoFlip = flip == null,
        super(flip: flip ?? false);
  double hp, dmg, spd;
  double max = 0, cd = 0, kx = 0, ky = 0, atkT = 0, born = 0, gold;
  String? name;
  bool crown, shield, noTouch, hidden = false, dead = false, autoFlip;
  FoeAi? ai;
  ShootSpec? shoot;
  void Function(Pen p, Foe f, Arena G)? drawFn;
  void Function(Foe f, Arena G)? onDie;
  // Trạng thái AI riêng (lao tới, lang thang...)
  String ph = 'walk';
  double pt = 0, ddx = 0, ddy = 0;
  double? wa;
  bool cdSet = false;

  /// Bản sao để vẽ hoạt ảnh chết.
  Mob ghost() => Mob(x: x, y: y, size: size, img: img, sheet: sheet, anim: anim, fly: fly, boss: boss, flip: flip)
    ..t = t
    ..dieT = 0
    ..hurt = .15;
}

class Shot extends XY {
  Shot(super.x, super.y, this.vx, this.vy, {this.d = 0, required this.img, required this.size, required this.life, this.rot});
  double vx, vy, size, life;
  final int d;
  final String img;
  final double? rot;
}

/// Vùng nguy hiểm báo trước (vòng / chữ nhật đỏ).
class Tele extends XY {
  Tele(super.x, super.y, {this.r = 0, this.w = 0, this.h = 0, required this.dmg, double t = 1.2})
      : t = t,
        t0 = t;
  final double r, w, h, dmg;
  double t;
  final double t0;
  bool done = false;
}

class Drop extends XY {
  Drop(super.x, super.y, this.v);
  final int v;
  double t = 0;
  bool got = false;
}

class Light extends XY {
  Light(super.x, super.y, this.r);
  final double r;
}

class AutoFire {
  const AutoFire({required this.rate, required this.img, this.speed = 1.3, this.mul = .8, this.size = .05, this.dir});
  final double rate, speed, mul, size;
  final String img;

  /// null = nhắm quái gần nhất; 'up' | 'right'
  final String? dir;
}

/// Cấu hình một vùng đấu trường (cfg của web). Vùng con kế thừa và giữ trạng thái riêng.
abstract class ArenaCfg {
  ArenaCfg(this.Z);
  final ZoneCtx Z;
  String get name;
  String get goalText;
  String? get hint => null;
  bool get melee => true;
  String? get mount => null;
  (String, String)? get mountSpr => null;
  AutoFire? get autoFire => null;
  double get skillCd => 6;
  String get skillLabel => '✨';
  double? heroSize(Arena G) => null;
  double get heroSpeed => 1;
  Rect? bounds(Arena G) => null;
  void start(Arena G) {}
  void tick(Arena G, double dt) {}
  bool done(Arena G);
  String? goal(Arena G);
  void bg(Pen p, Arena G);
  void after(Pen p, Arena G) {}

  /// true = dùng skill() riêng thay chiêu xoáy.
  bool get customSkill => false;
  void skill(Arena G) {}

  /// Bán kính vùng sáng quanh bé khi trời tối (null = không tối).
  double? dark(Arena G) => null;
  void afterDark(Pen p, Arena G) {}
}

class Arena extends RpgStage {
  Arena(super.Z, super.art, super.W, super.H, super.audio, this.cfg) {
    final st = Z.st;
    hs = cfg.heroSize(this) ?? S * .13;
    final br = math.min(54.0, S * .085);
    final melee = cfg.melee;
    if (melee) btnList.add(Btn('atk', W - br - 18, H - br - 22, br * 1.15, '⚔️', c: hx(0xff922b)));
    btnList.add(Btn('sk', W - br * (melee ? 3.4 : 1) - 18, H - br - 22, br * .9, cfg.skillLabel, c: hx(0xb197fc)));
    btnList.add(Btn('pot', W - br - 18, H - br * (melee ? 3.6 : 3.2) - 22, br * .75, '🧪', c: hx(0x69db7c)));
    B = Buttons(M, btnList);
    J = Joystick(M, keys, W, H, (p) => p.y > 70 && !(p.x > W - br * 5 - 30 && p.y > H - br * 5));
    hero = HeroState(x: W / 2, y: H * .6, hp: st.maxhp.toDouble(), max: st.maxhp.toDouble(), size: hs);
    skMax = cfg.skillCd;
    pet = makePet(Z);
    if (pet != null) {
      pet!
        ..x = hero.x
        ..y = hero.y;
    }
    cfg.start(this);
  }
  final ArenaCfg cfg;
  late final double hs;
  final List<Btn> btnList = [];
  late final Buttons B;
  late final Joystick J;
  late final HeroState hero;
  PetState? pet;
  List<Mob> dying = [];
  List<Foe> foes = [];
  List<Shot> shots = [], eshots = [];
  List<Tele> zones = [];
  List<Drop> drops = [];
  List<Light> lights = [];
  double flash = 0, atkCd = 0, skCd = 0, skMax = 6, ring = 0, fireT = 0;

  Foe add(Foe f) {
    f.max = f.hp;
    if (f.size == 0) f.size = S * .1;
    f.hurt = 0;
    if (!f.cdSet) f.cd = rand(.5, 1.5);
    f.t = rand(0, 2);
    f.kx = f.ky = 0;
    f.atkT = 0;
    f.born = 0;
    foes.add(f);
    return f;
  }

  /// Sinh quái ở mép màn (side 0 trên, 1 phải, 2 dưới, 3 trái).
  Foe edge(Foe f, {int? side}) {
    final sd = side ?? rnd.nextInt(4);
    switch (sd) {
      case 0:
        f
          ..x = rand(0, W)
          ..y = -40;
      case 1:
        f
          ..x = W + 40
          ..y = rand(80, H);
      case 2:
        f
          ..x = rand(0, W)
          ..y = H + 40;
      default:
        f
          ..x = -40
          ..y = rand(80, H);
    }
    return add(f);
  }

  void hit(Foe f, int d, [bool crit = false]) {
    if (f.dead || f.shield) {
      if (f.shield) F.text(f.x, f.y - f.size * .6, '🛡', Colors.white);
      return;
    }
    f.hp -= d;
    f.hurt = .15;
    FB.num(f.x, f.y - f.size * .6, crit ? '$d!' : '$d', crit: crit);
    FB.sparks(f.x, f.y, crit ? 9 : 5, crit ? hx(0xffe066) : Colors.white);
    if (f.hp <= 0) {
      f.dead = true;
      kills++;
      sfx(f.boss ? 'boom' : 'pop');
      F.burst(f.x, f.y, f.boss ? 40 : 14);
      FB.ring(f.x, f.y, f.size * .7, Colors.white, 6);
      C.shake(f.boss ? 14 : 2.5);
      if (f.boss) C.stop(.25);
      if (f.drawFn == null) dying.add(f.ghost());
      final g = ((2 + Z.r * 3) * (f.boss ? 15 : f.gold) * Z.st.goldMul).round();
      drops.add(Drop(f.x, f.y, g));
      xp += ((3 + Z.r * 2) * (f.boss ? 10 : 1)).round();
      f.onDie?.call(f, this);
    }
  }

  void hurt(double d) {
    final h = hero;
    if (h.inv > 0 || end != null) return;
    final v = taken(d, Z.st.def);
    h.hp -= v;
    h.inv = .8;
    sfx('hit');
    FB.num(h.x, h.y - hs * .6, '-$v', c: hx(0xff6b6b));
    C.shake(6);
    flash = .35;
  }

  void tele(Tele z) => zones.add(z);

  Rect get _bounds => cfg.bounds(this) ?? Rect.fromLTRB(hs / 2, 70 + hs / 2, W - hs / 2, H - hs / 2);

  Foe? nearest(XY from, [double rng = 1e9]) {
    Foe? b;
    var bd = rng;
    for (final f in foes) {
      if (f.dead || f.hidden) continue;
      final d = dist(f, from);
      if (d < bd) {
        bd = d;
        b = f;
      }
    }
    return b;
  }

  @override
  RunResult? update(double rdt) {
    C.update(rdt);
    final dt = rdt * C.scale(rdt);
    t += dt;
    F.update(dt);
    FB.update(dt);
    flash = math.max(0, flash - rdt);
    for (final f in dying) {
      f.dieT = f.dieT! + dt * 2;
    }
    dying.removeWhere((f) => f.dieT! >= 1);
    final h = hero, st = Z.st;
    if (end != null) {
      endT += dt;
      return endT > 2 ? RunResult(win: end == 'win', gold: gold, xp: xp, kills: kills, potions: Z.potions) : null;
    }
    if (introT > 0) {
      introT -= dt;
      if (introT > 0) return null;
    }
    // Di chuyển
    final j = J.get(), spd = S * .42 * st.spd * cfg.heroSpeed;
    h.x += j.x * spd * dt;
    h.y += j.y * spd * dt;
    if (j.x.abs() > .2) h.face = j.x > 0 ? 1 : -1;
    if (cfg.mountSpr != null && hypot(j.x, j.y) > .2) {
      final ta = math.atan2(j.x, -j.y);
      var da = ta - h.ang;
      while (da > pi) {
        da -= pi * 2;
      }
      while (da < -pi) {
        da += pi * 2;
      }
      h.ang += da * math.min(1, dt * 6);
      if (rnd.nextDouble() < dt * 20) FB.dust(h.x - math.sin(h.ang) * hs * .6, h.y + math.cos(h.ang) * hs * .6, 1, 0, const Color(0xCCFFFFFF));
    }
    h.mv = hypot(j.x, j.y) > .15;
    final bd = _bounds;
    h.x = clamp(h.x, bd.left, bd.right);
    h.y = clamp(h.y, bd.top, bd.bottom);
    h.inv = math.max(0, h.inv - dt);
    h.swing = math.max(0, h.swing - dt);
    if (st.regen > 0) h.hp = math.min(h.max, h.hp + h.max * st.regen * dt);
    atkCd -= dt;
    skCd -= dt;
    // Đánh gần: tự nhắm quái gần nhất
    if ((B.hit('atk') || J.key(' ')) && atkCd <= 0 && cfg.melee) {
      atkCd = .32;
      h.swing = .25;
      sfx('flip');
      final tg = nearest(h);
      if (tg != null && tg.x != h.x) h.face = tg.x > h.x ? 1 : -1;
      final R = hs * 1.25;
      var any = false;
      for (final f in List.of(foes)) {
        if (!f.dead && !f.hidden && dist(f, h) < R + f.size * .45) {
          final s = strike(st);
          hit(f, s.d, s.crit);
          any = true;
          if (!f.boss) {
            final a = math.atan2(f.y - h.y, f.x - h.x);
            f.kx += math.cos(a) * S * 1.1;
            f.ky += math.sin(a) * S * 1.1;
          }
        }
      }
      if (any) {
        sfx('hit');
        C.stop(.05);
        C.shake(2.5);
      }
      FB.slash(h.x + h.face * hs * .1, h.y - hs * .05, hs * .75, h.face > 0 ? 0 : pi, h.face.toDouble());
    }
    if (B.hit('sk') && skCd <= 0) {
      skCd = skMax;
      sfx('power');
      if (cfg.customSkill) {
        cfg.skill(this);
      } else {
        final R = S * .3;
        F.burst(h.x, h.y, 40, [hx(0xb197fc), hx(0xe5dbff), Colors.white]);
        FB.ring(h.x, h.y, R, hx(0xd0bfff), 10, .5);
        C.shake(5);
        for (final f in List.of(foes)) {
          if (!f.dead && !f.hidden && dist(f, h) < R + f.size / 2) {
            final s = strike(st, 2);
            hit(f, s.d, s.crit);
          }
        }
        ring = .4;
      }
    }
    if (B.hit('pot')) potionUse(Z, h, F, audio);
    // Tự bắn (tàu, đại bàng)
    final A = cfg.autoFire;
    if (A != null) {
      fireT -= dt;
      if (fireT <= 0) {
        final tg = A.dir != null ? null : nearest(h, S * 1.2);
        if (A.dir != null || tg != null) {
          fireT = A.rate;
          final v = S * A.speed;
          var a = A.dir == 'up' ? -pi / 2 : (A.dir == 'right' ? 0.0 : math.atan2(tg!.y - h.y, tg.x - h.x));
          // Bắn thẳng thì tự nhắm nhẹ vào quái phía trước (lệch tối đa ~35°) cho bé dễ trúng
          if (A.dir == 'right') {
            final fr = foes.where((f) => !f.dead && !f.hidden && f.x > h.x + 20).toList()..sort((p, q) => dist(p, h).compareTo(dist(q, h)));
            if (fr.isNotEmpty) a = clamp(math.atan2(fr.first.y - h.y, fr.first.x - h.x), -.6, .6);
          }
          shots.add(Shot(h.x, h.y, math.cos(a) * v, math.sin(a) * v, img: A.img, size: S * A.size, life: 2, rot: a));
          sfx('shoot');
        }
      }
    }
    cfg.tick(this, dt);
    petUpdate(pet, this, dt);
    // Quái
    for (final f in List.of(foes)) {
      if (f.dead) continue;
      f.t += dt;
      f.hurt = math.max(0, f.hurt - dt);
      f.cd -= dt;
      f.atkT = math.max(0, f.atkT - dt);
      f.born += dt;
      if (f.kx != 0 || f.ky != 0) {
        f.x += f.kx * dt;
        f.y += f.ky * dt;
        final k = math.exp(-dt * 9);
        f.kx *= k;
        f.ky *= k;
        if (f.kx.abs() + f.ky.abs() < 4) f.kx = f.ky = 0;
      }
      final ox = f.x, oy = f.y;
      if (f.ai != null) {
        f.ai!(f, this, dt);
      } else {
        final a = math.atan2(h.y - f.y, h.x - f.x);
        f.x += math.cos(a) * f.spd * dt;
        f.y += math.sin(a) * f.spd * dt;
      }
      f.moving = (f.x - ox).abs() + (f.y - oy).abs() > dt * 8;
      if (!f.hidden && !f.noTouch && dist(f, h) < (f.size + hs) * .38) {
        if (h.inv <= 0 && end == null) f.atkT = .35;
        hurt(f.dmg);
      }
      final sh = f.shoot;
      if (sh != null && f.cd <= 0 && !f.hidden) {
        f.cd = sh.rate * rand(.8, 1.2);
        f.atkT = .35;
        final a = sh.dir ?? math.atan2(h.y - f.y, h.x - f.x), v = S * sh.speed;
        eshots.add(Shot(f.x, f.y, math.cos(a) * v, math.sin(a) * v, d: f.dmg.round(), img: sh.img, size: S * sh.size, life: 4));
      }
    }
    foes = foes.where((f) => !f.dead && f.x > -300 && f.x < W + 300 && f.y > -300 && f.y < H + 300).toList();
    // Đạn của bé / đồng đội
    for (final s in shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      for (final f in List.of(foes)) {
        if (!f.dead && !f.hidden && dist(s, f) < f.size * .45 + s.size * .3) {
          final k = s.d != 0 ? (d: s.d, crit: false) : strike(st, A?.mul ?? .8);
          hit(f, k.d, k.crit);
          s.life = 0;
          break;
        }
      }
    }
    shots.removeWhere((s) => s.life <= 0);
    for (final s in eshots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (dist(s, h) < hs * .35 + s.size * .3) {
        hurt(s.d.toDouble());
        s.life = 0;
      }
    }
    eshots.removeWhere((s) => !(s.life > 0 && s.x > -50 && s.x < W + 50 && s.y > -50 && s.y < H + 50));
    // Vùng nguy hiểm báo trước (vòng đỏ)
    for (final z in zones) {
      z.t -= dt;
      if (z.t <= 0 && !z.done) {
        z.done = true;
        F.burst(z.x, z.y, 18, [hx(0xff6b6b), hx(0xffa94d), hx(0xffe066)]);
        FB.ring(z.x, z.y, z.r > 0 ? z.r : z.w / 2, hx(0xffa94d), 8);
        C.shake(4);
        sfx('boom');
        final inside = z.w > 0 ? (h.x > z.x - z.w / 2 && h.x < z.x + z.w / 2 && h.y > z.y - z.h / 2 && h.y < z.y + z.h / 2) : dist(z, h) < z.r;
        if (inside) hurt(z.dmg);
      }
    }
    zones.removeWhere((z) => z.t <= -.3);
    // Vàng bay về
    for (final d in drops) {
      d.t += dt;
      if (d.t > .5) {
        final a = math.atan2(h.y - d.y, h.x - d.x), v = S * 1.8;
        d.x += math.cos(a) * v * dt;
        d.y += math.sin(a) * v * dt;
        if (dist(d, h) < 30) {
          gold += d.v;
          d.got = true;
          sfx('coin');
        }
      }
    }
    drops.removeWhere((d) => d.got);
    if (ring > 0) ring = math.max(0, ring - dt);
    if (h.hp <= 0) {
      h.hp = 0;
      end = 'lose';
      sfx('wrong');
    } else if (cfg.done(this)) {
      end = 'win';
      sfx('win');
      F.burst(W / 2, H / 2, 60);
    }
    return null;
  }

  final Paint _layer = Paint();

  @override
  void render(Canvas c) {
    final p = pen..c = c;
    final h = hero;
    C.begin(c);
    cfg.bg(p, this);
    for (final z in zones) {
      final k = 1 - math.max(0, z.t) / z.t0;
      final fillC = Color.fromRGBO(255, 59, 59, .15 + k * .3), line = const Color(0xE6FF3B3B);
      if (z.w > 0) {
        final r = Rect.fromCenter(center: Offset(z.x, z.y), width: z.w, height: z.h);
        c.drawRect(r, p.fill(fillC));
        c.drawRect(r, p.stroke(line, 3));
      } else {
        p.circle(z.x, z.y, z.r, fillC);
        p.ring(z.x, z.y, z.r, line, 3);
        p.ring(z.x, z.y, z.r * k, line, 3);
      }
    }
    for (final d in drops) {
      drawCoin(p, d.x, d.y - math.sin(math.min(1, d.t / .5) * pi) * 40, 28, t + d.v);
    }
    for (final f in dying) {
      _drawFoe(p, f);
    }
    final ents = <Mob?>[...foes.where((f) => !f.hidden), null]..sort((a, b) => (a?.y ?? h.y).compareTo(b?.y ?? h.y));
    for (final e in ents) {
      if (e == null) {
        _drawHeroMount(p);
        continue;
      }
      final f = e as Foe;
      if (f.drawFn != null) {
        f.drawFn!(p, f, this);
        continue;
      }
      if (f.autoFlip) f.flip = h.x > f.x;
      // Quái mới xuất hiện: phóng to dần (outBack)
      final sz0 = f.size;
      if (f.born < .35) f.size = sz0 * math.max(.05, E.outBack(f.born / .35));
      f.atk = f.atkT > 0 ? 1 - f.atkT / .35 : 0;
      _drawFoe(p, f);
      f.size = sz0;
      if (f.crown) p.draw('Crown', f.x, f.y - f.size * .55, f.size * .35);
      if (!f.boss && f.hp < f.max) hpBar(p, f.x - f.size * .35, f.y - f.size * .62, f.size * .7, 8, f.hp, f.max);
    }
    petDraw(p, pet, this);
    for (final s in shots) {
      p.draw(s.img, s.x, s.y, s.size, rot: s.rot ?? t * 12);
    }
    for (final s in eshots) {
      p.draw(s.img, s.x, s.y, s.size, rot: t * 8);
    }
    if (ring > 0) p.ring(h.x, h.y, S * .3 * (1.2 - ring), hx(0xb197fc, clamp01(ring * 2)), 10);
    cfg.after(p, this);
    FB.draw(p);
    C.end(c);
    final dr = cfg.dark(this);
    if (dr != null) {
      // Bóng tối: lớp tối, khoét các vùng sáng (bé + đốm sáng)
      final full = Rect.fromLTWH(0, 0, W, H);
      c.saveLayer(full, _layer);
      c.drawRect(full, p.fill(const Color(0xED080A1E)));
      for (final L in [Light(h.x, h.y, dr), ...lights]) {
        final g = Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = ui.Gradient.radial(Offset(L.x, L.y), L.r, [Colors.black, Colors.black, const Color(0x00000000)], [0, .25, 1]);
        c.drawCircle(Offset(L.x, L.y), L.r, g);
      }
      c.restore();
      cfg.afterDark(p, this);
    }
    F.draw(p);
    if (flash > 0) {
      final g = Paint()
        ..shader = ui.Gradient.radial(Offset(W / 2, H / 2), math.max(W, H) * .75, [const Color(0x00FF0000), const Color(0x00FF0000), Color.fromRGBO(255, 30, 30, math.min(1, flash * 1.2))],
            [0, S * .3 / (math.max(W, H) * .75), 1]);
      c.drawRect(Rect.fromLTWH(0, 0, W, H), g);
    }
    final boss = foes.where((f) => f.boss && !f.dead).firstOrNull;
    if (boss != null) bossBar(p, W, H, boss.hp, boss.max, boss.name ?? 'Trùm', W < 700 ? 132 : H - 30);
    topHud(p, W, Z, h.hp, h.max, gold, cfg.goal(this));
    J.draw(p);
    B.draw(p);
    final sk = btnList.firstWhere((b) => b.id == 'sk');
    if (skCd > 0) {
      c.drawArc(Rect.fromCircle(center: Offset(sk.x, sk.y), radius: sk.r), -pi / 2, pi * 2 * skCd / skMax, true, p.fill(const Color(0x80000000)));
    }
    drawPotionCount(p, btnList.firstWhere((b) => b.id == 'pot'), Z.potions);
    if (introT > 0) zoneIntro(p, W, H, Z, cfg.name, cfg.goalText, cfg.hint);
    if (end != null) endBanner(p, W, H, end == 'win', gold);
    fade(p, W, H, t, end != null ? endT : 0);
  }

  void _drawFoe(Pen p, Mob f) {
    final sh = f.sheet != null ? sp(f.sheet!) : null;
    String? anim = f.anim;
    if (sh != null && f.dieT != null && sh.anims.containsKey('${f.anim}_die')) anim = '${f.anim}_die';
    drawMob(p, f, sheet: sh, anim: anim, frame: f.frame);
  }

  void _drawHeroMount(Pen p) {
    final h = hero;
    final blink = h.inv > 0 && (h.inv * 20).floor() % 2 == 1 ? .5 : 1.0;
    final ms = cfg.mountSpr;
    if (ms != null) {
      // Thuyền (sprite nhìn từ trên): xoay theo hướng lái, nhấp nhô trên sóng
      final bob = math.sin(t * 3) * .04;
      if (!p.spr(sp(ms.$1), ms.$2, h.x, h.y + hs * .1, hs * 1.5, rot: h.ang + bob, alpha: blink)) {
        p.draw(cfg.mount, h.x, h.y + hs * .15, hs * 1.35, flip: h.face < 0, alpha: blink);
      }
      drawHero(p, h.x, h.y - hs * .12, hs * .62, Z, face: h.face, swing: h.swing, hurt: h.inv, t: t, pose: 'idle');
    } else if (cfg.mount != null) {
      final eagle = cfg.mount == 'Eagle';
      p.draw(cfg.mount, h.x, h.y + hs * .15, hs * 1.35, flip: eagle ? true : h.face < 0, alpha: blink);
      drawHero(p, h.x, h.y + hs * (eagle ? -.22 : .02), hs * .7, Z, face: eagle ? 1 : h.face, swing: h.swing, hurt: h.inv, t: t, pose: 'sit');
    } else {
      drawHero(p, h.x, h.y, hs, Z, face: h.face, swing: h.swing, hurt: h.inv, t: t, moving: h.mv);
    }
  }
}

// ---------- Flame: vòng lặp game ----------
/// Chạy một RpgStage bằng vòng lặp của Flame (dt tối đa .05 như loop() của web).
class RpgFlame extends Game {
  RpgFlame(this.stage, this.onDone);
  final RpgStage stage;
  final void Function(RunResult r) onDone;
  bool finished = false;

  /// Kích thước thật của khung (có thể khác lúc tạo màn, vd. xoay máy): vẽ co giãn theo.
  Size view = Size.zero;

  @override
  Color backgroundColor() => const Color(0xFF101228);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    view = Size(size.x, size.y);
  }

  @override
  void update(double dt) {
    if (finished) return;
    final r = stage.update(math.min(.05, dt));
    if (r != null) {
      finished = true;
      onDone(r);
    }
  }

  @override
  void render(Canvas canvas) {
    final sx = view.width > 0 ? view.width / stage.W : 1.0, sy = view.height > 0 ? view.height / stage.H : 1.0;
    final scaled = (sx - 1).abs() > .001 || (sy - 1).abs() > .001;
    if (scaled) {
      canvas.save();
      canvas.scale(sx, sy);
    }
    canvas.clipRect(Rect.fromLTWH(0, 0, stage.W, stage.H));
    stage.render(canvas);
    if (scaled) canvas.restore();
  }

  Offset toStage(Offset p) => view.width > 0 ? Offset(p.dx * stage.W / view.width, p.dy * stage.H / view.height) : p;

  @override
  void onRemove() {
    stage.dispose();
    super.onRemove();
  }
}

/// Khung chơi: GameWidget + cảm ứng nhiều ngón (Listener) + bàn phím.
class RpgGameView extends StatefulWidget {
  const RpgGameView({super.key, required this.game});
  final RpgFlame game;
  @override
  State<RpgGameView> createState() => _RpgGameViewState();
}

class _RpgGameViewState extends State<RpgGameView> {
  final FocusNode _focus = FocusNode(debugLabel: 'rpg');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode n, KeyEvent e) {
    final k = keyName(e.logicalKey), keys = widget.game.stage.keys;
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      keys.add(k);
    } else if (e is KeyUpEvent) {
      keys.remove(k);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game, M = g.stage.M;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          final p = g.toStage(e.localPosition);
          M.down(e.pointer, p.dx, p.dy);
        },
        onPointerMove: (e) {
          final p = g.toStage(e.localPosition);
          M.move(e.pointer, p.dx, p.dy);
        },
        onPointerUp: (e) => M.up(e.pointer),
        onPointerCancel: (e) => M.up(e.pointer),
        child: GameWidget(game: g),
      ),
    );
  }
}
