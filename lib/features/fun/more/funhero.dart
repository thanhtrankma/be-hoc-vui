// ignore_for_file: non_constant_identifier_names, constant_identifier_names
// Siêu nhân diệt quái vật bản nâng cấp: 7 loại chưởng (thường, lửa xuyên, ba tia, băng làm chậm, sấm sét từ trời, bão xoáy hút quái,
// sóng đất), mỗi chưởng 5 cấp; giày tên lửa, khiên, nam châm, siêu chưởng nạp năng lượng; trùm có đòn dậm đất (nhảy qua sóng).
// Kho đồ giữ qua màn (ctx.carry): chưởng đã mở + cấp cao nhất, chưởng đang dùng, nâng cấp vĩnh viễn, xu, tên lửa/khiên còn lại, siêu chưởng đã nạp.
// Màn "Kho chưởng" (lớp Flutter phủ canvas) trước cấp đầu của lượt: chọn chưởng mang vào, dùng xu mua/nâng cấp.
// CHỦ: agent F. Port của reference/web/js/games/funhero.js.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/content/models.dart' show Json;
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/ui.dart' show EmojiImage, kFontFamily;
import 'package:be_vui_hoc/features/learn/creative/figure.dart' as fig;
import 'package:flutter/material.dart';

import 'kit/funkit.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funheroGames = {
  'hero': const FunCanvasModule('hero', hero),
};

class _Power {
  const _Power(this.c, this.vi, this.en, this.img);
  final String c, vi, en, img;
}

const Map<String, _Power> _POWERS = {
  'basic': _Power('#ffe066', 'CHƯỞNG', 'BLAST', 'Collision'),
  'fire': _Power('#ff922b', 'CHƯỞNG LỬA', 'FIRE BLAST', 'Fire'),
  'triple': _Power('#ffd43b', 'BA TIA', 'TRIPLE SHOT', 'Glowing star'),
  'ice': _Power('#74c0fc', 'CHƯỞNG BĂNG', 'ICE BLAST', 'Snowflake'),
  'thunder': _Power('#fcc419', 'SẤM SÉT', 'THUNDER', 'Cloud with lightning'),
  'tornado': _Power('#63e6be', 'BÃO XOÁY', 'TORNADO', 'Tornado'),
  'quake': _Power('#d9480f', 'SÓNG ĐẤT', 'QUAKE', 'Volcano'),
};
final List<String> _PK = _POWERS.keys.toList();
const int _PMAX = 5;

class _Up {
  const _Up(this.img, this.vi, this.en, this.max, this.cost);
  final String img, vi, en;
  final int max;
  final int Function(int n) cost;
}

// Nâng cấp vĩnh viễn ở Kho chưởng (giá tăng theo cấp; chơi 2-4 lượt mua được 1 món)
final Map<String, _Up> _UPS = {
  'hp': _Up('Red heart', 'Máu', 'Health', 3, (n) => 250 * (n + 1)),
  'armor': _Up('Shield', 'Giáp', 'Armor', 3, (n) => 200 * (n + 1)),
  'rate': _Up('Comet', 'Bắn nhanh', 'Rapid fire', 4, (n) => 150 * (n + 1)),
  'super': _Up('High voltage', 'Siêu chưởng', 'Super blast', 4, (n) => 150 * (n + 1)),
  'dash': _Up('Running shoe', 'Lướt', 'Dash', 1, (_) => 300),
  'jump3': _Up('Wing', 'Nhảy 3 lần', 'Triple jump', 1, (_) => 300),
  'pound': _Up('Flexed biceps', 'Đấm đất', 'Ground pound', 1, (_) => 350),
};
const int _UNLOCK = 200, _ROCKET_COST = 60, _STOCK_MAX = 3;
int _lvCost(int n) => 100 + 60 * (n - 1);

/// +v của JS (chuỗi số, bool, null → 0; còn lại NaN).
double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v == null) return 0;
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? 0 : (double.tryParse(s) ?? double.nan);
  }
  return double.nan;
}

/// int(v, a, b) của web: Math.max(a, Math.min(b, Math.floor(+v) || 0)).
int _int(Object? v, int a, int b) {
  final d = _num(v);
  if (d.isNaN || d == 0) return math.max(a, math.min(b, 0));
  if (d.isInfinite) return d > 0 ? b : a;
  return math.max(a, math.min(b, d.floor()));
}

class _Gear {
  _Gear(this.coins, this.own, this.power, this.up, this.fly, this.shield, this.charge);
  int coins, fly, shield;
  final Map<String, int> own, up;
  String power;
  double charge;
  Json out(double ch) => {
        'v': 1,
        'coins': coins,
        'own': {...own},
        'power': power,
        'up': {...up},
        'fly': fly,
        'shield': shield,
        'charge': (ch * 100).round() / 100,
      };
}

// Đọc kho đồ phòng thủ: thiếu trường thì mặc định; chưởng thường luôn có (sàn 1).
_Gear _norm(Object? c0) {
  final c = c0 is Map ? c0 : const {};
  final o = c['own'] is Map ? c['own'] as Map : const {}, u = c['up'] is Map ? c['up'] as Map : const {};
  final own = <String, int>{}, up = <String, int>{};
  for (final k in _PK) {
    own[k] = _int(o[k], 0, _PMAX);
  }
  own['basic'] = math.max(1, own['basic']!);
  for (final k in _UPS.keys) {
    up[k] = _int(u[k], 0, _UPS[k]!.max);
  }
  final p = c['power'];
  final ch = _num(c['charge']);
  return _Gear(_int(c['coins'], 0, 10000000), own, p is String && (own[p] ?? 0) > 0 ? p : 'basic', up, _int(c['fly'], 0, _STOCK_MAX),
      _int(c['shield'], 0, _STOCK_MAX), ch.isNaN ? 0 : math.max(0, math.min(1, ch)));
}

/// norm() của web (kho đồ chuẩn hoá) — để test.
@visibleForTesting
Json heroNorm(Object? carry) {
  final g = _norm(carry);
  return g.out(g.charge);
}

// ---------- Màn Kho chưởng ----------
class _Armory extends StatefulWidget {
  const _Armory({required this.G, required this.save, required this.g, required this.onPlay});
  final _Gear G;
  final VoidCallback save, onPlay;
  final Fun g;
  @override
  State<_Armory> createState() => _ArmoryState();
}

const _ink = Color(0xFF23324D);
const List<double> _gray = [.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0];

class _ArmoryState extends State<_Armory> {
  _Gear get G => widget.G;
  Tr get tr => widget.g.tr;

  TextStyle _st(double size, {Color color = Colors.white, FontWeight w = FontWeight.w800}) =>
      TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: w, color: color, height: 1.1);

  Widget _stars(int n, int m) => Text.rich(TextSpan(children: [
        TextSpan(text: '★' * n, style: _st(17, color: const Color(0xFFF59F00))),
        TextSpan(text: '★' * math.max(0, m - n), style: _st(17, color: const Color(0xFFCED4DA))),
      ]));

  Widget _buy(String key, int cost, VoidCallback act) {
    final dis = G.coins < cost;
    return GestureDetector(
      key: Key('hero-buy-$key'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (G.coins < cost) return;
        G.coins -= cost;
        act();
        widget.g.sfx('power');
        widget.save();
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: dis ? const Color(0xFFADB5BD) : const Color(0xFF2F9E44), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const EmojiImage('Coin', size: 20, photo: false),
          const SizedBox(width: 3),
          Text('$cost', style: _st(17)),
        ]),
      ),
    );
  }

  Widget _max() => Padding(padding: const EdgeInsets.only(top: 2), child: Text('MAX', style: _st(17, color: const Color(0xFF2F9E44))));

  Widget _card({Key? key, required String img, required String name, required Widget stars, required Widget action, bool on = false, bool off = false, VoidCallback? onTap}) {
    Widget icon = EmojiImage(img, size: 58, photo: false);
    if (off) icon = Opacity(opacity: .35, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_gray), child: icon));
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFF9DB) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: on ? const Color(0xFFFFD43B) : Colors.transparent, width: 4),
            boxShadow: const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 5))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(height: 2),
            Text(name, textAlign: TextAlign.center, style: _st(15, color: _ink)),
            const SizedBox(height: 2),
            stars,
            action,
          ]),
        ),
        if (on)
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFF2F9E44), shape: BoxShape.circle),
              child: Text('✔', style: _st(18)),
            ),
          ),
      ]),
    );
  }

  /// grid-template-columns: repeat(auto-fill, minmax(112px, 1fr)); gap 10; max-width 900.
  Widget _grid(List<Widget> cards) => LayoutBuilder(builder: (context, cons) {
        final w = math.min(900.0, cons.maxWidth);
        final n = math.max(1, ((w + 10) / 122).floor());
        final cw = (w - 10 * (n - 1)) / n;
        return Center(
          child: SizedBox(
            width: w,
            child: Wrap(spacing: 10, runSpacing: 10, children: [for (final c in cards) SizedBox(width: cw, child: c)]),
          ),
        );
      });

  Widget _sec(String s) => Padding(padding: const EdgeInsets.fromLTRB(0, 14, 0, 6), child: Opacity(opacity: .9, child: Text(s, style: _st(18.5))));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final powers = [
      for (final k in _PK)
        () {
          final P = _POWERS[k]!, n = G.own[k]!;
          return _card(
            key: Key('hero-power-$k'),
            img: P.img,
            name: tr(P.vi, P.en),
            stars: _stars(n, _PMAX),
            on: G.power == k,
            off: n == 0,
            onTap: () {
              if (n == 0) return;
              G.power = k;
              widget.g.sfx('pop');
              widget.save();
              setState(() {});
            },
            action: n == 0
                ? _buy(k, _UNLOCK, () {
                    G.own[k] = 1;
                    G.power = k;
                  })
                : n < _PMAX
                    ? _buy(k, _lvCost(n), () => G.own[k] = n + 1)
                    : _max(),
          );
        }(),
    ];
    final ups = [
      for (final e in _UPS.entries)
        () {
          final k = e.key, U = e.value, n = G.up[k]!;
          return _card(
            key: Key('hero-up-$k'),
            img: U.img,
            name: tr(U.vi, U.en),
            stars: _stars(n, U.max),
            off: n == 0,
            action: n < U.max ? _buy('up-$k', U.cost(n), () => G.up[k] = n + 1) : _max(),
          );
        }(),
      _card(
        key: const Key('hero-up-rocket'),
        img: 'Rocket',
        name: tr('Giày tên lửa', 'Rocket shoes'),
        stars: Text(G.fly > 0 ? '🚀' * G.fly : '0', style: _st(17, color: const Color(0xFFF59F00))),
        off: G.fly == 0,
        action: G.fly < _STOCK_MAX ? _buy('rocket', _ROCKET_COST, () => G.fly++) : _max(),
      ),
    ];
    return Container(
      key: const Key('hero-armory'),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4263EB), Color(0xFF1C7ED6)])),
      child: Stack(children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12 + pad.left, 64 + pad.top, 12 + pad.right, 110 + pad.bottom),
            child: Column(children: [
              Text(tr('🦸 Kho chưởng', '🦸 Power armory'), textAlign: TextAlign.center, style: _st(32).copyWith(shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 3))])),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const EmojiImage('Coin', size: 38, photo: false),
                  const SizedBox(width: 6),
                  Text('${G.coins}', key: const Key('hero-coins'), style: _st(29)),
                ]),
              ),
              _sec(tr('👆 Chọn chưởng mang vào', '👆 Pick the power to bring')),
              _grid(powers),
              _sec(tr('💪 Nâng cấp', '💪 Upgrades')),
              _grid(ups),
            ]),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8 + pad.bottom,
          child: Center(
            child: GestureDetector(
              key: const Key('hero-play'),
              onTap: () {
                widget.g.sfx('power');
                widget.onPlay();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD43B),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [BoxShadow(color: Color(0xFFE67700), offset: Offset(0, 6))],
                ),
                child: Text(tr('Chơi ▶', 'Play ▶'), style: _st(32, color: _ink)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------- Thực thể ----------
class _Box {
  _Box(this.x, this.y, this.w, this.h);
  double x, y, w, h;
}

bool _hit(_Box a, _Box b, [double s = .7]) => hitBox(a.x, a.y, a.w, a.h, b.x, b.y, b.w, b.h, s);

class _Foe extends _Box {
  _Foe(this.k, double x, double y, double w, double h, {this.v = 0, this.ph = 0, this.hp = 1, this.pts = 2, this.rock = false})
      : super(x, y, w, h);
  final String k;
  double v, ph, hp, slow = 0, flash = 0, ty = 0;
  int pts;
  bool float = false, drop = false;
  final bool rock;
}

class _Shot extends _Box {
  _Shot(super.x, super.y, super.w, super.h, this.vx, this.vy, this.dmg, this.k,
      {this.pierce = 0, this.freeze = 0, this.splash = 0, this.sweep = false, this.pull = 0});
  final double vx, vy, dmg, freeze, splash, pull;
  final String k;
  int pierce;
  final bool sweep;
  bool hitBoss = false;
  Set<_Foe>? hitSet;
}

class _Item extends _Box {
  _Item(this.k, double x, double y) : super(x, y, 54, 54);
  final String k;
}

class _Fire extends _Box {
  _Fire(double x, double y, this.vx, this.vy) : super(x, y, 46, 46);
  double vx, vy;
}

class _Wave extends _Box {
  _Wave(double x, double y, this.v) : super(x, y, 60, 36);
  final double v;
}

class _Boss extends _Box {
  _Boss(this.k, double x, double y, double w, double h, this.hp) : max = hp, super(x, y, w, h);
  final String k;
  double hp, cd = 2, ph = 0, flash = 0, stomp = 5;
  final double max;
}

class _Me {
  _Me(this.x, this.y, this.w, this.h, this.power);
  double x, y, w, h, vy = 0, inv = 0, cd = 0, punch = 0, fly = 0, shield = 0, magnet = 0, dash = 0, dashCd = 0;
  int jumps = 0;
  String power;
  bool pound = false;
}

class _Cloud {
  _Cloud(this.x, this.y, this.s);
  double x, y;
  final double s;
}

class _Bolt {
  _Bolt(this.x, this.y, this.w);
  final double x, y, w;
  double life = .3;
}

class _Ring {
  _Ring(this.x);
  final double x;
  double life = .45;
}

class _Bldg {
  _Bldg(this.x, this.w, this.h, this.c);
  final double x, w, h;
  final String c;
}

class _Btn {
  const _Btn(this.x, this.y);
  final double x, y;
}

Future<LoopGame> hero(Fun g) async {
  // Cấp: quái nhanh và dày hơn, trùm nhiều máu và đánh dồn dập hơn; trùm đổi Ogre/Rồng mỗi 10 cấp.
  final lv = g.level, th = theme(lv), bossK = (lv ~/ 10) % 2 == 1 ? 'Dragon' : 'Ogre', tr = g.tr;
  final G = _norm(g.ctx.carry);
  var charge = G.charge;
  Json out() => G.out(charge);
  void save() => g.ctx.saveGear(out());
  // Kho chưởng chỉ hiện ở cấp đầu của lượt (web: opts.heroArmory dùng chung các cấp của một vé = ctx.ticket)
  if (g.ctx.ticket['heroArmory'] != true) {
    g.ctx.ticket['heroArmory'] = true;
    await g.overlay<bool>((context, close) => _Armory(G: G, save: save, g: g, onPlay: () => close(true)));
  }
  const FOES = ['Alien monster', 'Ghost', 'Bat', 'Goblin', 'Spider'];
  final (sh, _) = await (
    sheets(['plat/enemies', 'plat/tiles', 'plat/bg', 'fxa/fx', 'creatures/flyers']),
    loadAll([g.hero, ...FOES, 'Ogre', 'Dragon', th.sun, 'Rock', 'Construction', 'Coin', 'Fire', 'Red heart', 'Cloud', 'Sun with face', 'Glowing star',
      'Snowflake', 'Rocket', 'Shield', 'Magnet', 'High voltage', 'Collision', 'Cloud with lightning', 'Tornado', 'Volcano', 'Running shoe', 'Wing', 'Flexed biceps', 'Comet']),
  ).wait;
  final en = sh[0], tl = sh[1], bgs = sh[2], fxs = sh[3], fly = sh[4];
  // Quái là sinh vật Kenney có hoạt ảnh (khoá luật chơi vẫn theo tên cũ)
  const LOOK = {'Alien monster': 'slime', 'Ghost': 'fly', 'Bat': 'bee', 'Goblin': 'sslime', 'Spider': 'ladybug'};
  final D = dust(260), B = booms(fxs), SH = shaker();
  double land = 0, runDust = 0;
  var wasAir = false;
  final c = g.c, W = g.W, H = g.H;
  final ground = H * .8, S = math.min(W, H), HX = W * .2;
  final me = _Me(HX, ground, S * .17, S * .17, G.power);
  final shots = <_Shot>[], foes = <_Foe>[], coins = <_Box>[], fire = <_Fire>[], waves = <_Wave>[], items = <_Item>[], clouds = <_Cloud>[];
  final bolts = <_Bolt>[], rings = <_Ring>[], F = fx();
  final city = List.generate(14, (i) => _Bldg(i * 110.0, rand(70, 110), rand(H * .15, H * .4), pick(const ['#a5d8ff', '#bac8ff', '#d0bfff', '#99e9f2'])));
  for (var i = 0; i < 5; i++) {
    clouds.add(_Cloud(rand(0, W), rand(20, H * .25), rand(70, 120)));
  }
  // Sức mạnh đồ (0..1): quái/trùm tăng máu nhẹ theo đồ để cấp cao vẫn thử thách
  final best = _PK.map((k) => G.own[k]!).reduce((a, b) => math.max(a, b)), ownSum = _PK.fold<int>(0, (a, k) => a + G.own[k]!) - 1;
  final gp = math.min(1.0, (best - 1) / 4 * .5 + ownSum / 34 * .15 + (G.up['hp']! + G.up['armor']! + G.up['rate']! + G.up['super']!) / 14 * .35);
  final maxLives = lives0 + G.up['hp']!, cdM = 1 - .08 * G.up['rate']!, maxJ = G.up['jump3']! > 0 ? 3 : 2, sup = G.up['super']!;
  var score = 0, lives = maxLives, armor = G.up['armor']!;
  double t = 0, spawn = 1.5, endT = 0, scroll = 0, beam = 0;
  var holdUp = false;
  _Boss? boss;
  ({bool win, int score})? end;
  final btnR = math.min(66.0, S * .105), sR = btnR * .72;
  final jumpBtn = _Btn(btnR + 24, H - btnR - 20), shotBtn = _Btn(W - btnR - 24, H - btnR - 20), superBtn = _Btn(W - btnR - 24, H - btnR * 3.4 - 20);
  final dashBtn = _Btn(jumpBtn.x, jumpBtn.y - btnR * 2.3), swapBtn = _Btn(shotBtn.x - btnR * 2.25, shotBtn.y);
  final rocketBtn = _Btn(superBtn.x - btnR * 1.9, superBtn.y), shieldBtn = _Btn(superBtn.x - btnR * 3.5, superBtn.y);
  List<String> owned() => _PK.where((k) => G.own[k]! > 0).toList();
  void earn(int n) => G.coins += n;
  String pname(String k) => tr(_POWERS[k]!.vi, _POWERS[k]!.en);
  void jump() {
    if (me.fly > 0) {
      holdUp = true;
      return;
    }
    if (me.jumps < maxJ) {
      me.vy = -math.sqrt(2 * 2600 * H * .3) * (me.jumps > 0 ? .85 : 1);
      me.jumps++;
      me.pound = false;
      g.sfx('jump');
    }
    // Đấm đất: hết lượt nhảy mà còn trên không thì chạm nhảy để lao xuống
    else if (G.up['pound']! > 0 && !me.pound && me.y < ground - 30) {
      me.pound = true;
      me.vy = 2400;
      g.sfx('shoot');
    }
  }

  void dash() {
    if (G.up['dash']! == 0 || me.dashCd > 0) return;
    me.dash = .35;
    me.dashCd = 1.2;
    g.sfx('shoot');
    F.text(me.x, me.y - me.h * 1.2, tr('LƯỚT!', 'DASH!'), '#63e6be');
  }

  void swap() {
    final o = owned();
    if (o.length < 2) return;
    me.power = o[(o.indexOf(me.power) + 1) % o.length];
    G.power = me.power;
    g.sfx('pop');
    F.text(me.x + me.w, me.y - me.h * 1.2, pname(me.power), _POWERS[me.power]!.c);
  }

  void drop(double x, double y) {
    coins.add(_Box(x, y - 10, 36, 36));
    final r = random();
    if (r < .09) {
      items.add(_Item(pick(_PK), x, y - 40));
    } else if (r < .12) {
      items.add(_Item('fly', x, y - 40));
    } else if (r < .145) {
      items.add(_Item('shield', x, y - 40));
    } else if (r < .165) {
      items.add(_Item('heart', x, y - 40));
    } else if (r < .185) {
      items.add(_Item('magnet', x, y - 40));
    }
  }

  final ITEM_IMG = <String, String>{'fly': 'Rocket', 'shield': 'Shield', 'heart': 'Red heart', 'magnet': 'Magnet', for (final k in _PK) k: _POWERS[k]!.img};
  void kill(_Foe f) {
    B.add(f.x, f.y, f.w * 1.4);
    D.sparks(f.x, f.y, 12, '#ffe066', 300);
    SH.add(3);
    F.star(f.x, f.y);
    g.sfx('boom');
    score += f.pts;
    F.text(f.x, f.y - 30, '+${f.pts}', '#ffd43b');
    charge = math.min(1, charge + .12 * (1 + sup * .15));
    drop(f.x, f.y);
  }

  // Đánh một quái (đá thì vỡ luôn); xoá khỏi danh sách nếu chết
  void hitFoe(_Foe f, double dmg, String col) {
    final j = foes.indexOf(f);
    if (j < 0) return;
    if (f.rock) {
      D.debris(f.x, f.y, 12, '#868e96', 320);
      B.add(f.x, f.y, f.w * 1.2, 'smoke');
      foes.removeAt(j);
      score++;
      return;
    }
    f.hp -= dmg;
    if (f.hp <= 0) {
      kill(f);
      foes.removeAt(j);
    } else {
      D.sparks(f.x, f.y, 6, col, 200);
      f.flash = .1;
      f.x += 14;
    }
  }

  void shoot() {
    if (me.cd > 0 || beam > 0 || shots.length > 36) return;
    me.punch = .18;
    g.sfx('shoot');
    final y = me.y - me.h * .55, x = me.x + me.w * .4, p = me.power, L = math.max(1, G.own[p] ?? 1), li = L - 1;
    if (p == 'basic') {
      me.cd = .28;
      final n = const [1, 2, 2, 3, 3][li], sz = 30.0 + L * 5;
      for (var i = 0; i < n; i++) {
        shots.add(_Shot(x, y + (i - (n - 1) / 2) * 26, sz, sz, 760, 0, const [1.0, .8, 1.0, .8, 1.0][li], p));
      }
    } else if (p == 'fire') {
      me.cd = .38;
      final sz = 44.0 + L * 10;
      shots.add(_Shot(x, y, sz, sz, 620, 0, 1 + L * .5, p, pierce: 2 + L));
    } else if (p == 'triple') {
      me.cd = .3;
      final n = const [3, 3, 5, 5, 7][li], sz = 24.0 + L * 3;
      for (var i = 0; i < n; i++) {
        shots.add(_Shot(x, y, sz, sz, 720, (i - (n - 1) / 2) * (n > 5 ? 110 : 150), const [.5, .6, .6, .7, .7][li], p));
      }
    } else if (p == 'ice') {
      me.cd = .3;
      final sz = 32.0 + L * 6;
      shots.add(_Shot(x, y, sz, sz, 700, 0, .8 + L * .4, p, freeze: 1.5 + L * .5, splash: L >= 4 ? S * (L >= 5 ? .3 : .22) : 0));
    } else if (p == 'thunder') {
      // Sấm sét đánh từ trời xuống quái gần nhất (cấp cao đánh nhiều quái cùng lúc)
      me.cd = .55;
      final n = const [1, 1, 2, 2, 3][li], dmg = 1.5 + L * .6, bw = 5.0 + L * 3;
      final tg = (foes.where((f) => f.x > me.x && f.x < W + 10).toList()..sort((a, b) => a.x.compareTo(b.x))).take(n).toList();
      for (final f in tg) {
        bolts.add(_Bolt(f.x, f.y, bw));
        hitFoe(f, dmg, _POWERS['thunder']!.c);
      }
      final bs = boss;
      if (bs != null && tg.length < n) {
        bolts.add(_Bolt(bs.x, bs.y, bw));
        bs.hp -= dmg;
        bs.flash = .1;
        D.sparks(bs.x, bs.y - bs.h * .3, 8, '#fff3bf', 260);
      }
      if (tg.isEmpty && boss == null) bolts.add(_Bolt(me.x + W * .35, ground, bw));
      SH.add(2.0 + L);
      while (bolts.length > 12) {
        bolts.removeAt(0);
      }
    } else if (p == 'tornado') {
      me.cd = .7;
      final sz = 56.0 + L * 14;
      shots.add(_Shot(x, ground - sz / 2, sz, sz, 320, 0, 1 + L * .5, p, sweep: true, pull: S * (.22 + L * .05)));
    } else {
      me.cd = .6;
      final hg = S * (.1 + L * .035);
      shots.add(_Shot(x, ground - hg / 2, 60.0 + L * 8, hg, 650, 0, 1.2 + L * .5, 'quake', sweep: true));
      D.debris(x, ground, 6 + L * 2, '#8d5524', 300);
      SH.add(2.0 + L);
    }
    me.cd *= cdM;
  }

  void superMove() {
    if (charge < 1 || beam > 0) return;
    charge = 0;
    beam = 1.6 + sup * .4;
    g.sfx('win');
    SH.add(12.0 + sup * 2);
    F.text(W / 2, H * .3, tr('SIÊU CHƯỞNG!', 'SUPER BLAST!'), '#ffd43b');
  }

  void useRocket() {
    if (G.fly < 1 || me.fly > 0) return;
    G.fly--;
    me.fly = 8;
    g.sfx('power');
    F.text(me.x, me.y - me.h * 1.2, tr('GIÀY TÊN LỬA!', 'ROCKET SHOES!'), '#ff922b');
  }

  void useShield() {
    if (G.shield < 1 || me.shield > 0) return;
    G.shield--;
    me.shield = 10;
    g.sfx('power');
    F.text(me.x, me.y - me.h * 1.2, tr('KHIÊN!', 'SHIELD!'), '#74c0fc');
  }

  bool near(double x, double y, _Btn b, [double? r]) => hypot(x - b.x, y - b.y) < (r ?? btnR);
  g.onDown((e) {
    final x = e.x, y = e.y;
    if (near(x, y, superBtn)) return superMove();
    if (G.up['dash']! > 0 && near(x, y, dashBtn)) return dash();
    if (owned().length > 1 && near(x, y, swapBtn, sR * 1.15)) return swap();
    if (G.fly > 0 && near(x, y, rocketBtn, sR * 1.1)) return useRocket();
    if (G.shield > 0 && near(x, y, shieldBtn, sR * 1.1)) return useShield();
    if (x < W / 2) {
      jump();
    } else {
      shoot();
    }
  });
  g.onUp((_) => holdUp = false);
  g.onCancel((_) => holdUp = false);

  final hpM = 1 + gp * .6;
  _Foe makeFoe() {
    final sz = S * .14, k = pick(t < 20 ? const ['Alien monster', 'Ghost', 'Bat'] : FOES), hp0 = (1 + lv ~/ 20) * hpM;
    _Foe base(double y, {double? hp, int pts = 2}) => _Foe(k, W + 80, y, sz, sz, v: rand(20, 70) + ramp(lv, 0, 70), ph: rand(0, 6), hp: hp ?? hp0, pts: pts);
    if (k == 'Bat') return base(ground - S * .3, pts: 3);
    if (k == 'Ghost') return base(ground - S * .2)..float = true;
    if (k == 'Goblin') return base(ground - sz / 2, hp: hp0 + hpM, pts: 4);
    if (k == 'Spider') {
      return base(-sz, pts: 3)
        ..drop = true
        ..ty = ground - S * rand(.15, .35);
    }
    return base(ground - sz / 2);
  }

  void hurt() {
    if (me.inv > 0 || me.dash > 0) return;
    if (me.shield > 0) {
      me.shield = 0;
      me.inv = 1;
      g.sfx('pop');
      return;
    }
    if (armor > 0) {
      armor--;
      me.inv = 1.2;
      g.sfx('pop');
      SH.add(5);
      F.text(me.x, me.y - me.h * 1.2, tr('GIÁP!', 'ARMOR!'), '#74c0fc');
      return;
    }
    lives--;
    me.inv = 1.8;
    g.sfx('hit');
    SH.add(9);
    D.sparks(me.x, me.y - me.h / 2, 14, '#ff8787', 300);
    me.vy = math.min(me.vy, -500);
    me.pound = false;
    if (lives <= 0) end = (win: false, score: score);
  }

  // Tự chơi (chỉ test, g.bot): bắn liên tục, nhảy qua đá/sóng/quái sát người, dùng siêu chưởng khi đầy.
  void botPlay() {
    shoot();
    if (charge >= 1) superMove();
    if (me.y < ground - 2) return;
    final danger = waves.any((w) => w.x > me.x && w.x - me.x < S * .45) ||
        foes.any((f) => f.x > me.x && f.x - me.x < S * (f.rock ? .4 : .25) && f.y > ground - S * .25) ||
        fire.any((f) => (f.x - me.x).abs() < S * .3 && f.vy > 0);
    if (danger) jump();
  }

  return LoopGame(
    update: (dt) {
      t += dt;
      SH.update(dt);
      D.update(dt);
      B.update(dt);
      land = math.max(0, land - dt);
      for (var i = bolts.length - 1; i >= 0; i--) {
        if ((bolts[i].life -= dt) <= 0) bolts.removeAt(i);
      }
      for (var i = rings.length - 1; i >= 0; i--) {
        if ((rings[i].life -= dt) <= 0) rings.removeAt(i);
      }
      final e0 = end;
      if (e0 != null) {
        endT += dt;
        F.update(dt);
        if (endT > 2) {
          G.power = me.power;
          return FunEnd(win: e0.win, score: e0.score, carry: out());
        }
        return null;
      }
      if (g.bot) botPlay();
      final v = boss != null ? 0.0 : (230 + t * 1.5) * ramp(lv, 1, 1.35);
      scroll += v * dt;
      // Bay bằng giày tên lửa: giữ nửa trái để bay lên
      if (me.fly > 0) {
        me.fly -= dt;
        me.vy += (holdUp ? -1900 : 900) * dt;
        me.vy = math.max(-520, math.min(420, me.vy));
        if (random() < .8) D.emit(me.x - me.w * .2, me.y - me.h * .2, rand(-40, 0), rand(150, 260), life: .3, r: 5, grow: 6, c: random() < .5 ? '#ff922b' : '#ffd43b', a: .9);
      } else {
        me.vy += 2600 * dt;
      }
      me.y += me.vy * dt;
      if (me.y < me.h + 40) {
        me.y = me.h + 40;
        me.vy = 0;
      }
      if (me.y >= ground) {
        if (wasAir && me.vy > 300) {
          land = .18;
          D.puff(me.x, ground, 6, 'rgba(230,220,200,1)', 90, 7);
        }
        if (me.pound) {
          // Đấm đất: sóng chấn động hai bên, quái mặt đất gần đó trúng đòn
          me.pound = false;
          me.inv = math.max(me.inv, .3);
          SH.add(12);
          g.sfx('boom');
          rings.add(_Ring(me.x));
          D.debris(me.x, ground, 18, '#8d5524', 420);
          for (final f in [...foes]) {
            if ((f.x - me.x).abs() < S * .5 && f.y > ground - S * .32) hitFoe(f, 3, '#ffd43b');
          }
          final bs = boss;
          if (bs != null && (bs.x - me.x).abs() < S * .5 + bs.w / 2) {
            bs.hp -= 3;
            bs.flash = .1;
          }
        }
        me.y = ground;
        me.vy = 0;
        me.jumps = 0;
      }
      wasAir = me.y < ground - 2;
      // Lướt: phóng tới trước, chạm quái là hạ, xong thì từ từ về chỗ cũ
      if (me.dash > 0) {
        me.dash -= dt;
        me.x = math.min(W * .55, me.x + 1500 * dt);
        D.emit(me.x - me.w * .4, me.y - me.h * .5, -300, rand(-30, 30), life: .3, r: 8, grow: 8, c: 'rgba(99,230,190,1)', a: .6);
      } else {
        me.x += (HX - me.x) * math.min(1, dt * 2.5);
      }
      // Bụi chân khi chạy
      runDust -= dt;
      if (!wasAir && v > 0 && runDust <= 0) {
        runDust = .12;
        D.emit(me.x - me.w * .15, ground - 4, -v * .3 + rand(-20, 20), rand(-40, -10), life: .4, r: 4, grow: 10, c: 'rgba(230,220,200,1)', a: .6);
      }
      me.inv = math.max(0, me.inv - dt);
      me.cd = math.max(0, me.cd - dt);
      me.punch = math.max(0, me.punch - dt);
      me.shield = math.max(0, me.shield - dt);
      me.magnet = math.max(0, me.magnet - dt);
      me.dashCd = math.max(0, me.dashCd - dt);
      // Siêu chưởng: tia lớn quét ngang (nâng cấp: lâu hơn, to hơn, mạnh hơn)
      if (beam > 0) {
        beam -= dt;
        final by = me.y - me.h * .55, bh = S * .22 * (1 + sup * .12);
        for (var j = foes.length - 1; j >= 0; j--) {
          if (j >= foes.length) continue;
          final f = foes[j];
          if (f.x > me.x && (f.y - by).abs() < bh) {
            if (f.rock) {
              hitFoe(f, 1, '#fff');
            } else {
              kill(f);
              foes.remove(f);
            }
          }
        }
        final bs = boss;
        if (bs != null && (bs.y - by).abs() < bs.h) {
          bs.hp -= dt * (7 + sup * 3);
          bs.flash = .1;
        }
      }
      final bs0 = boss;
      if (bs0 == null) {
        spawn -= dt;
        if (spawn <= 0 && t < 55) {
          spawn = math.max(1, 1.8 - t / 60) * ramp(lv, 1, .68);
          final r = random(), sz = S * .14;
          if (r < .58) {
            foes.add(makeFoe());
          } else if (r < .78) {
            foes.add(_Foe(random() < .5 ? 'Rock' : 'Construction', W + 80, ground - sz * .4, sz * .9, sz * .8, rock: true));
          } else {
            final hgt = rand(.12, .45) * H;
            for (var k = 0; k < 5; k++) {
              coins.add(_Box(W + 60 + k * 60, ground - hgt - math.sin(k / 4 * math.pi) * 50, 40, 40));
            }
          }
        }
        if (t >= 55 && foes.isEmpty) {
          final hp = (ramp(lv, 40, 115) * (1 + gp)).roundToDouble();
          boss = _Boss(bossK, W + 200, ground - S * .2, S * .4, S * .4, hp);
          g.sfx('power');
          F.text(W / 2, H * .3, tr('QUÁI VẬT TRÙM!', 'BIG BOSS!'), '#ff6b6b');
        }
      } else {
        final bs = bs0;
        bs.ph += dt;
        bs.flash = math.max(0, bs.flash - dt);
        bs.x += (W * .78 - bs.x) * math.min(1, dt * 1.2);
        bs.y = ground - bs.h / 2 - (math.sin(bs.ph * 2)).abs() * 20;
        bs.cd -= dt;
        bs.stomp -= dt;
        final rage = bs.hp < bs.max / 2;
        if (bs.cd <= 0) {
          bs.cd = (rage ? rand(1, 1.5) : rand(1.4, 2.2)) * ramp(lv, 1, .65);
          for (var k = 0; k < (rage ? 2 : 1); k++) {
            fire.add(_Fire(bs.x - bs.w * .3, bs.y, -rand(260, 380), -rand(300, 650)));
          }
        }
        // Dậm đất: sóng chạy sát đất, bé phải nhảy qua
        if (bs.stomp <= 0) {
          bs.stomp = (rage ? 3 : 4.5) * ramp(lv, 1, .7);
          waves.add(_Wave(bs.x - bs.w * .4, ground - 18, 380));
          SH.add(10);
          D.debris(bs.x - bs.w * .3, ground, 14, '#8d5524', 360);
          g.sfx('boom');
          F.text(bs.x, bs.y - bs.h * .6, tr('RẦM!', 'STOMP!'), '#ff6b6b');
        }
        if (bs.hp <= 0) {
          for (var k = 0; k < 9; k++) {
            B.add(bs.x + rand(-bs.w * .4, bs.w * .4), bs.y + rand(-bs.h * .4, bs.h * .4), rand(100, 170));
          }
          SH.add(16);
          D.sparks(bs.x, bs.y, 30, '#ffd43b', 420);
          score += 40;
          earn(20);
          F.text(W / 2, H * .38, tr('+20 XU', '+20 COINS'), '#ffd43b');
          g.sfx('win');
          end = (win: true, score: score);
          boss = null;
          save();
        }
      }
      for (var i = shots.length - 1; i >= 0; i--) {
        final s = shots[i];
        s.x += s.vx * dt;
        s.y += s.vy * dt;
        if (s.x > W + 80 || s.y < -40 || s.y > H + 40) {
          shots.removeAt(i);
          continue;
        }
        final col = _POWERS[s.k]!.c;
        // Bão xoáy / sóng đất: đi xuyên, mỗi quái trúng một lần; bão hút quái lại gần
        if (s.sweep) {
          final hs = s.hitSet ??= <_Foe>{};
          for (var j = foes.length - 1; j >= 0; j--) {
            if (j >= foes.length) continue;
            final f = foes[j];
            if (s.pull > 0 && !f.rock && (f.x - s.x).abs() < s.pull && (f.y - s.y).abs() < s.pull * 1.4) {
              f.x += (s.x - f.x) * math.min(1, dt * 3);
              if (!f.float) f.y += (s.y - f.y) * math.min(1, dt * 2);
            }
            if (hs.contains(f) || !_hit(s, f, .85)) continue;
            hs.add(f);
            hitFoe(f, s.dmg, col);
          }
          final bs = boss;
          if (bs != null && _hit(s, bs, .8)) {
            if (s.k == 'tornado') {
              bs.hp -= s.dmg * 1.6 * dt;
              bs.flash = .08;
              if (random() < .3) D.sparks(bs.x - bs.w * .3, s.y, 3, col, 200);
            } else if (!s.hitBoss) {
              s.hitBoss = true;
              bs.hp -= s.dmg * 1.5;
              bs.flash = .1;
              D.debris(bs.x - bs.w * .3, ground, 8, '#8d5524', 300);
            }
          }
          continue;
        }
        var used = false;
        for (var j = foes.length - 1; j >= 0 && !used; j--) {
          if (j >= foes.length) continue;
          final f = foes[j];
          if (!_hit(s, f, .9) || (s.hitSet != null && s.hitSet!.contains(f))) continue;
          if (s.pierce > 0) {
            (s.hitSet ??= <_Foe>{}).add(f);
            if (--s.pierce <= 0) used = true;
          } else {
            used = true;
          }
          if (f.rock) {
            if (s.k == 'fire') {
              hitFoe(f, 1, col);
            } else {
              D.sparks(s.x, s.y, 6, '#ced4da', 200);
            }
            continue;
          }
          if (s.freeze > 0) {
            f.slow = s.freeze;
            if (s.splash > 0) {
              for (final o in foes) {
                if (!o.rock && hypot(o.x - f.x, o.y - f.y) < s.splash) o.slow = s.freeze;
              }
            }
          }
          hitFoe(f, s.dmg, col);
        }
        final bs = boss;
        if (!used && bs != null && _hit(s, bs, .8)) {
          used = true;
          bs.hp -= s.dmg;
          bs.flash = .08;
          D.sparks(s.x, s.y, 6, col, 220);
        }
        if (used) shots.removeAt(i);
      }
      final meBox = _Box(me.x, me.y - me.h / 2, me.w, me.h);
      for (var i = foes.length - 1; i >= 0; i--) {
        if (i >= foes.length) continue;
        final f = foes[i];
        f.ph += dt;
        f.slow = math.max(0, f.slow - dt);
        final sp = f.slow > 0 ? .35 : 1.0;
        f.x -= (v + f.v) * dt * (f.rock ? 1 : sp);
        if (f.k == 'Bat') f.y += math.sin(f.ph * 3) * 60 * dt;
        if (f.float) f.y = ground - S * .2 + math.sin(f.ph * 2) * S * .08;
        if (f.drop) f.y += (f.ty - f.y) * math.min(1, dt * 2);
        if (f.x < -120) {
          foes.removeAt(i);
          continue;
        }
        f.flash = math.max(0, f.flash - dt);
        if (_hit(meBox, f, .55)) {
          if (me.dash > 0) {
            hitFoe(f, 3, '#63e6be');
            continue;
          }
          hurt();
          if (!f.rock) {
            foes.remove(f);
            B.add(f.x, f.y, f.w * 1.2);
          }
        }
      }
      for (var i = coins.length - 1; i >= 0; i--) {
        final cn = coins[i];
        cn.x -= v * dt;
        if (me.magnet > 0 && (cn.x - me.x).abs() < W * .5) {
          cn.x += (me.x - cn.x) * math.min(1, dt * 6);
          cn.y += (me.y - me.h / 2 - cn.y) * math.min(1, dt * 6);
        }
        if (cn.x < -60) {
          coins.removeAt(i);
          continue;
        }
        if (_hit(meBox, cn, .9)) {
          score++;
          earn(1);
          g.sfx('coin');
          F.text(cn.x, cn.y - 20, '+1', '#ffd43b');
          D.sparks(cn.x, cn.y, 5, '#ffe066', 140);
          coins.removeAt(i);
        }
      }
      for (var i = items.length - 1; i >= 0; i--) {
        final it = items[i];
        it.x -= v * dt;
        it.y += math.sin(t * 3) * 20 * dt;
        if (it.x < -60) {
          items.removeAt(i);
          continue;
        }
        if (!_hit(meBox, it, .9)) continue;
        items.removeAt(i);
        g.sfx('power');
        D.sparks(it.x, it.y, 14, '#fff3bf', 260);
        final P = _POWERS[it.k];
        if (P != null) {
          // Nhặt chưởng: chưa có thì mở, có rồi thì lên sao, đã max thì đổi thành xu
          final n = G.own[it.k]!;
          me.power = G.power = it.k;
          if (n >= _PMAX) {
            earn(15);
            F.text(it.x, it.y - 20, tr('+15 XU', '+15 COINS'), '#ffd43b');
          } else {
            G.own[it.k] = n + 1;
            F.text(it.x, it.y - 20, n > 0 ? '${pname(it.k)} ${'★' * (n + 1)}' : '${tr('MỚI!', 'NEW!')} ${pname(it.k)}', P.c);
          }
          save();
        } else if (it.k == 'fly') {
          if (me.fly > 0) {
            G.fly = math.min(_STOCK_MAX, G.fly + 1);
            F.text(it.x, it.y - 20, '+1 🚀', '#ff922b');
            save();
          } else {
            me.fly = 8;
            F.text(it.x, it.y - 20, tr('GIÀY TÊN LỬA!', 'ROCKET SHOES!'), '#ff922b');
          }
        } else if (it.k == 'shield') {
          if (me.shield > 0) {
            G.shield = math.min(_STOCK_MAX, G.shield + 1);
            F.text(it.x, it.y - 20, tr('+1 KHIÊN', '+1 SHIELD'), '#74c0fc');
            save();
          } else {
            me.shield = 10;
            F.text(it.x, it.y - 20, tr('KHIÊN!', 'SHIELD!'), '#74c0fc');
          }
        } else if (it.k == 'magnet') {
          me.magnet = 10;
          F.text(it.x, it.y - 20, tr('NAM CHÂM!', 'MAGNET!'), '#ff6b6b');
        } else {
          lives = math.min(maxLives, lives + 1);
          F.text(it.x, it.y - 20, '+❤', '#ff6b6b');
        }
      }
      for (var i = fire.length - 1; i >= 0; i--) {
        final f = fire[i];
        f.x += f.vx * dt;
        f.y += f.vy * dt;
        f.vy += 900 * dt;
        if (f.y > ground + 20 || f.x < -60) {
          fire.removeAt(i);
          continue;
        }
        if (random() < .5) D.emit(f.x, f.y, rand(-20, 20), rand(-20, 20), life: .35, r: 5, grow: 10, c: 'rgba(120,120,120,1)', a: .4);
        if (_hit(meBox, f, .6)) {
          hurt();
          fire.removeAt(i);
        }
      }
      for (var i = waves.length - 1; i >= 0; i--) {
        final w = waves[i];
        w.x -= w.v * dt;
        if (random() < .6) D.emit(w.x, ground - 4, rand(40, 120), rand(-160, -60), life: .5, r: 4, grow: 0, c: '#8d5524', k: 2, g: 800, a: 1);
        if (w.x < -80) {
          waves.removeAt(i);
          continue;
        }
        if (me.y > ground - 40 && _hit(meBox, w, .7)) {
          hurt();
          waves.removeAt(i);
        }
      }
      for (final cl in clouds) {
        cl.x -= (v * .1 + 10) * dt;
        if (cl.x < -150) {
          cl.x = W + 150;
          cl.y = rand(20, H * .25);
        }
      }
      F.update(dt);
      return null;
    },
    draw: () {
      c.save();
      SH.apply(c);
      final sky = c.createLinearGradient(0, 0, 0, ground);
      sky.addColorStop(0, boss != null ? '#845ef7' : hex(th.sky[0]));
      sky.addColorStop(1, hex(th.sky[1]));
      c.fillStyle = sky;
      c.fillRect(-20, -20, W + 40, H + 40);
      draw(c, th.sun, W * .85, H * .14, S * .16);
      for (final cl in clouds) {
        draw(c, 'Cloud', cl.x, cl.y, cl.s, cl.s * .6);
      }
      // Nền nhiều lớp: đồi xa chậm, thành phố giữa, mặt đất lát gạch chạy theo tốc độ
      backHills(c, bgs, lv, scroll * .12, ground + 8, H * .42, W);
      const span = 14 * 110.0;
      c.globalAlpha = .75;
      for (final b in city) {
        final x = ((b.x - scroll * .3) % span + span) % span - 110;
        c.fillStyle = b.c;
        c.fillRect(x, ground - b.h * .7, b.w, b.h * .7);
        c.fillStyle = 'rgba(255,255,255,.55)';
        for (var wy = ground - b.h * .7 + 14; wy < ground - 20; wy += 28) {
          for (var wx = x + 12; wx < x + b.w - 18; wx += 26) {
            c.fillRect(wx, wy, 12, 14);
          }
        }
      }
      c.globalAlpha = 1;
      groundTiles(c, tl, lv, scroll, ground - 6, W, H + 20, math.max(48, S * .08));
      for (final cn in coins) {
        coin(c, fxs, t + cn.x * .01, cn.x, cn.y, cn.w);
      }
      for (final it in items) {
        c.fillStyle = 'rgba(255,255,255,.7)';
        c.beginPath();
        c.arc(it.x, it.y, it.w * .6, 0, 7);
        c.fill();
        drawO(c, ITEM_IMG[it.k]!, it.x, it.y, it.w, h: it.w, rot: it.k == 'fly' ? -math.pi / 4 : math.sin(t * 4) * .2);
      }
      for (final f in foes) {
        if (f.drop) {
          c.strokeStyle = 'rgba(255,255,255,.8)';
          c.lineWidth = 2;
          c.beginPath();
          c.moveTo(f.x, 0);
          c.lineTo(f.x, f.y - f.h / 2);
          c.stroke();
        }
        if (f.rock) {
          c.fillStyle = 'rgba(0,0,0,.18)';
          c.beginPath();
          c.ellipse(f.x, ground, f.w * .45, 6, 0, 0, 7);
          c.fill();
          if (f.k == 'Rock') {
            spr(c, tl, 'rock', f.x, f.y - f.h * .1, f.h * 1.15);
          } else {
            anim(c, en, 'saw', t, f.x, f.y, f.h * 1.1, rot: -t * 8);
          }
        } else {
          final sq = 1 + math.sin(f.ph * 10) * .06; // nhún khi bò/bay
          c.save();
          c.translate(f.x, f.y + f.h * .45);
          c.scale(1 / sq, sq);
          anim(c, en, LOOK[f.k] ?? 'slime', f.ph, 0, -f.h * .45, f.h, alpha: f.flash > 0 ? .55 : 1);
          c.restore();
        }
        if (f.slow > 0) {
          c.fillStyle = 'rgba(116,192,252,.45)';
          c.beginPath();
          c.arc(f.x, f.y, f.w * .6, 0, 7);
          c.fill();
          draw(c, 'Snowflake', f.x + f.w * .35, f.y - f.h * .4, 22);
        }
      }
      for (final f in fire) {
        spr(c, tl, 'fireball', f.x, f.y, f.h * 1.1, rot: math.atan2(f.vy, f.vx) + math.pi);
      }
      for (final w in waves) {
        c.fillStyle = 'rgba(132,94,247,.75)';
        c.beginPath();
        c.ellipse(w.x, w.y, w.w / 2, w.h / 2 + math.sin(t * 20) * 4, 0, math.pi, 0);
        c.fill();
        draw(c, 'Collision', w.x, w.y - 10, 34);
      }
      final bs = boss;
      if (bs != null) {
        c.fillStyle = 'rgba(0,0,0,.2)';
        c.beginPath();
        c.ellipse(bs.x, ground, bs.w * .4, 12, 0, 0, 7);
        c.fill();
        final rage = bs.hp < bs.max / 2, jx = rage ? math.sin(t * 50) * 2 : 0.0;
        if (bs.k == 'Dragon') {
          anim(c, fly, 'dragon', t, bs.x + jx, bs.y - bs.h * .1 + math.sin(bs.ph * 3) * 10, bs.h * .85, flip: true, alpha: bs.flash > 0 ? .6 : 1);
        } else {
          // Quái vật trùm: slime khối khổng lồ nhún theo nhịp nhảy
          final hop = (math.sin(bs.ph * 2)).abs(), sq = 1 + (1 - hop) * .12;
          c.save();
          c.translate(bs.x + jx, ground);
          c.scale(sq, 1 / sq);
          anim(c, en, rage ? 'fslime' : 'bslime', bs.ph, 0, -bs.h * .5 - hop * 20, bs.h, alpha: bs.flash > 0 ? .6 : 1);
          c.restore();
        }
      }
      for (final s in shots) {
        final col = _POWERS[s.k]!.c;
        if (s.k == 'tornado') {
          // Bão xoáy: vòng gió + hình lốc xoáy lắc lư (không gradient)
          c.globalAlpha = .35;
          c.fillStyle = col;
          c.beginPath();
          c.ellipse(s.x, s.y + s.h * .1, s.w * .62, s.h * .55, 0, 0, 7);
          c.fill();
          c.globalAlpha = 1;
          drawO(c, 'Tornado', s.x + math.sin(t * 18) * 4, s.y, s.w * 1.1, h: s.h * 1.1, flip: (t * 8).floor() % 2 == 0);
          continue;
        }
        if (s.k == 'quake') {
          c.fillStyle = 'rgba(141,85,36,.85)';
          c.beginPath();
          c.ellipse(s.x, ground, s.w / 2, s.h, 0, math.pi, 0);
          c.fill();
          c.fillStyle = col;
          c.beginPath();
          c.ellipse(s.x, ground, s.w * .3, s.h * .7, 0, math.pi, 0);
          c.fill();
          spr(c, tl, 'rock', s.x - s.w * .2, ground - s.h * .95, s.h * .45);
          spr(c, tl, 'rock', s.x + s.w * .15, ground - s.h * .75, s.h * .35);
          continue;
        }
        final gr = c.createRadialGradient(s.x, s.y, 2, s.x, s.y, s.w * .65);
        gr.addColorStop(0, '#fff');
        gr.addColorStop(.4, col);
        gr.addColorStop(1, 'rgba(255,255,255,0)');
        c.fillStyle = gr;
        c.beginPath();
        c.arc(s.x, s.y, s.w * .65, 0, 7);
        c.fill();
        if (s.k == 'fire') drawO(c, 'Fire', s.x, s.y, s.w * .8, h: s.w * .8, rot: math.pi / 2);
        if (s.k == 'ice') drawO(c, 'Snowflake', s.x, s.y, s.w * .7, h: s.w * .7, rot: t * 8);
        if (s.k == 'basic' && s.w > 50) draw(c, 'Collision', s.x, s.y, s.w * .6);
      }
      // Sấm sét: tia zíc zắc từ mây xuống quái
      for (final b in bolts) {
        c.globalAlpha = math.min(1, b.life * 5);
        draw(c, 'Cloud with lightning', b.x, 120, 70);
        c.strokeStyle = '#fcc419';
        c.lineWidth = b.w;
        c.lineJoin = 'round';
        c.beginPath();
        c.moveTo(b.x, 140);
        const n = 6;
        for (var k = 1; k <= n; k++) {
          c.lineTo(b.x + (k < n ? (k.isOdd ? 1 : -1) * (14 + b.w) : 0), 140 + (b.y - 140) * k / n);
        }
        c.stroke();
        c.strokeStyle = '#fff';
        c.lineWidth = b.w * .35;
        c.stroke();
        c.globalAlpha = 1;
      }
      // Vòng chấn động của đấm đất
      for (final r in rings) {
        final k = 1 - r.life / .45;
        c.strokeStyle = 'rgba(255,212,59,${(1 - k).toStringAsFixed(2)})';
        c.lineWidth = 8;
        c.beginPath();
        c.ellipse(r.x, ground, S * .5 * k + 20, 24 * (1 - k) + 6, 0, 0, 7);
        c.stroke();
      }
      // Siêu chưởng
      if (beam > 0) {
        final by = me.y - me.h * .55, bt = S * .18 * (1 + sup * .12) * (.7 + .3 * math.sin(t * 40));
        final gr = c.createLinearGradient(0, by - bt, 0, by + bt);
        final ec = sup >= 3 ? 'rgba(255,107,107,0)' : 'rgba(255,212,59,0)';
        gr.addColorStop(0, ec);
        gr.addColorStop(.5, 'rgba(255,255,255,.95)');
        gr.addColorStop(1, sup >= 2 ? 'rgba(116,192,252,0)' : ec);
        c.fillStyle = gr;
        c.fillRect(me.x + me.w * .3, by - bt, W, bt * 2);
      }
      final blink = me.inv > 0 && me.dash <= 0 && (me.inv * 10).floor() % 2 == 0;
      if (!blink) {
        c.fillStyle = 'rgba(0,0,0,.15)';
        c.beginPath();
        c.ellipse(me.x, ground + 4, me.w * .4, 8, 0, 0, 7);
        c.fill();
        if (me.fly > 0) drawO(c, 'Rocket', me.x - me.w * .25, me.y - me.h * .2, me.w * .45, h: me.w * .45, rot: math.pi * .75);
        // Bé mặc trang phục theo linh vật (figure.dart chưa có áo choàng)
        // Nhún khi tiếp đất, nghiêng nhẹ theo vận tốc rơi
        final sq = land > 0 ? 1 - math.sin(land / .18 * math.pi) * .12 : 1.0;
        c.save();
        c.translate(me.x, me.y);
        c.scale(2 - sq, sq);
        c.rotate(me.dash > 0 ? .25 : math.max(-.15, math.min(.15, me.vy / 4000)));
        c.translate(-me.x, -me.y);
        fig.drawFigure(c.canvas, me.x, me.y, me.h * 1.25, fig.heroOf(g.hero),
            pose: me.punch > 0 || me.dash > 0 ? 'punch' : me.y < ground - 2 ? 'jump' : 'run', act: me.punch > 0 ? 1 - me.punch / .18 : 0, t: t, face: 1);
        c.restore();
        if (me.pound) draw(c, 'Flexed biceps', me.x, me.y + 10, me.w * .5);
        if (me.shield > 0) {
          c.strokeStyle = 'rgba(116,192,252,.85)';
          c.lineWidth = 4;
          c.beginPath();
          c.arc(me.x, me.y - me.h / 2, me.w * .75, 0, 7);
          c.stroke();
        }
      }
      D.draw(c);
      B.draw(c);
      F.draw(c);
      c.restore();
      // Nút bấm lớn
      void btn(_Btn b, double r, bool on, [String fill = 'rgba(255,255,255,.75)']) {
        c.fillStyle = fill;
        c.globalAlpha = on ? 1 : .5;
        c.beginPath();
        c.arc(b.x, b.y, r, 0, 7);
        c.fill();
        c.globalAlpha = 1;
      }

      for (final (b, label) in [(jumpBtn, me.fly > 0 ? '🚀' : '⬆'), (shotBtn, '💥')]) {
        btn(b, btnR, true);
        c.font = '${(btnR * .9).toStringAsFixed(0)}px';
        c.textAlign = 'center';
        c.fillStyle = '#23324d';
        c.fillText(label, b.x, b.y + btnR * .32);
      }
      if (G.up['dash']! > 0) {
        btn(dashBtn, btnR * .85, me.dashCd <= 0);
        drawO(c, 'Running shoe', dashBtn.x, dashBtn.y, btnR, h: btnR, alpha: me.dashCd > 0 ? .4 : 1);
      }
      // Nút đổi chưởng: hình chưởng đang dùng + sao + mũi tên vòng
      final own = owned();
      if (own.length > 1) {
        btn(swapBtn, sR, true, 'rgba(255,255,255,.85)');
        c.strokeStyle = _POWERS[me.power]!.c;
        c.lineWidth = 5;
        c.beginPath();
        c.arc(swapBtn.x, swapBtn.y, sR, 0, 7);
        c.stroke();
        draw(c, _POWERS[me.power]!.img, swapBtn.x, swapBtn.y - 4, sR * 1.2);
        c.font = '800 ${(sR * .34).round()}px';
        c.textAlign = 'center';
        c.fillStyle = '#f59f00';
        c.fillText('★' * G.own[me.power]!, swapBtn.x, swapBtn.y + sR * .78);
        c.font = '${(sR * .5).round()}px';
        c.fillText('🔄', swapBtn.x + sR * .8, swapBtn.y - sR * .6);
      }
      if (G.fly > 0) {
        btn(rocketBtn, sR, me.fly <= 0);
        drawO(c, 'Rocket', rocketBtn.x, rocketBtn.y, sR * 1.2, h: sR * 1.2, alpha: me.fly > 0 ? .4 : 1);
        c.font = '800 ${(sR * .55).round()}px';
        c.fillStyle = '#e8590c';
        c.textAlign = 'center';
        c.fillText('×${G.fly}', rocketBtn.x + sR * .6, rocketBtn.y + sR * .95);
      }
      if (G.shield > 0) {
        btn(shieldBtn, sR, me.shield <= 0);
        drawO(c, 'Shield', shieldBtn.x, shieldBtn.y, sR * 1.2, h: sR * 1.2, alpha: me.shield > 0 ? .4 : 1);
        c.font = '800 ${(sR * .55).round()}px';
        c.fillStyle = '#1c7ed6';
        c.textAlign = 'center';
        c.fillText('×${G.shield}', shieldBtn.x + sR * .6, shieldBtn.y + sR * .95);
      }
      // Nút siêu chưởng: vòng nạp năng lượng
      c.fillStyle = charge >= 1 ? 'rgba(255,212,59,${(.8 + .2 * math.sin(t * 10)).toStringAsFixed(2)})' : 'rgba(255,255,255,.5)';
      c.beginPath();
      c.arc(superBtn.x, superBtn.y, btnR * .85, 0, 7);
      c.fill();
      c.strokeStyle = '#ff922b';
      c.lineWidth = 7;
      c.beginPath();
      c.arc(superBtn.x, superBtn.y, btnR * .85, -math.pi / 2, -math.pi / 2 + math.pi * 2 * charge);
      c.stroke();
      drawO(c, 'High voltage', superBtn.x, superBtn.y, btnR, h: btnR, alpha: charge >= 1 ? 1 : .45);
      if (sup > 0) {
        c.font = '800 ${(btnR * .3).round()}px';
        c.fillStyle = '#f59f00';
        c.textAlign = 'center';
        c.fillText('★' * sup, superBtn.x, superBtn.y + btnR * 1.1);
      }
      // HUD: lõi vẽ điểm/đồng hồ/máu trùm; tim tự vẽ vì máu tối đa có thể hơn 5
      hud(c, W, score: score, lives: 0, time: bs != null ? null : math.max(0, 55 - t), bossHp: bs?.hp, bossMax: bs?.max);
      final narrow = W < 520, hs = narrow ? 22.0 : 30.0, hg = narrow ? 25.0 : 36.0;
      for (var i = 0; i < maxLives; i++) {
        final row = narrow && i >= 5 ? 1 : 0, col = row > 0 ? i - 5 : i;
        draw(c, 'Red heart', W - (narrow ? 30 : 40) - col * hg, 32.0 + row * 26, hs, hs, false, 0, i < lives ? 1 : .22);
      }
      final P = _POWERS[me.power]!, py = narrow && bs != null ? 88.0 : 62.0;
      c.fillStyle = 'rgba(0,0,0,.3)';
      roundRect(c, 72, py, 232, 36, 18);
      c.fill();
      draw(c, P.img, 92, py + 18, 28);
      c.fillStyle = P.c;
      c.font = '800 19px';
      c.textAlign = 'left';
      c.fillText('${pname(me.power)} ${'★' * G.own[me.power]!}', 110, py + 25);
      var ix = 86.0;
      for (var i = 0; i < armor; i++, ix += 30) {
        draw(c, 'Shield', ix, py + 56, 26);
      }
      if (me.fly > 0) {
        c.fillStyle = 'rgba(0,0,0,.3)';
        roundRect(c, ix - 12, py + 42, 130, 28, 14);
        c.fill();
        c.fillStyle = '#ff922b';
        roundRect(c, ix - 4, py + 51, 114 * me.fly / 8, 10, 5);
        c.fill();
      }
      // Đầu màn: dải chưởng đã có (bé thấy đồ mang theo)
      if (t < 3.6) {
        final n = own.length, sz = math.min(52.0, (W - 40) / n - 8), x0 = W / 2 - (n * (sz + 8) - 8) / 2 + sz / 2, y0 = H / 2 + 124;
        c.fillStyle = 'rgba(0,0,0,.4)';
        roundRect(c, x0 - sz / 2 - 10, y0 - sz / 2 - 8, n * (sz + 8) + 12, sz + 34, 16);
        c.fill();
        for (var i = 0; i < n; i++) {
          final k = own[i], x = x0 + i * (sz + 8);
          if (k == me.power) {
            c.strokeStyle = '#ffd43b';
            c.lineWidth = 4;
            c.beginPath();
            c.arc(x, y0, sz * .58, 0, 7);
            c.stroke();
          }
          draw(c, _POWERS[k]!.img, x, y0, sz * .85);
          c.font = '800 ${math.max(10, (sz * .26).round())}px';
          c.textAlign = 'center';
          c.fillStyle = '#ffd43b';
          c.fillText('★' * G.own[k]!, x, y0 + sz * .5 + 14);
        }
      }
      if (t < 2.8) {
        levelBanner(c, W, H, lv, bossK == 'Dragon' ? tr('Hạ rồng trùm', 'Defeat the dragon boss') : tr('Hạ quái vật trùm', 'Defeat the monster boss'),
            tr('Trái: nhảy (giữ để bay) · Phải: bắn chưởng · ⚡ siêu chưởng', 'Left: jump (hold to fly) · Right: blast · ⚡ super blast'), tr);
      }
      final e = end;
      if (e != null) banner(c, W, H, e.win ? endText(true, lv, tr) : tr('HẾT LƯỢT!', 'GAME OVER!'), tr('$score điểm', '$score points'));
    },
  );
}
