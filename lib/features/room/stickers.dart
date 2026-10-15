// Album hình dán + huy hiệu (/album). Huy hiệu: kBadges + LearnTracker.badgeEarned (core/game/learn_tracking.dart).
// CHỦ: agent D. Port của reference/web/js/app.js album().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (StickersScreen) vì router/registry trỏ tới.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Hình đen mờ cho hình dán chưa có (filter: brightness(0) opacity(.12)).
const ColorFilter _shadowFilter = ColorFilter.matrix([
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, //
  0, 0, 0, .12, 0,
]);

/// Xám mờ cho huy hiệu chưa có (grayscale(1) opacity(.3)).
const ColorFilter _greyFilter = ColorFilter.matrix([
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  0, 0, 0, .3, 0,
]);

class StickersScreen extends ConsumerStatefulWidget {
  const StickersScreen({super.key});
  @override
  ConsumerState<StickersScreen> createState() => _StickersScreenState();
}

class _StickersScreenState extends ConsumerState<StickersScreen> with SayOnOpen {
  @override
  String? get openPhrase => 'album';

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i18n = ref.watch(i18nProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    final have = p.stickers.toSet();
    final badges = p.badges.toSet();
    final w = MediaQuery.sizeOf(context).width;
    final fs = baseFontSize(context);
    final audio = ref.read(audioProvider);
    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(
          leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                audio.sfx('tap');
                context.go('/map');
              }),
          title: i18n.t('albumTitle'),
          trailing: Pill(key: const Key('sticker-count'), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), children: [Text('${have.length}/${data.stickers.length}')]),
        ),
        GridView.extent(
          maxCrossAxisExtent: (w * .26).clamp(80.0, 130.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            for (final s in data.stickers)
              Chunky(
                key: Key('sticker-$s'),
                radius: 24,
                depth: 5,
                pressScale: .92,
                gradient: have.contains(s) ? const RadialGradient(center: Alignment(0, -.2), colors: [Colors.white, Color(0xFFFFF6DC)]) : null,
                color: have.contains(s) ? Colors.white : const Color(0x99FFFFFF),
                shadowColor: have.contains(s) ? const Color(0xFFF3DFA6) : const Color(0xCCE3ECF7),
                onTap: () => audio.sfx(have.contains(s) ? 'pop' : 'tap'),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .78,
                    child: have.contains(s) ? EmojiImage(s, photo: false) : ColorFiltered(colorFilter: _shadowFilter, child: EmojiImage(s, photo: false)),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
          child: Text('🏅 ${i18n.t('badges')}',
              textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.5, fontWeight: FontWeight.w800, color: AppColors.ink2)),
        ),
        GridView.extent(
          maxCrossAxisExtent: (w * .28).clamp(100.0, 150.0),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .85,
          children: [
            for (final b in kBadges)
              Container(
                key: Key('badge-${b.id}'),
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                decoration: BoxDecoration(
                  gradient: badges.contains(b.id) ? const RadialGradient(center: Alignment(0, -.4), colors: [Colors.white, Color(0xFFFFF4D6)]) : null,
                  color: badges.contains(b.id) ? null : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: badges.contains(b.id) ? const Color(0xFFF3DFA6) : AppColors.line, offset: const Offset(0, 5))],
                ),
                child: Column(spacing: 2, children: [
                  Expanded(
                    child: badges.contains(b.id) ? EmojiImage(b.img, photo: false) : ColorFiltered(colorFilter: _greyFilter, child: EmojiImage(b.img, photo: false)),
                  ),
                  Text(i18n.L(b),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs * .85, height: 1.15, color: badges.contains(b.id) ? AppColors.ink2 : AppColors.inkSoft)),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}
