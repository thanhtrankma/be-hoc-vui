// Hiệu ứng một lần dùng chung cho các trò của agent A (port các @keyframes trong app.css: pop, shake, cardIn,
// rewardIn, mergePop, talk, sayBob, beacon). Tôn trọng Motion.enabled (test tắt → hiện ngay trạng thái cuối).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/ui/motion.dart';

/// Đường cong --ease-pop của web: cubic-bezier(.34, 1.56, .64, 1).
const Curve kEasePop = Cubic(.34, 1.56, .64, 1);

/// Chạy builder(t) với t: 0→1 một lần khi `trigger` đổi (và lúc tạo nếu playOnStart). Motion tắt → t = 1 ngay.
class OneShot extends StatefulWidget {
  const OneShot({
    super.key,
    required this.duration,
    required this.builder,
    this.trigger,
    this.delay = Duration.zero,
    this.playOnStart = true,
    this.child,
  });
  final Duration duration;
  final Duration delay;
  final Object? trigger;
  final bool playOnStart;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  State<OneShot> createState() => _OneShotState();
}

class _OneShotState extends State<OneShot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration, value: 1);

  @override
  void initState() {
    super.initState();
    if (widget.playOnStart) _play();
  }

  @override
  void didUpdateWidget(OneShot old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _play();
  }

  void _play() {
    if (!Motion.enabled) {
      _c.value = 1;
      return;
    }
    _c.value = 0;
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, child: widget.child, builder: (context, child) => widget.builder(context, _c.value, child));
}

/// @keyframes pop { 50% { scale(1.1) } } — chạy khi trigger đổi.
class PopOnce extends StatelessWidget {
  const PopOnce({super.key, required this.trigger, required this.child, this.scale = 1.1, this.ms = 400, this.playOnStart = false});
  final Object? trigger;
  final Widget child;
  final double scale;
  final int ms;
  final bool playOnStart;
  @override
  Widget build(BuildContext context) => OneShot(
        duration: Duration(milliseconds: ms),
        trigger: trigger,
        playOnStart: playOnStart,
        child: child,
        builder: (context, t, child) => Transform.scale(scale: 1 + (scale - 1) * math.sin(t * math.pi), child: child),
      );
}

/// @keyframes shake: lắc ngang ±12px (450ms) — chạy khi trigger đổi.
class ShakeOnce extends StatelessWidget {
  const ShakeOnce({super.key, required this.trigger, required this.child, this.amp = 12});
  final Object? trigger;
  final Widget child;
  final double amp;
  @override
  Widget build(BuildContext context) => OneShot(
        duration: const Duration(milliseconds: 450),
        trigger: trigger,
        playOnStart: false,
        child: child,
        builder: (context, t, child) => Transform.translate(offset: Offset(amp * math.sin(t * math.pi * 4) * (t < 1 ? 1 : 0), 0), child: child),
      );
}

/// @keyframes cardIn: từ dưới 26px, nhỏ .9, mờ → rõ (380ms, ease-pop), trễ theo thứ tự.
class CardIn extends StatelessWidget {
  const CardIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => OneShot(
        duration: const Duration(milliseconds: 380),
        delay: Duration(milliseconds: 50 * index.clamp(0, 4)),
        child: child,
        builder: (context, t, child) {
          final k = kEasePop.transform(t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, 26 * (1 - k)), child: Transform.scale(scale: .9 + .1 * k, child: child)),
          );
        },
      );
}

/// @keyframes rewardIn: scale(.4) rotate(-6°) mờ → bình thường (450ms ease-pop).
class RewardIn extends StatelessWidget {
  const RewardIn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => OneShot(
        duration: const Duration(milliseconds: 450),
        child: child,
        builder: (context, t, child) {
          final k = kEasePop.transform(t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.rotate(angle: -6 * (1 - k) * math.pi / 180, child: Transform.scale(scale: .4 + .6 * k, child: child)),
          );
        },
      );
}

/// Nhịp phập phồng lặp khi `on` (talk/sayBob/beacon). Motion tắt → đứng yên.
class Pulse extends StatelessWidget {
  const Pulse({super.key, required this.on, required this.child, this.scale = 1.12, this.dy = 0, this.ms = 500});
  final bool on;
  final Widget child;
  final double scale;
  final double dy;
  final int ms;
  @override
  Widget build(BuildContext context) {
    if (!on || !Motion.of(context)) return child;
    // LoopAnim.transform: phập phồng ở tầng vẽ, không dựng lại widget mỗi khung (= translate(scale quanh tâm)).
    return LoopAnim.transform(
      period: Duration(milliseconds: ms * 2),
      alignment: Alignment.center,
      transform: (t) {
        final k = .5 - .5 * math.cos(t * 2 * math.pi);
        final s = 1 + (scale - 1) * k;
        return Matrix4.translationValues(0, dy * k, 0)..multiply(Matrix4.diagonal3Values(s, s, 1));
      },
      child: child,
    );
  }
}
