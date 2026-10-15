// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api
// Đua xe tốc độ (Flame). Tiếng động cơ: ctx.audio.engine(0..1).
// CHỦ: agent G. Port của reference/web/js/games/funracer.js.
// Gara (chọn xe, nâng cấp, mở xe mới, sơn, dán hình, nâng sức mạnh hộp quà), hộp quà bí ẩn (tên lửa, khiên, nam châm,
// tăng tốc, biến hình robot, sấm sét, bom dầu, khiên vàng, xe bay), bình nitro, giáp, ô đồ giữ qua màn.
// Bệ tăng tốc, dốc nhảy, rào chắn, dầu trơn; xe máy cấp cao biết thả dầu và bắn tên lửa. Nhìn từ trên xuống, 6 xe, xếp hạng.
// Kéo ngón tay để lái, chạm nút để dùng đồ / nitro.
// Kho đồ (ctx.carry, v:1): {coins, car, own[], up{xe:{eng,acc,grip,nitro,armor,bag}}, ip{món:sao}, items[], paint{}, decal{}, paints[], decals[]}
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/content/models.dart' show Json;
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'act_ui.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funracerGames = {'racer': const RacerModule()};

class RacerModule extends FunGameModule {
  const RacerModule();
  @override
  String get id => 'racer';
  @override
  Widget build(BuildContext context, FunGameContext ctx) => RacerView(ctx: ctx);
}

// ---------- Dữ liệu ----------
class CarDef {
  const CarDef(this.id, this.color, this.paint, this.model, this.vi, this.note, this.vmax, this.acc, this.grip, this.robot, {this.armor = 0, this.cost = 0});
  final String id, paint, vi, note;
  final int color, model, armor, cost;
  final double vmax, acc, grip, robot;
}

const List<CarDef> kCars = [
  CarDef('red', 0xfa5252, 'red', 1, 'Tia chớp', 'Chạy nhanh', 580, 1.1, 650, 7),
  CarDef('blue', 0x4c6ef5, 'blue', 1, 'Rồng xanh', 'Tăng tốc mạnh', 550, 1.6, 650, 7),
  CarDef('yellow', 0xfab005, 'yellow', 1, 'Ong vàng', 'Lái nhạy', 550, 1.1, 900, 7),
  CarDef('purple', 0xbe4bdb, 'purple', 1, 'Robot tím', 'Biến hình lâu', 550, 1.1, 700, 11),
  CarDef('green', 0x40c057, 'green', 5, 'Khủng long', 'Giáp dày', 570, 1.3, 760, 8, armor: 2, cost: 450),
  CarDef('black', 0x343a40, 'black', 1, 'Báo đen', 'Siêu nhanh', 615, 1.45, 820, 9, cost: 700),
];
const Map<String, (String, String)> kRItems = {
  'rocket': ('Rocket', 'TÊN LỬA!'), 'shield': ('Shield', 'KHIÊN!'), 'magnet': ('Magnet', 'NAM CHÂM!'),
  'turbo': ('High voltage', 'TĂNG TỐC!'), 'robot': ('Robot', 'BIẾN HÌNH!'), 'triple': ('Fire', '3 TÊN LỬA!'),
  'zap': ('Cloud with lightning', 'SẤM SÉT!'), 'bomb': ('Bomb', 'BOM DẦU!'), 'gold': ('Glowing star', 'KHIÊN VÀNG!'), 'fly': ('Wing', 'XE BAY!'),
};
final List<String> _itemKeys = kRItems.keys.toList();
const _boxPool = ['rocket', 'rocket', 'triple', 'shield', 'magnet', 'turbo', 'robot', 'robot', 'zap', 'zap', 'bomb', 'bomb', 'gold', 'fly', 'fly'];
const kShopItems = ['rocket', 'shield', 'magnet', 'turbo', 'robot', 'zap', 'bomb', 'gold', 'fly'];
const List<(String, String, int)> kUps = [('eng', 'Gear', 5), ('acc', 'Wind face', 5), ('grip', 'Wrench', 5), ('nitro', 'Fuel pump', 5), ('armor', 'Shield', 4), ('bag', 'Backpack', 2)];
int upCost(String k, int n) => k == 'bag' ? 220 + n * 140 : 120 + n * 60;
const int kIpMax = 3;
int ipCost(int n) => 100 + n * 60;
const Map<String, int> kPaints = {'red': 0xfa5252, 'blue': 0x4c6ef5, 'green': 0x40c057, 'yellow': 0xfab005, 'black': 0x343a40, 'purple': 0xbe4bdb};
const int kPaintCost = 30, kDecalCost = 40, kBagMax = 3;
const kDecals = ['Star', 'Fire', 'High voltage', 'Crown'];
const _rankCoins = [0, 15, 10, 6, 4, 2, 1];
const List<(int, String)> _aiSpr = [(0xfa5252, 'car_red_3'), (0x4c6ef5, 'car_blue_5'), (0x40c057, 'car_green_3'), (0xfab005, 'car_yellow_5'), (0xbe4bdb, 'car_purple_3'), (0xfd7e14, 'car_black_3')];

/// Kho đồ Gara (norm() của web): thiếu/sai trường thì lấy mặc định, không hạ cấp đã có.
class RacerGear {
  RacerGear.from(Object? raw) {
    final c = raw is Map ? raw : const {};
    List arr(Object? v) => v is List ? v : const [];
    Map mp(Object? v) => v is Map ? v : const {};
    final ownS = <String>{'red', 'blue', 'yellow', 'purple', ...arr(c['own']).map((e) => '$e')}..retainWhere((id) => kCars.any((x) => x.id == id));
    own = ownS.toList();
    for (final x in kCars) {
      final uu = mp(mp(c['up'])[x.id]);
      up[x.id] = {for (final s in kUps) s.$1: jInt(uu[s.$1], 0, s.$3)};
    }
    for (final k in kShopItems) {
      ip[k] = jInt(mp(c['ip'])[k], 0, kIpMax);
    }
    paints = {...arr(c['paints']).map((e) => '$e'), ...kCars.where((x) => own.contains(x.id)).map((x) => x.paint)}.where(kPaints.containsKey).toList();
    decals = {...arr(c['decals']).map((e) => '$e')}.where(kDecals.contains).toList();
    for (final x in kCars) {
      final p = mp(c['paint'])[x.id];
      paint[x.id] = paints.contains(p) ? p as String : x.paint;
      final d = mp(c['decal'])[x.id];
      if (decals.contains(d)) decal[x.id] = d as String;
    }
    coins = jInt(c['coins'], 0, 10000000);
    car = own.contains(c['car']) ? c['car'] as String : 'red';
    items = arr(c['items']).map((e) => '$e').where(kRItems.containsKey).take(kBagMax).toList();
  }
  int coins = 0;
  String car = 'red';
  List<String> own = [], items = [], paints = [], decals = [];
  final Map<String, Map<String, int>> up = {};
  final Map<String, int> ip = {};
  final Map<String, String> paint = {}, decal = {};

  Json toJson() => {
        'v': 1,
        'coins': coins,
        'car': car,
        'own': [...own],
        'up': {for (final e in up.entries) e.key: {...e.value}},
        'ip': {...ip},
        'items': [...items],
        'paint': {...paint},
        'decal': {...decal},
        'paints': [...paints],
        'decals': [...decals],
      };
  RacerGear clone() => RacerGear.from(toJson());
  String sprOf(CarDef c) => 'car_${paint[c.id] ?? c.paint}_${c.model}';
}

// ---------- Vẽ xe ----------
/// Xe đua nhìn từ trên: bóng đổ, thân nghiêng theo tay lái, đèn phanh, đầu bé, số xe.
void drawCar(Canvas c, Gfx g, SpriteSheet? rs, double x, double y, double w, double h, String frame,
    {int? num, double ang = 0, Costume? hero, double scale = 1, double steer = 0, double brake = 0, double lift = 0, String? decal}) {
  c.save();
  c.translate(x, y);
  ellipse(c, w * .1 + lift * 18, h * .07 + lift * 22, w * .52 * scale, h * .5 * scale, rgba(0, 0, 0, .22), ang);
  c.rotate(ang);
  c.scale(scale * (1 - math.min(.08, steer.abs() * .12)), scale);
  if (!g.spr(c, rs, frame, 0, 0, h)) fillRR(c, -w / 2, -h / 2, w, h, w * .3, hex(0xfa5252));
  if (decal != null) g.draw(c, decal, 0, -h * .27, w * .42);
  if (brake > .1) {
    ellipse(c, -w * .3, h * .47, w * .1, h * .025, rgba(255, 40, 40, .5 + brake * .5));
    ellipse(c, w * .3, h * .47, w * .1, h * .025, rgba(255, 40, 40, .5 + brake * .5));
    ellipse(c, 0, h * .56, w * .5, h * .07, rgba(255, 60, 60, brake * .25));
  }
  // Web: {...heroOf(hero), hat: 'racing'} → mũ lưỡi trai của tay đua (OLD_HATS racing = 'Billed cap').
  if (hero != null) drawHead(c, 0, h * .02, w * .2, hero.copyWith(hat: 'Billed cap'));
  if (num != null) {
    circle(c, 0, h * .08, w * .16, Colors.white);
    Txt.draw(c, '$num', 0, h * .08 + w * .08, size: w * .22, color: hex(0x212529));
  }
  c.restore();
}

// ---------- Widget: Gara → đua ----------
class RacerView extends StatefulWidget {
  const RacerView({super.key, required this.ctx, this.skipGarage = false});
  final FunGameContext ctx;

  /// Test: vào đua ngay với xe đang chọn.
  final bool skipGarage;
  @override
  State<RacerView> createState() => _RacerViewState();
}

class _RacerViewState extends State<RacerView> {
  late final ActSession ses = actSession(widget.ctx);
  late final RacerGear gear = RacerGear.from(widget.ctx.carry);
  Gfx? gfx;
  RacerGame? game;

  @override
  void initState() {
    super.initState();
    Gfx.load(racerImgs(widget.ctx), ['racing/racing', 'fxa/fx', 'toon/robot', 'space/space']).then((g) {
      if (!mounted) return;
      setState(() => gfx = g);
      final picked = ses.data['car'] as String?;
      if (picked != null || widget.skipGarage) _go(picked ?? gear.car);
    });
  }

  void _go(String carId) {
    ses.data['car'] = carId;
    gear.car = carId;
    setState(() => game = RacerGame(ctx: widget.ctx, gfx: gfx!, gear: gear, carId: carId));
  }

  @override
  void dispose() {
    widget.ctx.audio.engine(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (gfx == null) return const ActLoading(color: Color(0xFF8CE99A));
    final g = game;
    if (g == null) {
      return RacerGarage(ctx: widget.ctx, gear: gear, gfx: gfx!, onGo: _go);
    }
    return ActGameView(
      ctx: widget.ctx,
      game: g,
      toResult: (r) {
        final e = r as RaceEnd;
        return FunResult(score: e.score, win: e.win, pos: e.pos, carry: e.carry);
      },
      onResult: (r) => actSessionDone(ses, widget.ctx, r),
    );
  }
}

List<String> racerImgs(FunGameContext ctx) => [
      ...funTheme(ctx.level).deco, 'Coin', 'High voltage', 'Chequered flag', 'Trophy', 'Rocket', 'Shield', 'Magnet', 'Robot', 'Fire', 'Construction', 'Collision',
      'Sparkles', 'Wrapped gift', 'Cloud with lightning', 'Bomb', 'Glowing star', 'Wing', 'Fuel pump', 'Star', 'Crown', ctx.heroImg,
    ];

/// Màn Gara: chạm thẻ xe = chọn và vào đua ngay; nút cờ lê để nâng cấp xe đó; "Chơi ▶" chạy xe đang chọn.
class RacerGarage extends StatefulWidget {
  const RacerGarage({super.key, required this.ctx, required this.gear, required this.gfx, required this.onGo});
  final FunGameContext ctx;
  final RacerGear gear;
  final Gfx gfx;
  final void Function(String carId) onGo;
  @override
  State<RacerGarage> createState() => _RacerGarageState();
}

class _RacerGarageState extends State<RacerGarage> {
  late String sel = widget.gear.car;
  final Map<String, int> shakes = {};
  RacerGear get G => widget.gear;

  void save() => widget.ctx.saveGear(G.toJson());
  void go(CarDef c) {
    G.car = c.id;
    save();
    widget.ctx.audio.sfx('power');
    widget.onGo(c.id);
  }

  void pay(int cost, String key, VoidCallback fn) {
    if (G.coins < cost) {
      widget.ctx.audio.sfx('wrong');
      setState(() {
        shakes[key] = (shakes[key] ?? 0) + 1;
        shakes['coins'] = (shakes['coins'] ?? 0) + 1;
      });
      return;
    }
    setState(() {
      G.coins -= cost;
      fn();
    });
    widget.ctx.audio.sfx('star');
    save();
  }

  Widget buy(int cost, String key, VoidCallback fn) => ShakeBox(
        trigger: shakes[key] ?? 0,
        child: GestureDetector(
          key: Key('buy-$key'),
          onTap: () => pay(cost, key, fn),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: G.coins < cost ? const Color(0xFFADB5BD) : const Color(0xFF40C057),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: G.coins < cost ? const Color(0xFF868E96) : const Color(0xFF2B8A3E), offset: const Offset(0, 3))],
            ),
            child: PriceTag(cost),
          ),
        ),
      );
  Widget maxTag() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFAB005), borderRadius: BorderRadius.circular(14)),
        child: Text('MAX', style: shopText(18)),
      );

  Widget carPic(CarDef c, {double op = 1}) => Opacity(
        opacity: op,
        child: SizedBox(
          width: 80,
          height: 100,
          child: CustomPaint(painter: _CarPainter(widget.gfx, G.sprOf(c), heroOf(widget.ctx.heroImg), G.decal[c.id])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = kCars.firstWhere((x) => x.id == sel, orElse: () => kCars.first);
    final U = G.up[c.id]!;
    final dark = shopText(18, color: const Color(0xFF343A40));
    final slots = kCars.map((x) {
      final owned = G.own.contains(x.id), lv = kUps.fold<int>(0, (s, u) => s + G.up[x.id]![u.$1]!);
      if (!owned) {
        return ShakeBox(
          trigger: shakes['car-${x.id}'] ?? 0,
          child: GestureDetector(
            key: Key('car-${x.id}'),
            onTap: () => pay(x.cost, 'car-${x.id}', () {
              G.own.add(x.id);
              if (!G.paints.contains(x.paint)) G.paints.add(x.paint);
              sel = x.id;
              G.car = x.id;
            }),
            child: Container(
              width: 140,
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
              decoration: BoxDecoration(color: const Color(0xFFDEE2E6), borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFF868E96), width: 4)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                carPic(x, op: .45),
                Text(x.vi, style: shopText(18, color: const Color(0xFF495057))),
                Row(mainAxisSize: MainAxisSize.min, children: [const EmojiImage('Locked', size: 22, photo: false), PriceTag(x.cost, color: const Color(0xFFE67700))]),
              ]),
            ),
          ),
        );
      }
      final on = x.id == sel;
      return SizedBox(
        width: 140,
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          GestureDetector(
            key: Key('car-${x.id}'),
            onTap: () => go(x),
            child: Container(
              width: 140,
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: hex(kPaints[G.paint[x.id]] ?? x.color), width: 5),
                boxShadow: on ? const [BoxShadow(color: Color(0xFFFFD43B), spreadRadius: 5)] : const [BoxShadow(color: Color(0x26000000), offset: Offset(0, 5))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [carPic(x), Text(x.vi, style: dark), Text(x.note, style: shopText(13, color: const Color(0xFF868E96)))]),
            ),
          ),
          GestureDetector(
            key: Key('tune-${x.id}'),
            onTap: () {
              setState(() {
                sel = x.id;
                G.car = x.id;
              });
              widget.ctx.audio.sfx('tap');
              save();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: on ? const Color(0xFFFFD43B) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const EmojiImage('Wrench', size: 26, photo: false), Text('★$lv', style: dark)]),
            ),
          ),
        ]),
      );
    }).toList();
    Widget row(String img, int n, int max, Widget b) => Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            EmojiImage(img, size: 40, photo: false),
            const SizedBox(width: 6),
            Expanded(child: Text(starsText(n, max), style: shopText(20, color: const Color(0xFFFAB005)))),
            b,
          ]),
        );
    final ups = kUps.map((u) {
      final n = U[u.$1]!;
      return row(u.$2, n, u.$3, n >= u.$3 ? maxTag() : buy(upCost(u.$1, n), 'up-${u.$1}', () => U[u.$1] = n + 1));
    }).toList();
    Widget sw(String key, Widget child, bool on, Color bg, VoidCallback tap) => ShakeBox(
          trigger: shakes[key] ?? 0,
          child: GestureDetector(
            key: Key(key),
            onTap: tap,
            child: Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [if (on) const BoxShadow(color: Color(0xFFFFD43B), spreadRadius: 5), const BoxShadow(color: Color(0x33000000), offset: Offset(0, 3))],
              ),
              child: child,
            ),
          ),
        );
    final sws = kPaints.keys.map((p) {
      final has = G.paints.contains(p);
      return sw('paint-$p', has ? const SizedBox() : const PriceTag(kPaintCost, size: 12), G.paint[c.id] == p, hex(kPaints[p]!), () {
        if (has) {
          setState(() => G.paint[c.id] = p);
          widget.ctx.audio.sfx('tap');
          save();
        } else {
          pay(kPaintCost, 'paint-$p', () {
            G.paints.add(p);
            G.paint[c.id] = p;
          });
        }
      });
    }).toList();
    final dcs = <String?>[null, ...kDecals].map((d) {
      final has = d == null || G.decals.contains(d);
      return sw('decal-${d ?? 'none'}', Column(mainAxisSize: MainAxisSize.min, children: [
        if (d == null) Text('✕', style: shopText(20, color: const Color(0xFFE67700))) else EmojiImage(d, size: 28, photo: false),
        if (!has) Text('$kDecalCost', style: shopText(11, color: const Color(0xFFE67700))),
      ]), (G.decal[c.id]) == d, Colors.white, () {
        if (has) {
          setState(() => d == null ? G.decal.remove(c.id) : G.decal[c.id] = d);
          widget.ctx.audio.sfx('tap');
          save();
        } else {
          pay(kDecalCost, 'decal-$d', () {
            G.decals.add(d);
            G.decal[c.id] = d;
          });
        }
      });
    }).toList();
    final its = kShopItems.map((k) {
      final n = G.ip[k]!;
      return row(kRItems[k]!.$1, n, kIpMax, n >= kIpMax ? maxTag() : buy(ipCost(n), 'ip-$k', () => G.ip[k] = n + 1));
    }).toList();
    final nb = 1 + U['bag']!;
    final bag = Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
      for (var i = 0; i < nb; i++)
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: i < G.items.length ? const Color(0xFFFFE066) : const Color(0xFFE9ECEF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
          child: i < G.items.length ? EmojiImage(kRItems[G.items[i]]!.$1, size: 38, photo: false) : null,
        ),
    ]);
    return ShopFrame(colors: const [Color(0xFF74C0FC), Color(0xFFE7F5FF)], children: [
      Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('🏎️ Gara', style: shopText(30, color: const Color(0xFF343A40))),
        ShakeBox(trigger: shakes['coins'] ?? 0, child: CoinPill(G.coins, dark: false)),
        PlayBtn(onTap: () => go(c), color: const Color(0xFFFA5252), shade: const Color(0x40000000)),
      ]),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: slots),
      ShopBox(
        light: true,
        title: Row(children: [const EmojiImage('Hammer and wrench', size: 36, photo: false), const SizedBox(width: 8), Text(c.vi, style: shopText(22, color: const Color(0xFF343A40)))]),
        child: Wrap(spacing: 8, runSpacing: 8, children: ups),
      ),
      ShopBox(
        light: true,
        title: const EmojiImage('Artist palette', size: 36, photo: false),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [...sws, const SizedBox(width: 12), ...dcs]),
      ),
      ShopBox(
        light: true,
        title: Row(children: [const EmojiImage('Wrapped gift', size: 36, photo: false), const SizedBox(width: 8), bag]),
        child: Wrap(spacing: 8, runSpacing: 8, children: its),
      ),
    ]);
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.g, this.frame, this.hero, this.decal);
  final Gfx g;
  final String frame;
  final Costume hero;
  final String? decal;
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height * .9, w = h * 66 / 122;
    drawCar(canvas, g, g.sh('racing/racing'), size.width / 2, size.height / 2, w, h, frame, hero: hero, decal: decal);
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) => old.frame != frame || old.decal != decal;
}

// ---------- Game ----------
class RaceEnd {
  RaceEnd(this.win, this.score, this.pos, this.earn, this.carry);
  final bool win;
  final int score, pos, earn;
  final Json carry;
}

class _Ai {
  _Ai(this.d, this.off, this.base, this.color, this.spr, this.num);
  double d, off, v = 0, ph = rnd(0, 6), spin = 0, slow = 0;
  final double base;
  final int color, num;
  final String spr;
}

class _It {
  _It(this.d, this.off, this.k);
  double d, off;
  final String k;
}

class _Rocket {
  _Rocket(this.d, this.x, this.v, this.life, this.turn);
  double d, x, v, life, rot = 0;
  final double turn;
  _Ai? target;
}

class _Scen {
  _Scen(this.d, this.side, this.gap, this.k, this.ken, this.s, [this.tri = false]);
  final double d, side, gap, s;
  final String k;
  final bool ken, tri;
}

class RacerGame extends ActGame {
  RacerGame({required this.ctx, required super.gfx, required RacerGear gear, required String carId})
      : G = gear,
        super(audio: ctx.audio, lv: ctx.level) {
    base = kCars.firstWhere((c) => c.id == carId, orElse: () => kCars.first);
  }
  final FunGameContext ctx;
  final RacerGear G;
  late final CarDef base;
  late final SpriteSheet? rs = gfx.sh('racing/racing'), fxs = gfx.sh('fxa/fx'), robotS = gfx.sh('toon/robot'), sp = gfx.sh('space/space');
  late final FunTheme th = funTheme(lv);
  late final int goalPos = lv < 8 ? 3 : (lv < 20 ? 2 : 1);
  late final String goalTxt = goalPos == 1 ? 'Về nhất' : 'Về top $goalPos';
  late final Costume hero = heroOf(ctx.heroImg);

  // Xe trong màn = chỉ số gốc + nâng cấp
  late Map<String, int> U;
  late Map<String, int> P;
  late String paintId, mySpr;
  String? myDecal;
  late double vmaxC, accC, gripC, robotC;
  late int carColor, slots;
  late double nitroDur, gp;
  late Json g0;
  late double carW, carH, rw, meY;
  late int len;
  late List<(int, String)> ais;

  // me
  double d = 0, x = 0, v = 0, vx = 0, nitro = 0, spin = 0, ang = 0, steer = 0, shield = 0, magnet = 0, robot = 0, morph = 0, air = 0, slow = 0, bump = 0, gold = 0, fly = 0, inv = 0;
  double? tx;
  int coins = 0, hits = 0, tanks = 0, armor = 0, armor0 = 0;
  List<String> bag = [], hidden = [];
  final Map<String, double> tmax = {};

  late List<_Ai> ai;
  final List<_It> items = [], traps = [];
  final List<_Scen> scen = [];
  final List<_Rocket> rockets = [], botR = [];
  final List<(double, double)> skids = [];
  late final Fx F = Fx(gfx);
  final Dust D = Dust(260);
  late final Booms B = Booms(gfx, fxs);
  final Shaker SH = Shaker();
  double vPrev = 0, brake = 0, botCd = 3;
  int lastSaved = 0;
  late double atkOil, atkRkt;
  double t = -3.2, endT = 0, roulette = 0, flash = 0, popItem = 0;
  int lastBeep = 4;
  RaceEnd? end;
  final List<_Ai> finishOrder = [];
  late double btnR;
  late Offset btn;
  late (double, double, double) nbtn;
  late List<(double, double, double)> sbtn;

  static double hsh(double n) {
    final x = math.sin(n * 127.1) * 43758.5453;
    return x - x.floorToDouble();
  }

  double cx(double dd) => W / 2 + W * .13 * math.sin(dd * .0009) + W * .09 * math.sin(dd * .00037 + 1.3);
  double ix(_It it) => cx(it.d) + it.off * rw;
  bool get flying => air > 0 || fly > 0;
  bool get tough => robot > 0 || shield > 0 || gold > 0;
  int place() => 1 + ai.where((a) => a.d > d).length;

  @override
  void setup() {
    U = G.up[base.id]!;
    P = G.ip;
    paintId = G.paint[base.id] ?? base.paint;
    vmaxC = base.vmax + U['eng']! * 22;
    accC = base.acc + U['acc']! * .14;
    gripC = base.grip + U['grip']! * 55;
    robotC = base.robot;
    carColor = kPaints[paintId] ?? base.color;
    mySpr = G.sprOf(base);
    myDecal = G.decal[base.id];
    slots = 1 + U['bag']!;
    nitroDur = 1.3 + U['nitro']! * .2;
    gp = (U['eng']! + U['acc']! + U['grip']! + U['nitro']! + U['armor']!) / 24 + (base.vmax - 550) / 400;
    g0 = G.toJson();
    carW = math.max(46, math.min(70, W * .075));
    carH = carW * 1.75;
    rw = math.min(W * .34, 260);
    len = ramp(lv, 20000, 34000).round();
    meY = H * .72;
    ais = _aiSpr.where((e) => !e.$2.startsWith('car_${paintId}_')).take(5).toList();
    x = cx(0) + rw * .3;
    bag = G.items.take(slots).toList();
    hidden = G.items.skip(slots).toList();
    tanks = 1 + (U['nitro']! / 2).ceil();
    armor = armor0 = U['armor']! + base.armor;
    const starts = [(220.0, -.5), (220.0, .1), (420.0, -.2), (420.0, .5), (620.0, 0.0)];
    ai = [
      for (var i = 0; i < 5; i++)
        _Ai(starts[i].$1, starts[i].$2, rnd(470, 540) + ramp(lv, -40, 105) + gp * ramp(lv, 15, 75), ais[i % ais.length].$1, ais[i % ais.length].$2, i + 2),
    ];
    atkOil = lv >= 5 ? ramp(lv, .01, .05) + gp * .01 : 0;
    atkRkt = lv >= 14 ? ramp(lv, .02, .07) + gp * .015 : 0;
    const ken = ['tree_large', 'tree_small', 'tree_large', 'tent_red', 'tent_blue', 'tires_red', 'tires_white', 'barrel_red', 'barrel_blue', 'rock1'];
    for (var dd = 300.0; dd < len + 800; dd += rnd(60, 120)) {
      final isK = rnd01() < .55, k = isK ? pickOf(ken) : pickOf(th.deco);
      final s = isK ? (k.startsWith('tree') ? rnd(80, 130) : k.startsWith('tent') ? rnd(70, 95) : rnd(30, 44)) : rnd(58, 96);
      scen.add(_Scen(dd, rnd01() < .5 ? -1 : 1, isK && k.startsWith('tire') ? rnd(0, 20) : rnd(10, 160), k, isK, s));
    }
    for (var dd = 1600.0; dd < len; dd += rnd(2600, 4200)) {
      scen.add(_Scen(dd, rnd01() < .5 ? -1 : 1, 30, 'tribune_full', true, 110, true));
    }
    for (var dd = 900.0; dd < len - 400; dd += rnd(420, 700)) {
      final r = math.min(.999, rnd01() + ramp(lv, 0, .16)), off = rnd(-.65, .65);
      if (r < .38) {
        for (var k = 0; k < 5; k++) {
          items.add(_It(dd + k * 70, off, 'coin'));
        }
      } else if (r < .58) {
        for (final o in [-.55, 0.0, .55]) {
          items.add(_It(dd, o, 'box'));
        }
      } else if (r < .7) {
        items.add(_It(dd, off, 'boost'));
      } else if (r < .78) {
        items.add(_It(dd, off, 'ramp'));
      } else if (r < .9) {
        items.add(_It(dd, off, 'oil'));
      } else {
        items.add(_It(dd, -.4, 'cone'));
        items.add(_It(dd + 260, .4, 'cone'));
      }
    }
    btnR = math.min(62, S * .1);
    btn = Offset(W - btnR - 22, H - btnR - 22);
    nbtn = (btn.dx - btnR * 2.35, btn.dy + btnR * .15, btnR * .78);
    sbtn = [(btn.dx, btn.dy, btnR), for (final i in [1, 2]) (btn.dx, btn.dy - btnR * (1.75 + (i - 1) * 1.45), btnR * .62)];
  }

  // ---- Cảm ứng ----
  Object _hitBtn(double px, double py) {
    if (hypot(px - btn.dx, py - btn.dy) < btnR * 1.15) return 0;
    for (var i = 1; i < slots; i++) {
      if (hypot(px - sbtn[i].$1, py - sbtn[i].$2) < sbtn[i].$3 * 1.2) return i;
    }
    if (hypot(px - nbtn.$1, py - nbtn.$2) < nbtn.$3 * 1.2) return 'n';
    return -1;
  }

  @override
  void down(Ptr p) {
    final b = _hitBtn(p.x, p.y);
    if (b == 'n') return useNitro();
    if (b is int && b >= 0) return useItem(b);
    tx = p.x;
  }

  @override
  void move(Ptr p) {
    if (_hitBtn(p.x, p.y) == -1) tx = p.x;
  }

  @override
  void up(Ptr p) => tx = null;

  @override
  void onStop() => audio.engine(0);

  // ---- Đồ ----
  Json build([int extra = 0]) => {
        ...RacerGear.from(g0).toJson(),
        'coins': (g0['coins'] as int) + coins + extra,
        'items': [...bag, ...hidden].take(kBagMax).toList(),
      };
  void saveMid() {
    ctx.saveGear(build());
    lastSaved = coins;
  }

  void giveItem() {
    if (bag.length >= slots || roulette > 0) return;
    roulette = .9;
    sfx('coin');
  }

  void fireRocket([double off = 0]) {
    final pr = P['rocket']!;
    rockets.add(_Rocket(d + carH * .6, x + off, v + 620 + pr * 60, 3 + pr * .4, 6.0 + pr * 2));
    sfx('shoot');
    D.puff(x + off, meY - carH * .5, 4, const Color(0xFFF0F0F0), 50, 7);
  }

  void timed(String k, double s) {
    final cur = _get(k);
    _set(k, math.max(cur, s));
    tmax[k] = _get(k);
  }

  double _get(String k) => switch (k) { 'nitro' => nitro, 'shield' => shield, 'magnet' => magnet, 'robot' => robot, 'gold' => gold, 'fly' => fly, _ => 0 };
  void _set(String k, double val) {
    switch (k) {
      case 'nitro':
        nitro = val;
      case 'shield':
        shield = val;
      case 'magnet':
        magnet = val;
      case 'robot':
        robot = val;
      case 'gold':
        gold = val;
      case 'fly':
        fly = val;
    }
  }

  void useNitro() {
    if (tanks <= 0 || end != null || t < 0) {
      if (t >= 0 && end == null) sfx('tap');
      return;
    }
    tanks--;
    timed('nitro', nitroDur);
    sfx('power');
    SH.add(4);
    F.text(x, meY - carH, 'NITRO!', 0xff922b);
  }

  void useItem([int i = 0]) {
    if (i >= bag.length || end != null || t < 0) return;
    final k = bag.removeAt(i);
    final p = P[k == 'triple' ? 'rocket' : k] ?? 0, m = 1 + p * .25;
    popItem = .3;
    saveMid();
    F.text(x, meY - carH, kRItems[k]!.$2, 0xffd43b);
    switch (k) {
      case 'rocket':
        fireRocket();
        if (p >= 3) later(.18, () => fireRocket(carW * .5));
      case 'triple':
        fireRocket(-carW * .6);
        later(.15, () => fireRocket(0));
        later(.3, () => fireRocket(carW * .6));
      case 'shield':
        timed('shield', 7 * m);
        sfx('power');
      case 'magnet':
        timed('magnet', 8 * m);
        sfx('power');
      case 'turbo':
        timed('nitro', 3 * m);
        sfx('power');
        SH.add(4);
      case 'robot':
        timed('robot', robotC * (1 + p * .2));
        morph = .7;
        sfx('win');
        F.burst(x, meY, 30, [0xbe4bdb, 0xffd43b, 0x4dabf7]);
        B.add(x, meY, carH * 1.2, 'smoke');
      case 'zap':
        final dur = 2.5 + p * .8;
        flash = .35;
        sfx('boom');
        SH.add(6);
        for (final a in ai) {
          if (a.d > d) {
            a.slow = dur;
            final ay = meY - (a.d - d);
            if (ay > -40) D.sparks(cx(a.d) + a.off * rw, ay, 10, 0xffe066, 260);
          }
        }
      case 'bomb':
        final n = 1 + p;
        for (var j = 0; j < n; j++) {
          traps.add(_It(d - carH * (.8 + j * 1.1), clamp((x - cx(d)) / rw + (j % 2 == 1 ? .35 : -.35) * (j > 0 ? 1 : 0), -.8, .8), 'trap'));
        }
        sfx('pop');
        B.add(x, meY + carH * .7, 70, 'smoke');
      case 'gold':
        timed('gold', 6 * m);
        sfx('win');
        F.burst(x, meY, 30, [0xffd43b, 0xfab005, 0xffffff]);
      case 'fly':
        timed('fly', 2.6 * (1 + p * .3));
        sfx('jump');
        D.puff(x, meY + carH * .4, 8, const Color(0xFFDCDCDC), 90, 9);
    }
  }

  bool absorb(double px, double py) {
    if (armor <= 0) return false;
    armor--;
    inv = .8;
    sfx('hit');
    F.text(px, py - 30, 'KENG!', 0x74c0fc);
    D.sparks(px, py, 12, 0xa5d8ff, 260);
    SH.add(3);
    return true;
  }

  void knock(_Ai a, double push) {
    a.spin = 1.2;
    a.v *= .3;
    a.off = clamp(a.off + push * .4, -.85, .85);
    final ax = cx(a.d) + a.off * rw, ay = meY - (a.d - d);
    B.add(ax, ay, carH * 1.1);
    D.sparks(ax, ay, 14, 0xffd43b, 320);
    D.puff(ax, ay, 6, const Color(0xFF5A5A5A), 70, 10);
    sfx('boom');
    hits++;
    SH.add(7);
  }

  @override
  Object? step(double dt) {
    t += dt;
    SH.update(dt);
    D.update(dt);
    B.update(dt);
    popItem = math.max(0, popItem - dt);
    if (t < 0) {
      final n = (-t).ceil();
      if (n < lastBeep) {
        lastBeep = n;
        sfx('tap');
      }
      F.update(dt);
      if (rnd01() < .5) D.emit(x + rnd(-6, 6), meY + carH * .5, rnd(-20, 20), rnd(30, 70), life: .5, r: 4, grow: 14, a: .5);
      return null;
    }
    if (lastBeep > 0) {
      lastBeep = 0;
      sfx('power');
      SH.add(3);
      for (var k = 0; k < 10; k++) {
        D.emit(x + rnd(-carW * .4, carW * .4), meY + carH * .5, rnd(-60, 60), rnd(60, 160), life: .7, r: 6, grow: 24, c: const Color(0xFFD2D2D2), a: .6);
      }
    }
    if (end != null) {
      endT += dt;
      F.update(dt);
      audio.engine(math.max(0, .3 - endT * .3));
      if (endT > 2.4) {
        audio.engine(0);
        return end;
      }
      return null;
    }
    if (roulette > 0) {
      roulette -= dt;
      if (roulette <= 0) {
        if (bag.length < slots) bag.add(pickOf(_boxPool));
        sfx('power');
        popItem = .35;
        saveMid();
      }
    }
    final roadX = cx(d), off = x - roadX, onRoad = off.abs() < rw - carW * .35;
    final isRobot = robot > 0, fl = flying;
    var vmax = isRobot ? vmaxC + 170 : vmaxC;
    if (gold > 0) vmax += 90;
    if (fly > 0) vmax += 60;
    if (nitro > 0) vmax = math.max(vmax, 860);
    if (!onRoad && !isRobot && !fl && gold <= 0) vmax = 250;
    if (slow > 0) vmax *= .55;
    v += (vmax - v) * math.min(1, dt * (v < vmax ? accC : 3));
    if (spin > 0) {
      spin -= dt;
      v *= 1 - dt * 1.5;
    }
    nitro = math.max(0, nitro - dt);
    shield = math.max(0, shield - dt);
    magnet = math.max(0, magnet - dt);
    robot = math.max(0, robot - dt);
    morph = math.max(0, morph - dt);
    air = math.max(0, air - dt);
    slow = math.max(0, slow - dt);
    bump = math.max(0, bump - dt);
    gold = math.max(0, gold - dt);
    fly = math.max(0, fly - dt);
    inv = math.max(0, inv - dt);
    if (isRobot && robot < .05) {
      F.burst(x, meY, 20);
      sfx('pop');
      B.add(x, meY, carH, 'smoke');
    }
    d += v * dt;
    final tgx = tx ?? x;
    final want = clamp((tgx - x) * 8, -gripC, gripC);
    vx = approach(vx, want, gripC / 70, dt);
    x += vx * dt;
    x = clamp(x + (cx(d) - roadX), roadX - rw - 80, roadX + rw + 80);
    final lean = vx / 2600 + (cx(d + 200) - cx(d)) / 900;
    ang = spin > 0 ? spin * 8 : approach(ang, lean, 10, dt);
    steer = approach(steer, vx / gripC * .45, 12, dt);
    brake = clamp(brake + ((v < vPrev - 2 || slow > 0) ? dt * 6 : -dt * 3));
    vPrev = v;
    meY = approach(meY, H * (.7 + math.min(1, v / 860) * .07), 2, dt);
    final hard = vx.abs() > gripC * .7 || spin > 0;
    if (onRoad && !fl && hard && v > 250) {
      skids.add((d - carH * .3, x - cx(d) - carW * .38));
      skids.add((d - carH * .3, x - cx(d) + carW * .38));
      if (skids.length > 400) skids.removeRange(0, 2);
      if (rnd01() < .5) D.emit(x + (rnd01() < .5 ? -1 : 1) * carW * .4, meY + carH * .3, rnd(-30, 30), rnd(40, 100), life: .6, r: 5, grow: 22, c: const Color(0xFFEBEBEB), a: .45);
    }
    if (rnd01() < .5) {
      if (nitro > 0) {
        D.emit(x + rnd(-5, 5), meY + carH * .52, rnd(-15, 15), v * .25 + rnd(20, 60), life: .3, r: 5, grow: 6, c: hex(pickOf([0xffa94d, 0xffe066, 0xff6b6b])), a: .9);
      } else {
        D.emit(x + rnd(-5, 5), meY + carH * .52, rnd(-15, 15), v * .25 + rnd(20, 60), life: .5, r: 3, grow: 12, c: hex(0xadb5bd), a: .45);
      }
    }
    if (!onRoad && !isRobot && !fl && v > 80) {
      D.emit(x + rnd(-carW * .4, carW * .4), meY + carH * .45, rnd(-40, 40), rnd(60, 140), life: .45, r: 3, grow: 10, c: hex(pickOf([0x8ce99a, 0x69db7c, 0xc3a06b])), a: .8);
    }
    if (isRobot && rnd01() < .3) D.emit(x + rnd(-carW * .4, carW * .4), meY + carH * .4, rnd(-50, 50), rnd(80, 160), life: .4, r: 4, grow: 10, c: const Color(0xFFC8B48C), a: .6);
    if (gold > 0 && rnd01() < .4) D.emit(x + rnd(-carW * .6, carW * .6), meY + rnd(-carH * .5, carH * .5), 0, rnd(40, 90), life: .5, r: 4, grow: 2, c: hex(pickOf([0xffd43b, 0xfff3bf])), a: 1);
    audio.engine(math.min(1, v / 860));
    // Đối thủ
    botCd -= dt;
    for (final a in ai) {
      a.ph += dt;
      final gap = a.d - d;
      final band = gap > 600 ? .88 : (gap < -600 ? 1.12 : 1.0);
      if (a.slow > 0) a.slow -= dt;
      if (a.spin > 0) {
        a.spin -= dt;
        a.v *= 1 - dt * 2;
      } else {
        a.v += (a.base * band * (a.slow > 0 ? .5 : 1) * (1 + .06 * math.sin(a.ph * .7)) - a.v) * math.min(1, dt * (a.slow > 0 ? 2 : .8));
      }
      a.d += a.v * dt;
      a.off = clamp(a.off + math.sin(a.ph * .4) * .1 * dt, -.8, .8);
      final ax = cx(a.d) + a.off * rw, ay = meY - (a.d - d);
      if (rnd01() < .25 && ay > -carH && ay < H + carH) D.emit(ax + rnd(-4, 4), ay + carH * .52, rnd(-10, 10), rnd(20, 50), life: .4, r: 3, grow: 10, c: hex(0xadb5bd), a: .4);
      if (a.spin <= 0 && a.slow <= 0 && a.d < len - 300) {
        if (gap > 250 && gap < 1100 && rnd01() < atkOil * dt) {
          items.add(_It(a.d - carH, a.off, 'oil'));
          if (ay > 0) F.text(ax, ay - 30, 'Dầu!', 0xced4da);
        }
        if (gap < -150 && gap > -700 && botCd <= 0 && rnd01() < atkRkt * dt * 5) {
          botCd = ramp(lv, 5, 2.6);
          botR.add(_Rocket(a.d + carH * .6, ax, a.v + 300, 4, 0));
          sfx('shoot');
        }
      }
      if (!fl && (ay - meY).abs() < carH * .85 && (ax - x).abs() < carW * .9 && a.spin <= 0 && (inv <= 0 || tough)) {
        final push = x < ax ? 1.0 : -1.0;
        if (tough) {
          knock(a, push);
          F.text(ax, ay - 30, isRobot ? 'BỤP!' : 'BẬT!', 0xffd43b);
          if (gold > 0) coins += 2;
        } else if (absorb((x + ax) / 2, (meY + ay) / 2)) {
          a.v *= .85;
          x -= push * 26;
          vx = -push * 380;
          bump = .25;
          a.d += ay < meY ? 10 : -10;
        } else {
          x -= push * 26;
          vx = -push * 380;
          v *= .82;
          a.v *= .95;
          SH.add(5);
          bump = .25;
          sfx('hit');
          D.sparks((x + ax) / 2, (meY + ay) / 2, 10, 0xffe066, 260);
          a.d += ay < meY ? 6 : -6;
        }
      }
      for (var j = traps.length - 1; j >= 0; j--) {
        final tr = traps[j];
        if (a.spin <= 0 && (a.d - tr.d).abs() < carH * .5 && (a.off - tr.off).abs() * rw < carW * .9) {
          traps.removeAt(j);
          knock(a, 0);
          if (ay > -40 && ay < H + 40) F.text(ax, ay - 30, 'TRƠN!', 0xffd43b);
        }
      }
      if (a.d >= len && !finishOrder.contains(a)) finishOrder.add(a);
    }
    final minAi = ai.map((a) => a.d).reduce(math.min);
    for (var j = traps.length - 1; j >= 0; j--) {
      if (traps[j].d < minAi - 300 || traps.length > 14) traps.removeAt(j);
    }
    // Tên lửa của bé
    for (var i = rockets.length - 1; i >= 0; i--) {
      final r = rockets[i];
      r.life -= dt;
      r.d += r.v * dt;
      if (r.target == null || r.target!.spin > 0) {
        final c = ai.where((a) => a.d > r.d - 50 && a.d - r.d < 1400 && a.spin <= 0).toList()..sort((p, q) => p.d.compareTo(q.d));
        r.target = c.firstOrNull;
      }
      final px = r.x;
      if (r.target != null) {
        final txx = cx(r.target!.d) + r.target!.off * rw;
        r.x += (txx - r.x) * math.min(1, dt * r.turn);
      } else {
        r.x += (cx(r.d) - r.x) * math.min(1, dt * 2);
      }
      r.rot = math.atan2(r.x - px, math.max(1, r.v * dt));
      final ry = meY - (r.d - d);
      D.emit(r.x + rnd(-3, 3), ry + 22, rnd(-15, 15), rnd(30, 80), life: .5, r: 4, grow: 14, c: const Color(0xFFF0F0F0), a: .6);
      if (rnd01() < .6) D.emit(r.x, ry + 18, 0, 60, life: .15, r: 5, grow: 2, c: hex(pickOf([0xffa94d, 0xffe066])), a: 1);
      final hitA = ai.where((a) => a.spin <= 0 && (a.d - r.d).abs() < carH * .7 && (cx(a.d) + a.off * rw - r.x).abs() < carW).firstOrNull;
      if (hitA != null) {
        knock(hitA, 0);
        F.text(r.x, ry - 30, 'TRÚNG!', 0xff6b6b);
        rockets.removeAt(i);
        continue;
      }
      if (r.life <= 0 || r.d > d + H * 1.5) rockets.removeAt(i);
    }
    // Tên lửa của xe máy
    for (var i = botR.length - 1; i >= 0; i--) {
      final r = botR[i];
      r.life -= dt;
      r.d += r.v * dt;
      final px = r.x;
      r.x += (x - r.x) * math.min(1, dt * 1.3);
      r.rot = math.atan2(r.x - px, math.max(1, r.v * dt));
      final ry = meY - (r.d - d);
      if (rnd01() < .5) D.emit(r.x + rnd(-3, 3), ry + 22, rnd(-15, 15), rnd(30, 80), life: .4, r: 4, grow: 12, c: const Color(0xFFF0F0F0), a: .5);
      if (!fl && (r.d - d).abs() < carH * .6 && (r.x - x).abs() < carW * .7) {
        botR.removeAt(i);
        B.add(x, meY - carH * .3, carH);
        if (tough) {
          sfx('boom');
          F.text(x, meY - carH, 'BẬT!', 0xffd43b);
        } else if (!absorb(x, meY - carH * .3)) {
          spin = .8;
          v *= .5;
          sfx('boom');
          SH.add(8);
          F.text(x, meY - carH, 'Ối!', 0xff6b6b);
        }
        continue;
      }
      if (r.life <= 0 || r.d > d + H) botR.removeAt(i);
    }
    // Vật phẩm trên đường
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i], iy = meY - (it.d - d);
      if (iy > H + 60) {
        items.removeAt(i);
        continue;
      }
      if (iy < -H) continue;
      var ixx = ix(it);
      if (it.k == 'coin' && magnet > 0 && iy > meY - 380 && iy < meY + 40) {
        it.off += ((x - ixx) / rw) * math.min(1, dt * 6);
        ixx = ix(it);
        it.d -= (it.d - d) * math.min(1, dt * 4);
      }
      final near = (iy - meY).abs() < carH * .55 && (ixx - x).abs() < carW * .8;
      if (!near) continue;
      if (fl && it.k != 'coin' && it.k != 'box') continue;
      switch (it.k) {
        case 'coin':
          items.removeAt(i);
          coins++;
          sfx('coin');
          F.text(ixx, iy - 20, '+1', 0xffd43b);
          D.sparks(ixx, iy, 6, 0xffe066, 160);
          if (coins - lastSaved >= 10) saveMid();
        case 'box':
          items.removeAt(i);
          F.burst(ixx, iy, 14, [0xff6b6b, 0xffd43b, 0x4dabf7, 0x69db7c]);
          D.sparks(ixx, iy, 10, 0xffffff, 220);
          giveItem();
        case 'boost':
          nitro = math.max(nitro, 1.4);
          sfx('power');
          F.text(ixx, iy - 30, 'VÙÙ!', 0xff922b);
          items.removeAt(i);
          SH.add(3);
        case 'ramp':
          air = .9;
          sfx('jump');
          F.text(ixx, iy - 30, 'BAY!', 0x4dabf7);
          items.removeAt(i);
          D.puff(x, meY + carH * .4, 6, const Color(0xFFDCDCDC), 80, 8);
        case 'oil':
          items.removeAt(i);
          if (!tough && nitro <= 0 && !absorb(ixx, iy)) {
            spin = .8;
            sfx('hit');
            F.text(ixx, iy - 30, 'Trơn quá!', 0xced4da);
          }
        case 'cone':
          items.removeAt(i);
          D.debris(ixx, iy, 10, 0xff922b, 280);
          if (tough) {
            sfx('boom');
            F.text(ixx, iy - 30, 'ĐẬP TAN!', 0xffd43b);
            coins += 2;
            B.add(ixx, iy, 80);
            SH.add(4);
          } else if (!absorb(ixx, iy)) {
            slow = .9;
            sfx('hit');
            SH.add(5);
            bump = .25;
          }
      }
    }
    if ((air > 0 && air < dt * 1.5) || (fly > 0 && fly < dt * 1.5)) {
      SH.add(4);
      D.puff(x, meY + carH * .3, 8, const Color(0xFFDCDCDC), 90, 9);
    }
    flash = math.max(0, flash - dt);
    if (d >= len) {
      final pos = 1 + finishOrder.length;
      final bonus = pos < 7 ? const [0, 30, 20, 10, 5, 3, 2][pos] : 0, earn = pos < _rankCoins.length ? _rankCoins[pos] : 0;
      end = RaceEnd(pos <= goalPos, coins + bonus + hits * 2, pos, coins + earn, build(earn));
      sfx(pos <= 3 ? 'win' : 'pop');
      F.burst(x, meY, 40);
      for (var k = 0; k < 40; k++) {
        D.emit(rnd(0, W), -10, rnd(-60, 60), rnd(120, 320), life: 2.2, r: 5, grow: 0, c: hex(pickOf([0xffd43b, 0xff6b6b, 0x4dabf7, 0x69db7c, 0xffffff])), k: 2, g: 120, a: 1);
      }
    }
    F.update(dt);
    return null;
  }

  // ---------- Vẽ ----------
  late final int _ns = ((H + 32) / 10).ceil() + 1;
  late final List<double> _rowsY = List.generate(_ns, (i) => -16.0 + i * 10);
  late final List<double> _rowsC = List.filled(_ns, 0);

  void _strip(Canvas c, double a, double b, Color col) {
    final path = Path()..moveTo(_rowsC[0] + a, _rowsY[0]);
    for (var i = 1; i < _ns; i++) {
      path.lineTo(_rowsC[i] + a, _rowsY[i]);
    }
    for (var i = _ns - 1; i >= 0; i--) {
      path.lineTo(_rowsC[i] + b, _rowsY[i]);
    }
    c.drawPath(path, fillP(col));
  }

  double yOf(double dd) => meY - (dd - d);
  void _quad(Path p, double d0, double d1, double a, double b) {
    final y0 = yOf(d0), y1 = yOf(d1), c0 = cx(d0), c1 = cx(d1);
    p
      ..moveTo(c0 + a, y0)
      ..lineTo(c0 + b, y0)
      ..lineTo(c1 + b, y1)
      ..lineTo(c1 + a, y1)
      ..close();
  }

  @override
  void paint(Canvas c) {
    c.save();
    SH.apply(c);
    for (var i = 0; i < _ns; i++) {
      _rowsC[i] = cx(d + (meY - _rowsY[i]));
    }
    final dTop = d + meY + 8, dBot = d + meY - H - 8;
    rect(c, 0, 0, W, H, Color(th.ground));
    for (var dd = (dBot / 160).floorToDouble() * 160 + 80; dd < dTop; dd += 160) {
      final y1 = yOf(dd), y0 = yOf(dd + 80);
      rect(c, 0, y0, W, y1 - y0, rgba(0, 0, 0, .05));
    }
    for (var dd = (dBot / 22).ceilToDouble() * 22; dd < dTop; dd += 22) {
      final r1 = hsh(dd / 22), r2 = hsh(dd / 22 + 7.3);
      final side = r1 < .5 ? -1 : 1, gx = cx(dd) + side * (rw + 50 + r2 * math.min(220, W * .25));
      if (gx > 0 && gx < W) circle(c, gx, yOf(dd), r2 > .4 ? 4 : 7, r2 > .7 ? hex(0xffd43b) : (r2 > .4 ? hex(0xff8787) : rgba(43, 138, 62, .55)));
    }
    _strip(c, -rw - 34, -rw - 14, rgba(233, 196, 106, .85));
    _strip(c, rw + 14, rw + 34, rgba(233, 196, 106, .85));
    _strip(c, -rw - 14, -rw, hex(0xf8f9fa));
    _strip(c, rw, rw + 14, hex(0xf8f9fa));
    final kerb = Path();
    for (var dd = (dBot / 72).floorToDouble() * 72 + 36; dd < dTop; dd += 72) {
      _quad(kerb, dd, dd + 36, -rw - 14, -rw);
      _quad(kerb, dd, dd + 36, rw, rw + 14);
    }
    c.drawPath(kerb, fillP(hex(0xe03131)));
    _strip(c, -rw - 3, -rw, rgba(0, 0, 0, .18));
    _strip(c, rw + 11, rw + 14, rgba(0, 0, 0, .18));
    _strip(c, -rw, rw, hex(0x525962));
    _strip(c, -rw, -rw * .72, rgba(0, 0, 0, .14));
    _strip(c, rw * .72, rw, rgba(0, 0, 0, .14));
    _strip(c, -rw, -rw * .88, rgba(0, 0, 0, .08));
    _strip(c, rw * .88, rw, rgba(0, 0, 0, .08));
    final lanes = Path();
    for (var dd = (dBot / 140).floorToDouble() * 140 + 70; dd < dTop; dd += 140) {
      _quad(lanes, dd, dd + 70, -rw / 3 - 3, -rw / 3 + 3);
      _quad(lanes, dd, dd + 70, rw / 3 - 3, rw / 3 + 3);
    }
    c.drawPath(lanes, fillP(rgba(255, 255, 255, .85)));
    for (final (d0, d1) in [(0.0, 36.0), (len.toDouble(), len + 48.0)]) {
      if (d1 < dBot || d0 > dTop) continue;
      for (var dd = d0; dd < d1; dd += 12) {
        for (var k = 0; k < 2 * rw / 18; k++) {
          final y = yOf(dd + 12);
          rect(c, cx(dd) - rw + k * 18, y, 18, 12.5, (k + (dd / 12).floor()) % 2 == 1 ? Colors.white : hex(0x212529));
        }
      }
    }
    for (final k in skids) {
      final ky = meY - (k.$1 - d);
      if (ky > -10 && ky < H + 10) rect(c, cx(k.$1) + k.$2 - 3, ky - 3, 6, 7, rgba(20, 20, 20, .28));
    }
    final finY = meY - (len - d);
    if (finY > -120 && finY < H + 80) {
      final fc = cx(len.toDouble());
      rect(c, fc - rw - 30, finY - 12, rw * 2 + 70, 26, rgba(0, 0, 0, .25));
      rect(c, fc - rw - 34, finY - 70, 14, 80, hex(0x495057));
      rect(c, fc + rw + 20, finY - 70, 14, 80, hex(0x495057));
      fillRR(c, fc - rw - 34, finY - 92, rw * 2 + 68, 40, 10, hex(0xe03131));
      Txt.draw(c, '🏁 VỀ ĐÍCH 🏁', fc, finY - 62, size: 28);
    }
    final tt = clock;
    for (final tr in traps) {
      final ty = yOf(tr.d);
      if (ty < -60 || ty > H + 60) continue;
      final px = cx(tr.d) + tr.off * rw;
      gfx.spr(c, rs, 'oil', px, ty, 64, rot: tr.d % 6);
      strokeCircle(c, px, ty, 36, rgba(255, 107, 107, .5 + .4 * math.sin(tt * 8)), 4);
    }
    for (final it in items) {
      final iy = meY - (it.d - d);
      if (iy < -60 || iy > H + 60) continue;
      final px = ix(it);
      switch (it.k) {
        case 'coin':
          gfx.coin(c, fxs, tt + it.d * .01, px, iy, 34);
        case 'box':
          final bob = math.sin(tt * 5 + it.off * 5);
          ellipse(c, px + 4, iy + 22, 20 - bob * 3, 7, rgba(0, 0, 0, .2));
          c.save();
          c.translate(px, iy - 6 - bob * 6);
          c.rotate(math.sin(tt * 3 + it.off * 5) * .2);
          final hue = (tt * 120 + it.off * 200) % 360;
          fillRR(c, -22, -22, 44, 44, 9, hsl(hue, .85, .6));
          c.drawRRect(rr(-22, -22, 44, 44, 9), strokeP(Colors.white, 3));
          Txt.draw(c, '?', 0, 11, size: 30);
          c.restore();
        case 'boost':
          fillRR(c, px - 36, iy - 42, 72, 84, 12, rgba(255, 146, 43, .55));
          for (var k = 0; k < 3; k++) {
            final ph = ((tt * 2.2 + k / 3) % 1);
            gfx.spr(c, rs, 'arrow_yellow', px, iy + 26 - ph * 60, 30, alpha: math.sin(ph * math.pi));
          }
        case 'ramp':
          final path = Path()
            ..moveTo(px - 46, iy + 30)
            ..lineTo(px + 46, iy + 30)
            ..lineTo(px + 34, iy - 30)
            ..lineTo(px - 34, iy - 30)
            ..close();
          c.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, iy + 30), Offset(0, iy - 30), [hex(0x5c940d), hex(0xffd43b)]));
          gfx.spr(c, rs, 'arrow_white', px, iy, 26);
        case 'oil':
          gfx.spr(c, rs, 'oil', px, iy, 52, rot: it.d % 6);
        case 'cone':
          gfx.spr(c, rs, 'cone_straight', px - 14, iy, 36);
          gfx.spr(c, rs, 'cone_straight', px + 14, iy + 6, 36);
      }
    }
    for (final a in ai) {
      final ay = meY - (a.d - d);
      if (ay <= -carH || ay >= H + carH) continue;
      final ax = cx(a.d) + a.off * rw;
      drawCar(c, gfx, rs, ax, ay, carW, carH, a.spr,
          num: a.num, ang: a.spin > 0 ? a.spin * 9 : math.sin(a.ph * .4) * .06, steer: math.cos(a.ph * .4) * .2, brake: a.spin > 0 || a.slow > 0 ? 1 : 0);
      if (a.slow > 0) gfx.draw(c, 'Cloud with lightning', ax, ay - carH * .62 + math.sin(tt * 9) * 3, 46);
    }
    D.draw(c);
    for (final r in rockets) {
      gfx.spr(c, sp, 'missile', r.x, meY - (r.d - d), 44, rot: r.rot);
    }
    for (final r in botR) {
      final ry = meY - (r.d - d);
      if (ry > H - 10) {
        final path = Path()
          ..moveTo(r.x, H - 46)
          ..lineTo(r.x - 18, H - 14)
          ..lineTo(r.x + 18, H - 14)
          ..close();
        c.drawPath(path, fillP(rgba(250, 82, 82, .6 + .4 * math.sin(tt * 14))));
        Txt.draw(c, '!', r.x, H - 18, size: 22);
      } else {
        circle(c, r.x, ry, 26, rgba(250, 82, 82, .35));
        gfx.spr(c, sp, 'missile', r.x, ry, 40, rot: r.rot);
      }
    }
    if (nitro > 0) {
      for (final sx in [-carW * .2, carW * .2]) {
        final fl = carH * (.45 + rnd01() * .25), y0 = meY + carH * .5;
        final path = Path()
          ..moveTo(x + sx - 9, y0)
          ..quadraticBezierTo(x + sx, y0 + fl * 1.2, x + sx + 9, y0);
        c.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, y0), Offset(0, y0 + fl), [hex(0xfff3bf), hex(0xffa94d), rgba(240, 62, 62, 0)], [0, .3, 1]));
      }
    }
    if (v > 600) {
      final col = rgba(255, 255, 255, math.min(.5, (v - 600) / 400));
      for (var k = 0; k < 10; k++) {
        final lx = hsh(k + (tt * 8).floorToDouble()) * W, ly = hsh(k * 3.7 + (tt * 8).floorToDouble()) * H;
        line(c, lx, ly, lx, ly + 60, col, 3, StrokeCap.butt);
      }
    }
    final flyK = fly > 0 ? math.min(1.0, math.min(fly / .4, ((tmax['fly'] ?? 1) - fly) / .4)) : 0.0;
    final airK = math.max(air > 0 ? math.sin(air / .9 * math.pi) : 0.0, flyK);
    final bumpK = bump > 0 ? math.sin(bump / .25 * math.pi) * .08 : 0.0;
    if (fly > 0) {
      for (final sd in [-1.0, 1.0]) {
        gfx.draw(c, 'Wing', x + sd * carW * (.75 + airK * .2), meY - airK * 20 - carH * .05, carW * 1.1, carW * 1.1 * (.8 + .2 * math.sin(tt * 18)), sd > 0, 0, .4 + .6 * flyK);
      }
    }
    if (robot > 0 && morph <= .35 && robotS != null) {
      ellipse(c, x, meY + carH * .38, carW * .6, carH * .14, rgba(0, 0, 0, .22));
      gfx.anim(c, robotS, 'run', tt, x, meY + carH * .42 - airK * 20, carH * 1.15 * (1 + airK * .3), flip: vx < -40);
    } else if (!(inv > 0 && (tt * 16).floor() % 2 == 1)) {
      drawCar(c, gfx, rs, x, meY - airK * 20, carW, carH, mySpr,
          ang: ang + (morph > 0 ? morph * 12 : 0), hero: hero, scale: 1 + airK * .35 + bumpK, steer: steer, brake: brake, lift: airK, decal: myDecal);
    }
    if (morph > 0) {
      for (var k = 0; k < 3; k++) {
        gfx.draw(c, 'Sparkles', x + rnd(-40, 40), meY + rnd(-50, 50), 30);
      }
    }
    if (shield > 0) {
      final e = math.sin(tt * 6) * 3;
      c.drawOval(Rect.fromCenter(center: Offset(x, meY), width: (carW * .9 + e) * 2, height: (carH * .7 + e) * 2), strokeP(rgba(116, 192, 252, .5 + .3 * math.sin(tt * 10)), 5));
    }
    if (gold > 0) {
      final e = math.sin(tt * 8) * 4;
      c.drawOval(Rect.fromCenter(center: Offset(x, meY), width: (carW + e) * 2, height: (carH * .76 + e) * 2), strokeP(rgba(255, 212, 59, .7 + .3 * math.sin(tt * 12)), 8));
      gfx.draw(c, 'Glowing star', x, meY - carH * .8, 34, 34, false, tt * 3);
    }
    if (magnet > 0) gfx.draw(c, 'Magnet', x + carW * .7, meY - carH * .5, 30, 30, false, math.sin(tt * 8) * .3);
    B.draw(c);
    for (final sc in scen) {
      final sy2 = meY - (sc.d - d);
      if (sy2 < -130 || sy2 > H + 130) continue;
      final sx2 = cx(sc.d) + sc.side * (rw + 40 + sc.gap + sc.s / 2);
      if (sc.ken) {
        gfx.spr(c, rs, sc.k, sx2, sy2, sc.s, rot: sc.tri ? sc.side * math.pi / 2 : 0);
        continue;
      }
      ellipse(c, sx2 + sc.s * .15, sy2 + sc.s * .38, sc.s * .38, sc.s * .12, rgba(0, 0, 0, .18));
      gfx.draw(c, sc.k, sx2, sy2, sc.s);
    }
    F.draw(c);
    c.restore();
    if (flash > 0) rect(c, 0, 0, W, H, rgba(255, 255, 230, flash * 1.6));
    // HUD
    final pos = end?.pos ?? place();
    fillRR(c, 12, 10, 150, 64, 20, rgba(0, 0, 0, .35));
    Txt.draw(c, 'Hạng', 26, 36, size: 22, align: TA.left);
    Txt.draw(c, '$pos/6', 26, 66, size: 34, align: TA.left, color: pos == 1 ? hex(0xffd43b) : Colors.white);
    fillRR(c, 172, 10, 110, 44, 22, rgba(0, 0, 0, .35));
    gfx.spr(c, fxs, 'coin', 196, 32, 28);
    Txt.draw(c, '$coins', 216, 42, size: 26, align: TA.left);
    for (var k = 0; k < armor0; k++) {
      gfx.draw(c, 'Shield', 186 + k * 24.0, 68, 22, 22, false, 0, k < armor ? 1 : .25);
    }
    final bx = W - 26, by = 80.0, bh = H - 260;
    fillRR(c, bx - 6, by, 12, bh, 6, rgba(0, 0, 0, .3));
    for (final a in ai) {
      circle(c, bx, by + bh * (1 - math.min(1, a.d / len)), 6, hex(a.color));
    }
    final my = by + bh * (1 - math.min(1, d / len));
    circle(c, bx, my, 10, hex(carColor));
    strokeCircle(c, bx, my, 10, Colors.white, 3);
    gfx.draw(c, 'Chequered flag', bx, by - 18, 30);
    final bs = 1 + (popItem > 0 ? math.sin(popItem / .35 * math.pi) * .18 : 0);
    for (var i = slots - 1; i >= 0; i--) {
      final sb = sbtn[i], r = i == 0 ? btnR * bs : sb.$3, k = i < bag.length ? bag[i] : null;
      circle(c, sb.$1, sb.$2, r, k != null ? rgba(255, 212, 59, .85 + .15 * math.sin(tt * 8)) : rgba(255, 255, 255, .55));
      strokeCircle(c, sb.$1, sb.$2, r, Colors.white, i == 0 ? 5 : 4);
      if (i == bag.length && roulette > 0) {
        gfx.draw(c, kRItems[_itemKeys[(tt * 14).floor() % _itemKeys.length]]!.$1, sb.$1, sb.$2, r * 1.1);
      } else if (k != null) {
        gfx.draw(c, kRItems[k]!.$1, sb.$1, sb.$2, r * 1.2, r * 1.2, false, k == 'rocket' || k == 'triple' ? -math.pi / 4 : math.sin(tt * 6) * .12);
      } else {
        gfx.draw(c, 'Wrapped gift', sb.$1, sb.$2, r * .9, r * .9, false, 0, .45);
      }
    }
    circle(c, nbtn.$1, nbtn.$2, nbtn.$3, tanks > 0 ? rgba(255, 146, 43, .9) : rgba(255, 255, 255, .4));
    strokeCircle(c, nbtn.$1, nbtn.$2, nbtn.$3, Colors.white, 4);
    gfx.draw(c, 'Fuel pump', nbtn.$1, nbtn.$2 - 4, nbtn.$3 * 1.05, nbtn.$3 * 1.05, false, 0, tanks > 0 ? 1 : .4);
    circle(c, nbtn.$1 + nbtn.$3 * .72, nbtn.$2 + nbtn.$3 * .62, 15, hex(0x212529));
    Txt.draw(c, '$tanks', nbtn.$1 + nbtn.$3 * .72, nbtn.$2 + nbtn.$3 * .62 + 7, size: 20);
    var hy = 84.0;
    for (final (k, im) in const [('robot', 'Robot'), ('gold', 'Glowing star'), ('fly', 'Wing'), ('shield', 'Shield'), ('magnet', 'Magnet'), ('nitro', 'High voltage')]) {
      final val = _get(k);
      if (val <= 0) continue;
      fillRR(c, 72, hy, 130, 34, 17, rgba(0, 0, 0, .3));
      gfx.draw(c, im, 92, hy + 17, 26);
      fillRR(c, 110, hy + 11, 82 * math.min(1, val / (tmax[k] ?? 3)), 12, 6, hex(0xffd43b));
      hy += 40;
    }
    if (t < 0) {
      final n = (-t).ceil(), ph = -t - (-t).floor();
      fillRR(c, W / 2 - 90, H * .3 - 40, 180, 80, 20, hex(0x212529));
      const lights = [0xfa5252, 0xfab005, 0x40c057];
      for (var i = 0; i < 3; i++) {
        circle(c, W / 2 - 55 + i * 55, H * .3, 24, (3 - i) >= n ? hex(lights[i]) : hex(0x495057));
      }
      c.save();
      c.translate(W / 2, H / 2);
      final k = easeOutBack(math.min(1, (1 - ph) * 2.5));
      c.scale(k, k);
      c.translate(-W / 2, -H / 2);
      banner(c, W, H, n > 0 ? '$n' : 'ĐI!', 'Cấp ${lv + 1} · ${th.vi} · 🎯 $goalTxt');
      c.restore();
      final gearIc = [...bag.map((k) => kRItems[k]!.$1), for (var i = 0; i < tanks; i++) 'Fuel pump', for (var i = 0; i < armor; i++) 'Shield'];
      if (gearIc.isNotEmpty) {
        final gw = math.min(W - 40, gearIc.length * 48.0 + 24), gx = W / 2 - gw / 2, gy = H / 2 + 80, st = (gw - 24) / gearIc.length;
        fillRR(c, gx, gy, gw, 56, 28, rgba(0, 0, 0, .4));
        for (var i = 0; i < gearIc.length; i++) {
          gfx.draw(c, gearIc[i], gx + 12 + st * (i + .5), gy + 28, math.min(40, st - 4));
        }
      }
    } else if (t < .8) {
      c.saveLayer(Rect.fromLTWH(0, 0, W, H), Paint()..color = rgba(0, 0, 0, 1 - t / .8));
      c.translate(W / 2, H / 2);
      c.scale(1 + t, 1 + t);
      c.translate(-W / 2, -H / 2);
      banner(c, W, H, 'ĐI!');
      c.restore();
    }
    final e = end;
    if (e != null) {
      banner(c, W, H, e.win ? funEndText(true, lv) : '🏁 VỀ THỨ ${e.pos}', e.win ? 'Về thứ ${e.pos} · +${e.earn} xu' : 'Cần ${goalTxt.toLowerCase()} · +${e.earn} xu');
    }
  }
}
