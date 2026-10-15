// Học cùng lớp (port phần dữ liệu của app.js: classWeek, classItems, classDone): lộ trình theo thứ tự bài sách Lớp 1
// (content.kntt). Dùng bởi màn Học cùng lớp (agent D) và khung màn chơi (bài tiếp / thưởng vé khi xong cả bài sách).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content.dart';
import '../content/levels.dart';
import '../store/store.dart';

/// Một "bài" của lộ trình: Tiếng Việt tập 1 (theo bài), tập 2 (theo tuần chủ đề), Toán (theo bài).
class ClassItem {
  ClassItem({required this.key, required this.title, required this.sub, required this.wk, required this.acts, required this.json});

  /// 'tv1', 'tv2w19', 'toan3'...
  final String key;
  final String title;
  final String sub;
  final int wk;

  /// Hoạt động: [đảo, chỉ số bài].
  final List<(String, int)> acts;
  final Json json;
  bool get thin => json['thin'] == true;
  List<String> get stories => asStrList(json['stories']);
}

DateTime _monday(DateTime d) {
  // Thứ Hai của tuần (12 giờ trưa để khỏi lệch giờ mùa hè).
  return DateTime(d.year, d.month, d.day - (d.weekday - 1), 12);
}

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ClassPlan {
  ClassPlan(this.content, this.store);
  final Content content;
  final AppStore store;

  Json get kntt => content.map('kntt');
  bool get available => content.has('kntt');

  /// Tuần hiện tại (1..35) = tuần bố mẹ chọn (p.cls.wk vào ngày p.cls.at) + số tuần đã qua; chưa chọn thì tính từ ngày khai giảng.
  int classWeek(Profile p, [DateTime? now]) {
    final today = _monday(now ?? store.now());
    final c = asMap(p.json['cls']);
    int wk;
    if (c['wk'] != null && c['at'] != null) {
      final at = _monday(DateTime.parse('${c['at']}T12:00:00'));
      wk = asInt(c['wk']) + (today.difference(at).inHours / (24 * 7)).round();
    } else {
      final start = _monday(DateTime.parse('${kntt['start'] ?? '2026-09-07'}T12:00:00'));
      wk = 1 + (today.difference(start).inHours / (24 * 7)).floor();
    }
    return wk.clamp(1, 35);
  }

  /// Bố mẹ chọn tuần lớp đang học; app tự đi tiếp mỗi tuần từ mốc này.
  void setClassWeek(Profile p, int wk) {
    p.json['cls'] = {...asMap(p.json['cls']), 'wk': wk, 'at': _ymd(_monday(store.now()))};
    store.save();
  }

  /// Bỏ tuần tự chọn, theo lịch năm học (giữ danh sách bài đã thưởng).
  void resetClassWeek(Profile p) {
    final d = asMap(p.json['cls'])['done'];
    p.json['cls'] = d == null ? <String, dynamic>{} : {'done': d};
    store.save();
  }

  static List<(String, int)> _acts(Object? v) => [
        for (final a in (v is List ? v : const []))
          if (a is List && a.length >= 2) (a[0].toString(), asInt(a[1])),
      ];

  /// subj: 'tv' (Tiếng Việt) | 'toan' (Toán).
  List<ClassItem> classItems(String subj) {
    final k = kntt;
    if (subj == 'toan') {
      return [
        for (final x in asMapList(k['toan'])) ClassItem(key: 'toan${x['b']}', title: 'Bài ${x['b']}', sub: asStr(x['name']), wk: asInt(x['wk']), acts: _acts(x['acts']), json: x),
      ];
    }
    return [
      for (final x in asMapList(k['tv'])) ClassItem(key: 'tv${x['b']}', title: 'Bài ${x['b']}', sub: asStr(x['name']), wk: asInt(x['wk']), acts: _acts(x['acts']), json: x),
      for (final x in asMapList(k['tv2'])) ClassItem(key: 'tv2w${x['wk']}', title: 'Tuần ${x['wk']}', sub: asStr(x['name']), wk: asInt(x['wk']), acts: _acts(x['acts']), json: x),
    ];
  }

  bool actDone(Profile p, (String, int) a) => store.levelStars(p, a.$1, a.$2) > 0;
  bool itemDone(Profile p, ClassItem it) => it.acts.isNotEmpty && it.acts.every((a) => actDone(p, a));

  /// Sau một hoạt động: hoạt động kế tiếp trong cùng bài, và phần thưởng khi vừa xong cả bài (+3 vé một lần).
  ({(String, int)? next, String? reward}) classDone(Profile p, String islId, int li) {
    for (final subj in ['tv', 'toan']) {
      ClassItem? it;
      for (final x in classItems(subj)) {
        if (x.acts.any((a) => a.$1 == islId && a.$2 == li)) {
          it = x;
          break;
        }
      }
      if (it == null) continue;
      (String, int)? next;
      for (final a in it.acts) {
        if (!actDone(p, a)) {
          next = a;
          break;
        }
      }
      String? reward;
      final cls = p.json['cls'] = asMap(p.json['cls']);
      final done = cls['done'] = asMap(cls['done']);
      if (itemDone(p, it) && done[it.key] == null) {
        done[it.key] = 1;
        if (store.funOn) store.addTickets(3);
        store.save();
        reward = '${subj == 'toan' ? 'Toán' : 'Tiếng Việt'} · ${it.title}';
      }
      return (next: next, reward: reward);
    }
    return (next: null, reward: null);
  }

  /// Tên ngắn của một hoạt động (bỏ tiền tố "Bài n: ").
  String actName((String, int) a, AppData data, String lang) {
    final isl = data.island(a.$1);
    if (isl == null) return a.$1;
    final lv = levelsOf(isl, content);
    if (a.$2 < 0 || a.$2 >= lv.length) return isl.textOf(lang);
    return lv[a.$2].name.textOf(lang).replaceFirst(RegExp(r'^Bài \d+: '), '');
  }
}

final classPlanProvider = Provider<ClassPlan>((ref) => ClassPlan(ref.watch(contentProvider), ref.read(storeProvider)));
