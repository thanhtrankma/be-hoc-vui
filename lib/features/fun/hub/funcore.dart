// Lõi chung cho game canvas ở Khu vui chơi (port reference/web/js/games/funcore.js).
// CHỦ: agent E. API CÔNG KHAI, ỔN ĐỊNH — agent F/G có thể import (giữ nguyên chữ ký).
//
// Cách dùng (tương đương canvasIn + loop({update, draw}) của web):
// ```dart
// class CatchGame extends FunCanvasGame {
//   CatchGame(super.ctx);
//   @override List<String> get images => ['Basket', 'Red apple', ...];   // loadAll([...])
//   @override List<String> get sheetNames => ['plat/tiles'];             // sheets([...]) của funfx
//   @override void init() { /* W, H, S đã có: dựng màn */ }
//   @override FunResult? update(double dt) { ...; return end ? FunResult(score:, win:) : null; }
//   @override void paint(Canvas c) { img.draw(c, 'Basket', x, y, 80); hud(c, score: score); }
//   @override void pointerDown(Offset p, int id) { ... }
// }
// // trong FunGameModule.build():
// return FunCanvas(game: CatchGame(ctx));     // tự gọi ctx.finish(result) khi update() trả kết quả
// ```
// - Game bắt đầu ngay; hình/sheet nạp nền (vẽ bỏ qua khi chưa có — giống web khi ảnh lỗi).
// - dt kẹp 0.05 s như web; ctx.alive == false → dừng vòng lặp (không gọi finish).
// - Kiểm thử không cần widget: `game.setSize(800, 600); game.update(.05); game.pointerDown(...)`;
//   vẽ thử: `game.paint(Canvas(ui.PictureRecorder()))`.
// - Chữ trên canvas: FunText.draw (đệm TextPainter), song ngữ bằng tr('vi', 'en').
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/store/store.dart' show kFunMax;
import 'package:be_vui_hoc/core/ui/ui.dart';

export 'package:be_vui_hoc/core/game/fun_games.dart' show FunResult, FunGameContext, FunGameModule, FunTheme, funTheme, funThemeImgs, kLevelsPerTicket, funGameDef;
export 'package:be_vui_hoc/core/store/store.dart' show kFunMax;

/// Số tim mặc định trên HUD (LIVES).
const int kFunLives = 5;

const _font = kFontFamily;

/// Va chạm hai hộp tâm (x, y) cỡ w×h, s = hệ số thu nhỏ (hit() của funcore.js).
bool funHit(double ax, double ay, double aw, double ah, double bx, double by, double bw, double bh, [double s = .7]) =>
    (ax - bx).abs() < (aw + bw) / 2 * s && (ay - by).abs() < (ah + bh) / 2 * s;

/// Màu CSS '#rrggbb' → Color (tiện khi chép bảng màu từ web).
Color hexColor(String hex, [double alpha = 1]) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  return Color(int.parse(h, radix: 16) | 0xFF000000).withValues(alpha: alpha);
}

// ---------------------------------------------------------------------------------------------------------------
// Hình emoji cho canvas
// ---------------------------------------------------------------------------------------------------------------

/// Kho hình emoji đã giải mã (sprite()/loadAll()/draw() của funcore.js). Dùng chung: [FunImages.shared].
class FunImages {
  FunImages();
  static final FunImages shared = FunImages();
  final Map<String, ui.Image> _m = {};

  /// Nạp các hình còn thiếu (lỗi thì bỏ qua).
  Future<void> load(Iterable<String> names) async {
    final need = names.where((n) => n.isNotEmpty && !_m.containsKey(n)).toSet();
    if (need.isEmpty) return;
    _m.addAll(await loadEmojiUiImages(need));
  }

  ui.Image? operator [](String name) => _m[name];
  bool has(String name) => _m.containsKey(name);

  /// Vẽ hình tâm (x, y), rộng w, cao h (mặc định = w). Chưa nạp → bỏ qua.
  void draw(Canvas c, String name, double x, double y, double w, {double? h, bool flip = false, double rot = 0, double alpha = 1}) {
    final im = _m[name];
    if (im == null || alpha <= 0) return;
    drawImageCentered(c, im, x, y, w, h ?? w, flip, rot, alpha.clamp(0.0, 1.0));
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Chữ
// ---------------------------------------------------------------------------------------------------------------

/// Vẽ chữ lên canvas như ctx.fillText/strokeText (y = đường chân chữ). Có đệm TextPainter.
class FunText {
  FunText._();
  static final Map<String, (TextPainter, TextPainter?)> _cache = {};

  /// align: left/center/right theo điểm x (textAlign của canvas). stroke: viền chữ (strokeText).
  /// fit: bề rộng tối đa — chữ dài thu nhỏ cho vừa (fit() của levelBanner).
  static void draw(Canvas c, String text, double x, double y,
      {double size = 26, FontWeight weight = FontWeight.w800, Color color = Colors.white, TextAlign align = TextAlign.center, Color? stroke, double strokeWidth = 4, double? fit, double alpha = 1}) {
    if (text.isEmpty || alpha <= 0) return;
    final a = (alpha.clamp(0.0, 1.0) * 16).round() / 16;
    if (a <= 0) return;
    final col = color.withValues(alpha: color.a * a);
    final sc = stroke?.withValues(alpha: stroke.a * a);
    final key = '$text|${size.toStringAsFixed(1)}|${weight.value}|${col.toARGB32()}|${sc?.toARGB32()}|$strokeWidth';
    var e = _cache[key];
    if (e == null) {
      if (_cache.length > 400) _cache.clear();
      TextPainter mk(Paint? fg) => TextPainter(
            text: TextSpan(text: text, style: TextStyle(fontFamily: _font, fontSize: size, fontWeight: weight, color: fg == null ? col : null, foreground: fg, height: 1)),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
      e = (
        mk(null),
        sc == null
            ? null
            : mk(Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = sc),
      );
      _cache[key] = e;
    }
    final (fill, st) = e;
    final w = fill.width;
    final base = fill.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final k = fit != null && w > fit && w > 0 ? fit / w : 1.0;
    final dx = switch (align) { TextAlign.left || TextAlign.start => 0.0, TextAlign.right || TextAlign.end => -w, _ => -w / 2 };
    c.save();
    c.translate(x, y);
    if (k != 1) c.scale(k, k);
    final o = Offset(dx, -base);
    st?.paint(c, o);
    fill.paint(c, o);
    c.restore();
  }

  /// Bề rộng chữ (measureText).
  static double width(String text, {double size = 26, FontWeight weight = FontWeight.w800}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontFamily: _font, fontSize: size, fontWeight: weight)), textDirection: TextDirection.ltr)..layout();
    return tp.width;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Vẽ hình học
// ---------------------------------------------------------------------------------------------------------------

/// roundRect(ctx, x, y, w, h, r) + fill.
void fillRRect(Canvas c, double x, double y, double w, double h, double r, Color color) {
  if (w <= 0 || h <= 0) return;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.min(r, math.min(w, h) / 2))), Paint()..color = color);
}

/// roundRect + stroke.
void strokeRRect(Canvas c, double x, double y, double w, double h, double r, Color color, double width) {
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color);
}

/// Hình tròn tô màu.
void fillCircle(Canvas c, double x, double y, double r, Color color) => c.drawCircle(Offset(x, y), math.max(0, r), Paint()..color = color);

/// Elip tô màu tâm (x, y), bán trục rx, ry.
void fillEllipse(Canvas c, double x, double y, double rx, double ry, Color color) =>
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), Paint()..color = color);

/// Nền trời gradient dọc từ y=0 tới h (sky() của funmore.js).
void funSky(Canvas c, double w, double h, Color top, Color bottom, [double y0 = 0]) {
  c.drawRect(
      Rect.fromLTWH(0, y0, w, h - y0),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, y0), Offset(0, h), [top, bottom]));
}

const List<String> _themeEn = ['Meadow', 'Desert', 'Snowland', 'Night city', 'Candy forest', 'Volcano'];

/// Tên cảnh theo cấp, song ngữ (THEMES[].vi).
String funThemeName(int lv, [bool en = false]) => en ? _themeEn[(lv ~/ 10) % _themeEn.length] : funTheme(lv).vi;

/// Màu cảnh theo cấp (THEMES).
extension FunThemeColors on FunTheme {
  Color get skyTop => Color(sky[0]);
  Color get skyBottom => Color(sky[1]);
  Color get groundColor => Color(ground);
  Color get edgeColor => Color(edge);
}

// ---------------------------------------------------------------------------------------------------------------
// Hạt lấp lánh + chữ bay (fx())
// ---------------------------------------------------------------------------------------------------------------

class _Part {
  _Part(this.x, this.y, this.vx, this.vy, this.life, {this.c = Colors.white, this.r = 4, this.text, this.star = false});
  double x, y, vx, vy, life, r;
  Color c;
  String? text;
  bool star;
}

/// Hạt lấp lánh + chữ bay lên + sao (fx() của funcore.js).
class FunFx {
  FunFx([FunImages? images]) : img = images ?? FunImages.shared;
  final FunImages img;
  final List<_Part> _p = [];
  static const defaultColors = [Color(0xFFFFD43B), Color(0xFFFF922B), Color(0xFFFF6B6B), Color(0xFF74C0FC), Color(0xFFB197FC)];

  int get count => _p.length;

  void burst(double x, double y, [int n = 14, List<Color> colors = defaultColors]) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * math.pi * 2, v = rand(120, 320);
      _p.add(_Part(x, y, math.cos(a) * v, math.sin(a) * v, rand(.4, .8), c: pick(colors), r: rand(3, 7)));
    }
  }

  void text(double x, double y, String s, [Color c = Colors.white]) => _p.add(_Part(x, y, 0, -70, .9, text: s, c: c));
  void star(double x, double y) => _p.add(_Part(x, y, rand(-40, 40), -160, .9, star: true));

  void update(double dt) {
    for (var i = _p.length - 1; i >= 0; i--) {
      final p = _p[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += (p.text != null || p.star ? 0 : 300) * dt;
      p.life -= dt;
      if (p.life <= 0) _p.removeAt(i);
    }
  }

  void draw(Canvas c) {
    final paint = Paint();
    for (final p in _p) {
      final a = (p.life * 1.6).clamp(0.0, 1.0);
      if (p.text != null) {
        FunText.draw(c, p.text!, p.x, p.y, size: 26, color: p.c, stroke: const Color(0x59000000), alpha: a);
      } else if (p.star) {
        img.draw(c, 'Glowing star', p.x, p.y, 34, alpha: a);
      } else {
        c.drawCircle(Offset(p.x, p.y), p.r, paint..color = p.c.withValues(alpha: a));
      }
    }
  }

  void clear() => _p.clear();
}

// ---------------------------------------------------------------------------------------------------------------
// HUD, băng chữ
// ---------------------------------------------------------------------------------------------------------------

/// Ô điểm (xu) trái, tim phải, đồng hồ giữa, thanh máu trùm (hud() của funcore.js).
/// lives > 0: vẽ [kFunLives] tim; bossHp/bossMax: thanh máu trùm.
void funHud(Canvas c, double w, {required int score, int lives = 0, double? time, double? bossHp, double? bossMax, FunImages? images}) {
  final img = images ?? FunImages.shared;
  final narrow = w < 520, hs = narrow ? 22.0 : 30.0, hg = narrow ? 25.0 : 36.0, tw = narrow ? 90.0 : 100.0;
  fillRRect(c, 12, 10, narrow ? 112 : 150, 44, 22, const Color(0x47000000));
  img.draw(c, 'Coin', 38, 32, 30);
  FunText.draw(c, '$score', 60, 42, size: 28, align: TextAlign.left);
  if (lives > 0) {
    for (var i = 0; i < kFunLives; i++) {
      img.draw(c, 'Red heart', w - (narrow ? 30 : 40) - i * hg, 32, hs, alpha: i < lives ? 1 : .22);
    }
  }
  if (time != null) {
    fillRRect(c, w / 2 - tw / 2, 10, tw, 44, 22, const Color(0x47000000));
    FunText.draw(c, '⏱ ${time.ceil()}', w / 2, 42, size: 28);
  }
  if (bossHp != null && bossMax != null && bossMax > 0) {
    final bw = math.min(360.0, w * .5);
    fillRRect(c, w / 2 - bw / 2, 62, bw, 18, 9, const Color(0x59000000));
    fillRRect(c, w / 2 - bw / 2 + 3, 65, (bw - 6) * math.max(0, bossHp / bossMax), 12, 6, const Color(0xFFFF6B6B));
  }
}

/// Băng chữ lớn giữa màn (banner()).
void funBanner(Canvas c, double w, double h, String text, [String? sub]) {
  c.drawRect(Rect.fromLTWH(0, h / 2 - 70, w, 140), Paint()..color = const Color(0x59000000));
  FunText.draw(c, text, w / 2, h / 2 + (sub != null ? 0 : 18), size: 54, fit: w - 24);
  if (sub != null) FunText.draw(c, sub, w / 2, h / 2 + 42, size: 26, weight: FontWeight.w700, fit: w - 24);
}

/// Màn mở đầu cấp: CẤP n, mục tiêu, gợi ý (levelBanner()).
void funLevelBanner(Canvas c, double w, double h, int lv, String goal, [String? hint, bool en = false]) {
  c.drawRect(Rect.fromLTWH(0, h / 2 - 90, w, 180), Paint()..color = const Color(0x66000000));
  FunText.draw(c, '${en ? 'LEVEL' : 'CẤP'} ${lv + 1}', w / 2, h / 2 - 22, size: 50, color: const Color(0xFFFFD43B));
  FunText.draw(c, '🎯 $goal', w / 2, h / 2 + 20, size: 28, fit: w - 24);
  if (hint != null && hint.isNotEmpty) FunText.draw(c, hint, w / 2, h / 2 + 58, size: 20, weight: FontWeight.w700, color: const Color(0xD9FFFFFF), fit: w - 24);
}

/// Ô mục tiêu điểm (goalPill()).
void funGoalPill(Canvas c, double w, int now, int need, [double y = 62]) {
  if (w < 640) y = math.max(y, 62);
  final ok = now >= need;
  fillRRect(c, w / 2 - 70, y, 140, 36, 18, ok ? const Color(0xD92F9E44) : const Color(0x47000000));
  FunText.draw(c, ok ? '🎯 $need ✔' : '🎯 $now/$need', w / 2, y + 26, size: 22);
}

/// Chữ kết thúc cấp (endText()), song ngữ.
String funEnd(bool win, int lv, [bool en = false]) {
  if (!en) return funEndText(win, lv);
  return win ? (lv + 1 >= kFunMax ? '🏆 TOP LEVEL!' : '⭐ LEVEL ${lv + 2}!') : 'LEVEL NOT CLEARED';
}

// ---------------------------------------------------------------------------------------------------------------
// Game canvas + vòng lặp
// ---------------------------------------------------------------------------------------------------------------

/// Một game canvas (một cấp). Lớp con viết init/update/paint + nhận chạm. Xem chú thích đầu file.
abstract class FunCanvasGame {
  FunCanvasGame(this.ctx);
  final FunGameContext ctx;

  /// Kích thước màn chơi (≥ 320 như canvasIn()), S = min(W, H).
  double W = 800, H = 600;
  double get S => math.min(W, H);

  /// Cấp hiện tại (opts.level).
  int get lv => ctx.level;
  FunTheme get th => funTheme(lv);

  final FunImages img = FunImages.shared;
  final Map<String, SpriteSheet?> sheets = {};
  bool get en => ctx.i18n.isEn;
  String tr(String vi, String en) => this.en ? en : vi;
  AudioService get audio => ctx.audio;
  void sfx(String name) => ctx.audio.sfx(name);

  /// Hình emoji cần nạp (loadAll).
  List<String> get images => const [];

  /// Sprite sheet cần nạp (sheets() của funfx), vd. 'plat/tiles'.
  List<String> get sheetNames => const [];

  bool _inited = false;
  bool get inited => _inited;

  /// Nạp hình + sheet (chạy nền; game không đợi).
  Future<void> load() async {
    await Future.wait([
      img.load(['Coin', 'Red heart', 'Glowing star', ...images]),
      ...sheetNames.map((n) async => sheets[n] = await loadSheet(n)),
    ]);
  }

  /// Đặt cỡ màn rồi gọi [init] (một lần).
  void setSize(double w, double h) {
    W = math.max(320, w);
    H = math.max(320, h);
    if (!_inited) {
      _inited = true;
      init();
    }
  }

  /// Dựng màn (W/H đã có).
  void init();

  /// Một bước; trả kết quả khi xong cấp (loop() resolve).
  FunResult? update(double dt);

  /// Vẽ một khung.
  void paint(Canvas c);

  void pointerDown(Offset p, int id) {}
  void pointerMove(Offset p, int id, bool down) {}
  void pointerUp(Offset p, int id) {}

  /// Phím đang giữ (mũi tên/WASD).
  final Set<LogicalKeyboardKey> keys = {};
  void dispose() {}
}

/// Widget chạy một [FunCanvasGame]: Ticker → update(dt ≤ .05) → vẽ. Kết quả → onEnd (mặc định ctx.finish).
class FunCanvas extends StatefulWidget {
  const FunCanvas({super.key, required this.game, this.onEnd, this.background});
  final FunCanvasGame game;
  final void Function(FunResult r)? onEnd;
  final Color? background;
  @override
  State<FunCanvas> createState() => _FunCanvasState();
}

class _FunCanvasState extends State<FunCanvas> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  Duration _last = Duration.zero;
  bool _done = false;

  FunCanvasGame get g => widget.game;

  @override
  void initState() {
    super.initState();
    g.load().then((_) {
      if (mounted) _frame.value++;
    }).catchError((_) {});
    _ticker.start();
  }

  void _tick(Duration now) {
    final dt = math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (_done) return;
    if (!g.ctx.alive) {
      _done = true;
      _ticker.stop();
      return;
    }
    if (!g.inited) return;
    final r = g.update(dt);
    _frame.value++;
    if (r != null) {
      _done = true;
      _ticker.stop();
      final cb = widget.onEnd;
      if (cb != null) {
        cb(r);
      } else {
        g.ctx.finish(r);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _focus.dispose();
    g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 800.0, h = box.maxHeight.isFinite ? box.maxHeight : 600.0;
      g.setSize(w, h);
      return Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent) g.keys.add(e.logicalKey);
          if (e is KeyUpEvent) g.keys.remove(e.logicalKey);
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => g.pointerDown(e.localPosition, e.pointer),
          onPointerMove: (e) => g.pointerMove(e.localPosition, e.pointer, e.down),
          onPointerHover: (e) => g.pointerMove(e.localPosition, e.pointer, false),
          onPointerUp: (e) => g.pointerUp(e.localPosition, e.pointer),
          onPointerCancel: (e) => g.pointerUp(e.localPosition, e.pointer),
          child: ClipRect(
            child: CustomPaint(
              size: Size(w, h),
              painter: _GamePainter(g, _frame, widget.background),
            ),
          ),
        ),
      );
    });
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.g, Listenable frame, this.bg) : super(repaint: frame);
  final FunCanvasGame g;
  final Color? bg;
  @override
  void paint(Canvas canvas, Size size) {
    if (bg != null) canvas.drawRect(Offset.zero & size, Paint()..color = bg!);
    if (!g.inited) return;
    g.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => old.g != g;
}

/// FunGameModule đơn giản cho game canvas một cấp: `FunCanvasModule('catch', CatchGame.new)`.
class FunCanvasModule extends FunGameModule {
  const FunCanvasModule(this.id, this.create);
  @override
  final String id;
  final FunCanvasGame Function(FunGameContext ctx) create;
  @override
  Widget build(BuildContext context, FunGameContext ctx) => ColoredBox(color: const Color(0xFF212529), child: FunCanvas(game: create(ctx)));
}
