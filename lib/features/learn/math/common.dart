// Tiện ích chung cho các đảo của agent B (Số đếm, Toán, Đời sống, Trí nhớ, Khám phá, Âm nhạc).
// Chỉ dùng trong thư mục learn/math.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

/// Bộ câu hỏi quiz gần nhất mà game của agent B dựng (test đọc để biết đáp án).
@visibleForTesting
List<QuizQuestion>? debugMathQuiz;

/// Ghi lại bộ câu hỏi cho test, trả về chính nó.
List<QuizQuestion> keepQuiz(List<QuizQuestion> qs) => debugMathQuiz = qs;

/// Chữ giao diện riêng của các đảo này (core i18n chưa có khoá). Thiếu khoá → core i18n t().
const Map<String, Map<String, String>> _strings = {
  'vi': {
    'hour': '{n} giờ',
    'tensOnes': '{t} chục {o} đơn vị',
    'tensOnly': '{t} chục',
    'month': 'Tháng {m} / {y}',
    'cm': '{n} cm',
  },
  'en': {
    'hour': "{n} o'clock",
    'tensOnes': '{t} tens {o} ones',
    'tensOnly': '{t} tens',
    'month': 'Month {m} / {y}',
    'cm': '{n} cm',
  },
};

/// Chữ giao diện theo ngôn ngữ của bé.
String mt(GameContext g, String key, [Map<String, Object?>? vars]) {
  final s = _strings[g.i18n.lang]?[key] ?? _strings['vi']![key];
  if (s == null) return g.i18n.t(key, vars);
  return s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${vars?[m[1]] ?? ''}');
}

/// Gộp nhiều object như {...a, ...b} của JS.
Json merge(List<Json> parts) => {for (final p in parts) ...p};

/// Số ngẫu nhiên [0, n).
int rnd(int n) => rng.nextInt(n);

/// Lựa chọn quiz; bọc khoá `mc-<id>` để test chạm đúng thẻ.
QuizChoice mChoice(Object id, WidgetBuilder node) =>
    QuizChoice(id: id, node: (c) => ColoredBox(key: ValueKey('mc-$id'), color: const Color(0x00000000), child: node(c)));

List<QuizChoice> numChoices(Iterable<int> list) => [for (final k in list) mChoice(k, (_) => Text('$k'))];

/// Đáp án nhiễu gần đáp án đúng, trong khoảng [lo, hi] (near() của math.js).
List<int> near(int ans, int n, int lo, int hi) {
  final c = <int>{ans};
  for (var d = 1; c.length < n && d <= hi - lo; d++) {
    for (final k in shuffle([ans - d, ans + d])) {
      if (k >= lo && k <= hi && c.length < n) c.add(k);
    }
  }
  return shuffle(c);
}

/// Đáp án nhiễu cho số hai chữ số: cùng chục khác đơn vị, cùng đơn vị khác chục (near100 của math.js).
List<int> near100(int n, [int count = 4]) {
  final c = <int>{n};
  final t = n ~/ 10, o = n % 10;
  final pool = shuffle([n + 1, n - 1, n + 10, n - 10, t * 10 + (o + 2) % 10, ((t + 1) % 10) * 10 + o, o * 10 + t].where((k) => k > 0 && k < 100 && k != n));
  for (final k in pool) {
    if (c.length < count) c.add(k);
  }
  return shuffle(c);
}

/// Giới hạn phần minh hoạ trong quiz (stage không bị giới hạn chiều cao): co lại cho vừa màn hình.
class StageFit extends StatelessWidget {
  const StageFit({super.key, required this.child, this.heightFrac = .4, this.maxHeight = 560});
  final Widget child;
  final double heightFrac;
  final double maxHeight;
  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(100, s.width - 24), maxHeight: (s.height * heightFrac).clamp(110, maxHeight)),
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

/// Nút đề có loa (prompt-btn của web) cho các màn tự dựng (không qua QuizView).
class PromptButton extends StatelessWidget {
  const PromptButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    return Chunky(
      onTap: onTap,
      radius: 999,
      padding: const EdgeInsets.fromLTRB(12, 8, 26, 8),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('🔊', style: TextStyle(fontSize: 24)),
        ),
        Flexible(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.15, color: AppColors.ink))),
      ]),
    );
  }
}

/// Lắc ngang khi trigger đổi (keyframes shake của web).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = _c.value;
          final dx = _c.isAnimating ? -12 * math.sin(t * 4 * math.pi) : 0.0;
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// Phình nhẹ một lần khi trigger đổi (keyframes pop/hit).
class Bump extends StatefulWidget {
  const Bump({super.key, required this.trigger, required this.child, this.scale = 1.1, this.ms = 300});
  final int trigger;
  final Widget child;
  final double scale;
  final int ms;
  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.ms));
  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final k = math.sin(_c.value * math.pi);
          return Transform.scale(scale: 1 + (widget.scale - 1) * k, child: child);
        },
      );
}

/// Hiện ra bằng cách phình từ nhỏ (animation pop khi phần tử mới xuất hiện).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.ms = 300});
  final Widget child;
  final int ms;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: .5, end: 1),
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutBack,
        child: child,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
      );
}

/// Ô phép tính (.eq): nền trắng, chữ to.
class EqBox extends StatelessWidget {
  const EqBox(this.spans, {super.key, this.fontSize});
  final List<InlineSpan> spans;
  final double? fontSize;
  static EqBox text(String s) => EqBox([TextSpan(text: s)]);
  @override
  Widget build(BuildContext context) {
    final fs = fontSize ?? vwClamp(context, 44, 7.5, 84);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: solidShadow(AppColors.line)),
      child: Text.rich(TextSpan(children: spans), style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1.15, color: AppColors.ink)),
    );
  }
}

/// Ô trống "?" gạch chân nét đứt (.blank).
const TextSpan blankSpan = TextSpan(
  text: ' ? ',
  style: TextStyle(color: Color(0xFFC7D3E3), decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed, decorationColor: Color(0xFFC7D3E3), decorationThickness: 3),
);

/// Chữ to / nhỏ trên thẻ thưởng (.reward .big / .small).
class BigText extends StatelessWidget {
  const BigText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: vwClamp(context, 44, 7, 80), fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink));
}

class SmallText extends StatelessWidget {
  const SmallText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center, style: TextStyle(fontSize: baseFontSize(context) * 1.4, fontWeight: FontWeight.w700, color: AppColors.inkSoft, height: 1.2));
}

/// Cột nội dung thẻ thưởng: hình + chữ, co theo màn hình.
Widget rewardColumn(BuildContext context, List<Widget> kids) {
  final s = MediaQuery.sizeOf(context);
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: s.width * .8, maxHeight: s.height * .6),
    child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: kids)),
  );
}

/// Cạnh hình thưởng (.reward img).
double rewardImg(BuildContext context) => vwClamp(context, 140, 22, 220);
