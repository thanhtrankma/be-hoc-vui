// Kiểu dữ liệu cho app.json (đảo, linh vật, hình dán, tủ đồ, thú cưng) và vài tiện ích đọc JSON.
// content.json có ~100 bộ dữ liệu khác nhau: giữ dạng Map/List (xem content.dart), chỉ gõ kiểu cho phần dùng chung.
import 'package:flutter/painting.dart';

import '../i18n/i18n.dart';

typedef Json = Map<String, dynamic>;

// ---------- Đọc JSON an toàn ----------
int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);
double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
String asStr(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();
bool asBool(Object? v) => v == true || (v is num && v != 0);
List<String> asStrList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
Json asMap(Object? v) => v is Json ? v : v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asMapList(Object? v) => v is List ? v.whereType<Map>().map(asMap).toList() : <Json>[];

/// Màu CSS '#rrggbb' / '#rgb' → Color. Sai định dạng thì trả fallback.
Color parseColor(String? css, [Color fallback = const Color(0xFF4FB3FF)]) {
  if (css == null) return fallback;
  var s = css.trim();
  if (!s.startsWith('#')) return fallback;
  s = s.substring(1);
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? fallback : Color(v);
}

/// Chữ song ngữ {vi, en}.
class LText implements Localized {
  const LText(this.vi, [this.en]);
  factory LText.fromJson(Object? j) {
    if (j is Map) return LText(asStr(j['vi']), j['en'] == null ? null : asStr(j['en']));
    return LText(asStr(j));
  }
  final String vi;
  final String? en;
  @override
  String textOf(String lang) => lang == 'en' ? (en ?? vi) : vi;
}

/// Một đảo trên bản đồ. Đảo học có `game`; đảo đặc biệt có `route` (/room, /duel, /lop1); `soon` = sắp có.
class Island implements Localized {
  Island({required this.id, this.game, this.route, required this.img, required this.colorHex, required this.vi, required this.en, this.soon = false, required this.json});
  factory Island.fromJson(Json j) => Island(
        id: asStr(j['id']),
        game: j['game'] as String?,
        route: j['route'] as String?,
        img: asStr(j['img']),
        colorHex: asStr(j['color'], '#4fb3ff'),
        vi: asStr(j['vi']),
        en: asStr(j['en'], asStr(j['vi'])),
        soon: asBool(j['soon']),
        json: j,
      );
  final String id;
  final String? game;
  final String? route;
  final String img;
  final String colorHex;
  final String vi;
  final String en;
  final bool soon;
  final Json json;
  Color get color => parseColor(colorHex);
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

class Mascot implements Localized {
  Mascot({required this.id, required this.img, required this.vi, required this.en, required this.stars, required this.json});
  factory Mascot.fromJson(Json j) =>
      Mascot(id: asStr(j['id']), img: asStr(j['img']), vi: asStr(j['vi']), en: asStr(j['en']), stars: asInt(j['stars']), json: j);
  final String id;
  final String img;
  final String vi;
  final String en;

  /// Số sao cần để mở (0 = có sẵn khi tạo hồ sơ).
  final int stars;
  final Json json;
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

/// Đồ trong Phòng của bé. slot: hat | eyes | hand | bg. bg: chuỗi CSS gradient (xem cssBackground()).
class WardrobeItem {
  WardrobeItem({required this.id, required this.slot, required this.img, required this.vi, required this.price, this.bg, required this.json});
  factory WardrobeItem.fromJson(Json j) => WardrobeItem(
      id: asStr(j['id']), slot: asStr(j['slot']), img: asStr(j['img']), vi: asStr(j['vi']), price: asInt(j['price']), bg: j['bg'] as String?, json: j);
  final String id;
  final String slot;
  final String img;
  final String vi;
  final int price;
  final String? bg;
  final Json json;
}

class PetKind implements Localized {
  PetKind({required this.id, required this.vi, required this.en, required this.p, required this.img, required this.foods, required this.toy, required this.sound, required this.names, required this.json});
  factory PetKind.fromJson(Json j) => PetKind(
        id: asStr(j['id']),
        vi: asStr(j['vi']),
        en: asStr(j['en']),
        p: asStr(j['p']),
        img: asStr(j['img']),
        foods: asStrList(j['foods']),
        toy: asStr(j['toy']),
        sound: asStr(j['sound']),
        names: asStrList(j['names']),
        json: j,
      );
  final String id;
  final String vi;
  final String en;

  /// Tên đọc trong câu (vd. "cún con").
  final String p;
  final String img;
  final List<String> foods;
  final String toy;
  final String sound;
  final List<String> names;
  final Json json;
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

class PetItem {
  PetItem({required this.lv, required this.img, required this.slot});
  factory PetItem.fromJson(Json j) => PetItem(lv: asInt(j['lv']), img: asStr(j['img']), slot: asStr(j['slot']));
  final int lv;
  final String img;
  final String slot;
}

/// app.json đã gõ kiểu.
class AppData {
  AppData({required this.mascots, required this.stickers, required this.islands, required this.images, required this.wardrobe, required this.pets, required this.petItems, required this.raw});
  factory AppData.fromJson(Json j) => AppData(
        mascots: asMapList(j['mascots']).map(Mascot.fromJson).toList(),
        stickers: asStrList(j['stickers']),
        islands: asMapList(j['islands']).map(Island.fromJson).toList(),
        images: asStrList(j['images']),
        wardrobe: asMapList(j['wardrobe']).map(WardrobeItem.fromJson).toList(),
        pets: asMapList(j['pets']).map(PetKind.fromJson).toList(),
        petItems: asMapList(j['petItems']).map(PetItem.fromJson).toList(),
        raw: j,
      );
  final List<Mascot> mascots;
  final List<String> stickers;
  final List<Island> islands;
  final List<String> images;
  final List<WardrobeItem> wardrobe;
  final List<PetKind> pets;
  final List<PetItem> petItems;
  final Json raw;

  /// Linh vật theo id (không có thì linh vật đầu tiên, như web).
  Mascot mascot(String? id) => mascots.firstWhere((m) => m.id == id, orElse: () => mascots.first);
  Island? island(String? id) {
    for (final i in islands) {
      if (i.id == id) return i;
    }
    return null;
  }

  WardrobeItem? wardrobeItem(String? id) {
    for (final w in wardrobe) {
      if (w.id == id) return w;
    }
    return null;
  }

  PetKind pet(String? id) => pets.firstWhere((p) => p.id == id, orElse: () => pets.first);

  /// Các đảo học (có trò chơi), dùng cho thử thách hằng ngày, huy hiệu.
  List<Island> get gameIslands => islands.where((i) => i.game != null).toList();
}

/// Ảnh chụp thật thay hình hoạt hình (photos.json): f = đường dẫn 'photo/x.webp'.
class PhotoInfo {
  PhotoInfo({required this.f, this.by, this.lic, this.src});
  factory PhotoInfo.fromJson(Json j) => PhotoInfo(f: asStr(j['f']), by: j['by'] as String?, lic: j['lic'] as String?, src: j['src'] as String?);
  final String f;
  final String? by;
  final String? lic;
  final String? src;
  String get assetPath => 'assets/$f';
}
