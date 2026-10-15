// Chọn bé (kids() của app.js): thẻ từng bé (linh vật, tên, sao) + thẻ "Thêm bé"; nút Bố mẹ góc phải.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

class KidsScreen extends ConsumerStatefulWidget {
  const KidsScreen({super.key});
  @override
  ConsumerState<KidsScreen> createState() => _KidsScreenState();
}

class _KidsScreenState extends ConsumerState<KidsScreen> with SayOnOpen {
  @override
  String? get openPhrase => 'whoPlays';

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i = ref.watch(i18nProvider);
    final audio = ref.read(audioProvider);
    final w = MediaQuery.sizeOf(context).width;
    final cardW = w <= 480 ? (w - 32 - 14) / 2 : (w * .26).clamp(150.0, 220.0);
    final fs = baseFontSize(context);
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(title: i.t('whoPlays'), trailing: ParentButton(onPassed: () => context.go('/parent'))),
        SizedBox(height: MediaQuery.sizeOf(context).height * .04),
        Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 18, children: [
          for (final p in store.profiles)
            SizedBox(
              width: cardW,
              child: Chunky(
                key: Key('kid-${p.id}'),
                pressScale: .97,
                extraShadow: kCardShadow,
                depth: 0,
                onTap: () {
                  audio.sfx('tap');
                  store.setActive(p.id);
                  context.go('/map');
                },
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
                child: Column(spacing: 6, children: [
                  Container(
                    width: (w * .14).clamp(84.0, 120.0),
                    height: (w * .14).clamp(84.0, 120.0),
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(0, -.3), colors: [Colors.white, Color(0xFFE8F4FF)], stops: [0, .7])),
                    child: EmojiImage(data.mascot(p.mascot).img, photo: false),
                  ),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.35, fontWeight: FontWeight.w800, color: AppColors.ink2, height: 1.15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7D6), borderRadius: BorderRadius.circular(999)),
                    child: Text('⭐ ${p.stars}', style: const TextStyle(color: Color(0xFF8A6100), fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          SizedBox(
            width: cardW,
            child: GestureDetector(
              key: const Key('kid-add'),
              onTap: () {
                audio.sfx('tap');
                context.go('/new');
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: .9), width: 4),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 8, children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: solidShadow(AppColors.primaryDark, 5)),
                    child: Text('+', style: TextStyle(color: Colors.white, fontSize: fs * 2.4, fontWeight: FontWeight.w800, height: 1)),
                  ),
                  Text(i.t('addKid'), style: TextStyle(fontSize: fs * 1.2, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
