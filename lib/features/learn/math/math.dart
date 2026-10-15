// Đảo Toán vui: cộng trừ có hình, so sánh, số đến 20, cộng trừ nhẩm, xem đồng hồ, hình học, số đến 100, lớp 1 nâng cao.
// CHỦ: agent B. Port của reference/web/js/games/math.js.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'common.dart';

final GameModule mathModule = MathGame();

class MathGame extends GameModule {
  @override
  String get id => 'math';
  @override
  Widget build(BuildContext context, GameContext ctx) => MathView(ctx: ctx);
}

const int _round = 8;
const List<String> _pics = ['Red apple', 'Star', 'Fish', 'Soccer ball', 'Tangerine', 'Duck', 'Hibiscus', 'Cupcake', 'Balloon', 'Strawberry'];
const List<Color> _shapeColors = [Color(0xFFFF6B6B), Color(0xFF4FB3FF), Color(0xFF3CCF91), Color(0xFFFFC93C), Color(0xFFB388FF), Color(0xFFFF922B), Color(0xFFFF6FAE)];

String _pic() => _pics[rnd(_pics.length)];
String _sg(Object? op) => op == '+' ? '+' : '−';

/// Bộ câu hỏi theo lv.kind (KINDS của math.js).
List<QuizQuestion> mathQuestions(GameContext g, Json lv) {
  final b = _MathBuilder(g);
  return switch (asStr(lv['kind'])) {
    'position' => b.position(),
    'maxmin' => b.maxmin(lv),
    'seqnum' => b.seqnum(),
    'cmpexpr' => b.cmpexpr(),
    'missing' => b.missing(lv),
    'word' => b.word(lv),
    'chain' => b.chain(),
    'add2d' => b.twoDigit('add'),
    'sub2d' => b.twoDigit('sub'),
    'blocks' => b.blocksQ(),
    'next' => b.nextQ(),
    'cmp100' => b.cmp100(),
    'add100' => b.addSub100('add'),
    'sub100' => b.addSub100('sub'),
    'add' => b.addSub(lv, 'add'),
    'sub' => b.addSub(lv, 'sub'),
    'mix' => b.mix(lv),
    'cmp' => b.cmp(lv),
    'tens' => b.tens(),
    'clock' => b.clock(),
    'shape' => b.shape(),
    _ => b.addSub({'max': 5, 'pics': true}, 'add'),
  };
}

class MathView extends StatefulWidget {
  const MathView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<MathView> createState() => _MathViewState();
}

class _MathViewState extends State<MathView> {
  late final Json lv = widget.ctx.level ?? widget.ctx.content.list('mathLevels')[widget.ctx.levelIndex];
  late final List<QuizQuestion> qs = keepQuiz(mathQuestions(widget.ctx, lv));
  @override
  Widget build(BuildContext context) {
    final kind = asStr(lv['kind']);
    final intro = kind == 'add' || kind == 'sub' ? 'mathIntro' : kind == 'word' ? 'wordIntro' : null;
    return QuizView(ctx: widget.ctx, questions: qs, options: QuizOptions(intro: intro), onDone: widget.ctx.finish);
  }
}

class _MathBuilder {
  _MathBuilder(this.g);
  final GameContext g;
  Content get c => g.content;
  Json n100(int n) => c.list('nums100')[n];

  Widget _box(List<Widget> kids) => StageFit(child: Column(mainAxisSize: MainAxisSize.min, spacing: 10, children: kids));

  List<QuizQuestion> addSub(Json lv, String kind) {
    final add = kind == 'add';
    final mx = asInt(lv['max'], 10), mn = asInt(lv['min']);
    final facts = c.list(add ? 'addFacts' : 'subFacts').where((f) {
      final a = asInt(f['a']), b = asInt(f['b']), cc = asInt(f['c']);
      return a <= mx && b >= 1 && (add ? a >= 1 && cc <= mx && cc >= mn : a >= mn);
    });
    final pics = asBool(lv['pics']);
    final sign = add ? '+' : '−';
    return [
      for (final f in sample(facts, _round))
        () {
          final a = asInt(f['a']), b = asInt(f['b']), cc = asInt(f['c']);
          final pic = _pic();
          return QuizQuestion(
            say: g.audio.tpl(add ? 'addQ' : 'subQ', f),
            stage: (_) => _box([
              if (pics)
                add
                    ? Row(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
                        PicGroup(n: a, pic: pic),
                        Text('+', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        PicGroup(n: b, pic: pic),
                      ])
                    : PicGroup(n: a, pic: pic, crossFrom: a - b),
              EqBox.text('$a $sign $b = ?'),
            ]),
            choices: numChoices(near(cc, 4, 0, math.max(10, mx))),
            cls: 'nums',
            answer: cc,
            reward: g.audio.tpl(add ? 'addA' : 'subA', f),
            rewardNode: (_) => BigText('$a $sign $b = $cc'),
          );
        }(),
    ];
  }

  List<QuizQuestion> mix(Json lv) {
    final l2 = {...lv, 'pics': false};
    return shuffle([...addSub(l2, 'add').take(_round ~/ 2), ...addSub(l2, 'sub').take(_round ~/ 2)]);
  }

  List<QuizQuestion> cmp(Json lv) {
    final mx = asInt(lv['max'], 10);
    final facts = c.list('cmpFacts').where((f) {
      final a = asInt(f['a']), b = asInt(f['b']);
      return a <= mx && b <= mx && a >= 1 && b >= 1;
    });
    // Cân đối: khoảng 1/5 câu "bằng nhau".
    final eqs = facts.where((f) => f['a'] == f['b']), neq = facts.where((f) => f['a'] != f['b']);
    final picks = shuffle([...sample(eqs, 2), ...sample(neq, _round - 2)]);
    const sign = {'lớn hơn': '>', 'bé hơn': '<', 'bằng': '='};
    return [
      for (final f in picks)
        () {
          final pic = _pic();
          final a = asInt(f['a']), b = asInt(f['b']);
          final s = sign[f['rel']] ?? '=';
          Widget side(int n) => Column(mainAxisSize: MainAxisSize.min, spacing: 8, children: [PicGroup(n: n, pic: pic, maxWidth: 230), EqBox.text('$n')]);
          return QuizQuestion(
            say: g.audio.phrase('cmpQ', 'vi'),
            stage: (_) => StageFit(
              child: Row(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
                side(a),
                const EqBox([TextSpan(text: '?', style: TextStyle(color: Color(0xFFC7D3E3)))]),
                side(b),
              ]),
            ),
            choices: [for (final x in ['>', '<', '=']) mChoice(x, (_) => Text(x))],
            cls: 'nums',
            answer: s,
            reward: g.audio.tpl('cmpA', f),
            rewardNode: (_) => BigText('$a $s $b'),
          );
        }(),
    ];
  }

  List<QuizQuestion> tens() => [
        for (final n in sample([11, 12, 13, 14, 15, 16, 17, 18, 19, 20], _round))
          QuizQuestion(
            say: g.audio.phrase('tensQ', 'vi'),
            stage: (_) => StageFit(child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [TenFrame(on: 10), TenFrame(on: n - 10)])),
            choices: numChoices(near(n, 4, 10, 20)),
            cls: 'nums',
            answer: n,
            reward: g.audio.tpl('num', c.list('nums')[n]),
            rewardNode: (_) => BigText('10 + ${n - 10} = $n'),
          ),
      ];

  List<QuizQuestion> clock() => [
        for (final hh in sample(c.list('clockHours'), _round))
          () {
            final n = asInt(hh['n']);
            return QuizQuestion(
              say: g.audio.phrase('clockQ', 'vi'),
              stage: (ctx) => ClockFace(hour: n, size: vwClamp(ctx, 180, 30, 260).clamp(120, MediaQuery.sizeOf(ctx).height * .34)),
              choices: [for (final k in near(n, 3, 1, 12)) mChoice(k, (_) => Text(mt(g, 'hour', {'n': k})))],
              cls: 'nums',
              answer: n,
              reward: g.audio.tpl('clockA', hh),
              rewardNode: (ctx) => rewardColumn(ctx, [ClockFace(hour: n, size: vwClamp(ctx, 150, 22, 200)), SmallText(mt(g, 'hour', {'n': n}))]),
            );
          }(),
      ];

  List<QuizQuestion> shape() {
    final shapes = c.list('shapes');
    ShapeSpec spec(String id) => ShapeSpec(id, _shapeColors[rnd(_shapeColors.length)], id == 'circle' ? 0 : rnd(4) * 15 - 15);
    return [
      for (var i = 0; i < _round; i++)
        () {
          final sh = shapes[rnd(shapes.length)];
          final order = shuffle(shapes);
          final specs = {for (final x in order) asStr(x['id']): spec(asStr(x['id']))};
          final q = g.audio.tpl('shapeQ', sh);
          final ans = asStr(sh['id']);
          final rs = spec(ans);
          return QuizQuestion(
            say: q,
            label: asStr(sh['name']),
            choices: [for (final x in order) mChoice(asStr(x['id']), (_) => ShapeView(spec: specs[asStr(x['id'])]!, size: 100))],
            answer: ans,
            reward: g.audio.tpl('shapeA', sh),
            rewardNode: (ctx) => rewardColumn(ctx, [ShapeView(spec: rs, size: vwClamp(ctx, 130, 20, 190)), SmallText(asStr(sh['name']))]),
          );
        }(),
    ];
  }

  // ---------- Số đến 100 ----------
  String _tensText(int n) => n % 10 == 0 ? mt(g, 'tensOnly', {'t': n ~/ 10}) : mt(g, 'tensOnes', {'t': n ~/ 10, 'o': n % 10});

  List<QuizQuestion> blocksQ() => [
        for (final n in sample(List.generate(88, (i) => i + 11), _round))
          QuizQuestion(
            say: g.audio.phrase('blocksQ', 'vi'),
            stage: (_) => StageFit(child: Blocks(n: n)),
            choices: numChoices(near100(n)),
            cls: 'nums',
            answer: n,
            reward: g.audio.tpl('n100', n100(n)),
            rewardNode: (ctx) => rewardColumn(ctx, [Blocks(n: n, compact: true), BigText('$n'), SmallText(_tensText(n))]),
          ),
      ];

  List<QuizQuestion> nextQ() => [
        for (var i = 0; i < _round; i++)
          () {
            final after = i % 2 == 0;
            final n = after ? 1 + rnd(98) : 2 + rnd(98);
            final ans = after ? n + 1 : n - 1;
            final q = g.audio.tpl(after ? 'nextQ' : 'prevQ', n100(n));
            return QuizQuestion(
              say: q,
              label: q?.text,
              choices: numChoices(shuffle({ans, ans + 2, ans - 2, after ? n - 1 : n + 1}.where((k) => k >= 0 && k <= 100))),
              cls: 'nums',
              answer: ans,
              reward: g.audio.tpl('n100', n100(ans)),
              rewardNode: (_) => BigText(after ? '$n → $ans' : '$ans ← $n'),
            );
          }(),
      ];

  List<QuizQuestion> cmp100() => [
        for (var i = 0; i < _round; i++)
          () {
            final bigger = i % 2 == 0;
            int a, b;
            do {
              a = 10 + rnd(90);
              b = rng.nextDouble() < .5 ? a + (rng.nextDouble() < .5 ? 1 : -1) * (1 + rnd(9)) : 10 + rnd(90);
            } while (a == b || b < 10 || b > 99);
            final ans = bigger ? math.max(a, b) : math.min(a, b);
            final key = bigger ? 'biggerQ' : 'smallerQ';
            final ph = g.audio.phrase(key, 'vi');
            return QuizQuestion(
              say: ph,
              label: ph.text,
              choices: numChoices(shuffle([a, b])),
              cls: 'nums',
              answer: ans,
              reward: g.audio.tpl('n100', n100(ans)),
              rewardNode: (_) => BigText('${math.max(a, b)} > ${math.min(a, b)}'),
            );
          }(),
      ];

  List<QuizQuestion> addSub100(String kind) {
    final add = kind == 'add';
    final sign = add ? '+' : '−';
    return [
      for (final f in sample(c.list(add ? 'add100' : 'sub100'), _round))
        QuizQuestion(
          say: g.audio.tpl(add ? 'add100Q' : 'sub100Q', f),
          stage: (_) => StageFit(child: EqBox.text('${f['a']} $sign ${f['b']} = ?')),
          choices: numChoices(near100(asInt(f['c']))),
          cls: 'nums',
          answer: asInt(f['c']),
          reward: g.audio.tpl(add ? 'add100A' : 'sub100A', f),
          rewardNode: (_) => BigText('${f['a']} $sign ${f['b']} = ${f['c']}'),
        ),
    ];
  }

  // ---------- Lớp 1 nâng cao ----------
  List<QuizQuestion> missing(Json lv) {
    final mx = asInt(lv['max'], 10);
    final pool = [
      for (final f in c.list('addFacts')) {...f, 'k': 'add'},
      for (final f in c.list('subFacts')) {...f, 'k': 'sub'},
    ].where((f) {
      final a = asInt(f['a']), b = asInt(f['b']), cc = asInt(f['c']);
      return b >= 1 && a <= mx && cc <= mx && (mx <= 10 || math.max(a, cc) > 10);
    });
    return [
      for (final f in sample(pool, _round))
        () {
          final sign = f['k'] == 'add' ? '+' : '−';
          return QuizQuestion(
            say: g.audio.phrase('missQ', 'vi'),
            stage: (_) => StageFit(child: EqBox([TextSpan(text: '${f['a']} $sign '), blankSpan, TextSpan(text: ' = ${f['c']}')])),
            choices: numChoices(near(asInt(f['b']), 4, 1, mx)),
            cls: 'nums',
            answer: asInt(f['b']),
            reward: g.audio.tpl(f['k'] == 'add' ? 'addA' : 'subA', f),
            rewardNode: (_) => BigText('${f['a']} $sign ${f['b']} = ${f['c']}'),
          );
        }(),
    ];
  }

  List<QuizQuestion> word(Json lv) {
    final mx = asInt(lv['max'], 10);
    final pool = mx > 20
        ? c.list('wordProbs100')
        : c.list('wordProbs').where((w) {
            final a = asInt(w['a']), cc = asInt(w['c']);
            return mx <= 10 ? a <= 10 && cc <= 10 : math.max(a, cc) > 10;
          });
    return [
      for (final w in sample(pool, _round))
        QuizQuestion(
          say: g.audio.tpl('wordQ', w),
          stage: (ctx) => WordProb(img: asStr(w['img']), text: asStr(w['show'])),
          choices: numChoices(mx > 20 ? near100(asInt(w['c'])) : near(asInt(w['c']), 4, 0, math.max(10, mx))),
          cls: 'nums',
          answer: asInt(w['c']),
          reward: g.audio.tpl('wordA', w),
          rewardNode: (ctx) => rewardColumn(ctx, [BigText('${w['a']} ${_sg(w['op'])} ${w['b']} = ${w['c']}'), SmallText('${w['c']} ${w['unit'] ?? ''}')]),
        ),
    ];
  }

  List<QuizQuestion> chain() => [
        for (final f in sample(c.list('chainFacts'), _round))
          () {
            final text = '${f['a']} ${_sg(f['o1'])} ${f['b']} ${_sg(f['o2'])} ${f['d']}';
            return QuizQuestion(
              say: g.audio.tpl('chainQ', f),
              stage: (_) => StageFit(child: EqBox.text('$text = ?')),
              choices: numChoices(near(asInt(f['c']), 4, 0, 10)),
              cls: 'nums',
              answer: asInt(f['c']),
              reward: g.audio.tpl('chainA', f),
              rewardNode: (_) => BigText('$text = ${f['c']}'),
            );
          }(),
      ];

  /// Cộng trừ hai chữ số: đặt tính dọc như vở lớp 1.
  List<QuizQuestion> twoDigit(String kind) {
    final add = kind == 'add';
    final sign = add ? '+' : '−';
    return [
      for (final f in sample(c.list(add ? 'add2d' : 'sub2d'), _round))
        QuizQuestion(
          say: g.audio.tpl(add ? 'add100Q' : 'sub100Q', f),
          stage: (_) => StageFit(child: VCol(a: asInt(f['a']), b: asInt(f['b']), sign: sign)),
          choices: numChoices(near100(asInt(f['c']))),
          cls: 'nums',
          answer: asInt(f['c']),
          reward: g.audio.tpl(add ? 'add100A' : 'sub100A', f),
          rewardNode: (_) => BigText('${f['a']} $sign ${f['b']} = ${f['c']}'),
        ),
    ];
  }

  /// Vị trí: vật ở giữa, bốn vật xung quanh. Trái/phải tính theo mắt bé nhìn.
  List<QuizQuestion> position() => [
        for (final q in sample(c.list('posQs'), _round))
          () {
            final items = asMap(q['items']);
            return QuizQuestion(
              say: g.audio.tpl('posQ', q),
              label: asStr(q['t']),
              stage: (_) => StageFit(heightFrac: .34, child: PosGrid(center: asStr(q['center']), items: items.map((k, v) => MapEntry(k, asStr(v))))),
              choices: [for (final x in shuffle(items.values.map(asStr))) mChoice(x, (_) => EmojiImage(x, size: 120))],
              answer: asStr(q['answer']),
              reward: g.audio.tpl('posA', q),
            );
          }(),
      ];

  List<QuizQuestion> maxmin(Json lv) {
    final mx = asInt(lv['max'], 10);
    return [
      for (var i = 0; i < _round; i++)
        () {
          final big = i % 2 == 0;
          final set = <int>{};
          while (set.length < 4) {
            set.add(mx <= 10 ? rnd(11) : 10 + rnd(90));
          }
          final nums = set.toList();
          final ans = big ? nums.reduce(math.max) : nums.reduce(math.min);
          final ph = g.audio.phrase(big ? 'biggestQ' : 'smallestQ', 'vi');
          return QuizQuestion(
            say: ph,
            label: ph.text,
            choices: numChoices(shuffle(nums)),
            cls: 'nums',
            answer: ans,
            reward: ans != 0 ? g.audio.tpl('n100', n100(ans)) : g.audio.tpl('num', c.list('nums')[0]),
            rewardNode: (_) => BigText('$ans'),
          );
        }(),
    ];
  }

  /// Dãy số cách đều: 2, 4, 6, ? hoặc 10, 20, 30, ?
  List<QuizQuestion> seqnum() {
    final out = <QuizQuestion>[];
    for (var i = 0; i < _round; i++) {
      final step = const [1, 2, 5, 10][rnd(4)];
      final down = rng.nextDouble() < .25;
      const len = 4;
      final maxStart = 99 - step * len;
      final a = step == 10 ? 10 * (1 + rnd(5)) : step == 5 ? 5 * rnd(10) : 1 + rnd(math.max(1, maxStart));
      var seq = List.generate(len, (k) => a + k * step);
      if (down) seq = seq.reversed.toList();
      final ans = down ? seq[len - 1] - step : seq[len - 1] + step;
      if (ans <= 0 || ans > 99) continue;
      out.add(QuizQuestion(
        say: g.audio.phrase('nextNumQ', 'vi'),
        stage: (_) => StageFit(child: EqBox([TextSpan(text: '${seq.join(', ')}, '), blankSpan])),
        choices: numChoices(shuffle({ans, ans + step, ans - step, ans + 1}.where((k) => k > 0 && k < 100)).take(4)),
        cls: 'nums',
        answer: ans,
        reward: g.audio.tpl('n100', n100(ans)),
        rewardNode: (_) => BigText([...seq, ans].join(', ')),
      ));
    }
    return out;
  }

  List<QuizQuestion> cmpexpr() => [
        for (final f in sample(c.list('cmpExpr'), _round))
          QuizQuestion(
            say: g.audio.phrase('cmpExprQ', 'vi'),
            stage: (_) => StageFit(child: EqBox([TextSpan(text: '${f['a']} ${_sg(f['op'])} ${f['b']} '), blankSpan, TextSpan(text: ' ${f['n']}')])),
            choices: [for (final x in ['>', '<', '=']) mChoice(x, (_) => Text(x))],
            cls: 'nums',
            answer: asStr(f['rel']),
            reward: g.audio.tpl('cmpExprA', f),
            rewardNode: (_) => BigText('${f['a']} ${_sg(f['op'])} ${f['b']} ${f['rel']} ${f['n']}'),
          ),
      ];
}

// ---------------------------------------------------------------- Hình minh hoạ

/// Nhóm hình (.group); từ crossFrom trở đi bị gạch (phép trừ).
class PicGroup extends StatelessWidget {
  const PicGroup({super.key, required this.n, required this.pic, int? crossFrom, this.maxWidth = 330}) : crossFrom = crossFrom ?? n;
  final int n;
  final String pic;
  final int crossFrom;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final sz = vwClamp(context, 40, 6.4, 62);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(22)),
      child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < n; i++)
          SizedBox(
            width: sz,
            height: sz,
            child: i >= crossFrom
                ? Stack(alignment: Alignment.center, children: [
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .3, 0]),
                      child: EmojiImage(pic, size: sz, photo: false),
                    ),
                    Text('✕', style: TextStyle(color: AppColors.bad, fontSize: sz * .7, fontWeight: FontWeight.w800)),
                  ])
                : EmojiImage(pic, size: sz, photo: false),
          ),
      ]),
    );
  }
}

/// Khung 10 ô (.frame): n ô tô đỏ.
class TenFrame extends StatelessWidget {
  const TenFrame({super.key, required this.on});
  final int on;
  @override
  Widget build(BuildContext context) {
    final d = vwClamp(context, 34, 6, 56);
    Widget dot(int i) => Container(
          width: d,
          height: d,
          decoration: i < on
              ? const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFF9F80), Color(0xFFFF6B6B)]))
              : BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD9E2EE), width: 3)),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: solidShadow(AppColors.line, 5)),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
        for (var r = 0; r < 2; r++) Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [for (var k = 0; k < 5; k++) dot(r * 5 + k)]),
      ]),
    );
  }
}

/// Mặt đồng hồ chỉ giờ đúng (kim phút ở số 12).
class ClockFace extends StatelessWidget {
  const ClockFace({super.key, required this.hour, this.size = 220});
  final int hour;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ClockPainter(hour)));
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.hour);
  final int hour;
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200;
    canvas.scale(k);
    const c = Offset(100, 100);
    canvas.drawCircle(c, 94, Paint()..color = Colors.white);
    canvas.drawCircle(c, 94, Paint()
      ..color = AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8);
    for (var n = 1; n <= 12; n++) {
      final a = n / 12 * math.pi * 2;
      final tp = TextPainter(
        text: TextSpan(text: '$n', style: const TextStyle(fontFamily: kFontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(100 + math.sin(a) * 74 - tp.width / 2, 100 - math.cos(a) * 74 - tp.height / 2));
    }
    canvas.drawLine(c, const Offset(100, 30), Paint()
      ..color = AppColors.inkSoft
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    final ha = (hour % 12) / 12 * math.pi * 2;
    canvas.drawLine(c, Offset(100 + math.sin(ha) * 48, 100 - math.cos(ha) * 48), Paint()
      ..color = AppColors.primary
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 7, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.hour != hour;
}

/// Hình học: id (circle, square, triangle, rect), màu và góc xoay cố định khi tạo câu.
class ShapeSpec {
  const ShapeSpec(this.id, this.color, this.rot);
  final String id;
  final Color color;
  final int rot;
}

class ShapeView extends StatelessWidget {
  const ShapeView({super.key, required this.spec, this.size = 100});
  final ShapeSpec spec;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _ShapePainter(spec)));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.s);
  final ShapeSpec s;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.translate(50, 50);
    canvas.rotate(s.rot * math.pi / 180);
    canvas.translate(-50, -50);
    final fill = Paint()..color = s.color;
    final stroke = Paint()
      ..color = const Color(0x26000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    final path = switch (s.id) {
      'circle' => Path()..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 38)),
      'square' => Path()..addRRect(RRect.fromLTRBR(14, 14, 86, 86, const Radius.circular(6))),
      'triangle' => Path()
        ..moveTo(50, 10)
        ..lineTo(90, 84)
        ..lineTo(10, 84)
        ..close(),
      _ => Path()..addRRect(RRect.fromLTRBR(6, 28, 94, 74, const Radius.circular(6))),
    };
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.s != s;
}

/// Khối chục (thanh) và đơn vị (khối lập phương).
class Blocks extends StatelessWidget {
  const Blocks({super.key, required this.n, this.compact = false});
  final int n;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final w = vwClamp(context, 14, 2.6, 22), h = vwClamp(context, 9, 1.7, 14);
    Widget rod() => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: const Color(0xFF1C7ED6), borderRadius: BorderRadius.circular(6)),
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
            for (var i = 0; i < 10; i++)
              Container(width: w, height: h, decoration: BoxDecoration(color: const Color(0xFF74C0FC), borderRadius: BorderRadius.circular(3))),
          ]),
        );
    Widget cube() => Container(
          width: w,
          height: w,
          decoration: BoxDecoration(
            color: const Color(0xFFFFA94D),
            borderRadius: BorderRadius.circular(4),
            border: const Border(bottom: BorderSide(color: Color(0x26000000), width: 3)),
          ),
        );
    final ones = n % 10;
    return Container(
      padding: compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(22), boxShadow: solidShadow(AppColors.line, 5)),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, spacing: compact ? 10 : 22, children: [
        Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [for (var i = 0; i < n ~/ 10; i++) rod()]),
        if (ones > 0)
          Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
            for (var r = 0; r < (ones / 3).ceil(); r++)
              Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [for (var k = r * 3; k < math.min(ones, r * 3 + 3); k++) cube()]),
          ]),
      ]),
    );
  }
}

/// Bài toán có lời văn (.wordprob).
class WordProb extends StatelessWidget {
  const WordProb({super.key, required this.img, required this.text});
  final String img;
  final String text;
  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return Container(
      constraints: BoxConstraints(maxWidth: math.min(760, s.width - 24)),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: solidShadow(AppColors.line)),
      child: Row(spacing: 16, children: [
        EmojiImage(img, size: vwClamp(context, 90, 13, 130)),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: vwClamp(context, 18, 3, 28), fontWeight: FontWeight.w700, height: 1.35, color: AppColors.ink)),
        ),
      ]),
    );
  }
}

/// Đặt tính dọc (.vcol).
class VCol extends StatelessWidget {
  const VCol({super.key, required this.a, required this.b, required this.sign});
  final int a, b;
  final String sign;
  @override
  Widget build(BuildContext context) {
    final fs = vwClamp(context, 54, 9, 90);
    final st = TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 34, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: solidShadow(AppColors.line)),
      child: DefaultTextStyle(
        style: st,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$a'),
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink, width: 6))),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 18, children: [Text(sign, style: const TextStyle(color: AppColors.primary)), Text('$b')]),
          ),
          const Text('?', style: TextStyle(color: Color(0xFFC7D3E3))),
        ]),
      ),
    );
  }
}

/// Lưới vị trí 3×3: trên, trái, giữa, phải, dưới.
class PosGrid extends StatelessWidget {
  const PosGrid({super.key, required this.center, required this.items});
  final String center;
  final Map<String, String> items;
  @override
  Widget build(BuildContext context) {
    final cell = vwClamp(context, 46, 8, 80);
    Widget at(String? name, {double k = .86}) =>
        SizedBox(width: cell, height: cell, child: name == null ? null : Center(child: EmojiImage(name, size: cell * k)));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: solidShadow(AppColors.line)),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
        Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [at(null), at(items['top']), at(null)]),
        Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [at(items['left']), at(center, k: 1), at(items['right'])]),
        Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [at(null), at(items['bottom']), at(null)]),
      ]),
    );
  }
}
