// Danh sách bài của một đảo (islandScreen() của app.js): tab cấp học, thanh tiến độ, lưới bài (sao, khoá, bài kế tiếp).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/content/levels.dart';
import '../../core/game/learn_tracking.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

/// Đảo vừa đọc câu dẫn (không đọc lại khi quay về từ màn chơi). Bản đồ đặt lại null.
String? islandIntroSaid;

class IslandScreen extends ConsumerStatefulWidget {
  const IslandScreen({super.key, required this.islandId});
  final String islandId;
  @override
  ConsumerState<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends ConsumerState<IslandScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isl = ref.read(appDataProvider).island(widget.islandId);
      if (isl == null || isl.soon || isl.route != null) {
        if (mounted) context.go('/map');
        return;
      }
      if (islandIntroSaid != widget.islandId) {
        final k = kIslandIntro[widget.islandId];
        if (k != null) ref.read(audioProvider).sayPhrase(k);
      }
      islandIntroSaid = widget.islandId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    final data = ref.watch(appDataProvider);
    final isl = data.island(widget.islandId);
    if (p == null || isl == null || isl.soon || isl.route != null) return const SizedBox();
    final content = ref.watch(contentProvider);
    final tracker = ref.watch(learnTrackerProvider);
    final i = ref.watch(i18nProvider);
    final audio = ref.read(audioProvider);
    final have = islTiers(isl, content);
    final cur = tracker.tierForIsland(isl, p);
    final lvls = tierLevels(isl, content, cur);
    final done = lvls.where((l) => store.levelStars(p, isl.id, l.i) > 0).length;
    bool open(int li) => levelUnlocked(lockOrder: store.lockOrder, isl: isl, content: content, i: li, starsOf: (k) => store.levelStars(p, isl.id, k));
    LevelInfo? firstOpen;
    for (final l in lvls) {
      if (store.levelStars(p, isl.id, l.i) == 0 && open(l.i)) {
        firstOpen = l;
        break;
      }
    }
    final w = MediaQuery.sizeOf(context).width;
    final fs = baseFontSize(context);

    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(
          leading: IconBtn(icon: AppIcon.back, label: 'Back', onTap: () {
            audio.sfx('tap');
            context.go('/map');
          }),
          title: i.L(isl),
          trailing: Pill(children: [const EmojiImage('Glowing star', size: 34, photo: false), Text('${p.stars}')]),
        ),
        if (have.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(alignment: WrapAlignment.center, spacing: w < 600 ? 6 : 10, runSpacing: 10, children: [
              for (final k in have)
                _TierTab(
                  tier: tierOf(k),
                  on: k == cur,
                  lang: i.lang,
                  showAge: w > 520,
                  compact: w < 600,
                  onTap: () {
                    audio.sfx('tap');
                    setState(() => tracker.viewTier[isl.id] = k);
                  },
                ),
            ]),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              height: 30,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x99FFFFFF), offset: Offset(0, 3))],
              ),
              child: Stack(children: [
                FractionallySizedBox(
                  widthFactor: lvls.isEmpty ? 0 : done / lvls.length,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(const Color(0x59FFFFFF), isl.color), isl.color], stops: const [0, .6]),
                    ),
                  ),
                ),
                Center(
                  child: Text(i.t('levelsDone', {'a': done, 'b': lvls.length}),
                      key: const Key('levels-done'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * .9, color: AppColors.ink2, shadows: const [Shadow(color: Colors.white, offset: Offset(0, 1))])),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final minCell = (w * .42).clamp(0.0, 160.0);
          final gap = (w * .02).clamp(12.0, 20.0);
          final cols = ((c.maxWidth + gap) / (minCell + gap)).floor().clamp(1, 12);
          final cell = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final (n, lv) in lvls.indexed)
              SizedBox(
                width: cell,
                child: RiseIn(
                  index: n,
                  child: LevelCard(
                    level: lv,
                    number: n + 1,
                    color: isl.color,
                    stars: store.levelStars(p, isl.id, lv.i),
                    open: open(lv.i),
                    next: identical(firstOpen, lv),
                    name: i.L(lv.name),
                    onTap: () {
                      if (!open(lv.i)) {
                        audio.sfx('wrong');
                        audio.sayPhrase('locked');
                        return;
                      }
                      audio.sfx('tap');
                      context.go('/play/${isl.id}/${lv.i}');
                    },
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _TierTab extends StatelessWidget {
  const _TierTab({required this.tier, required this.on, required this.lang, required this.showAge, required this.onTap, this.compact = false});
  final TierInfo tier;
  final bool on, showAge, compact;
  final String lang;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fg = on ? Colors.white : AppColors.ink2;
    return Chunky(
      key: Key('tiertab-${tier.id}'),
      onTap: onTap,
      radius: 999,
      depth: on ? 4 : 0,
      shadowColor: const Color(0x26000000),
      color: on ? tier.color : Colors.white.withValues(alpha: .8),
      border: Border.all(color: on ? Colors.white.withValues(alpha: .9) : Colors.transparent, width: 3),
      padding: compact ? const EdgeInsets.fromLTRB(6, 4, 12, 4) : const EdgeInsets.fromLTRB(8, 6, 18, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: compact ? 4 : 8, children: [
          EmojiImage(tier.img, size: compact ? 28 : 38, photo: false),
          Text(tier.textOf(lang), style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * 1.15, color: fg)),
          if (showAge) Text(tier.age.textOf(lang), style: TextStyle(fontWeight: FontWeight.w700, fontSize: baseFontSize(context) * .8, color: on ? Colors.white : AppColors.inkSoft)),
        ]),
      ),
    );
  }
}

/// Thẻ một bài (.level): vòng tròn màu đảo (hình/số/🔒), tên bài, ★★★. Bài kế tiếp viền vàng nhấp nháy.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.level, required this.number, required this.color, required this.stars, required this.open, required this.next, required this.name, required this.onTap});
  final LevelInfo level;
  final int number;
  final Color color;
  final int stars;
  final bool open, next;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    final border = next ? AppColors.sun : stars > 0 ? const Color(0xFFC9F2D3) : Colors.transparent;
    Widget card(double glow) => Chunky(
          key: Key('level-${level.i}'),
          onTap: onTap,
          pressScale: .95,
          radius: 28,
          depth: 6,
          border: Border.all(color: border, width: 3),
          extraShadow: glow > 0 ? [BoxShadow(color: const Color(0x8CFFC93C), spreadRadius: 8 * glow)] : const [],
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
          child: Opacity(
            opacity: open ? 1 : .55,
            child: Column(spacing: 2, children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: open ? color : const Color(0xFFC9D5E3),
                  gradient: open ? RadialGradient(center: const Alignment(-.3, -.44), radius: .6, colors: [Color.alphaBlend(const Color(0x73FFFFFF), color), color]) : null,
                  boxShadow: const [BoxShadow(color: Color(0x1423324D), offset: Offset(0, 4))],
                ),
                foregroundDecoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0x26000000)], stops: [0, .9, .9]),
                ),
                child: !open
                    ? const Text('🔒', style: TextStyle(fontSize: 30))
                    : level.img != null
                        ? EmojiImage(level.img!, size: 54, photo: false)
                        : Text('$number', style: TextStyle(color: Colors.white, fontSize: fs * 1.7, fontWeight: FontWeight.w800, shadows: const [Shadow(color: Color(0x26000000), offset: Offset(0, 2))])),
              ),
              SizedBox(
                height: fs * 1.05 * 1.15 * 2,
                child: Center(
                  child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.05, height: 1.15, color: AppColors.ink2)),
                ),
              ),
              StarRow(stars: stars, size: fs * 1.3),
            ]),
          ),
        );
    if (!next) return card(0);
    // Bài kế tiếp: vòng sáng vàng nhịp 1,4 giây (keyframes pulse).
    return LoopAnim(period: const Duration(milliseconds: 1400), builder: (context, t, _) => card(t < .5 ? t * 2 : 2 - t * 2));
  }
}
