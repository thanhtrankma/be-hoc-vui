// Đảo Tập viết: bé tô chữ/số bằng ngón tay trên dòng kẻ ô li. Mực chỉ chảy khi ngón tay đi đúng nét, đúng chiều.
// CHỦ: agent A. Port của reference/web/js/games/trace.js (SVG → CustomPainter, getPointAtLength → PathMetric).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'fx.dart';
import 'quiz.dart' show RewardContent;

final GameModule traceModule = TraceGame();

class TraceGame extends GameModule {
  @override
  String get id => 'trace';
  @override
  Widget build(BuildContext context, GameContext ctx) => TraceView(ctx: ctx);
}

// Hệ toạ độ 100×150: dòng trên 10, đường kẻ giữa 60, dòng kẻ chân 110, dòng dưới 145.
const double _as = 10, _xh = 60, _bl = 110, _ds = 145;

/// Một lệnh vẽ: M/L/Q như SVG, A = cung tròn (cx, cy, r, góc đầu, góc cuối), E = cung elip (cx, cy, rx, ry, góc đầu, góc cuối).
/// Góc tính theo màn hình (0 = phải, 90 = dưới); góc giảm = ngược kim đồng hồ.
typedef Cmd = List<Object>;
typedef Stroke = List<Cmd>;

const Stroke _hat = [
  ['M', 36, 49],
  ['L', 50, 36],
  ['L', 64, 49],
];
const Stroke _breve = [
  ['A', 50, 38, 11, 180, 0],
];
Stroke _roundA(num cx, num cy, [num r = 24]) => [
      ['A', cx, cy, r, -25, -385],
    ];

/// Mỗi chữ: danh sách nét theo thứ tự viết (GLYPHS của web).
final Map<String, List<Stroke>> kGlyphs = {
  'o': [
    [
      ['A', 50, 85, 25, -60, -420],
    ],
  ],
  'ô': [
    [
      ['A', 50, 85, 25, -60, -420],
    ],
    _hat,
  ],
  'ơ': [
    [
      ['A', 48, 85, 25, -60, -420],
    ],
    [
      ['M', 68, 68],
      ['Q', 80, 66, 82, 54],
    ],
  ],
  'a': [
    _roundA(47, 85),
    [
      ['M', 72, _xh],
      ['L', 72, _bl],
    ],
  ],
  'ă': [
    _roundA(47, 85),
    [
      ['M', 72, _xh],
      ['L', 72, _bl],
    ],
    _breve,
  ],
  'â': [
    _roundA(47, 85),
    [
      ['M', 72, _xh],
      ['L', 72, _bl],
    ],
    _hat,
  ],
  'c': [
    [
      ['A', 52, 85, 25, -40, -320],
    ],
  ],
  'e': [
    [
      ['M', 27, 86],
      ['L', 75, 86],
      ['A', 51, 86, 24, 0, -315],
    ],
  ],
  'ê': [
    [
      ['M', 27, 86],
      ['L', 75, 86],
      ['A', 51, 86, 24, 0, -315],
    ],
    _hat,
  ],
  'b': [
    [
      ['M', 28, _as],
      ['L', 28, _bl],
    ],
    [
      ['A', 50, 86, 22, 180, 540],
    ],
  ],
  'd': [
    _roundA(50, 86, 23),
    [
      ['M', 73, _as],
      ['L', 73, _bl],
    ],
  ],
  'đ': [
    _roundA(50, 86, 23),
    [
      ['M', 73, _as],
      ['L', 73, _bl],
    ],
    [
      ['M', 60, 32],
      ['L', 86, 32],
    ],
  ],
  'i': [
    [
      ['M', 50, _xh],
      ['L', 50, _bl],
    ],
    [
      ['M', 50, 40],
      ['L', 50, 45],
    ],
  ],
  't': [
    [
      ['M', 48, 24],
      ['L', 48, 102],
      ['Q', 48, 111, 60, 110],
    ],
    [
      ['M', 32, _xh],
      ['L', 66, _xh],
    ],
  ],
  'u': [
    [
      ['M', 28, _xh],
      ['L', 28, 88],
      ['A', 50, 88, 22, 180, 0],
      ['L', 72, _xh],
    ],
    [
      ['M', 72, _xh],
      ['L', 72, _bl],
    ],
  ],
  'ư': [
    [
      ['M', 28, _xh],
      ['L', 28, 88],
      ['A', 50, 88, 22, 180, 0],
      ['L', 72, _xh],
    ],
    [
      ['M', 72, _xh],
      ['L', 72, _bl],
    ],
    [
      ['M', 72, 62],
      ['Q', 84, 60, 84, 48],
    ],
  ],
  'l': [
    [
      ['M', 50, _as],
      ['L', 50, _bl],
    ],
  ],
  'h': [
    [
      ['M', 28, _as],
      ['L', 28, _bl],
    ],
    [
      ['M', 28, 84],
      ['A', 50, 84, 22, 180, 360],
      ['L', 72, _bl],
    ],
  ],
  'k': [
    [
      ['M', 30, _as],
      ['L', 30, _bl],
    ],
    [
      ['M', 70, _xh],
      ['L', 31, 88],
      ['L', 72, _bl],
    ],
  ],
  'm': [
    [
      ['M', 18, _xh],
      ['L', 18, _bl],
    ],
    [
      ['M', 18, 80],
      ['A', 34, 80, 16, 180, 360],
      ['L', 50, _bl],
    ],
    [
      ['M', 50, 80],
      ['A', 66, 80, 16, 180, 360],
      ['L', 82, _bl],
    ],
  ],
  'n': [
    [
      ['M', 26, _xh],
      ['L', 26, _bl],
    ],
    [
      ['M', 26, 82],
      ['A', 49, 82, 23, 180, 360],
      ['L', 72, _bl],
    ],
  ],
  'r': [
    [
      ['M', 32, _xh],
      ['L', 32, _bl],
    ],
    [
      ['M', 32, 82],
      ['A', 52, 82, 20, 180, 310],
    ],
  ],
  'g': [
    _roundA(48, 84, 23),
    [
      ['M', 71, _xh],
      ['L', 71, 125],
      ['A', 51, 125, 20, 0, 160],
    ],
  ],
  'p': [
    [
      ['M', 28, _xh],
      ['L', 28, _ds],
    ],
    [
      ['A', 50, 85, 22, 180, 540],
    ],
  ],
  'q': [
    _roundA(50, 85, 23),
    [
      ['M', 73, _xh],
      ['L', 73, _ds],
    ],
  ],
  'y': [
    [
      ['M', 27, _xh],
      ['L', 50, _bl],
    ],
    [
      ['M', 74, _xh],
      ['L', 38, _ds],
    ],
  ],
  's': [
    [
      ['A', 50, 73, 13, -30, -270],
      ['A', 50, 98, 12, -90, 160],
    ],
  ],
  'v': [
    [
      ['M', 26, _xh],
      ['L', 50, _bl],
      ['L', 74, _xh],
    ],
  ],
  'x': [
    [
      ['M', 28, _xh],
      ['L', 72, _bl],
    ],
    [
      ['M', 72, _xh],
      ['L', 28, _bl],
    ],
  ],
  '0': [
    [
      ['E', 50, 68, 23, 42, -90, -450],
    ],
  ],
  '1': [
    [
      ['M', 34, 44],
      ['L', 56, 26],
      ['L', 56, _bl],
    ],
  ],
  '2': [
    [
      ['A', 50, 48, 22, 200, 380],
      ['L', 28, _bl],
      ['L', 74, _bl],
    ],
  ],
  '3': [
    [
      ['A', 48, 46, 20, 210, 450],
      ['A', 48, 88, 22, -90, 155],
    ],
  ],
  '4': [
    [
      ['M', 60, 26],
      ['L', 24, 84],
      ['L', 78, 84],
    ],
    [
      ['M', 60, 52],
      ['L', 60, _bl],
    ],
  ],
  '5': [
    [
      ['M', 36, 28],
      ['L', 36, 64],
      ['A', 50, 85, 24, -125, 155],
    ],
    [
      ['M', 36, 28],
      ['L', 72, 28],
    ],
  ],
  '6': [
    [
      ['M', 68, 30],
      ['Q', 30, 44, 28, 88],
      ['A', 50, 88, 22, 180, -180],
    ],
  ],
  '7': [
    [
      ['M', 26, 28],
      ['L', 74, 28],
      ['L', 40, _bl],
    ],
  ],
  '8': [
    [
      ['A', 50, 46, 19, -60, -420],
    ],
    [
      ['A', 50, 88, 22, -90, 270],
    ],
  ],
  '9': [
    [
      ['A', 48, 48, 21, 0, -360],
      ['L', 69, _bl],
    ],
  ],
};

double _n(Object v) => (v as num).toDouble();
double _rad(double d) => d * math.pi / 180;

/// Đổi danh sách lệnh của một nét thành Path (toạ độ chữ 100×150). Cung chia nhỏ ≤ 90° như web.
Path compileStroke(Stroke stroke) {
  final p = Path();
  Offset? cur;
  void moveOrLine(Offset o) {
    if (cur == null) {
      p.moveTo(o.dx, o.dy);
    } else if ((cur! - o).distance > .5) {
      p.lineTo(o.dx, o.dy);
    }
    cur = o;
  }

  for (final c in stroke) {
    switch (c[0]) {
      case 'M':
        p.moveTo(_n(c[1]), _n(c[2]));
        cur = Offset(_n(c[1]), _n(c[2]));
      case 'L':
        p.lineTo(_n(c[1]), _n(c[2]));
        cur = Offset(_n(c[1]), _n(c[2]));
      case 'Q':
        p.quadraticBezierTo(_n(c[1]), _n(c[2]), _n(c[3]), _n(c[4]));
        cur = Offset(_n(c[3]), _n(c[4]));
      default:
        final isA = c[0] == 'A';
        final cx = _n(c[1]), cy = _n(c[2]);
        final rx = _n(c[3]), ry = isA ? rx : _n(c[4]);
        final a0 = _n(isA ? c[4] : c[5]), a1 = _n(isA ? c[5] : c[6]);
        Offset pt(double a) => Offset(cx + rx * math.cos(_rad(a)), cy + ry * math.sin(_rad(a)));
        moveOrLine(pt(a0));
        final steps = ((a1 - a0).abs() / 90).ceil();
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
        for (var k = 0; k < steps; k++) {
          final s = a0 + (a1 - a0) * k / steps, e = a0 + (a1 - a0) * (k + 1) / steps;
          p.arcTo(rect, _rad(s), _rad(e - s), false);
        }
        cur = pt(a1);
    }
  }
  return p;
}

const double _tol = 15, _look = 14, _step = 2;

/// Điểm mẫu dọc một nét, cách nhau STEP (getPointAtLength của web).
List<Offset> strokeSamples(Path path) {
  final out = <Offset>[];
  for (final m in path.computeMetrics()) {
    for (double l = 0; l <= m.length; l += _step) {
      out.add(m.getTangentForOffset(l)!.position);
    }
    break; // mỗi nét chỉ một đường liền
  }
  return out;
}

double _len(Path p) {
  for (final m in p.computeMetrics()) {
    return m.length;
  }
  return 0;
}

/// Nét của một chữ (đã dựng) — cho test và màn tô.
List<Path> glyphPaths(String ch) => (kGlyphs[ch] ?? const []).map(compileStroke).toList();

// ---------------------------------------------------------------------------------------------------------------

class TraceView extends StatefulWidget {
  const TraceView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<TraceView> createState() => _TraceViewState();
}

class _TraceViewState extends State<TraceView> {
  GameContext get g => widget.ctx;
  late final Json lv = g.level ?? const {};
  late final List<String> chars = asStrList(lv['chars']).where(kGlyphs.containsKey).toList();
  late final Map<String, Json> by = {for (final l in g.content.list('letters')) l['ch'] as String: l};
  int i = 0;
  bool reward = false;
  bool get dead => !mounted || g.aborted;

  bool _isDigit(String ch) => RegExp(r'\d').hasMatch(ch);
  VoiceLine? _voice(String ch) => _isDigit(ch)
      ? g.audio.tpl('writeNum', g.content.list('digits')[int.parse(ch)])
      : g.audio.tpl('writeLetter', by[ch] ?? {'ch': ch, 'say': ch});
  VoiceLine? _done(String ch) => _isDigit(ch)
      ? g.audio.tpl('num', g.content.list('nums')[int.parse(ch)])
      : g.audio.tpl('letterWord', by[ch] ?? {'ch': ch, 'say': ch});

  @override
  void initState() {
    super.initState();
    g.audio.preload(chars.expand((ch) => [_voice(ch), _done(ch)]));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (dead) return;
    g.hideBuddy();
    if (chars.isEmpty) {
      g.finish(3);
      return;
    }
    g.progress(0, chars.length);
    await g.audio.sayPhrase('traceIntro');
    if (dead || i != 0 || reward) return;
    g.audio.say(_voice(chars[0]));
  }

  Future<void> _charDone() async {
    if (dead) return;
    final ch = chars[i];
    g.audio.sfx('correct');
    setState(() => reward = true);
    await Future.wait([g.audio.say(_done(ch)), wait(1200)]);
    if (dead) return;
    if (i + 1 >= chars.length) {
      g.progress(chars.length, chars.length);
      g.finish(3);
      return;
    }
    setState(() {
      i++;
      reward = false;
    });
    g.progress(i, chars.length);
    g.audio.say(_voice(chars[i]));
  }

  @override
  Widget build(BuildContext context) {
    if (chars.isEmpty) return const SizedBox();
    final ch = chars[i];
    final L = _isDigit(ch) ? null : by[ch];
    return Stack(children: [
      Center(child: TraceBoard(key: ValueKey('trace-$i'), ch: ch, audio: g.audio, onDone: _charDone)),
      if (reward)
        Positioned.fill(
          child: ColoredBox(
            key: const Key('trace-reward'),
            color: const Color(0xB8E6F7FF),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RewardIn(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFFFF3BF), width: 4),
                      boxShadow: kCardShadow,
                    ),
                    child: RewardContent(img: L?['img'] as String?, big: ch, small: L?['word'] as String?),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Bảng tô một chữ: dòng kẻ ô li, nét mờ, nét chấm, mực, chấm xanh chỉ chỗ bắt đầu (số thứ tự nét).
class TraceBoard extends StatefulWidget {
  const TraceBoard({super.key, required this.ch, required this.audio, required this.onDone});
  final String ch;
  final AudioService audio;
  final VoidCallback onDone;
  @override
  State<TraceBoard> createState() => _TraceBoardState();
}

class _TraceBoardState extends State<TraceBoard> {
  late final List<Path> strokes = glyphPaths(widget.ch);
  late final List<double> lengths = strokes.map(_len).toList();
  late List<Offset> samples;
  int si = 0, pi = 0, hint = 0;
  bool drawing = false, done = false;
  double scale = 1;

  @override
  void initState() {
    super.initState();
    samples = strokeSamples(strokes[0]);
  }

  void _startStroke() {
    samples = strokeSamples(strokes[si]);
    pi = 0;
  }

  Offset _toGlyph(Offset local) => Offset(local.dx / scale - 6, local.dy / scale);

  void _advance(Offset p) {
    if (done) return;
    var best = -1;
    final end = math.min(samples.length - 1, pi + _look.toInt());
    for (var j = pi; j <= end; j++) {
      if ((samples[j] - p).distance < _tol) best = j;
    }
    if (best > pi) setState(() => pi = best);
    if (pi >= samples.length - 3) {
      drawing = false;
      widget.audio.sfx('star');
      setState(() {
        si++;
        if (si < strokes.length) {
          _startStroke();
        } else {
          done = true;
        }
      });
      if (done) widget.onDone();
    }
  }

  void _down(PointerDownEvent e) {
    if (done) return;
    final p = _toGlyph(e.localPosition);
    if ((p - samples[pi]).distance < _tol * 1.7) {
      drawing = true;
      _advance(p);
    } else {
      widget.audio.sfx('pop');
      setState(() => hint++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    return LayoutBuilder(builder: (context, box) {
      // .trace-svg { width: min(88vw, 47vh) } — và vừa khung stage.
      // Màn ngang thấp: dùng hết chiều cao vùng chơi cho bảng to hơn.
      final byH = box.maxHeight.isFinite ? box.maxHeight * 112 / 150 : mq.height * .47;
      var w = math.min(mq.width * .88, math.max(mq.height * .47, mq.width > mq.height ? byH : 0.0));
      if (box.maxWidth.isFinite) w = math.min(w, box.maxWidth);
      w = math.min(w, byH);
      w = math.max(w, 120);
      final h = w * 150 / 112;
      scale = w / 112;
      final dot = si < strokes.length ? samples[pi] : null;
      return Container(
        key: const Key('trace-board'),
        width: w,
        height: h,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: kCardShadow),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: (e) {
            if (drawing) _advance(_toGlyph(e.localPosition));
          },
          onPointerUp: (_) => drawing = false,
          onPointerCancel: (_) => drawing = false,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: done ? 1 : 0),
                duration: const Duration(milliseconds: 300),
                builder: (context, doneT, _) => CustomPaint(
                  painter: _TracePainter(strokes: strokes, lengths: lengths, si: si, inkLen: pi * _step, scale: scale, doneT: doneT),
                ),
              ),
            ),
            if (dot != null)
              Positioned(
                left: (dot.dx + 6) * scale - 7 * scale,
                top: dot.dy * scale - 7 * scale,
                child: IgnorePointer(child: _StartDot(r: 7 * scale, moving: pi > 0, hint: hint, label: strokes.length > 1 ? '${si + 1}' : '')),
              ),
          ]),
        ),
      );
    });
  }
}

class _StartDot extends StatelessWidget {
  const _StartDot({required this.r, required this.moving, required this.hint, required this.label});
  final double r;
  final bool moving;
  final int hint;
  final String label;
  @override
  Widget build(BuildContext context) {
    final circle = Container(
      key: const Key('trace-dot'),
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(color: AppColors.good, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: r * 2.5 / 7)),
    );
    // beacon: 50% scale(1.45), 1.2s lặp (đứng yên khi đang tô); hint: nhấp nháy nhanh 3 lần khi chạm sai chỗ.
    Widget anim = moving
        ? circle
        : Pulse(on: true, scale: 1.45, ms: 600, child: circle);
    anim = OneShot(
      duration: const Duration(milliseconds: 900),
      trigger: hint,
      playOnStart: false,
      child: anim,
      builder: (context, t, child) => Transform.scale(scale: t >= 1 ? 1 : 1 + .45 * math.sin(t * 3 * math.pi).abs(), child: child),
    );
    return SizedBox(
      width: r * 2,
      height: r * 2,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (label.isNotEmpty)
          Positioned(
            bottom: r * 2 + r * .3,
            child: Text(label, style: TextStyle(fontSize: r * 9 / 7 * 1.2, fontWeight: FontWeight.w800, color: const Color(0xFF22A04F), height: 1)),
          ),
        anim,
      ]),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.strokes, required this.lengths, required this.si, required this.inkLen, required this.scale, required this.doneT});
  final List<Path> strokes;
  final List<double> lengths;
  final int si;
  final double inkLen;
  final double scale;
  final double doneT;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(6, 0);
    // Dòng kẻ ô li.
    for (final (y, kind) in [(_as, 2), (_xh, 1), (_bl, 0), (_ds, 2)]) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kind == 0 ? 1.4 : .8
        ..color = kind == 0 ? const Color(0xFFFF8FAB) : kind == 1 ? const Color(0xFFA5C8F0) : const Color(0xFFD6E4F5);
      final line = Path()
        ..moveTo(-6, y)
        ..lineTo(106, y);
      canvas.drawPath(kind == 2 ? _dash(line, 3, 3) : line, paint);
    }
    // Nét mờ (guide) và nét chấm (dash); nét đang tô đậm hơn.
    for (var k = 0; k < strokes.length; k++) {
      canvas.drawPath(
        strokes[k],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = k == si ? const Color(0xFFDFE9F6) : const Color(0xFFEDF2F8),
      );
    }
    for (var k = 0; k < strokes.length; k++) {
      canvas.drawPath(
        _dash(strokes[k], 3, 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = k == si ? const Color(0xFF8FA3BF) : const Color(0xFFC3D0E0),
      );
    }
    // Mực: nét đã xong vẽ đủ, nét đang tô vẽ tới chỗ ngón tay.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(const Color(0xFFFF6B3D), AppColors.good, doneT)!;
    for (var k = 0; k < strokes.length && k <= si; k++) {
      if (k < si) {
        canvas.drawPath(strokes[k], ink);
      } else if (inkLen > 0) {
        for (final m in strokes[k].computeMetrics()) {
          canvas.drawPath(m.extractPath(0, math.min(inkLen, lengths[k])), ink);
          break;
        }
      }
    }
    canvas.restore();
  }

  Path _dash(Path src, double on, double off) {
    final out = Path();
    for (final ui.PathMetric m in src.computeMetrics()) {
      for (double d = 0; d < m.length; d += on + off) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.si != si || old.inkLen != inkLen || old.doneT != doneT || old.scale != scale;
}
