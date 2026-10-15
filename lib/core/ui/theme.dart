// Bảng màu, phông Baloo 2 và cỡ chữ theo app.css (:root). Dùng AppColors.* thay vì tự chọn màu.
import 'dart:math';

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const ink = Color(0xFF23324D);
  static const inkSoft = Color(0xFF5B6B88);
  static const ink2 = Color(0xFF33456A);
  static const skyTop = Color(0xFF8FD3FF);
  static const skyBottom = Color(0xFFE6F7FF);
  static const warm = Color(0xFFFFF7E0);
  static const card = Colors.white;
  static const line = Color(0xFFE3ECF7);
  static const sun = Color(0xFFFFC93C);
  static const sunDark = Color(0xFFE0A800);
  static const good = Color(0xFF22C55E);
  static const goodDark = Color(0xFF169947);
  static const bad = Color(0xFFFF6B6B);
  static const primary = Color(0xFFFF8A5B);
  static const primaryDark = Color(0xFFE86A3A);
  static const blue = Color(0xFF4FB3FF);
  static const blueDark = Color(0xFF2B8FD9);
  static const segBg = Color(0xFFEEF3F9);
  static const hill1 = Color(0xFFD3F2C9);
  static const hill2 = Color(0xFFC2EBB6);
  static const prize = Color(0xFFFFF7E0);
  static const overlayScrim = Color(0x5923324D); // rgba(35,50,77,.35)

  /// Màu pháo giấy (ui.js confetti).
  static const confetti = [Color(0xFFFF8A5B), Color(0xFFFFC93C), Color(0xFF4FB3FF), Color(0xFF3CCF91), Color(0xFFB388FF), Color(0xFFFF6FAE)];
}

const String kFontFamily = 'Baloo2';

/// Bóng đổ kiểu "nút nổi" của web: 0 6px 0 màu đậm.
List<BoxShadow> solidShadow(Color c, [double dy = 6]) => [BoxShadow(color: c, offset: Offset(0, dy))];

/// --shadow của thẻ: 0 6px 0 rgba(35,50,77,.12), 0 12px 28px rgba(35,50,77,.10)
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x1F23324D), offset: Offset(0, 6)),
  BoxShadow(color: Color(0x1A23324D), offset: Offset(0, 12), blurRadius: 28),
];

/// Cỡ chữ gốc như body { font-size: clamp(17px, 1.6vw + 10px, 22px) }. Các cỡ "em" của web nhân với số này.
double baseFontSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (0.016 * w + 10).clamp(17.0, 22.0);
}

/// clamp(min, vw*k + add, max) theo bề ngang màn hình.
double vwClamp(BuildContext context, double minV, double vw, double maxV, [double add = 0]) {
  final w = MediaQuery.sizeOf(context).width;
  return max(minV, min(maxV, w * vw / 100 + add));
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: kFontFamily,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue, primary: AppColors.primary, surface: Colors.white),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: kFontFamily, bodyColor: AppColors.ink, displayColor: AppColors.ink2),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: _EnterTransitionBuilder(),
        TargetPlatform.android: _EnterTransitionBuilder(),
      }),
    );
  }
}

/// Chuyển màn như web (.screen { animation: enter }): mờ dần + trượt lên 16px.
class _EnterTransitionBuilder extends PageTransitionsBuilder {
  const _EnterTransitionBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final a = CurvedAnimation(parent: animation, curve: const Cubic(.2, .8, .3, 1));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: child),
    );
  }
}
