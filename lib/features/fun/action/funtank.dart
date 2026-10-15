// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api, constant_identifier_names
// Xe tăng dũng cảm (Flame).
// CHỦ: agent G. Port của reference/web/js/games/funtank.js.
// Lái tới chỗ chạm, tháp pháo tự ngắm. 8 loại đạn nhặt từ hộp (rơi từ địch/thùng gỗ), mỗi loại 5 sao; đổi đạn bằng nút bên trái.
// Chiêu bên phải nạp năng lượng khi hạ địch: khiên điện, sửa xe, gọi không kích, xe tăng đồng minh (tối đa 2).
// Kho đồ giữ qua màn (ctx.carry): {v, coins, wp: {loại: sao cao nhất}, cur, body, up: {hp, spd, rate, rng, ally}, allies, en}.
// Xưởng xe tăng chỉ hiện ở cấp đầu của vé: chọn màu xe, chọn đạn, mua nâng cấp vĩnh viễn bằng xu.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/content/models.dart' show Json;
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'act_ui.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funtankGames = {'tank': const TankModule()};

class TankModule extends FunGameModule {
  const TankModule();
  @override
  String get id => 'tank';
  @override
  Widget build(BuildContext context, FunGameContext ctx) => TankView(ctx: ctx);
}

// ---------- Dữ liệu ----------
class TkWeapon {
  const TkWeapon(this.id, this.vi, this.img, this.c);
  final String id, vi, img;
  final int c;
}

const List<TkWeapon> kTkWeapons = [
  TkWeapon('norm', 'Đạn thường', 'Bullseye', 0x37b24d),
  TkWeapon('multi', 'Nhiều nòng', 'Sparkles', 0xf59f00),
  TkWeapon('bounce', 'Đạn nảy', 'Basketball', 0xff922b),
  TkWeapon('homing', 'Tên lửa', 'Rocket', 0xf03e3e),
  TkWeapon('blast', 'Pháo nổ', 'Collision', 0xd9480f),
  TkWeapon('laser', 'Laser', 'High voltage', 0xae3ec9),
  TkWeapon('flame', 'Súng lửa', 'Fire', 0xe8590c),
  TkWeapon('mine', 'Mìn', 'Bomb', 0x495057),
];
final Map<String, TkWeapon> _wp = {for (final w in kTkWeapons) w.id: w};
const List<(String, String, int, int, String)> kTkSkills = [
  ('shield', 'Shield', 25, 0x1c7ed6, 'KHIÊN ĐIỆN!'),
  ('fix', 'Wrench', 35, 0x2f9e44, 'SỬA XE!'),
  ('air', 'Airplane', 50, 0xe03131, 'KHÔNG KÍCH!'),
  ('ally', 'Military helmet', 60, 0xf08c00, 'ĐỒNG MINH!'),
];
const List<(String, String, String, int)> kBodies = [
  ('green', 'tankBody_green', 'tankGreen_barrel2', 0x37b24d),
  ('blue', 'tankBody_blue', 'tankBlue_barrel2', 0x1c7ed6),
  ('sand', 'tankBody_sand', 'tankSand_barrel1', 0xd9a441),
];
const List<(String, String, String, int)> kTkUps = [
  ('hp', 'Red heart', 'Máu', 5),
  ('spd', 'Running shoe', 'Chạy', 5),
  ('rate', 'Stopwatch', 'Bắn nhanh', 5),
  ('rng', 'Bow and arrow', 'Bắn xa', 5),
  ('ally', 'Military helmet', 'Đồng minh', 2),
];
int tkUpPrice(String id, int n) => id == 'ally' ? 160 * (n + 1) : 70 + 50 * n;
const int kTkWpPrice = 120;
final List<String> kTankImgs = [
  'Coin', 'Red heart', 'Shield', 'Glowing star', 'Wrapped gift', 'Airplane',
  ...kTkWeapons.map((w) => w.img), ...kTkSkills.map((s) => s.$2), ...kTkUps.map((u) => u.$2),
];

/// Kho đồ xe tăng (normCarry của web).
class TankGear {
  TankGear.from(Object? raw) {
    final c = raw is Map ? raw : const {};
    Map mp(Object? v) => v is Map ? v : const {};
    wp['norm'] = 1;
    for (final w in kTkWeapons) {
      final s = jInt(mp(c['wp'])[w.id], 0, 5);
      if (s > 0) wp[w.id] = math.max(wp[w.id] ?? 0, s);
    }
    for (final u in kTkUps) {
      up[u.$1] = jInt(mp(c['up'])[u.$1], 0, u.$4);
    }
    coins = jInt(c['coins']);
    cur = wp.containsKey(c['cur']) ? c['cur'] as String : 'norm';
    body = kBodies.any((b) => b.$1 == c['body']) ? c['body'] as String : 'green';
    allies = jInt(c['allies'], 0, 2);
    en = jInt(c['en'], 0, 100);
  }
  int coins = 0, allies = 0, en = 0;
  String cur = 'norm', body = 'green';
  final Map<String, int> wp = {}, up = {};
  Json toJson() => {'v': 1, 'coins': coins, 'wp': {...wp}, 'cur': cur, 'body': body, 'up': {...up}, 'allies': allies, 'en': en};
}

/// Xe tăng nhìn từ trên: thân xoay theo hướng chạy a, nòng xoay theo tháp pháo tur.
void drawTank(Canvas c, Gfx g, SpriteSheet? tk, double x, double y, String body, String barrel, double size, double a, double tur, [double recoil = 0, double alpha = 1]) {
  ellipse(c, x + 4, y + 6, size * .55, size * .5, rgba(0, 0, 0, .2 * alpha));
  if (!g.spr(c, tk, body, x, y, size, rot: a + math.pi / 2, alpha: alpha)) {
    c.save();
    c.translate(x, y);
    c.rotate(a);
    fillRR(c, -size / 2, -size * .4, size, size * .8, 8, hex(0x37b24d, alpha));
    c.restore();
  }
  final bl = size * .62, back = recoil * size * .12;
  if (!g.spr(c, tk, barrel, x + math.cos(tur) * (bl * .38 - back), y + math.sin(tur) * (bl * .38 - back), bl, rot: tur - math.pi / 2, alpha: alpha)) {
    line(c, x, y, x + math.cos(tur) * bl * .8, y + math.sin(tur) * bl * .8, hex(0x495057, alpha), size * .12);
  }
}

// ---------- Widget ----------
class TankView extends StatefulWidget {
  const TankView({super.key, required this.ctx, this.skipShop = false});
  final FunGameContext ctx;
  final bool skipShop;
  @override
  State<TankView> createState() => _TankViewState();
}

class _TankViewState extends State<TankView> {
  late final ActSession ses = actSession(widget.ctx);
  late final TankGear gear = TankGear.from(widget.ctx.carry);
  Gfx? gfx;
  TankGame? game;

  @override
  void initState() {
    super.initState();
    Gfx.load(kTankImgs, ['tanks/tanks', 'fxa/fx']).then((g) {
      if (!mounted) return;
      setState(() => gfx = g);
      if (ses.data['shop'] == true || widget.skipShop) _go();
    });
  }

  void _go() {
    ses.data['shop'] = true;
    setState(() => game = TankGame(ctx: widget.ctx, gfx: gfx!, gear: gear));
  }

  @override
  Widget build(BuildContext context) {
    if (gfx == null) return const ActLoading(color: Color(0xFF5C940D));
    final g = game;
    if (g == null) return TankShop(ctx: widget.ctx, gear: gear, gfx: gfx!, onPlay: _go);
    return ActGameView(
      ctx: widget.ctx,
      game: g,
      toResult: (r) {
        final e = r as TankEnd;
        return FunResult(score: e.score, win: e.win, carry: e.carry);
      },
      onResult: (r) => actSessionDone(ses, widget.ctx, r),
    );
  }
}

/// Xưởng xe tăng: màu xe, đạn mang vào, nâng cấp vĩnh viễn.
class TankShop extends StatefulWidget {
  const TankShop({super.key, required this.ctx, required this.gear, required this.gfx, required this.onPlay});
  final FunGameContext ctx;
  final TankGear gear;
  final Gfx gfx;
  final VoidCallback onPlay;
  @override
  State<TankShop> createState() => _TankShopState();
}

class _TankShopState extends State<TankShop> {
  final Map<String, int> shakes = {};
  TankGear get G => widget.gear;
  void save() => widget.ctx.saveGear(G.toJson());
  void nope(String key) {
    widget.ctx.audio.sfx('wrong');
    setState(() => shakes[key] = (shakes[key] ?? 0) + 1);
  }

  Widget card(String key, int color, bool on, VoidCallback tap, List<Widget> kids) => ShakeBox(
        trigger: shakes[key] ?? 0,
        child: GestureDetector(
          key: Key(key),
          onTap: tap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 86),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFFF3BF) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hex(color), width: 4),
              boxShadow: [if (on) const BoxShadow(color: Color(0xFFFFD43B), spreadRadius: 4), const BoxShadow(color: Color(0x2E000000), offset: Offset(0, 5))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: kids),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = shopText(13, color: const Color(0xFF495057));
    Widget stars(int n) => Text.rich(TextSpan(children: [
          TextSpan(text: '★' * n, style: shopText(16, color: const Color(0xFFF59F00))),
          TextSpan(text: '★' * (5 - n), style: shopText(16, color: const Color(0xFFDEE2E6))),
        ]));
    Widget row(String lab, List<Widget> kids) => ShopBox(
          title: Center(child: Text(lab, style: shopText(20))),
          child: SizedBox(width: double.infinity, child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: kids)),
        );
    return ShopFrame(colors: const [Color(0xFF5C940D), Color(0xFF2B8A3E)], children: [
      Wrap(spacing: 12, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('🛠️ Xưởng xe tăng', style: shopText(28)), CoinPill(G.coins)]),
      row('🎨', [
        for (final b in kBodies)
          card('body-${b.$1}', b.$4, G.body == b.$1, () {
            widget.ctx.audio.sfx('tap');
            setState(() => G.body = b.$1);
            save();
          }, [SizedBox(width: 72, height: 72, child: CustomPaint(painter: _TankPainter(widget.gfx, b.$2, b.$3)))]),
      ]),
      row('💥', [
        for (final w in kTkWeapons)
          card('wp-${w.id}', w.c, G.cur == w.id, () {
            final s = G.wp[w.id] ?? 0;
            if (s > 0) {
              widget.ctx.audio.sfx('tap');
              setState(() => G.cur = w.id);
              save();
              return;
            }
            if (G.coins < kTkWpPrice) return nope('wp-${w.id}');
            setState(() {
              G.coins -= kTkWpPrice;
              G.wp[w.id] = 1;
              G.cur = w.id;
            });
            widget.ctx.audio.sfx('coin');
            save();
          }, [
            Opacity(opacity: (G.wp[w.id] ?? 0) > 0 ? 1 : .35, child: EmojiImage(w.img, size: 46, photo: false)),
            if ((G.wp[w.id] ?? 0) > 0) stars(G.wp[w.id]!) else PriceTag(kTkWpPrice, ok: G.coins >= kTkWpPrice, color: const Color(0xFF343A40), size: 15),
            Text(w.vi, style: dark),
          ]),
      ]),
      row('⬆️', [
        for (final u in kTkUps)
          () {
            final n = G.up[u.$1]!, max = n >= u.$4, p = tkUpPrice(u.$1, n);
            return card('up-${u.$1}', max ? 0xffd43b : 0x74c0fc, false, () {
              if (max || G.coins < p) return nope('up-${u.$1}');
              setState(() {
                G.coins -= p;
                G.up[u.$1] = n + 1;
              });
              widget.ctx.audio.sfx('power');
              save();
            }, [
              EmojiImage(u.$2, size: 46, photo: false),
              Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
                for (var i = 0; i < u.$4; i++) Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: i < n ? const Color(0xFF40C057) : const Color(0xFFDEE2E6))),
              ]),
              if (max) Text('MAX', style: shopText(16, color: const Color(0xFFF59F00))) else PriceTag(p, ok: G.coins >= p, color: const Color(0xFF343A40), size: 15),
              Text(u.$3, style: dark),
            ]);
          }(),
      ]),
      PlayBtn(
        color: const Color(0xFFF76707),
        shade: const Color(0xFFC2410C),
        onTap: () {
          widget.ctx.audio.sfx('power');
          save();
          widget.onPlay();
        },
      ),
    ]);
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter(this.g, this.body, this.barrel);
  final Gfx g;
  final String body, barrel;
  @override
  void paint(Canvas canvas, Size size) => drawTank(canvas, g, g.sh('tanks/tanks'), size.width / 2, size.height / 2, body, barrel, size.width * .66, -math.pi / 2, -math.pi / 2);
  @override
  bool shouldRepaint(covariant _TankPainter old) => old.body != body;
}

// ---------- Game ----------
class TankEnd {
  TankEnd(this.win, this.score, this.carry);
  final bool win;
  final int score;
  final Json carry;
}

class _Foe {
  _Foe(this.k, this.x, this.y, this.hp, this.cd, this.s) : max = hp;
  final String k;
  double x, y, hp, max, cd, s, ph = rnd(0, 6), flash = 0, ang = math.pi / 2, tur = math.pi / 2, cd2 = 0;
  bool dead = false, boss = false;
}

class _Bul {
  _Bul(this.x, this.y, this.vx, this.vy, this.life, this.kind, {this.mine = false, this.dmg = 1, this.r = 8, this.spr, this.pierce = 0, this.bn = 0, this.turn = 0, this.boom = 0, this.rad = 0, this.max = 1, this.big = false});
  double x, y, vx, vy, life, dmg, r, turn, boom, rad, max;
  final String kind;
  final bool mine, big;
  final String? spr;
  int pierce, bn;
  _Foe? last;
}

class _Wall {
  _Wall(this.x, this.y, this.w, this.h, this.k);
  final double x, y, w, h;
  final String k;
  double hp = 3, hitT = 0;
}

class _Ally {
  _Ally(this.x, this.y, this.cd, this.slot, [this.inv = 0]);
  double x, y, cd, inv, a = -math.pi / 2, tur = -math.pi / 2;
  int hp = 3;
  final int slot;
}

class _Item {
  _Item(this.k, this.x, this.y, this.t, [this.w]);
  final String k;
  final double x, y;
  double t;
  final String? w;
}

class TankGame extends ActGame {
  TankGame({required this.ctx, required super.gfx, required TankGear gear})
      : G = gear,
        super(audio: ctx.audio, lv: ctx.level);
  final FunGameContext ctx;
  final TankGear G;
  late final SpriteSheet? tk = gfx.sh('tanks/tanks'), fxs = gfx.sh('fxa/fx');
  late final FunTheme th = funTheme(lv);
  late final int need = math.min(30, 5 + (lv * .4).floor());
  late final bool bossLv = (lv + 1) % 5 == 0;
  late final Fx F = Fx(gfx);
  final Dust D = Dust(260);
  late final Booms B = Booms(gfx, fxs, 24);
  final Shaker SH = Shaker();
  late double R;
  late bool narrow, sand;
  late String groundK;
  ui.Picture? _ground;
  Size? _groundSize;
  late (String, String, String, int) BODY;
  final List<(double, double, double, double)> tracks = List.filled(60, (0, 0, 0, 0));
  int trackI = 0;
  double trackD = 0;
  final List<(double, double, String, double)> deco = [];
  late int startAllies, maxHp;
  late double pw, hpMul, range, cdMul, speed;
  late Map<String, int> st;
  late String cur;
  late double en;
  int hp = 0, coinsRun = 0, killed = 0;
  // me
  double mx = 0, my = 0, ma = -math.pi / 2, mtur = -math.pi / 2, recoil = 0, cd = 0, mcd = 1, inv = 1.5, shield = 0, eshield = 0;
  double? tx, ty;
  bool aimOk = false;
  final List<_Bul> bullets = [];
  final List<_Foe> foes = [];
  final List<_Item> items = [];
  final List<_Wall> walls = [];
  final List<_Mine> mines = [];
  final List<(double, double, double, double, double, double, int)> beams = [];
  final List<_Bomb> bombs = [];
  final List<_Ally> allies = [];
  (double, double, double)? plane;
  double t = 0, spawn = 1, endT = 0;
  int sndT = 0;
  TankEnd? end;
  _Foe? boss;
  bool bossDone = false;
  late double fsp, fireRate, ebs;
  late double bs, ss;
  int? steerId;

  @override
  void setup() {
    R = S * .05;
    narrow = W < 520;
    BODY = kBodies.firstWhere((b) => b.$1 == G.body, orElse: () => kBodies.first);
    sand = [1, 5].contains((lv ~/ 10) % 6);
    groundK = sand ? 'tileSand1' : 'tileGrass1';
    for (var i = 0; i < 6; i++) {
      deco.add((i % 2 == 1 ? W - rnd(10, 40) : rnd(10, 40), 100 + (i >> 1) * (H - 140) / 2 + rnd(0, 60), pickOf(const ['treeGreen_large', 'treeGreen_small', 'treeBrown_large']), S * rnd(.12, .18)));
    }
    startAllies = math.min(2, math.max(G.allies, G.up['ally']!));
    pw = (G.wp.values.reduce(math.max) - 1) / 4 + (G.up['rate']! + G.up['rng']!) / 10 + startAllies * .2;
    hpMul = (1 + lv * .035) * (1 + .3 * pw);
    maxHp = 5 + G.up['hp']!;
    range = hypot(W, H) * (.42 + .06 * G.up['rng']!);
    cdMul = 1 - .06 * G.up['rate']!;
    speed = 230 * (1 + .08 * G.up['spd']!);
    st = {...G.wp};
    cur = st.containsKey(G.cur) ? G.cur : 'norm';
    hp = maxHp;
    en = math.max(25, G.en.toDouble());
    mx = W / 2;
    my = H * .8;
    for (var i = 0; i < startAllies; i++) {
      allies.add(_Ally(mx + (i > 0 ? 1 : -1) * R * 2.4, my + R * 1.5, rnd(.3, .8), i));
    }
    final nw = ramp(lv, 4, 10).round();
    for (var i = 0; i < nw; i++) {
      walls.add(_Wall(rnd(W * .1, W * .9), rnd(H * .25, H * .65), S * .1, S * .1, rnd01() < .55 ? 'crateWood' : 'sandbagBeige'));
    }
    fsp = ramp(lv, 40, 110);
    fireRate = ramp(lv, 3.2, 1.3);
    ebs = ramp(lv, 160, 260);
    bs = narrow ? 48 : 58;
    ss = narrow ? 56 : 66;
  }

  _Wall? inWall(double x, double y, double r) {
    for (final w in walls) {
      if ((x - w.x).abs() < w.w / 2 + r && (y - w.y).abs() < w.h / 2 + r) return w;
    }
    return null;
  }

  Json carryNow() {
    final wp = {...G.wp};
    for (final k in st.keys) {
      wp[k] = math.max(wp[k] ?? 0, st[k]!);
    }
    return {'v': 1, 'coins': G.coins + coinsRun, 'wp': wp, 'cur': cur, 'body': G.body, 'up': {...G.up}, 'allies': allies.length, 'en': math.min(100, en).round()};
  }

  void saveNow() => ctx.saveGear(carryNow());

  void finish(bool win) {
    if (end != null) return;
    if (win) {
      coinsRun += 15 + (bossLv ? 20 : 0);
      sfx('win');
    }
    end = TankEnd(win, killed * 3 + (win ? hp * 2 : 0) + (bossDone ? 20 : 0), carryNow());
  }

  List<(TkWeapon, double, double, double)> wBtns() {
    final l = kTkWeapons.where((w) => st.containsKey(w.id)).toList();
    return [for (var i = 0; i < l.length; i++) (l[i], 10 + bs / 2, H - 12 - bs / 2 - i * (bs + 8), bs / 2)];
  }

  List<((String, String, int, int, String), double, double, double)> sBtns() =>
      [for (var i = 0; i < kTkSkills.length; i++) (kTkSkills[i], W - 10 - ss / 2, H - 12 - ss / 2 - i * (ss + 10), ss / 2)];

  bool canSkill((String, String, int, int, String) s) =>
      en >= s.$3 && !(s.$1 == 'ally' && allies.length >= 2) && !(s.$1 == 'fix' && hp >= maxHp && allies.every((a) => a.hp >= 3));

  void useSkill((String, String, int, int, String) s) {
    if (!canSkill(s)) {
      sfx('wrong');
      return;
    }
    en -= s.$3;
    sfx('power');
    F.text(mx, my - R * 2, s.$5, 0xffe066);
    F.burst(mx, my, 12);
    switch (s.$1) {
      case 'shield':
        eshield = 7;
      case 'fix':
        hp = maxHp;
        for (final a in allies) {
          a.hp = 3;
        }
        F.text(mx, my - R * 3.2, '❤' * math.min(5, maxHp), 0xff6b6b);
      case 'air':
        plane = (-80, H * .45, 0);
        final tg = foes.where((f) => !f.dead).take(8).toList();
        for (var i = 0; i < tg.length; i++) {
          bombs.add(_Bomb(tg[i], tg[i].x, tg[i].y, .35 + i * .14));
        }
        for (var i = tg.length; i < 4; i++) {
          bombs.add(_Bomb(null, rnd(W * .15, W * .85), rnd(110, H * .6), .35 + i * .14));
        }
      case 'ally':
        allies.add(_Ally(mx, my + R * 2, .5, allies.any((a) => a.slot == 0) ? 1 : 0, 1));
    }
    saveNow();
  }

  @override
  void down(Ptr p) {
    if (t >= 2 && end == null) {
      for (final b in wBtns()) {
        if (hypot(p.x - b.$2, p.y - b.$3) < b.$4 + 6) {
          if (cur != b.$1.id) {
            cur = b.$1.id;
            sfx('tap');
            F.text(b.$2 + bs * 1.6, b.$3, '${b.$1.vi} ${'★' * st[cur]!}');
            cd = math.min(cd, .15);
          }
          return;
        }
      }
      for (final b in sBtns()) {
        if (hypot(p.x - b.$2, p.y - b.$3) < b.$4 + 6) return useSkill(b.$1);
      }
    }
    steerId = p.id;
    tx = p.x;
    ty = p.y;
  }

  @override
  void move(Ptr p) {
    if (steerId == p.id) {
      tx = p.x;
      ty = p.y;
    }
  }

  @override
  void up(Ptr p) {
    if (steerId == p.id) steerId = null;
  }

  // ---- Địch ----
  static const Map<String, (String, String, double, double, double)> FT = {
    'basic': ('tankBody_red', 'tankRed_barrel1', 1, 1, .1),
    'fast': ('tankBody_dark', 'tankDark_barrel3', .8, 1.9, .085),
    'heavy': ('tankBody_bigRed', 'tankRed_barrel1', 3, .7, .13),
    'turret': ('crateMetal', 'specialBarrel1', 3, 0, .1),
    'boss': ('tankBody_huge', 'specialBarrel6', 1, .5, .24),
  };
  String pickFoe() {
    final r = rnd01(), tur = foes.where((f) => f.k == 'turret').length;
    if (lv >= 7 && r < .12 && tur < 2) return 'turret';
    if (lv >= 3 && r < .36) return 'fast';
    if (lv >= 12 && r < .52) return 'heavy';
    return 'basic';
  }

  _Foe addFoe(String k, double x, double y) {
    final T = FT[k]!, m = math.max(1.0, T.$3 * hpMul);
    final f = _Foe(k, x, y, m, rnd(1, fireRate), S * T.$5);
    if (k == 'turret') {
      for (var n = 0; n < 12 && inWall(f.x, f.y, f.s) != null; n++) {
        f.x = rnd(W * .15, W * .85);
        f.y = rnd(H * .18, H * .5);
      }
    }
    foes.add(f);
    return f;
  }

  void spawnBoss() {
    final m = 25 * (1 + lv * .05) * (1 + .5 * pw);
    final b = boss = addFoe('boss', W / 2, -60);
    b.hp = b.max = m;
    b.boss = true;
    b.cd = 2;
    b.cd2 = 5;
    sfx('boom');
    SH.add(12);
    F.text(W / 2, H * .35, '⚠️ TRÙM XE TĂNG!', 0xff6b6b);
  }

  void drop(double x, double y, double wpChance) {
    final r = rnd01();
    if (r < wpChance) {
      final open = kTkWeapons.where((w) => (st[w.id] ?? 0) < 5).toList();
      if (open.isEmpty) {
        items.add(_Item('coin', x, y, 9));
        return;
      }
      final w = ((st[cur] ?? 0) < 5 && rnd01() < .35) ? _wp[cur]! : pickOf(open);
      items.add(_Item('wp', x, y, 10, w.id));
    } else if (r < wpChance + .12) {
      items.add(_Item('coin', x, y, 9));
    } else if (r < wpChance + .18 && hp < maxHp) {
      items.add(_Item('heart', x, y, 9));
    } else if (r < wpChance + .22) {
      items.add(_Item('shield', x, y, 9));
    }
  }

  void killFoe(_Foe f) {
    if (f.dead) return;
    f.dead = true;
    sfx('boom');
    B.add(f.x, f.y, f.s * 1.8);
    D.debris(f.x, f.y, 10, 0x495057, 300);
    D.puff(f.x, f.y, 6, const Color(0xFF505050), 60, 10);
    SH.add(f.boss ? 16 : (f.k == 'heavy' ? 8 : 5));
    F.star(f.x, f.y);
    en = math.min(100, en + (f.boss ? 40 : (f.k == 'heavy' || f.k == 'turret' ? 12 : 8)));
    coinsRun += 3;
    if (f.boss) {
      bossDone = true;
      boss = null;
      coinsRun += 5;
      for (var i = 0; i < 5; i++) {
        B.add(f.x + rnd(-60, 60), f.y + rnd(-50, 50), f.s);
      }
      final open = kTkWeapons.where((w) => (st[w.id] ?? 0) < 5).toList();
      items.add(_Item('wp', f.x, f.y, 12, open.isEmpty ? 'norm' : pickOf(open).id));
      finish(true);
      return;
    }
    killed++;
    drop(f.x, f.y, lv < 10 ? .24 : .17);
    if (killed >= need) {
      if (bossLv) {
        if (boss == null && !bossDone) spawnBoss();
      } else {
        finish(true);
      }
    }
  }

  void hurtFoe(_Foe f, double d, double x, double y) {
    if (f.dead || d <= 0) return;
    f.hp -= d;
    f.flash = .1;
    if (f.hp <= 0) {
      killFoe(f);
    } else {
      D.sparks(x, y, 4, 0xffe066, 180);
    }
  }

  void wallHit(_Wall w, double d) {
    w.hp -= d;
    w.hitT = .15;
    if (w.hp <= 0 && walls.contains(w)) {
      walls.remove(w);
      B.add(w.x, w.y, w.w * 1.4, 'smoke');
      D.debris(w.x, w.y, 12, w.k == 'crateWood' ? 0xc08552 : 0xd8c8a0, 260);
      SH.add(4);
      sfx('pop');
      if (w.k == 'crateWood') drop(w.x, w.y, .55);
    }
  }

  void splash(double x, double y, double rad, double d, [bool big = false]) {
    B.add(x, y, rad * 1.6);
    if (big) B.add(x + rnd(-20, 20), y + rnd(-20, 20), rad * 1.2);
    D.sparks(x, y, 10, 0xffa94d, 300);
    SH.add(big ? 8 : 4);
    sfx('boom');
    for (final f in [...foes]) {
      if (!f.dead && hypot(f.x - x, f.y - y) < rad + f.s * .4) hurtFoe(f, f.boss && big ? f.max * .1 : d, f.x, f.y);
    }
    for (final w in [...walls]) {
      if (hypot(w.x - x, w.y - y) < rad + w.w * .4) wallHit(w, 1);
    }
  }

  void shot(double a, double sp, {String kind = 'norm', double dmg = 1, double r = 8, String? spr, int pierce = 0, int bn = 0, double? life, double turn = 0, double boom = 0, double rad = 0, double max = 1}) {
    if (bullets.length > 150) return;
    bullets.add(_Bul(mx + math.cos(a) * R * 1.4, my + math.sin(a) * R * 1.4, math.cos(a) * sp, math.sin(a) * sp, life ?? range / sp * 1.1, kind,
        mine: true, dmg: dmg, r: r, spr: spr, pierce: pierce, bn: bn, turn: turn, boom: boom, rad: rad, max: max));
  }

  _Foe? nearestFoe(double x, double y, [double maxD = double.infinity, _Foe? skip]) {
    _Foe? b;
    var bd = maxD;
    for (final f in foes) {
      if (f.dead || f == skip) continue;
      final d = hypot(f.x - x, f.y - y);
      if (d < bd) {
        bd = d;
        b = f;
      }
    }
    return b;
  }

  double flameRange() => R * (3.6 + .5 * (st['flame'] ?? 1));

  void fire(double tgx, double tgy) {
    final s = st[cur]!, a = mtur, fx0 = mx + math.cos(a) * R * 1.5, fy0 = my + math.sin(a) * R * 1.5;
    recoil = 1;
    switch (cur) {
      case 'norm':
        shot(a, 560, dmg: 1.0 + (s >= 3 ? 1 : 0) + (s >= 5 ? 1 : 0), r: 6 + s * 1.6, spr: const ['bulletGreen2', 'bulletGreen2', 'bulletBlue2', 'bulletBlue2', 'bulletDark2'][s - 1], pierce: s >= 4 ? 1 : 0);
        cd = (.46 - .04 * s) * cdMul;
        sfx('shoot');
      case 'multi':
        final n = const [2, 3, 3, 4, 5][s - 1];
        for (var i = 0; i < n; i++) {
          shot(a + (i - (n - 1) / 2) * .17, 520, dmg: s >= 3 ? 1.3 : 1, r: 8, spr: 'bulletGreen2');
        }
        cd = (.56 - .03 * s) * cdMul;
        sfx('shoot');
      case 'bounce':
        shot(a, 470, kind: 'bounce', dmg: 1 + (s >= 4 ? .6 : 0), bn: s + 1, r: 10.0 + s, life: 4);
        cd = (.5 - .02 * s) * cdMul;
        sfx('pop');
      case 'homing':
        final n = const [1, 1, 2, 2, 3][s - 1];
        for (var i = 0; i < n; i++) {
          shot(a + (i - (n - 1) / 2) * .6, 330, kind: 'homing', dmg: 2.0 + (s >= 3 ? 1 : 0), turn: 2.5 + s * .7, boom: s >= 4 ? R * 1.6 : 0, r: 24.0 + s * 2, life: 3.2);
        }
        cd = (1 - .06 * s) * cdMul;
        sfx('shoot');
      case 'blast':
        final d = hypot(tgx - fx0, tgy - fy0), sp = 420.0, l = math.max(.15, d / sp);
        shot(a, sp, kind: 'blast', dmg: 2.0 + s ~/ 2, rad: R * (1.5 + .35 * s), life: l, r: 16.0 + s * 2, max: l);
        cd = (1.15 - .07 * s) * cdMul;
        sfx('shoot');
        SH.add(3);
      case 'laser':
        final len = range * 1.2, w = 4 + s * 2.4, d = 1.0 + ((s - 1) ~/ 2) + (s >= 5 ? .5 : 0);
        beams.add((fx0, fy0, a, len, w, .22, const [0xff6b6b, 0xff8787, 0xf783ac, 0xda77f2, 0x9775fa][s - 1]));
        final cx = math.cos(a), cy = math.sin(a);
        for (final f in [...foes]) {
          if (f.dead) continue;
          final px = f.x - fx0, py = f.y - fy0, along = px * cx + py * cy;
          if (along < 0 || along > len) continue;
          if ((px * cy - py * cx).abs() < f.s * .45 + w / 2) hurtFoe(f, d, f.x, f.y);
        }
        cd = (.78 - .05 * s) * cdMul;
        sfx('laser');
      case 'flame':
        final fr = flameRange(), sp = 330.0, n = s >= 4 ? 2 : 1;
        for (var i = 0; i < n; i++) {
          shot(a + rnd(-1, 1) * (.14 + .04 * s), sp * rnd(.85, 1.1), kind: 'flame', dmg: .25 + .08 * s, life: fr / sp, r: 8, max: fr / sp);
        }
        cd = .09 * cdMul;
        recoil = .4;
        sndT -= 1;
        if (sndT <= 0) {
          sndT = 4;
          sfx('shoot');
        }
      case 'mine':
        shot(a, 520, dmg: 1, r: 7, spr: 'bulletGreen2');
        cd = .8 * cdMul;
        sfx('shoot');
    }
    if (cur != 'flame' && cur != 'laser') {
      D.puff(fx0, fy0, 3, const Color(0xFFE6E6E6), 40, 5);
      SH.add(1.2);
    }
  }

  void hurt() {
    if (inv > 0 || end != null) return;
    if (eshield > 0) return;
    if (shield > 0) {
      shield = 0;
      inv = 1;
      sfx('pop');
      return;
    }
    hp--;
    inv = 1.4;
    sfx('hit');
    B.add(mx, my, R * 2.5);
    SH.add(10);
    if (hp <= 0) finish(false);
  }

  @override
  Object? step(double dt) {
    t += dt;
    F.update(dt);
    D.update(dt);
    B.update(dt);
    SH.update(dt);
    recoil = math.max(0, recoil - dt * 4);
    for (final w in walls) {
      w.hitT = math.max(0, w.hitT - dt);
    }
    for (var i = 0; i < tracks.length; i++) {
      final tr = tracks[i];
      if (tr.$4 > 0) tracks[i] = (tr.$1, tr.$2, tr.$3, math.max(0, tr.$4 - dt));
    }
    for (var i = beams.length - 1; i >= 0; i--) {
      final b = beams[i];
      final l = b.$6 - dt;
      if (l <= 0) {
        beams.removeAt(i);
      } else {
        beams[i] = (b.$1, b.$2, b.$3, b.$4, b.$5, l, b.$7);
      }
    }
    if (end != null) {
      endT += dt;
      return endT > 2 ? end : null;
    }
    if (t < 2) return null;
    inv = math.max(0, inv - dt);
    cd -= dt;
    shield = math.max(0, shield - dt);
    eshield = math.max(0, eshield - dt);
    if (tx != null) {
      final dx = tx! - mx, dy = ty! - my, d = hypot(dx, dy);
      if (d > 8) {
        final ta = math.atan2(dy, dx);
        final da = angDiff(ta, ma);
        ma += clamp(da, -7 * dt, 7 * dt);
        final sp = speed * (1 - math.min(.6, da.abs() / 2));
        final nx = mx + dx / d * sp * dt, ny = my + dy / d * sp * dt;
        trackD += sp * dt;
        if (trackD > R * .5) {
          trackD = 0;
          tracks[trackI] = (mx, my, ma, 3);
          trackI = (trackI + 1) % tracks.length;
          if (rnd01() < .4) D.emit(mx - math.cos(ma) * R, my - math.sin(ma) * R, rnd(-20, 20), rnd(-20, 20), life: .5, r: 4, grow: 10, c: sand ? const Color(0xFFDCBE8C) : const Color(0xFFAA966E), a: .5);
        }
        if (inWall(nx, my, R) == null) mx = clamp(nx, R, W - R);
        if (inWall(mx, ny, R) == null) my = clamp(ny, 80 + R, H - R);
      }
    }
    // Ngắm: địch gần nhất trong tầm; không có địch thì bắn thùng gỗ (có quà)
    double? tgx, tgy;
    final nf = nearestFoe(mx, my, cur == 'flame' ? flameRange() * 1.15 : range);
    if (nf != null) {
      tgx = nf.x;
      tgy = nf.y;
    } else if (cur != 'flame' && cur != 'mine') {
      _Wall? best;
      for (final w in walls) {
        if (w.k != 'crateWood') continue;
        final d = hypot(w.x - mx, w.y - my);
        if (d < range * .7 && (best == null || d < hypot(best.x - mx, best.y - my))) best = w;
      }
      if (best != null) {
        tgx = best.x;
        tgy = best.y;
      }
    }
    if (tgx != null) {
      final da = angDiff(math.atan2(tgy! - my, tgx - mx), mtur);
      mtur += clamp(da, -9 * dt, 9 * dt);
      aimOk = da.abs() < .35;
      if (cd <= 0 && aimOk) fire(tgx, tgy);
    }
    if (cur == 'mine') {
      mcd -= dt;
      final s = st['mine']!;
      if (mcd <= 0 && foes.isNotEmpty && mines.length < 2 + s) {
        mcd = (1.5 - .12 * s) * cdMul;
        mines.add(_Mine(mx - math.cos(ma) * R * 1.3, my - math.sin(ma) * R * 1.3, s));
        sfx('pop');
      }
    }
    spawn -= dt;
    if (boss == null && spawn <= 0 && foes.length < ramp(lv, 2, 6).round() && killed + foes.length < need) {
      spawn = ramp(lv, 2.2, .9);
      final k = pickFoe();
      addFoe(k, rnd(W * .1, W * .9), k == 'turret' ? rnd(H * .18, H * .5) : 100);
    }
    final add = <String>[];
    for (final f in [...foes]) {
      if (f.dead) continue;
      f.ph += dt;
      f.flash = math.max(0, f.flash - dt);
      final T = FT[f.k]!;
      final aim = math.atan2(my - f.y, mx - f.x);
      f.tur += clamp(angDiff(aim, f.tur), -3 * dt, 3 * dt);
      if (f.boss) {
        final gy = math.min(H * .3, 170.0), nx = W / 2 + math.sin(f.ph * .45) * W * .32;
        f.y += (gy - f.y) * math.min(1, dt * 1.5);
        f.x += (nx - f.x) * math.min(1, dt * 1.2);
        f.ang = math.pi / 2;
        f.cd -= dt;
        f.cd2 -= dt;
        if (f.cd <= 0) {
          f.cd = ramp(lv, 2.2, 1.2);
          final n = lv < 20 ? 3 : 5;
          for (var i = 0; i < n; i++) {
            final b = f.tur + (i - (n - 1) / 2) * .22;
            bullets.add(_Bul(f.x + math.cos(b) * f.s * .5, f.y + math.sin(b) * f.s * .5, math.cos(b) * ebs, math.sin(b) * ebs, 6, 'enemy', big: true));
          }
          SH.add(3);
          D.puff(f.x + math.cos(f.tur) * f.s * .5, f.y + math.sin(f.tur) * f.s * .5, 4, const Color(0xFFE6E6E6), 40, 6);
        }
        if (f.cd2 <= 0) {
          f.cd2 = ramp(lv, 7, 4.5);
          if (foes.length < 5) add.addAll(['basic', lv >= 10 ? 'fast' : 'basic']);
        }
      } else if (f.k != 'turret') {
        final a = aim + math.sin(f.ph) * .8;
        f.ang += clamp(angDiff(a, f.ang), -4 * dt, 4 * dt);
        final v = fsp * T.$4, nx = f.x + math.cos(a) * v * dt, ny = f.y + math.sin(a) * v * dt * .6;
        if (inWall(nx, ny, f.s * .4) == null) {
          f.x = clamp(nx, f.s / 2, W - f.s / 2);
          f.y = clamp(ny, 90, H * .7);
        }
        if (f.k == 'fast' && rnd01() < .2) D.emit(f.x, f.y, rnd(-15, 15), rnd(-15, 15), life: .4, r: 3, grow: 8, c: const Color(0xFFAA966E), a: .4);
      }
      if (!f.boss) {
        f.cd -= dt;
        if (f.cd <= 0) {
          f.cd = rnd(fireRate * .8, fireRate * 1.3) * (f.k == 'turret' ? 1.3 : (f.k == 'fast' ? 1.2 : 1));
          final n = f.k == 'turret' ? 3 : 1;
          for (var i = 0; i < n; i++) {
            final b = f.tur + (i - (n - 1) / 2) * .25;
            bullets.add(_Bul(f.x + math.cos(b) * f.s * .5, f.y + math.sin(b) * f.s * .5, math.cos(b) * ebs, math.sin(b) * ebs, 6, 'enemy'));
          }
          D.puff(f.x + math.cos(f.tur) * f.s * .55, f.y + math.sin(f.tur) * f.s * .55, 2, const Color(0xFFE6E6E6), 30, 4);
        }
      }
      if (hypot(f.x - mx, f.y - my) < R + f.s * .4) {
        if (eshield > 0) {
          hurtFoe(f, 3 * dt * hpMul, f.x, f.y);
        } else {
          hurt();
        }
      }
      if (eshield > 0 && hypot(f.x - mx, f.y - my) < R * 1.9 + f.s * .4) hurtFoe(f, 2 * dt * hpMul, f.x, f.y);
    }
    for (final k in add) {
      final b = boss;
      addFoe(k, b != null ? b.x + rnd(-60, 60) : W / 2, 110);
    }
    for (var i = allies.length - 1; i >= 0; i--) {
      final al = allies[i];
      al.inv = math.max(0, al.inv - dt);
      al.cd -= dt;
      final gx = mx + (al.slot > 0 ? 1 : -1) * R * 2.4, gy = math.min(H - R, my + R * 1.6), dx = gx - al.x, dy = gy - al.y, d = hypot(dx, dy);
      if (d > 6) {
        final v = math.min(d * 3, speed * 1.1);
        al.x += dx / d * v * dt;
        al.y += dy / d * v * dt;
        al.a += clamp(angDiff(math.atan2(dy, dx), al.a), -6 * dt, 6 * dt);
      }
      final ft = nearestFoe(al.x, al.y, range * .9);
      if (ft != null) {
        final da = angDiff(math.atan2(ft.y - al.y, ft.x - al.x), al.tur);
        al.tur += clamp(da, -8 * dt, 8 * dt);
        if (al.cd <= 0 && da.abs() < .4 && bullets.length < 150) {
          al.cd = .75 * cdMul;
          final a = al.tur;
          bullets.add(_Bul(al.x + math.cos(a) * R, al.y + math.sin(a) * R, math.cos(a) * 520, math.sin(a) * 520, range / 520, 'norm', mine: true, dmg: 1, r: 6, spr: 'bulletGreen2'));
        }
      }
    }
    for (var i = bullets.length - 1; i >= 0; i--) {
      if (i >= bullets.length) continue;
      final b = bullets[i];
      if (b.kind == 'homing') {
        final f = nearestFoe(b.x, b.y);
        if (f != null) {
          final a = math.atan2(b.vy, b.vx), da = angDiff(math.atan2(f.y - b.y, f.x - b.x), a), na = a + clamp(da, -b.turn * dt, b.turn * dt), sp = hypot(b.vx, b.vy);
          b.vx = math.cos(na) * sp;
          b.vy = math.sin(na) * sp;
        }
        if (rnd01() < .5) D.emit(b.x, b.y, rnd(-20, 20), rnd(-20, 20), life: .35, r: 3, grow: 8, c: const Color(0xFFC8C8C8), a: .5);
      }
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.life -= dt;
      if (b.kind == 'blast') {
        if (b.life <= 0) {
          bullets.remove(b);
          splash(b.x, b.y, b.rad, b.dmg);
        }
        continue;
      }
      if (b.life <= 0) {
        bullets.remove(b);
        continue;
      }
      final out = b.x < 0 || b.x > W || b.y < 70 || b.y > H;
      if (out) {
        if (b.kind == 'bounce' && b.bn > 0) {
          b.bn--;
          if (b.x < 0 || b.x > W) {
            b.vx = -b.vx;
          } else {
            b.vy = -b.vy;
          }
          b.x = clamp(b.x, 1, W - 1);
          b.y = clamp(b.y, 71, H - 1);
          sfx('pop');
        } else {
          bullets.remove(b);
          continue;
        }
      }
      final w = inWall(b.x, b.y, 4);
      if (w != null) {
        if (b.mine) wallHit(w, b.kind == 'flame' ? b.dmg : 1);
        if (b.kind == 'bounce' && b.bn > 0) {
          b.bn--;
          final kx = (b.x - w.x) / (w.w / 2), ky = (b.y - w.y) / (w.h / 2);
          if (kx.abs() > ky.abs()) {
            b.vx = -b.vx;
          } else {
            b.vy = -b.vy;
          }
          b.x += b.vx * dt * 2;
          b.y += b.vy * dt * 2;
          D.sparks(b.x, b.y, 4, 0xffa94d, 140);
          continue;
        }
        bullets.remove(b);
        D.sparks(b.x, b.y, 5, 0xffe066, 160);
        if (b.boom > 0) splash(b.x, b.y, b.boom, b.dmg * .5);
        continue;
      }
      if (b.mine) {
        _Foe? f;
        for (final q in foes) {
          if (!q.dead && q != b.last && hypot(q.x - b.x, q.y - b.y) < q.s * .5 + (b.kind == 'flame' ? 8 : 0)) {
            f = q;
            break;
          }
        }
        if (f == null) continue;
        hurtFoe(f, b.dmg, b.x, b.y);
        b.last = f;
        if (b.boom > 0) splash(b.x, b.y, b.boom, b.dmg * .5);
        if (b.pierce > 0) {
          b.pierce--;
          continue;
        }
        if (b.kind == 'bounce' && b.bn > 0) {
          b.bn--;
          final n2 = nearestFoe(b.x, b.y, range, f), sp = hypot(b.vx, b.vy);
          if (n2 != null) {
            final a = math.atan2(n2.y - b.y, n2.x - b.x);
            b.vx = math.cos(a) * sp;
            b.vy = math.sin(a) * sp;
          } else {
            b.vx = -b.vx;
            b.vy = -b.vy;
          }
          continue;
        }
        bullets.remove(b);
      } else {
        final dm = hypot(b.x - mx, b.y - my);
        if (eshield > 0 && dm < R * 1.9) {
          bullets.remove(b);
          D.sparks(b.x, b.y, 6, 0x74c0fc, 200);
          continue;
        }
        if (dm < R) {
          bullets.remove(b);
          hurt();
          continue;
        }
        final al = allies.where((a) => hypot(b.x - a.x, b.y - a.y) < R * .75).firstOrNull;
        if (al != null) {
          bullets.remove(b);
          if (al.inv <= 0 && --al.hp <= 0) {
            allies.remove(al);
            B.add(al.x, al.y, R * 2);
            sfx('boom');
          } else {
            al.inv = .6;
            D.sparks(b.x, b.y, 5, 0xffe066, 160);
          }
        }
      }
    }
    for (var i = mines.length - 1; i >= 0; i--) {
      final m = mines[i];
      m.t += dt;
      if (m.t > 25) {
        mines.removeAt(i);
        continue;
      }
      if (m.t < .4) continue;
      final f = nearestFoe(m.x, m.y, R * 3.2);
      if (f == null) continue;
      final d = hypot(f.x - m.x, f.y - m.y);
      if (d < f.s * .5 + 10) {
        mines.removeAt(i);
        splash(m.x, m.y, R * (1.4 + .3 * m.s), 3.0 + m.s);
        continue;
      }
      m.x += (f.x - m.x) / d * 150 * dt;
      m.y += (f.y - m.y) / d * 150 * dt;
    }
    final pl = plane;
    if (pl != null) {
      final nx = pl.$1 + (W + 200) / 1.6 * dt;
      plane = nx > W + 100 ? null : (nx, pl.$2, pl.$3 + dt);
    }
    for (var i = bombs.length - 1; i >= 0; i--) {
      final bm = bombs[i];
      bm.t -= dt;
      final f = bm.f;
      if (f != null && !f.dead) {
        bm.x = f.x;
        bm.y = f.y;
      }
      if (bm.t <= 0) {
        bombs.removeAt(i);
        splash(bm.x, bm.y, R * 2.2, 5 * hpMul, true);
      }
    }
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.t -= dt;
      if (it.t <= 0) {
        items.removeAt(i);
        continue;
      }
      if (hypot(it.x - mx, it.y - my) > R + 26) continue;
      items.removeAt(i);
      switch (it.k) {
        case 'wp':
          st[it.w!] = math.min(5, (st[it.w] ?? 0) + 1);
          cur = it.w!;
          sfx('power');
          F.burst(mx, my, 16);
          F.text(mx, my - R * 2, '${_wp[it.w]!.vi} ${'★' * st[it.w]!}', 0xffe066);
          saveNow();
        case 'coin':
          coinsRun += 3;
          sfx('coin');
          F.text(it.x, it.y - 20, '+3', 0xffd43b);
        case 'heart':
          hp = math.min(maxHp, hp + 1);
          sfx('power');
        default:
          shield = 8;
          sfx('power');
      }
    }
    foes.removeWhere((f) => f.dead);
    return null;
  }

  @override
  void paint(Canvas c) {
    c.save();
    SH.apply(c);
    if (tk != null) {
      // Nền đất tĩnh: chụp một lần thành ảnh (trước đây ~50 drawImageRect mỗi khung).
      if (_ground == null || _groundSize != Size(W, H)) {
        _groundSize = Size(W, H);
        final rec = ui.PictureRecorder();
        gfx.tile(Canvas(rec), tk, groundK, math.max(96, S * .16), 0, 0, -10, -10, W + 20, H + 20);
        _ground = flattenPicture(rec.endRecording(), W + 20, H + 20, x: -10, y: -10, filter: FilterQuality.low);
      }
      c.drawPicture(_ground!);
    } else {
      rect(c, 0, 0, W, H, Color(th.ground));
    }
    for (final tr in tracks) {
      if (tr.$4 > 0) gfx.spr(c, tk, 'tracksSmall', tr.$1, tr.$2, R * .9, rot: tr.$3 + math.pi / 2, alpha: math.min(.5, tr.$4 * .25));
    }
    for (final w in walls) {
      final k = 1 + w.hitT * 1.2;
      if (!gfx.spr(c, tk, w.k, w.x, w.y, w.h * k * (w.k == 'crateWood' ? 1 : .8), alpha: .55 + math.max(0, w.hp) * .15, rot: w.hitT * 1.5)) {
        fillRR(c, w.x - w.w / 2, w.y - w.h / 2, w.w, w.h, 6, w.k == 'crateWood' ? hex(0xc08552) : hex(0xd8c8a0));
      }
    }
    for (final m in mines) {
      gfx.draw(c, 'Bomb', m.x, m.y, 30);
      if ((m.t * 4).floor() % 2 == 1) circle(c, m.x + 7, m.y - 9, 4, hex(0xff2b2b));
    }
    for (final it in items) {
      final y = it.y + math.sin(t * 5 + it.x) * 3, al = it.t < 2 && (it.t * 6).floor() % 2 == 1 ? .4 : 1.0;
      if (it.k == 'wp') {
        final w = _wp[it.w]!, s = narrow ? 44.0 : 52.0;
        fillRR(c, it.x - s / 2 + 3, y - s / 2 + 5, s, s, 12, rgba(0, 0, 0, .25 * al));
        fillRR(c, it.x - s / 2, y - s / 2, s, s, 12, hex(w.c, al));
        c.drawRRect(rr(it.x - s / 2, y - s / 2, s, s, 12), strokeP(Colors.white.withValues(alpha: al), 3 + math.sin(t * 8) * 1.5));
        gfx.draw(c, w.img, it.x, y, s * .7, s * .7, false, 0, al);
        gfx.draw(c, 'Glowing star', it.x + s * .42, y - s * .42, 22, 22, false, 0, al);
      } else {
        gfx.draw(c, it.k == 'coin' ? 'Coin' : (it.k == 'heart' ? 'Red heart' : 'Shield'), it.x, y, 40, 40, false, 0, al);
      }
    }
    for (final f in foes) {
      final T = FT[f.k]!, al = f.flash > 0 ? .55 : 1.0;
      if (f.k == 'turret') {
        gfx.spr(c, tk, 'crateMetal', f.x, f.y, f.s, alpha: al);
        final bl = f.s * .6;
        gfx.spr(c, tk, T.$2, f.x + math.cos(f.tur) * bl * .35, f.y + math.sin(f.tur) * bl * .35, bl, rot: f.tur - math.pi / 2, alpha: al);
      } else if (f.boss) {
        drawTank(c, gfx, tk, f.x, f.y, T.$1, T.$2, f.s * 1.05, f.ang, f.tur, 0, al);
        final o = f.s * .22;
        for (final sx in [-1.0, 1.0]) {
          gfx.spr(c, tk, 'specialBarrel1', f.x + math.cos(f.tur) * f.s * .25 - math.sin(f.tur) * o * sx, f.y + math.sin(f.tur) * f.s * .25 + math.cos(f.tur) * o * sx, f.s * .4, rot: f.tur - math.pi / 2, alpha: al);
        }
      } else {
        drawTank(c, gfx, tk, f.x, f.y, T.$1, T.$2, f.s * 1.05, f.ang, f.tur, 0, al);
      }
      if (!f.boss && f.max > 1.5 && f.hp < f.max) {
        final bw = f.s * .8;
        rect(c, f.x - bw / 2, f.y - f.s * .7, bw, 6, rgba(0, 0, 0, .4));
        rect(c, f.x - bw / 2, f.y - f.s * .7, bw * math.max(0, f.hp / f.max), 6, hex(0xff6b6b));
      }
    }
    for (final al in allies) {
      if (al.inv > 0 && (al.inv * 10).floor() % 2 == 1) continue;
      drawTank(c, gfx, tk, al.x, al.y, BODY.$2, BODY.$3, R * 1.45, al.a, al.tur);
      gfx.draw(c, 'Military helmet', al.x, al.y, R * .7);
    }
    final blink = inv > 0 && (inv * 10).floor() % 2 == 1;
    if (!blink) {
      drawTank(c, gfx, tk, mx, my, BODY.$2, BODY.$3, R * 2.1, ma, mtur, recoil);
      if (recoil > .7 && cur != 'flame' && cur != 'laser') gfx.spr(c, tk, 'shotOrange', mx + math.cos(mtur) * R * 1.9, my + math.sin(mtur) * R * 1.9, R * .9, rot: mtur + math.pi / 2);
      if (shield > 0) strokeCircle(c, mx, my, R * 1.5 + math.sin(t * 6) * 3, rgba(116, 192, 252, .6 + .2 * math.sin(t * 10)), 5);
    }
    if (eshield > 0) {
      final rr0 = R * 1.9, al = eshield < 1.5 && (eshield * 6).floor() % 2 == 1 ? .35 : 1.0;
      circle(c, mx, my, rr0, rgba(77, 171, 247, .18 * al));
      strokeCircle(c, mx, my, rr0, hex(0x74c0fc, al), 4);
      final path = Path();
      for (var k = 0; k < 4; k++) {
        var a = rnd(0, tau);
        path.moveTo(mx + math.cos(a) * rr0, my + math.sin(a) * rr0);
        for (var j = 1; j < 4; j++) {
          a += rnd(.1, .3);
          final r2 = rr0 * rnd(.85, 1.1);
          path.lineTo(mx + math.cos(a) * r2, my + math.sin(a) * r2);
        }
      }
      c.drawPath(path, strokeP(hex(0xe7f5ff, al), 2));
    }
    for (final bm in beams) {
      final k = bm.$6 / .22, ex = bm.$1 + math.cos(bm.$3) * bm.$4, ey = bm.$2 + math.sin(bm.$3) * bm.$4;
      line(c, bm.$1, bm.$2, ex, ey, hex(bm.$7, k), bm.$5 * 2);
      line(c, bm.$1, bm.$2, ex, ey, Colors.white.withValues(alpha: k), bm.$5 * .6);
    }
    for (final b in bullets) {
      final a = math.atan2(b.vy, b.vx);
      switch (b.kind) {
        case 'enemy':
          if (!gfx.spr(c, tk, 'bulletRed2', b.x, b.y, b.big ? 28 : 20, rot: a + math.pi / 2)) circle(c, b.x, b.y, b.big ? 8 : 6, hex(0xfa5252));
        case 'flame':
          final k = 1 - b.life / b.max;
          circle(c, b.x, b.y, 6 + k * 14, (k < .3 ? hex(0xffe066) : (k < .6 ? hex(0xff922b) : hex(0xe03131))).withValues(alpha: 1 - k * .7));
        case 'bounce':
          gfx.draw(c, 'Basketball', b.x, b.y, b.r * 2, b.r * 2, false, t * 12);
        case 'homing':
          gfx.draw(c, 'Rocket', b.x, b.y, b.r, b.r, false, a + math.pi / 4);
        case 'blast':
          final k = 1 - b.life / b.max, lift = math.sin(k * math.pi) * 40;
          ellipse(c, b.x, b.y, b.r * .5, b.r * .3, rgba(0, 0, 0, .25));
          circle(c, b.x, b.y - lift, b.r * .55, hex(0x343a40));
          circle(c, b.x - 3, b.y - lift - 3, b.r * .2, hex(0xff922b));
        default:
          if (!gfx.spr(c, tk, b.spr ?? 'bulletGreen2', b.x, b.y, b.r * 2.4, rot: a + math.pi / 2)) circle(c, b.x, b.y, b.r * .6, hex(0x37b24d));
      }
    }
    D.draw(c);
    for (final d in deco) {
      gfx.spr(c, tk, d.$3, d.$1, d.$2, d.$4);
    }
    B.draw(c);
    final pl = plane;
    if (pl != null) {
      ellipse(c, pl.$1 + 30, pl.$2 + 70, 50, 16, rgba(0, 0, 0, .18));
      gfx.draw(c, 'Airplane', pl.$1, pl.$2, 110, 110, false, math.pi / 4);
    }
    F.draw(c);
    c.restore();
    _hud(c);
    if (t < 2) levelBanner(c, W, H, lv, bossLv ? 'Hạ $need xe tăng + TRÙM' : 'Hạ $need xe tăng địch', 'Chạm để lái · Nhặt hộp súng · Nút trái đổi đạn, nút phải dùng chiêu');
    final e = end;
    if (e != null) banner(c, W, H, e.win ? funEndText(true, lv) : 'XE TĂNG HỎNG RỒI!', 'Hạ $killed/$need');
  }

  void _hud(Canvas c) {
    final ct = '${G.coins + coinsRun}';
    fillRR(c, 12, 10, math.max(narrow ? 112 : 150, Txt.width(ct, 28) + 66), 44, 22, rgba(0, 0, 0, .28));
    gfx.draw(c, 'Coin', 38, 32, 30);
    Txt.draw(c, ct, 60, 42, size: 28, align: TA.left);
    final hs = math.min(narrow ? 22.0 : 30.0, W * .42 / maxHp - 3), hg = hs + 3;
    for (var i = 0; i < maxHp; i++) {
      gfx.draw(c, 'Red heart', W - 12 - hs / 2 - i * hg, 32, hs, hs, false, 0, i < hp ? 1 : .22);
    }
    final ew = math.min(170.0, W * .3), ex = W - 12 - ew, ey = 52.0;
    fillRR(c, ex, ey, ew, 14, 7, rgba(0, 0, 0, .3));
    fillRR(c, ex + 2, ey + 2, math.max(4, (ew - 4) * en / 100), 10, 5, hex(0xffd43b));
    gfx.draw(c, 'High voltage', ex - 12, ey + 7, 22);
    goalPill(c, W, killed, need, 16);
    final b = boss;
    if (b != null) {
      final bw = math.min(360.0, W * .6), by = narrow ? 104.0 : 62.0;
      fillRR(c, W / 2 - bw / 2, by, bw, 20, 10, rgba(0, 0, 0, .4));
      fillRR(c, W / 2 - bw / 2 + 3, by + 3, (bw - 6) * math.max(0, b.hp / b.max), 14, 7, hex(0xff6b6b));
      gfx.draw(c, 'Collision', W / 2 - bw / 2 - 14, by + 10, 28);
    }
    if (t < 2) return;
    for (final b in wBtns()) {
      final on = b.$1.id == cur, r = b.$4 * (on ? 1.08 : .92);
      circle(c, b.$2, b.$3, r, on ? hex(b.$1.c) : rgba(0, 0, 0, .35));
      strokeCircle(c, b.$2, b.$3, r, on ? Colors.white : rgba(255, 255, 255, .5), on ? 4 : 2);
      gfx.draw(c, b.$1.img, b.$2, b.$3 - 4, r * 1.1);
      final n = st[b.$1.id]!, sw = math.min(11.0, r * .4);
      for (var k = 0; k < n; k++) {
        gfx.draw(c, 'Glowing star', b.$2 + (k - (n - 1) / 2) * sw, b.$3 + r * .68, sw + 2);
      }
    }
    for (final b in sBtns()) {
      final s = b.$1, ok = canSkill(s), k = math.min(1.0, en / s.$3);
      circle(c, b.$2, b.$3, b.$4, ok ? hex(s.$4) : rgba(0, 0, 0, .4));
      strokeCircle(c, b.$2, b.$3, b.$4 - 3, rgba(255, 255, 255, .3), 5);
      c.drawArc(Rect.fromCircle(center: Offset(b.$2, b.$3), radius: b.$4 - 3), -math.pi / 2, tau * k, false, strokeP(ok ? Colors.white : hex(0xffd43b), 5));
      final pulse = ok ? 1 + math.sin(t * 6) * .06 : 1.0;
      gfx.draw(c, s.$2, b.$2, b.$3, b.$4 * 1.15 * pulse, b.$4 * 1.15 * pulse, false, s.$1 == 'air' ? math.pi / 4 : 0, ok ? 1 : .45);
      if (s.$1 == 'ally') Txt.draw(c, '${allies.length}/2', b.$2, b.$3 + b.$4 + 2, size: 16);
    }
  }
}

class _Mine {
  _Mine(this.x, this.y, this.s);
  double x, y, t = 0;
  final int s;
}

class _Bomb {
  _Bomb(this.f, this.x, this.y, this.t);
  final _Foe? f;
  double x, y, t;
}
