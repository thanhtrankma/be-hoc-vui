// Kết thúc một bài (finishRound() của app.js) + ăn mừng mốc tiến bộ (celebrate) + bằng khen (certificate).
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
import '../parents/certificate.dart';

/// Ghi kết quả và hiện bảng thưởng. onAgain: dựng lại bài (Chơi lại).
Future<void> finishRound(
  BuildContext context,
  WidgetRef ref, {
  required Island island,
  required int li,
  required int stars,
  String? from,
  required VoidCallback onAgain,
}) async {
  final store = ref.read(storeProvider);
  final data = ref.read(appDataProvider);
  final content = ref.read(contentProvider);
  final audio = ref.read(audioProvider);
  final tracker = ref.read(learnTrackerProvider);
  final i = ref.read(i18nProvider);
  final p = store.profile;
  if (p == null) return;

  final before = p.stars;
  final sticker = store.recordRound(island.id, li, stars, data.stickers);
  final dailyDone = store.dailyProgress(island.id);
  final funOn = store.funOn;
  final pet = p.pet;
  if (pet != null) {
    pet['happy'] = (asInt(pet['happy'], 50) + 8).clamp(0, 100);
    pet['xp'] = asInt(pet['xp']) + 5;
    p.json['pet'] = pet;
    store.save();
  }
  final tickets = store.ticketsPer + (dailyDone ? 2 : 0);
  if (funOn) store.addTickets(tickets);
  final unlocked = data.mascots.where((m) => m.stars > before && m.stars <= p.stars).toList();
  final badges = store.newBadges([for (final b in kBadges) if (tracker.badgeEarned(b, p)) b.id]).map((id) => kBadges.firstWhere((b) => b.id == id)).toList();
  final ms = tracker.checkMilestones(p);
  final due = tracker.dueCount(p);
  audio.sfx('win');
  confetti();
  audio.sayPhrase('roundDone');

  // Bài tiếp: bài sau trong cùng cấp đang xem. Học cùng lớp: hoạt động sau trong cùng bài sách (xong cả bài: +3 vé một lần).
  final list = tierLevels(island, content, tracker.tierForIsland(island, p));
  final cls = from == 'lop1' ? ref.read(classPlanProvider).classDone(p, island.id, li) : null;
  String? nextPath;
  if (cls != null) {
    final n = cls.next;
    nextPath = n == null ? null : '/play/${n.$1}/${n.$2}/lop1';
  } else {
    final k = list.indexWhere((l) => l.i == li);
    if (k >= 0 && k + 1 < list.length) nextPath = '/play/${island.id}/${list[k + 1].i}';
  }
  final homePath = cls != null ? '/lop1' : '/island/${island.id}';
  if (!context.mounted) return;

  void go(BuildContext c, String path) {
    Navigator.pop(c);
    context.go(path);
  }

  await showPanel<void>(
    context: context,
    builder: (c) => _ResultPanel(
      stars: stars,
      title: i.t('great'),
      onStarsDone: (panelMounted) async {
        await wait(1600);
        if (!panelMounted()) return;
        if (ms.isNotEmpty) {
          if (c.mounted) celebrate(c, ref, p, ms);
          return;
        }
        if (dailyDone) {
          audio.sayPhrase('dailyDone');
        } else if (badges.isNotEmpty) {
          audio.sayPhrase('badge');
        } else if (unlocked.isNotEmpty) {
          audio.sayPhrase('newMascot');
        } else if (sticker != null) {
          audio.sayPhrase('newSticker');
        }
      },
      prizes: [
        if (sticker != null) Prize(img: sticker, text: i.t('newSticker')),
        for (final m in unlocked) Prize(img: m.img, text: '${i.t('newBuddy')} ${i.L(m)}'),
        if (dailyDone) Prize(img: 'Fire', text: '${i.t('daily')} ✔ +5 ⭐'),
        if (pet != null) Prize(img: data.pet(pet['type'] as String?).img, text: i.t('petHappyLearn', {'name': pet['name']})),
        if (funOn) Prize(img: 'Admission tickets', text: i.t('gotTicket', {'n': tickets}), color: const Color(0xFFF3F0FF)),
        if (cls?.reward != null) Prize(img: 'Backpack', text: 'Xong ${cls!.reward}${funOn ? ' · +3 vé' : ''}'),
        for (final b in badges) Prize(img: b.img, text: '${i.t('badges')}: ${i.L(b)}'),
        for (final id in ms) Prize(img: tracker.msInfo(id, i.lang).img, text: '${tracker.msInfo(id, i.lang).text} 🏅', onTap: () => certificate(c, ref, p, id)),
        if (due >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Chunky(
              onTap: () => go(c, '/review'),
              color: const Color(0xFF845EF7),
              shadowColor: const Color(0xFF5F3DC4),
              depth: 4,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('🔁 Ôn nhanh $due chỗ hay nhầm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
      buttons: [
        AppButton(key: const Key('res-home'), icon: cls != null ? '🎒' : '🗺️', label: cls != null ? 'Bài học' : i.t('map'), variant: BtnVariant.ghostPanel, onTap: () => go(c, homePath)),
        AppButton(
          key: const Key('res-again'),
          icon: '🔄',
          label: i.t('again'),
          variant: BtnVariant.blue,
          onTap: () {
            Navigator.pop(c);
            onAgain();
          },
        ),
        if (nextPath != null) AppButton(key: const Key('res-next'), label: '${i.t('nextLevel')} ➜', variant: BtnVariant.green, onTap: () => go(c, nextPath!)),
      ],
    ),
  );
}

/// Bảng kết quả: tiêu đề, 3 sao sáng dần (380ms/sao + tiếng 'star'), phần thưởng, nút.
class _ResultPanel extends ConsumerStatefulWidget {
  const _ResultPanel({required this.stars, required this.prizes, required this.buttons, required this.title, required this.onStarsDone});
  final int stars;
  final List<Widget> prizes;
  final List<Widget> buttons;
  final String title;
  final Future<void> Function(bool Function() mounted) onStarsDone;
  @override
  ConsumerState<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends ConsumerState<_ResultPanel> {
  int lit = 0;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var k = 0; k < widget.stars; k++) {
      await wait(380);
      if (!mounted) return;
      setState(() => lit = k + 1);
      ref.read(audioProvider).sfx('star');
    }
    await widget.onStarsDone(() => mounted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(key: const Key('result-panel'), mainAxisSize: MainAxisSize.min, children: [
      PanelTitle(widget.title),
      BigStars(lit: lit),
      ...widget.prizes,
      PanelRow(children: widget.buttons),
    ]);
  }
}

/// Ăn mừng mốc tiến bộ mới (celebrate() của app.js).
void celebrate(BuildContext context, WidgetRef ref, Profile p, List<String> ids) {
  if (ids.isEmpty) return;
  final tracker = ref.read(learnTrackerProvider);
  final i = ref.read(i18nProvider);
  final main = ids.last;
  final info = tracker.msInfo(main, i.lang);
  confetti(n: 140);
  ref.read(audioProvider).sfx('win');
  ref.read(audioProvider).sayPhrase(info.phrase);
  showPanel<void>(
    context: context,
    builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Hop(child: const EmojiImage('Trophy', size: 110, photo: false)),
        EmojiImage(info.img, size: 90, photo: false),
      ]),
      PanelTitle('🎉 ${i.t('great')}'),
      for (final id in ids) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tracker.msInfo(id, i.lang).text, style: const TextStyle(fontWeight: FontWeight.w800))),
      PanelRow(children: [
        AppButton(label: '${i.t('next')} ➜', variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(c)),
        AppButton(
          icon: '🏅',
          label: 'Bằng khen',
          variant: BtnVariant.green,
          onTap: () {
            Navigator.pop(c);
            certificate(context, ref, p, main);
          },
        ),
      ]),
    ]),
  );
}

/// Bằng khen có tên bé (certificate() của app.js): ảnh PNG 1080×1350 như web, xem features/parents/certificate.dart.
/// parent = true khi mở từ Báo cáo (đã qua khoá bố mẹ).
void certificate(BuildContext context, WidgetRef ref, Profile p, String id, {bool parent = false}) {
  showCertificate(context, ref, p, id, parent: parent);
}
