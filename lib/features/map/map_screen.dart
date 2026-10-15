// Bản đồ đảo (map() của app.js): lời chào + cấp học + sao + album + đổi bé + bố mẹ; thử thách hôm nay;
// thanh Khu vui chơi & Thú cưng; lưới các đảo (tiến độ theo cấp đang học).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/content/levels.dart';
import '../../core/game/class_plan.dart';
import '../../core/game/learn_tracking.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';
import '../tiers/tier_picker.dart';
import 'island_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SayOnOpen {
  @override
  String? get openPhrase => 'pickIsland';

  @override
  void initState() {
    super.initState();
    islandIntroSaid = null;
    // Bé chưa chọn cấp học: hỏi ngay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(storeProvider).profile;
      if (mounted && p != null && p.tier == null) chooseTier(context, ref, p);
    });
  }

  void _go(String path) {
    ref.read(audioProvider).sfx('tap');
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    final data = ref.watch(appDataProvider);
    final content = ref.watch(contentProvider);
    final i = ref.watch(i18nProvider);
    final tracker = ref.watch(learnTrackerProvider);
    final w = MediaQuery.sizeOf(context).width;
    final tier = tierOf(p.tier);

    final hello = GestureDetector(
      key: const Key('hello'),
      onTap: () => _go('/buddies'),
      child: Row(spacing: 12, children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const RadialGradient(center: Alignment(0, -.3), colors: [Colors.white, Color(0xFFE8F4FF)], stops: [0, .75]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: solidShadow(AppColors.line, 5),
          ),
          child: Dressed(profile: p, size: 60),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(i.t('hi', {'name': p.name}), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: baseFontSize(context) * 1.45, fontWeight: FontWeight.w800, height: 1.05, color: AppColors.ink2)),
            Text(i.t('pickIsland'), style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: baseFontSize(context) * .9)),
          ]),
        ),
      ]),
    );
    // Màn hẹp (< 600px): nút 48px, hình 26-30px, khoảng cách 8px như CSS của web.
    final compact = w < 600;
    final pillImg = compact ? 26.0 : 34.0;
    final tools = [
      Pill(
        key: const Key('tier-pill'),
        borderColor: tier.color,
        padding: compact ? const EdgeInsets.fromLTRB(6, 2, 10, 2) : const EdgeInsets.fromLTRB(6, 3, 14, 3),
        onTap: () {
          ref.read(audioProvider).sfx('tap');
          chooseTier(context, ref, p);
        },
        children: [EmojiImage(tier.img, size: compact ? 26 : 30, photo: false), Text(i.L(tier))],
      ),
      Pill(
        padding: compact ? const EdgeInsets.fromLTRB(6, 4, 10, 4) : null,
        children: [EmojiImage('Glowing star', size: pillImg, photo: false), Text('${p.stars}', key: const Key('star-count'))],
      ),
      IconBtn(size: compact ? 48 : 60, label: i.t('album'), onTap: () => _go('/album'), child: EmojiImage('Trophy', size: compact ? 30 : 40, photo: false)),
      IconBtn(size: compact ? 48 : 60, icon: AppIcon.kids, label: i.t('switchKid'), onTap: () => _go('/kids')),
      ParentButton(height: compact ? 48 : 60, onPassed: () => context.go('/parent')),
    ];
    final topbar = w < 600
        ? Column(children: [
            hello,
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: tools),
          ])
        : Row(spacing: 12, children: [Expanded(child: hello), ...tools]);

    // Bé Lớp 1: ô Học cùng lớp lên đầu bản đồ.
    final islands = [...data.islands];
    if (p.tier == 3) {
      final k = islands.indexWhere((x) => x.id == 'lop1');
      if (k > 0) islands.insert(0, islands.removeAt(k));
    }
    final portraitTablet = w >= 600 && w <= 900 && MediaQuery.orientationOf(context) == Orientation.portrait;
    final cols = w > 820 && !portraitTablet ? 4 : portraitTablet ? 3 : 2;
    final aspect = w > 820 && !portraitTablet ? 1.55 : portraitTablet ? 1 / 1.02 : w < 600 ? 1 / .92 : 1 / 1.05;

    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(bottom: 14), child: topbar),
        _DailyBar(profile: p, onGo: _go),
        const SizedBox(height: 12),
        _FunBars(profile: p, onGo: _go),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: (w * .02).clamp(12.0, 22.0),
          crossAxisSpacing: (w * .02).clamp(12.0, 22.0),
          childAspectRatio: aspect,
          children: [
            for (final (k, isl) in islands.indexed)
              RiseIn(
                index: k,
                child: IslandCard(
                  island: isl,
                  index: k,
                  profile: p,
                  wide: w > 820 && !portraitTablet,
                  progress: () {
                    if (isl.route != null || isl.soon) return null;
                    final lv = tierLevels(isl, content, tracker.tierForIsland(isl, p));
                    return (lv.where((l) => store.levelStars(p, isl.id, l.i) > 0).length, lv.length);
                  }(),
                  special: isl.id == 'room'
                      ? '⭐ ${store.wallet(p)}'
                      : isl.id == 'lop1'
                          ? 'Tuần ${ref.read(classPlanProvider).classWeek(p)}'
                          : '👨‍👩‍👦',
                  onTap: () {
                    if (isl.route != null) return _go(isl.route!);
                    if (isl.soon) {
                      ref.read(audioProvider).sfx('pop');
                      ref.read(audioProvider).sayPhrase('soon');
                      return;
                    }
                    _go('/island/${isl.id}');
                  },
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

/// Một ô đảo (.island): nền màu đảo có vầng sáng, hình nhún, tên, thanh tiến độ.
class IslandCard extends ConsumerWidget {
  const IslandCard({super.key, required this.island, required this.index, required this.profile, required this.progress, required this.special, required this.onTap, this.wide = false});
  final Island island;
  final int index;
  final Profile profile;
  final (int, int)? progress;
  final String special;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final fs = baseFontSize(context) * (wide ? 1.15 : 1.15);
    final c = island.color;
    final isSpecial = island.route != null;
    final full = progress != null && progress!.$2 > 0 && progress!.$1 == progress!.$2;
    final textShadow = const [Shadow(color: Color(0x33000000), offset: Offset(0, 2))];
    Widget body = LayoutBuilder(builder: (context, cons) {
      final imgW = cons.maxWidth * (wide ? .40 : .54);
      return Stack(children: [
        // vầng sáng sau hình (.island::after) + lớp bóng (.island::before)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x2EFFFFFF), Color(0x00FFFFFF), Color(0x14000000)], stops: [0, .4, 1]),
              border: full ? Border.all(color: const Color(0xE6FFE066), width: 5) : null,
            ),
          ),
        ),
        Positioned(
          top: cons.maxHeight * .10,
          left: (cons.maxWidth - cons.maxWidth * .54) / 2,
          width: cons.maxWidth * .54,
          height: cons.maxWidth * .54,
          child: const DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x38FFFFFF))),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8, wide ? 8 : 10, 8, wide ? 10 : 10),
          child: Column(children: [
            SizedBox(height: cons.maxHeight * (wide ? .02 : .04)),
            Expanded(
              child: Bob(
                delay: Duration(milliseconds: index.isOdd ? 1500 : 0),
                child: SizedBox(width: imgW, child: EmojiImage(island.img, photo: false)),
              ),
            ),
            Text(
              i.L(island),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fs, height: 1.1, shadows: textShadow),
            ),
            if (isSpecial)
              Text(special, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: fs * .58, shadows: textShadow))
            else if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FractionallySizedBox(
                  widthFactor: .78,
                  child: Row(spacing: 6, children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 9,
                          color: Colors.black.withValues(alpha: .18),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress!.$2 == 0 ? 0 : progress!.$1 / progress!.$2,
                            child: Container(decoration: BoxDecoration(color: full ? const Color(0xFFFFE066) : Colors.white, borderRadius: BorderRadius.circular(99))),
                          ),
                        ),
                      ),
                    ),
                    Text('${progress!.$1}/${progress!.$2}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: fs * .58, shadows: textShadow)),
                  ]),
                ),
              ),
          ]),
        ),
        if (island.soon)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(999)),
              child: Text(i.t('soon'), style: TextStyle(color: AppColors.inkSoft, fontSize: fs * .5, fontWeight: FontWeight.w800)),
            ),
          ),
      ]);
    });
    if (island.soon) body = Opacity(opacity: .75, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_desat), child: body));
    return Chunky(
      key: Key('island-${island.id}'),
      onTap: onTap,
      pressScale: .95,
      radius: 34,
      depth: 8,
      shadowColor: const Color(0x24000000),
      extraShadow: const [BoxShadow(color: Color(0x2623324D), offset: Offset(0, 14), blurRadius: 26)],
      color: c,
      gradient: isSpecial
          ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF845EF7), Color(0xFFFF6FAE)])
          : RadialGradient(center: const Alignment(0, -.4), radius: .8, colors: [Color.alphaBlend(Colors.white.withValues(alpha: .55), c), c]),
      child: ClipRRect(borderRadius: BorderRadius.circular(34), child: body),
    );
  }
}

// saturate(.35)
const List<double> _desat = [
  .5228, .4683, .0089, 0, 0, //
  .1393, .8518, .0089, 0, 0, //
  .1393, .4683, .3924, 0, 0, //
  0, 0, 0, 1, 0,
];

/// Thử thách hôm nay (dailyBar): 3 đảo theo ngày, chuỗi ngày, nút ôn bài.
class _DailyBar extends ConsumerWidget {
  const _DailyBar({required this.profile, required this.onGo});
  final Profile profile;
  final void Function(String) onGo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i = ref.watch(i18nProvider);
    final tracker = ref.watch(learnTrackerProvider);
    final dl = store.peekDaily();
    if (dl == null) {
      // Tạo thử thách hôm nay sau khung hình (store.daily() có ghi máy).
      WidgetsBinding.instance.addPostFrameCallback((_) => store.daily(data.gameIslands.map((x) => x.id).toList()));
      return const SizedBox(height: 64);
    }
    final claimed = dl['claimed'] == true;
    final done = asStrList(dl['done']);
    final due = tracker.dueCount(profile);
    final streak = profile.streakCount;
    return Container(
      key: const Key('daily'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: claimed ? const Color(0xFFE7FBE9) : Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(22),
        boxShadow: solidShadow(AppColors.line, 4),
      ),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        Text('🎯 ${i.t('daily')}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink2)),
        Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
          for (final id in asStrList(dl['tasks']))
            if (data.island(id) case final isl?)
              Chunky(
                onTap: () => onGo('/island/$id'),
                pressScale: .92,
                depth: 0,
                radius: 16,
                color: isl.color,
                extraShadow: const [BoxShadow(color: Color(0x26000000), offset: Offset(0, -4), spreadRadius: -2)],
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(alignment: Alignment.center, children: [
                    Opacity(opacity: done.contains(id) ? .5 : 1, child: EmojiImage(isl.img, size: 37, photo: false)),
                    if (done.contains(id))
                      const Text('✔', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, shadows: [Shadow(color: Color(0x4D000000), offset: Offset(0, 2))])),
                  ]),
                ),
              ),
        ]),
        if (streak > 0) Text('🔥 ${i.t('streak', {'n': streak})}', style: const TextStyle(color: Color(0xFFE8590C), fontWeight: FontWeight.w800)),
        if (due >= 2)
          Chunky(
            onTap: () => onGo('/review'),
            color: const Color(0xFF845EF7),
            shadowColor: const Color(0xFF5F3DC4),
            depth: 4,
            radius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔁 Ôn bài ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text('$due', style: const TextStyle(color: Color(0xFF5F3DC4), fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// Thanh Khu vui chơi + Thú cưng (.bars2 .funbar).
class _FunBars extends ConsumerWidget {
  const _FunBars({required this.profile, required this.onGo});
  final Profile profile;
  final void Function(String) onGo;

  Widget _bar(BuildContext context, {required Key key, required Gradient g, required String img, required String title, required Widget sub, List<String> games = const [], required VoidCallback onTap}) {
    final w = MediaQuery.sizeOf(context).width;
    final fs = baseFontSize(context);
    return Chunky(
      key: key,
      onTap: onTap,
      pressScale: .98,
      radius: 24,
      depth: 6,
      shadowColor: const Color(0x26000000),
      gradient: g,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: LayoutBuilder(builder: (context, c) {
          // Hình game nhỏ bên phải chỉ hiện khi đủ chỗ (web: ẩn dưới 560px).
          final showGames = games.isNotEmpty && w > 560 && c.maxWidth > 430;
          return Row(spacing: 12, children: [
            Bob(period: const Duration(seconds: 2), child: EmojiImage(img, size: 54, photo: false)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * .5),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fs * (w <= 900 ? 1.15 : 1.3), shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 2))])),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 2, 12, 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(999)),
                child: DefaultTextStyle.merge(style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: fs * (w <= 900 ? .8 : 1)), child: sub),
              ),
            ),
            if (showGames)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(fit: BoxFit.scaleDown, child: Row(spacing: 4, children: [for (final g in games) EmojiImage(g, size: 44, photo: false)])),
                ),
              ),
          ]);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i = ref.watch(i18nProvider);
    final pet = profile.pet;
    final bars = <Widget>[
      if (store.funOn)
        _bar(
          context,
          key: const Key('funbar'),
          g: const LinearGradient(begin: Alignment(-1, -.4), end: Alignment(1, .4), colors: [Color(0xFF7048E8), Color(0xFFF03E3E), Color(0xFFF59F00)], stops: [0, .6, 1]),
          img: 'Joystick',
          title: i.t('funZone'),
          sub: Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
            const EmojiImage('Admission tickets', size: 30, photo: false),
            Flexible(child: Text(' ${i.t('tickets', {'n': store.tickets(profile)})}', overflow: TextOverflow.ellipsis)),
          ]),
          games: const ['Racing car', 'Rocket', 'Robot'],
          onTap: () => onGo('/fun'),
        ),
      _bar(
        context,
        key: const Key('petbar'),
        g: const LinearGradient(begin: Alignment(-1, -.4), end: Alignment(1, .4), colors: [Color(0xFFFF8787), Color(0xFFF783AC), Color(0xFFFFA94D)], stops: [0, .55, 1]),
        img: pet != null ? data.pet(pet['type'] as String?).img : 'Paw prints',
        title: pet != null ? asStr(pet['name']) : i.t('petRoom'),
        sub: Text('❤️ ${pet != null ? i.t('petCare') : i.t('petAdopt')}', overflow: TextOverflow.ellipsis),
        onTap: () => onGo('/pet'),
      ),
    ];
    if (MediaQuery.sizeOf(context).width <= 700 || bars.length == 1) return Column(spacing: 12, children: bars);
    return Row(spacing: 12, children: [for (final b in bars) Expanded(child: b)]);
  }
}
