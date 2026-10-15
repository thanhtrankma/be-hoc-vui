// Port của js/store.js: hồ sơ các bé + cài đặt, lưu trên máy (shared_preferences, khoá 'bvh.v1').
// Định dạng JSON GIỮ NGUYÊN như localStorage của web, để sao lưu và đồng bộ (sync) dùng chung với bản web.
// Mọi đọc/ghi bọc try/catch: lỗi lưu thì app vẫn chạy, chỉ không nhớ.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/models.dart';
import 'profile.dart';

export 'profile.dart';

const String kStoreKey = 'bvh.v1';

/// Cài đặt mặc định (giống DEFAULTS của web).
const Map<String, dynamic> kDefaultSettings = {
  'lang': 'vi', 'music': true, 'sound': true, 'limit': 20, 'fun': true, 'ticketsPer': 1, 'lockOrder': false,
};

/// Số cấp mỗi game ở Khu vui chơi (trùng MAX_LV của funcore).
const int kFunMax = 60;

class AppStore extends ChangeNotifier {
  AppStore(this._prefs, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _rnd = random ?? Random() {
    _s = _load();
  }

  final SharedPreferences? _prefs;
  final DateTime Function() _clock;
  final Random _rnd;
  late Json _s;

  /// Gọi sau mỗi lần lưu (sync.js dùng để biết có thay đổi cần đẩy lên). Agent I gắn vào đây.
  VoidCallback? onSave;

  DateTime now() => _clock();
  int get _nowMs => _clock().millisecondsSinceEpoch;

  // ---------- Nạp / lưu ----------
  Json _load() {
    try {
      final txt = _prefs?.getString(kStoreKey);
      if (txt != null) {
        final s = jsonDecode(txt);
        if (s is Map && s['profiles'] is List) {
          return {
            'profiles': asMapList(s['profiles']),
            'active': s['active'],
            'settings': {...kDefaultSettings, ...asMap(s['settings'])},
            'gone': asMap(s['gone']),
            'smt': s['smt'] ?? 0,
          };
        }
      }
    } catch (_) {/* bỏ qua: dữ liệu hỏng thì bắt đầu mới */}
    return {'profiles': <Json>[], 'active': null, 'settings': {...kDefaultSettings}, 'gone': <String, dynamic>{}, 'smt': 0};
  }

  void _rawSave() {
    try {
      _prefs?.setString(kStoreKey, jsonEncode(_s));
    } catch (_) {/* bỏ qua */}
  }

  /// Lưu: đóng dấu giờ sửa (mt) lên hồ sơ đang chơi, ghi máy, báo widget vẽ lại.
  void save() {
    final p = profile;
    if (p != null) p.json['mt'] = _nowMs;
    _rawSave();
    onSave?.call();
    notifyListeners();
  }

  /// Toàn bộ trạng thái thô (JSON) — chỉ đọc, dùng cho debug/test.
  Json get raw => _s;

  // ---------- Kho khoá/giá trị phụ (thay các khoá localStorage khác của web: 'bvh.sync', 'bvh.micOK'...) ----------
  String? getKv(String key) {
    try {
      return _prefs?.getString(key);
    } catch (_) {
      return null;
    }
  }

  void setKv(String key, String? value) {
    try {
      if (value == null) {
        _prefs?.remove(key);
      } else {
        _prefs?.setString(key, value);
      }
    } catch (_) {/* bỏ qua */}
  }

  // ---------- Cài đặt ----------
  Json get settings => _s['settings'] as Json;
  void setSetting(String k, Object? v) {
    settings[k] = v;
    _s['smt'] = _nowMs;
    save();
  }

  String get lang => settings['lang'] == 'en' ? 'en' : 'vi';
  bool get soundOn => settings['sound'] != false;
  bool get musicOn => settings['music'] != false;
  bool get funOn => settings['fun'] != false;
  bool get lockOrder => settings['lockOrder'] == true;
  int get ticketsPer => asInt(settings['ticketsPer'], 1);
  int get limitMinutes => asInt(settings['limit']);

  // ---------- Hồ sơ ----------
  List<Profile> get profiles => (_s['profiles'] as List).map((e) => Profile(e as Json)).toList();
  String? get activeId => _s['active'] as String?;
  Profile? get profile {
    for (final p in _s['profiles'] as List) {
      if ((p as Json)['id'] == _s['active']) return Profile(p);
    }
    return null;
  }

  Profile? profileById(String id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Chỉ đổi bé đang chơi: không đóng dấu sửa hồ sơ.
  void setActive(String? id) {
    _s['active'] = id;
    _rawSave();
    notifyListeners();
  }

  Profile addProfile(String name, String? mascot) {
    final id = _nowMs.toRadixString(36) + _rnd.nextInt(1 << 20).toRadixString(36).padLeft(4, '0').substring(0, 4);
    final p = <String, dynamic>{
      'id': id, 'name': name, 'mascot': mascot, 'stars': 0, 'rounds': 0, 'stickers': <String>[], 'levels': <String, dynamic>{},
      'usage': <String, dynamic>{}, 'bonus': <String, dynamic>{}, 'created': _nowMs,
    };
    (_s['profiles'] as List).add(p);
    _s['active'] = id;
    save();
    return Profile(p);
  }

  void updateProfile(String id, Map<String, dynamic> fields) {
    final p = profileById(id);
    if (p == null) return;
    p.json.addAll(fields);
    p.json['mt'] = _nowMs;
    save();
  }

  void removeProfile(String id) {
    (_s['profiles'] as List).removeWhere((p) => (p as Json)['id'] == id);
    _s['gone'] = {...asMap(_s['gone']), id: _nowMs};
    if (_s['active'] == id) _s['active'] = profiles.isEmpty ? null : profiles.first.id;
    save();
  }

  int levelStars(Profile p, String island, int i) => asInt(p.levels['$island:$i']);

  /// Ghi kết quả một lượt chơi. Sao cộng dồn mỗi lượt (chơi lại = luyện thêm), bài chỉ giữ số sao cao nhất.
  /// Trả về hình dán mới (ngẫu nhiên trong stickerPool chưa có) hoặc null.
  String? recordRound(String island, int i, int stars, List<String> stickerPool) {
    final p = profile;
    if (p == null) return null;
    final key = '$island:$i';
    p.levels[key] = max(asInt(p.levels[key]), stars);
    p.stars += stars;
    p.rounds += 1;
    _logDay(p, 1, stars);
    final left = stickerPool.where((s) => !p.stickers.contains(s)).toList();
    final sticker = left.isEmpty ? null : left[_rnd.nextInt(left.length)];
    if (sticker != null) p.stickers.add(sticker);
    save();
    return sticker;
  }

  // YYYY-MM-DD theo giờ máy.
  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String today() => dayKey(_clock());

  void addUsage(int seconds) {
    final p = profile;
    if (p == null) return;
    final d = today();
    p.usage[d] = asInt(p.usage[d]) + seconds;
    final keys = p.usage.keys.toList()..sort();
    while (keys.length > 60) {
      p.usage.remove(keys.removeAt(0));
    }
    save();
  }

  /// Hết giờ chơi hôm nay chưa (giới hạn + phút bố mẹ cho thêm).
  bool overLimit() {
    final p = profile;
    final lim = limitMinutes;
    if (p == null || lim == 0) return false;
    final d = today();
    return asInt(p.usage[d]) >= (lim + asInt(p.bonus[d])) * 60;
  }

  void addBonus(int minutes) {
    final p = profile;
    if (p == null) return;
    final d = today();
    p.json['bonus'] = {d: asInt(p.bonus[d]) + minutes};
    save();
  }

  String exportData() =>
      jsonEncode({'app': 'be-vui-hoc', 'version': 1, 'exported': _clock().toUtc().toIso8601String(), 'data': _s});

  /// Khôi phục từ file sao lưu (định dạng web). Sai file → ném FormatException.
  void importData(String text) {
    final obj = jsonDecode(text);
    final d = obj is Map && obj['app'] == 'be-vui-hoc' ? obj['data'] : null;
    if (d is! Map || d['profiles'] is! List) throw const FormatException('bad file');
    final profs = asMapList(d['profiles']);
    _s = {
      'profiles': profs,
      'active': d['active'] ?? (profs.isEmpty ? null : profs.first['id']),
      'settings': {...kDefaultSettings, ...asMap(d['settings'])},
      'gone': <String, dynamic>{},
      'smt': _nowMs,
    };
    _rawSave();
    onSave?.call();
    notifyListeners();
  }

  // ---------- Phòng của bé: ví sao (sao kiếm được trừ sao đã tiêu), đồ đã mua, đồ đang đeo ----------
  int wallet(Profile p) => p.stars - p.spent;
  bool buy(WardrobeItem item) {
    final p = profile;
    if (p == null || wallet(p) < item.price) return false;
    p.spent = p.spent + item.price;
    p.json['owned'] = [...p.owned, item.id];
    equip(item.slot, item.id);
    return true;
  }

  void equip(String slot, String? id) {
    final p = profile;
    if (p == null) return;
    final o = {...p.outfit, slot: id};
    if (id == null) o.remove(slot);
    p.json['outfit'] = o;
    save();
  }

  // ---------- Thử thách hằng ngày: 3 đảo chọn theo ngày (cùng thuật toán băm với web), chuỗi ngày liên tiếp ----------
  /// Thử thách của hôm nay nếu đã tạo (không ghi gì — gọi được trong build). Chưa có thì gọi daily() sau khung hình.
  Json? peekDaily() {
    final d = profile?.json['daily'];
    return d is Map && d['date'] == today() ? d.cast<String, dynamic>() : null;
  }

  Json daily(List<String> islandIds) {
    final p = profile!;
    final d = today();
    final cur = p.json['daily'];
    if (cur is! Map || cur['date'] != d) {
      final rnd = seededRandom(d + p.id);
      final pool = [...islandIds];
      final tasks = <String>[];
      while (tasks.length < 3 && pool.isNotEmpty) {
        tasks.add(pool.removeAt((rnd() * pool.length).floor()));
      }
      p.json['daily'] = <String, dynamic>{'date': d, 'tasks': tasks, 'done': <String>[], 'claimed': false};
      save();
    }
    return (p.json['daily'] as Map).cast<String, dynamic>();
  }

  /// Ghi nhận một lượt chơi cho thử thách. Trả về true nếu vừa hoàn thành đủ 3 nhiệm vụ (+5 sao, tăng chuỗi ngày).
  bool dailyProgress(String islandId) {
    final p = profile;
    if (p == null) return false;
    final dl = p.json['daily'];
    if (dl is! Map || dl['date'] != today() || dl['claimed'] == true) return false;
    final tasks = asStrList(dl['tasks']);
    final done = asStrList(dl['done']);
    if (tasks.contains(islandId) && !done.contains(islandId)) done.add(islandId);
    dl['done'] = done;
    if (done.length < tasks.length) {
      save();
      return false;
    }
    dl['claimed'] = true;
    final y = dayKey(_clock().subtract(const Duration(days: 1)));
    final st = p.streak ?? {'last': null, 'count': 0};
    final count = st['last'] == y ? asInt(st['count']) + 1 : st['last'] == today() ? asInt(st['count']) : 1;
    p.json['streak'] = {'last': today(), 'count': count};
    p.stars += 5;
    save();
    return true;
  }

  // ---------- Huy hiệu: ghi lại cái nào đã nhận để báo "mới" một lần ----------
  List<String> newBadges(List<String> earnedIds) {
    final p = profile;
    if (p == null) return const [];
    final have = p.badges.toSet();
    final fresh = earnedIds.where((id) => !have.contains(id)).toList();
    if (fresh.isNotEmpty) {
      p.json['badges'] = [...have, ...fresh];
      save();
    }
    return fresh;
  }

  // ---------- Khu vui chơi: vé chơi game kiếm được bằng cách học ----------
  int tickets(Profile p) => p.json['tickets'] == null ? 2 : asInt(p.json['tickets']);
  void addTickets(int n) {
    final p = profile;
    if (p == null) return;
    p.json['tickets'] = tickets(p) + n;
    save();
  }

  bool useTicket() {
    final p = profile;
    if (p == null || tickets(p) <= 0) return false;
    p.json['tickets'] = tickets(p) - 1;
    save();
    return true;
  }

  /// Lưu kỷ lục; trả về true nếu là kỷ lục mới.
  bool saveBest(String game, int score) {
    final p = profile;
    if (p == null) return false;
    final isNew = score > asInt(p.best[game]);
    if (isNew) p.best[game] = score;
    save();
    return isNew;
  }

  int funLevel(Profile p, String id) => min(kFunMax - 1, asInt(p.funLevels[id]));
  void funLevelUp(String id) {
    final p = profile;
    if (p == null) return;
    p.json['funLevel'] = {...p.funLevels, id: min(kFunMax - 1, funLevel(p, id) + 1)};
    save();
  }

  /// Kho đồ của từng game Khu vui chơi (súng, skill, nâng cấp xe...), JSON thuần do game tự định nghĩa.
  Json gear(Profile? p, String id) => p == null ? <String, dynamic>{} : asMap(p.gearAll[id]);
  void saveGear(String id, Json? data) {
    final p = profile;
    if (p == null || data == null) return;
    p.json['gear'] = {...p.gearAll, id: data};
    save();
  }

  // ---------- Theo dõi học tập (Báo cáo bố mẹ, ôn tập ngắt quãng, mốc tiến bộ) ----------
  // p.learn: items {"bộ:id": [đúng ngay, sai, ngày ôn tới, chuỗi đúng liền, đã thạo 0/1]}, conf {"loại|đáp án|bé chọn": n},
  //   skills {đảo: [đúng ngay, sai, tổng ms]}, days {"YYYY-MM-DD": [bài, sao, đúng, sai, mục mới thạo]}, ms [mốc], msAt {mốc: ngày}
  int dayNum([DateTime? d]) {
    final t = d ?? _clock();
    return ((t.millisecondsSinceEpoch + t.timeZoneOffset.inMilliseconds) / 864e5).floor();
  }

  static const List<int> _gaps = [0, 1, 3, 7, 14, 30];
  static bool mastered(List? it) => it != null && asInt(it[3]) >= 1 && asInt(it[0]) > asInt(it[1]);

  Json learn(Profile p) {
    final l = p.json['learn'] is Map<String, dynamic> ? p.json['learn'] as Json : (p.json['learn'] = asMap(p.json['learn']));
    for (final k in ['items', 'conf', 'skills', 'days', 'msAt']) {
      l[k] = l[k] is Map<String, dynamic> ? l[k] : asMap(l[k]);
    }
    l['ms'] = l['ms'] is List ? l['ms'] : <dynamic>[];
    return l;
  }

  List _logDay(Profile p, int rounds, int stars) {
    final days = learn(p)['days'] as Json;
    final d = (days[today()] as List?) ?? (days[today()] = <dynamic>[0, 0, 0, 0, 0]);
    d[0] = asInt(d[0]) + rounds;
    d[1] = asInt(d[1]) + stars;
    final keys = days.keys.toList()..sort();
    while (keys.length > 60) {
      days.remove(keys.removeAt(0));
    }
    return d;
  }

  /// Ghi một câu hỏi: ok = đúng ngay lần đầu; keys = các mục của câu; conf = cặp nhầm ["loại|đáp án|bé chọn"].
  /// Trả về danh sách mục vừa thạo lần đầu.
  List<String> recordAnswer(String skill, List<String> keys, bool ok, [List<String> conf = const [], int ms = 0]) {
    final p = profile;
    if (p == null) return const [];
    final l = learn(p);
    final skills = l['skills'] as Json;
    final sk = (skills[skill] as List?) ?? (skills[skill] = <dynamic>[0, 0, 0]);
    sk[ok ? 0 : 1] = asInt(sk[ok ? 0 : 1]) + 1;
    sk[2] = asInt(sk[2]) + min(ms, 60000);
    final d = _logDay(p, 0, 0);
    d[ok ? 2 : 3] = asInt(d[ok ? 2 : 3]) + 1;
    final now = dayNum();
    final fresh = <String>[];
    final items = l['items'] as Json;
    for (final k in keys) {
      final it = (items[k] as List?) ?? (items[k] = <dynamic>[0, 0, 0, 0, 0]);
      if (ok) {
        it[0] = asInt(it[0]) + 1;
        it[3] = asInt(it[3]) + 1;
        it[2] = now + _gaps[min(asInt(it[3]), _gaps.length - 1)];
      } else {
        it[1] = asInt(it[1]) + 1;
        it[3] = 0;
        it[2] = now;
      }
      if (asInt(it[4]) == 0 && mastered(it)) {
        it[4] = 1;
        d[4] = asInt(d[4]) + 1;
        fresh.add(k);
      }
    }
    final cf = l['conf'] as Json;
    for (final c in conf) {
      cf[c] = asInt(cf[c]) + 1;
    }
    if (cf.length > 80) {
      final ck = cf.keys.toList()..sort((a, b) => asInt(cf[a]) - asInt(cf[b]));
      for (final k in ck.take(ck.length - 80)) {
        cf.remove(k);
      }
    }
    save();
    return fresh;
  }

  /// Mục cần ôn: từng sai, chưa nhớ chắc (chuỗi đúng < 5) và đã tới ngày ôn. all = lấy cả mục chưa tới ngày.
  List<String> dueItems(Profile p, {bool all = false}) {
    final items = learn(p)['items'] as Json;
    final now = dayNum();
    final list = items.entries.where((e) {
      final it = e.value as List;
      final ok = asInt(it[1]) > 0 && asInt(it[3]) < 5;
      return ok && (all ? (asInt(it[3]) < 2 || asInt(it[2]) <= now) : asInt(it[2]) <= now);
    }).toList();
    list.sort((a, b) {
      final x = a.value as List, y = b.value as List;
      final c = asInt(x[2]) - asInt(y[2]);
      return c != 0 ? c : (asInt(y[1]) - asInt(y[0])) - (asInt(x[1]) - asInt(x[0]));
    });
    return list.map((e) => e.key).toList();
  }

  /// Bài ôn tập: cộng sao như một bài (không tính vào bài của đảo).
  void recordReview(int stars) {
    final p = profile;
    if (p == null) return;
    p.stars += stars;
    _logDay(p, 1, stars);
    save();
  }

  List<String> addMilestones(List<String> ids) {
    final p = profile;
    if (p == null) return const [];
    final l = learn(p);
    final ms = l['ms'] as List;
    final fresh = ids.where((id) => !ms.contains(id)).toList();
    if (fresh.isNotEmpty) {
      ms.addAll(fresh);
      for (final id in fresh) {
        (l['msAt'] as Json)[id] = today();
      }
      save();
    }
    return fresh;
  }

  // ---------- Đồng bộ nhiều máy (sync.dart của agent I mã hoá rồi mới gửi) ----------
  Json snapshot() => {'profiles': _s['profiles'], 'settings': _s['settings'], 'gone': _s['gone'], 'smt': _s['smt']};

  static Json _maxMerge(Object? a, Object? b) {
    final o = {...asMap(a)};
    asMap(b).forEach((k, v) {
      if (v is num) {
        final a = o[k] is num ? o[k] as num : 0;
        o[k] = a >= v ? a : v;
      }
    });
    return o;
  }

  /// Gộp dữ liệu máy khác vào máy này, sửa tại chỗ. Mỗi hồ sơ: bản sửa sau thắng, nhưng sao, số lượt, giờ học,
  /// cấp game, hình dán lấy phần lớn hơn của cả hai máy (không bao giờ giảm). Trả về true nếu có thay đổi.
  bool mergeRemote(Object? remote) {
    if (remote is! Map || remote['profiles'] is! List) return false;
    var changed = false;
    final gone = {...asMap(_s['gone'])};
    asMap(remote['gone']).forEach((id, t) => gone[id] = max(asInt(t), asInt(gone[id])));
    _s['gone'] = gone;
    final list = _s['profiles'] as List;
    for (final rp in asMapList(remote['profiles'])) {
      final rid = rp['id'];
      if (asInt(gone[rid]) >= asInt(rp['mt']) && gone.containsKey(rid)) continue;
      final idx = list.indexWhere((p) => (p as Json)['id'] == rid);
      if (idx < 0) {
        list.add(rp);
        changed = true;
        continue;
      }
      final lp = list[idx] as Json;
      if (jsonEncode(lp) == jsonEncode(rp)) continue;
      final win = asInt(rp['mt']) > asInt(lp['mt']) ? rp : lp, lose = identical(win, rp) ? lp : rp;
      int big(String k) => max(asInt(win[k]), asInt(lose[k]));
      final merged = <String, dynamic>{
        ...win,
        'levels': _maxMerge(lose['levels'], win['levels']),
        'funLevel': _maxMerge(lose['funLevel'], win['funLevel']),
        'usage': _maxMerge(lose['usage'], win['usage']),
        'stars': big('stars'),
        'rounds': big('rounds'),
        'spent': big('spent'),
        'stickers': {...asStrList(win['stickers']), ...asStrList(lose['stickers'])}.toList(),
        'mt': max(asInt(lp['mt']), asInt(rp['mt'])),
      };
      lp
        ..removeWhere((k, _) => !merged.containsKey(k))
        ..addAll(merged);
      changed = true;
    }
    final n = list.length;
    list.removeWhere((p) => gone.containsKey((p as Json)['id']) && asInt(gone[p['id']]) >= asInt(p['mt']));
    if (list.length != n) changed = true;
    if (profile == null) _s['active'] = profiles.isEmpty ? null : profiles.first.id;
    if (asInt(remote['smt']) > asInt(_s['smt'])) {
      _s['settings'] = {...kDefaultSettings, ...asMap(remote['settings'])};
      _s['smt'] = remote['smt'];
      changed = true;
    }
    if (changed) {
      _rawSave();
      notifyListeners();
    }
    return changed;
  }
}

/// Bộ sinh số giả ngẫu nhiên theo chuỗi (port seeded() trong store.js, cho ra đúng dãy số như web).
double Function() seededRandom(String str) {
  int imul(int a, int b) => (a * b) & 0xFFFFFFFF;
  var h = 2166136261;
  for (final c in str.codeUnits) {
    h = imul(h ^ c, 16777619);
  }
  return () {
    h = imul(h ^ (h >> 15), 2246822507);
    h = imul(h ^ (h >> 13), 3266489909);
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    return h / 4294967296;
  };
}

/// SharedPreferences đã mở (main() override). Test: SharedPreferences.setMockInitialValues({}).
final storeProvider = ChangeNotifierProvider<AppStore>((ref) => AppStore(null));
