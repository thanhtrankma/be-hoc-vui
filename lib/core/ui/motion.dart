// Bật/tắt hoạt ảnh lặp vô hạn (mây trôi, hình nhún, nút nhấp nháy).
// Test widget đặt Motion.enabled = false để pumpAndSettle() không chờ mãi. Máy bật "Giảm chuyển động" cũng tắt.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
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
  const LoopAnim({super.key, required this.period, required Widget Function(BuildContext context, double t, Widget? child) this.builder, this.delay = Duration.zero, this.child})
      : transform = null,
        alignment = null;

  /// Hoạt ảnh chỉ dời/xoay/phóng [child] (nhún, nhảy, phập phồng, mây trôi): ma trận [transform](t) áp thẳng ở tầng
  /// vẽ, KHÔNG dựng lại widget mỗi khung. Quan trọng khi nằm trong LayoutBuilder: dựng lại ở đó bắt LayoutBuilder
  /// (và cả màn phía trên) layout + vẽ lại mỗi khung. [alignment] như Transform.scale/rotate (null = như Transform.translate).
  const LoopAnim.transform({super.key, required this.period, required Matrix4 Function(double t) this.transform, this.alignment, this.delay = Duration.zero, this.child})
      : builder = null;
  final Duration period;

  /// Lệch pha (như animation-delay âm của CSS).
  final Duration delay;
  final Widget Function(BuildContext context, double t, Widget? child)? builder;
  final Matrix4 Function(double t)? transform;
  final Alignment? alignment;
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
  Widget build(BuildContext context) {
    // Hiệu năng: hoạt ảnh lặp vô hạn chỉ được vẽ lại phần của nó (RepaintBoundary ngoài), và phần con tĩnh
    // (child) chỉ bị dời/xoay chứ không phải ghi lại mỗi khung hình (RepaintBoundary trong). Không đổi hình.
    final child = widget.child;
    final tf = widget.transform;
    if (tf != null) {
      return RepaintBoundary(
        child: _LoopTransform(animation: _c, transform: tf, alignment: widget.alignment, child: child == null ? null : RepaintBoundary(child: child)),
      );
    }
    final builder = widget.builder!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: child == null ? null : RepaintBoundary(child: child),
        builder: (context, child) => builder(context, _c.value, child),
      ),
    );
  }
}

/// Transform theo hoạt ảnh ở tầng RenderObject (như FadeTransition với độ mờ): chỉ vẽ lại, không dựng/layout lại.
class _LoopTransform extends SingleChildRenderObjectWidget {
  const _LoopTransform({required this.animation, required this.transform, this.alignment, super.child});
  final Animation<double> animation;
  final Matrix4 Function(double t) transform;
  final Alignment? alignment;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLoopTransform(animation, transform, alignment);

  @override
  void updateRenderObject(BuildContext context, _RenderLoopTransform renderObject) {
    renderObject
      ..fn = transform
      ..alignment = alignment
      ..animation = animation;
  }
}

class _RenderLoopTransform extends RenderTransform {
  _RenderLoopTransform(this._animation, this._fn, Alignment? alignment) : super(transform: _fn(_animation.value), alignment: alignment);
  Animation<double> _animation;
  Matrix4 Function(double t) _fn;
  set fn(Matrix4 Function(double t) f) {
    _fn = f;
    _tick();
  }

  set animation(Animation<double> a) {
    if (a == _animation) return;
    if (attached) _animation.removeListener(_tick);
    _animation = a;
    if (attached) a.addListener(_tick);
    _tick();
  }

  // RenderTransform.transform= chỉ markNeedsPaint (không layout).
  void _tick() => transform = _fn(_animation.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_tick);
    _tick();
  }

  @override
  void detach() {
    _animation.removeListener(_tick);
    super.detach();
  }
}

/// Nhún lên xuống (keyframes bob của web: 0→-8px→0 trong 3 giây).
class Bob extends StatelessWidget {
  const Bob({super.key, required this.child, this.amplitude = 8, this.period = const Duration(seconds: 3), this.delay = Duration.zero});
  final Widget child;
  final double amplitude;
  final Duration period;
  final Duration delay;
  @override
  Widget build(BuildContext context) => LoopAnim.transform(
        period: period,
        delay: delay,
        transform: (t) {
          // ease-in-out: 0 → -amp (50%) → 0
          final k = (1 - math.cos(t * 2 * math.pi)) / 2;
          return Matrix4.translationValues(0, -amplitude * k, 0);
        },
        child: child,
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
  Widget build(BuildContext context) => LoopAnim.transform(
        period: period,
        delay: delay,
        alignment: Alignment.center,
        transform: (t) {
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
          // = Transform.translate(Transform.rotate(child)) (dời không phụ thuộc tâm nên gộp được một ma trận quanh tâm).
          return Matrix4.translationValues(0, y, 0)..multiply(Matrix4.rotationZ(r * math.pi / 180));
        },
        child: child,
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
