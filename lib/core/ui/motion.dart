// Bật/tắt hoạt ảnh lặp vô hạn (mây trôi, hình nhún, nút nhấp nháy).
// Test widget đặt Motion.enabled = false để pumpAndSettle() không chờ mãi. Máy bật "Giảm chuyển động" cũng tắt.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class Motion {
  Motion._();

  /// Tắt toàn cục (test).
  static bool enabled = true;

  /// Có nên chạy hoạt ảnh lặp ở chỗ này không.
  static bool of(BuildContext context) => enabled && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// Hoạt ảnh lặp đơn giản: builder nhận t ∈ [0,1) chạy vòng theo period. Motion tắt → t = 0 cố định.
class LoopAnim extends StatefulWidget {
  const LoopAnim({super.key, required this.period, required this.builder, this.delay = Duration.zero, this.child});
  final Duration period;

  /// Lệch pha (như animation-delay âm của CSS).
  final Duration delay;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  State<LoopAnim> createState() => _LoopAnimState();
}

class _LoopAnimState extends State<LoopAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = Motion.of(context);
    if (on && !_running) {
      _running = true;
      final off = widget.period.inMicroseconds == 0 ? 0.0 : (widget.delay.inMicroseconds / widget.period.inMicroseconds) % 1.0;
      _c.value = off;
      _c.repeat();
    } else if (!on && _running) {
      _running = false;
      _c.stop();
      _c.value = 0;
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

/// Nhún lên xuống (keyframes bob của web: 0→-8px→0 trong 3 giây).
class Bob extends StatelessWidget {
  const Bob({super.key, required this.child, this.amplitude = 8, this.period = const Duration(seconds: 3), this.delay = Duration.zero});
  final Widget child;
  final double amplitude;
  final Duration period;
  final Duration delay;
  @override
  Widget build(BuildContext context) => LoopAnim(
        period: period,
        delay: delay,
        child: child,
        builder: (context, t, child) {
          // ease-in-out: 0 → -amp (50%) → 0
          final k = (1 - math.cos(t * 2 * math.pi)) / 2;
          return Transform.translate(offset: Offset(0, -amplitude * k), child: child);
        },
      );
}

/// Nhảy (keyframes hop: 40% -18px xoay -4°, 60% -10px xoay 3°), dùng ở màn Bắt đầu và phần thưởng.
class Hop extends StatelessWidget {
  const Hop({super.key, required this.child, this.period = const Duration(milliseconds: 1600), this.delay = Duration.zero, this.height = 18});
  final Widget child;
  final Duration period;
  final Duration delay;
  final double height;
  @override
  Widget build(BuildContext context) => LoopAnim(
        period: period,
        delay: delay,
        child: child,
        builder: (context, t, child) {
          double y, r;
          if (t < .4) {
            final k = _ease(t / .4);
            y = -height * k;
            r = -4 * k;
          } else if (t < .6) {
            final k = _ease((t - .4) / .2);
            y = -height + (height - height * 10 / 18) * k;
            r = -4 + 7 * k;
          } else {
            final k = _ease((t - .6) / .4);
            y = -height * 10 / 18 * (1 - k);
            r = 3 * (1 - k);
          }
          return Transform.translate(offset: Offset(0, y), child: Transform.rotate(angle: r * math.pi / 180, child: child));
        },
      );
}

double _ease(double x) => x < .5 ? 2 * x * x : 1 - (-2 * x + 2) * (-2 * x + 2) / 2;

/// Phần tử xuất hiện lần lượt (keyframes rise: từ dưới 18px, nhỏ .94, mờ → rõ), trễ theo thứ tự index.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (!Motion.enabled) {
      _c.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 30 * (widget.index.clamp(0, 8)));
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final k = const Cubic(.34, 1.56, .64, 1).transform(_c.value);
        final o = _c.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: o,
          child: Transform.translate(offset: Offset(0, 18 * (1 - k)), child: Transform.scale(scale: .94 + .06 * k, child: child)),
        );
      },
    );
  }
}
