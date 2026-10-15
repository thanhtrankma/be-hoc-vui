// Lớp mỏng mô phỏng CanvasRenderingContext2D của web trên dart:ui Canvas, để port game canvas (funnew*, funhero)
// gần như từng dòng: fillStyle/strokeStyle nhận chuỗi màu CSS ('#ffd43b', 'rgba(0,0,0,.3)', 'hsl(120,85%,62%)')
// hoặc Grad (createLinearGradient/createRadialGradient); globalAlpha, save/restore, path, chữ (font '800 28px').
// CHỦ: agent F (lib/features/fun/more/). Không phụ thuộc file của agent khác.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/ui/theme.dart' show kFontFamily;
import 'package:flutter/painting.dart';

// ---------- Màu CSS ----------
final Map<String, Color> _colorCache = {};

/// Đọc màu CSS: #rgb, #rrggbb, #rrggbbaa, rgb(), rgba(), hsl(), hsla(), vài tên màu.
Color cssColor(String s) {
  final hit = _colorCache[s];
  if (hit != null) return hit;
  if (_colorCache.length > 3000) _colorCache.clear();
  return _colorCache[s] = _parseCss(s.trim());
}

const Map<String, int> _named = {
  'white': 0xFFFFFFFF, 'black': 0xFF000000, 'red': 0xFFFF0000, 'transparent': 0x00000000, 'gold': 0xFFFFD700,
  'yellow': 0xFFFFFF00, 'blue': 0xFF0000FF, 'green': 0xFF008000, 'orange': 0xFFFFA500, 'gray': 0xFF808080, 'grey': 0xFF808080,
};

Color _parseCss(String s) {
  if (s.startsWith('#')) {
    var h = s.substring(1);
    if (h.length == 3 || h.length == 4) h = h.split('').map((c) => '$c$c').join();
    final v = int.tryParse(h, radix: 16) ?? 0;
    if (h.length == 8) return Color(((v & 0xFF) << 24) | (v >> 8));
    return Color(0xFF000000 | v);
  }
  final m = RegExp(r'^(rgba?|hsla?)\((.*)\)$').firstMatch(s);
  if (m != null) {
    final parts = m[2]!.split(RegExp(r'[,\s/]+')).where((e) => e.isNotEmpty).toList();
    double num(int i, [double d = 0]) {
      if (i >= parts.length) return d;
      final p = parts[i];
      if (p.endsWith('%')) return (double.tryParse(p.substring(0, p.length - 1)) ?? 0) / 100;
      return double.tryParse(p) ?? d;
    }

    final a = num(3, 1).clamp(0.0, 1.0);
    if (m[1]!.startsWith('rgb')) {
      return Color.fromRGBO(num(0).round().clamp(0, 255), num(1).round().clamp(0, 255), num(2).round().clamp(0, 255), a);
    }
    final hsl = HSLColor.fromAHSL(a, num(0) % 360, num(1).clamp(0.0, 1.0), num(2).clamp(0.0, 1.0));
    return hsl.toColor();
  }
  return Color(_named[s] ?? 0xFF000000);
}

/// Màu → chuỗi CSS (để lưu vào fillStyle khi có sẵn Color).
String cssOf(Color c) => 'rgba(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()},${c.a})';

/// Dải màu (CanvasGradient).
class Grad {
  Grad.linear(this.x0, this.y0, this.x1, this.y1)
      : radial = false,
        r0 = 0,
        r1 = 0,
        cx1 = 0,
        cy1 = 0;
  Grad.radial(this.x0, this.y0, this.r0, this.cx1, this.cy1, this.r1)
      : radial = true,
        x1 = 0,
        y1 = 0;
  final bool radial;
  final double x0, y0, x1, y1, r0, r1, cx1, cy1;
  final List<double> _stops = [];
  final List<Color> _colors = [];
  ui.Shader? _shader;
  void addColorStop(double at, Object color) {
    _stops.add(at.clamp(0.0, 1.0));
    _colors.add(color is Color ? color : cssColor(color.toString()));
    _shader = null;
  }

  ui.Shader get shader {
    if (_shader != null) return _shader!;
    final cols = _colors.isEmpty ? const [Color(0x00000000), Color(0x00000000)] : (_colors.length == 1 ? [_colors[0], _colors[0]] : _colors);
    final st = _colors.length < 2 ? const [0.0, 1.0] : _stops;
    if (radial) {
      // Gần đúng: tâm = điểm cuối, bán kính r1; r0 → điểm dừng đầu.
      final k0 = r1 <= 0 ? 0.0 : (r0 / r1).clamp(0.0, 1.0);
      return _shader = ui.Gradient.radial(Offset(cx1, cy1), math.max(.001, r1), cols, [for (final s in st) k0 + s * (1 - k0)]);
    }
    return _shader = ui.Gradient.linear(Offset(x0, y0), Offset(x1, y1), cols, st);
  }
}

class _State {
  _State(Ctx2D c)
      : fill = c.fillStyle,
        stroke = c.strokeStyle,
        lw = c.lineWidth,
        ga = c.globalAlpha,
        font = c.font,
        align = c.textAlign,
        base = c.textBaseline,
        cap = c.lineCap,
        join = c.lineJoin,
        dash = c._dash;
  final Object fill, stroke;
  final double lw, ga;
  final String font, align, base, cap, join;
  final List<double> dash;
}

class _TextKey {
  _TextKey(this.text, this.size, this.weight, this.color, this.strokeW);
  final String text;
  final double size;
  final int weight;
  final int color;
  final double strokeW;
  @override
  bool operator ==(Object o) => o is _TextKey && o.text == text && o.size == size && o.weight == weight && o.color == color && o.strokeW == strokeW;
  @override
  int get hashCode => Object.hash(text, size, weight, color, strokeW);
}

final Map<_TextKey, TextPainter> _textCache = {};

TextPainter _painter(String text, double size, int weight, Color color, double strokeW) {
  final key = _TextKey(text, size, weight, color.toARGB32(), strokeW);
  final hit = _textCache[key];
  if (hit != null) return hit;
  if (_textCache.length > 600) {
    for (final p in _textCache.values) {
      p.dispose();
    }
    _textCache.clear();
  }
  final fw = FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)];
  final style = strokeW > 0
      ? TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: fw, height: 1, foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeJoin = StrokeJoin.round
        ..color = color)
      : TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: fw, height: 1, color: color);
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
  return _textCache[key] = tp;
}

/// Bối cảnh vẽ kiểu Canvas 2D. Gán [canvas] mỗi khung rồi gọi các lệnh như web.
class Ctx2D {
  Ctx2D([ui.Canvas? canvas]) : _canvas = canvas;
  ui.Canvas? _canvas;
  ui.Canvas get canvas => _canvas!;
  set canvas(ui.Canvas c) {
    _canvas = c;
    reset();
  }

  /// Chuỗi màu CSS, Color, hoặc Grad.
  Object fillStyle = '#000';
  Object strokeStyle = '#000';
  double lineWidth = 1;
  double globalAlpha = 1;
  String font = '400 10px';
  String textAlign = 'left';
  String textBaseline = 'alphabetic';
  String lineCap = 'butt';
  String lineJoin = 'miter';

  /// Bỏ qua (web dùng một lần cho grayscale); giữ để port nguyên dòng.
  String filter = 'none';
  List<double> _dash = const [];
  final List<_State> _stack = [];
  ui.Path _path = ui.Path();
  final Paint _paint = Paint();

  void reset() {
    fillStyle = '#000';
    strokeStyle = '#000';
    lineWidth = 1;
    globalAlpha = 1;
    font = '400 10px';
    textAlign = 'left';
    textBaseline = 'alphabetic';
    lineCap = 'butt';
    lineJoin = 'miter';
    filter = 'none';
    _dash = const [];
    _stack.clear();
    _path = ui.Path();
    _hasPt = false;
  }

  // ---------- trạng thái ----------
  void save() {
    _stack.add(_State(this));
    canvas.save();
  }

  void restore() {
    if (_stack.isEmpty) return;
    final s = _stack.removeLast();
    fillStyle = s.fill;
    strokeStyle = s.stroke;
    lineWidth = s.lw;
    globalAlpha = s.ga;
    font = s.font;
    textAlign = s.align;
    textBaseline = s.base;
    lineCap = s.cap;
    lineJoin = s.join;
    _dash = s.dash;
    canvas.restore();
  }

  void translate(double x, double y) => canvas.translate(x, y);
  void rotate(double a) => canvas.rotate(a);
  void scale(double x, double y) => canvas.scale(x, y);
  void setLineDash(List<num> d) => _dash = d.map((e) => e.toDouble()).toList();

  // ---------- path ----------
  bool _hasPt = false;
  void beginPath() {
    _path = ui.Path();
    _hasPt = false;
  }

  void moveTo(double x, double y) {
    _path.moveTo(x, y);
    _hasPt = true;
  }

  void lineTo(double x, double y) {
    if (_hasPt) {
      _path.lineTo(x, y);
    } else {
      _path.moveTo(x, y);
    }
    _hasPt = true;
  }
  void closePath() => _path.close();
  void quadraticCurveTo(double cx, double cy, double x, double y) => _path.quadraticBezierTo(cx, cy, x, y);
  void bezierCurveTo(double c1x, double c1y, double c2x, double c2y, double x, double y) => _path.cubicTo(c1x, c1y, c2x, c2y, x, y);
  void rect(double x, double y, double w, double h) {
    _path.addRect(Rect.fromLTWH(x, y, w, h));
    _hasPt = true;
  }
  void arcTo(double x1, double y1, double x2, double y2, double r) => _path.arcToPoint(Offset(x2, y2), radius: Radius.circular(r));

  static double _sweep(double a0, double a1, bool ccw) {
    const tau = math.pi * 2;
    if (!ccw) {
      if (a1 - a0 >= tau) return tau;
      var s = (a1 - a0) % tau;
      if (s < 0) s += tau;
      return s;
    }
    if (a0 - a1 >= tau) return -tau;
    var s = (a0 - a1) % tau;
    if (s < 0) s += tau;
    return -s;
  }

  void arc(double x, double y, double r, double a0, double a1, [bool ccw = false]) {
    final rect = Rect.fromCircle(center: Offset(x, y), radius: math.max(0, r));
    final sw = _sweep(a0, a1, ccw);
    if (sw.abs() >= math.pi * 2 - 1e-6) {
      // Vòng tròn đủ: tách hai nửa để Path vẽ đúng (sweep 2π bị Skia coi là 0).
      _path.arcTo(rect, a0, math.pi * (sw > 0 ? 1 : -1), !_hasPt);
      _path.arcTo(rect, a0 + math.pi * (sw > 0 ? 1 : -1), math.pi * (sw > 0 ? 1 : -1), false);
      _hasPt = true;
      return;
    }
    _path.arcTo(rect, a0, sw, !_hasPt);
    _hasPt = true;
  }

  void ellipse(double x, double y, double rx, double ry, double rot, double a0, double a1, [bool ccw = false]) {
    rx = math.max(0, rx);
    ry = math.max(0, ry);
    final sw = _sweep(a0, a1, ccw);
    final full = sw.abs() >= math.pi * 2 - 1e-6;
    if (rot == 0) {
      final rect = Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2);
      if (full) {
        _path.addOval(rect);
      } else {
        _path.arcTo(rect, a0, sw, !_hasPt);
      }
      _hasPt = true;
      return;
    }
    final p = ui.Path();
    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    if (full) {
      p.addOval(rect);
    } else {
      p.arcTo(rect, a0, sw, true);
    }
    final m = Matrix4Lite.rotation(rot, x, y);
    _path.addPath(p.transform(m), Offset.zero);
    _hasPt = true;
  }

  /// roundRect() của funcore: bắt đầu path mới hình chữ nhật bo góc.
  void roundRectPath(double x, double y, double w, double h, double r) {
    _path = ui.Path();
    _hasPt = true;
    if (w < 0) {
      x += w;
      w = -w;
    }
    if (h < 0) {
      y += h;
      h = -h;
    }
    r = math.max(0, math.min(r, math.min(w, h) / 2));
    _path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
  }

  // ---------- tô / viền ----------
  Paint _fillPaint(Object style) {
    final p = _paint
      ..style = PaintingStyle.fill
      ..shader = null
      ..maskFilter = null;
    if (style is Grad) {
      p
        ..shader = style.shader
        ..color = Color.fromRGBO(0, 0, 0, globalAlpha.clamp(0.0, 1.0));
    } else {
      final c = style is Color ? style : cssColor(style.toString());
      p.color = globalAlpha >= 1 ? c : c.withValues(alpha: c.a * globalAlpha.clamp(0.0, 1.0));
    }
    return p;
  }

  Paint _strokePaint() {
    final p = _fillPaint(strokeStyle)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = lineCap == 'round' ? StrokeCap.round : (lineCap == 'square' ? StrokeCap.square : StrokeCap.butt)
      ..strokeJoin = lineJoin == 'round' ? StrokeJoin.round : (lineJoin == 'bevel' ? StrokeJoin.bevel : StrokeJoin.miter);
    return p;
  }

  void fill() {
    if (globalAlpha <= 0) return;
    canvas.drawPath(_path, _fillPaint(fillStyle));
  }

  void stroke() {
    if (globalAlpha <= 0) return;
    canvas.drawPath(_dash.isEmpty ? _path : _dashed(_path, _dash), _strokePaint());
  }

  static ui.Path _dashed(ui.Path src, List<double> dash) {
    final out = ui.Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0, i = 0;
      while (d < m.length) {
        final len = dash[i % dash.length];
        if (i.isEven) out.addPath(m.extractPath(d, d + len), Offset.zero);
        d += len;
        i++;
      }
    }
    return out;
  }

  void fillRect(double x, double y, double w, double h) {
    if (globalAlpha <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), _fillPaint(fillStyle));
  }

  void strokeRect(double x, double y, double w, double h) {
    if (globalAlpha <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), _strokePaint());
  }

  void clearRect(double x, double y, double w, double h) =>
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..blendMode = BlendMode.clear);

  Grad createLinearGradient(double x0, double y0, double x1, double y1) => Grad.linear(x0, y0, x1, y1);
  Grad createRadialGradient(double x0, double y0, double r0, double x1, double y1, double r1) => Grad.radial(x0, y0, r0, x1, y1, r1);

  // ---------- ảnh ----------
  /// drawImage(im, sx, sy, sw, sh, dx, dy, dw, dh).
  void drawImageRect(ui.Image im, double sx, double sy, double sw, double sh, double dx, double dy, double dw, double dh) {
    if (globalAlpha <= 0) return;
    final p = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(0, 0, 0, globalAlpha.clamp(0.0, 1.0));
    canvas.drawImageRect(im, Rect.fromLTWH(sx, sy, sw, sh), Rect.fromLTWH(dx, dy, dw, dh), p);
  }

  /// drawImage(im, dx, dy, dw, dh).
  void drawImage(ui.Image im, double dx, double dy, double dw, double dh) =>
      drawImageRect(im, 0, 0, im.width.toDouble(), im.height.toDouble(), dx, dy, dw, dh);

  // ---------- chữ ----------
  (double, int) _font() {
    final m = RegExp(r'(\d+)\s+([\d.]+)px').firstMatch(font);
    if (m != null) return (double.parse(m[2]!), int.parse(m[1]!));
    final s = RegExp(r'([\d.]+)px').firstMatch(font);
    return (s == null ? 10 : double.parse(s[1]!), font.contains('bold') ? 700 : 400);
  }

  double measureText(String text) {
    final (size, w) = _font();
    return _painter(text, size, w, const Color(0xFF000000), 0).width;
  }

  void _text(String text, double x, double y, Color color, double strokeW) {
    if (globalAlpha <= 0 || text.isEmpty) return;
    final (size, w) = _font();
    final col = globalAlpha >= 1 ? color : color.withValues(alpha: color.a * globalAlpha.clamp(0.0, 1.0));
    final tp = _painter(text, size, w, col, strokeW);
    var dx = x;
    if (textAlign == 'center') {
      dx -= tp.width / 2;
    } else if (textAlign == 'right' || textAlign == 'end') {
      dx -= tp.width;
    }
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    var dy = y - base;
    if (textBaseline == 'middle') {
      dy = y - tp.height / 2;
    } else if (textBaseline == 'top' || textBaseline == 'hanging') {
      dy = y;
    } else if (textBaseline == 'bottom') {
      dy = y - tp.height;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  void fillText(String text, double x, double y) {
    final s = fillStyle;
    _text(text, x, y, s is Color ? s : (s is Grad ? (s._colors.isEmpty ? const Color(0xFF000000) : s._colors.first) : cssColor(s.toString())), 0);
  }

  void strokeText(String text, double x, double y) {
    final s = strokeStyle;
    _text(text, x, y, s is Color ? s : cssColor(s.toString()), lineWidth);
  }
}

/// Ma trận 4x4 (Float64List) cho Path.transform: quay quanh (cx, cy).
class Matrix4Lite {
  static Float64List rotation(double a, double cx, double cy) {
    final c = math.cos(a), s = math.sin(a);
    return Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, cx, cy, 0, 1]);
  }
}
