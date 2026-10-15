// ignore_for_file: prefer_initializing_formals
// Nhân vật sprite (Kenney Toon Characters, CC0) cho Khu vui chơi, RPG, Lập trình robot — port games/figure.js.
// Sheet do tools/sprites.py của web tạo: assets/sprites/toon/<base>.webp|json (+ <base>.<nhóm>.webp = ảnh bóng của
// nhóm màu áo/tóc/quần) và assets/sprites/pets/<dog|cat>.*
// CHỦ: agent C. Agent E/F/G/H dùng — GIỮ NGUYÊN chữ ký công khai: Costume, kCostumes, costumeOf, kLookShirts, kLookHats,
// setPlayer, lookOf, heroOf, kBot, kDad, kFriends, preloadFigures, figureSize, drawFigure, drawHead, PetBuddy, petBuddy,
// FigureView, PetView. (Thêm mới, không bắt buộc: figuresReady, FigureController, drawFigure(weapon: 'tên hình').)
//
// Vẽ khi sheet chưa nạp xong thì dùng hình người đơn giản (không lỗi) — giống web bỏ qua khung, nhưng vẫn thấy nhân vật.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';

/// Trang phục: base 'boy' | 'girl' | 'kid' | 'dad' | 'robot'; màu áo/quần/tóc (đổi màu thật trên sprite);
/// hat = tên hình Fluent đội trên đầu ('Crown', 'Billed cap', 'Rescue workers helmet', 'Top hat'; tên cũ
/// 'racing'/'police'/'fire'/'conductor'/'crown' vẫn nhận).
class Costume {
  const Costume({required this.base, this.shirt, this.pants, this.hair, this.hat});
  final String base;
  final Color? shirt;
  final Color? pants;
  final Color? hair;
  final String? hat;
  Costume copyWith({String? base, Color? shirt, Color? pants, Color? hair, String? hat}) =>
      Costume(base: base ?? this.base, shirt: shirt ?? this.shirt, pants: pants ?? this.pants, hair: hair ?? this.hair, hat: hat ?? this.hat);

  @override
  bool operator ==(Object other) =>
      other is Costume && other.base == base && other.shirt == shirt && other.pants == pants && other.hair == hair && other.hat == hat;
  @override
  int get hashCode => Object.hash(base, shirt, pants, hair, hat);
}

Color _c(int v) => Color(v);

/// Trang phục theo tên hình linh vật (COSTUMES của web).
final Map<String, Costume> kCostumes = {
  'Man superhero': Costume(base: 'boy', shirt: _c(0xFF1C7ED6), pants: _c(0xFFE03131)),
  'Woman superhero': Costume(base: 'girl', shirt: _c(0xFFE64980)),
  'Robot': const Costume(base: 'robot'),
  'Racing car': Costume(base: 'boy', shirt: _c(0xFFFA5252), pants: _c(0xFF343A40), hat: 'Billed cap'),
  'T-rex': Costume(base: 'boy', shirt: _c(0xFF40C057)),
  'Astronaut': Costume(base: 'kid', shirt: _c(0xFFF1F3F5), pants: _c(0xFFCED4DA)),
  'Princess': Costume(base: 'girl', shirt: _c(0xFFF783AC), hair: _c(0xFFFAB005), hat: 'Crown'),
  'Unicorn': Costume(base: 'kid', shirt: _c(0xFFB197FC), hair: _c(0xFFF783AC)),
  'Cat face': Costume(base: 'boy', shirt: _c(0xFFFF922B), pants: _c(0xFF5C3D2E)),
  'Rabbit face': Costume(base: 'girl', shirt: _c(0xFFF1F3F5)),
  'Dog face': Costume(base: 'boy', shirt: _c(0xFFC08A52), pants: _c(0xFF5C3D2E)),
  'Panda': Costume(base: 'kid', shirt: _c(0xFFF8F9FA), pants: _c(0xFF343A40)),
  'Fire engine': Costume(base: 'boy', shirt: _c(0xFFE03131), pants: _c(0xFF343A40), hat: 'Rescue workers helmet'),
  'Woman fairy': Costume(base: 'girl', shirt: _c(0xFF63E6BE), hair: _c(0xFFFFD43B)),
  'Rocket': Costume(base: 'boy', shirt: _c(0xFFE9ECEF), pants: _c(0xFF868E96)),
  'Police car': Costume(base: 'boy', shirt: _c(0xFF1864AB), pants: _c(0xFF212529), hat: 'Billed cap'),
  'Sauropod': Costume(base: 'kid', shirt: _c(0xFF4DABF7)),
  'Locomotive': Costume(base: 'boy', shirt: _c(0xFF495057), pants: _c(0xFF343A40), hat: 'Top hat'),
  'Ninja': Costume(base: 'boy', shirt: _c(0xFF343A40), pants: _c(0xFF212529), hair: _c(0xFF212529)),
  'Bear': Costume(base: 'boy', shirt: _c(0xFFA0522D), pants: _c(0xFF5C3D2E)),
  'Dragon': Costume(base: 'kid', shirt: _c(0xFFE03131)),
  'Lion': Costume(base: 'girl', shirt: _c(0xFFFAB005), hair: _c(0xFFE8590C)),
};
final Costume _default = Costume(base: 'boy', shirt: _c(0xFF339AF0));

/// {...DEFAULT, ...COSTUMES[img]} của web.
Costume costumeOf(String? img) {
  final c = kCostumes[img];
  if (c == null) return _default;
  return Costume(base: c.base, shirt: c.shirt ?? _default.shirt, pants: c.pants, hair: c.hair, hat: c.hat);
}

/// Bé tự chọn ở Khu vui chơi (p.look): màu áo, mũ (null = không mũ).
final List<Color> kLookShirts = [0xFF1C7ED6, 0xFFE03131, 0xFF2F9E44, 0xFFF08C00, 0xFFAE3EC9, 0xFFE64980, 0xFF15AABF, 0xFF343A40].map(_c).toList();
const List<String?> kLookHats = [null, 'Billed cap', 'Crown', 'Rescue workers helmet', 'Top hat'];

({String img, Costume c})? _player;

/// Đặt nhân vật của bé (gọi khi vào Khu vui chơi/RPG với p.look). look = {base: 'boy'|'girl', shirt: '#hex', hat}.
void setPlayer(String img, Json? look) {
  final base = look?['base'];
  _player = (base == 'boy' || base == 'girl') ? (img: img, c: lookOf(look!)) : null;
}

Costume lookOf(Json look) {
  final base = asStr(look['base'], 'boy');
  return Costume(
    base: base,
    shirt: parseColor(look['shirt'] as String?, base == 'girl' ? _c(0xFFE64980) : _c(0xFF1C7ED6)),
    hair: look['hair'] == null ? null : parseColor(look['hair'] as String?),
    pants: base == 'boy' ? parseColor(look['pants'] as String?, _c(0xFF343A40)) : null,
    hat: look['hat'] as String?,
  );
}

/// Nhân vật của bé (nếu img trùng linh vật của bé hoặc null), không thì trang phục theo hình.
Costume heroOf([String? img]) {
  final p = _player;
  if (p != null && (img == null || img == p.img)) return p.c;
  return costumeOf(img);
}

final Costume kBot = Costume(base: 'robot', shirt: _c(0xFFFA5252));
const Costume kDad = Costume(base: 'dad');
final List<Costume> kFriends = [
  Costume(base: 'kid', shirt: _c(0xFF40C057)),
  Costume(base: 'girl', shirt: _c(0xFFFAB005)),
  Costume(base: 'boy', shirt: _c(0xFF7950F2)),
  Costume(base: 'kid', shirt: _c(0xFF15AABF), hair: _c(0xFF8D5524)),
];

// Mũ kiểu cũ (đợt 14) -> hình Fluent
const Map<String, String?> _oldHats = {
  'racing': 'Billed cap', 'police': 'Billed cap', 'fire': 'Rescue workers helmet', 'conductor': 'Top hat', 'crown': 'Crown', //
  'space': null, 'ears': null, 'dino': null, 'mane': null, 'horn': null, 'ninja': null, 'antenna': null,
};
const List<String> _hats = ['Crown', 'Billed cap', 'Rescue workers helmet', 'Top hat'];
const List<String> _bases = ['boy', 'girl', 'kid', 'dad', 'robot'];
const Map<String, String> _petSheet = {'dog': 'dog', 'fox': 'dog', 'cat': 'cat', 'rabbit': 'cat', 'hamster': 'dog', 'panda': 'cat'};
const Map<String, Map<String, Color>> _petTint = {
  'dog': {'fur': Color(0xFFB7793F)},
  'hamster': {'fur': Color(0xFFE3B26B)},
};

// ---------- Nạp ----------
final Map<String, SpriteSheet> _sheets = {}; // 'boy'... | 'pet:dog'
final Map<String, ui.Image> _shades = {}; // 'toon/boy.shirt' -> ảnh bóng
final Map<String, ui.Image> _hatImgs = {};
final Map<String, ui.Image> _weapons = {};
final Set<String> _weaponLoading = {};
Future<void>? _ready;

/// true khi mọi sheet nhân vật đã nạp (vẽ được sprite thật).
bool get figuresReady => _sheets.length >= _bases.length + 2;

Future<void> _loadSheetWithShades(String name, String key) async {
  final s = await loadSheet(name);
  if (s == null) return;
  final tint = s.meta['tint'];
  if (tint is Map) {
    for (final g in tint.keys) {
      final im = await loadUiImage('assets/sprites/$name.$g.webp');
      if (im != null) _shades['$name.$g'] = im;
    }
  }
  _sheets[key] = s;
}

/// Nạp mọi sheet nhân vật + ảnh bóng đổi màu + hình mũ. Gọi nhiều lần được (dùng chung một Future).
Future<void> preloadFigures() => _ready ??= () async {
      try {
        await Future.wait([
          for (final b in _bases) _loadSheetWithShades('toon/$b', b),
          for (final p in ['dog', 'cat']) _loadSheetWithShades('pets/$p', 'pet:$p'),
          for (final h in _hats) loadEmojiUiImage(h).then((im) => im == null ? null : _hatImgs[h] = im),
        ]);
      } catch (e) {
        debugPrint('figure sprites: $e');
      }
      if (!figuresReady) _ready = null; // thử lại lần sau
    }();

// ---------- Đổi màu áo/tóc/quần ngay trên sprite (một lần cho mỗi bộ màu, lưu ảnh) ----------
// Ảnh bóng của từng nhóm màu (xám = độ sáng, chỉ có ở điểm thuộc nhóm): nhân màu đích lên ảnh bóng rồi phủ lên sheet.
final Map<String, ui.Image> _variants = {};

ui.Image? _variant(SpriteSheet sheet, Map<String, Color?> colors) {
  final base = sheet.image;
  if (base == null) return null;
  final tint = sheet.meta['tint'];
  final groups = colors.keys.where((g) => colors[g] != null && tint is Map && tint.containsKey(g) && _shades['${sheet.name}.$g'] != null).toList();
  if (groups.isEmpty) return base;
  final id = '${sheet.name}|${groups.map((g) => '$g${colors[g]!.toARGB32()}').join('|')}';
  final hit = _variants[id];
  if (hit != null) return hit;
  try {
    final rec = ui.PictureRecorder();
    final cv = Canvas(rec);
    cv.drawImage(base, Offset.zero, Paint());
    for (final g in groups) {
      cv.drawImage(_shades['${sheet.name}.$g']!, Offset.zero, Paint()..colorFilter = ColorFilter.mode(colors[g]!, BlendMode.modulate));
    }
    final img = rec.endRecording().toImageSync(base.width, base.height);
    return _variants[id] = img;
  } catch (_) {
    return base;
  }
}

class _Look {
  _Look(this.sheet, this.img, this.hatName);
  final SpriteSheet sheet;
  final ui.Image img;
  final String? hatName;
  ui.Image? get hat => hatName == null ? null : _hatImgs[hatName];
}

final Map<Costume, _Look> _looks = {};

String _baseOf(Costume c) => _bases.contains(c.base) ? c.base : 'boy';

String? _hatOf(String? hat) {
  if (hat == null) return null;
  if (_oldHats.containsKey(hat)) return _oldHats[hat];
  return _hats.contains(hat) ? hat : null;
}

_Look? _look(Costume? c) {
  c ??= _default;
  final hit = _looks[c];
  if (hit != null) return hit;
  final b = _baseOf(c), sh = _sheets[b];
  if (sh == null) {
    preloadFigures();
    return null;
  }
  // robot bố/mẹ không đổi màu; áo của dad giữ nguyên trừ khi game đổi
  final img = _variant(sh, {'shirt': c.shirt, 'hair': c.hair, 'pants': c.pants});
  if (img == null) return null;
  final hn = _hatOf(c.hat);
  return _looks[c] = _Look(sh, img, hn);
}

List<double>? _numList(Object? v) => v is List ? v.map((e) => (e as num).toDouble()).toList() : null;
List<double>? _metaAt(SpriteSheet sh, String key, String fr) {
  final m = sh.meta[key];
  if (m is! Map) return null;
  return _numList(m[fr]) ?? _numList(m['idle']);
}

double _top(SpriteSheet sh) => (sh.meta['top'] as num? ?? 0).toDouble();

// ---------- Chọn khung theo tư thế ----------
(String, double, double) _frameFor(SpriteSheet sh, String pose, double t, double act) {
  final a = act.clamp(0.0, 1.0);
  final sin = math.sin;
  switch (pose) {
    case 'idle':
      return ('idle', 0, 0);
    case 'run':
      return (frameAt(sh, 'walk', t * 1.25), 0, 0);
    case 'walk':
      return (frameAt(sh, 'walk', t), 0, 0);
    case 'sprint':
      return (frameAt(sh, 'run', t), 0, 0);
    case 'jump':
      return ('jump', 0, 0);
    case 'fall':
      return ('fall', 0, 0);
    case 'punch':
      return (a < .2 ? 'hold' : 'attack0', a < .2 ? 0 : sin(a * math.pi) * .06, 0);
    case 'kick':
      return (a < .15 ? 'hold' : 'kick', 0, 0);
    case 'flykick':
      return ('attackKick', 0, 0);
    case 'swing':
      return (a < .4 ? 'attack1' : 'attack2', a < .4 ? 0 : .04, 0);
    case 'throw':
      return (a < .45 ? 'attack1' : 'attack0', 0, 0);
    case 'block':
      return ('hold', -.02, -.05);
    case 'hurt':
      return ('hit', -.03, -.12);
    case 'sit':
      return ('duck', 0, 0);
    case 'pull':
      return ('drag', -.02 + sin(t * 9) * .015, -.08 + sin(t * 9) * .03);
    case 'cheer':
      return (frameAt(sh, 'cheer', t), 0, 0);
    case 'talk':
      return (frameAt(sh, 'talk', t), 0, 0);
    default:
      return (sh.frames.containsKey(pose) ? pose : sh.anims.containsKey(pose) ? frameAt(sh, pose, t) : 'idle', 0, 0);
  }
}

/// Bề ngang và cỡ đầu xấp xỉ của nhân vật cao h.
({double w, double head}) figureSize(double h) => (w: h * .78, head: h * .55);

ui.Image? _weaponImg(String? name) {
  if (name == null) return null;
  final im = _weapons[name];
  if (im == null && _weaponLoading.add(name)) {
    loadEmojiUiImage(name).then((v) {
      if (v != null) _weapons[name] = v;
    });
  }
  return im;
}

/// Vẽ nhân vật: (x, y) = điểm giữa hai bàn chân, h = chiều cao (chân tới đỉnh đầu, không tính mũ).
/// pose: idle | run | walk | sprint | jump | fall | punch | kick | flykick | swing | throw | block | hurt | sit | pull | cheer | talk | interact | show
/// t: giây (hoạt ảnh); act: 0..1 tiến độ đòn; face: 1 phải / -1 trái; team: màu vòng dưới chân;
/// noHead: chỉ vẽ phần dưới cổ (game vẽ đầu to riêng bằng drawHead); shadow: false = không vẽ bóng.
/// Vũ khí cầm tay: weaponImage (ảnh đã nạp) hoặc weapon (tên hình Fluent, tự nạp lần đầu).
void drawFigure(Canvas canvas, double x, double y, double h, Costume c,
    {String pose = 'idle',
    double t = 0,
    double act = 0,
    int face = 1,
    double alpha = 1,
    ui.Image? weaponImage,
    String? weapon,
    Color? team,
    bool noHead = false,
    bool shadow = true}) {
  final L = _look(c);
  if (L == null) {
    _drawFallback(canvas, x, y, h, c, pose: pose, t: t, alpha: alpha, team: team, noHead: noHead, shadow: shadow);
    return;
  }
  final sh = L.sheet, size = sh.size ?? const Size(192, 256);
  final fh = h / (1 - _top(sh)), k = fh / size.height;
  final (fr, dx, rot) = _frameFor(sh, pose, t, act);
  final bob = pose == 'idle' ? 1 + math.sin(t * 2.6) * .012 : pose == 'cheer' ? 1 + math.sin(t * 8).abs() * .03 : 1.0;
  final lift = pose == 'cheer' ? math.sin(t * 8).abs() * h * .04 : 0.0;
  canvas.save();
  if (shadow && pose != 'sit' && pose != 'jump' && pose != 'fall' && pose != 'flykick') {
    // đang bay thì game tự vẽ bóng dưới đất
    final col = team != null ? team.withValues(alpha: (0x88 / 255) * alpha) : Colors.black.withValues(alpha: .18 * alpha);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: h * .6, height: h * .13), Paint()..color = col);
  }
  final fx = x + dx * h * face, fy = y - lift;
  if (noHead) {
    final hb = _metaAt(sh, 'head', fr);
    if (hb != null) {
      final cut = fy - (size.height - (hb[1] + hb[3] * .3)) * k;
      canvas.clipRect(Rect.fromLTWH(x - h * 2, cut, h * 4, h * 2));
    }
  }
  drawFrame(canvas, sh, fr, fx, fy, fh, flip: face < 0, rot: rot * face, image: L.img, sy: bob, alpha: alpha);
  // toạ độ khung logic -> màn hình (có xoay quanh chân)
  Offset p(double px, double py) {
    final lx = (px - size.width * sh.anchor.dx) * k * face, ly = (py - size.height * sh.anchor.dy) * k * bob;
    final cr = math.cos(rot * face), sr = math.sin(rot * face);
    return Offset(fx + lx * cr - ly * sr, fy + lx * sr + ly * cr);
  }

  if (L.hat != null && !noHead) {
    final hb = _metaAt(sh, 'head', fr);
    if (hb != null) {
      final crown = L.hatName == 'Crown';
      final w = hb[2] * k * (crown ? .62 : .95);
      final hp = p(hb[0] + 4, hb[1] - hb[3] * (crown ? .64 : .36));
      drawImageCentered(canvas, L.hat, hp.dx, hp.dy, w, w, face < 0, rot * face, alpha);
    }
  }
  final wimg = weaponImage ?? _weaponImg(weapon);
  if (wimg != null) {
    final hd = _metaAt(sh, 'hand', fr);
    if (hd != null) {
      final wp = p(hd[0], hd[1]);
      final ws = h * .46, a = ((hd.length > 2 ? hd[2] : 0) + rot) * face;
      drawImageCentered(canvas, wimg, wp.dx + math.sin(a) * ws * .28, wp.dy - math.cos(a) * ws * .28, ws, ws, face < 0, a, alpha);
    }
  }
  canvas.restore();
}

// Hình người đơn giản khi sprite chưa nạp (hoặc trong test).
void _drawFallback(Canvas canvas, double x, double y, double h, Costume c,
    {String pose = 'idle', double t = 0, double alpha = 1, Color? team, bool noHead = false, bool shadow = true}) {
  final paint = Paint();
  if (shadow) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: h * .6, height: h * .13), paint..color = (team ?? Colors.black).withValues(alpha: .18 * alpha));
  }
  final bob = pose == 'run' || pose == 'walk' ? math.sin(t * 12).abs() * h * .03 : 0.0;
  final body = Rect.fromLTWH(x - h * .18, y - h * .62 - bob, h * .36, h * .42);
  canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(h * .1)), paint..color = (c.shirt ?? _default.shirt!).withValues(alpha: alpha));
  canvas.drawRect(Rect.fromLTWH(x - h * .15, y - h * .22, h * .3, h * .2), paint..color = (c.pants ?? const Color(0xFF343A40)).withValues(alpha: alpha));
  if (!noHead) {
    canvas.drawCircle(Offset(x, y - h * .78 - bob), h * .2, paint..color = (c.base == 'robot' ? const Color(0xFFADB5BD) : const Color(0xFFFFD8A8)).withValues(alpha: alpha));
  }
}

/// Chân dung (đầu + cổ áo) tâm (x, y), bán kính r (HUD, bóng, ô cờ...).
void drawHead(Canvas canvas, double x, double y, double r, Costume c, {int face = 1, bool hurt = false, double t = 0}) {
  final L = _look(c);
  if (L == null) {
    final paint = Paint();
    canvas.drawCircle(Offset(x, y + r * .8), r * .7, paint..color = c.shirt ?? _default.shirt!);
    canvas.drawCircle(Offset(x, y), r, paint..color = c.base == 'robot' ? const Color(0xFFADB5BD) : const Color(0xFFFFD8A8));
    return;
  }
  final sh = L.sheet;
  final fr = hurt ? 'hit' : (t % 4.2) > 3.9 ? 'talk' : 'idle';
  final f = sh.frames[fr], hb = _metaAt(sh, 'head', fr);
  if (f == null || hb == null) return;
  final sx = f[0], sy = f[1], sw = f[2], shh = f[3];
  final ox = f.length > 4 ? f[4] : 0.0, oy = f.length > 5 ? f[5] : 0.0;
  // hộp đầu, lấy rộng hơn chút để có cổ áo, cắt trong phạm vi khung đã cắt
  final bx0 = math.max(hb[0] - hb[2] * .55, ox), bx1 = math.min(hb[0] + hb[2] * .55, ox + sw);
  final by0 = math.max(hb[1] - hb[3] * .55, oy), by1 = math.min(hb[1] + hb[3] * .62, oy + shh);
  if (bx1 <= bx0 || by1 <= by0) return;
  final k = r * 2.1 / hb[2];
  canvas.save();
  canvas.translate(x, y);
  if (face < 0) canvas.scale(-1, 1);
  canvas.drawImageRect(
    L.img,
    Rect.fromLTWH(sx + bx0 - ox, sy + by0 - oy, bx1 - bx0, by1 - by0),
    Rect.fromLTWH((bx0 - hb[0]) * k, (by0 - hb[1]) * k, (bx1 - bx0) * k, (by1 - by0) * k),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
  if (L.hat != null) {
    final crown = L.hatName == 'Crown';
    final w = hb[2] * k * (crown ? .62 : .95);
    drawImageCentered(canvas, L.hat, x + 4 * k * face, y - hb[3] * k * (crown ? .64 : .36), w, w, face < 0);
  }
}

/// Thú đồng đội (dog | cat | fox | rabbit | hamster | panda).
class PetBuddy {
  PetBuddy(this.kind) : _t = math.Random().nextDouble() * 2;
  final String kind;
  double _t, _mv = 0;
  void update(double dt, bool moving) {
    _t += dt;
    _mv += ((moving ? 1 : 0) - _mv) * math.min(1, dt * 8);
  }

  /// size ~ dài thân (u của petrig); thú cao ~1.8 × size.
  void draw(Canvas canvas, double x, double y, double size, [int face = 1]) {
    final sk = _petSheet[kind] ?? 'dog';
    final sh = _sheets['pet:$sk'];
    if (sh == null) {
      preloadFigures();
      final p = Paint()..color = _petTint[kind]?['fur'] ?? const Color(0xFFB7793F);
      final hop = _mv > .5 ? math.sin(_t * 14).abs() * size * .1 : 0.0;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y - size * .5 - hop), width: size * 1.2, height: size * .8), p);
      canvas.drawCircle(Offset(x + face * size * .55, y - size * 1.0 - hop), size * .38, p);
      return;
    }
    final img = _petTint[kind] != null ? _variant(sh, _petTint[kind]!) : sh.image;
    final hh = size * 1.8 / (sh.anchor.dy - _top(sh)); // cao ~1.8 lần size
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: size * 1.1, height: size * .26), Paint()..color = const Color(0x26000000));
    drawFrame(canvas, sh, frameAt(sh, _mv > .5 ? 'walk' : 'idle', _t), x, y, hh, flip: face < 0, image: img);
  }
}

PetBuddy petBuddy(String kind) => PetBuddy(kind);

/// Điều khiển FigureView từ ngoài (figureEl của web: el.pose, el.face, el.weapon, el.run(giây)).
class FigureController extends ChangeNotifier {
  FigureController({String pose = 'idle', int face = 1, String? weapon})
      : _pose = pose,
        _face = face,
        _weapon = weapon;
  String _pose;
  int _face;
  String? _weapon;
  double runT = 0;

  String get pose => _pose;
  set pose(String v) {
    _pose = v;
    notifyListeners();
  }

  int get face => _face;
  set face(int v) {
    if (v == _face) return;
    _face = v;
    notifyListeners();
  }

  String? get weapon => _weapon;
  set weapon(String? v) {
    _weapon = v;
    notifyListeners();
  }

  /// Chạy tại chỗ s giây rồi về tư thế cũ.
  void run(double s) {
    runT = s;
    notifyListeners();
  }
}

/// Nhân vật động trong giao diện (figureEl): tự chạy hoạt ảnh. controller (tuỳ chọn) đổi pose/face/run từ ngoài.
class FigureView extends StatefulWidget {
  const FigureView({super.key, required this.costume, this.size = 160, this.pose = 'idle', this.face = 1, this.controller});
  final Costume costume;
  final double size;
  final String pose;
  final int face;
  final FigureController? controller;

  @override
  State<FigureView> createState() => _FigureViewState();
}

class _FigureViewState extends State<FigureView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _t = ValueNotifier(math.Random().nextDouble() * 3);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_changed);
    if (!figuresReady) {
      preloadFigures().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant FigureView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = Motion.of(context);
    if (on && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _changed() {
    if (!_ticker.isActive) {
      widget.controller?.runT = 0; // không có hoạt ảnh: chạy tại chỗ xong ngay
      if (mounted) setState(() {});
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    final c = widget.controller;
    if (c != null && c.runT > 0) c.runT = math.max(0, c.runT - dt);
    _t.value += dt;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(child: CustomPaint(painter: _FigurePainter(widget.costume, widget.pose, _t, widget.face, widget.controller))),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.c, this.pose, this.t, this.face, this.ctl) : super(repaint: Listenable.merge([t, ?ctl]));
  final Costume c;
  final String pose;
  final ValueNotifier<double> t;
  final int face;
  final FigureController? ctl;
  @override
  void paint(Canvas canvas, Size size) {
    final ct = ctl;
    final p = ct == null ? pose : (ct.runT > 0 ? 'run' : ct.pose);
    drawFigure(canvas, size.width / 2, size.height * .97, size.height * .8, c, pose: p, t: t.value, face: ct?.face ?? face, weapon: ct?.weapon);
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) => old.pose != pose || old.c != c || old.face != face || old.ctl != ctl;
}

/// Thú cưng đứng thở trong giao diện (petEl).
class PetView extends StatefulWidget {
  const PetView({super.key, required this.kind, this.size = 120});
  final String kind;
  final double size;
  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late PetBuddy _rig = petBuddy(widget.kind);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!figuresReady) {
      preloadFigures().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant PetView old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _rig = petBuddy(widget.kind);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = Motion.of(context);
    if (on && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : math.min(.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _rig.update(dt, false);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(child: CustomPaint(painter: _PetPainter(_rig, _frame))),
      );
}

class _PetPainter extends CustomPainter {
  _PetPainter(this.rig, this.frame) : super(repaint: frame);
  final PetBuddy rig;
  final ValueNotifier<int> frame;
  @override
  void paint(Canvas canvas, Size size) => rig.draw(canvas, size.width / 2, size.height * .95, size.width * .44);
  @override
  bool shouldRepaint(covariant _PetPainter old) => old.rig != rig;
}

/// Để test: xoá bộ nhớ đệm trang phục (khi sheet nạp lại).
@visibleForTesting
void debugResetFigureCache() {
  _looks.clear();
  _variants.clear();
}
