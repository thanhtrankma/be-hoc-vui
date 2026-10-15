// Hồ sơ một bé: khung gõ kiểu (extension type) bọc thẳng Map JSON của web (localStorage 'bvh.v1').
// Ghi qua setter là ghi vào Map, nên sao lưu/đồng bộ giữ nguyên định dạng web. Trường lạ (do game thêm) vẫn còn nguyên.
//
// Các khoá trong JSON (giống store.js):
//   id, name, mascot, stars, rounds, stickers[], levels{"đảo:i": sao}, usage{"YYYY-MM-DD": giây}, bonus{ngày: phút},
//   created, mt (giờ sửa), tier, spent, owned[], outfit{slot: id}, daily{date,tasks,done,claimed}, streak{last,count},
//   badges[], tickets, best{game: điểm}, funLevel{game: cấp}, gear{game: {...}}, learn{...}, pet{...}, look{...},
//   rpg{...}, cls{...} (Học cùng lớp)
import '../content/models.dart';

extension type Profile(Json json) {
  String get id => asStr(json['id']);
  String get name => asStr(json['name']);
  set name(String v) => json['name'] = v;
  String? get mascot => json['mascot'] as String?;
  set mascot(String? v) => json['mascot'] = v;

  int get stars => asInt(json['stars']);
  set stars(int v) => json['stars'] = v;
  int get rounds => asInt(json['rounds']);
  set rounds(int v) => json['rounds'] = v;
  int get spent => asInt(json['spent']);
  set spent(int v) => json['spent'] = v;

  /// Cấp học 1..3 (null = chưa chọn).
  int? get tier => json['tier'] == null ? null : asInt(json['tier']);
  set tier(int? v) => json['tier'] = v;

  int get created => asInt(json['created']);
  int get mt => asInt(json['mt']);

  List<String> get stickers => _strList('stickers');
  List<String> get owned => _strList('owned');
  List<String> get badges => _strList('badges');

  /// "đảo:i" → sao cao nhất.
  Map<String, dynamic> get levels => _map('levels');
  Map<String, dynamic> get usage => _map('usage');
  Map<String, dynamic> get bonus => _map('bonus');
  Map<String, dynamic> get outfit => _map('outfit');
  Map<String, dynamic> get best => _map('best');
  Map<String, dynamic> get funLevels => _map('funLevel');
  Map<String, dynamic> get gearAll => _map('gear');

  /// Thú cưng (pet.js quản lý nội dung): {type, name, happy, xp, ...} hoặc null.
  Json? get pet => json['pet'] is Map ? (json['pet'] as Map).cast<String, dynamic>() : null;

  /// Nhân vật trong Khu vui chơi: {base: 'boy'|'girl', shirt, hat}.
  Json? get look => json['look'] is Map ? (json['look'] as Map).cast<String, dynamic>() : null;
  Json? get streak => json['streak'] is Map ? (json['streak'] as Map).cast<String, dynamic>() : null;
  int get streakCount => asInt(streak?['count']);

  // Danh sách/Map sửa tại chỗ: đảm bảo trường tồn tại và đúng kiểu (JSON cũ có thể thiếu).
  List<String> _strList(String k) {
    final v = json[k];
    if (v is List<String>) return v;
    final l = v is List ? v.map((e) => e.toString()).toList() : <String>[];
    json[k] = l;
    return l;
  }

  Map<String, dynamic> _map(String k) {
    final v = json[k];
    if (v is Map<String, dynamic>) return v;
    final m = v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
    json[k] = Map<String, dynamic>.of(m);
    return json[k] as Map<String, dynamic>;
  }
}
