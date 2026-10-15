// Theo dõi học tập (port "Đợt 15" của app.js): quy mỗi câu hỏi về "mục" (tiếng, chữ cái, phép tính, từ tiếng Anh...)
// bằng cách tra ngược câu đọc trong voice.json; mốc tiến bộ; huy hiệu. Dùng bởi khung màn chơi, ôn tập, báo cáo bố mẹ.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/voice_data.dart';
import '../content/content.dart';
import '../content/levels.dart';
import '../i18n/i18n.dart';
import '../store/store.dart';
import 'game_module.dart';

const List<String> kRevSets = ['vnwords', 'twoWords', 'sentences', 'ruleWords', 'addFacts', 'subFacts', 'add100', 'sub100', 'add2d', 'sub2d'];
const List<String> kFactSets = ['addFacts', 'subFacts', 'add100', 'sub100', 'add2d', 'sub2d'];
const Map<String, List<int>> kMsSteps = {'w': [10, 25, 50, 100], 'e': [10, 25, 50, 100], 'm': [20, 50, 100]};

/// Tách "bộ:id" ở dấu ':' đầu tiên.
(String, String) splitKey(String k) {
  final i = k.indexOf(':');
  return i < 0 ? (k, '') : (k.substring(0, i), k.substring(i + 1));
}

String _js(Object? v) => v == null ? '' : (v is double && v == v.truncateToDouble() ? v.toInt().toString() : v.toString());

/// id của một mục trong bộ dữ liệu: id ?? ch ?? "a,b" ?? chỉ số.
String itemId(Json it, int i) {
  if (it['id'] != null) return _js(it['id']);
  if (it['ch'] != null) return _js(it['ch']);
  if (it['a'] != null && it['b'] != null) return '${_js(it['a'])},${_js(it['b'])}';
  return '$i';
}

class ItemInfo {
  const ItemInfo({required this.set, required this.label, this.img, this.it});
  final String set;
  final String label;
  final String? img;
  final Json? it;
}

class MilestoneInfo {
  const MilestoneInfo({required this.text, required this.img, required this.phrase});
  final String text;
  final String img;
  final String phrase;
}

/// Huy hiệu (BADGES của app.js). test(p) do BadgeRules tính.
class BadgeDef implements Localized {
  const BadgeDef(this.id, this.img, this.vi, this.en);
  final String id, img, vi, en;
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

const List<BadgeDef> kBadges = [
  BadgeDef('first', 'Glowing star', 'Bài đầu tiên', 'First level'),
  BadgeDef('r10', 'Sports medal', '10 lượt chơi', '10 rounds'),
  BadgeDef('r50', 'Trophy', '50 lượt chơi', '50 rounds'),
  BadgeDef('s100', 'Star', '100 ngôi sao', '100 stars'),
  BadgeDef('s300', 'Shooting star', '300 ngôi sao', '300 stars'),
  BadgeDef('streak3', 'Fire', '3 ngày liên tiếp', '3-day streak'),
  BadgeDef('streak7', 'Sparkles', '7 ngày liên tiếp', '7-day streak'),
  BadgeDef('abc', 'Books', 'Thuộc chữ cái', 'Letter master'),
  BadgeDef('writer', 'Pencil', 'Viết đẹp', 'Neat writer'),
  BadgeDef('math', 'Abacus', 'Nhà toán học', 'Math whiz'),
  BadgeDef('reader', 'Open book', 'Mọt sách', 'Bookworm'),
  BadgeDef('stickers', 'Rainbow', '15 hình dán', '15 stickers'),
  BadgeDef('explorer', 'Globe showing Asia-Australia', 'Nhà thám hiểm', 'Explorer'),
  BadgeDef('fashion', 'Crown', 'Thời trang', 'Fashionista'),
];

class LearnTracker {
  LearnTracker({required this.content, required this.data, required this.voice, required this.store});
  final Content content;
  final AppData data;
  final VoiceData voice;
  final AppStore store;
  Map<String, String>? _rev;

  /// Cấp đang xem theo đảo (tab trên màn danh sách bài). Khung màn chơi cập nhật.
  final Map<String, int> viewTier = {};

  // ---------- Tra ngược câu đọc → mục ----------
  Map<String, String> revIndex() {
    if (_rev != null) return _rev!;
    final m = <String, String>{};
    for (final set in kRevSets) {
      final arr = content.list(set);
      for (final tp in voice.templates.values) {
        if (!tp.forSets.contains(set)) continue;
        for (var i = 0; i < arr.length; i++) {
          final it = arr[i];
          final k = '${tp.lang}|${tp.text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (mm) => _js(it[mm[1]]))}';
          m.putIfAbsent(k, () => '$set:${itemId(it, i)}');
        }
      }
    }
    return _rev = m;
  }

  String? lookup(VoiceLine? say) => say == null ? null : revIndex()[say.key];

  ItemInfo? itemOf(String key) {
    final (set, id) = splitKey(key);
    if (set == 'tone') return ItemInfo(set: set, label: id == 'ngang' ? 'không dấu' : 'dấu $id');
    if (set == 'letters') {
      for (final l in content.list('letters')) {
        if (l['ch'] == id) return ItemInfo(set: set, label: id, img: l['img'] as String?, it: l);
      }
      return null;
    }
    final arr = content.list(set);
    for (var k = 0; k < arr.length; k++) {
      if (itemId(arr[k], k) != id) continue;
      final it = arr[k];
      final label = _js(it['w'] ?? it['t'] ?? it['en'] ?? (it['a'] != null ? '${_js(it['a'])} ${set.startsWith('sub') ? '−' : '+'} ${_js(it['b'])}' : id));
      return ItemInfo(set: set, label: label, img: it['img'] as String?, it: it);
    }
    return null;
  }

  static String skillOfSet(String set) =>
      set == 'letters' ? 'letters' : set.startsWith('en_') ? 'english' : kFactSets.contains(set) ? 'math' : 'spell';

  // ---------- Ghi câu hỏi ----------
  List<String> itemKeys(Island isl, Json? lv, QuizRecord q) {
    final keys = <String>[];
    if (isl.id == 'letters') {
      keys.add('letters:${_js(q.answer)}');
    } else if (isl.id == 'english' && lv?['set'] != null) {
      keys.add('${lv!['set']}:${_js(q.answer)}');
    } else {
      final k = lookup(q.say) ?? lookup(q.reward);
      if (k != null) keys.add(k);
    }
    if (isl.id == 'spell' && lv?['kind'] == 'tone') keys.add('tone:${_js(q.answer)}');
    return keys;
  }

  /// Loại cặp nhầm (để báo "con hay nhầm b/d"). Khuôn chọn hình (id vô nghĩa) thì không ghi.
  static String? confNs(Island isl, Json? lv) {
    if (isl.id == 'letters') return 'letters';
    if (isl.id == 'english') return lv?['set'] as String?;
    if (isl.id == 'spell' && lv != null) {
      final kind = lv['kind'];
      return kind == 'tone' ? 'tone' : ['onset', 'rime', 'build', 'rule'].contains(kind) ? 'spell' : null;
    }
    return null;
  }

  void recordQ(String skill, List<String> keys, String? ns, QuizRecord q) {
    final ok = q.picks.isEmpty;
    final conf = ns == null
        ? <String>[]
        : {...q.picks}.where((x) => x != q.answer && (x is String || x is num)).map((x) => '$ns|${_js(q.answer)}|${_js(x)}').toList();
    store.recordAnswer(skill, keys, ok, conf, q.ms);
  }

  /// Ghi một câu của bài đang chơi (g.record của web).
  void recordForLevel(Island isl, Json? lv, QuizRecord q) => recordQ(isl.id, itemKeys(isl, lv, q), confNs(isl, lv), q);

  // ---------- Mốc tiến bộ ----------
  int tierForIsland(Island isl, Profile p) => tierFor(isl, content, profileTier: p.tier, viewTier: viewTier[isl.id]);

  int masteredCount(Profile p, bool Function(String k) test) {
    final items = store.learn(p)['items'] as Json;
    var n = 0;
    items.forEach((k, v) {
      if (v is List && v.length > 4 && asInt(v[4]) != 0 && test(k)) n++;
    });
    return n;
  }

  static bool isEn(String k) => k.startsWith('en_');
  static bool isFact(String k) => kFactSets.contains(splitKey(k).$1);

  List<String> milestoneIds(Profile p) {
    final out = <String>[];
    final w = masteredCount(p, (k) => k.startsWith('vnwords:')), l = masteredCount(p, (k) => k.startsWith('letters:'));
    final e = masteredCount(p, isEn), m = masteredCount(p, isFact);
    for (final n in kMsSteps['w']!) {
      if (w >= n) out.add('w$n');
    }
    for (final n in kMsSteps['e']!) {
      if (e >= n) out.add('e$n');
    }
    for (final n in kMsSteps['m']!) {
      if (m >= n) out.add('m$n');
    }
    if (l >= 10) out.add('l10');
    if (l >= content.list('letters').length) out.add('lall');
    for (final isl in data.gameIslands) {
      final tier = tierForIsland(isl, p);
      final lv = tierLevels(isl, content, tier);
      if (lv.isNotEmpty && lv.every((x) => store.levelStars(p, isl.id, x.i) > 0)) out.add('i:${isl.id}:$tier');
    }
    return out;
  }

  MilestoneInfo msInfo(String id, String lang) {
    final m = RegExp(r'^([weml])(\d+|all)$').firstMatch(id);
    if (m != null) {
      final n = m[2]!;
      final txt = switch (m[1]) {
        'w' => 'Con đã đọc đúng $n tiếng!',
        'e' => 'Con đã thuộc $n từ tiếng Anh!',
        'm' => 'Con đã làm đúng $n phép tính!',
        _ => n == 'all' ? 'Con đã thuộc cả bảng chữ cái!' : 'Con đã nhận ra $n chữ cái!',
      };
      final pic = const {'w': 'Open book', 'e': 'Globe showing Asia-Australia', 'm': 'Abacus', 'l': 'Books'}[m[1]]!;
      return MilestoneInfo(text: txt, img: pic, phrase: 'ms_$id');
    }
    final parts = id.split(':');
    final iid = parts.length > 1 ? parts[1] : '';
    final tier = parts.length > 2 ? parts[2] : '0';
    final isl = data.island(iid);
    final tierTxt = tier != '0' ? ' (${tierOf(int.tryParse(tier)).textOf(lang)})' : '';
    return MilestoneInfo(text: 'Con đã học xong đảo ${isl?.textOf(lang) ?? iid}$tierTxt!', img: isl?.img ?? 'Trophy', phrase: 'ms_isl');
  }

  /// Hồ sơ cũ chưa có p.learn: tạo, ghi ngày bắt đầu theo dõi, đánh dấu sẵn các mốc đã đạt (không ăn mừng lại).
  Json ensureLearn(Profile p) {
    final l = store.learn(p);
    if (l['since'] == null) {
      l['since'] = store.today();
      final ms = l['ms'] as List;
      for (final id in milestoneIds(p)) {
        if (!ms.contains(id)) {
          ms.add(id);
          (l['msAt'] as Json)[id] = l['since'];
        }
      }
      store.save();
    }
    return l;
  }

  List<String> checkMilestones(Profile p) {
    ensureLearn(p);
    return store.addMilestones(milestoneIds(p));
  }

  // ---------- Ôn tập ----------
  bool reviewable(String k) {
    final s = splitKey(k).$1;
    return s == 'letters' || s == 'tone' || s.startsWith('en_') || kRevSets.contains(s);
  }

  int dueCount(Profile p) => store.dueItems(p).where(reviewable).length;

  // ---------- Huy hiệu ----------
  bool allDone(Profile p, String islandId) {
    final isl = data.island(islandId);
    if (isl == null) return false;
    return tierLevels(isl, content, tierForIsland(isl, p)).every((l) => store.levelStars(p, islandId, l.i) > 0);
  }

  bool badgeEarned(BadgeDef b, Profile p) => switch (b.id) {
        'first' => p.rounds >= 1,
        'r10' => p.rounds >= 10,
        'r50' => p.rounds >= 50,
        's100' => p.stars >= 100,
        's300' => p.stars >= 300,
        'streak3' => p.streakCount >= 3,
        'streak7' => p.streakCount >= 7,
        'abc' => allDone(p, 'letters'),
        'writer' => allDone(p, 'trace'),
        'math' => allDone(p, 'math'),
        'reader' => allDone(p, 'read'),
        'stickers' => p.stickers.length >= 15,
        'explorer' => data.gameIslands.every((i) => store.levelStars(p, i.id, 0) > 0),
        'fashion' => p.owned.length >= 3,
        _ => false,
      };
}

final learnTrackerProvider = Provider<LearnTracker>((ref) {
  final b = ref.watch(contentBundleProvider);
  return LearnTracker(content: b.content, data: b.data, voice: b.voice, store: ref.read(storeProvider));
});
