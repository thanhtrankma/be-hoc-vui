// Khối giao diện dùng chung theo app.css: nút to bo tròn (.btn), nút biểu tượng (.icon-btn), viên thuốc (.pill),
// thanh trên (.topbar), thẻ (.card), nút chọn (.seg), chấm tiến độ (.progress), sao (.lstars), dấu thanh (toneMark).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Hộp "nổi" có bóng đặc phía dưới, nhấn thì lún xuống (kiểu nút của web). Nền tảng cho mọi nút.
class Chunky extends StatefulWidget {
  const Chunky({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.gradient,
    this.shadowColor = AppColors.line,
    this.depth = 6,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.border,
    this.extraShadow = const [],
    this.pressScale = 1,
    this.enabled = true,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Gradient? gradient;
  final Color shadowColor;
  final double depth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final List<BoxShadow> extraShadow;

  /// Thu nhỏ khi nhấn (.island:active { scale(.95) }) thay vì lún. 1 = lún.
  final double pressScale;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<Chunky> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sink = widget.pressScale == 1 && _down;
    final dy = sink ? widget.depth - 1 : 0.0;
    final shadowDy = sink ? 1.0 : widget.depth;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(0, dy, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.gradient == null ? widget.color : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.border,
        boxShadow: [if (widget.depth > 0) BoxShadow(color: widget.shadowColor, offset: Offset(0, shadowDy)), ...widget.extraShadow],
      ),
      child: widget.child,
    );
    final scaled = widget.pressScale == 1 ? box : AnimatedScale(scale: _down ? widget.pressScale : 1, duration: const Duration(milliseconds: 100), child: box);
    final content = Opacity(opacity: widget.enabled ? 1 : .45, child: scaled);
    if (widget.onTap == null || !widget.enabled) return Semantics(label: widget.semanticLabel, child: content);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

enum BtnVariant { primary, blue, green, ghost, ghostPanel }

/// Nút chính (.btn): to, bo tròn, chữ đậm trắng. big = nút Bắt đầu (84px).
class AppButton extends StatelessWidget {
  const AppButton({super.key, this.label, this.child, this.icon, this.onTap, this.variant = BtnVariant.primary, this.big = false, this.enabled = true, this.minWidth, this.fontSize});
  final String? label;
  final Widget? child;

  /// Biểu tượng/emoji trước chữ (vd. '▶', '🔄').
  final String? icon;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final bool big;
  final bool enabled;
  final double? minWidth;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, sh, fg) = switch (variant) {
      BtnVariant.primary => (AppColors.primary, AppColors.primaryDark, Colors.white),
      BtnVariant.blue => (AppColors.blue, AppColors.blueDark, Colors.white),
      BtnVariant.green => (AppColors.good, AppColors.goodDark, Colors.white),
      BtnVariant.ghost => (Colors.white, AppColors.line, AppColors.ink),
      BtnVariant.ghostPanel => (const Color(0xFFEEF3FA), const Color(0xFFD3DEEC), AppColors.ink),
    };
    final base = baseFontSize(context);
    final fs = fontSize ?? base * (big ? 1.5 : 1.15);
    final light = variant != BtnVariant.ghost && variant != BtnVariant.ghostPanel;
    final text = DefaultTextStyle.merge(
      style: TextStyle(
        color: fg,
        fontWeight: FontWeight.w800,
        fontSize: fs,
        height: 1.1,
        shadows: light ? const [Shadow(color: Color(0x1F000000), offset: Offset(0, 2))] : null,
      ),
      // Chỗ hẹp: thu nhỏ chữ thay vì tràn.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Text(icon!), SizedBox(width: fs * .4)],
          child ?? Text(label ?? '', textAlign: TextAlign.center, maxLines: 1),
        ]),
      ),
    );
    return Chunky(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      enabled: enabled,
      color: bg,
      gradient: light
          ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .55], colors: [Color.alphaBlend(const Color(0x47FFFFFF), bg), bg])
          : null,
      shadowColor: sh,
      depth: 6,
      radius: 999,
      padding: EdgeInsets.symmetric(horizontal: fs * (big ? 1.8 : 1.4)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: big ? 84 : 64, minWidth: minWidth ?? 0),
        child: Center(widthFactor: 1, child: text),
      ),
    );
  }
}

/// Biểu tượng nét tròn đồng bộ (ICONS của ui.js): back, close, gear, kids.
enum AppIcon { back, close, gear, kids }

const Map<AppIcon, String> _iconPaths = {
  AppIcon.back: '<path d="M14.5 5.5 8 12l6.5 6.5"/>',
  AppIcon.close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
  AppIcon.gear:
      '<path d="M19.2 10.4 L21.5 10.8 L21.5 13.2 L19.2 13.6 L18.2 16.0 L19.6 17.9 L17.9 19.6 L16.0 18.2 L13.6 19.2 L13.2 21.5 L10.8 21.5 L10.4 19.2 L8.0 18.2 L6.1 19.6 L4.4 17.9 L5.8 16.0 L4.8 13.6 L2.5 13.2 L2.5 10.8 L4.8 10.4 L5.8 8.0 L4.4 6.1 L6.1 4.4 L8.0 5.8 L10.4 4.8 L10.8 2.5 L13.2 2.5 L13.6 4.8 L16.0 5.8 L17.9 4.4 L19.6 6.1 L18.2 8.0Z" stroke-linejoin="round"/><circle cx="12" cy="12" r="3"/>',
  AppIcon.kids:
      '<circle cx="9" cy="8.5" r="3.2"/><path d="M3.5 19.5c.6-3.3 2.8-5 5.5-5s4.9 1.7 5.5 5"/><circle cx="16.8" cy="9.5" r="2.5"/><path d="M15.6 14.6c2.6-.3 4.4 1.3 4.9 4.4"/>',
};

class AppIconView extends StatelessWidget {
  const AppIconView(this.icon, {super.key, this.size = 30, this.color = AppColors.ink2});
  final AppIcon icon;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final sw = icon == AppIcon.back ? 3.2 : 2.6;
    final svg = '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="$hex" stroke-width="$sw" '
        'stroke-linecap="round" stroke-linejoin="round">${_iconPaths[icon]}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Nút vuông trắng 60×60 (.icon-btn) chứa biểu tượng hoặc hình.
class IconBtn extends StatelessWidget {
  const IconBtn({super.key, this.icon, this.child, required this.onTap, this.label, this.size = 60});
  final AppIcon? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final String? label;
  final double size;
  @override
  Widget build(BuildContext context) {
    final btn = Chunky(
      onTap: onTap,
      depth: 5,
      radius: 20,
      semanticLabel: label ?? icon?.name,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child ?? (icon == null ? null : AppIconView(icon!, size: size / 2))),
      ),
    );
    // Nút Quay lại / ✕ của màn cũng là nút Back của Android (web: nút back trình duyệt về màn trước).
    // Không có thì Back thoát app ngay giữa game vì go_router chỉ giữ một trang.
    // Panel mở đè lên thì route của nút không còn là route hiện tại → Back đóng panel trước.
    if (onTap == null || (icon != AppIcon.back && icon != AppIcon.close)) return btn;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onTap!();
      },
      child: btn,
    );
  }
}

/// Viên thuốc trắng (.pill): hình nhỏ + số (sao, vé...).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.children, this.onTap, this.borderColor, this.padding});
  final List<Widget> children;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    return Chunky(
      onTap: onTap,
      depth: 4,
      radius: 999,
      border: borderColor == null ? null : Border.all(color: borderColor!, width: 3),
      padding: padding ?? const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink2, fontSize: fs),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: children),
        ),
      ),
    );
  }
}

/// Tiêu đề màn (.topbar h1): giữa, đậm, viền trắng.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.textAlign = TextAlign.center});
  final String text;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) {
    final fs = vwClamp(context, 22, 2.4, 36, 10);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fs, height: 1.1, fontWeight: FontWeight.w800, color: AppColors.ink2, shadows: const [Shadow(color: Colors.white, offset: Offset(0, 2))]),
    );
  }
}

/// Thanh trên: [trái] tiêu đề [phải]. Mặc định trái/phải rộng 60 (.spacer) để tiêu đề nằm giữa.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.leading, this.title, this.titleWidget, this.trailing, this.bottomGap = 14});
  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final double bottomGap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(spacing: 12, children: [
          leading ?? const SizedBox(width: 60),
          Expanded(child: titleWidget ?? (title == null ? const SizedBox() : ScreenTitle(title!))),
          trailing ?? const SizedBox(width: 60),
        ]),
      ),
    );
  }
}

/// Thẻ trắng bo 28 (.card).
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18), this.radius = 28, this.color = Colors.white});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: kCardShadow),
        child: child,
      );
}

/// Nhóm nút chọn một (.seg) như cài đặt Bật/Tắt.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onPick});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onPick;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(999)),
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final (v, label) in options)
          GestureDetector(
            onTap: () => onPick(v),
            // Không dùng Container.alignment: trong Wrap nó làm mỗi nút giãn hết bề ngang → các lựa chọn xếp dọc.
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: v == value ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: v == value ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2))] : null,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: v == value ? AppColors.ink : AppColors.inkSoft)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Chấm tiến độ trong màn chơi (.progress i): xong = xanh, đang làm = vàng to hơn.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.index, required this.total});
  final int index;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
      for (var k = 0; k < total; k++)
        AnimatedScale(
          scale: k == index ? 1.25 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k < index ? AppColors.good : k == index ? AppColors.sun : Colors.white.withValues(alpha: .75),
              boxShadow: const [BoxShadow(color: Color(0x14000000), offset: Offset(0, -3), spreadRadius: -1)],
            ),
          ),
        ),
    ]);
  }
}

/// ★★★ của danh sách bài: sao đạt màu vàng, còn lại xám nhạt.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.max = 3, this.size});
  final int stars;
  final int max;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final fs = size ?? baseFontSize(context) * 1.15;
    return Text.rich(
      TextSpan(children: [
        for (var k = 0; k < max; k++) TextSpan(text: '★', style: TextStyle(color: k < stars ? AppColors.sun : const Color(0xFFD9E2EE))),
      ]),
      style: TextStyle(fontSize: fs, letterSpacing: 2, height: 1.1),
    );
  }
}

/// Dấu thanh vẽ bằng SVG (sách lớp 1 dạy dấu là hình ` ´ ̉ ~ .), không phụ thuộc phông máy.
class ToneMark extends StatelessWidget {
  const ToneMark(this.tone, {super.key, this.size = 40, this.color = AppColors.ink});
  final String tone;
  final double size;
  final Color color;
  static const Map<String, String> paths = {
    'ngang': '<path d="M5 12h14"/>',
    'huyền': '<path d="M8 4l8 9"/>',
    'sắc': '<path d="M16 4l-8 9"/>',
    'hỏi': '<path d="M9.6 5.6Q9.6 3.2 12.2 3.2T14.8 5.6Q14.8 7.4 12.2 7.9V9.6"/>',
    'ngã': '<path d="M5 10Q8 5 12 9T19 8"/>',
    'nặng': '<circle cx="12" cy="18" r="2.4" fill="currentColor" stroke="none"/>',
  };
  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final body = (paths[tone] ?? '').replaceAll('currentColor', hex);
    final svg = '<svg viewBox="0 0 24 22" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="$hex" stroke-width="2.6" '
        'stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return Semantics(label: tone, child: SvgPicture.string(svg, width: size, height: size * 22 / 24));
  }
}

/// Khung một màn (#app của web): nền trong suốt (thấy nền trời), lề an toàn, lề 16px, rộng tối đa 1200 ở giữa.
/// scroll: nội dung dài cuộn dọc (danh sách đảo, bài...).
class AppScreen extends StatelessWidget {
  const AppScreen({super.key, required this.child, this.scroll = false, this.maxWidth = 1200, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 18)});
  final Widget child;
  final bool scroll;
  final double maxWidth;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);
    // RepaintBoundary: khi cuộn chỉ dời lớp nội dung đã vẽ, không ghi lại cả danh sách (thẻ đảo, ~50 thẻ game) mỗi khung.
    if (scroll) body = SingleChildScrollView(child: RepaintBoundary(child: body));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: body),
        ),
      ),
    );
  }
}
