// Học cùng lớp (/lop1): lộ trình theo tuần học (content.kntt). Mở hoạt động: context.go("/play/<đảo>/<bài>/lop1") — khung màn chơi đã xử lý "bài tiếp"/thưởng vé theo bài sách (classDone).
// CHỦ: agent D. Port của reference/web/js/app.js classScreen()/pickClassWeek().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (Lop1Screen) vì router/registry trỏ tới.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/game/class_plan.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'room_strings.dart';

const Color _kBlue = Color(0xFF3D8BFD);

// Giữ môn đang xem và các mục đang mở khi quay lại (như classSubj/classOpen của web).
String _classSubj = 'tv';
final Map<String, bool> _classOpen = {};

/// Các nhóm bài của tuần: bài tuần này, bài đã qua, bài sắp tới.
({List<ClassItem> cur, List<ClassItem> prev, List<ClassItem> next}) classGroups(List<ClassItem> items, int wk) {
  var cur = items.where((x) => x.wk == wk).toList();
  // Tuần không mở bài mới (bài kéo dài nhiều tuần): bài gần nhất vẫn là bài của tuần này.
  if (cur.isEmpty) {
    final before = items.where((x) => x.wk < wk).toList();
    if (before.isNotEmpty && wk != 18) cur = [before.last];
  }
  final prev = items.where((x) => x.wk <= wk && !cur.contains(x)).toList();
  final next = items.where((x) => x.wk > wk).toList();
  return (cur: cur, prev: prev, next: next);
}

class Lop1Screen extends ConsumerStatefulWidget {
  const Lop1Screen({super.key});
  @override
  ConsumerState<Lop1Screen> createState() => _Lop1ScreenState();
}

class _Lop1ScreenState extends ConsumerState<Lop1Screen> {
  AudioService get audio => ref.read(audioProvider);

  @override
  void initState() {
    super.initState();
    if (!ref.read(classPlanProvider).available) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/map');
      });
    }
  }

  String _title(I18n i18n, ClassItem it) {
    if (it.key.startsWith('tv2w')) return clsT(i18n, 'clsWeek', {'n': it.wk});
    final b = it.json['b'];
    return b == null ? it.title : clsT(i18n, 'clsLesson', {'n': b});
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final plan = ref.watch(classPlanProvider);
    final i18n = ref.watch(i18nProvider);
    final p = store.profile;
    if (p == null || !plan.available) return const SizedBox();
    final wk = plan.classWeek(p);
    final items = plan.classItems(_classSubj);
    final g = classGroups(items, wk);
    ClassItem? firstTodo;
    for (final x in g.cur) {
      if (x.acts.isNotEmpty && !plan.itemDone(p, x)) {
        firstTodo = x;
        break;
      }
    }
    final fs = baseFontSize(context);

    Widget fold(String id, String label, List<ClassItem> list) {
      if (list.isEmpty) return const SizedBox();
      final open = _classOpen[id] == true;
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            key: Key('cls-fold-$id'),
            onTap: () {
              audio.sfx('tap');
              setState(() => _classOpen[id] = !open);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: const Color(0xBFFFFFFF), borderRadius: BorderRadius.circular(999)),
              child: Text('${open ? '▾ ' : '▸ '}$label (${list.length})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs, color: AppColors.ink)),
            ),
          ),
          if (open) Column(spacing: 14, children: [for (final it in list) _card(context, i18n, plan, p, it, false)]),
        ]),
      );
    }

    return AppScreen(
      scroll: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(
              leading: IconBtn(
                  icon: AppIcon.back,
                  label: 'Back',
                  onTap: () {
                    audio.sfx('tap');
                    context.go('/map');
                  }),
              title: clsT(i18n, 'clsTitle'),
              trailing: Pill(key: const Key('cls-week'), children: [const EmojiImage('School', size: 28, photo: false), Text(clsT(i18n, 'clsWeek', {'n': wk}))]),
            ),
            // Tab môn học
            Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 12, children: [
              for (final (id, name, ic, col) in [
                ('tv', clsT(i18n, 'clsTv'), 'Open book', const Color(0xFFFF6F91)),
                ('toan', clsT(i18n, 'clsToan'), 'Abacus', const Color(0xFF4DABF7)),
              ])
                Flexible(
                  child: Chunky(
                    key: Key('cls-tab-$id'),
                    radius: 22,
                    depth: 5,
                    color: id == _classSubj ? col : Colors.white,
                    shadowColor: id == _classSubj ? Color.lerp(col, Colors.black, .2)! : AppColors.line,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    onTap: () {
                      audio.sfx('tap');
                      setState(() => _classSubj = id);
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
                      EmojiImage(ic, size: 40, photo: false),
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.1, color: id == _classSubj ? Colors.white : AppColors.ink2)),
                      ),
                    ]),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
              child: Text(clsT(i18n, 'clsWeekNow', {'n': wk}),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.25, fontWeight: FontWeight.w800, color: AppColors.ink2)),
            ),
            if (g.cur.isNotEmpty)
              Column(spacing: 14, children: [for (final it in g.cur) _card(context, i18n, plan, p, it, it == firstTodo)])
            else
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(16)),
                  child: Text(clsT(i18n, wk == 18 || wk > 35 ? 'clsReview' : 'clsContinue'), textAlign: TextAlign.center),
                ),
              ),
            fold('prev', clsT(i18n, 'clsPrev'), g.prev.reversed.toList()),
            fold('next', clsT(i18n, 'clsNext'), g.next),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
              child: Column(children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(clsT(i18n, 'clsFoot'), textAlign: TextAlign.center, style: TextStyle(fontSize: fs * .85, color: const Color(0xFF5C6B7A))),
                ),
                const SizedBox(height: 10),
                AppButton(
                  key: const Key('cls-other-week'),
                  label: clsT(i18n, 'clsOtherWeek'),
                  variant: BtnVariant.ghost,
                  onTap: () async {
                    audio.sfx('tap');
                    if (await parentGate(context, ref) && mounted) _pickWeek(p);
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, I18n i18n, ClassPlan plan, Profile p, ClassItem it, bool now) {
    final done = plan.itemDone(p, it);
    final data = ref.read(appDataProvider);
    final content = ref.read(contentProvider);
    final fs = baseFontSize(context);
    return Container(
      key: Key('cls-card-${it.key}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xEBFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: now ? _kBlue : Colors.transparent, width: 3),
        boxShadow: [BoxShadow(color: now ? const Color(0xFFA5C8FF) : const Color(0x14000000), offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: 10, children: [
          Text(_title(i18n, it), style: TextStyle(fontSize: fs * 1.15, color: _kBlue, fontWeight: FontWeight.w800)),
          Expanded(child: Text(it.sub, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.1, color: AppColors.ink))),
          if (done) Text('✔', style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFF2B8A3E), fontSize: fs * 1.3)),
        ]),
        if (it.thin) Padding(padding: const EdgeInsets.only(top: 4), child: Text(clsT(i18n, 'clsThin'), style: TextStyle(fontSize: fs * .88, color: const Color(0xFF6C7A89)))),
        if (it.stories.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(clsT(i18n, 'clsStories'), style: TextStyle(fontSize: fs * .88, color: const Color(0xFF6C7A89)))),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final minW = (MediaQuery.sizeOf(context).width * .38).clamp(100.0, 140.0);
          final cols = (c.maxWidth / (minW + 10)).floor().clamp(1, 8);
          final w = (c.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in it.acts) SizedBox(width: w, child: _act(context, i18n, plan, data, content, p, a)),
          ]);
        }),
      ]),
    );
  }

  Widget _act(BuildContext context, I18n i18n, ClassPlan plan, AppData data, Content content, Profile p, (String, int) a) {
    final isl = data.island(a.$1);
    final col = isl?.color ?? _kBlue;
    final st = ref.read(storeProvider).levelStars(p, a.$1, a.$2);
    String img = isl?.img ?? 'School';
    if (isl != null) {
      final lv = levelsOf(isl, content);
      if (a.$2 >= 0 && a.$2 < lv.length && lv[a.$2].img != null) img = lv[a.$2].img!;
    }
    return Chunky(
      key: Key('cls-act-${a.$1}-${a.$2}'),
      radius: 18,
      depth: 4,
      color: st > 0 ? const Color(0xFFF4FFF6) : Colors.white,
      shadowColor: Color.lerp(col, Colors.white, .55)!,
      border: Border.all(color: Color.lerp(col, Colors.white, .7)!, width: 3),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      onTap: () {
        audio.sfx('tap');
        context.go('/play/${a.$1}/${a.$2}/lop1');
      },
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
        EmojiImage(img, size: 44, photo: false),
        Text(plan.actName(a, data, i18n.lang),
            textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * .92, height: 1.15)),
        StarRow(stars: st, size: baseFontSize(context)),
      ]),
    );
  }

  // Bố mẹ chọn tuần lớp đang học; app tự đi tiếp mỗi tuần từ mốc này.
  void _pickWeek(Profile p) {
    final plan = ref.read(classPlanProvider);
    final i18n = ref.read(i18nProvider);
    final wk = plan.classWeek(p);
    final tv = plan.classItems('tv');
    String label(int n) {
      final xs = tv.where((x) => x.wk == n && !x.sub.startsWith('Ôn tập')).toList();
      return xs.isNotEmpty ? xs.map((x) => x.sub).join(' · ') : n == 18 ? clsT(i18n, 'clsReviewHk1') : '';
    }

    final hasWk = asMap(p.json['cls'])['wk'] != null;
    showPanel<void>(
      context: context,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PanelTitle(clsT(i18n, 'clsPickTitle')),
          NoteText(clsT(i18n, 'clsPickNote')),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * .52),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: 35,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = i + 1;
                return GestureDetector(
                  key: Key('cls-wk-$n'),
                  onTap: () {
                    audio.sfx('tap');
                    plan.setClassWeek(p, n);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: n == wk ? const Color(0xFFD0E4FF) : const Color(0xFFF1F5FB), borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: 10, children: [
                      Text(clsT(i18n, 'clsWeek', {'n': n}), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Expanded(child: Text(label(n), textAlign: TextAlign.left, style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A)))),
                    ]),
                  ),
                );
              },
            ),
          ),
          PanelRow(children: [
            if (hasWk)
              AppButton(
                  label: clsT(i18n, 'clsSchedule'),
                  variant: BtnVariant.ghostPanel,
                  onTap: () {
                    plan.resetClassWeek(p);
                    Navigator.pop(ctx);
                  }),
            AppButton(label: i18n.t('cancel'), variant: BtnVariant.blue, onTap: () => Navigator.pop(ctx)),
          ]),
        ]);
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
