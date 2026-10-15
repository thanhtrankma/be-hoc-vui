// Nền trời của web (body gradient + .sky: 3 đám mây trôi + 2 quả đồi xanh nhạt dưới đáy).
// Mọi màn đã nằm trên nền này (AppShell bọc ngoài router), màn riêng không cần tự vẽ.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'motion.dart';
import 'theme.dart';

class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.skyTop, AppColors.skyBottom, Color(0xFFFFF7E0)],
              stops: [0, .7, 1],
            ),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _HillsPainter())),
        // Mây trôi: lớp riêng (không bắt nền + màn phía trên vẽ lại), dừng hẳn khi màn game che kín nền (SkyCover).
        RepaintBoundary(
          child: ValueListenableBuilder<bool>(
            valueListenable: SkyCover.covered,
            builder: (context, covered, child) => TickerMode(enabled: !covered, child: child!),
            child: LayoutBuilder(builder: (context, c) {
              return Stack(children: [
                _Cloud(top: c.maxHeight * .08, scale: 1, opacity: .85, period: const Duration(seconds: 60), delay: Duration.zero, width: c.maxWidth),
                _Cloud(top: c.maxHeight * .26, scale: .7, opacity: .85, period: const Duration(seconds: 85), delay: const Duration(seconds: 30), width: c.maxWidth),
                _Cloud(top: c.maxHeight * .55, scale: .55, opacity: .6, period: const Duration(seconds: 110), delay: const Duration(seconds: 70), width: c.maxWidth),
              ]);
            }),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Bọc một màn che kín nền trời (game toàn màn hình, nền đục): khi còn màn như vậy, mây ngừng chạy
/// (không tốn CPU/GPU cho thứ không nhìn thấy). Hình không đổi vì mây bị che.
class SkyCover extends StatefulWidget {
  const SkyCover({super.key, required this.child});
  final Widget child;

  /// Đang có màn che kín nền (mây dừng). Cập nhật sau khung hình (không báo giữa lúc dựng cây widget).
  static final ValueNotifier<bool> covered = ValueNotifier<bool>(false);
  static int _n = 0;
  static void _sync() {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => covered.value = _n > 0)
      ..ensureVisualUpdate();
  }

  @override
  State<SkyCover> createState() => _SkyCoverState();
}

class _SkyCoverState extends State<SkyCover> {
  @override
  void initState() {
    super.initState();
    SkyCover._n++;
    SkyCover._sync();
  }

  @override
  void dispose() {
    SkyCover._n--;
    SkyCover._sync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Đồi: nửa elip phía trên (border-radius 50% 50% 0 0), chìm 8vh dưới đáy.
class _HillsPainter extends CustomPainter {
  const _HillsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void hill(double left, double width, double height, Color c, double op) {
      final bottom = h + h * .08;
      final top = bottom - height;
      final r = Rect.fromLTWH(left, top, width, height);
      final corner = Radius.elliptical(width / 2, height / 2);
      canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: corner, topRight: corner), Paint()..color = c.withValues(alpha: op));
    }

    hill(-.20 * w, .85 * w, .24 * h, AppColors.hill1, .75);
    hill(w + .25 * w - .90 * w, .90 * w, .20 * h, AppColors.hill2, .7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.top, required this.scale, required this.opacity, required this.period, required this.delay, required this.width});
  final double top, scale, opacity, width;
  final Duration period, delay;

  @override
  Widget build(BuildContext context) {
    // translateX từ -200px tới 100vw + 200px (web: left -200px, drift tới calc(100vw + 400px)).
    final motion = Motion.of(context);
    return Positioned(
      top: top,
      left: 0,
      child: LoopAnim.transform(
        period: period,
        delay: delay,
        transform: (t) {
          // Tắt hoạt ảnh: đặt mây ở vị trí cố định cho đẹp.
          final k = motion ? t : (scale == 1 ? .18 : scale == .7 ? .62 : .35);
          final x = -200 + k * (width + 400);
          return Matrix4.translationValues(x, 0, 0);
        },
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: const CustomPaint(size: Size(180, 96), painter: _CloudPainter())),
        ),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    // thân 180×56 bo 60, đặt dưới cùng; 2 cục tròn 80 và 60 nhô lên.
    const top = 40.0;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, top, 180, 56), const Radius.circular(60)), p);
    canvas.drawCircle(const Offset(28 + 40, top - 40 + 40), 40, p);
    canvas.drawCircle(const Offset(90 + 30, top - 28 + 30), 30, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
