// Đảo Số đếm: chạm từng hình để đếm (bé nghe "một, hai, ba…"), rồi chọn số đúng.
// CHỦ: agent B. Port của web js/games/count.js.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'common.dart';

final GameModule countModule = CountGame();

class CountGame extends GameModule {
  @override
  String get id => 'count';
  @override
  Widget build(BuildContext context, GameContext ctx) => CountView(ctx: ctx);
}

const int _round = 6;

// Số 1–10 dùng numbers, 11–100 dùng nums100 (cùng câu đọc "mười một"...).
Json _numOf(Content c, int n) => n <= 10 ? c.list('numbers')[n - 1] : c.list('nums100')[n];
VoiceLine? _voiceN(AudioService a, Content c, int n) => n <= 10 ? a.tpl('number', c.list('numbers')[n - 1]) : a.tpl('n100', c.list('nums100')[n]);

/// Bộ câu hỏi bài li (questions() của count.js).
List<QuizQuestion> countQuestions(GameContext g) {
  final content = g.content;
  final lv = g.level ?? content.list('countLevels')[g.levelIndex];
  final mn = asInt(lv['min'], 1), mx = asInt(lv['max'], 3);
  final round = asBool(lv['round']), tens = asBool(lv['tens']);
  final nChoices = asInt(lv['choices'], 3);
  final range = <int>[for (var k = mn; k <= mx; k++) if (!round || k % 10 == 0) k];
  final picks = <int>[];
  while (picks.length < _round) {
    final n = range[rnd(range.length)];
    if (picks.isEmpty || picks.last != n || range.length == 1) picks.add(n);
  }
  final allThings = content.list('things');
  final things = shuffle(mx > 10 ? allThings.where((x) => !asBool(x['big'])) : allThings);
  final a = g.audio;
  return [
    for (var i = 0; i < picks.length; i++)
      () {
        final n = picks[i];
        final thing = things[i % things.length];
        final num = _numOf(content, n);
        // Số nhiễu gần đáp án; số lớn: lệch 1 và lệch 10 (nhầm số chục).
        final cand = tens ? (round ? [n - 10, n + 10, n - 20, n + 20] : [n - 1, n + 1, n - 10, n + 10]) : [n - 2, n - 1, n + 1, n + 2];
        final hi = math.max(10, mx);
        final nearL = shuffle(cand.where((k) => k >= 1 && k <= math.max(hi, 100) && (tens || k <= hi)));
        final choices = shuffle([n, ...nearL.take(nChoices - 1)]);
        final q = a.tpl('howMany', thing);
        final img = asStr(thing['img']);
        return QuizQuestion(
          say: q,
          label: q?.text,
          stage: (_) => StageFit(
            heightFrac: n > 10 ? .42 : .36,
            child: tens ? TensBoard(key: ValueKey('board-$i'), n: n, img: img, g: g) : CountBoard(key: ValueKey('board-$i'), n: n, img: img, g: g),
          ),
          choices: numChoices(choices),
          cls: 'nums',
          answer: n,
          reward: n <= 10 ? a.tpl('countAnswer', merge([num, thing])) : a.tpl('n100', num),
          rewardNode: (c) => rewardColumn(c, [
            EmojiImage(img, size: rewardImg(c), photo: false),
            BigText('$n'),
            SmallText('${num['num']} ${thing['name']}'),
          ]),
        );
      }(),
  ];
}

class CountView extends StatefulWidget {
  const CountView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<CountView> createState() => _CountViewState();
}

class _CountViewState extends State<CountView> {
  late final List<QuizQuestion> qs = keepQuiz(countQuestions(widget.ctx));
  @override
  Widget build(BuildContext context) => QuizView(ctx: widget.ctx, questions: qs, onDone: widget.ctx.finish);
}

/// Bảng đếm: chạm từng hình, hình được gắn số thứ tự.
class CountBoard extends StatefulWidget {
  const CountBoard({super.key, required this.n, required this.img, required this.g});
  final int n;
  final String img;
  final GameContext g;
  @override
  State<CountBoard> createState() => _CountBoardState();
}

class _CountBoardState extends State<CountBoard> {
  final Map<int, int> tags = {};

  void _tap(int i) {
    if (tags.containsKey(i)) return;
    setState(() => tags[i] = tags.length + 1);
    widget.g.audio.sfx('count');
    widget.g.audio.say(_voiceN(widget.g.audio, widget.g.content, tags[i]!));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final many = n > 10;
    final cols = n <= 5 ? n : n <= 10 ? (n / 2).ceil() : 5;
    final size = many ? vwClamp(context, 52, 8, 84) : vwClamp(context, 80, 13, 130);
    final gap = vwClamp(context, 8, 1.6, 18);
    final rows = (n / cols).ceil();
    return Padding(
      padding: EdgeInsets.all(many ? 8 : 18),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
        for (var r = 0; r < rows; r++)
          Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
            for (var i = r * cols; i < math.min(n, (r + 1) * cols); i++) _item(i, size),
          ]),
      ]),
    );
  }

  Widget _item(int i, double size) {
    final counted = tags.containsKey(i);
    return GestureDetector(
      key: ValueKey('count-item-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(i),
      child: AnimatedScale(
        scale: counted ? 1.06 : 1,
        duration: const Duration(milliseconds: 150),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: counted ? const Color(0xFFFFF7D6) : Colors.white.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(24),
              border: counted ? Border.all(color: AppColors.sun, width: 4) : null,
            ),
            child: EmojiImage(widget.img, size: size * .82, photo: false),
          ),
          if (counted)
            Positioned(
              top: -10,
              right: -8,
              child: PopIn(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 38),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(19)),
                  child: Text('${tags[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Đếm theo chục (số lớn tới 100): mỗi thanh 10 hình, chạm thanh đếm "mười, hai mươi…", rồi chạm từng hình lẻ.
class TensBoard extends StatefulWidget {
  const TensBoard({super.key, required this.n, required this.img, required this.g});
  final int n;
  final String img;
  final GameContext g;
  @override
  State<TensBoard> createState() => _TensBoardState();
}

class _TensBoardState extends State<TensBoard> {
  int counted = 0, bump = 0, hint = -1;
  final Set<int> bars = {}, ones = {};

  int get tens => widget.n ~/ 10;

  void _add(int by) {
    setState(() {
      counted += by;
      bump++;
    });
    widget.g.audio.sfx('count');
    widget.g.audio.say(_voiceN(widget.g.audio, widget.g.content, counted));
  }

  void _bar(int i) {
    if (bars.contains(i)) return;
    bars.add(i);
    if (hint == i) hint = -1;
    _add(10);
  }

  void _one(int i) {
    if (ones.contains(i)) return;
    if (bars.length < tens) {
      widget.g.audio.sfx('wrong');
      setState(() => hint = List.generate(tens, (k) => k).firstWhere((k) => !bars.contains(k)));
      return;
    }
    ones.add(i);
    _add(1);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.n % 10;
    const im = 34.0;
    return Padding(
      padding: const EdgeInsets.only(right: 76, top: 8),
      child: Stack(clipBehavior: Clip.none, children: [
        Column(mainAxisSize: MainAxisSize.min, spacing: 10, children: [
          for (var r = 0; r < (tens / 2).ceil(); r++)
            Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
              for (var i = r * 2; i < math.min(tens, r * 2 + 2); i++)
                GestureDetector(
                  key: ValueKey('ten-bar-$i'),
                  onTap: () => _bar(i),
                  child: Shake(
                    trigger: hint == i ? 1 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: bars.contains(i) ? const Color(0xFFFFF7D6) : Colors.white.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: bars.contains(i) ? AppColors.sun : hint == i ? AppColors.bad : Colors.transparent, width: 4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [for (var k = 0; k < 10; k++) EmojiImage(widget.img, size: im, photo: false)]),
                    ),
                  ),
                ),
            ]),
          if (o > 0)
            Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
              for (var i = 0; i < o; i++)
                GestureDetector(
                  key: ValueKey('one-$i'),
                  onTap: () => _one(i),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ones.contains(i) ? const Color(0xFFFFF7D6) : Colors.white.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(20),
                      border: ones.contains(i) ? Border.all(color: AppColors.sun, width: 4) : null,
                    ),
                    child: EmojiImage(widget.img, size: 50, photo: false),
                  ),
                ),
            ]),
        ]),
        Positioned(
          top: -6,
          right: -76,
          child: Bump(
            trigger: bump,
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(32)),
              child: Text('$counted', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34)),
            ),
          ),
        ),
      ]),
    );
  }
}
