// Store: định dạng JSON giống localStorage 'bvh.v1' của web (để sao lưu/đồng bộ dùng chung), và các phép ghi chính.
import 'dart:convert';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Một bản lưu thật của web (rút gọn), kèm trường lạ do game thêm (rpg, look...).
const webBlob = '''
{"profiles":[{"id":"mg1abc12","name":"Na","mascot":"robot","stars":42,"rounds":9,"stickers":["Rainbow","Rocket"],
 "levels":{"letters:0":3,"count:2":2},"usage":{"2026-10-14":600},"bonus":{},"created":1760400000000,"mt":1760500000000,
 "tier":2,"tickets":4,"spent":5,"owned":["cap"],"outfit":{"hat":"cap"},"best":{"racer":120},"funLevel":{"racer":3},
 "gear":{"hunt":{"sword":2}},"pet":{"type":"dog","name":"Bông","happy":60},"look":{"base":"girl","shirt":"#e64980"},
 "rpg":{"lv":3,"gold":50},"learn":{"items":{"letters:a":[2,1,20000,1,1]},"conf":{},"skills":{},"days":{},"ms":[],"msAt":{}}}],
 "active":"mg1abc12","settings":{"lang":"vi","music":false,"sound":true,"limit":20,"fun":true,"ticketsPer":1,"lockOrder":false},
 "gone":{},"smt":1760000000000}
''';

Future<AppStore> storeWith(Map<String, Object> values, {DateTime? now}) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return AppStore(prefs, clock: now == null ? null : () => now);
}

void main() {
  test('đọc bản lưu của web, giữ nguyên trường lạ khi ghi lại', () async {
    final s = await storeWith({kStoreKey: webBlob});
    final p = s.profile!;
    expect(p.name, 'Na');
    expect(p.stars, 42);
    expect(p.tier, 2);
    expect(s.levelStars(p, 'letters', 0), 3);
    expect(s.tickets(p), 4);
    expect(s.wallet(p), 37);
    expect(s.musicOn, false);
    s.save();
    final prefs = await SharedPreferences.getInstance();
    final out = jsonDecode(prefs.getString(kStoreKey)!) as Map<String, dynamic>;
    expect(out.keys.toSet(), {'profiles', 'active', 'settings', 'gone', 'smt'});
    final op = (out['profiles'] as List).first as Map<String, dynamic>;
    expect(op['rpg'], {'lv': 3, 'gold': 50});
    expect(op['look'], {'base': 'girl', 'shirt': '#e64980'});
    expect(op['levels'], {'letters:0': 3, 'count:2': 2});
    expect(op['stickers'], ['Rainbow', 'Rocket']);
    expect(op['mt'], isA<int>());
  });

  test('hồ sơ mới có đúng các khoá như web', () async {
    final s = await storeWith({});
    final p = s.addProfile('Bin', 'superhero');
    expect(s.activeId, p.id);
    expect(p.json.keys.toSet(), containsAll(['id', 'name', 'mascot', 'stars', 'rounds', 'stickers', 'levels', 'usage', 'bonus', 'created', 'mt']));
    expect(s.settings, kDefaultSettings);
    expect(s.tickets(p), 2); // mặc định 2 vé như web
  });

  test('recordRound: sao cộng dồn, bài giữ sao cao nhất, có hình dán mới', () async {
    final s = await storeWith({});
    final p = s.addProfile('Bin', 'superhero');
    final st = s.recordRound('count', 1, 2, ['Rainbow']);
    expect(st, 'Rainbow');
    s.recordRound('count', 1, 1, ['Rainbow']);
    expect(s.levelStars(p, 'count', 1), 2);
    expect(p.stars, 3);
    expect(p.rounds, 2);
    expect(p.stickers, ['Rainbow']);
    final days = (s.learn(p)['days'] as Map).values.first as List;
    expect(days[0], 2);
    expect(days[1], 3);
  });

  test('seededRandom cho ra đúng dãy số như store.js', () {
    final r = seededRandom('2026-10-15mgabc123');
    expect(r(), closeTo(0.6264975760132074, 1e-15));
    expect(r(), closeTo(0.13423658139072359, 1e-15));
    expect(r(), closeTo(0.3819378688931465, 1e-15));
  });

  test('daily(): cùng 3 đảo như web cho cùng ngày + id; xong đủ thì +5 sao và chuỗi ngày', () async {
    final s = await storeWith({}, now: DateTime(2026, 10, 15, 9));
    final p = s.addProfile('Na', 'robot');
    p.json['id'] = 'kid1';
    s.setActive('kid1');
    const ids = ['letters', 'spell', 'trace', 'read', 'count', 'math', 'life', 'english', 'memory', 'logic', 'code', 'arcade', 'music', 'art', 'explore'];
    final dl = s.daily(ids);
    expect(dl['tasks'], ['code', 'memory', 'letters']);
    expect(s.dailyProgress('code'), false);
    expect(s.dailyProgress('memory'), false);
    final before = p.stars;
    expect(s.dailyProgress('letters'), true);
    expect(p.stars, before + 5);
    expect(p.streakCount, 1);
  });

  test('vé, kỷ lục, cấp game, kho đồ', () async {
    final s = await storeWith({});
    final p = s.addProfile('Na', 'robot');
    expect(s.useTicket(), true);
    expect(s.useTicket(), true);
    expect(s.useTicket(), false);
    s.addTickets(3);
    expect(s.tickets(p), 3);
    expect(s.saveBest('racer', 10), true);
    expect(s.saveBest('racer', 5), false);
    s.funLevelUp('racer');
    expect(s.funLevel(p, 'racer'), 1);
    s.saveGear('hunt', {'sword': 1});
    expect(s.gear(p, 'hunt'), {'sword': 1});
  });

  test('giới hạn giờ chơi + phút bố mẹ cho thêm', () async {
    final s = await storeWith({}, now: DateTime(2026, 10, 15, 9));
    s.addProfile('Na', 'robot');
    s.addUsage(20 * 60);
    expect(s.overLimit(), true);
    s.addBonus(10);
    expect(s.overLimit(), false);
  });

  test('recordAnswer + dueItems (ôn tập ngắt quãng)', () async {
    final s = await storeWith({});
    final p = s.addProfile('Na', 'robot');
    s.recordAnswer('letters', ['letters:b'], false, ['letters|b|d']);
    expect(s.dueItems(p), ['letters:b']);
    s.recordAnswer('letters', ['letters:b'], true);
    s.recordAnswer('letters', ['letters:b'], true);
    // đã thạo (đúng > sai, chuỗi ≥ 1) và ngày ôn tới ở tương lai
    final it = (s.learn(p)['items'] as Map)['letters:b'] as List;
    expect(it[4], 1);
    expect(s.dueItems(p), isEmpty);
    expect((s.learn(p)['conf'] as Map)['letters|b|d'], 1);
  });

  test('export/import đúng định dạng file sao lưu của web', () async {
    final s = await storeWith({kStoreKey: webBlob});
    final txt = s.exportData();
    final obj = jsonDecode(txt) as Map;
    expect(obj['app'], 'be-vui-hoc');
    expect(obj['version'], 1);
    final s2 = await storeWith({});
    s2.importData(txt);
    expect(s2.profile!.name, 'Na');
    expect(() => s2.importData('{"app":"khac"}'), throwsFormatException);
  });

  test('mergeRemote: sao và hình dán lấy phần lớn hơn, hồ sơ mới được thêm', () async {
    final s = await storeWith({kStoreKey: webBlob});
    final remote = jsonDecode(webBlob) as Map<String, dynamic>;
    final rp = (remote['profiles'] as List).first as Map<String, dynamic>;
    rp['stars'] = 50;
    rp['mt'] = 1760600000000;
    rp['stickers'] = ['Star'];
    rp['levels'] = {'letters:0': 1, 'math:0': 3};
    (remote['profiles'] as List).add({'id': 'other', 'name': 'Bin', 'mt': 1, 'stars': 1, 'stickers': [], 'levels': {}, 'usage': {}});
    expect(s.mergeRemote(remote), true);
    final p = s.profileById('mg1abc12')!;
    expect(p.stars, 50);
    expect(p.stickers.toSet(), {'Rainbow', 'Rocket', 'Star'});
    expect(p.levels['letters:0'], 3);
    expect(p.levels['math:0'], 3);
    expect(s.profiles.length, 2);
    // hồ sơ đã xoá ở máy khác thì bị xoá ở đây
    expect(s.mergeRemote({'profiles': [], 'gone': {'other': 99999999999999}}), true);
    expect(s.profiles.length, 1);
  });

  test('settings: setSetting đóng dấu smt', () async {
    final s = await storeWith({});
    s.setSetting('lang', 'en');
    expect(s.lang, 'en');
    expect(asInt(s.raw['smt']), greaterThan(0));
  });
}
