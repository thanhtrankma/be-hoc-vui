// Nghỉ mắt (rest() của app.js): hết giờ chơi hôm nay; bố mẹ qua khoá thì cho thêm 10 phút.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});
  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> with SayOnOpen {
  @override
  String? get openPhrase => 'rest';

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final w = MediaQuery.sizeOf(context).width;
    return AppScreen(
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
            LoopAnim(
              period: const Duration(seconds: 3),
              builder: (context, t, child) => Transform.scale(scale: 1 + .06 * (t < .5 ? t * 2 : 2 - t * 2), child: child),
              child: EmojiImage('Sleeping face', size: (w * .25).clamp(150.0, 240.0), photo: false),
            ),
            ScreenTitle(i.t('restTitle')),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(i.t('restText'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const EmojiImage('Glass of milk', size: 90, photo: false),
            AppButton(
              icon: '⏱️',
              label: i.t('moreTime'),
              variant: BtnVariant.ghost,
              onTap: () async {
                if (await parentGate(context, ref)) {
                  ref.read(storeProvider).addBonus(10);
                  if (context.mounted) context.go('/map');
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}
