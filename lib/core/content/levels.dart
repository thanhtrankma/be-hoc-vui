// Danh sách bài của từng đảo và cấp học (port levelsOf/LEVEL_KEY/TIERS/tierFor/tierLevels/unlocked trong app.js).
// Danh sách bài lấy thẳng từ dữ liệu, không cần code trò chơi.
import 'package:flutter/painting.dart';

import '../i18n/i18n.dart';
import 'content.dart';

/// game → khoá danh sách bài trong content.json (đảo 'letters' và 'english' dùng game 'pick', xem levelsKeyOf).
const Map<String, String> levelKeyByGame = {
  'count': 'countLevels', 'memory': 'memoryLevels', 'spell': 'spellLevels', 'trace': 'traceLevels', 'math': 'mathLevels',
  'logic': 'logicLevels', 'music': 'musicLevels', 'art': 'artLevels', 'explore': 'exploreLevels', 'read': 'readLevels',
  'life': 'lifeLevels', 'arcade': 'arcadeLevels', 'code': 'codeLevels',
};

String? levelsKeyOf(Island isl) =>
    isl.id == 'letters' ? 'letterLevels' : isl.id == 'english' ? 'englishLevels' : levelKeyByGame[isl.game];

/// Một bài trong danh sách. i = chỉ số trong content[levelsKey] (dùng làm khoá sao "đảo:i").
class LevelInfo {
  const LevelInfo({required this.i, required this.tier, required this.hide, required this.name, this.img, required this.json});
  final int i;

  /// 0 = thuộc mọi cấp; 1 Mầm, 2 Chồi, 3 Lớp 1.
  final int tier;
  final bool hide;
  final LText name;

  /// Hình thay số thứ tự (đảo không phải 'pick', hoặc Tiếng Anh).
  final String? img;
  final Json json;
}

List<LevelInfo> levelsOf(Island isl, Content content) {
  final key = levelsKeyOf(isl);
  if (key == null) return const [];
  final list = content.list(key);
  return [
    for (var i = 0; i < list.length; i++)
      LevelInfo(
        i: i,
        tier: asInt(list[i]['tier']),
        hide: asBool(list[i]['hide']),
        name: LText.fromJson(list[i]['name']),
        img: (isl.id == 'english' || isl.game != 'pick') ? list[i]['img'] as String? : null,
        json: list[i],
      ),
  ];
}

/// Dữ liệu thô của bài li (levelData trong app.js).
Json? levelData(Island isl, Content content, int li) {
  final key = levelsKeyOf(isl);
  return key == null ? null : content.level(key, li);
}

// ---------- Cấp học: 1 Mầm (3-4 tuổi), 2 Chồi (5 tuổi), 3 Lớp 1 (6 tuổi). Bài tier 0 thuộc mọi cấp. ----------
class TierInfo implements Localized {
  const TierInfo({required this.id, required this.img, required this.colorValue, required this.vi, required this.en, required this.age, required this.what});
  final int id;
  final String img;
  final int colorValue;
  final String vi;
  final String en;
  final LText age;
  final LText what;
  Color get color => Color(colorValue);
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

const List<TierInfo> kTiers = [
  TierInfo(id: 1, img: 'Seedling', colorValue: 0xFF51CF66, vi: 'Mầm', en: 'Sprout', age: LText('3–4 tuổi', 'Age 3–4'),
      what: LText('Chữ cái, đếm đến 10, màu sắc, hình khối', 'Letters, counting to 10, colors, shapes')),
  TierInfo(id: 2, img: 'Herb', colorValue: 0xFF20C997, vi: 'Chồi', en: 'Bud', age: LText('5 tuổi', 'Age 5'),
      what: LText('Dấu thanh, ghép tiếng, tập viết, cộng trừ trong 10', 'Tones, syllables, writing, +/− within 10')),
  TierInfo(id: 3, img: 'Deciduous tree', colorValue: 0xFF3D8BFD, vi: 'Lớp 1', en: 'Grade 1', age: LText('6 tuổi', 'Age 6'),
      what: LText('Vần khó, đọc từ, xếp câu, toán đến 100, lời văn', 'Harder rhymes, reading, sentences, math to 100')),
];

TierInfo tierOf(int? id) => kTiers.firstWhere((x) => x.id == id, orElse: () => kTiers[2]);

/// Các cấp có bài (không ẩn) trong một đảo, tăng dần.
List<int> islTiers(Island isl, Content content) {
  final s = <int>{for (final l in levelsOf(isl, content)) if (!l.hide && l.tier != 0) l.tier};
  return s.toList()..sort();
}

/// Cấp hiển thị cho một đảo: cấp đang xem (tab) hoặc cấp của bé; đảo không có cấp đó thì lấy cấp gần nhất (ưu tiên thấp hơn).
int tierFor(Island isl, Content content, {int? profileTier, int? viewTier}) {
  final have = islTiers(isl, content);
  if (have.isEmpty) return 0;
  final want = viewTier ?? (profileTier == null || profileTier == 0 ? 3 : profileTier);
  if (have.contains(want)) return want;
  final lower = have.where((x) => x < want).toList();
  return lower.isNotEmpty ? lower.last : have.first;
}

/// Bài của một cấp (bài tier 0 thuộc mọi cấp; tier 0 = mọi bài).
List<LevelInfo> tierLevels(Island isl, Content content, int tier) =>
    levelsOf(isl, content).where((l) => !l.hide && (tier == 0 || l.tier == 0 || l.tier == tier)).toList();

/// Mặc định mọi bài đều mở; bố mẹ bật "khoá theo thứ tự" thì phải xong bài trước trong cùng cấp.
bool levelUnlocked({required bool lockOrder, required Island isl, required Content content, required int i, required int Function(int i) starsOf}) {
  if (!lockOrder) return true;
  final all = levelsOf(isl, content);
  final list = tierLevels(isl, content, i >= 0 && i < all.length ? all[i].tier : 0);
  final pos = list.indexWhere((l) => l.i == i);
  return pos <= 0 || starsOf(list[pos - 1].i) > 0;
}

/// Câu dẫn khi mở danh sách bài của đảo (voice.json phrases).
const Map<String, String> kIslandIntro = {
  'letters': 'lettersIntro', 'count': 'countIntro', 'english': 'englishIntro', 'memory': 'memoryIntro', 'spell': 'spellIntro',
  'trace': 'traceIntro', 'math': 'mathIntro', 'logic': 'logicIntro', 'music': 'musicIntro', 'art': 'artIntro', 'explore': 'exploreIntro',
  'read': 'readIntro', 'life': 'lifeIntro', 'arcade': 'arcadeIntro', 'code': 'codeIntro',
};
