// Đảo Toán đời sống: siêu thị mini, dài–ngắn, cao–thấp, nặng–nhẹ, đo bằng kẹp giấy và thước, thứ trong tuần, xem lịch.
// CHỦ: agent B. Port của reference/web/js/games/life.js.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'common.dart';

final GameModule lifeModule = LifeGame();

class LifeGame extends GameModule {
  @override
  String get id => 'life';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final lv = ctx.level ?? ctx.content.list('lifeLevels')[ctx.levelIndex];
    return switch (asStr(lv['kind'])) {
      'shop' => ShopView(ctx: ctx, types: asInt(lv['types'], 1)),
      'weight' => WeightView(ctx: ctx),
      'week' => WeekView(ctx: ctx),
      'calendar' => CalendarView(ctx: ctx),
      final k => _LifeQuiz(ctx: ctx, kind: k),
    };
  }
}

/// Đáp án của vòng đang chơi trong các màn tự dựng (test đọc): shop = {id: số}, weight = 'a'|'b', week = thứ, calendar = ngày.
@visibleForTesting
Object? debugLifeAnswer;

const List<Color> _pencilColors = [Color(0xFFFF6B6B), Color(0xFF4DABF7), Color(0xFF51CF66), Color(0xFFFCC419), Color(0xFF9775FA), Color(0xFFFF922B)];

VoiceLine _praise(AudioService a) => a.phrase('praise${1 + rnd(6)}');

// ---------------------------------------------------------------- Quiz: dài–ngắn, cao–thấp, kẹp giấy, thước

class _LifeQuiz extends StatefulWidget {
  const _LifeQuiz({required this.ctx, required this.kind});
  final GameContext ctx;
  final String kind;
  @override
  State<_LifeQuiz> createState() => _LifeQuizState();
}

class _LifeQuizState extends State<_LifeQuiz> {
  late final List<QuizQuestion> qs = keepQuiz(lifeQuestions(widget.ctx, widget.kind));
  @override
  Widget build(BuildContext context) => QuizView(
        ctx: widget.ctx,
        questions: qs,
        options: QuizOptions(intro: widget.kind == 'length' ? 'lifeIntro' : null),
        onDone: widget.ctx.finish,
      );
}

List<QuizQuestion> lifeQuestions(GameContext g, String kind) => switch (kind) {
      'height' => _heightQ(g),
      'clips' => _clipsQ(g),
      'ruler' => _rulerQ(g),
      _ => _lengthQ(g),
    };

List<QuizQuestion> _lengthQ(GameContext g) => [
      for (var i = 0; i < 6; i++)
        () {
          final lens = sample([4, 5, 6, 7, 8, 9, 10, 11], 3);
          final longest = rng.nextDouble() < .5;
          final target = longest ? lens.reduce(math.max) : lens.reduce(math.min);
          final colors = sample(_pencilColors, 3);
          final ph = g.audio.phrase(longest ? 'longest' : 'shortest', 'vi');
          // Thẻ lựa chọn vuông: bút dựng đứng trên cùng một khung để so được độ dài.
          return QuizQuestion(
            say: ph,
            label: ph.text,
            choices: [
              for (var k = 0; k < 3; k++)
                mChoice(lens[k], (_) => RotatedBox(quarterTurns: 3, child: SizedBox(width: 11 * 30 + 4, height: 34, child: Align(alignment: Alignment.centerLeft, child: Pencil(len: lens[k], color: colors[k]))))),
            ],
            cls: 'pencils',
            cols: 3,
            answer: target,
            reward: _praise(g.audio),
          );
        }(),
    ];

List<QuizQuestion> _heightQ(GameContext g) => [
      for (var i = 0; i < 6; i++)
        () {
          final hs = sample([2, 3, 4, 5, 6, 7, 8], 3);
          final tall = rng.nextDouble() < .5;
          final target = tall ? hs.reduce(math.max) : hs.reduce(math.min);
          final colors = sample(_pencilColors, 3);
          final ph = g.audio.phrase(tall ? 'tallest' : 'lowest', 'vi');
          return QuizQuestion(
            say: ph,
            label: ph.text,
            choices: [for (var k = 0; k < 3; k++) mChoice(hs[k], (_) => Tower(n: hs[k], color: colors[k]))],
            cls: 'towers',
            answer: target,
            reward: _praise(g.audio),
          );
        }(),
    ];

List<QuizQuestion> _clipsQ(GameContext g) => [
      for (var i = 0; i < 6; i++)
        () {
          final n = 2 + rnd(6);
          final opts = shuffle({n, n - 1, n + 1}.where((k) => k >= 1));
          final color = _pencilColors[rnd(_pencilColors.length)];
          return QuizQuestion(
            say: g.audio.phrase('clipsQ', 'vi'),
            stage: (_) => StageFit(
              child: _Measure(children: [
                Pencil(len: n, color: color, unit: 56),
                Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < n; k++) const PaperClip(width: 56)]),
              ]),
            ),
            choices: numChoices(opts),
            cls: 'nums',
            answer: n,
            reward: g.audio.tpl('clipsA', g.content.list('numbers')[n - 1]),
          );
        }(),
    ];

List<QuizQuestion> _rulerQ(GameContext g) => [
      for (var i = 0; i < 6; i++)
        () {
          final n = 3 + rnd(8);
          final opts = shuffle({n, n - 1, n + 1, n + 2}.where((k) => k >= 1 && k <= 10)).take(3).toList();
          if (!opts.contains(n)) opts[0] = n;
          final color = _pencilColors[rnd(_pencilColors.length)];
          final shown = shuffle(opts);
          return QuizQuestion(
            say: g.audio.phrase('rulerQ', 'vi'),
            stage: (_) => StageFit(
              child: _Measure(children: [
                Padding(padding: const EdgeInsets.only(left: 15), child: Pencil(len: n, color: color, unit: 40)),
                const Ruler(max: 12),
              ]),
            ),
            choices: [for (final k in shown) mChoice(k, (_) => Text(mt(g, 'cm', {'n': k})))],
            cls: 'nums',
            answer: n,
            reward: g.audio.tpl('rulerA', g.content.list('numbers')[n - 1]),
          );
        }(),
    ];

class _Measure extends StatelessWidget {
  const _Measure({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(22)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: children),
      );
}

/// Bút chì dài len đơn vị (mỗi đơn vị unit px), đầu nhọn bên phải.
class Pencil extends StatelessWidget {
  const Pencil({super.key, required this.len, required this.color, this.unit = 30});
  final int len;
  final Color color;
  final double unit;
  @override
  Widget build(BuildContext context) => SizedBox(width: len * unit + 4, height: 34, child: CustomPaint(painter: _PencilPainter(len * unit, color)));
}

class _PencilPainter extends CustomPainter {
  _PencilPainter(this.l, this.color);
  final double l;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / 34);
    canvas.drawRRect(RRect.fromLTRBR(0, 6, l - 30, 28, const Radius.circular(4)), Paint()..color = color);
    canvas.drawRRect(RRect.fromLTRBR(0, 6, 12, 28, const Radius.circular(3)), Paint()..color = const Color(0xFFFFA8A8));
    canvas.drawRect(const Rect.fromLTRB(12, 6, 18, 28), Paint()..color = const Color(0xFFADB5BD));
    canvas.drawPath(
        Path()
          ..moveTo(l - 30, 6)
          ..lineTo(l, 17)
          ..lineTo(l - 30, 28)
          ..close(),
        Paint()..color = const Color(0xFFFFE8CC));
    canvas.drawPath(
        Path()
          ..moveTo(l - 9, 13.5)
          ..lineTo(l, 17)
          ..lineTo(l - 9, 20.5)
          ..close(),
        Paint()..color = const Color(0xFF343A40));
  }

  @override
  bool shouldRepaint(_PencilPainter old) => old.l != l || old.color != color;
}

/// Tháp khối (cao–thấp): khung chung 8 khối, tháp đặt ở đáy.
class Tower extends StatelessWidget {
  const Tower({super.key, required this.n, required this.color});
  final int n;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 8 * 29,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, spacing: 3, children: [
          for (var i = 0; i < n; i++)
            Container(
              width: 56,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: const Border(bottom: BorderSide(color: Color(0x26000000), width: 4)),
              ),
            ),
        ]),
      );
}

/// Cái kẹp giấy.
class PaperClip extends StatelessWidget {
  const PaperClip({super.key, this.width = 56});
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: width * 14 / 30, child: CustomPaint(painter: _ClipPainter()));
}

class _ClipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 30);
    final p = Path()
      ..moveTo(3, 7)
      ..arcToPoint(const Offset(7, 3), radius: const Radius.circular(4))
      ..lineTo(25, 3)
      ..arcToPoint(const Offset(25, 9), radius: const Radius.circular(3))
      ..lineTo(10, 9)
      ..arcToPoint(const Offset(10, 5.8), radius: const Radius.circular(1.6))
      ..lineTo(23, 5.8);
    canvas.drawPath(
        p,
        Paint()
          ..color = const Color(0xFF868E96)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ClipPainter old) => false;
}

/// Thước kẻ vàng 0..max cm (mỗi cm 40px, vạch 0 cách mép 15px).
class Ruler extends StatelessWidget {
  const Ruler({super.key, required this.max});
  final int max;
  @override
  Widget build(BuildContext context) => SizedBox(width: max * 40 + 30, height: 46, child: CustomPaint(painter: _RulerPainter(max)));
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.max);
  final int max;
  @override
  void paint(Canvas canvas, Size size) {
    const u = 40.0, ink = Color(0xFF5C3D00);
    final w = max * u + 30;
    final r = RRect.fromLTRBR(0, 0, w, 46, const Radius.circular(6));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFFE066));
    canvas.drawRRect(r, Paint()
      ..color = const Color(0xFFE0A800)
      ..style = PaintingStyle.stroke);
    final big = Paint()
      ..color = ink
      ..strokeWidth = 2;
    final small = Paint()
      ..color = ink
      ..strokeWidth = 1.2;
    for (var i = 0; i <= max; i++) {
      final x = 15 + i * u;
      canvas.drawLine(Offset(x, 0), Offset(x, 18), big);
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: const TextStyle(fontFamily: kFontFamily, fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 38 - tp.height + 4));
      if (i < max) canvas.drawLine(Offset(x + u / 2, 0), Offset(x + u / 2, 10), small);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.max != max;
}

// ---------------------------------------------------------------- Khung chung cho màn tự dựng

/// Màn nhiều vòng tự chạy (shop, cân, thứ, lịch): vòng lặp async như web, mỗi vòng chờ completer.
abstract class _RoundsState<T extends StatefulWidget> extends State<T> {
  GameContext get g;
  int mistakes = 0;
  Completer<void>? roundDone;

  bool get gone => !mounted || g.aborted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (gone) return;
    final ok = await run();
    if (ok && !gone) g.finish(starsFor(mistakes));
  }

  /// Chạy hết các vòng; false nếu bị dừng giữa chừng.
  Future<bool> run();

  Future<void> waitRound() {
    roundDone = Completer<void>();
    return roundDone!.future;
  }

  void endRound() {
    if (roundDone != null && !roundDone!.isCompleted) roundDone!.complete();
  }
}

// ---------------------------------------------------------------- Siêu thị

class ShopView extends StatefulWidget {
  const ShopView({super.key, required this.ctx, required this.types});
  final GameContext ctx;
  final int types;
  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends _RoundsState<ShopView> {
  @override
  GameContext get g => widget.ctx;
  static const _rounds = 5;

  Json? who;
  List<(Json, int)> order = [];
  List<VoiceLine?> voice = [];
  List<Json> shelf = [];
  final Map<String, int> basket = {};
  bool happy = false, busy = false;
  int wrongBump = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => g.hideBuddy());
  }

  @override
  Future<bool> run() async {
    final c = g.content;
    final items0 = c.list('shopItems');
    await g.audio.sayPhrase('shopIntro');
    for (var r = 0; r < _rounds; r++) {
      if (gone) return false;
      g.progress(r, _rounds);
      final w = sample(c.list('customers'), 1).first;
      final items = sample(items0, widget.types);
      final ord = [for (final it in items) (it, 1 + rnd(5))];
      final nums = c.list('shopNums');
      final v = [
        for (var k = 0; k < ord.length; k++)
          k == 0
              ? g.audio.tpl('shopOrder', merge([w, nums[ord[k].$2 - 1], ord[k].$1]))
              : g.audio.tpl('shopAnd', merge([nums[ord[k].$2 - 1], ord[k].$1])),
      ];
      g.audio.preload(v);
      final ids = items.map((x) => x['id']).toSet();
      setState(() {
        who = w;
        order = ord;
        voice = v;
        shelf = shuffle([...items, ...sample(items0.where((x) => !ids.contains(x['id'])), 4 - items.length)]);
        basket.clear();
        happy = false;
        busy = false;
      });
      debugLifeAnswer = {for (final o in ord) asStr(o.$1['id']): o.$2};
      _speakOrder();
      await waitRound();
    }
    if (gone) return false;
    g.progress(_rounds, _rounds);
    return true;
  }

  Future<void> _speakOrder() async {
    final my = voice;
    for (final v in my) {
      if (gone || voice != my) return;
      await g.audio.say(v);
    }
  }

  void _add(Json it) {
    if (happy) return;
    setState(() => basket[asStr(it['id'])] = (basket[asStr(it['id'])] ?? 0) + 1);
    g.audio.sfx('pop');
  }

  void _remove(String id) {
    if (happy) return;
    setState(() => basket[id] = (basket[id] ?? 1) - 1);
    g.audio.sfx('tap');
  }

  Future<void> _deliver() async {
    if (busy || happy) return;
    final ok = order.every((o) => (basket[asStr(o.$1['id'])] ?? 0) == o.$2) &&
        basket.entries.every((e) => e.value == 0 || order.any((o) => o.$1['id'] == e.key));
    busy = true;
    if (ok) {
      g.audio.sfx('correct');
      g.cheer();
      setState(() => happy = true);
      await g.audio.sayPhrase('shopThanks');
      endRound();
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      g.sad();
      setState(() => wrongBump++);
      await g.audio.sayPhrase('shopWrong');
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (who == null) return const SizedBox.expand();
    final fs = baseFontSize(context);
    return LayoutBuilder(builder: (context, box) {
      final w = math.min(900.0, box.maxWidth - 24);
      final landscape = box.maxWidth > box.maxHeight * 1.2;
      // Ô kệ: theo bề ngang, nhưng không để tràn chiều cao.
      final shelfItem = math.min((w - 28 - 36) / 4, landscape ? (box.maxHeight - 250) : (box.maxHeight - 330) / 1.0).clamp(56.0, 170.0);
      // Điện thoại xoay ngang: 20% chiều cao có thể < 64 → lấy cận dưới nhỏ hơn (clamp lỗi khi min > max).
      final custMax = box.maxHeight * .2;
      final custImg = vwClamp(context, 80, 12, 120).clamp(math.min(64.0, custMax), custMax).toDouble();
      final shelfW = shelfItem * 4 + 36 + 28;
      final customer = Row(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
        GestureDetector(key: const Key('shop-customer'), onTap: _speakOrder, child: EmojiImage(asStr(who!['img']), size: custImg, photo: false)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: kCardShadow),
          child: happy
              ? PopIn(child: Text('😊', style: TextStyle(fontSize: custImg * .4)))
              : Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
                  for (final o in order)
                    Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                      Text('${o.$2}', style: TextStyle(fontSize: custImg * .34, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      EmojiImage(asStr(o.$1['img']), size: custImg * .4, photo: false),
                    ]),
                ]),
        ),
      ]);
      final shelfEl = Container(
        width: shelfW,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9C79A), Color(0xFFD4A373)]),
          borderRadius: BorderRadius.circular(24),
          border: const Border(bottom: BorderSide(color: Color(0x1F000000), width: 8)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final it in shelf)
            Chunky(
              key: Key('shelf-${it['id']}'),
              onTap: () => _add(it),
              pressScale: .94,
              depth: 0,
              radius: 20,
              color: Colors.white.withValues(alpha: .75),
              child: SizedBox(width: shelfItem, height: shelfItem, child: Center(child: EmojiImage(asStr(it['img']), size: shelfItem * .72, photo: false))),
            ),
        ]),
      );
      final items = [
        for (final e in basket.entries)
          for (var k = 0; k < e.value; k++)
            GestureDetector(
              key: Key('bitem-${e.key}-$k'),
              onTap: () => _remove(e.key),
              child: PopIn(child: EmojiImage(asStr(g.content.list('shopItems').firstWhere((x) => x['id'] == e.key)['img']), size: 44, photo: false)),
            ),
      ];
      final basketBox = Shake(
        trigger: wrongBump,
        child: Container(
          key: const Key('basket'),
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFC7D3E3), width: 4)),
          child: Row(spacing: 8, children: [
            const EmojiImage('Shopping cart', size: 56, photo: false),
            Expanded(child: Wrap(spacing: 4, runSpacing: 4, children: items)),
          ]),
        ),
      );
      final deliver = AppButton(key: const Key('deliver'), icon: '🛍️', label: g.i18n.t('deliver'), variant: BtnVariant.green, onTap: _deliver, fontSize: fs * 1.1);
      // Điện thoại dọc: giỏ cạnh nút chỉ còn chỗ cho 1 món/hàng → giỏ cao dần, kệ bị đẩy lên khi bé đang bấm.
      // Cho giỏ cả bề ngang, nút Giao hàng xuống dưới.
      final narrow = shelfW < 520;
      final basketRow = SizedBox(
        width: shelfW,
        child: narrow
            ? Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [basketBox, deliver])
            : Row(spacing: 14, children: [Expanded(child: basketBox), deliver]),
      );
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // Đơn hàng dài (3 món) trên máy hẹp: thu nhỏ hàng khách + bong bóng thay vì tràn ngang.
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [FittedBox(fit: BoxFit.scaleDown, child: customer), shelfEl, basketRow]),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------- Cân đĩa

class WeightView extends StatefulWidget {
  const WeightView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<WeightView> createState() => _WeightViewState();
}

class _WeightViewState extends _RoundsState<WeightView> {
  @override
  GameContext get g => widget.ctx;
  static const _rounds = 6;
  Json? a, b;
  String heavy = 'a';
  int tilt = 0;
  String? right, wrong;
  bool busy = false;

  @override
  Future<bool> run() async {
    final ws = g.content.list('weights');
    for (var r = 0; r < _rounds; r++) {
      if (gone) return false;
      g.progress(r, _rounds);
      Json x, y;
      do {
        final p = sample(ws, 2);
        x = p[0];
        y = p[1];
      } while ((asDouble(x['w']) - asDouble(y['w'])).abs() < 2);
      setState(() {
        a = x;
        b = y;
        heavy = asDouble(x['w']) > asDouble(y['w']) ? 'a' : 'b';
        tilt = 0;
        right = wrong = null;
        busy = false;
      });
      debugLifeAnswer = heavy;
      g.audio.sayPhrase('heavyQ');
      await waitRound();
    }
    if (gone) return false;
    g.progress(_rounds, _rounds);
    return true;
  }

  Future<void> _pick(String k) async {
    if (busy) return;
    busy = true;
    final heavyItem = heavy == 'a' ? a! : b!;
    setState(() => tilt = heavy == 'a' ? -1 : 1);
    if (k == heavy) {
      setState(() => right = k);
      g.audio.sfx('correct');
      g.cheer();
      await Future.wait([g.audio.say(g.audio.tpl('weightA', heavyItem)), wait(1200)]);
    } else {
      mistakes++;
      setState(() => wrong = k);
      g.audio.sfx('wrong');
      g.sad();
      await g.audio.say(g.audio.tpl('weightA', heavyItem));
      await wait(600);
    }
    endRound();
  }

  @override
  Widget build(BuildContext context) {
    if (a == null) return const SizedBox.expand();
    final ph = g.audio.phrase('heavyQ');
    return LayoutBuilder(builder: (context, box) {
      final scaleH = (box.maxHeight * .4).clamp(150.0, 280.0);
      final btn = math.min((math.min(box.maxWidth, 700) - 60) / 2, box.maxHeight - scaleH - 130).clamp(80.0, 260.0);
      Widget choice(String k, Json it) => SizedBox(
            key: Key('w-$k'),
            width: btn,
            height: btn,
            child: Chunky(
              onTap: () => _pick(k),
              radius: 32,
              depth: 8,
              color: right == k ? const Color(0xFFE7FBE9) : wrong == k ? const Color(0xFFFFE3E3) : Colors.white,
              shadowColor: right == k ? const Color(0xFF9FE3B0) : AppColors.line,
              child: Center(child: EmojiImage(asStr(it['img']), size: btn * .72)),
            ),
          );
      return Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
            PromptButton(label: ph.text, onTap: () => g.audio.sayPhrase('heavyQ')),
            SizedBox(width: math.min(560, box.maxWidth * .88), height: scaleH, child: BalanceScale(a: asStr(a!['img']), b: asStr(b!['img']), tilt: tilt)),
            Row(mainAxisSize: MainAxisSize.min, spacing: 24, children: [choice('a', a!), choice('b', b!)]),
          ]),
        ),
      );
    });
  }
}

/// Cân đĩa: tilt -1 = bên trái nặng (nghiêng trái), 1 = bên phải.
class BalanceScale extends StatelessWidget {
  const BalanceScale({super.key, required this.a, required this.b, this.tilt = 0});
  final String a, b;
  final int tilt;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final bw = w * .88;
        final pw = bw * .34, ph = math.min(90.0, h * .4);
        final cy = h * .3 + 6;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: tilt * 12.0),
          duration: const Duration(milliseconds: 600),
          curve: const Cubic(.3, 1.4, .6, 1),
          builder: (context, ang, _) {
            final r = ang * math.pi / 180;
            Offset end(double sx) => Offset(w / 2 + math.cos(r) * sx * .37 * bw, cy + math.sin(r) * sx * .37 * bw);
            Widget pan(String img, Offset p) => Positioned(
                  left: p.dx - pw / 2,
                  top: p.dy,
                  width: pw,
                  height: ph,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      border: const Border(bottom: BorderSide(color: Color(0xFFADB5BD), width: 8)),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(pw / 2)),
                    ),
                    child: Padding(padding: const EdgeInsets.only(bottom: 2), child: EmojiImage(img, size: math.min(pw * .7, ph * .9))),
                  ),
                );
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: w / 2 - 9,
                bottom: 0,
                width: 18,
                height: h * .7,
                child: Container(decoration: const BoxDecoration(color: Color(0xFF868E96), borderRadius: BorderRadius.vertical(top: Radius.circular(8)))),
              ),
              Positioned(
                left: w / 2 - 59,
                bottom: 0,
                width: 118,
                height: 16,
                child: Container(decoration: BoxDecoration(color: const Color(0xFF495057), borderRadius: BorderRadius.circular(8))),
              ),
              Positioned(
                left: w / 2 - bw / 2,
                top: cy - 6,
                width: bw,
                height: 12,
                child: Transform.rotate(
                  angle: r,
                  child: Container(decoration: BoxDecoration(color: const Color(0xFF495057), borderRadius: BorderRadius.circular(6))),
                ),
              ),
              pan(a, end(-1)),
              pan(b, end(1)),
            ]);
          },
        );
      });
}

// ---------------------------------------------------------------- Thứ trong tuần

class WeekView extends StatefulWidget {
  const WeekView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends _RoundsState<WeekView> {
  @override
  GameContext get g => widget.ctx;
  static const _rounds = 6;
  int today = 0, ans = 0;
  bool tomorrow = true, done = false;
  VoiceLine? q;
  final Map<int, int> shakes = {};

  @override
  Future<bool> run() async {
    final days = g.content.list('weekdays');
    for (var r = 0; r < _rounds; r++) {
      if (gone) return false;
      g.progress(r, _rounds);
      final t = rnd(7);
      final tm = r % 2 == 0;
      setState(() {
        today = t;
        tomorrow = tm;
        ans = (t + (tm ? 1 : 6)) % 7;
        q = g.audio.tpl(tm ? 'weekTomorrow' : 'weekYesterday', days[t]);
        done = false;
      });
      debugLifeAnswer = ans;
      g.audio.say(q);
      await waitRound();
    }
    if (gone) return false;
    g.progress(_rounds, _rounds);
    return true;
  }

  Future<void> _tap(int i) async {
    if (done) return;
    g.audio.say(g.audio.tpl('dayName', g.content.list('weekdays')[i]));
    if (i == ans) {
      setState(() => done = true);
      g.audio.sfx('correct');
      g.cheer();
      await wait(1300);
      endRound();
    } else {
      mistakes++;
      setState(() => shakes[i] = (shakes[i] ?? 0) + 1);
      g.audio.sfx('wrong');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (q == null) return const SizedBox.expand();
    final days = g.content.list('weekdays');
    return LayoutBuilder(builder: (context, box) {
      final w = math.min(900.0, box.maxWidth - 24);
      // 7 ô phải vừa một hàng: máy 320dp chỉ còn ~31px mỗi ô (không ép tối thiểu 36 → tràn).
      final cw = math.min((w - 6 * 8) / 7, 140.0);
      final ch = math.min(cw / .8, box.maxHeight - 120);
      final fs = vwClamp(context, 20, 3.4, 34).clamp(math.min(14.0, cw * .5), cw * .5).toDouble();
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
          PromptButton(label: '${g.i18n.t(tomorrow ? 'tomorrow' : 'yesterday')}?', onTap: () => g.audio.say(q)),
          Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
            for (final d in days)
              () {
                final i = asInt(d['i']);
                final isToday = i == today, ok = done && i == ans, wk = i >= 5;
                return Shake(
                  key: Key('day-$i'),
                  trigger: shakes[i] ?? 0,
                  child: Chunky(
                    onTap: () => _tap(i),
                    radius: 20,
                    depth: 5,
                    color: ok ? const Color(0xFFD3F9D8) : isToday ? const Color(0xFFFFF3BF) : Colors.white,
                    shadowColor: ok ? const Color(0xFF8CE99A) : isToday ? const Color(0xFFFFD43B) : AppColors.line,
                    child: SizedBox(
                      width: cw,
                      height: ch,
                      // FittedBox: ô hẹp trên điện thoại (cw ~43) không đủ cao cho chữ + sao → thu nhỏ, không tràn.
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                            Text(asStr(d['short']), style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: wk ? AppColors.bad : AppColors.ink)),
                            if (isToday) EmojiImage('Glowing star', size: cw * .5, photo: false),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              }(),
          ]),
        ]),
      );
    });
  }
}

// ---------------------------------------------------------------- Xem lịch

class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.ctx, this.now});
  final GameContext ctx;

  /// Ngày hôm nay (test cố định được).
  final DateTime? now;
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends _RoundsState<CalendarView> {
  @override
  GameContext get g => widget.ctx;
  static const _rounds = 5;
  late final DateTime now = widget.now ?? DateTime.now();
  late final int days = DateTime(now.year, now.month + 1, 0).day;
  late final int first = DateTime(now.year, now.month, 1).weekday - 1; // 0 = thứ hai
  int target = 0;
  bool done = false;
  VoiceLine? q;
  final Map<int, int> shakes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => g.hideBuddy());
  }

  @override
  Future<bool> run() async {
    final cal = g.content.list('calNums');
    await g.audio.sayPhrase('calendarIntro');
    final targets = sample(List.generate(days, (i) => i + 1), _rounds);
    for (var r = 0; r < _rounds; r++) {
      if (gone) return false;
      g.progress(r, _rounds);
      setState(() {
        target = targets[r];
        q = g.audio.tpl('findDate', cal[target - 1]);
        done = false;
      });
      debugLifeAnswer = target;
      g.audio.say(q);
      await waitRound();
    }
    if (gone) return false;
    g.progress(_rounds, _rounds);
    return true;
  }

  Future<void> _tap(int n) async {
    if (done) return;
    if (n == target) {
      setState(() => done = true);
      g.audio.sfx('correct');
      g.cheer();
      final cal = g.content.list('calNums');
      await g.audio.say(g.audio.tpl('dateIs', cal[n - 1]));
      if (gone) return;
      await g.audio.say(g.audio.tpl('isDay', g.content.list('weekdays')[(first + n - 1) % 7]));
      await wait(500);
      endRound();
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      setState(() => shakes[n] = (shakes[n] ?? 0) + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (q == null) return const SizedBox.expand();
    final wds = g.content.list('weekdays');
    final wd = (first + target - 1) % 7;
    return LayoutBuilder(builder: (context, box) {
      final rows = ((first + days) / 7).ceil();
      final w = math.min(640.0, box.maxWidth - 24);
      // Ô ngày: theo bề ngang, co lại nếu màn thấp.
      final cell = math.min((w - 20 - 24) / 7, (box.maxHeight - 90 - 50 - 40 - 20) / (rows * 1 + .9) * 1.1).clamp(28.0, 90.0);
      final ch = cell / 1.1;
      final fs = (cell * .38).clamp(14.0, 24.0);
      final gw = cell * 7 + 24 + 20;
      Widget head(Json d) {
        final i = asInt(d['i']);
        final hl = done && i == wd;
        return Container(
          width: cell,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: hl ? AppColors.sun : null, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(asStr(d['short']), style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * .9, color: hl ? AppColors.ink : i >= 5 ? AppColors.bad : AppColors.inkSoft)),
        );
      }

      Widget day(int n) {
        final wk = (first + n - 1) % 7 >= 5;
        final ok = done && n == target;
        final isNow = n == now.day;
        return Shake(
          key: Key('cd-$n'),
          trigger: shakes[n] ?? 0,
          child: GestureDetector(
            onTap: () => _tap(n),
            child: Container(
              width: cell,
              height: ch,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ok ? AppColors.good : const Color(0xFFF3F6FB),
                borderRadius: BorderRadius.circular(12),
                border: isNow ? Border.all(color: AppColors.blue, width: 3) : null,
              ),
              child: Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs, color: ok ? Colors.white : wk ? AppColors.bad : AppColors.ink)),
            ),
          ),
        );
      }

      final cells = <Widget>[for (var i = 0; i < first; i++) SizedBox(width: cell, height: ch), for (var n = 1; n <= days; n++) day(n)];
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
            PromptButton(label: q?.text ?? '', onTap: () => g.audio.say(q)),
            Container(
              width: gw,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: kCardShadow),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  color: AppColors.bad,
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.center,
                  child: Text(mt(g, 'month', {'m': now.month, 'y': now.year}),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * 1.3)),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                    Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [for (final d in wds) head(d)]),
                    for (var r = 0; r < rows; r++)
                      Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                        for (var k = r * 7; k < math.min(cells.length, r * 7 + 7); k++) cells[k],
                      ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}
