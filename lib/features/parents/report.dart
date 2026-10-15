// Báo cáo của con (/report/<id>): 7 ngày, kỹ năng, chỗ hay nhầm, mốc tiến bộ & bằng khen. Dữ liệu: store.learn(p), LearnTracker.
// CHỦ: agent I. Port của reference/web/js/app.js report() (+ skillRows, weakList, nextGoal).
// Đã qua khoá bố mẹ trước khi vào (từ Góc bố mẹ).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'certificate.dart';

int? pct(int r, int w) => r + w > 0 ? (r / (r + w) * 100).round() : null;
String toneName(String x) => x == 'ngang' ? 'không dấu' : 'dấu $x';
const List<String> kWeekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/// Một dòng "Con đã học được gì".
class SkillRow {
  SkillRow({required this.id, required this.img, required this.color, required this.name, required this.main, this.frac, this.acc, this.extra});
  final String id, img, name, main;
  final Color color;
  final double? frac;
  final String? acc, extra;
}

/// Một chỗ hay nhầm (cặp nhầm hoặc mục cần ôn).
class WeakItem {
  WeakItem({required this.text, required this.n, this.key, this.img, this.conf = false});
  final String text;
  final int n;
  final String? key, img;
  final bool conf;
}

/// Một ngày trong biểu đồ 7 ngày.
class DayStat {
  DayStat({required this.wd, required this.date, required this.min, required this.les, required this.stars, required this.newM});
  final String wd;
  final int date, min, les, stars, newM;
}

/// Tính số liệu báo cáo (thuần, test được).
class ReportModel {
  ReportModel({required this.store, required this.tracker, required this.content, required this.data, required this.lang});
  final AppStore store;
  final LearnTracker tracker;
  final Content content;
  final AppData data;
  final String lang;

  List<DayStat> days(Profile p) {
    final l = store.learn(p);
    final now = store.now();
    return [
      for (var k = 6; k >= 0; k--)
        () {
          final d = now.subtract(Duration(days: k));
          final key = AppStore.dayKey(d);
          final dd = l['days'][key] is List ? (l['days'][key] as List) : const [0, 0, 0, 0, 0];
          return DayStat(
            wd: k == 0 ? 'Nay' : kWeekDays[d.weekday % 7],
            date: d.day,
            min: (asInt(p.usage[key]) / 60).round(),
            les: asInt(dd[0]),
            stars: asInt(dd[1]),
            newM: dd.length > 4 ? asInt(dd[4]) : 0,
          );
        }(),
    ];
  }

  String _factGroup(String key) {
    final (set, id) = splitKey(key);
    if (set != 'addFacts' && set != 'subFacts') return 'f100';
    final ab = id.split(',').map((x) => num.tryParse(x) ?? 0).toList();
    final a = ab.isNotEmpty ? ab[0] : 0, b = ab.length > 1 ? ab[1] : 0;
    return (set == 'addFacts' ? a + b : a) <= 10 ? 'f10' : 'f20';
  }

  List<SkillRow> skillRows(Profile p) {
    final l = store.learn(p);
    final items = l['items'] as Json, sk = l['skills'] as Json;
    ({int r, int w, int n, int m}) sum(bool Function(String k) test) {
      var r = 0, w = 0, n = 0, m = 0;
      items.forEach((k, v) {
        if (v is! List || !test(k)) return;
        r += asInt(v[0]);
        w += asInt(v[1]);
        n++;
        if (v.length > 4 && asInt(v[4]) != 0) m++;
      });
      return (r: r, w: w, n: n, m: m);
    }

    String accTxt(List<int> s) => pct(s[0], s[1]) == null ? '' : '${pct(s[0], s[1])}% đúng ngay · ${s[0] + s[1]} câu';
    List<int> S(String id) {
      final v = sk[id];
      return v is List ? [asInt(v[0]), asInt(v.length > 1 ? v[1] : 0), asInt(v.length > 2 ? v[2] : 0)] : [0, 0, 0];
    }

    final rows = <SkillRow>[];
    void add(String id, String name, String main, double? frac, String? acc, [String? extra]) {
      final isl = data.island(id);
      rows.add(SkillRow(id: id, img: isl?.img ?? 'Star', color: isl?.color ?? AppColors.blue, name: name, main: main, frac: frac, acc: acc, extra: extra));
    }

    String nameOf(String id) => data.island(id)?.textOf(lang) ?? id;
    final nLetters = content.list('letters').length;
    final l1 = sum((k) => k.startsWith('letters:'));
    if (l1.n > 0 || S('letters')[0] + S('letters')[1] > 0) {
      add('letters', nameOf('letters'), 'Nhận ra ${l1.m}/$nLetters chữ cái', nLetters == 0 ? null : l1.m / nLetters, accTxt(S('letters')));
    }
    final w = sum((k) => k.startsWith('vnwords:')), t = sum((k) => k.startsWith('tone:'));
    if (w.n > 0 || S('spell')[0] + S('spell')[1] > 0) {
      final weakTone = items.entries
          .where((e) => e.key.startsWith('tone:') && e.value is List && asInt(e.value[1]) > asInt(e.value[0]) / 3 && asInt(e.value[1]) >= 2)
          .map((e) => toneName(splitKey(e.key).$2))
          .toList();
      final nW = content.list('vnwords').length;
      add(
        'spell',
        nameOf('spell'),
        'Đọc đúng ${w.m}/$nW tiếng',
        nW == 0 ? null : w.m / nW,
        accTxt(S('spell')),
        t.n > 0 ? 'Dấu thanh: ${pct(t.r, t.w)}% đúng${weakTone.isNotEmpty ? ' · còn nhầm ${weakTone.join(', ')}' : ''}' : null,
      );
    }
    final r2 = sum((k) => k.startsWith('twoWords:')), rs = sum((k) => k.startsWith('sentences:'));
    if (r2.n > 0 || rs.n > 0 || S('read')[0] + S('read')[1] > 0) {
      add('read', nameOf('read'), 'Đọc hiểu ${r2.m} từ, ${rs.m} câu', null, accTxt(S('read')));
    }
    const groups = {'f10': 'Cộng trừ trong 10', 'f20': 'Cộng trừ đến 20', 'f100': 'Cộng trừ đến 100'};
    final mathLines = <String>[];
    groups.forEach((g, name) {
      final s = sum((k) => LearnTracker.isFact(k) && _factGroup(k) == g);
      if (s.r + s.w > 0) mathLines.add('$name: ${pct(s.r, s.w)}% đúng (${s.r + s.w} câu)');
    });
    final f = sum(LearnTracker.isFact);
    if (f.n > 0 || S('math')[0] + S('math')[1] > 0) {
      add(
        'math',
        nameOf('math'),
        mathLines.isNotEmpty ? mathLines.first : 'Làm đúng ${f.m} phép tính',
        null,
        accTxt(S('math')),
        mathLines.length > 1 ? mathLines.skip(1).join(' · ') : null,
      );
    }
    final e = sum(LearnTracker.isEn);
    final enSets = content.list('englishLevels').map((x) => x['set']).whereType<String>().toSet();
    final enTotal = enSets.fold<int>(0, (n, s) => n + content.list(s).length);
    if (e.n > 0 || S('english')[0] + S('english')[1] > 0) {
      add('english', nameOf('english'), 'Thuộc ${e.m}/$enTotal từ tiếng Anh', enTotal == 0 ? null : e.m / enTotal, accTxt(S('english')));
    }
    // Các đảo còn lại: chỉ tỉ lệ đúng.
    for (final i in data.gameIslands) {
      if (const ['letters', 'spell', 'read', 'math', 'english'].contains(i.id)) continue;
      final s = S(i.id);
      if (s[0] + s[1] > 0) {
        add(
          i.id,
          i.textOf(lang),
          '${pct(s[0], s[1])}% đúng ngay',
          pct(s[0], s[1])! / 100,
          '${s[0] + s[1]} câu · ~${max(1, (s[2] / (s[0] + s[1]) / 1000).round())} giây/câu',
        );
      }
    }
    return rows;
  }

  String confLabel(String ns, String x) {
    if (ns == 'tone') return toneName(x);
    if (ns.startsWith('en_')) {
      for (final e in content.list(ns)) {
        if ('${e['id']}' == x) return '${e['en'] ?? x}';
      }
    }
    return x;
  }

  List<WeakItem> weakList(Profile p) {
    final l = store.learn(p);
    // Gộp hai chiều (b→d và d→b là một cặp "b ↔ d").
    final pairs = <String, ({String ns, String a, String b, int n, int top})>{};
    (l['conf'] as Json).forEach((k, v) {
      final parts = k.split('|');
      if (parts.length < 3) return;
      final ns = parts[0], a = parts[1], b = parts[2], n = asInt(v);
      final ab = [a, b]..sort();
      final id = '$ns|${ab.join('|')}';
      final cur = pairs[id] ?? (ns: ns, a: a, b: b, n: 0, top: 0);
      final better = n > cur.top;
      pairs[id] = (ns: ns, a: better ? a : cur.a, b: better ? b : cur.b, n: cur.n + n, top: better ? n : cur.top);
    });
    final sorted = pairs.values.where((x) => x.n >= 2).toList()..sort((x, y) => y.n - x.n);
    final conf = sorted.take(6).map((x) {
      final key = x.ns == 'letters'
          ? 'letters:${x.a}'
          : x.ns == 'tone'
          ? 'tone:${x.a}'
          : x.ns.startsWith('en_')
          ? '${x.ns}:${x.a}'
          : null;
      return WeakItem(text: '${confLabel(x.ns, x.a)} ↔ ${confLabel(x.ns, x.b)}', n: x.n, key: key, conf: true);
    }).toList();
    final inConf = conf.map((x) => x.key).toSet();
    final items = l['items'] as Json;
    final due = store.dueItems(p, all: true).where((k) => tracker.reviewable(k) && !inConf.contains(k)).take(10);
    final out = <WeakItem>[...conf];
    for (final k in due) {
      final info = tracker.itemOf(k);
      if (info == null) continue;
      out.add(WeakItem(text: info.label, img: info.img, n: asInt((items[k] as List)[1]), key: k));
    }
    return out;
  }

  String? nextGoal(Profile p) {
    final w = tracker.masteredCount(p, (k) => k.startsWith('vnwords:')), e = tracker.masteredCount(p, LearnTracker.isEn);
    final m = tracker.masteredCount(p, LearnTracker.isFact);
    int? next(String k, int have) {
      for (final n in kMsSteps[k]!) {
        if (n > have) return n;
      }
      return null;
    }

    final nw = next('w', w), ne = next('e', e), nm = next('m', m);
    final opts = <(int, String)>[
      if (nw != null) (nw - w, 'đọc đúng $nw tiếng'),
      if (nm != null) (nm - m, 'làm đúng $nm phép tính'),
      if (ne != null) (ne - e, 'thuộc $ne từ tiếng Anh'),
    ]..sort((a, b) => a.$1 - b.$1);
    return opts.isEmpty ? null : 'Còn ${opts.first.$1} nữa là con ${opts.first.$2}.';
  }

  /// Mốc đã đạt, mới nhất trước.
  List<String> milestones(Profile p) {
    final l = store.learn(p);
    final at = l['msAt'] as Json;
    final ms = asStrList(l['ms']).reversed.toList();
    // sort ổn định như Array.prototype.sort của web
    final idx = {for (var k = 0; k < ms.length; k++) ms[k]: k};
    ms.sort((a, b) {
      final c = '${at[b] ?? ''}'.compareTo('${at[a] ?? ''}');
      return c != 0 ? c : idx[a]! - idx[b]!;
    });
    return ms;
  }
}

final reportModelProvider = Provider<ReportModel>((ref) {
  final b = ref.watch(contentBundleProvider);
  return ReportModel(
    store: ref.watch(storeProvider),
    tracker: ref.watch(learnTrackerProvider),
    content: b.content,
    data: b.data,
    lang: ref.watch(i18nProvider).lang,
  );
});

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.kidId});
  final String kidId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final i = ref.watch(i18nProvider);
    final p = store.profileById(kidId);
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/parent');
      });
      return const AppScreen(child: SizedBox());
    }
    final model = ref.watch(reportModelProvider);
    final l = store.learn(p);
    final days = model.days(p);
    final td = days.last;
    final wk = (
      min: days.fold<int>(0, (a, d) => a + d.min),
      les: days.fold<int>(0, (a, d) => a + d.les),
      stars: days.fold<int>(0, (a, d) => a + d.stars),
      newM: days.fold<int>(0, (a, d) => a + d.newM),
      on: days.where((d) => d.min > 0 || d.les > 0).length,
    );
    final maxMin = max(10, days.map((d) => d.min).reduce(max));
    final rows = model.skillRows(p), weak = model.weakList(p), ms = model.milestones(p);
    final goal = model.nextGoal(p);
    final summary = wk.on > 0
        ? 'Tuần này ${p.name} học ${wk.on}/7 ngày, ${wk.min} phút, ${wk.les} bài${wk.newM > 0 ? ', thạo thêm ${wk.newM} mục mới' : ''}.'
        : '${p.name} chưa học tuần này.';
    final tracker = ref.read(learnTrackerProvider);

    void practice(String path) {
      ref.read(audioProvider).sfx('tap');
      store.setActive(p.id);
      context.go(path);
    }

    return AppScreen(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          TopBar(
            leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                context.go('/parent');
              },
            ),
            title: '📊 Báo cáo của ${p.name}',
          ),
          // ----- Tổng quan -----
          CardBox(
            key: const Key('rp-hero'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Row(
                  spacing: 14,
                  children: [
                    Dressed(profile: p, size: 84),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(summary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          Text(
                            '${tierOf(p.tier).textOf(i.lang)} · ⭐ ${p.stars} sao · 🔥 ${p.streakCount} ngày liên tiếp',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                          if (goal != null)
                            Text(
                              '🎯 $goal',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TileGroup(title: 'Hôm nay', tiles: [('⏱️', td.min, 'phút'), ('📚', td.les, 'bài'), ('⭐', td.stars, 'sao')]),
                    _TileGroup(title: '7 ngày qua', tiles: [('⏱️', wk.min, 'phút'), ('📚', wk.les, 'bài'), ('⭐', wk.stars, 'sao')]),
                  ],
                ),
              ],
            ),
          ),
          // ----- 7 ngày -----
          _Section(
            title: '📅 7 ngày qua',
            children: [
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              d.min > 0 ? '${d.min}′' : '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Container(
                                  alignment: Alignment.bottomCenter,
                                  decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(10)),
                                  child: FractionallySizedBox(
                                    heightFactor: d.min / maxMin,
                                    widthFactor: 1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: identical(d, td) ? AppColors.primary : AppColors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              d.wd,
                              style: TextStyle(fontWeight: FontWeight.w800, color: identical(d, td) ? AppColors.primaryDark : AppColors.ink),
                            ),
                            Text(d.les > 0 ? '${d.les} bài' : '·', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const NoteText('Cột: số phút học mỗi ngày. Dưới cột: số bài đã làm.', textAlign: TextAlign.start),
            ],
          ),
          // ----- Kỹ năng -----
          _Section(
            title: '🧠 Con đã học được gì',
            children: [
              if (rows.isEmpty) const NoteText('Chưa có số liệu. Cho bé chơi vài bài, báo cáo sẽ hiện ở đây.', textAlign: TextAlign.start),
              for (final r in rows) _SkillTile(row: r),
              NoteText(
                '"Đúng ngay" = chọn đúng ở lần chạm đầu. Số liệu theo dõi từ ${fmtDate(l['since'] as String? ?? store.today())}.',
                textAlign: TextAlign.start,
              ),
            ],
          ),
          // ----- Hay nhầm -----
          _Section(
            title: '🔎 Con hay nhầm',
            children: [
              if (weak.isEmpty) const NoteText('Chưa thấy chỗ nào con nhầm nhiều lần. Tuyệt!', textAlign: TextAlign.start),
              if (weak.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final x in weak)
                      Chunky(
                        key: ValueKey('weak-${x.text}'),
                        depth: 3,
                        radius: 16,
                        color: x.conf ? const Color(0xFFFFF0E8) : Colors.white,
                        border: Border.all(color: AppColors.line, width: 2),
                        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                        semanticLabel: 'Luyện riêng mục này',
                        onTap: x.key == null ? null : () => practice('/review/x/${Uri.encodeComponent(x.key!)}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            if (x.img != null) EmojiImage(x.img!, size: 30, photo: false),
                            // Câu dài (xếp câu, đọc câu) xuống dòng trong thẻ thay vì tràn ngang.
                            Flexible(child: Text(x.text, style: const TextStyle(fontWeight: FontWeight.w800))),
                            Text('sai ${x.n} lần', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppButton(
                      key: const Key('rp-practice'),
                      icon: '▶',
                      label: 'Luyện lại cho ${p.name}',
                      variant: BtnVariant.green,
                      onTap: () => practice('/review/all'),
                    ),
                  ),
                ),
                const NoteText(
                  'Bấm "Luyện lại" rồi đưa máy cho bé: bé làm một bài ôn ngắn đúng những chỗ này. Các chỗ sai cũng tự hỏi lại sau 1, 3, 7 ngày (nút 🔁 trên bản đồ).',
                  textAlign: TextAlign.start,
                ),
              ],
            ],
          ),
          // ----- Mốc tiến bộ -----
          _Section(
            title: '🏅 Mốc tiến bộ & bằng khen',
            children: [
              if (ms.isEmpty)
                const NoteText('Chưa có mốc nào. Mốc đầu tiên: đọc đúng 10 tiếng, nhận ra 10 chữ cái hoặc làm đúng 20 phép tính.', textAlign: TextAlign.start),
              for (final id in ms)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chunky(
                    key: ValueKey('ms-$id'),
                    depth: 3,
                    radius: 18,
                    border: Border.all(color: AppColors.line, width: 2),
                    padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                    onTap: () => showCertificate(context, ref, p, id, parent: true),
                    child: Row(
                      spacing: 10,
                      children: [
                        EmojiImage(tracker.msInfo(id, i.lang).img, size: 44, photo: false),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tracker.msInfo(id, i.lang).text, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                fmtDate(asMap(l['msAt'])[id] as String?),
                                style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.inkSoft, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Text('🏅', style: TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => CardBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: baseFontSize(context) * 1.25, fontWeight: FontWeight.w800, color: AppColors.ink2),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.title, required this.tiles});
  final String title;
  final List<(String, int, String)> tiles;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(18)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (final (ic, n, label) in tiles)
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Text(ic),
                      Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.row});
  final SkillRow row;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: row.color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      border: Border(left: BorderSide(color: row.color, width: 5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        EmojiImage(row.img, size: 44, photo: false),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(row.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (row.acc != null && row.acc!.isNotEmpty) Text(row.acc!, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
              Text(row.main),
              if (row.frac != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: (row.frac!.clamp(.02, 1.0)).toDouble(), minHeight: 10, color: row.color, backgroundColor: Colors.white),
                ),
              if (row.extra != null) Text(row.extra!, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ],
    ),
  );
}
