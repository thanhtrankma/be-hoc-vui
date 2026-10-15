// Chọn cấp học (chooseTier() của app.js): Mầm (3–4 tuổi), Chồi (5 tuổi), Lớp 1 (6 tuổi).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/levels.dart';
import '../../core/game/learn_tracking.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

/// Mở bảng chọn cấp cho bé p. Trả về true nếu đã chọn.
Future<bool> chooseTier(BuildContext context, WidgetRef ref, Profile p) async {
  ref.read(audioProvider).sayPhrase('pickTier');
  final r = await showPanel<bool>(context: context, maxWidth: 760, builder: (ctx) => _TierPanel(profile: p));
  return r ?? false;
}

class _TierPanel extends ConsumerWidget {
  const _TierPanel({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final narrow = MediaQuery.sizeOf(context).width <= 640;
    final cards = [
      for (final x in kTiers)
        _TierCard(
          tier: x,
          on: profile.tier == x.id,
          narrow: narrow,
          lang: i.lang,
          onTap: () {
            ref.read(audioProvider).sfx('pop');
            ref.read(storeProvider).updateProfile(profile.id, {'tier': x.id});
            ref.read(learnTrackerProvider).viewTier.clear();
            Navigator.pop(context, true);
          },
        ),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      PanelTitle(i.t('pickTier')),
      const SizedBox(height: 14),
      if (narrow)
        Column(spacing: 14, children: cards)
      else
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [for (final c in cards) Expanded(child: c)])),
      const SizedBox(height: 6),
      NoteText(i.t('tierHint')),
    ]);
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.on, required this.narrow, required this.lang, required this.onTap});
  final TierInfo tier;
  final bool on, narrow;
  final String lang;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    final name = Text(tier.textOf(lang), style: TextStyle(fontSize: fs * 1.6, height: 1, color: Colors.white, fontWeight: FontWeight.w800, shadows: const [Shadow(color: Color(0x2E000000), offset: Offset(0, 2))]));
    final age = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(999)),
      child: Text(tier.age.textOf(lang), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
    );
    final what = Text(tier.what.textOf(lang), textAlign: narrow ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white, fontSize: fs * .85, fontWeight: FontWeight.w600, height: 1.25));
    final img = Bob(child: EmojiImage(tier.img, size: narrow ? 60 : (MediaQuery.sizeOf(context).width * .12).clamp(70.0, 100.0), photo: false));
    return Chunky(
      key: Key('tier-${tier.id}'),
      onTap: onTap,
      pressScale: .97,
      radius: 28,
      color: tier.color,
      gradient: RadialGradient(center: const Alignment(0, -.5), radius: 1, colors: [Color.alphaBlend(Colors.white.withValues(alpha: .35), tier.color), tier.color]),
      shadowColor: Color.alphaBlend(Colors.black.withValues(alpha: .15), tier.color),
      border: on ? Border.all(color: AppColors.sun, width: 5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: narrow
          ? Row(spacing: 12, children: [
              img,
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [name, age]), what])),
            ])
          : Column(spacing: 4, children: [img, name, age, what]),
    );
  }
}
