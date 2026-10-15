// Đổi linh vật (buddies() của app.js): linh vật mở khoá theo tổng sao.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';
import 'new_kid_screen.dart';

class BuddiesScreen extends ConsumerWidget {
  const BuddiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    final data = ref.watch(appDataProvider);
    final i = ref.watch(i18nProvider);
    final audio = ref.read(audioProvider);
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(
          leading: IconBtn(icon: AppIcon.back, label: 'Back', onTap: () {
            audio.sfx('tap');
            context.go('/map');
          }),
          title: i.t('buddies'),
          trailing: Pill(children: [const EmojiImage('Glowing star', size: 34, photo: false), Text('${p.stars}')]),
        ),
        MascotGrid(
          mascots: data.mascots,
          selected: p.mascot,
          isOpen: (m) => p.stars >= m.stars,
          onPick: (m) {
            if (p.stars < m.stars) {
              audio.sfx('wrong');
              audio.sayPhrase('needStars');
              return;
            }
            store.updateProfile(p.id, {'mascot': m.id});
            audio.sfx('pop');
            audio.say(audio.tpl(i.isEn ? 'mascotEn' : 'mascotVi', m.json));
          },
        ),
      ]),
    );
  }
}
