// Linh vật kèm đồ đang đeo (mũ, kính, đồ cầm tay) và nền (dressed() của app.js). Dùng ở bản đồ, màn chơi, phòng, bằng khen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content.dart';
import '../store/store.dart';
import 'emoji_image.dart';

/// Nền CSS đơn giản của tủ đồ → Gradient. Hỗ trợ linear-gradient(180deg, màu [vị trí%], ...) và radial-gradient(circle at x% y%, ...).
Gradient? cssGradient(String? css) {
  if (css == null) return null;
  final m = RegExp(r'^(linear|radial)-gradient\((.*)\)$').firstMatch(css.trim());
  if (m == null) return null;
  final parts = m[2]!.split(RegExp(r',(?![^(]*\))')).map((s) => s.trim()).toList();
  Alignment center = Alignment.center;
  if (parts.isNotEmpty && (parts.first.endsWith('deg') || parts.first.startsWith('circle'))) {
    final head = parts.removeAt(0);
    final at = RegExp(r'at (\d+)% (\d+)%').firstMatch(head);
    if (at != null) center = Alignment(int.parse(at[1]!) / 50 - 1, int.parse(at[2]!) / 50 - 1);
  }
  final colors = <Color>[];
  final stops = <double>[];
  for (var i = 0; i < parts.length; i++) {
    final seg = parts[i].split(' ');
    colors.add(parseColor(seg[0]));
    stops.add(seg.length > 1 && seg[1].endsWith('%') ? double.parse(seg[1].replaceAll('%', '')) / 100 : (parts.length == 1 ? 0 : i / (parts.length - 1)));
  }
  // vị trí phải tăng dần (CSS tự kẹp)
  for (var i = 1; i < stops.length; i++) {
    if (stops[i] < stops[i - 1]) stops[i] = stops[i - 1];
  }
  if (m[1] == 'radial') return RadialGradient(center: center, radius: .9, colors: colors, stops: stops);
  return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops);
}

/// Linh vật mặc đồ. buddy = bản nhỏ trong màn chơi (không vẽ nền).
class Dressed extends ConsumerWidget {
  const Dressed({super.key, required this.profile, this.size = 72, this.showBg = true});
  final Profile profile;
  final double size;
  final bool showBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final o = profile.outfit;
    final m = data.mascot(profile.mascot);
    WardrobeItem? item(String slot) => o[slot] is String ? data.wardrobeItem(o[slot] as String) : null;
    final hat = item('hat'), eyes = item('eyes'), hand = item('hand'), bg = item('bg');
    final s = size;
    return Container(
      width: s,
      height: s,
      decoration: showBg && bg?.bg != null ? BoxDecoration(gradient: cssGradient(bg!.bg), borderRadius: BorderRadius.circular(s * .3)) : null,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: EmojiImage(m.img, photo: false)),
        // vị trí như .dressed .o-hat/.o-eyes/.o-hand
        if (hat != null) Positioned(top: -s * .34, left: s * .18, width: s * .64, child: EmojiImage(hat.img, photo: false)),
        if (eyes != null) Positioned(top: s * .24, left: s * .20, width: s * .60, child: EmojiImage(eyes.img, photo: false)),
        if (hand != null) Positioned(right: -s * .22, bottom: -s * .08, width: s * .50, child: EmojiImage(hand.img, photo: false)),
      ]),
    );
  }
}
