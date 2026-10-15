// Khuôn "nghe rồi chọn" (port games/quiz.js): dùng cho chữ cái, tiếng Anh, đếm số, toán, đời sống, tư duy, ôn tập...
// CHỦ: agent A. Foundation viết sẵn API + bản chạy được tối thiểu để agent B/C/E dùng ngay khi làm song song.
// Agent A: hoàn thiện giao diện/hiệu ứng (combo, thẻ thưởng, onRight, pickReward, anim...) nhưng GIỮ NGUYÊN chữ ký công khai:
//   starsFor, QuizChoice, QuizReward, QuizQuestion, QuizOptions, QuizView, kRound.
import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

export 'package:be_vui_hoc/core/ui/utils.dart' show sequence, shuffle, sample;

/// 0 lỗi = 3 sao, ≤ 2 lỗi = 2 sao, còn lại 1 sao.
int starsFor(int mistakes) => mistakes == 0 ? 3 : mistakes <= 2 ? 2 : 1;

/// Một lựa chọn: id so với answer; node vẽ nội dung thẻ.
class QuizChoice {
  const QuizChoice({required this.id, required this.node});
  final Object id;
  final WidgetBuilder node;
}

/// Thẻ thưởng sau khi đúng (pickReward của web).
class QuizReward {
  const QuizReward({this.say = const [], this.node, this.minMs});
  final List<VoiceLine?> say;
  final WidgetBuilder? node;
  final int? minMs;
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

  /// Kiểu lưới lựa chọn (cls của web: 'syll', 'nums', 'words'...).
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
  const QuizOptions({this.intro, this.minRewardMs, this.combo = false});

  /// Khoá câu dẫn (voice.json) đọc trước câu đầu.
  final String? intro;
  final int? minRewardMs;

  /// Đếm chuỗi đúng liên tiếp (🔥 3 liền!).
  final bool combo;
}

/// Chạy một loạt câu hỏi trong stage; xong gọi onDone(sao). Game thường gọi: onDone: ctx.finish.
class QuizView extends StatefulWidget {
  const QuizView({super.key, required this.ctx, required this.questions, this.options = const QuizOptions(), required this.onDone});
  final GameContext ctx;
  final List<QuizQuestion> questions;
  final QuizOptions options;
  final void Function(int stars) onDone;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int i = 0, mistakes = 0, streak = 0;
  bool busy = false;
  final Set<Object> wrong = {};
  final List<Object> picks = [];
  Object? right;
  WidgetBuilder? rewardNode;
  late DateTime t0;

  GameContext get g => widget.ctx;
  QuizQuestion get q => widget.questions[i];

  @override
  void initState() {
    super.initState();
    g.audio.preload(widget.questions.expand((q) => [q.say, q.reward, ...q.preload]));
    WidgetsBinding.instance.addPostFrameCallback((_) => _startQuestion(first: true));
  }

  Future<void> _startQuestion({bool first = false}) async {
    if (!mounted || g.aborted) return;
    g.progress(i, widget.questions.length);
    t0 = DateTime.now();
    if (first && widget.options.intro != null) {
      await g.audio.sayPhrase(widget.options.intro!);
      await wait(350);
      if (!mounted || busy || g.aborted) return;
    }
    g.audio.say(q.say);
  }

  Future<void> _tap(QuizChoice c) async {
    if (busy || wrong.contains(c.id)) return;
    setState(() => busy = true);
    if (c.id == q.answer) {
      g.record(QuizRecord(answer: q.answer, say: q.say, reward: q.reward, picks: List.of(picks), ms: DateTime.now().difference(t0).inMilliseconds));
      g.audio.sfx('correct');
      g.cheer();
      g.audio.stopVoice();
      streak = picks.isEmpty ? streak + 1 : 0;
      setState(() => right = c.id);
      if (q.onRight != null) await q.onRight!();
      final r = q.pickReward?.call(missed: picks.isNotEmpty, streak: streak) ?? QuizReward(say: [q.reward], node: q.rewardNode);
      if (r.node != null) setState(() => rewardNode = r.node);
      await Future.wait([g.audio.sayAll(r.say), wait(r.minMs ?? widget.options.minRewardMs ?? (r.node != null ? 1100 : 650))]);
      if (!mounted || g.aborted) return;
      if (i + 1 >= widget.questions.length) {
        g.progress(widget.questions.length, widget.questions.length);
        widget.onDone(starsFor(mistakes));
        return;
      }
      setState(() {
        i++;
        busy = false;
        right = null;
        rewardNode = null;
        wrong.clear();
        picks.clear();
      });
      _startQuestion();
    } else {
      mistakes++;
      picks.add(c.id);
      g.audio.sfx('wrong');
      g.sad();
      setState(() => wrong.add(c.id));
      await g.audio.retry();
      if (!mounted || g.aborted) return;
      setState(() => busy = false);
      g.audio.say(q.say);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    final n = q.cols ?? q.choices.length;
    return Stack(children: [
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (q.say != null || q.label != null)
          Chunky(
            onTap: () => g.audio.say(q.say),
            radius: 999,
            padding: const EdgeInsets.fromLTRB(12, 10, 26, 10),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
              if (q.say != null)
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Text('🔊', style: TextStyle(fontSize: 26)),
                ),
              if (q.label != null) Flexible(child: Text(q.label!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.15))),
            ]),
          ),
        if (q.stage != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: q.stage!(context)),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          const gap = 16.0;
          final w = ((c.maxWidth.clamp(0, 900)) - gap * (n - 1)) / n;
          return Wrap(alignment: WrapAlignment.center, spacing: gap, runSpacing: gap, children: [
            for (final ch in q.choices)
              SizedBox(
                key: ValueKey('choice-${ch.id}'),
                width: w,
                height: w,
                child: Opacity(
                  opacity: wrong.contains(ch.id) ? .35 : 1,
                  child: Chunky(
                    onTap: () => _tap(ch),
                    radius: 32,
                    depth: 8,
                    color: right == ch.id ? const Color(0xFFE7FBE9) : Colors.white,
                    shadowColor: right == ch.id ? const Color(0xFF9FE3B0) : AppColors.line,
                    child: Center(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(fontSize: w * .55, fontWeight: FontWeight.w700, height: 1, color: AppColors.ink),
                        child: FractionallySizedBox(widthFactor: .72, heightFactor: .72, child: FittedBox(child: ch.node(context))),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ]),
      if (rewardNode != null)
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (_) => g.audio.stopVoice(),
            child: ColoredBox(
              color: const Color(0xB8E6F7FF),
              child: Center(
                child: CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontSize: fs * 3, fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink),
                    child: rewardNode!(context),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
