// Giao diện Gara / Xưởng / chọn chế độ đấu (phần DOM của funracer, funshooter, funtank, funvs1) bằng widget Flutter.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/theme.dart' show kFontFamily;
import 'package:flutter/material.dart';

TextStyle shopText(double size, {Color color = Colors.white, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: w, color: color, height: 1.1);

/// Rung ngang khi bấm mà không đủ xu (rcg-shake / shp-shake / tks-no).
class ShakeBox extends StatefulWidget {
  const ShakeBox({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  State<ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<ShakeBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  @override
  void didUpdateWidget(ShakeBox old) {
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
        builder: (_, child) => Transform.translate(offset: Offset(math.sin(_c.value * math.pi * 4) * 8 * (1 - _c.value), 0), child: child),
        child: widget.child,
      );
}

/// Thẻ bấm được (nút trắng bo tròn có bóng).
class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.child, this.onTap, this.on = false, this.color = const Color(0x2EFFFFFF), this.border = const Color(0x40FFFFFF), this.width});
  final Widget child;
  final VoidCallback? onTap;
  final bool on;
  final Color color, border;
  final double? width;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: on ? 1.04 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? const Color(0xFFFFD43B) : border, width: 4),
              boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 5))],
            ),
            child: child,
          ),
        ),
      );
}

/// Giá xu.
class PriceTag extends StatelessWidget {
  const PriceTag(this.price, {super.key, this.ok = true, this.color = Colors.white, this.size = 18});
  final int price;
  final bool ok;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: ok ? 1 : .45,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          EmojiImage('Coin', size: size * 1.2, photo: false),
          const SizedBox(width: 3),
          Text('$price', style: shopText(size, color: color)),
        ]),
      );
}

/// Ô số xu lớn ở đầu Gara / Xưởng.
class CoinPill extends StatelessWidget {
  const CoinPill(this.coins, {super.key, this.dark = true});
  final int coins;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('shop-coins'),
        padding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
        decoration: BoxDecoration(color: dark ? const Color(0x4D000000) : Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const EmojiImage('Coin', size: 34, photo: false),
          const SizedBox(width: 6),
          Text('$coins', style: shopText(26, color: dark ? Colors.white : const Color(0xFFE67700))),
        ]),
      );
}

/// Nút "Chơi ▶" to.
class PlayBtn extends StatelessWidget {
  const PlayBtn({super.key, required this.onTap, this.color = const Color(0xFF40C057), this.shade = const Color(0xFF2B8A3E)});
  final VoidCallback onTap;
  final Color color, shade;
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('shop-play'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: shade, offset: const Offset(0, 6))]),
          child: Text('Chơi ▶', style: shopText(30)),
        ),
      );
}

/// Khung cuộn chung: nền gradient, chừa chỗ nút ✕ ở góc trái trên.
class ShopFrame extends StatelessWidget {
  const ShopFrame({super.key, required this.colors, required this.children});
  final List<Color> colors;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 64, 12, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: children),
              ),
            ),
          ),
        ),
      );
}

/// Hộp nhóm (rcg-box / tks-row).
class ShopBox extends StatelessWidget {
  const ShopBox({super.key, required this.child, this.title, this.light = false});
  final Widget child;
  final Widget? title;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: light ? const Color(0xEBFFFFFF) : const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(22),
          boxShadow: light ? const [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 5))] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (title != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: title),
          child,
        ]),
      );
}

String starsText(int n, int max, [String on = '★', String off = '☆']) => on * n + off * (max - n);

/// Chọn chế độ đấu (chooseMode của funvs1): 🤖 Đấu với máy / 👨‍👦 Hai người.
class VsModePick extends StatelessWidget {
  const VsModePick({super.key, required this.title, required this.level, required this.onPick});
  final String title;
  final int level;
  final void Function(String mode) onPick;
  @override
  Widget build(BuildContext context) {
    Widget card(String key, String ico, String name, String sub, Color c) => GestureDetector(
          key: Key('vs-$key'),
          onTap: () => onPick(key),
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: c, width: 5),
              boxShadow: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 6))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Text(ico, style: const TextStyle(fontSize: 56)),
              Text(name, style: shopText(24, color: const Color(0xFF343A40))),
              Text(sub, textAlign: TextAlign.center, style: shopText(16, color: const Color(0xFF868E96), w: FontWeight.w600)),
            ]),
          ),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF74C0FC), Color(0xFFE7F5FF)])),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
              Text(title, textAlign: TextAlign.center, style: shopText(34, color: Colors.white).copyWith(shadows: const [Shadow(color: Color(0x4D000000), offset: Offset(0, 3))])),
              Wrap(spacing: 18, runSpacing: 18, alignment: WrapAlignment.center, children: [
                card('bot', '🤖', 'Đấu với máy', 'Cấp ${level + 1}', const Color(0xFF339AF0)),
                card('pvp', '👨‍👦', 'Hai người', 'Bố mẹ và bé cùng chơi', const Color(0xFFFA5252)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
