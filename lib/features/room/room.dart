// Phòng của bé (/room): mua và đeo đồ cho linh vật bằng ví sao.
// CHỦ: agent D. Port của reference/web/js/app.js room().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (RoomScreen) vì router/registry trỏ tới.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'wardrobe.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});
  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> with SayOnOpen {
  @override
  String? get openPhrase => 'roomIntro';

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i18n = ref.watch(i18nProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    final isl = data.island('room');
    final w = MediaQuery.sizeOf(context).width;
    final wide = w > 760;
    final size = math.min(260.0, w * .6);
    final stage = Container(
      key: const Key('room-stage'),
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const RadialGradient(center: Alignment(0, -.2), colors: [Colors.white, Color(0xB3FFFFFF)], stops: [0, .7]),
        borderRadius: BorderRadius.circular(32),
        boxShadow: kCardShadow,
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: Dressed(profile: p, size: size - 20)),
    );
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(
          leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                context.go('/map');
              }),
          title: isl == null ? i18n.t('room') : i18n.L(isl),
          trailing: Pill(key: const Key('wallet'), children: [const EmojiImage('Glowing star', size: 28, photo: false), Text('${store.wallet(p)}')]),
        ),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 20, children: [
            Expanded(child: stage),
            const Expanded(child: WardrobeShop()),
          ])
        else
          Column(spacing: 20, children: [stage, const WardrobeShop()]),
      ]),
    );
  }
}
