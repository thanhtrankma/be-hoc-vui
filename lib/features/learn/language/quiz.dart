// Khuôn "nghe rồi chọn" (port games/quiz.js): dùng cho chữ cái, tiếng Anh, ghép vần, đếm số, toán, đời sống, tư duy, ôn tập...
// CHỦ: agent A. API công khai GIỮ ỔN ĐỊNH cho agent B/C/E:
//   starsFor, kRound, QuizChoice, QuizReward, QuizQuestion, QuizOptions, QuizView (+ re-export sequence/shuffle/sample).
// Mở rộng (tuỳ chọn, không phá chữ ký cũ):
//   QuizChoice.text            — chữ bay vào ô trống (mặc định '$id').
//   QuizReward.timedNode       — thẻ thưởng có hoạt ảnh theo độ dài câu đọc (đánh vần chữ sáng dần).
//   QuizOptions.fly            — chữ đúng bay vào QuizBlank đầu tiên còn trống (Ghép vần), rồi cả từ nảy lên.
//   QuizView.onProgress        — đổi cách báo tiến độ (truyện: câu hỏi nối tiếp sau các trang).
//   Widget tiện dụng: QuizImg, QuizWordPic, QuizWordShow, QuizBlank, QuizSent, QuizWordRow, RewardContent, Swatch,
//   QuizCell.of(context) (kích thước thẻ lựa chọn đang vẽ).
// Hình trong thẻ lựa chọn: dùng QuizImg(name) (tự lấy cỡ theo thẻ) hoặc EmojiImage(name) — khuôn tự co cho vừa thẻ.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'fx.dart';

export 'package:be_vui_hoc/core/ui/utils.dart' show sequence, shuffle, sample;

/// Số câu một bài của các khuôn chọn đáp án (ROUND của web).
const int kRound = 8;

/// 0 lỗi = 3 sao, ≤ 2 lỗi = 2 sao, còn lại 1 sao.
int starsFor(int mistakes) => mistakes == 0 ? 3 : mistakes <= 2 ? 2 : 1;

/// Một lựa chọn: id so với answer; node vẽ nội dung thẻ.
class QuizChoice {
  const QuizChoice({required this.id, required this.node, this.text});
  final Object id;
  final WidgetBuilder node;

  /// Chữ của thẻ (dùng khi bay vào ô trống). null → '$id'.
  final String? text;
}

/// Thẻ thưởng sau khi đúng (pickReward của web: {say, node, anim, min}).
class QuizReward {
  const QuizReward({this.say = const [], this.node, this.minMs, this.timedNode});
  final List<VoiceLine?> say;
  final WidgetBuilder? node;
  final int? minMs;

  /// Thẻ có hoạt ảnh chạy theo độ dài (giây) câu đọc đầu tiên (anim(card, dur) của web). Có thì thay cho node.
  final Widget Function(BuildContext context, double voiceSeconds)? timedNode;
}

/// Một câu hỏi {say, label, stage?, choices, answer, reward, rewardNode, cls?} như web.
class QuizQuestion {
  const QuizQuestion({
    this.say,
    this.label,
    this.labelStyle,
    this.stage,
    required this.choices,
    required this.answer,
    this.reward,
    this.rewardNode,
    this.cls,
    this.cols,
    this.preload = const [],
    this.onRight,
    this.pickReward,
    this.key,
  });

  /// Câu đọc đề (nút 🔊 đọc lại).
  final VoiceLine? say;

  /// Chữ trên nút đề.
  final String? label;

  /// Kiểu chữ đặc biệt cho label (labelCls của web: 'upper', 'readword', 'readsent').
  final String? labelStyle;

  /// Phần minh hoạ giữa đề và lựa chọn (hình, phép tính...).
  final WidgetBuilder? stage;
  final List<QuizChoice> choices;
  final Object answer;
  final VoiceLine? reward;
  final WidgetBuilder? rewardNode;

  /// Kiểu lưới lựa chọn (cls của web: 'syll', 'nums', 'words', 'syll words', 'towers', 'pencils'...).
  final String? cls;

  /// Số cột (mặc định = số lựa chọn).
  final int? cols;
  final List<VoiceLine> preload;

  /// Hiệu ứng riêng chạy trước thẻ thưởng.
  final Future<void> Function()? onRight;
  final QuizReward Function({required bool missed, required int streak})? pickReward;

  /// Khoá tuỳ ý (ôn tập dùng để biết câu thuộc mục nào).
  final String? key;
}

class QuizOptions {
  const QuizOptions({this.intro, this.minRewardMs, this.combo = false, this.fly = false});

  /// Khoá câu dẫn (voice.json) đọc trước câu đầu.
  final String? intro;
  final int? minRewardMs;

  /// Đếm chuỗi đúng liên tiếp (🔥 3 liền!).
  final bool combo;

  /// Chữ đúng bay vào ô trống (QuizBlank) trước khi hiện thẻ thưởng.
  final bool fly;
}

// ---------------------------------------------------------------------------------------------------------------
// Phạm vi chung của một câu: ô trống đã điền, đang đọc đề (từ/hình nhún), kích thước thẻ.

class _QuizFx {
  final Map<int, GlobalKey> blanks = {};
  final Map<int, String> filled = {};
  final Map<int, double> blankFont = {};
  int merge = 0;
  bool saying = false;
  void reset() {
    blanks.clear();
    filled.clear();
    blankFont.clear();
    merge = 0;
    saying = false;
  }
}

class _QuizScope extends InheritedWidget {
  const _QuizScope({required this.fx, required this.saying, required this.merge, required this.filledCount, required super.child});
  final _QuizFx fx;
  final bool saying;
  final int merge;
  final int filledCount;
  static _QuizScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_QuizScope>();
  @override
  bool updateShouldNotify(_QuizScope old) => old.saying != saying || old.merge != merge || old.filledCount != filledCount;
}

/// Kích thước thẻ lựa chọn đang vẽ (để hình/chữ trong thẻ tự lấy cỡ).
class QuizCell extends InheritedWidget {
  const QuizCell({super.key, required this.size, required super.child});
  final Size size;
  static Size? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<QuizCell>()?.size;
  @override
  bool updateShouldNotify(QuizCell old) => old.size != size;
}

/// Thẻ thưởng đang vẽ (hình to hơn).
class _RewardScope extends InheritedWidget {
  const _RewardScope({required super.child});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_RewardScope>() != null;
  @override
  bool updateShouldNotify(_RewardScope old) => false;
}

/// Hình emoji tự lấy cỡ: trong thẻ lựa chọn = 80% thẻ; trong thẻ thưởng = clamp(140, 22vw, 220); còn lại = size.
class QuizImg extends StatelessWidget {
  const QuizImg(this.name, {super.key, this.size, this.photo = true});
  final String name;
  final double? size;
  final bool photo;
  @override
  Widget build(BuildContext context) {
    final cell = QuizCell.of(context);
    final s = size ?? (cell != null ? cell.shortestSide * .8 : _RewardScope.of(context) ? vwClamp(context, 140, 22, 220) : 120);
    return EmojiImage(name, size: s, photo: photo);
  }
}

/// Chấm màu tròn (.swatch).
class Swatch extends StatelessWidget {
  const Swatch(this.color, {super.key, this.size});
  final Color color;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final cell = QuizCell.of(context);
    final s = size ?? (cell != null ? cell.shortestSide * .7 : _RewardScope.of(context) ? vwClamp(context, 120, 18, 180) : 90);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: const Color(0xFFEEF2F7), width: 4),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color, Color.lerp(color, Colors.black, .12)!], stops: const [0, .85, 1]),
      ),
    );
  }
}

/// Hình minh hoạ của đề (.word-pic): nhún nhẹ khi đang đọc đề.
class QuizWordPic extends StatelessWidget {
  const QuizWordPic(this.img, {super.key, this.size});
  final String img;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final saying = _QuizScope.of(context)?.saying ?? false;
    final s = size ?? vwClamp(context, 140, 22, 230);
    return Pulse(
      on: saying,
      scale: 1.04,
      dy: -6,
      ms: 550,
      child: EmojiImage(img, size: s),
    );
  }
}

/// Hàng hình + chữ (.word-row).
class QuizWordRow extends StatelessWidget {
  const QuizWordRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, spacing: vwClamp(context, 12, 3, 30), children: children);
}

/// Ô chữ trắng to (.word-show): con là chữ và QuizBlank. Nảy lên khi ô trống vừa được điền.
class QuizWordShow extends StatelessWidget {
  const QuizWordShow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final sc = _QuizScope.of(context);
    final fs = vwClamp(context, 64, 11, 120);
    return PopOnce(
      trigger: sc?.merge ?? 0,
      scale: 1.12,
      ms: 450,
      child: Pulse(
        on: sc?.saying ?? false,
        scale: 1.04,
        dy: -6,
        ms: 550,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: solidShadow(AppColors.line)),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1, color: AppColors.ink),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children),
          ),
        ),
      ),
    );
  }
}

/// Câu xếp chữ (.sent): các từ cách nhau, ô trống là QuizBlank.
class QuizSent extends StatelessWidget {
  const QuizSent({super.key, required this.children, this.maxWidth = 760});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final sc = _QuizScope.of(context);
    final fs = vwClamp(context, 30, 5, 54);
    return PopOnce(
      trigger: sc?.merge ?? 0,
      scale: 1.12,
      ms: 450,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: solidShadow(AppColors.line)),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1.15, color: AppColors.ink),
          child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: children),
        ),
      ),
    );
  }
}

/// Ô trống "?" gạch đứt; chữ đúng bay vào thì thành chữ xanh. slot: thứ tự ô (ô nhỏ nhất còn trống được điền trước).
class QuizBlank extends StatefulWidget {
  const QuizBlank({super.key, this.slot = 0, this.minWidthEm = .7});
  final int slot;
  final double minWidthEm;
  @override
  State<QuizBlank> createState() => _QuizBlankState();
}

class _QuizBlankState extends State<QuizBlank> {
  final GlobalKey _key = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final sc = _QuizScope.of(context);
    final style = DefaultTextStyle.of(context).style;
    final fs = style.fontSize ?? 40;
    final filled = sc?.fx.filled[widget.slot];
    if (sc != null) {
      sc.fx.blanks[widget.slot] = _key;
      sc.fx.blankFont[widget.slot] = fs;
    }
    if (filled != null) {
      return Text(filled, key: _key, style: const TextStyle(color: Color(0xFF2B8A3E)));
    }
    return Container(
      key: _key,
      constraints: BoxConstraints(minWidth: fs * widget.minWidthEm),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFFC7D3E3), width: fs > 60 ? 6 : 5))),
      child: Text('?', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC7D3E3))),
    );
  }
}

/// Nội dung thẻ thưởng: hình to, chữ to (.big), chữ nhỏ (.small).
class RewardContent extends StatelessWidget {
  const RewardContent({super.key, this.img, this.imgWidget, this.big, this.small, this.bigSize, this.extra = const []});
  final String? img;
  final Widget? imgWidget;
  final String? big;
  final String? small;

  /// Cỡ chữ .big riêng (vd. câu dài: .sent-done).
  final double? bigSize;
  final List<Widget> extra;
  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    return Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
      ?imgWidget,
      if (img != null) EmojiImage(img!, size: vwClamp(context, 140, 22, 220)),
      if (big != null)
        Text(big!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: bigSize ?? vwClamp(context, 44, 7, 80), fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink2)),
      if (small != null) Text(small!, textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
      ...extra,
    ]);
  }
}

/// Builder thẻ thưởng tiện dụng: rewardOf(img: 'Cat', big: 'mèo').
WidgetBuilder rewardOf({String? img, String? big, String? small, double? bigSize}) =>
    (context) => RewardContent(img: img, big: big, small: small, bigSize: bigSize);

// ---------------------------------------------------------------------------------------------------------------

/// Chạy một loạt câu hỏi trong stage; xong gọi onDone(sao). Game thường gọi: onDone: ctx.finish.
class QuizView extends StatefulWidget {
  const QuizView({super.key, required this.ctx, required this.questions, this.options = const QuizOptions(), required this.onDone, this.onProgress});
  final GameContext ctx;
  final List<QuizQuestion> questions;
  final QuizOptions options;
  final void Function(int stars) onDone;

  /// Thay ctx.progress (vd. truyện: câu hỏi đánh số tiếp sau các trang).
  final void Function(int i, int n)? onProgress;

  /// Đáp án câu đang hiện (chỉ để test tự chơi qua bài).
  @visibleForTesting
  static Object? debugAnswer;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int i = 0, mistakes = 0, streak = 0;
  bool busy = false;
  bool talking = false;
  final Set<Object> wrong = {};
  final Map<Object, int> shakes = {};
  final List<Object> picks = [];
  final Map<int, GlobalKey> choiceKeys = {};
  final _QuizFx fx = _QuizFx();
  Object? right;
  Widget Function(BuildContext)? rewardBuilder;
  Completer<void>? skip;
  int? comboN;
  int comboSeq = 0;
  int qSeq = 0;
  late DateTime t0;

  GameContext get g => widget.ctx;
  QuizQuestion get q => widget.questions[i];
  bool get dead => !mounted || g.aborted;

  void _progress(int a, int n) => (widget.onProgress ?? g.progress)(a, n);

  @override
  void initState() {
    super.initState();
    t0 = DateTime.now();
    g.audio.preload(widget.questions.expand((q) => [q.say, q.reward, ...q.preload]));
    if (widget.questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!dead) widget.onDone(3);
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startQuestion(first: true));
  }

  Future<void> _startQuestion({bool first = false}) async {
    if (dead) return;
    _progress(i, widget.questions.length);
    t0 = DateTime.now();
    QuizView.debugAnswer = q.answer;
    // Câu đầu: đọc câu dẫn, nghỉ một nhịp rồi mới đọc đề; bé chạm đáp án giữa chừng thì thôi.
    if (first && widget.options.intro != null) {
      final my = qSeq;
      await g.audio.sayPhrase(widget.options.intro!);
      await wait(350);
      if (dead || busy || my != qSeq) return;
    }
    _speak();
  }

  Future<void> _speak() async {
    if (q.say == null || dead) return;
    final my = qSeq;
    setState(() {
      talking = true;
      fx.saying = true;
    });
    await g.audio.say(q.say);
    if (!mounted || my != qSeq) return;
    setState(() {
      talking = false;
      fx.saying = false;
    });
  }

  Future<void> _fly(QuizChoice c, int k) async {
    final slots = fx.blanks.keys.where((k) => !fx.filled.containsKey(k)).toList()..sort();
    if (slots.isEmpty) return;
    final slot = slots.first;
    final txt = c.text ?? '${c.id}';
    void fill() {
      if (!mounted) return;
      setState(() {
        fx.filled[slot] = txt;
        fx.merge++;
      });
    }

    final from = choiceKeys[k]?.currentContext?.findRenderObject() as RenderBox?;
    final to = fx.blanks[slot]?.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context);
    if (!Motion.of(context) || from == null || to == null || overlay == null || !from.attached || !to.attached) {
      fill();
      return;
    }
    final a = from.localToGlobal(from.size.center(Offset.zero));
    final b = to.localToGlobal(to.size.center(Offset.zero));
    final fs = fx.blankFont[slot] ?? 48;
    final done = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyChip(from: a, to: b, text: txt, fontSize: fs, onDone: () => done.isCompleted ? null : done.complete()),
    );
    overlay.insert(entry);
    await done.future.timeout(const Duration(milliseconds: 800), onTimeout: () {});
    entry.remove();
    fill();
    await wait(200);
  }

  Future<void> _tap(QuizChoice c, [int k = 0]) async {
    if (busy || wrong.contains(c.id) || dead) return;
    setState(() => busy = true);
    if (c.id == q.answer) {
      g.record(QuizRecord(answer: q.answer, say: q.say, reward: q.reward, picks: List.of(picks), ms: DateTime.now().difference(t0).inMilliseconds));
      g.audio.sfx('correct');
      g.cheer();
      g.audio.stopVoice();
      streak = picks.isEmpty ? streak + 1 : 0;
      setState(() {
        right = c.id;
        talking = false;
        fx.saying = false;
      });
      if (widget.options.combo && streak >= 3) _combo(streak);
      if (q.onRight != null) await q.onRight!();
      if (widget.options.fly) await _fly(c, k);
      if (dead) return;
      final r = q.pickReward?.call(missed: picks.isNotEmpty, streak: streak) ?? QuizReward(say: [q.reward], node: q.rewardNode);
      if (r.node != null || r.timedNode != null) {
        double dur = 0;
        if (r.timedNode != null) {
          dur = await g.audio.clipDuration(r.say.whereType<VoiceLine>().firstOrNull);
          if (dead) return;
        }
        final s = skip = Completer<void>();
        setState(() => rewardBuilder = r.timedNode != null ? (ctx) => r.timedNode!(ctx, dur) : r.node);
        await Future.any([
          Future.wait([g.audio.sayAll(r.say), wait(r.minMs ?? widget.options.minRewardMs ?? 1100)]),
          s.future,
        ]);
      } else {
        await Future.wait([g.audio.sayAll(r.say), wait(widget.options.minRewardMs != null ? 400 : 650)]);
      }
      if (dead) return;
      if (i + 1 >= widget.questions.length) {
        _progress(widget.questions.length, widget.questions.length);
        widget.onDone(starsFor(mistakes));
        return;
      }
      setState(() {
        i++;
        qSeq++;
        busy = false;
        right = null;
        rewardBuilder = null;
        skip = null;
        wrong.clear();
        shakes.clear();
        picks.clear();
        choiceKeys.clear();
        fx.reset();
      });
      _startQuestion();
    } else {
      mistakes++;
      picks.add(c.id);
      g.audio.sfx('wrong');
      g.sad();
      setState(() {
        wrong.add(c.id);
        shakes[c.id] = (shakes[c.id] ?? 0) + 1;
      });
      await g.audio.retry();
      if (dead) return;
      setState(() => busy = false);
      _speak();
    }
  }

  void _combo(int n) {
    final big = const [3, 5, 8, 10].contains(n);
    if (big) g.audio.sfx('power');
    final my = ++comboSeq;
    setState(() => comboN = n);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && my == comboSeq) setState(() => comboN = null);
    });
  }

  void _skipReward() {
    g.audio.stopVoice();
    final s = skip;
    if (s != null && !s.isCompleted) s.complete();
  }

  // ---------- Bố cục ----------
  Set<String> get _cls => (q.cls ?? '').split(' ').where((s) => s.isNotEmpty).toSet();

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) return const SizedBox();
    final mq = MediaQuery.sizeOf(context);
    final portrait = mq.height > mq.width;
    final cls = _cls;
    final n = q.choices.length;
    var cols = q.cols ?? n;
    // Màn dọc: 4 lựa chọn xếp 2×2 cho thẻ to, dễ chạm (trừ thẻ vần).
    if (portrait && mq.width <= 900 && n == 4 && !cls.contains('syll')) cols = 2;
    cols = cols.clamp(1, math.max(1, n));
    final words = cls.contains('words');
    final aspect = cls.contains('syll')
        ? (n == 6 ? 1.6 : 1.25)
        : cls.contains('nums')
            ? (portrait && n == 4 && mq.width <= 900 ? 1.5 : 1.2)
            : cls.contains('towers')
                ? .8
                : cls.contains('pencils')
                    ? 3.0
                    : 1.0;
    final gap = vwClamp(context, 12, 2.5, 26);
    final hasPrompt = q.say != null || q.label != null;

    return _QuizScope(
      fx: fx,
      saying: fx.saying,
      merge: fx.merge,
      filledCount: fx.filled.length,
      child: LayoutBuilder(builder: (context, box) {
        final maxW = math.min(box.maxWidth, cls.contains('pencils') ? 700.0 : (portrait && n == 4 && mq.width <= 900 ? 560.0 : 1000.0));
        final H = box.maxHeight.isFinite ? box.maxHeight : mq.height * .7;
        final promptH = !hasPrompt
            ? 0.0
            : switch (q.labelStyle) { 'readword' => 120.0, 'readsent' => 150.0, 'upper' => 110.0, _ => 76.0 };
        final stageH = q.stage == null ? 0.0 : math.max(110.0, H * .3);
        final budget = math.max(80.0, H - promptH - stageH - 40);
        final rows = words ? ((n + 3) ~/ 4) : (n + cols - 1) ~/ cols;
        double cellW = ((maxW - gap * (cols - 1)) / cols - .5).floorToDouble(), cellH = cellW / aspect;
        final maxCellH = (budget - gap * (rows - 1)) / rows;
        if (words) {
          cellH = math.min(vwClamp(context, 84, 9, 96), maxCellH);
        } else if (cellH > maxCellH) {
          cellH = maxCellH.floorToDouble();
          cellW = (cellH * aspect).floorToDouble();
        }
        final cssFont = cls.contains('words')
            ? vwClamp(context, 30, 5, 52)
            : cls.contains('syll')
                ? (mq.width <= 560 ? vwClamp(context, 30, 9, 48) : vwClamp(context, 48, 8, 96))
                : cls.contains('nums')
                    ? vwClamp(context, 56, 9, 110)
                    : (mq.width <= 480 && n == 3 ? vwClamp(context, 54, 15, 80) : vwClamp(context, 64, 11, 132));
        final font = math.min(cssFont, cellH * (cls.contains('syll') ? .55 : .62));

        // Khoảng cách dọc giữa đề, hình và lựa chọn: clamp(14px, 3vh, 30px).
        final vgap = (mq.height * .03).clamp(14.0, 30.0);
        final choiceWidgets = <Widget>[
          for (final (k, ch) in q.choices.indexed) _choice(context, k, ch, words ? null : cellW, cellH, font, words ? maxW * .22 : 0),
        ];
        return Stack(clipBehavior: Clip.none, children: [
          SizedBox(
            width: box.maxWidth,
            height: H,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (hasPrompt && q.stage == null) Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _prompt(context, math.min(box.maxWidth, 900)))),
                  if (hasPrompt && q.stage != null) _prompt(context, math.min(box.maxWidth, 900)),
                  if (q.stage != null)
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(top: vgap),
                        child: FittedBox(fit: BoxFit.scaleDown, child: KeyedSubtree(key: ValueKey('stage-$qSeq'), child: Builder(builder: q.stage!))),
                      ),
                    ),
                ]),
              ),
              SizedBox(height: vgap + 4),
              SizedBox(
                width: maxW,
                child: _unifyPhotos(context, Wrap(
                  key: ValueKey('choices-$qSeq'),
                  alignment: WrapAlignment.center,
                  spacing: gap,
                  runSpacing: gap,
                  children: choiceWidgets,
                )),
              ),
              const SizedBox(height: 10),
            ]),
          ),
          if (comboN != null) Positioned(top: 6, right: 10, child: _ComboBadge(n: comboN!, lang: g.i18n.lang)),
          if (rewardBuilder != null)
            Positioned.fill(
              child: GestureDetector(
                key: const Key('quiz-reward'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _skipReward(),
                child: _RewardOverlay(child: _RewardScope(child: Builder(builder: rewardBuilder!))),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _prompt(BuildContext context, double maxW) {
    final fs = baseFontSize(context);
    final ls = q.labelStyle;
    final labelFont = switch (ls) {
      'upper' => vwClamp(context, 56, 9, 96),
      'readword' => vwClamp(context, 44, 9, 84),
      'readsent' => vwClamp(context, 28, 5, 48),
      _ => fs * 1.15,
    };
    final pad = switch (ls) {
      'upper' => const EdgeInsets.fromLTRB(12, 4, 34, 4),
      'readword' => const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
      'readsent' => const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      _ => EdgeInsets.fromLTRB(q.say != null ? 12 : 26, 10, 26, 10),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW, minHeight: 64),
      child: OneShot(
        key: ValueKey('prompt-$qSeq'),
        duration: const Duration(milliseconds: 350),
        builder: (context, t, child) {
          final k = kEasePop.transform(t);
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 18 * (1 - k)), child: child));
        },
        child: Chunky(
          key: const Key('quiz-prompt'),
          onTap: q.say == null ? null : _speak,
          radius: ls == 'readword' ? 30 : ls == 'readsent' ? 28 : 999,
          padding: pad,
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
            if (q.say != null)
              Pulse(
                on: talking,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x26000000), offset: Offset(0, -4), spreadRadius: -2, blurStyle: BlurStyle.inner)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔊', style: TextStyle(fontSize: 26)),
                ),
              ),
            if (q.label != null)
              Flexible(
                child: Text(
                  q.label!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: labelFont, height: ls == 'readsent' ? 1.25 : 1.1, color: AppColors.ink2),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _choice(BuildContext context, int k, QuizChoice ch, double? w, double h, double font, double minW) {
    final isRight = right == ch.id, isWrong = wrong.contains(ch.id);
    final key = choiceKeys.putIfAbsent(k, () => GlobalKey());
    final dup = q.choices.take(k).any((x) => x.id == ch.id);
    final cell = Size(w ?? h * 1.6, h);
    Widget content = QuizCell(
      size: cell,
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: font, fontWeight: FontWeight.w700, height: 1, color: AppColors.ink2),
        child: Builder(builder: (context) => _fitNode(ch.node(context), cell)),
      ),
    );
    Widget card = Chunky(
      key: key,
      onTap: () => _tap(ch, k),
      radius: mqWidth(context) <= 480 ? 26 : 32,
      depth: 8,
      color: isRight ? const Color(0xFFE7FBE9) : isWrong ? const Color(0xFFFFF5F5) : Colors.white,
      shadowColor: isRight ? const Color(0xFF9FE3B0) : AppColors.line,
      border: Border.all(color: isRight ? const Color(0xFF6EE79A) : isWrong ? const Color(0xFFFFC9C9) : const Color(0xFFEEF3FA), width: 3),
      semanticLabel: ch.text ?? (ch.id is String || ch.id is num ? '${ch.id}' : null),
      child: w == null
          ? ConstrainedBox(
              constraints: BoxConstraints(minWidth: math.max(0, minW - 6), minHeight: h - 6),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Center(widthFactor: 1, child: content)),
            )
          : SizedBox(width: w - 6, height: h - 6, child: Center(child: content)),
    );
    card = Stack(clipBehavior: Clip.none, children: [
      card,
      if (isRight)
        Positioned(
          top: -12,
          right: -12,
          child: PopOnce(
            trigger: 1,
            playOnStart: true,
            ms: 350,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.good, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.goodDark, offset: Offset(0, 3))]),
              alignment: Alignment.center,
              child: const Text('✓', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1)),
            ),
          ),
        ),
    ]);
    return KeyedSubtree(
      key: ValueKey(dup ? 'choice-${ch.id}-$k' : 'choice-${ch.id}'),
      child: CardIn(
        key: ValueKey('in-$qSeq-$k'),
        index: k,
        child: ShakeOnce(
          trigger: shakes[ch.id] ?? 0,
          child: PopOnce(
            trigger: isRight,
            child: AnimatedOpacity(opacity: isWrong ? .35 : 1, duration: const Duration(milliseconds: 200), child: card),
          ),
        ),
      ),
    );
  }

  /// Một nhóm hình lựa chọn phải cùng kiểu (unifyPhotos của web): có hình chưa có ảnh chụp thì cả nhóm dùng hoạt hình,
  /// để không lộ đáp án và không lẫn ảnh với hoạt hình.
  Widget _unifyPhotos(BuildContext context, Widget child) {
    final names = <String>[];
    for (final c in q.choices) {
      final w = c.node(context);
      if (w is QuizImg && w.photo) names.add(w.name);
      if (w is EmojiImage && w.photo) names.add(w.name);
    }
    if (names.length < 2) return child;
    Map<String, PhotoInfo> photos;
    try {
      photos = ProviderScope.containerOf(context, listen: false).read(contentBundleProvider).photos;
    } catch (_) {
      return child;
    }
    final some = names.any(photos.containsKey);
    if (!some || groupUsesPhotos(photos, names)) return child;
    return PhotoScope(enabled: false, child: child);
  }

  /// Co nội dung thẻ cho vừa: hình emoji không cỡ → 80% thẻ; còn lại thu nhỏ nếu tràn.
  Widget _fitNode(Widget node, Size cell) {
    final box = Size(cell.width * .88, cell.height * .86);
    if (node is EmojiImage && node.size == null && node.width == null && node.height == null) {
      return SizedBox.square(dimension: cell.shortestSide * .8, child: FittedBox(fit: BoxFit.contain, child: node));
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: box.width, maxHeight: box.height),
      child: FittedBox(fit: BoxFit.scaleDown, child: node),
    );
  }
}

double mqWidth(BuildContext context) => MediaQuery.sizeOf(context).width;

/// Huy hiệu "🔥 n liền!" góc trên phải (đợt 15 web).
class _ComboBadge extends StatelessWidget {
  const _ComboBadge({required this.n, required this.lang});
  final int n;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final big = const [3, 5, 8, 10].contains(n);
    final fs = baseFontSize(context) * (big ? 1.7 : 1.3);
    return IgnorePointer(
      child: OneShot(
        key: ValueKey('combo-$n'),
        duration: const Duration(milliseconds: 400),
        builder: (context, t, child) {
          final k = kEasePop.transform(t);
          return Opacity(
            opacity: t,
            child: Transform.rotate(angle: -12 * (1 - k) * math.pi / 180, child: Transform.scale(scale: .3 + .7 * k, child: child)),
          );
        },
        child: Container(
          key: const Key('quiz-combo'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: big ? const Color(0xFFFFE066) : const Color(0xFFFFF3BF),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0xFFFFD43B), offset: Offset(0, 4))],
          ),
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: '🔥 '),
              TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.w900)),
              TextSpan(text: lang == 'en' ? ' in a row!' : ' liền!'),
            ]),
            style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, color: const Color(0xFFE8590C)),
          ),
        ),
      ),
    );
  }
}

/// Lớp thẻ thưởng (.reward): nền xanh nhạt mờ, vòng tia sáng xoay, thẻ trắng viền vàng bật ra.
class _RewardOverlay extends StatelessWidget {
  const _RewardOverlay({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final ray = math.min(mq.width * .8, 520.0);
    return OneShot(
      duration: const Duration(milliseconds: 200),
      builder: (context, t, c) => Opacity(opacity: t, child: c),
      child: ColoredBox(
        color: const Color(0xB8E6F7FF),
        child: Stack(alignment: Alignment.center, children: [
          IgnorePointer(
            child: LoopAnim(
              period: const Duration(seconds: 14),
              builder: (context, t, _) => Transform.rotate(angle: t * 2 * math.pi, child: CustomPaint(size: Size.square(ray), painter: _RaysPainter())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RewardIn(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: mq.width <= 480 ? 16 : 40, vertical: mq.width <= 480 ? 18 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFFFF3BF), width: 4),
                    boxShadow: kCardShadow,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontSize: vwClamp(context, 44, 7, 80), fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink2),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x73FFE066), Color(0x73FFE066), Color(0x00FFE066)],
        stops: const [0, .45, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const step = 24 * math.pi / 180, wedge = 12 * math.pi / 180;
    for (var a = 0.0; a < 2 * math.pi - 1e-6; a += step) {
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: r), a - math.pi / 2, wedge, false)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => false;
}

/// Chữ bay từ thẻ lựa chọn vào ô trống (.fly-chip, 340ms, cubic-bezier(.45, 0, .3, 1.25)).
class _FlyChip extends StatefulWidget {
  const _FlyChip({required this.from, required this.to, required this.text, required this.fontSize, required this.onDone});
  final Offset from, to;
  final String text;
  final double fontSize;
  final VoidCallback onDone;
  @override
  State<_FlyChip> createState() => _FlyChipState();
}

class _FlyChipState extends State<_FlyChip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))
    ..forward().whenComplete(widget.onDone);
  static const _curve = Cubic(.45, 0, .3, 1.25);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final k = _curve.transform(_c.value);
          final p = Offset.lerp(widget.from, widget.to, k)!;
          return Stack(children: [
            Positioned(
              left: p.dx,
              top: p.dy,
              child: FractionalTranslation(translation: const Offset(-.5, -.5), child: Transform.scale(scale: 1.15 - .15 * k, child: child)),
            ),
          ]);
        },
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE7FBE9),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Text(widget.text, style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w800, height: 1, color: const Color(0xFF2B8A3E))),
          ),
        ),
      ),
    );
  }
}
