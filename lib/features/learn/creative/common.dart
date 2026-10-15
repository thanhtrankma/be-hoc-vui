// Tiện ích dùng chung của đảo Tư duy / Lập trình / Tô màu (agent C): rung lắc, nảy, ảnh chụp theo nhóm.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Có dùng ảnh chụp cho cả nhóm hình không (unifyPhotos của web). Không có dữ liệu → hoạt hình.
bool usePhotos(BuildContext context, Iterable<String> names) {
  try {
    return groupUsesPhotos(ProviderScope.containerOf(context, listen: false).read(contentBundleProvider).photos, names);
  } catch (_) {
    return false;
  }
}

/// Rung ngang (.shake của web, 0,4 giây) mỗi khi [trigger] đổi.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child, this.amount = 10});
  final int trigger;
  final Widget child;
  final double amount;
  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && Motion.enabled) _c.forward(from: 0);
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
          final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 6) * widget.amount * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// Nảy lên khi xuất hiện (animation pop .35s của web).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.from = .4, this.ms = 350});
  final Widget child;
  final double from;
  final int ms;
  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      builder: (context, k, child) => Transform.scale(scale: k < .6 ? from + (1.15 - from) * k / .6 : 1.15 - .15 * (k - .6) / .4, child: child),
      child: child,
    );
  }
}

/// Nhãn nút theo ngôn ngữ cho chỗ core i18n chưa có khoá (chỉ dùng làm nhãn trợ năng).
String trLabel(String lang, String vi, String en) => lang == 'en' ? en : vi;
