// Thế giới phiêu lưu: dữ liệu lưu p.rpg (giống web), chỉ số, mở vùng, cộng thưởng sau màn, cửa hàng, lưu/đọc lại.
import 'dart:convert';
import 'dart:io';

import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/features/rpg/rpg.dart';
import 'package:be_vui_hoc/features/rpg/rpgcore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _store([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppStore(await SharedPreferences.getInstance());
  if (s.profile == null) s.addProfile('Na', 'robot');
  return s;
}

RunResult _res({bool win = true, int gold = 10, int xp = 5, int potions = 2}) => RunResult(win: win, gold: gold, xp: xp, kills: 3, potions: potions);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rpgOf tạo bản lưu mặc định như web', () async {
    final s = await _store();
    final R = rpgOf(s.profile!);
    expect(R.lv, 1);
    expect(R.gold, 30);
    expect(R.pot, 2);
    expect(R.pet, 'dog');
    expect(R.ownW, [0]);
    expect(R.c, isNull);
    expect(s.profile!.json['rpg'], isA<Map>());
  });

  test('chỉ số theo cấp + trang bị + bùa', () async {
    final s = await _store();
    final R = rpgOf(s.profile!)
      ..lv = 4
      ..w = 2
      ..a = 1
      ..c = 2;
    final st = rpgStats(R);
    expect(st.atk, 10 + 4 * 3 + 12);
    expect(st.def, 3 + 2);
    expect(st.maxhp, 80 + 4 * 15 + 20);
    expect(st.crit, closeTo(.2, 1e-9));
  });

  test('mở vùng: vùng sau mở khi thắng trùm vùng trước; màn mở lần lượt', () async {
    final s = await _store();
    final p = s.profile!;
    expect(canPlay(p, 0, 0), isTrue);
    expect(canPlay(p, 0, 1), isFalse);
    expect(canPlay(p, 1, 0), isFalse);
    expect(canPlay(p, 99, 0), isFalse);
    rpgOf(p).prog['0'] = kStages;
    expect(canPlay(p, 1, 0), isTrue);
    expect(unlockedZone(rpgOf(p), 2), isFalse);
  });

  test('thắng lần đầu: lên tiến độ, cộng vàng/kinh nghiệm, lên cấp; chơi lại chỉ nửa thưởng', () async {
    final s = await _store();
    final p = s.profile!;
    final out = applyStage(p, 0, 0, _res(gold: 10, xp: 5));
    final R = rpgOf(p);
    expect(out.win, isTrue);
    expect(R.progOf(0), 1);
    expect(out.gold, 10 + 15);
    expect(out.xp, 5 + 20);
    expect(R.gold, 30 + 25);
    // 25 xp < need(1)=50 → chưa lên cấp
    expect(R.lv, 1);
    final again = applyStage(p, 0, 0, _res(gold: 0, xp: 40));
    expect(again.xp, 40 + 10); // nửa thưởng
    expect(R.progOf(0), 1);
    expect(again.ups, 1);
    expect(R.lv, 2);
    expect(R.xp, 25 + 50 - 50);
  });

  test('thắng trùm: mở vùng mới + đồng đội; thua không lên tiến độ; bố mẹ chơi thử không lưu', () async {
    final s = await _store();
    final p = s.profile!;
    final R = rpgOf(p);
    R.prog['2'] = 5;
    R.prog['1'] = 6;
    R.prog['0'] = 6;
    final boss = applyStage(p, 2, 5, _res());
    expect(boss.cleared, isTrue);
    expect(boss.unlocked?.id, 'fairy');
    expect(petOk(R, kPets[1]), isTrue);
    expect(canPlay(p, 3, 0), isTrue);
    final lose = applyStage(p, 3, 0, _res(win: false, gold: 4, potions: 0));
    expect(lose.win, isFalse);
    expect(R.progOf(3), 0);
    expect(R.pot, 0);
    final gold = R.gold;
    final f = applyStage(p, 3, 0, _res(), free: true);
    expect(f.win, isTrue);
    expect(R.progOf(3), 0);
    expect(R.gold, gold);
  });

  test('cửa hàng: thiếu vàng không mua được; đủ thì trừ vàng', () async {
    final s = await _store();
    final R = rpgOf(s.profile!);
    expect(rpgBuy(R, kWeapons[1].cost, () => R.ownW.add(1)), isFalse);
    R.gold = 100;
    expect(
        rpgBuy(R, kWeapons[1].cost, () {
          R.ownW.add(1);
          R.w = 1;
        }),
        isTrue);
    expect(R.gold, 40);
    expect(R.w, 1);
    expect(R.ownW, [0, 1]);
  });

  test('lưu và đọc lại tiến độ (JSON giống web)', () async {
    final s = await _store();
    final p = s.profile!;
    applyStage(p, 0, 0, _res());
    rpgOf(p)
      ..w = 1
      ..ownW.add(1);
    s.save();
    final raw = (await SharedPreferences.getInstance()).getString('bvh.v1')!;
    final s2 = AppStore(await SharedPreferences.getInstance());
    final r2 = rpgOf(s2.profile!);
    expect(r2.progOf(0), 1);
    expect(r2.w, 1);
    expect(r2.ownW, [0, 1]);
    // Định dạng web: prog là map {"0": 1}
    final js = jsonDecode(raw) as Map;
    final rpg = ((js['profiles'] as List).first as Map)['rpg'] as Map;
    expect(rpg['prog'], {'0': 1});
    expect(rpg['lv'], 1);
  });

  test('đọc bản lưu web có prog dạng số', () async {
    final s = await _store({
      'bvh.v1': jsonEncode({
        'profiles': [
          {
            'id': 'k1',
            'name': 'Bi',
            'mascot': 'robot',
            'rpg': {
              'lv': 7,
              'xp': 12,
              'gold': 500,
              'w': 3,
              'a': 2,
              'c': 1,
              'ownW': [0, 1, 2, 3],
              'ownA': [0, 2],
              'ownC': [1],
              'pet': 'fairy',
              'pot': 4,
              'prog': {'0': 6, '1': 6, '2': 3}
            }
          }
        ],
        'active': 'k1',
        'settings': {}
      })
    });
    final R = rpgOf(s.profile!);
    expect(R.lv, 7);
    expect(R.progOf(2), 3);
    expect(canPlay(s.profile!, 2, 3), isTrue);
    expect(canPlay(s.profile!, 2, 4), isFalse);
    expect(rpgStats(R).goldMul, closeTo(1.3, 1e-9));
  });

  test('mọi hình RPG có file trong assets/img', () {
    final missing = rpgAllImages().where((n) => !File(imgAsset(n)).existsSync()).toList();
    expect(missing, isEmpty);
  });
}
