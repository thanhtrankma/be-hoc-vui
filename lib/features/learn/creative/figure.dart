// Nhân vật sprite (Kenney Toon) cho Khu vui chơi, RPG, Lập trình robot (port games/figure.js).
// CHỦ: agent C. Foundation viết sẵn API + dữ liệu trang phục + bản vẽ tạm (hình người đơn giản) để agent E/F/G/H
// dùng ngay khi làm song song. Agent C: thay phần VẼ bằng sprite thật (assets/sprites/toon/*, pets/*, đổi màu áo/tóc),
// nhưng GIỮ NGUYÊN chữ ký công khai: Costume, kCostumes, costumeOf, kLookShirts, kLookHats, setPlayer, lookOf, heroOf,
// kBot, kDad, kFriends, preloadFigures, figureSize, drawFigure, drawHead, PetBuddy, petBuddy, FigureView, PetView.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';

/// Trang phục: base 'boy' | 'girl' | 'kid' | 'dad' | 'robot'; màu áo/quần/tóc; hat = tên hình Fluent đội trên đầu.
class Costume {
  const Costume({required this.base, this.shirt, this.pants, this.hair, this.hat});
  final String base;
  final Color? shirt;
  final Color? pants;
  final Color? hair;
  final String? hat;
  Costume copyWith({String? base, Color? shirt, Color? pants, Color? hair, String? hat}) =>
      Costume(base: base ?? this.base, shirt: shirt ?? this.shirt, pants: pants ?? this.pants, hair: hair ?? this.hair, hat: hat ?? this.hat);
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

/// Nạp mọi sheet nhân vật (bản tạm: không cần nạp).
Future<void> preloadFigures() async {}

/// Bề ngang và cỡ đầu xấp xỉ của nhân vật cao h.
({double w, double head}) figureSize(double h) => (w: h * .78, head: h * .55);

/// Vẽ nhân vật: (x, y) = điểm giữa hai bàn chân, h = chiều cao (chân tới đỉnh đầu).
/// pose: idle | run | walk | sprint | jump | fall | punch | kick | flykick | swing | throw | block | hurt | sit | pull | cheer | talk | interact | show
/// face: 1 phải / -1 trái; act: 0..1 tiến độ đòn; weapon: hình Fluent cầm tay (ảnh đã nạp truyền qua weaponImage).
void drawFigure(Canvas canvas, double x, double y, double h, Costume c,
    {String pose = 'idle', double t = 0, double act = 0, int face = 1, double alpha = 1, ui.Image? weaponImage, Color? team, bool noHead = false, bool shadow = true}) {
  // BẢN TẠM (agent C thay bằng sprite): thân + đầu tròn.
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

/// Chân dung (đầu + cổ áo) tâm (x, y), bán kính r.
void drawHead(Canvas canvas, double x, double y, double r, Costume c, {int face = 1, bool hurt = false, double t = 0}) {
  final paint = Paint();
  canvas.drawCircle(Offset(x, y + r * .8), r * .7, paint..color = c.shirt ?? _default.shirt!);
  canvas.drawCircle(Offset(x, y), r, paint..color = c.base == 'robot' ? const Color(0xFFADB5BD) : const Color(0xFFFFD8A8));
}

/// Thú đồng đội (dog | cat | fox | rabbit | hamster | panda).
class PetBuddy {
  PetBuddy(this.kind);
  final String kind;
  double _t = 0, _mv = 0;
  void update(double dt, bool moving) {
    _t += dt;
    _mv += ((moving ? 1 : 0) - _mv) * math.min(1, dt * 8);
  }

  /// size ~ dài thân (u của petrig); thú cao ~1.8 × size.
  void draw(Canvas canvas, double x, double y, double size, [int face = 1]) {
    final p = Paint()..color = const Color(0xFFB7793F);
    final hop = _mv > .5 ? math.sin(_t * 14).abs() * size * .1 : 0.0;
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y - size * .5 - hop), width: size * 1.2, height: size * .8), p);
    canvas.drawCircle(Offset(x + face * size * .55, y - size * 1.0 - hop), size * .38, p);
  }
}

PetBuddy petBuddy(String kind) => PetBuddy(kind);

/// Nhân vật động trong giao diện (figureEl): tự chạy hoạt ảnh.
class FigureView extends StatelessWidget {
  const FigureView({super.key, required this.costume, this.size = 160, this.pose = 'idle', this.face = 1});
  final Costume costume;
  final double size;
  final String pose;
  final int face;
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: LoopAnim(
          period: const Duration(seconds: 4),
          builder: (context, t, _) => CustomPaint(painter: _FigurePainter(costume, pose, t * 4, face)),
        ),
      );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.c, this.pose, this.t, this.face);
  final Costume c;
  final String pose;
  final double t;
  final int face;
  @override
  void paint(Canvas canvas, Size size) => drawFigure(canvas, size.width / 2, size.height * .97, size.height * .8, c, pose: pose, t: t, face: face);
  @override
  bool shouldRepaint(covariant _FigurePainter old) => old.t != t || old.pose != pose || old.c != c;
}

/// Thú cưng đứng thở trong giao diện (petEl).
class PetView extends StatelessWidget {
  const PetView({super.key, required this.kind, this.size = 120});
  final String kind;
  final double size;
  @override
  Widget build(BuildContext context) {
    final rig = petBuddy(kind);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PetPainter(rig)),
    );
  }
}

class _PetPainter extends CustomPainter {
  _PetPainter(this.rig);
  final PetBuddy rig;
  @override
  void paint(Canvas canvas, Size size) => rig.draw(canvas, size.width / 2, size.height * .95, size.width * .44);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
