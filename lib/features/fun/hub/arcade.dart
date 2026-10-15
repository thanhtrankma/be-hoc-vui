// Đảo Trò chơi nhanh (đảo học, mở từ bản đồ): bắn bóng bay (chữ, số, dấu thanh, tiếng Anh) và đua xe tính nhẩm.
// CHỦ: agent E. Port của reference/web/js/games/arcade.js. Hợp đồng: GameModule/GameContext (lib/core/game/game_module.dart).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/vn_text.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart' show starsFor;

import 'funfx.dart' show spr;

final GameModule arcadeModule = ArcadeGame();

class ArcadeGame extends GameModule {
  @override
  String get id => 'arcade';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final lv = ctx.level ?? const {};
    return asStr(lv['kind']) == 'race' ? RaceView(key: const Key('arcade-race'), ctx: ctx) : BalloonView(key: const Key('arcade-balloon'), ctx: ctx);
  }
}

/// Số bóng cần bắn trúng (GOAL).
const int kBalloonGoal = 8;
const List<Color> _colors = [Color(0xFFFF6B6B), Color(0xFFFF922B), Color(0xFFFCC419), Color(0xFF51CF66), Color(0xFF22B8CF), Color(0xFF4C6EF5), Color(0xFF9775FA), Color(0xFFF06595)];
const List<String> _tones = ['ngang', 'huyền', 'sắc', 'hỏi', 'ngã', 'nặng'];

/// Mục tiêu một lượt: id đúng, câu đọc, sinh nhãn nhiễu, cách vẽ nhãn (target()).
class BalloonTarget {
  BalloonTarget({required this.id, required this.say, required this.make, this.image = false});
  final String id;
  final VoiceLine? say;
  final String Function() make;

  /// Nhãn là tên hình (tiếng Anh) thay vì chữ.
  final bool image;
}

BalloonTarget balloonTarget(String mode, Content content, AudioService audio) {
  switch (mode) {
    case 'letters':
      final letters = content.list('letters');
      final l = pick(letters);
      return BalloonTarget(id: asStr(l['ch']), say: audio.tpl('findLetter', l), make: () => asStr(pick(letters)['ch']));
    case 'numbers':
      final nums = content.list('nums');
      final n = rng.nextInt(21);
      return BalloonTarget(id: '$n', say: audio.tpl('findNum', nums[n]), make: () => '${rng.nextInt(21)}');
    case 'tones':
      final w = pick(content.list('vnwords'));
      return BalloonTarget(id: asStr(w['w']), say: audio.tpl('vnWord', w), make: () => nfc(asStr(w['c']) + placeTone(asStr(w['v']), pick(_tones))));
    default:
      final set = [...content.list('en_animals'), ...content.list('en_fruits')];
      final it = pick(set);
      return BalloonTarget(id: asStr(it['img']), say: audio.tpl('findEnThe', it), make: () => asStr(pick(set)['img']), image: true);
  }
}

class BalloonItem {
  BalloonItem(this.id, this.x, this.y, this.vy, this.phase, this.color, this.size);
  final String id;
  final double x, vy, size;
  double y, phase;
  final Color color;
  bool popped = false;
  int shake = 0;
}

// =================================================================================================================
// Bóng bay
// =================================================================================================================

class BalloonView extends StatefulWidget {
  const BalloonView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<BalloonView> createState() => BalloonViewState();
}

class BalloonViewState extends State<BalloonView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final balloons = <BalloonItem>[];
  int hits = 0, mistakes = 0, sinceTarget = 0;
  double speed = 1, spawnT = 0;
  BalloonTarget? tgt;
  bool alive = true, started = false;
  Duration _last = Duration.zero;
  Size _sky = const Size(400, 600);

  GameContext get g => widget.ctx;
  String get mode => asStr(g.level?['mode'], 'letters');

  /// Bóng đang bay đúng mục tiêu (cho kiểm thử).
  List<Key> get targetKeys => [for (final b in balloons) if (!b.popped && b.id == tgt?.id && b.y < _sky.height && b.y > -b.size) ValueKey(b)];
  List<Key> get wrongKeys => [for (final b in balloons) if (!b.popped && b.id != tgt?.id && b.y < _sky.height && b.y > -b.size) ValueKey(b)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      g.hideBuddy();
      g.progress(0, kBalloonGoal);
      _start();
    });
  }

  Future<void> _start() async {
    await g.audio.sayPhrase('balloonQ');
    if (!mounted || g.aborted) return;
    _newTarget();
    started = true;
    _ticker.start();
  }

  void _newTarget() {
    tgt = balloonTarget(mode, g.content, g.audio);
    sinceTarget = 0;
    g.audio.say(tgt!.say);
  }

  void _spawn() {
    final t = tgt!;
    // Bảo đảm mục tiêu xuất hiện đều: tối đa 3 quả nhiễu liền nhau.
    final isT = sinceTarget >= 3 || rng.nextDouble() < .38;
    var id = isT ? t.id : t.make();
    if (!isT && id == t.id) id = t.make();
    sinceTarget = id == t.id ? 0 : sinceTarget + 1;
    final w = _sky.width, size = (w / 7).clamp(86.0, 130.0);
    balloons.add(BalloonItem(id, rng.nextDouble() * math.max(1, w - size), _sky.height + 20, (55 + rng.nextDouble() * 30) * speed, rng.nextDouble() * 6, pick(_colors), size));
  }

  void _tick(Duration now) {
    final dt = math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (!alive || g.aborted) {
      alive = false;
      _ticker.stop();
      return;
    }
    spawnT -= dt;
    if (spawnT <= 0) {
      _spawn();
      spawnT = 1.15 / speed;
    }
    for (final b in balloons) {
      if (b.popped) continue;
      b.y -= b.vy * dt;
      b.phase += dt * 2;
    }
    balloons.removeWhere((b) => b.y < -200 && !b.popped);
    setState(() {});
  }

  void pop(BalloonItem b) {
    if (!alive || b.popped || tgt == null) return;
    if (b.id == tgt!.id) {
      setState(() => b.popped = true);
      g.audio.sfx('pop');
      g.audio.sfx('correct');
      g.cheer();
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => balloons.remove(b));
      });
      hits++;
      g.progress(hits, kBalloonGoal);
      speed = 1 + hits * .09;
      if (hits >= kBalloonGoal) {
        _finish();
        return;
      }
      _newTarget();
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      g.sad();
      setState(() => b.shake++);
    }
  }

  Future<void> _finish() async {
    alive = false;
    _ticker.stop();
    setState(() {
      for (final b in balloons) {
        b.popped = true;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    g.finish(starsFor(math.max(0, mistakes - 1)));
  }

  @override
  void dispose() {
    alive = false;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    return Column(children: [
      Chunky(
        key: const Key('balloon-prompt'),
        onTap: () {
          if (tgt != null) g.audio.say(tgt!.say);
        },
        radius: 999,
        depth: 5,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: Text('🔊', style: TextStyle(fontSize: fs * 1.8)),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          _sky = Size(box.maxWidth, math.max(box.maxHeight, 300));
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              for (final b in balloons)
                Positioned(
                  key: ValueKey(b),
                  left: b.x + math.sin(b.phase) * 10,
                  top: b.y,
                  child: _BalloonWidget(b: b, image: tgt?.image ?? false, onDown: () => pop(b)),
                ),
            ]),
          );
        }),
      ),
    ]);
  }
}

class _BalloonWidget extends StatelessWidget {
  const _BalloonWidget({required this.b, required this.image, required this.onDown});
  final BalloonItem b;
  final bool image;
  final VoidCallback onDown;
  @override
  Widget build(BuildContext context) {
    final s = b.size;
    final label = image
        ? EmojiImage(b.id, size: s * .66, photo: false)
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(b.id,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: vwClamp(context, 32, 5, 50),
                    height: 1,
                    shadows: const [Shadow(color: Color(0x40000000), offset: Offset(0, 2))])),
          );
    Widget body = SizedBox(
      width: s,
      height: s * 1.2 + 40,
      child: CustomPaint(
        painter: _BalloonPainter(b.color),
        child: Padding(padding: EdgeInsets.only(bottom: 40, left: s * .12, right: s * .12), child: Center(child: label)),
      ),
    );
    if (b.popped) {
      body = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 300),
        builder: (context, v, child) => Opacity(opacity: 1 - v, child: Transform.scale(scale: 1 + v * .6, child: child)),
        child: body,
      );
    } else if (b.shake > 0) {
      body = TweenAnimationBuilder<double>(
        key: ValueKey(b.shake),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, v, child) => Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * 8 * (1 - v), 0), child: child),
        child: body,
      );
    }
    return Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => onDown(), child: body);
  }
}

class _BalloonPainter extends CustomPainter {
  _BalloonPainter(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height - 40;
    // Dây
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, h + 40), Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 2);
    // Nút thắt
    final knot = Path()
      ..moveTo(w / 2 - 7, h + 1)
      ..lineTo(w / 2 + 7, h + 1)
      ..lineTo(w / 2, h - 6)
      ..close();
    canvas.drawPath(knot, Paint()..color = Color.lerp(c, Colors.black, .1)!);
    final r = Rect.fromLTWH(0, 0, w, h);
    canvas.drawOval(r, Paint()..color = c);
    // Bóng tối dưới phải + đốm sáng
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    canvas.drawOval(r.shift(const Offset(8, 10)).inflate(2), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = const Color(0x1F000000));
    canvas.restore();
    canvas.drawCircle(Offset(w * .32, h * .28), w * .14, Paint()..shader = RadialGradient(colors: [const Color(0xBFFFFFFF), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(w * .32, h * .28), radius: w * .14)));
  }

  @override
  bool shouldRepaint(covariant _BalloonPainter o) => o.c != c;
}

// =================================================================================================================
// Đua xe tính nhẩm
// =================================================================================================================

class RaceQ {
  RaceQ(this.text, this.answer, this.choices);
  final String text;
  final int answer;
  final List<int> choices;
}

RaceQ raceQ(Json lv, Content content) {
  final mode = asStr(lv['mode'], 'add'), max = asInt(lv['max'], 5);
  final kind = mode == 'mix' ? (rng.nextBool() ? 'add' : 'sub') : mode;
  final facts = content
      .list(kind == 'add' ? 'addFacts' : 'subFacts')
      .where((f) => asInt(f['a']) >= 1 && asInt(f['b']) >= 1 && asInt(f['a']) <= max && (kind == 'sub' || asInt(f['c']) <= max))
      .toList();
  final f = pick(facts);
  final c = asInt(f['c']);
  final opts = <int>{c};
  while (opts.length < 3) {
    final k = c + pick<int>(const [-2, -1, 1, 2]);
    if (k >= 0 && k <= 10) opts.add(k);
  }
  return RaceQ('${f['a']} ${kind == 'add' ? '+' : '−'} ${f['b']}', c, shuffle(opts));
}

class RaceView extends StatefulWidget {
  const RaceView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<RaceView> createState() => RaceViewState();
}

class RaceViewState extends State<RaceView> with SingleTickerProviderStateMixin {
  static const steps = 10;
  late final Ticker _ticker = createTicker(_tick);
  int kid = 0, mistakes = 0, boost = 0;
  double bot = 0, clock = 0, stall = 0;
  bool alive = true;
  RaceQ? q;
  final wrong = <int>{};
  Duration _last = Duration.zero;

  GameContext get g => widget.ctx;
  Json get lv => g.level ?? const {};

  /// Xe máy chạy đều: ~5 giây mỗi bước (bài khó hơn chậm hơn chút).
  late final double botSpeed = 1 / (asInt(lv['max'], 5) > 5 ? 5.6 : 4.6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      g.hideBuddy();
      g.progress(0, steps);
      _start();
    });
  }

  Future<void> _start() async {
    await g.audio.sayPhrase('raceIntro');
    if (!mounted || g.aborted) return;
    setState(_next);
    _ticker.start();
  }

  void _next() {
    q = raceQ(lv, g.content);
    wrong.clear();
  }

  void _tick(Duration now) {
    final dt = math.min(.1, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (!alive || g.aborted) {
      _ticker.stop();
      return;
    }
    clock += dt;
    setState(() => bot += botSpeed * dt);
    if (bot >= steps) _end(false);
  }

  void answer(int c) {
    final qq = q;
    if (!alive || qq == null || clock < stall) return;
    if (c == qq.answer) {
      g.audio.sfx('correct');
      setState(() {
        kid++;
        boost++;
      });
      g.progress(kid, steps);
      if (kid >= steps) {
        _end(true);
        return;
      }
      setState(_next);
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      setState(() => wrong.add(c));
      stall = clock + .9;
    }
  }

  Future<void> _end(bool win) async {
    if (!alive) return;
    alive = false;
    _ticker.stop();
    g.audio.sfx(win ? 'win' : 'wrong');
    if (win) {
      g.cheer();
    } else {
      g.sad();
    }
    await g.audio.sayPhrase(win ? 'raceWin' : 'raceLose');
    if (!mounted) return;
    g.finish(win ? (mistakes <= 2 ? 3 : 2) : 1);
  }

  @override
  void dispose() {
    alive = false;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final laneH = (mq.height * .11).clamp(70.0, 100.0);
    final kidW = vwClamp(context, 100, 15, 150), botW = vwClamp(context, 80, 12, 120);
    final fs = baseFontSize(context);
    final qq = q;
    Widget lane(double frac, Widget car, double w, {bool border = true}) => Container(
          height: laneH,
          decoration: border ? const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x80FFFFFF), width: 3))) : null,
          child: LayoutBuilder(builder: (context, box) {
            return Stack(clipBehavior: Clip.none, children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                left: box.maxWidth * .88 * frac,
                top: (laneH - w * 150 / 260) / 2,
                child: car,
              ),
            ]);
          }),
        );
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            key: const Key('race-track'),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF495057), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF343A40), width: 6)),
            child: Stack(children: [
              Column(children: [
                lane(math.min(bot, steps.toDouble()) / steps, _Car(frame: 'car_blue_3', fallback: 'Police car', width: botW), botW),
                lane(kid / steps, _Boost(trigger: boost, child: _Car(frame: 'car_red_1', fallback: 'Racing car', width: kidW, driver: g.buddyImg)), kidW, border: false),
              ]),
              const Positioned.fill(child: Align(alignment: Alignment(.92, 0), child: _Finish())),
            ]),
          ),
        ),
        if (qq != null)
          Text('${qq.text} = ?', key: const Key('race-q'), style: TextStyle(fontSize: vwClamp(context, 54, 9, 96), fontWeight: FontWeight.w800, color: AppColors.ink2, height: 1.1)),
        if (qq != null)
          Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 12, children: [
            for (final c in qq.choices)
              Chunky(
                key: Key('race-choice-$c'),
                onTap: () => answer(c),
                color: wrong.contains(c) ? const Color(0xFFFFE3E3) : Colors.white,
                radius: 28,
                child: SizedBox(
                  width: vwClamp(context, 96, 14, 150),
                  height: vwClamp(context, 96, 14, 150),
                  child: Center(child: Text('$c', style: TextStyle(fontSize: fs * 3, fontWeight: FontWeight.w800, color: wrong.contains(c) ? AppColors.bad : AppColors.ink))),
                ),
              ),
          ]),
      ]),
    );
  }
}

class _Finish extends StatelessWidget {
  const _Finish();
  @override
  Widget build(BuildContext context) => SizedBox(width: 18, height: double.infinity, child: CustomPaint(painter: _CheckerPainter()));
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const k = 9.0;
    for (var y = 0.0; y < s.height; y += k) {
      for (var x = 0.0; x < s.width; x += k) {
        final dark = ((x / k).round() + (y / k).round()).isOdd;
        c.drawRect(Rect.fromLTWH(x, y, k, k), Paint()..color = dark ? const Color(0xFF212529) : Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Xe vừa trả lời đúng: lao vọt lên (.car.boost).
class _Boost extends StatelessWidget {
  const _Boost({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      builder: (context, v, child) => Transform.scale(scale: 1 + math.sin(v * math.pi) * .12, child: child),
      child: child,
    );
  }
}

/// Xe đua nhìn từ trên (Kenney Racing Pack 'racing/racing'), đầu xe quay phải; chưa có sprite → hình emoji.
class _Car extends StatefulWidget {
  const _Car({required this.frame, required this.fallback, required this.width, this.driver});
  final String frame, fallback;
  final double width;
  final String? driver;
  @override
  State<_Car> createState() => _CarState();
}

class _CarState extends State<_Car> {
  SpriteSheet? sheet;
  @override
  void initState() {
    super.initState();
    loadSheet('racing/racing').then((s) {
      if (mounted && s != null) setState(() => sheet = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = w * 150 / 260;
    final car = sheet?.frames[widget.frame] != null
        ? CustomPaint(size: Size(w, h), painter: _CarPainter(sheet!, widget.frame))
        : SizedBox(width: w, height: h, child: Transform.flip(flipX: true, child: EmojiImage(widget.fallback, size: h, photo: false)));
    return SizedBox(
      width: w,
      height: h,
      child: Stack(clipBehavior: Clip.none, children: [
        car,
        if (widget.driver != null) Positioned(left: w * .3, top: h * .22, child: EmojiImage(widget.driver!, size: w * .3, photo: false)),
      ]),
    );
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.sheet, this.frame);
  final SpriteSheet sheet;
  final String frame;
  @override
  void paint(Canvas c, Size s) {
    // Canvas web 260×150, xe vẽ cao 236 xoay -90° rồi lật ngang (đầu xe sang phải).
    final k = s.width / 260;
    c.save();
    c.translate(s.width, 0);
    c.scale(-1, 1);
    spr(c, sheet, frame, 130 * k, 75 * k, 236 * k, rot: -math.pi / 2);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter o) => o.frame != frame || o.sheet != sheet;
}

/// Danh sách bài của đảo (levels()).
List<({String name, String img})> arcadeLevels(Content content) => [for (final l in content.list('arcadeLevels')) (name: asStr(l['name']), img: asStr(l['img']))];
