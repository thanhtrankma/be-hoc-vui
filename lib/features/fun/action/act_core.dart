// Lõi riêng cho các game hành động / đối kháng của agent G (bản sao cục bộ của funcore.js + funfx.js + motionb.js,
// không phụ thuộc thư mục fun/hub của agent E). Vẽ bằng Canvas trong vòng lặp Flame (Game.update/render).
//  - Gfx: hình emoji + sprite sheet đã nạp; draw/spr/anim/tile/coin như web.
//  - Txt: chữ trên canvas (TextPainter có bộ nhớ đệm), y = đường chân chữ như fillText.
//  - Fx (funcore fx), Dust/Booms/Shaker (funfx), Fxb/Camera/shadow (motionb).
//  - hud/banner/levelBanner/goalPill (funcore).
//  - ActGame: lớp nền Flame Game: setup() khi biết kích thước, step(dt) trả kết quả khi xong, paint(canvas), cảm ứng nhiều ngón.
//  - ActGameView: widget nhúng GameWidget + Listener, gọi ctx.finish đúng một lần.
//  - ActSession: nhớ lựa chọn trong một vé (xe đã chọn, chế độ đấu, đã qua Xưởng) giữa các cấp liên tiếp.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:be_vui_hoc/core/ui/theme.dart' show kFontFamily;
import 'package:be_vui_hoc/core/ui/utils.dart' as u;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

export 'package:be_vui_hoc/core/ui/utils.dart' show ramp, approach, easeOut, easeOutBack, lerp;

const double tau = math.pi * 2;
final math.Random _r = math.Random();

/// Số ngẫu nhiên [a, b).
double rnd(double a, double b) => a + _r.nextDouble() * (b - a);
double rnd01() => _r.nextDouble();
T pickOf<T>(List<T> a) => a[_r.nextInt(a.length)];
double clamp(double v, [double a = 0, double b = 1]) => v < a ? a : (v > b ? b : v);
double hypot(double x, double y) => math.sqrt(x * x + y * y);
double sgn(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

/// Góc chênh trong (-π, π].
double angDiff(double a, double b) {
  var d = a - b;
  while (d > math.pi) {
    d -= tau;
  }
  while (d < -math.pi) {
    d += tau;
  }
  return d;
}

/// hit() của funcore: hai hộp tâm (x, y) cỡ w×h chạm nhau (thu nhỏ theo s).
bool hitBox(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh, [double s = .7]) =>
    (ax - bx).abs() < (aw + bw) / 2 * s && (ay - by).abs() < (ah + bh) / 2 * s;

/// Màu từ 0xRRGGBB.
Color hex(int rgb, [double a = 1]) => Color(0xFF000000 | rgb).withValues(alpha: a);
Color rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a.clamp(0, 1).toDouble());
Color hsl(double h, double s, double l) => HSLColor.fromAHSL(1, h % 360, s, l).toColor();

// ---------- Easing (E của motionb) ----------
double c01(double t) => t < 0 ? 0 : (t > 1 ? 1 : t);
double outCubic(double t) => 1 - math.pow(1 - c01(t), 3).toDouble();
double inCubic(double t) => math.pow(c01(t), 3).toDouble();
double outBack(double t) {
  t = c01(t);
  const c = 1.70158;
  return 1 + (c + 1) * math.pow(t - 1, 3) + c * math.pow(t - 1, 2);
}

double bump(double t) => math.sin(c01(t) * math.pi);

// ---------- Vẽ cơ bản ----------
final Paint _fill = Paint()..isAntiAlias = true;
final Paint _stroke = Paint()
  ..style = PaintingStyle.stroke
  ..isAntiAlias = true;

Paint fillP(Color c) => _fill
  ..color = c
  ..shader = null;
Paint strokeP(Color c, double w, {StrokeCap cap = StrokeCap.butt, StrokeJoin join = StrokeJoin.miter}) => _stroke
  ..color = c
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = join
  ..shader = null;

RRect rr(double x, double y, double w, double h, double r) {
  final rad = math.max(0.0, math.min(r, math.min(w.abs(), h.abs()) / 2));
  return RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));
}

void fillRR(Canvas c, double x, double y, double w, double h, double r, Color col) {
  if (w <= 0 || h <= 0) return;
  c.drawRRect(rr(x, y, w, h, r), fillP(col));
}

void circle(Canvas c, double x, double y, double r, Color col) => c.drawCircle(Offset(x, y), math.max(0, r), fillP(col));
void strokeCircle(Canvas c, double x, double y, double r, Color col, double w) => c.drawCircle(Offset(x, y), math.max(0, r), strokeP(col, w));
void ellipse(Canvas c, double x, double y, double rx, double ry, Color col, [double rot = 0]) {
  if (rx <= 0 || ry <= 0) return;
  if (rot == 0) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), fillP(col));
    return;
  }
  c.save();
  c.translate(x, y);
  c.rotate(rot);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), fillP(col));
  c.restore();
}

void rect(Canvas c, double x, double y, double w, double h, Color col) => c.drawRect(Rect.fromLTWH(x, y, w, h), fillP(col));
void line(Canvas c, double x0, double y0, double x1, double y1, Color col, double w, [StrokeCap cap = StrokeCap.round]) =>
    c.drawLine(Offset(x0, y0), Offset(x1, y1), strokeP(col, w, cap: cap));

/// Bóng đổ elip (shadow() của motionb).
void shadow(Canvas c, double x, double y, double w, [double lift = 0, double a = .22]) {
  final k = 1 / (1 + math.max(0, lift) / 120);
  ellipse(c, x, y, w * k, w * .28 * k, rgba(0, 0, 0, a * k));
}

// ---------- Chữ ----------
enum TA { left, center, right }

class Txt {
  static final Map<String, TextPainter> _cache = {};

  static TextPainter _tp(String s, double size, FontWeight w, Color color, {double strokeW = 0}) {
    final key = '$s|${size.round()}|${w.value}|${color.toARGB32()}|${strokeW.round()}';
    var tp = _cache[key];
    if (tp != null) return tp;
    final style = strokeW > 0
        ? TextStyle(
            fontFamily: kFontFamily,
            fontSize: size.roundToDouble(),
            fontWeight: w,
            height: 1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeW
              ..strokeJoin = StrokeJoin.round
              ..color = color)
        : TextStyle(fontFamily: kFontFamily, fontSize: size.roundToDouble(), fontWeight: w, color: color, height: 1);
    tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return _cache[key] = tp;
  }

  static double width(String s, double size, [FontWeight w = FontWeight.w800]) {
    _trim();
    return _tp(s, size, w, const Color(0xFFFFFFFF)).width;
  }

  /// Bộ đệm quá lớn thì xoá (chỉ gọi trước khi lấy painter, không giữa chừng).
  static void _trim() {
    if (_cache.length > 400) clear();
  }

  /// Vẽ chữ: (x, y) = điểm neo theo align, y là đường chân chữ (như ctx.fillText).
  static void draw(Canvas c, String s, double x, double y,
      {double size = 26, Color color = Colors.white, FontWeight w = FontWeight.w800, TA align = TA.center, Color? stroke, double strokeW = 4, double alpha = 1}) {
    if (s.isEmpty || size < 1) return;
    _trim();
    final a = (alpha.clamp(0, 1) * 16).round() / 16;
    if (a <= 0) return;
    final col = a < 1 ? color.withValues(alpha: color.a * a) : color;
    final tp = _tp(s, size, w, col);
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = align == TA.left ? x : (align == TA.center ? x - tp.width / 2 : x - tp.width);
    if (stroke != null) {
      final sc = a < 1 ? stroke.withValues(alpha: stroke.a * a) : stroke;
      _tp(s, size, w, sc, strokeW: strokeW).paint(c, Offset(dx, y - base));
    }
    tp.paint(c, Offset(dx, y - base));
  }

  static void clear() {
    for (final t in _cache.values) {
      t.dispose();
    }
    _cache.clear();
  }
}

// ---------- Hình ----------
/// Hình emoji + sprite sheet đã nạp cho một game.
class Gfx {
  Gfx([Map<String, ui.Image>? imgs, Map<String, SpriteSheet?>? sheets])
      : imgs = imgs ?? {},
        sheets = sheets ?? {};
  final Map<String, ui.Image> imgs;
  final Map<String, SpriteSheet?> sheets;

  /// Nạp hình + sheet (lỗi bỏ qua).
  static Future<Gfx> load(Iterable<String> imgNames, Iterable<String> sheetNames) async {
    final sn = sheetNames.toSet().toList();
    final res = await Future.wait([loadEmojiUiImages(imgNames.where((e) => e.isNotEmpty)), loadSheets(sn)]);
    final imgs = res[0] as Map<String, ui.Image>;
    final sl = res[1] as List<SpriteSheet?>;
    return Gfx(imgs, {for (var i = 0; i < sn.length; i++) sn[i]: sl[i]});
  }

  SpriteSheet? sh(String name) => sheets[name];

  /// draw(ctx, name, x, y, w, h, {flip, rot, alpha}) của funcore.
  void draw(Canvas c, String? name, double x, double y, double w, [double? h, bool flip = false, double rot = 0, double alpha = 1]) {
    if (name == null || alpha <= 0) return;
    drawImageCentered(c, imgs[name], x, y, w, h ?? w, flip, rot, math.min(1, alpha));
  }

  /// spr() của funfx: khung theo chiều cao h. Trả false nếu không vẽ được.
  bool spr(Canvas c, SpriteSheet? s, String frame, double x, double y, double h, {double rot = 0, double alpha = 1, bool flip = false}) {
    if (s == null || alpha <= 0) return false;
    return drawFrame(c, s, frame, x, y, h, rot: rot, alpha: math.min(1, alpha), flip: flip);
  }

  bool anim(Canvas c, SpriteSheet? s, String name, double t, double x, double y, double h, {double rot = 0, double alpha = 1, bool flip = false}) {
    if (s == null || s.frames.isEmpty) return false;
    return spr(c, s, frameAt(s, name, t), x, y, h, rot: rot, alpha: alpha, flip: flip);
  }

  /// Lát kín vùng bằng một khung vuông (tile() của funfx).
  void tile(Canvas c, SpriteSheet? s, String frame, double size, double offX, double offY, double x0, double y0, double w, double h) {
    final f = s?.frames[frame];
    final im = s?.image;
    if (f == null || im == null) return;
    final sx = -(((offX % size) + size) % size), sy = -(((offY % size) + size) % size);
    final src = Rect.fromLTWH(f[0], f[1], f[2], f[3]);
    final p = Paint()..filterQuality = FilterQuality.low;
    for (var y = y0 + sy; y < y0 + h; y += size - .5) {
      for (var x = x0 + sx; x < x0 + w; x += size - .5) {
        c.drawImageRect(im, src, Rect.fromLTWH(x, y, size, size), p);
      }
    }
  }

  /// Đồng xu xoay (coin() của funfx, khung 'coin' của fxa/fx).
  void coin(Canvas c, SpriteSheet? fxs, double t, double x, double y, double s) {
    final f = fxs?.frames['coin'];
    final im = fxs?.image;
    if (f == null || im == null) {
      circle(c, x, y, s / 2, hex(0xffd43b));
      return;
    }
    final k = math.cos(t * 4), w = s * math.max(.18, k.abs());
    c.drawImageRect(im, Rect.fromLTWH(f[0], f[1], f[2], f[3]), Rect.fromLTWH(x - w / 2, y - s / 2, w, s), Paint()..filterQuality = FilterQuality.medium);
  }
}

// ---------- Hiệu ứng ----------
class _FxP {
  _FxP(this.x, this.y, this.vx, this.vy, this.life, this.c, this.r, {this.text, this.star = false});
  double x, y, vx, vy, life, r;
  Color c;
  String? text;
  bool star;
}

/// fx() của funcore: hạt lấp lánh + chữ bay lên + sao.
class Fx {
  Fx(this.g);
  final Gfx g;
  final List<_FxP> _parts = [];
  static const _cols = [0xffd43b, 0xff922b, 0xff6b6b, 0x74c0fc, 0xb197fc];

  void burst(double x, double y, [int n = 14, List<int>? colors]) {
    final cs = colors ?? _cols;
    for (var i = 0; i < n; i++) {
      final a = rnd01() * tau, v = rnd(120, 320);
      _parts.add(_FxP(x, y, math.cos(a) * v, math.sin(a) * v, rnd(.4, .8), hex(pickOf(cs)), rnd(3, 7)));
    }
    if (_parts.length > 400) _parts.removeRange(0, _parts.length - 400);
  }

  void text(double x, double y, String s, [int c = 0xffffff]) => _parts.add(_FxP(x, y, 0, -70, .9, hex(c), 0, text: s));
  void star(double x, double y) => _parts.add(_FxP(x, y, rnd(-40, 40), -160, .9, Colors.white, 0, star: true));

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

  void draw(Canvas c) {
    for (final p in _parts) {
      final a = clamp(p.life * 1.6);
      if (p.text != null) {
        Txt.draw(c, p.text!, p.x, p.y, size: 26, color: p.c, stroke: rgba(0, 0, 0, .35), strokeW: 4, alpha: a);
      } else if (p.star) {
        g.draw(c, 'Glowing star', p.x, p.y, 34, 34, false, 0, a);
      } else {
        circle(c, p.x, p.y, p.r, p.c.withValues(alpha: a));
      }
    }
  }
}

class _DustP {
  bool on = false;
  double x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, r = 4, grow = 0, g = 0, a = 1;
  int k = 0;
  Color c = Colors.white;
}

/// dust() của funfx: bể hạt cấp sẵn. k: 0 khói tròn to dần, 1 tia, 2 vụn rơi.
class Dust {
  Dust([int n = 220]) : _p = List.generate(n, (_) => _DustP());
  final List<_DustP> _p;
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

  void sparks(double x, double y, [int n = 12, int c = 0xffd43b, double sp = 260]) {
    for (var i = 0; i < n; i++) {
      final a = rnd01() * tau, v = sp * (.4 + rnd01() * .8);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .25 + rnd01() * .3, r: 2.5, grow: 0, c: hex(c), k: 1, a: 1);
    }
  }

  void puff(double x, double y, [int n = 6, Color c = const Color(0xFFE6E6E6), double sp = 60, double r = 8]) {
    for (var i = 0; i < n; i++) {
      final a = rnd01() * tau, v = sp * rnd01();
      emit(x, y, math.cos(a) * v, math.sin(a) * v - 20, life: .5 + rnd01() * .4, r: r * (.6 + rnd01() * .6), grow: r * 3, c: c, a: .55);
    }
  }

  void debris(double x, double y, [int n = 10, int c = 0x8d5524, double sp = 300]) {
    for (var i = 0; i < n; i++) {
      final a = -rnd01() * 3.14, v = sp * (.4 + rnd01() * .7);
      emit(x, y, math.cos(a) * v, math.sin(a) * v, life: .6 + rnd01() * .4, r: 3 + rnd01() * 3, grow: 0, c: hex(c), k: 2, g: 900, a: 1);
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
    for (final p in _p) {
      if (!p.on) continue;
      final k = p.life / p.max;
      final a = p.a * (p.k == 0 ? k : math.min(1, k * 2));
      final col = p.c.withValues(alpha: p.c.a * a);
      if (p.k == 1) {
        line(c, p.x - ox, p.y - oy, p.x - ox - p.vx * .04, p.y - oy - p.vy * .04, col, p.r, StrokeCap.butt);
      } else {
        circle(c, p.x - ox, p.y - oy, p.r + p.grow * (1 - k), col);
      }
    }
  }

  void clear() {
    for (final p in _p) {
      p.on = false;
    }
  }
}

class _Boom {
  bool on = false;
  double x = 0, y = 0, s = 0, t = 0, rot = 0;
  String k = 'boom';
}

/// booms() của funfx: nổ bằng sprite fxa/fx (boom, smoke).
class Booms {
  Booms(this.g, this.fxs, [int n = 24]) : _b = List.generate(n, (_) => _Boom());
  final Gfx g;
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
      ..rot = rnd01() * 6.28;
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
      final s = b.s * (.7 + easeOutC(math.min(1, k * 1.6)) * .5);
      if (!g.anim(c, fxs, b.k, b.t, b.x - ox, b.y - oy, s, rot: b.rot, alpha: k > .7 ? (1 - k) / .3 : 1)) {
        circle(c, b.x - ox, b.y - oy, s * .4, (b.k == 'smoke' ? hex(0xced4da) : hex(0xff922b)).withValues(alpha: 1 - k));
      }
    }
  }
}

double easeOutC(double k) => 1 - (1 - k) * (1 - k) * (1 - k);

/// shaker() của funfx: rung màn mượt.
class Shaker {
  double p = 0, t = 0;
  void add(double k) => p = math.min(18, p + k);
  void update(double dt) {
    t += dt;
    p = math.max(0, p - dt * (p * 4 + 8));
  }

  void apply(Canvas c) {
    if (p > .2) c.translate(math.sin(t * 61) * p, math.cos(t * 47) * p * .8);
  }
}

/// camera() của motionb: rung + dừng hình.
class Camera {
  double mag = 0, ox = 0, oy = 0, hold = 0, ph = 0;
  void shake(double v) => mag = math.min(22, mag + v);
  void stop(double s) => hold = math.max(hold, s);
  double scale(double dt) {
    if (hold > 0) {
      hold -= dt;
      return .08;
    }
    return 1;
  }

  void update(double dt) {
    ph += dt * 60;
    mag *= math.exp(-dt * 9);
    if (mag < .25) mag = 0;
    ox = math.sin(ph * 1.7) * mag;
    oy = math.cos(ph * 2.3) * mag * .8;
  }

  void begin(Canvas c) {
    c.save();
    if (mag != 0) c.translate(ox, oy);
  }

  void end(Canvas c) => c.restore();
}

class _BP {
  _BP(this.k, this.x, this.y, this.life, this.c, {this.vx, this.vy = 0, this.g = 0, this.r = 0, this.w = 0, this.s = '', this.size = 26});
  final int k;
  double x, y, life, r, w;
  double? vx;
  double vy, g, size;
  Color c;
  String s;
  late double lz;
}

/// fxb() của motionb: hạt, bụi, tia, vòng sóng, chữ/số nảy.
class Fxb {
  final List<_BP> _p = [];
  void _add(_BP p, double l0) {
    p.lz = l0;
    if (_p.length > 260) _p.removeAt(0);
    _p.add(p);
  }

  static const _cols = [0xffd43b, 0xff922b, 0xff6b6b, 0x74c0fc];

  void burst(double x, double y, [int n = 12, List<int>? colors, double sp = 260, double g = 500]) {
    final cs = colors ?? _cols;
    for (var i = 0; i < n; i++) {
      final a = rnd01() * 6.283, v = rnd(.35, 1) * sp;
      _add(_BP(0, x, y, rnd(.35, .75), hex(cs[i % cs.length]), vx: math.cos(a) * v, vy: math.sin(a) * v - sp * .25, g: g, r: rnd(2.5, 6)), .75);
    }
  }

  void dust(double x, double y, [int n = 5, double dir = 0, Color c = const Color(0xBFFFFFFF)]) {
    for (var i = 0; i < n; i++) {
      _add(_BP(1, x + rnd(-8, 8), y - rnd(0, 6), rnd(.35, .6), c, vx: (dir != 0 ? dir : rnd(-1, 1)) * rnd(30, 110), vy: -rnd(10, 50), g: -20, r: rnd(5, 10)), .6);
    }
  }

  void sparks(double x, double y, [int n = 8, int c = 0xfff3bf, double? dir]) {
    for (var i = 0; i < n; i++) {
      final a = dir == null ? rnd01() * 6.283 : dir + rnd(-.9, .9), v = rnd(280, 560);
      _add(_BP(2, x, y, rnd(.12, .25), hex(c), vx: math.cos(a) * v, vy: math.sin(a) * v), .25);
    }
  }

  void ring(double x, double y, [double r = 40, int c = 0xffffff, double w = 6, double life = .35]) => _add(_BP(3, x, y, life, hex(c), r: r, w: w), life);

  void num(double x, double y, String v, {bool crit = false, int c = 0xffffff, double size = 26}) =>
      _add(_BP(4, x + rnd(-10, 10), y, .9, hex(crit ? 0xffd43b : c), vx: rnd(-30, 30), vy: -150, g: 260, s: v, size: crit ? size * 1.35 : size), .9);

  void text(double x, double y, String s, [int c = 0xffffff, double size = 30]) => _add(_BP(4, x, y, 1.1, hex(c), vx: 0, vy: -70, s: s, size: size), 1.1);

  void update(double dt) {
    for (var i = _p.length - 1; i >= 0; i--) {
      final p = _p[i];
      p.life -= dt;
      if (p.life <= 0) {
        _p.removeAt(i);
        continue;
      }
      if (p.vx != null) {
        p.vy += p.g * dt;
        p.x += p.vx! * dt;
        p.y += p.vy * dt;
        if (p.k == 1) {
          p.vx = p.vx! * (1 - dt * 3);
          p.r += dt * 14;
        }
      }
    }
  }

  void draw(Canvas c) {
    for (final p in _p) {
      final k = p.life / p.lz;
      final a = math.min(1.0, k * 1.8);
      switch (p.k) {
        case 0:
          circle(c, p.x, p.y, p.r * (.4 + k * .6), p.c.withValues(alpha: a));
        case 1:
          circle(c, p.x, p.y, p.r, p.c.withValues(alpha: p.c.a * k * .7));
        case 2:
          line(c, p.x, p.y, p.x - p.vx! * .04, p.y - p.vy * .04, p.c.withValues(alpha: a), 3);
        case 3:
          final e = outCubic(1 - k);
          strokeCircle(c, p.x, p.y, p.r * (.3 + e), p.c.withValues(alpha: a), p.w * k + .5);
        case 4:
          final age = (p.lz - p.life) / .25, sc = age < 1 ? .3 + outBack(age) * .7 : 1.0;
          Txt.draw(c, p.s, p.x, p.y, size: (p.size * sc).roundToDouble(), color: p.c, w: FontWeight.w900, stroke: rgba(0, 0, 0, .55), strokeW: 5, alpha: a);
      }
    }
  }

  int get n => _p.length;
}

// ---------- HUD (funcore) ----------
const int kLives = 5;

void hud(Canvas c, Gfx g, double w, {required int score, int lives = 0, double? time, double? bossHp, double? bossMax}) {
  final narrow = w < 520, hs = narrow ? 22.0 : 30.0, hg = narrow ? 25.0 : 36.0, tw = narrow ? 90.0 : 100.0;
  fillRR(c, 12, 10, narrow ? 112 : 150, 44, 22, rgba(0, 0, 0, .28));
  g.draw(c, 'Coin', 38, 32, 30);
  Txt.draw(c, '$score', 60, 42, size: 28, align: TA.left);
  if (lives > 0) {
    for (var i = 0; i < kLives; i++) {
      g.draw(c, 'Red heart', w - (narrow ? 30 : 40) - i * hg, 32, hs, hs, false, 0, i < lives ? 1 : .22);
    }
  }
  if (time != null) {
    fillRR(c, w / 2 - tw / 2, 10, tw, 44, 22, rgba(0, 0, 0, .28));
    Txt.draw(c, '⏱ ${time.ceil()}', w / 2, 42, size: 28);
  }
  if (bossHp != null && bossMax != null) {
    final bw = math.min(360.0, w * .5);
    fillRR(c, w / 2 - bw / 2, 62, bw, 18, 9, rgba(0, 0, 0, .35));
    fillRR(c, w / 2 - bw / 2 + 3, 65, (bw - 6) * math.max(0, bossHp / bossMax), 12, 6, hex(0xff6b6b));
  }
}

void banner(Canvas c, double w, double h, String text, [String? sub]) {
  rect(c, 0, h / 2 - 70, w, 140, rgba(0, 0, 0, .35));
  final big = _fit(text, 54, w - 24);
  Txt.draw(c, text, w / 2, h / 2 + (sub != null ? 0 : 18), size: big);
  if (sub != null && sub.isNotEmpty) Txt.draw(c, sub, w / 2, h / 2 + 42, size: _fit(sub, 26, w - 24, FontWeight.w700), w: FontWeight.w700);
}

double _fit(String s, double size, double maxW, [FontWeight wt = FontWeight.w800]) {
  var px = size;
  while (px > 11 && Txt.width(s, px, wt) > maxW) {
    px -= 2;
  }
  return px;
}

/// Màn mở đầu: cấp + mục tiêu + dòng hướng dẫn.
void levelBanner(Canvas c, double w, double h, int lv, String goal, [String? hint]) {
  rect(c, 0, h / 2 - 90, w, 180, rgba(0, 0, 0, .4));
  Txt.draw(c, 'CẤP ${lv + 1}', w / 2, h / 2 - 22, size: 50, color: hex(0xffd43b));
  final g = '🎯 $goal';
  Txt.draw(c, g, w / 2, h / 2 + 20, size: _fit(g, 28, w - 24));
  if (hint != null) Txt.draw(c, hint, w / 2, h / 2 + 58, size: _fit(hint, 20, w - 24, FontWeight.w700), w: FontWeight.w700, color: rgba(255, 255, 255, .85));
}

void goalPill(Canvas c, double w, int now, int need, [double y = 62]) {
  if (w < 640) y = math.max(y, 62);
  final ok = now >= need;
  fillRR(c, w / 2 - 70, y, 140, 36, 18, ok ? rgba(47, 158, 68, .85) : rgba(0, 0, 0, .28));
  Txt.draw(c, ok ? '🎯 $need ✔' : '🎯 $now/$need', w / 2, y + 26, size: 22);
}

/// Nền vẽ sẵn (prerender của motionb): ghi lệnh vẽ một lần thành ảnh.
class Prerendered {
  Prerendered(double w, double h, void Function(Canvas c) fn) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    fn(c);
    _pic = rec.endRecording();
  }
  late final ui.Picture _pic;
  void draw(Canvas c) => c.drawPicture(_pic);
  void dispose() => _pic.dispose();
}

// ---------- Vòng lặp game (Flame) ----------
/// Một ngón tay trên màn (multi() của funvs1): toạ độ hiện tại + lúc chạm.
class Ptr {
  Ptr(this.id, this.x, this.y)
      : sx = x,
        sy = y;
  final int id;
  double x, y;
  final double sx, sy;
  String? btn;
  int side = -1;
}

class _Later {
  _Later(this.t, this.fn);
  double t;
  final VoidCallback fn;
}

/// Lớp nền cho mọi game của G: Flame Game vẽ bằng Canvas, logic như loop({update, draw}) của web.
abstract class ActGame extends Game {
  ActGame({required this.audio, required this.lv, required this.gfx});
  final AudioService audio;
  final int lv;
  final Gfx gfx;
  late double W, H, S;
  bool ready = false, ended = false;

  /// Đồng hồ thực (giây) thay performance.now()/1000.
  double clock = 0;
  bool Function() alive = () => true;
  void Function(Object result)? onEnd;
  final Map<int, Ptr> pts = {};
  final List<_Later> _later = [];

  void sfx(String n) => audio.sfx(n);

  /// setTimeout trong thời gian game (chạy trong tick, dừng khi game dừng).
  void later(double sec, VoidCallback fn) => _later.add(_Later(sec, fn));

  /// Đặt kích thước (canvasIn: tối thiểu 320) rồi dựng màn.
  void layout(double w, double h) {
    W = math.max(320, w);
    H = math.max(320, h);
    S = math.min(W, H);
    setup();
    ready = true;
  }

  void setup();

  /// Một bước; trả kết quả (khác null) khi xong.
  Object? step(double dt);
  void paint(Canvas c);

  /// Dừng (thoát hoặc xong): tắt tiếng động cơ...
  void onStop() {}

  final List<Prerendered> _pre = [];

  /// Nền vẽ sẵn một lần (prerender của motionb); giải phóng khi widget bị gỡ.
  Prerendered prerender(void Function(Canvas c) fn) {
    final p = Prerendered(W, H, fn);
    _pre.add(p);
    return p;
  }

  /// Widget bị gỡ: giải phóng tài nguyên vẽ.
  void disposeGfx() {
    for (final p in _pre) {
      p.dispose();
    }
    _pre.clear();
  }

  void down(Ptr p) {}
  void move(Ptr p) {}
  void up(Ptr p) {}

  /// Tiến một khung (dt đã giới hạn 0.05 như web).
  void tick(double dt) {
    if (!ready || ended) return;
    if (!alive()) {
      ended = true;
      onStop();
      return;
    }
    final d = math.min(.05, dt);
    clock += d;
    if (_later.isNotEmpty) {
      for (final l in [..._later]) {
        l.t -= d;
        if (l.t <= 0) {
          _later.remove(l);
          l.fn();
        }
      }
    }
    final r = step(d);
    if (r != null) {
      ended = true;
      onStop();
      onEnd?.call(r);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!ready && size.x > 0 && size.y > 0) layout(size.x, size.y);
  }

  @override
  void update(double dt) => tick(dt);

  double get _kx => hasLayout && size.x > 0 ? W / size.x : 1;
  double get _ky => hasLayout && size.y > 0 ? H / size.y : 1;

  @override
  void render(Canvas canvas) {
    if (!ready) return;
    canvas.save();
    if ((size.x - W).abs() > .5 || (size.y - H).abs() > .5) canvas.scale(size.x / W, size.y / H);
    canvas.clipRect(Rect.fromLTWH(0, 0, W, H));
    paint(canvas);
    canvas.restore();
  }

  /// Vẽ một khung lên canvas tạm (test).
  void paintOnce() {
    final rec = ui.PictureRecorder();
    paint(Canvas(rec));
    rec.endRecording().dispose();
  }

  // Cảm ứng (toạ độ widget → toạ độ game)
  void pointerDown(int id, Offset o) {
    if (!ready) return;
    final p = Ptr(id, o.dx * _kx, o.dy * _ky);
    pts[id] = p;
    down(p);
  }

  void pointerMove(int id, Offset o) {
    final p = pts[id];
    if (p == null) return;
    p.x = o.dx * _kx;
    p.y = o.dy * _ky;
    move(p);
  }

  void pointerUp(int id) {
    final p = pts.remove(id);
    if (p != null) up(p);
  }

  /// Test: chạy n giây với bước dt; dừng sớm khi xong. Trả kết quả nếu có.
  Object? runFor(double seconds, {double dt = 1 / 30, void Function()? each}) {
    Object? res;
    final old = onEnd;
    onEnd = (r) {
      res = r;
      old?.call(r);
    };
    for (var t = 0.0; t < seconds && !ended; t += dt) {
      each?.call();
      tick(dt);
    }
    onEnd = old;
    return res;
  }
}

/// Nút tròn trên canvas (buttons() của funvs1): down(id) đang giữ, hit(id) vừa bấm một lần.
class CBtn {
  CBtn(this.id, this.x, this.y, this.r, this.label, [this.c]);
  final String id, label;
  double x, y, r;
  final Color? c;
  bool hidden = false;
}

class CButtons {
  CButtons(this.game, this.list);
  final ActGame game;
  final List<CBtn> list;
  final Set<String> _hits = {};

  /// Gọi trong ActGame.down.
  bool press(Ptr p) {
    var any = false;
    for (final b in list) {
      if (!b.hidden && hypot(p.x - b.x, p.y - b.y) < b.r * 1.15) {
        _hits.add(b.id);
        p.btn = b.id;
        any = true;
      }
    }
    return any;
  }

  bool down(String id) {
    final b = list.where((q) => q.id == id).firstOrNull;
    if (b == null) return false;
    return game.pts.values.any((p) => hypot(p.x - b.x, p.y - b.y) < b.r * 1.25);
  }

  bool hit(String id) => _hits.remove(id);

  void draw(Canvas c) {
    for (final b in list) {
      if (b.hidden) continue;
      final on = down(b.id), r = b.r * (on ? .92 : 1);
      circle(c, b.x, b.y + (on ? 2 : 5), r, rgba(0, 0, 0, .18));
      circle(c, b.x, b.y + (on ? 2 : 0), r, on ? (b.c ?? hex(0xffd43b)) : rgba(255, 255, 255, .8));
      strokeCircle(c, b.x, b.y + (on ? 2 : 0), r, b.c ?? Colors.white, 4);
      Txt.draw(c, b.label, b.x, b.y + (on ? 2 : 0) + r * .32, size: r * .9, color: hex(0x212529));
    }
  }
}

// ---------- Widget ----------
/// Nhúng một ActGame: GameWidget + Listener nhiều ngón; xong thì gọi ctx.finish(toResult(r)) đúng một lần.
class ActGameView extends StatefulWidget {
  const ActGameView({super.key, required this.ctx, required this.game, required this.toResult, this.onResult});
  final FunGameContext ctx;
  final ActGame game;
  final FunResult Function(Object r) toResult;

  /// Gọi trước ctx.finish (vd. ghi phiên chơi).
  final void Function(FunResult r)? onResult;
  @override
  State<ActGameView> createState() => _ActGameViewState();
}

class _ActGameViewState extends State<ActGameView> {
  @override
  void initState() {
    super.initState();
    final g = widget.game;
    g.alive = () => mounted && widget.ctx.alive;
    g.onEnd = (r) {
      final res = widget.toResult(r);
      Future.microtask(() {
        widget.onResult?.call(res);
        widget.ctx.finish(res);
      });
    };
  }

  @override
  void dispose() {
    widget.game.ended = true;
    widget.game.onStop();
    widget.game.disposeGfx();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => g.pointerDown(e.pointer, e.localPosition),
      onPointerMove: (e) => g.pointerMove(e.pointer, e.localPosition),
      onPointerUp: (e) => g.pointerUp(e.pointer),
      onPointerCancel: (e) => g.pointerUp(e.pointer),
      child: GameWidget(game: g),
    );
  }
}

/// Phiên chơi trong một vé: các cấp liên tiếp (thắng → cấp sau) dùng chung dữ liệu (opts của web).
class ActSession {
  int lastLevel = -99, chain = 0;
  bool won = false, open = false;
  Map<String, Object?> data = {};

  /// true nếu đây là cấp đầu của vé (hiện Gara / Xưởng / chọn chế độ).
  bool first = true;
}

final Map<String, ActSession> _sessions = {};

/// Lấy phiên cho ctx: tiếp nối nếu cấp trước vừa thắng và đây là cấp kế tiếp (tối đa 3 cấp/vé).
ActSession actSession(FunGameContext ctx) {
  final key = '${ctx.gameId}|${identityHashCode(ctx.store)}|${ctx.profile.json['id']}';
  final s = _sessions[key] ??= ActSession();
  final cont = s.open && s.won && ctx.level == s.lastLevel + 1 && s.chain < kLevelsPerTicket;
  if (!cont) {
    s
      ..chain = 0
      ..data = {}
      ..first = true;
  } else {
    s.first = false;
  }
  s.open = false;
  return s;
}

/// Ghi kết quả một cấp vào phiên.
void actSessionDone(ActSession s, FunGameContext ctx, FunResult r) {
  s
    ..lastLevel = ctx.level
    ..won = r.win && !r.pvp
    ..chain = s.chain + 1
    ..open = true;
}

/// Xoá mọi phiên (test).
void actSessionsReset() => _sessions.clear();

/// Màn chờ nạp hình.
class ActLoading extends StatelessWidget {
  const ActLoading({super.key, this.color = const Color(0xFF1C2A5A)});
  final Color color;
  @override
  Widget build(BuildContext context) => ColoredBox(color: color, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
}

/// clamp số nguyên từ JSON (num() của web).
int jInt(Object? v, [int a = 0, int b = 1 << 30]) {
  final n = v is num ? v.floor() : (v is String ? (double.tryParse(v) ?? 0).floor() : 0);
  return n < a ? a : (n > b ? b : n);
}

/// Dùng ngẫu nhiên có trọng số chung.
double rampD(int lv, double a, double b) => u.ramp(lv, a, b);
