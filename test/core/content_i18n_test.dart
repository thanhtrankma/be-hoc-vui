// Nạp dữ liệu thật từ assets/, danh sách bài/cấp học, mẫu câu đọc, i18n, đặt dấu thanh.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/content/vn_text.dart';
import 'package:be_vui_hoc/core/game/class_plan.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/registry.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle b;
  setUpAll(() async => b = await loadContentBundle(rootBundle));

  test('nạp app.json: đảo, linh vật, tủ đồ, thú cưng', () {
    expect(b.data.islands.length, 18);
    expect(b.data.mascots.first.id, 'superhero');
    expect(b.data.island('room')!.route, '/room');
    expect(b.data.gameIslands.length, 15);
    expect(b.data.wardrobe.any((w) => w.slot == 'bg' && w.bg != null), true);
    expect(b.data.pets.first.foods, isNotEmpty);
    expect(b.photos['Airplane']!.assetPath, 'assets/photo/airplane.webp');
  });

  test('mỗi đảo học có module trong registry và có danh sách bài', () {
    for (final isl in b.data.gameIslands) {
      expect(gameModuleFor(isl.game), isNotNull, reason: isl.id);
      expect(levelsOf(isl, b.content), isNotEmpty, reason: isl.id);
    }
    expect(levelsKeyOf(b.data.island('letters')!), 'letterLevels');
    expect(levelsKeyOf(b.data.island('english')!), 'englishLevels');
    // Chữ cái không có hình ở bài; Tiếng Anh có.
    expect(levelsOf(b.data.island('letters')!, b.content).first.img, isNull);
    expect(levelsOf(b.data.island('english')!, b.content).first.img, 'Cat');
  });

  test('mọi game Khu vui chơi có module', () {
    for (final g in kFunGames) {
      expect(funGameModuleFor(g.id), isNotNull, reason: g.id);
    }
    expect(kFunGames.length, funGameModules.length);
  });

  test('cấp học: tierFor chọn cấp gần nhất, tierLevels gồm bài tier 0', () {
    final count = b.data.island('count')!;
    final have = islTiers(count, b.content);
    expect(have, isNotEmpty);
    expect(tierFor(count, b.content, profileTier: 1), have.contains(1) ? 1 : have.first);
    final music = b.data.island('music')!;
    // đảo âm nhạc: bài tier 0 thuộc mọi cấp
    expect(tierLevels(music, b.content, tierFor(music, b.content, profileTier: 2)), isNotEmpty);
    expect(tierOf(9).id, 3);
  });

  test('khoá theo thứ tự: bài sau mở khi bài trước có sao', () {
    final isl = b.data.island('count')!;
    final lv = tierLevels(isl, b.content, 1);
    final stars = <int, int>{};
    bool open(int i) => levelUnlocked(lockOrder: true, isl: isl, content: b.content, i: i, starsOf: (k) => stars[k] ?? 0);
    expect(open(lv[0].i), true);
    expect(open(lv[1].i), false);
    stars[lv[0].i] = 1;
    expect(open(lv[1].i), true);
    expect(levelUnlocked(lockOrder: false, isl: isl, content: b.content, i: lv[3].i, starsOf: (_) => 0), true);
  });

  test('voice: phrase, tpl có fx, tra file giọng', () {
    final v = b.voice;
    expect(v.phrase('praise1', 'vi').text, 'Giỏi quá!');
    final m = b.data.mascots.first;
    final line = v.tpl('mascotVi', m.json)!;
    expect(line, const VoiceLine('vi', 'Siêu nhân!'));
    expect(v.fileOf(line), isNotNull);
    final w = b.content.list('vnwords').first; // bò: "bờ. o. bo. huyền. bò."
    expect(v.tpl('spellFast', w)!.text, 'bờ o bo, huyền bò!');
    expect(v.tpl('spell', w)!.text, 'bờ, o, bo, huyền, bò.');
    expect(v.tpl('khongCo', {}), isNull);
  });

  test('SilentAudio: say/sayAll xong ngay, ghi log', () async {
    final a = SilentAudio(voice: b.voice);
    await a.sayAll([a.phrase('praise1'), a.phrase('praise2')]);
    a.sfx('win');
    expect(a.log, contains('sfx:win'));
    expect(a.log.where((e) => e.startsWith('say:')).length, 2);
  });

  test('i18n: t() thay biến, L() chọn vi/en', () {
    const vi = I18n('vi'), en = I18n('en');
    expect(vi.t('hi', {'name': 'Na'}), 'Chào Na!');
    expect(en.t('hi', {'name': 'Na'}), 'Hi Na!');
    expect(vi.t('khong-co'), 'khong-co');
    expect(en.tList('installSteps'), isEmpty); // hướng dẫn cài PWA chỉ dành cho bản web, đã bỏ
    expect(vi.L({'vi': 'Con vật', 'en': 'Animals'}), 'Con vật');
    expect(en.L({'vi': 'Con vật', 'en': 'Animals'}), 'Animals');
    expect(en.L({'vi': 'Chỉ có tiếng Việt'}), 'Chỉ có tiếng Việt');
    expect(en.L(b.data.island('letters')), 'Letters');
    expect(en.L(tierOf(1)), 'Sprout');
    expect(kStrings['vi']!.length, kStrings['en']!.length);
  });

  test('placeTone đặt dấu đúng chỗ (dựng sẵn NFC)', () {
    expect(placeTone('o', 'huyền'), 'ò');
    expect(placeTone('oa', 'huyền'), 'oà');
    expect(placeTone('uy', 'hỏi'), 'uỷ');
    expect(placeTone('ương', 'sắc'), 'ướng');
    expect(placeTone('ai', 'nặng'), 'ại');
    expect(placeTone('an', 'ngang'), 'an');
    expect(placeTone('uyên', 'huyền'), 'uyền');
  });

  test('theo dõi học tập: tra ngược câu đọc → mục; mốc; huy hiệu', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final p = store.addProfile('Na', 'robot');
    final t = LearnTracker(content: b.content, data: b.data, voice: b.voice, store: store);
    final w = b.content.list('vnwords').first;
    final say = b.voice.tpl('vnWord', w);
    if (say != null) expect(t.lookup(say), 'vnwords:${w['id']}');
    final letters = b.data.island('letters')!;
    t.recordForLevel(letters, b.content.level('letterLevels', 0), const QuizRecord(answer: 'a', picks: ['ă']));
    expect((store.learn(p)['items'] as Map).containsKey('letters:a'), true);
    expect((store.learn(p)['conf'] as Map)['letters|a|ă'], 1);
    expect(t.itemOf('letters:a')!.label, 'a');
    expect(t.msInfo('w10', 'vi').text, 'Con đã đọc đúng 10 tiếng!');
    store.recordRound('letters', 0, 3, const []);
    expect(t.badgeEarned(kBadges.first, p), true);
  });

  test('Học cùng lớp: tuần học, danh sách bài, bài tiếp', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance(), clock: () => DateTime(2026, 9, 16, 10));
    final p = store.addProfile('Na', 'robot');
    final plan = ClassPlan(b.content, store);
    expect(plan.classWeek(p), 2);
    final tv = plan.classItems('tv');
    expect(tv.first.key, 'tv1');
    expect(plan.classItems('toan').first.acts.first, ('count', 0));
    final r = plan.classDone(p, 'count', 0);
    expect(r.next, ('count', 0)); // chưa có sao: hoạt động đầu vẫn là "tiếp"
    plan.setClassWeek(p, 10);
    expect(plan.classWeek(p), 10);
  });
}
