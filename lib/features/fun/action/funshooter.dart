// ignore_for_file: non_constant_identifier_names, library_private_types_in_public_api
// Phi thuyền diệt quái (Flame).
// CHỦ: agent G. Port của reference/web/js/games/funshooter.js.
// 8 loại súng (laser, toả, plasma xuyên, tên lửa đuổi, tia sét nảy, chùm laser liên tục, đạn băng làm chậm, lốc xoáy bumerang),
// mỗi loại lên 5 sao; máy bay phụ, bom, 3 chiêu có nút (khiên năng lượng, mưa sao băng, phi thuyền khổng lồ) nạp khi hạ quái;
// trùm giữa trận và trùm cuối 2 giai đoạn. Kho đồ giữ qua màn (ctx.carry), Xưởng phi thuyền ở cấp đầu của vé.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/content/models.dart' show Json;
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'act_ui.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES).
final Map<String, FunGameModule> funshooterGames = {'shooter': const ShooterModule()};

class ShooterModule extends FunGameModule {
  const ShooterModule();
  @override
  String get id => 'shooter';
  @override
  Widget build(BuildContext context, FunGameContext ctx) => ShooterView(ctx: ctx);
}

// ---------- Dữ liệu ----------
const _bgs = ['bg_purple', 'bg_blue', 'bg_darkPurple', 'bg_black', 'bg_blue', 'bg_darkPurple'];
const _space = [(0x1a1b4b, 0x3b2c85), (0x0b3d3a, 0x1864ab), (0x3d0b2e, 0x862e9c), (0x1b1b1b, 0x495057), (0x0b2545, 0x0c8599), (0x3b0a0a, 0xc92a2a)];

class GunDef {
  const GunDef(this.c, this.vi, {this.s, this.f, this.orb = false});
  final int c;
  final String vi;
  final String? s, f;
  final bool orb;
}

const Map<String, GunDef> kGuns = {
  'laser': GunDef(0xffe066, 'LASER', s: 'laserBlue01'),
  'spread': GunDef(0x69db7c, 'ĐẠN TOẢ', f: 'Sparkles'),
  'plasma': GunDef(0xda77f2, 'PLASMA', orb: true),
  'missile': GunDef(0xff8787, 'TÊN LỬA', s: 'missile'),
  'thunder': GunDef(0x4dabf7, 'TIA SÉT', f: 'High voltage'),
  'beam': GunDef(0x3bc9db, 'CHÙM LASER', f: 'Flashlight'),
  'ice': GunDef(0xa5d8ff, 'ĐẠN BĂNG', f: 'Snowflake'),
  'vortex': GunDef(0xffa94d, 'LỐC XOÁY', f: 'Tornado'),
};
final List<String> kGunIds = kGuns.keys.toList();
const int kMaxStars = 5;
const List<(String, String, int, List<int>)> kShipUps = [
  ('hp', 'Red heart', 2, [350, 550]),
  ('armor', 'Shield', 3, [200, 350, 500]),
  ('rate', 'Fire', 3, [200, 350, 500]),
  ('drone', 'Satellite', 2, [250, 450]),
  ('bomb', 'Bomb', 3, [150, 250, 350]),
  ('magnet', 'Magnet', 2, [150, 300]),
];
const int kGunPrice = 300;
int starPrice(int n) => 100 * n;
const List<(String, String, int, int)> kSkills = [('shield', 'Shield', 0x4dabf7, 10), ('meteor', 'Shooting star', 0xffd43b, 18), ('giant', 'Rocket', 0xff6b6b, 26)];
const int kMaxBombs = 5, kMaxDrones = 2;

/// Kho đồ (readCarry/pack của web).
class ShipGear {
  ShipGear.from(Object? raw) {
    final c = raw is Map ? raw : const {};
    Map mp(Object? v) => v is Map ? v : const {};
    own['laser'] = 1;
    for (final g in kGunIds) {
      final n = jInt(mp(c['guns'])[g], 0, kMaxStars);
      if (n > 0) own[g] = n;
    }
    for (final u in kShipUps) {
      up[u.$1] = jInt(mp(c['up'])[u.$1], 0, u.$3);
    }
    for (final s in kSkills) {
      final v = mp(c['en'])[s.$1];
      en[s.$1] = v is num && v.isFinite ? clamp(v.toDouble()) : 0;
    }
    gun = own.containsKey(c['gun']) ? c['gun'] as String : 'laser';
    drones = jInt(math.max(jInt(c['drones']), up['drone']!), 0, kMaxDrones);
    bombs = jInt(math.max(1 + up['bomb']!, jInt(c['bombs'])), 1, kMaxBombs);
    coins = jInt(c['coins']);
    wins = jInt(c['wins']);
  }
  final Map<String, int> own = {}, up = {};
  final Map<String, double> en = {};
  String gun = 'laser';
  int drones = 0, bombs = 1, coins = 0, wins = 0;

  Json toJson() => {
        'v': 1,
        'guns': {...own},
        'gun': gun,
        'up': {...up},
        'drones': drones,
        'bombs': bombs.clamp(0, kMaxBombs),
        'coins': coins,
        'en': {for (final s in kSkills) s.$1: (en[s.$1]! * 100).round() / 100},
        'wins': wins,
      };
}

/// Biểu tượng súng: quả cầu màu + hình súng.
void gunIcon(Canvas c, Gfx g, SpriteSheet? sp, String id, double x, double y, double r, [double alpha = 1]) {
  final G = kGuns[id]!;
  circle(c, x, y, r, hex(G.c, alpha));
  strokeCircle(c, x, y, r, Colors.white.withValues(alpha: alpha), math.max(2, r * .14));
  circle(c, x, y, r * .72, rgba(0, 0, 0, .18 * alpha));
  if (G.f != null) {
    g.draw(c, G.f, x, y, r * 1.3, r * 1.3, false, 0, alpha);
  } else if (G.orb) {
    circle(c, x, y, r * .55, rgba(190, 75, 219, .9 * alpha));
    circle(c, x, y, r * .28, Colors.white.withValues(alpha: alpha));
  } else {
    g.spr(c, sp, G.s!, x, y, r * 1.5, rot: id == 'laser' ? .6 : -.6, alpha: alpha);
  }
}

// ---------- Widget ----------
class ShooterView extends StatefulWidget {
  const ShooterView({super.key, required this.ctx, this.skipShop = false});
  final FunGameContext ctx;
  final bool skipShop;
  @override
  State<ShooterView> createState() => _ShooterViewState();
}

const kShooterImgs = [
  'Rocket', 'Alien monster', 'Flying saucer', 'Ghost', 'Bat', 'Octopus', 'Comet', 'Alien', 'Glowing star', 'Shield', 'Red heart', 'Coin', 'Ringed planet', 'Crescent moon',
  'Bomb', 'Magnet', 'Satellite', 'Collision', 'Sparkles', 'High voltage', 'Flashlight', 'Snowflake', 'Tornado', 'Shooting star', 'Fire', 'Locked',
];

class _ShooterViewState extends State<ShooterView> {
  late final ActSession ses = actSession(widget.ctx);
  late final ShipGear gear = ShipGear.from(widget.ctx.carry);
  Gfx? gfx;
  ShooterGame? game;

  @override
  void initState() {
    super.initState();
    Gfx.load(kShooterImgs, ['space/space', 'fxa/fx']).then((g) {
      if (!mounted) return;
      setState(() => gfx = g);
      if (ses.data['shop'] == true || widget.skipShop) _go();
    });
  }

  void _go() {
    ses.data['shop'] = true;
    setState(() => game = ShooterGame(ctx: widget.ctx, gfx: gfx!, gear: gear));
  }

  @override
  Widget build(BuildContext context) {
    if (gfx == null) return const ActLoading();
    final g = game;
    if (g == null) return ShipShop(ctx: widget.ctx, gear: gear, gfx: gfx!, onPlay: _go);
    return ActGameView(
      ctx: widget.ctx,
      game: g,
      toResult: (r) {
        final e = r as ShootEnd;
        return FunResult(score: e.score, win: e.win, carry: e.carry);
      },
      onResult: (r) => actSessionDone(ses, widget.ctx, r),
    );
  }
}

/// Xưởng phi thuyền: chọn / mở súng, lên sao súng đang chọn, mua nâng cấp vĩnh viễn.
class ShipShop extends StatefulWidget {
  const ShipShop({super.key, required this.ctx, required this.gear, required this.gfx, required this.onPlay});
  final FunGameContext ctx;
  final ShipGear gear;
  final Gfx gfx;
  final VoidCallback onPlay;
  @override
  State<ShipShop> createState() => _ShipShopState();
}

class _ShipShopState extends State<ShipShop> {
  final Map<String, int> shakes = {};
  ShipGear get G => widget.gear;
  void save() => widget.ctx.saveGear(G.toJson());
  void buy(String key, int p, VoidCallback fn) {
    if (G.coins < p) {
      widget.ctx.audio.sfx('wrong');
      setState(() => shakes[key] = (shakes[key] ?? 0) + 1);
      return;
    }
    setState(() {
      G.coins -= p;
      fn();
    });
    widget.ctx.audio.sfx('power');
    save();
  }

  Widget gunPic(String g, double sz) => SizedBox(width: sz, height: sz, child: CustomPaint(painter: _GunPainter(widget.gfx, g)));

  Widget stars(int n, {int max = kMaxStars, String ch = '★', int color = 0xffd43b}) => Text.rich(TextSpan(children: [
        TextSpan(text: ch * n, style: shopText(18, color: hex(color))),
        TextSpan(text: ch * (max - n), style: shopText(18, color: const Color(0x4DFFFFFF))),
      ]));

  @override
  Widget build(BuildContext context) {
    final sel = G.gun, n = G.own[sel]!;
    Widget card(String key, Widget child, {bool on = false, VoidCallback? onTap}) => ShakeBox(
          trigger: shakes[key] ?? 0,
          child: SizedBox(width: 120, child: ShopCard(key: Key(key), on: on, onTap: onTap, child: child)),
        );
    final guns = kGunIds.map((g) {
      final has = G.own[g];
      return card('gun-$g', Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          Opacity(opacity: has != null ? 1 : .35, child: gunPic(g, 72)),
          if (has == null) const EmojiImage('Locked', size: 40, photo: false),
        ]),
        if (has != null) stars(has) else PriceTag(kGunPrice, ok: G.coins >= kGunPrice),
      ]), on: g == sel, onTap: () {
        if (has != null) {
          setState(() => G.gun = g);
          widget.ctx.audio.sfx('tap');
          save();
        } else {
          buy('gun-$g', kGunPrice, () {
            G.own[g] = 1;
            G.gun = g;
          });
        }
      });
    }).toList();
    final ups = <Widget>[
      card('star', Column(mainAxisSize: MainAxisSize.min, children: [
        gunPic(sel, 60),
        Text(n < kMaxStars ? '+★' : '★' * kMaxStars, style: shopText(16, color: hex(0xffd43b))),
        if (n < kMaxStars) PriceTag(starPrice(n), ok: G.coins >= starPrice(n)) else Text('MAX', style: shopText(16, color: hex(0xffd43b))),
      ]), onTap: () {
        if (n < kMaxStars) buy('star', starPrice(n), () => G.own[sel] = n + 1);
      }),
      for (final u in kShipUps)
        card('up-${u.$1}', Column(mainAxisSize: MainAxisSize.min, children: [
          EmojiImage(u.$2, size: 50, photo: false),
          stars(G.up[u.$1]!, max: u.$3, ch: '●', color: 0x69db7c),
          if (G.up[u.$1]! < u.$3) PriceTag(u.$4[G.up[u.$1]!], ok: G.coins >= u.$4[G.up[u.$1]!]) else Text('MAX', style: shopText(16, color: hex(0xffd43b))),
        ]), onTap: () {
          final lv = G.up[u.$1]!;
          if (lv >= u.$3) return;
          buy('up-${u.$1}', u.$4[lv], () {
            G.up[u.$1] = lv + 1;
            if (u.$1 == 'drone') G.drones = math.max(G.drones, G.up['drone']!);
            if (u.$1 == 'bomb') G.bombs = math.max(G.bombs, 1 + G.up['bomb']!).clamp(1, kMaxBombs);
          });
        }),
    ];
    return ShopFrame(colors: const [Color(0xFF1A1B4B), Color(0xFF5F3DC4)], children: [
      Wrap(spacing: 14, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('🚀 Xưởng phi thuyền', style: shopText(28)),
        CoinPill(G.coins),
      ]),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: guns),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: ups),
      PlayBtn(onTap: () {
        widget.ctx.audio.sfx('power');
        widget.onPlay();
      }),
    ]);
  }
}

class _GunPainter extends CustomPainter {
  _GunPainter(this.g, this.id);
  final Gfx g;
  final String id;
  @override
  void paint(Canvas canvas, Size size) => gunIcon(canvas, g, g.sh('space/space'), id, size.width / 2, size.height / 2, size.width * .4);
  @override
  bool shouldRepaint(covariant _GunPainter old) => old.id != id;
}

// ---------- Game ----------
class ShootEnd {
  ShootEnd(this.win, this.score, this.bonus, this.carry);
  final bool win;
  final int score, bonus;
  final Json carry;
}

class _Shot {
  _Shot(this.x, this.y, this.vx, this.vy, this.w, this.h, this.dmg, this.k, {this.pierce = 0, this.seek = false, this.slow = false, this.ay = 0});
  double x, y, vx, vy, ay;
  final double w, h, dmg;
  final String k;
  int pierce;
  final bool seek, slow;
  bool back = false, hitB = false;
  Set<_Foe>? hitSet;
}

class _Foe {
  _Foe(this.k, this.hp, this.pts, this.x, this.y, this.w, this.h, this.vy, {this.vx = 0, this.ph = 0, this.cd = 9, this.wave = 0, this.swoop = false, this.gun = false, this.big = false});
  final String k;
  double hp, x, y, w, h, vy, vx, ph, cd, wave;
  final int pts;
  final bool swoop, gun, big;
  bool dead = false;
  double flash = 0, slow = 0;
}

class _Boss {
  _Boss(this.k, this.fin, this.x, this.y, this.w, this.h, this.hp) : max = hp;
  final String k;
  final bool fin;
  double x, y, w, h, hp, cd = 1.5, ph = 0, flash = 0;
  final double max;
}

class _Obj {
  _Obj(this.x, this.y, this.vx, this.vy, this.w, this.h, {this.k = '', this.gun});
  double x, y, vx, vy, w, h;
  final String k;
  final String? gun;
  bool hitB = false;
}

class ShooterGame extends ActGame {
  ShooterGame({required this.ctx, required super.gfx, required ShipGear gear})
      : G = gear,
        super(audio: ctx.audio, lv: ctx.level);
  final FunGameContext ctx;
  final ShipGear G;
  late final SpriteSheet? sp = gfx.sh('space/space'), fxs = gfx.sh('fxa/fx');
  late final (int, int) space = _space[(lv ~/ 10) % _space.length];
  late final int hpUp = lv ~/ 15;
  late final String bgK = _bgs[(lv ~/ 10) % _bgs.length];
  final Dust D = Dust(240);
  late final Booms B = Booms(gfx, fxs, 30);
  final Shaker SH = Shaker();
  late final Fx F = Fx(gfx);
  late bool narrow;
  late Map<String, int> own, cur;
  // me
  double mx = 0, my = 0, mvx = 0, bank = 0, mw = 0, mh = 0, tx = 0, ty = 0, inv = 0, shield = 0, magnet = 0, eshield = 0, giant = 0, gs = 1;
  late String gun;
  final List<_Shot> shots = [];
  final List<_Foe> foes = [];
  final List<_Obj> orbs = [], items = [], coins = [], meteors = [];
  final List<(double, double, double, double)> stars = [];
  final List<(List<Offset>, double)> zaps = [];
  late int maxLives, lives;
  late double rateK, magR, armorCd, armorT;
  double scrollY = 0, pop = 0, t = 0, fire = 0, droneFire = 0, spawn = 1.2, endT = 0, flash = 0, beamSnd = 0;
  int score = 0, got = 0, lastSave = 0;
  _Boss? boss;
  bool midDone = false;
  ShootEnd? end;
  late double btnR, skR;
  late Offset bombBtn;
  late List<Offset> skBtn;
  static const gunBarX = 68.0, gunBarY = 88.0, gunBarH = 44.0;

  List<String> owned() => kGunIds.where(own.containsKey).toList();
  double stepW() => math.min(40, (W - gunBarX - 14) / owned().length);
  double barW() => owned().length * stepW() + 8;

  @override
  void setup() {
    narrow = W < 520;
    own = G.own;
    cur = {...own};
    gun = G.gun;
    mx = W / 2;
    my = H * .8;
    mw = mh = S * .13;
    tx = W / 2;
    ty = H * .8;
    shield = G.up['armor']! > 0 ? 6 : 0;
    for (var i = 0; i < 80; i++) {
      final s = rnd(1, 3);
      stars.add((rnd(0, W), rnd(0, H), s, s * s * 18 + rnd(0, 20)));
    }
    maxLives = kLives + G.up['hp']!;
    lives = maxLives;
    rateK = 1 - .08 * G.up['rate']!;
    magR = S * (.15 + .08 * G.up['magnet']!);
    armorCd = G.up['armor']! > 0 ? 30 - 6.0 * G.up['armor']! : 0;
    armorT = armorCd;
    btnR = math.min(56, S * .09);
    bombBtn = Offset(W - btnR - 20, H - btnR - 20);
    skR = btnR * .85;
    skBtn = [for (var i = 0; i < kSkills.length; i++) Offset(skR + 20, H - skR - 20 - i * (skR * 2 + 14))];
  }

  void save() {
    lastSave = G.coins;
    ctx.saveGear(G.toJson());
  }

  // ---- Cảm ứng ----
  final Set<int> _btnPtr = {};
  VoidCallback? _button(double x, double y) {
    if (hypot(x - bombBtn.dx, y - bombBtn.dy) < btnR * 1.15) return useBomb;
    for (var i = 0; i < kSkills.length; i++) {
      if (hypot(x - skBtn[i].dx, y - skBtn[i].dy) < skR * 1.15) return () => useSkill(kSkills[i].$1);
    }
    if (x > gunBarX - 6 && x < gunBarX + barW() + 6 && y > gunBarY - 6 && y < gunBarY + gunBarH + 30) return nextGun;
    return null;
  }

  void _steer(Ptr p) {
    tx = p.x;
    ty = clamp(p.y - S * .09, H * .35, H - 30);
  }

  @override
  void down(Ptr p) {
    final fn = _button(p.x, p.y);
    if (fn != null) {
      _btnPtr.add(p.id);
      return fn();
    }
    _steer(p);
  }

  @override
  void move(Ptr p) {
    if (_btnPtr.contains(p.id)) return;
    _steer(p);
  }

  @override
  void up(Ptr p) => _btnPtr.remove(p.id);

  double power() => math.min(1.9, 1 + .1 * (cur[gun]! - 1) + .12 * G.drones + .05 * G.up['rate']! + .04 * G.up['armor']! + .05 * G.up['hp']!);
  String dropGun() {
    final r = rnd01(), o = owned().where((g) => g != gun).toList();
    return r < .5 || (r < .8 && o.isEmpty) ? gun : (r < .8 ? pickOf(o) : pickOf(kGunIds));
  }

  void drop(double x, double y) {
    for (var k = 0; k < 2; k++) {
      coins.add(_Obj(x + rnd(-14, 14), y, 0, rnd(-80, 20), 30, 30));
    }
    final r = rnd01();
    if (r < .1) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'gun', gun: dropGun()));
    } else if (r < .13) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'Shield'));
    } else if (r < .155) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'Red heart'));
    } else if (r < .18) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'Bomb'));
    } else if (r < .2) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'Satellite'));
    } else if (r < .22) {
      items.add(_Obj(x, y, 0, 0, 50, 50, k: 'Magnet'));
    }
  }

  void kill(_Foe f) {
    B.add(f.x, f.y, f.w * 1.5);
    D.sparks(f.x, f.y, 12, 0xffe066, 300);
    D.puff(f.x, f.y, 4, const Color(0xFFA0A0B4), 50, f.w * .15);
    SH.add(f.big ? 5 : 2.5);
    F.star(f.x, f.y);
    score += f.pts;
    sfx('boom');
    F.text(f.x, f.y - 30, '+${f.pts}', 0xffd43b);
    drop(f.x, f.y);
    for (final s in kSkills) {
      if (G.en[s.$1]! < 1) {
        G.en[s.$1] = math.min(1, G.en[s.$1]! + 1 / s.$4);
        if (G.en[s.$1]! >= 1) {
          sfx('star');
          F.text(W / 2, H * .55, 'CHIÊU SẴN SÀNG!', s.$3);
        }
      }
    }
  }

  bool hitFoe(_Foe f, double dmg, double x, double y) {
    if (f.dead) return false;
    f.hp -= dmg;
    f.flash = .08;
    if (f.hp > 0) {
      D.sparks(x, y, 5, 0xfff3bf, 180);
      return false;
    }
    f.dead = true;
    kill(f);
    return true;
  }

  void bossHit(double dmg, double x, double y) {
    final b = boss;
    if (b == null) return;
    b.hp -= dmg;
    b.flash = .08;
    D.sparks(x, y, 4, 0xfff3bf, 160);
    if (b.hp > 0) return;
    for (var k = 0; k < 8; k++) {
      B.add(b.x + rnd(-b.w * .4, b.w * .4), b.y + rnd(-b.h * .3, b.h * .3), rnd(90, 160));
    }
    SH.add(14);
    flash = .3;
    D.sparks(b.x, b.y, 30, 0xffd43b, 420);
    score += b.fin ? 40 : 15;
    sfx('win');
    drop(b.x, b.y);
    drop(b.x - 40, b.y);
    drop(b.x + 40, b.y);
    if (b.fin) {
      finish(true);
    } else {
      midDone = true;
      items.add(_Obj(b.x, b.y, 0, 0, 50, 50, k: 'gun', gun: dropGun()));
    }
    boss = null;
  }

  void finish(bool win) {
    if (end != null) return;
    var bonus = 0;
    if (win) {
      bonus = 10 + lv ~/ 3;
      G.coins += bonus;
      G.wins++;
    }
    end = ShootEnd(win, score, bonus, const {});
  }

  void useBomb() {
    if (G.bombs <= 0 || end != null) return;
    G.bombs--;
    flash = .5;
    SH.add(16);
    sfx('boom');
    sfx('win');
    for (var k = 0; k < 8; k++) {
      B.add(rnd(W * .1, W * .9), rnd(H * .1, H * .7), rnd(100, 180));
    }
    for (final f in foes) {
      if (!f.dead) {
        f.dead = true;
        kill(f);
      }
    }
    orbs.clear();
    final b = boss;
    if (b != null) bossHit(math.min(12, b.max * .15), b.x, b.y);
    F.text(W / 2, H * .45, 'BÙM!', 0xffd43b);
    save();
  }

  void useSkill(String id) {
    if (end != null || G.en[id]! < 1) {
      sfx('tap');
      return;
    }
    G.en[id] = 0;
    sfx('power');
    sfx('win');
    flash = .25;
    final ty0 = H * (.4 + .07 * kSkills.indexWhere((s) => s.$1 == id));
    if (id == 'shield') {
      eshield = 8;
      F.text(W / 2, ty0, 'KHIÊN NĂNG LƯỢNG!', 0x74c0fc);
    } else if (id == 'meteor') {
      for (var k = 0; k < 18; k++) {
        meteors.add(_Obj(rnd(W * .05, W * 1.1), -60.0 - k * 45, -120, rnd(650, 800), S * .09, S * .09));
      }
      F.text(W / 2, ty0, 'MƯA SAO BĂNG!', 0xffd43b);
    } else {
      giant = 8;
      F.text(W / 2, ty0, 'PHI THUYỀN KHỔNG LỒ!', 0xff6b6b);
    }
    save();
  }

  void nextGun() {
    final o = owned();
    if (o.length < 2 || end != null) return;
    gun = G.gun = o[(o.indexOf(gun) + 1) % o.length];
    fire = .05;
    sfx('tap');
    F.text(mx, my - 60, kGuns[gun]!.vi, kGuns[gun]!.c);
    save();
  }

  void add(_Shot s) {
    if (shots.length < 160) shots.add(s);
  }

  void zap(double x, double y, int n, double dmg) {
    final pts = <Offset>[Offset(x, y)];
    final seen = <Object>{};
    var px = x, py = y, range = math.max(W, H);
    for (var k = 0; k < n; k++) {
      Object? best;
      var bd = range;
      double bx = 0, by = 0;
      for (final f in foes) {
        if (f.dead || seen.contains(f) || (k == 0 && f.y > y)) continue;
        final dd = hypot(f.x - px, f.y - py);
        if (dd < bd) {
          bd = dd;
          best = f;
          bx = f.x;
          by = f.y;
        }
      }
      final b = boss;
      if (best == null && b != null && !seen.contains(b) && (k == 0 || hypot(b.x - px, b.y - py) < range * 1.3)) {
        best = b;
        bx = b.x;
        by = b.y;
      }
      if (best == null) break;
      seen.add(best);
      pts.add(Offset(bx, by));
      px = bx;
      py = by;
      range = S * .38;
      if (best == boss) {
        bossHit(dmg, bx, by);
        break;
      }
      hitFoe(best as _Foe, dmg, bx, by);
    }
    if (pts.length < 2) pts.add(Offset(x + rnd(-30, 30), y - S * .3));
    final ln = [pts[0]];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      for (var j = 1; j <= 3; j++) {
        ln.add(Offset(a.dx + (b.dx - a.dx) * j / 4 + rnd(-12, 12), a.dy + (b.dy - a.dy) * j / 4 + rnd(-12, 12)));
      }
      ln.add(b);
    }
    if (zaps.length < 12) zaps.add((ln, .16));
  }

  void shoot(double x, double y, [bool small = false]) {
    final g = small ? 'laser' : gun, sv = small ? 1 : cur[gun]!;
    switch (g) {
      case 'laser':
        const dxs = [
          [0.0], [-10.0, 10.0], [-16.0, 0.0, 16.0], [-24.0, -8.0, 8.0, 24.0], [-30.0, -15.0, 0.0, 15.0, 30.0]
        ];
        for (final dx in dxs[sv - 1]) {
          add(_Shot(x + dx, y, 0, -820, 10, 26, 1, 'laser'));
        }
      case 'spread':
        final n = const [3, 5, 7, 9, 11][sv - 1];
        for (var i = 0; i < n; i++) {
          final a = (i - (n - 1) / 2) * .15;
          add(_Shot(x, y, math.sin(a) * 700, -math.cos(a) * 700, 14, 14, 1, 'spread'));
        }
      case 'plasma':
        const dxs = [
          [0.0], [-14.0, 14.0], [-22.0, 0.0, 22.0], [-22.0, 0.0, 22.0], [-30.0, -10.0, 10.0, 30.0]
        ];
        for (final dx in dxs[sv - 1]) {
          add(_Shot(x + dx, y, 0, -520, 30.0 + sv * 4, 30.0 + sv * 4, sv >= 4 ? 3 : 2, 'plasma', pierce: 3 + sv));
        }
      case 'missile':
        add(_Shot(x, y, 0, -820, 10, 26, 1, 'laser'));
        final n = sv + 1;
        for (var i = 0; i < n; i++) {
          add(_Shot(x + (i - (n - 1) / 2) * 20, y + 10, (i - (n - 1) / 2) * 120, -380, 22, 22, 2, 'missile', seek: true));
        }
      case 'thunder':
        zap(x, y, 1 + sv, sv >= 4 ? 2 : 1);
      case 'ice':
        final n = const [1, 2, 3, 3, 4][sv - 1];
        for (var i = 0; i < n; i++) {
          final a = (i - (n - 1) / 2) * .12;
          add(_Shot(x, y, math.sin(a) * 640, -math.cos(a) * 640, 26, 26, 1, 'ice', slow: true, pierce: sv >= 4 ? 2 : 0));
        }
      case 'vortex':
        final n = const [1, 2, 2, 3, 3][sv - 1];
        for (var i = 0; i < n; i++) {
          add(_Shot(x, y, (i - (n - 1) / 2) * 170, -780, 40.0 + sv * 5, 40.0 + sv * 5, sv >= 4 ? 2 : 1.5, 'vortex', pierce: 99, ay: 780 * 780 / (2 * H * .75)));
        }
    }
    if (!small && giant > 0) {
      for (final dd in [-1.0, 1.0]) {
        add(_Shot(x + dd * mw * .8, y + mh * .3, dd * 60, -820, 12, 30, 1, 'laser'));
      }
    }
  }

  static const Map<String, List<double>> _rate = {
    'laser': [.18, .16, .14, .13, .12], 'spread': [.28, .26, .24, .22, .2], 'plasma': [.42, .38, .34, .31, .28], 'missile': [.5, .45, .4, .37, .34],
    'thunder': [.42, .38, .34, .31, .28], 'beam': [.1, .1, .1, .1, .1], 'ice': [.26, .24, .22, .2, .18], 'vortex': [.55, .5, .46, .42, .38],
  };
  double rate() => _rate[gun]![cur[gun]! - 1] * (gun == 'beam' ? 1 : rateK) * (giant > 0 ? .6 : 1);
  double beamW() => S * (.03 + .012 * (cur['beam'] ?? 1)) * (giant > 0 ? 1.6 : 1);

  void beamTick() {
    final sv = cur['beam']!, bw = beamW(), dmg = (.4 + .08 * sv) / rateK;
    for (final f in foes) {
      if (!f.dead && f.y < my && (f.x - mx).abs() < bw / 2 + f.w * .4) hitFoe(f, dmg, f.x, f.y + f.h * .3);
    }
    final b = boss;
    if (b != null && b.y < my && (b.x - mx).abs() < bw / 2 + b.w * .35) bossHit(dmg, mx, b.y + b.h * .3);
  }

  static const _look = {'Alien monster': 'enemyGreen1', 'Ghost': 'enemyBlue2', 'Bat': 'enemyRed4', 'Flying saucer': 'ufoRed', 'Octopus': 'enemyBlack5', 'Comet': 'meteorBrown_big1'};
  // Kiểu quái: máu, điểm, tốc độ
  static const Map<String, (double, int, double)> _enemies = {
    'Alien monster': (1, 2, 90), 'Ghost': (1, 2, 70), 'Bat': (1, 3, 150), 'Flying saucer': (3, 4, 70), 'Octopus': (6, 6, 50), 'Comet': (2, 2, 220),
  };
  double hpOf(double b) => math.max(b, (b * power()).roundToDouble());

  _Foe _mk(String k, double hp, double x, double y, double w, double vy, {double vx = 0, double ph = 0, double cd = 9}) {
    final e = _enemies[k]!;
    return _Foe(k, hp, e.$2, x, y, w, w, vy, vx: vx, ph: ph, cd: cd, wave: k == 'Ghost' ? 40 : 0, swoop: k == 'Bat', gun: k == 'Flying saucer', big: k == 'Octopus');
  }

  void spawnFoe() {
    final tt = t + ramp(lv, 0, 30);
    final pool = tt < 15 ? const ['Alien monster', 'Ghost', 'Bat'] : (tt < 35 ? const ['Alien monster', 'Ghost', 'Bat', 'Flying saucer', 'Comet'] : _enemies.keys.toList());
    final k = pickOf(pool), e = _enemies[k]!, sz = S * rnd(.1, .12) * (k == 'Octopus' ? 1.4 : 1);
    if (rnd01() < .25 && t > 8) {
      final cxx = rnd(W * .25, W * .75);
      for (var i = -2; i <= 2; i++) {
        foes.add(_mk('Alien monster', hpOf(1), cxx + i * sz * .9, -sz - i.abs() * sz * .6, sz * .85, 110));
      }
      return;
    }
    foes.add(_mk(k, hpOf(e.$1 + hpUp), rnd(sz, W - sz), -sz, sz, (e.$3 + t * .8) * ramp(lv, 1, 1.5), vx: k == 'Comet' ? rnd(-80, 80) : 0, ph: rnd(0, 6), cd: rnd(1, 3)));
  }

  _Boss makeBoss(bool fin) {
    final hp = ((fin ? ramp(lv, 70, 190) : ramp(lv, 28, 80)) * power()).roundToDouble();
    return _Boss(fin ? 'Flying saucer' : 'Alien', fin, W / 2, -S * .3, S * (fin ? .4 : .3), S * (fin ? .4 : .3), hp);
  }

  void hurt() {
    if (inv > 0 || eshield > 0 || giant > 0) return;
    if (shield > 0) {
      shield = 0;
      inv = 1;
      armorT = armorCd;
      sfx('pop');
      return;
    }
    lives--;
    inv = 1.8;
    sfx('hit');
    SH.add(10);
    flash = .15;
    B.add(mx, my, mw * 1.2);
    D.sparks(mx, my, 16, 0xff8787, 300);
    if (cur[gun]! > 1) {
      cur[gun] = cur[gun]! - 1;
      F.text(mx, my - 50, 'Súng yếu đi', 0xced4da);
    }
    if (lives <= 0) finish(false);
  }

  @override
  Object? step(double dt) {
    t += dt;
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      var y = s.$2 + s.$4 * dt * (boss != null ? .5 : 1), x = s.$1;
      if (y > H) {
        y = 0;
        x = rnd(0, W);
      }
      stars[i] = (x, y, s.$3, s.$4);
    }
    flash = math.max(0, flash - dt);
    SH.update(dt);
    D.update(dt);
    B.update(dt);
    scrollY += dt * (boss != null ? 20 : 45);
    for (var i = zaps.length - 1; i >= 0; i--) {
      final l = zaps[i].$2 - dt;
      if (l <= 0) {
        zaps.removeAt(i);
      } else {
        zaps[i] = (zaps[i].$1, l);
      }
    }
    final e = end;
    if (e != null) {
      endT += dt;
      F.update(dt);
      return endT > 2.2 ? ShootEnd(e.win, score, e.bonus, G.toJson()) : null;
    }
    final px = mx;
    mx = approach(mx, tx, 9, dt);
    my = approach(my, ty, 9, dt);
    mvx = (mx - px) / math.max(dt, .001);
    bank = approach(bank, clamp(mvx / 700, -1, 1), 10, dt);
    if (rnd01() < .7) D.emit(mx + rnd(-4, 4), my + mh * .5, rnd(-20, 20), rnd(160, 260), life: .25, r: 3, grow: 4, c: rnd01() < .5 ? hex(0xffa94d) : hex(0xffe066), a: .9);
    inv = math.max(0, inv - dt);
    shield = math.max(0, shield - dt);
    magnet = math.max(0, magnet - dt);
    eshield = math.max(0, eshield - dt);
    giant = math.max(0, giant - dt);
    gs = approach(gs, giant > 0 ? 1.8 : 1, 6, dt);
    if (armorCd > 0 && shield <= 0) {
      armorT -= dt;
      if (armorT <= 0) {
        armorT = armorCd;
        shield = 8;
        F.text(mx, my - 50, 'KHIÊN!', 0x74c0fc);
      }
    }
    final bw0 = mw * gs, bh0 = mh * gs;
    fire -= dt;
    if (fire <= 0) {
      fire = rate();
      if (gun == 'beam') {
        beamTick();
        if ((beamSnd -= fire) <= 0) {
          beamSnd = .3;
          sfx('laser');
        }
        if (giant > 0) shoot(mx, my - mh / 2);
      } else {
        sfx(gun == 'plasma' || gun == 'vortex' ? 'shoot' : 'laser');
        shoot(mx, my - mh * gs / 2);
      }
    }
    droneFire -= dt;
    if (G.drones > 0 && droneFire <= 0) {
      droneFire = .35;
      for (var k = 0; k < G.drones; k++) {
        shoot(mx + (k > 0 ? 1 : -1) * mw * .9 * gs, my, true);
      }
    }
    final b = boss;
    if (b == null) {
      spawn -= dt;
      if (spawn <= 0 && t < 60 && !(t > 28 && !midDone)) {
        spawn = math.max(.3, 1.1 - t / 90) * ramp(lv, 1, .65);
        spawnFoe();
      }
      if (t > 28 && !midDone && foes.isEmpty) {
        boss = makeBoss(false);
        sfx('power');
        F.text(W / 2, H * .3, 'QUÁI TO XUẤT HIỆN!', 0xff6b6b);
      }
      if (t >= 60 && midDone && foes.isEmpty) {
        boss = makeBoss(true);
        sfx('power');
        F.text(W / 2, H * .3, 'TRÙM CUỐI!', 0xff6b6b);
      }
    } else {
      b.ph += dt;
      b.flash = math.max(0, b.flash - dt);
      b.y += (H * .2 - b.y) * math.min(1, dt * 1.5);
      b.x = W / 2 + math.sin(b.ph * .9) * (W * .32);
      b.cd -= dt;
      final rage = b.fin && b.hp < b.max / 2;
      if (b.cd <= 0) {
        final bcd = ramp(lv, 1, .65);
        if (!b.fin) {
          b.cd = 1.4 * bcd;
          for (final a in [-.5, -.25, 0.0, .25, .5]) {
            orbs.add(_Obj(b.x, b.y + b.h * .3, math.sin(a) * 170, math.cos(a) * 170, 22, 22));
          }
        } else if (!rage) {
          b.cd = 1.2 * bcd;
          for (final a in [-.45, 0.0, .45]) {
            orbs.add(_Obj(b.x, b.y + b.h * .3, math.sin(a) * 190, math.cos(a) * 190, 24, 24));
          }
        } else {
          b.cd = .9 * bcd;
          for (var k = 0; k < 8; k++) {
            final a = b.ph * 2 + k * math.pi / 4;
            orbs.add(_Obj(b.x, b.y, math.cos(a) * 150, math.sin(a).abs() * 150 + 40, 20, 20));
          }
          if (foes.length < 4 && rnd01() < .3) {
            final sz = S * .09;
            foes.add(_mk('Bat', hpOf(1), b.x, b.y, sz, 160));
          }
        }
      }
    }
    // Đạn của bé
    for (var i = shots.length - 1; i >= 0; i--) {
      final s = shots[i];
      if (s.seek) {
        double? gx, gy;
        final bb = boss;
        if (bb != null) {
          gx = bb.x;
          gy = bb.y;
        } else {
          var bd = 1e9;
          for (final f in foes) {
            if (f.dead) continue;
            final dd = hypot(f.x - s.x, f.y - s.y);
            if (dd < bd) {
              bd = dd;
              gx = f.x;
              gy = f.y;
            }
          }
        }
        if (gx != null) {
          final a = math.atan2(gy! - s.y, gx - s.x);
          s.vx += (math.cos(a) * 620 - s.vx) * math.min(1, dt * 5);
          s.vy += (math.sin(a) * 620 - s.vy) * math.min(1, dt * 5);
        }
        if (rnd01() < .6) D.emit(s.x, s.y, rnd(-15, 15), rnd(-15, 15), life: .4, r: 3, grow: 8, c: const Color(0xFFE6E6E6), a: .5);
      }
      if (s.ay != 0) {
        s.vy += s.ay * dt;
        if (!s.back && s.vy > 0) {
          s.back = true;
          s.hitSet = null;
          s.hitB = false;
        }
      }
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y < -50 || s.y > H + 50 || s.x < -50 || s.x > W + 50) {
        shots.removeAt(i);
        continue;
      }
      var used = false;
      for (var j = foes.length - 1; j >= 0 && !used; j--) {
        final f = foes[j];
        if (f.dead || !hitBox(s.x, s.y, s.w, s.h, f.x, f.y, f.w, f.h, .9) || (s.hitSet?.contains(f) ?? false)) continue;
        if (s.pierce > 0) {
          (s.hitSet ??= {}).add(f);
          if (--s.pierce <= 0) used = true;
        } else {
          used = true;
        }
        if (s.slow) f.slow = 2.5;
        hitFoe(f, s.dmg, s.x, s.y);
      }
      final bb = boss;
      if (!used && bb != null && !s.hitB && hitBox(s.x, s.y, s.w, s.h, bb.x, bb.y, bb.w, bb.h, .8)) {
        if (s.k == 'vortex') {
          s.hitB = true;
        } else {
          used = true;
        }
        bossHit(s.dmg, s.x, s.y);
      }
      if (used) shots.removeAt(i);
    }
    for (var i = meteors.length - 1; i >= 0; i--) {
      final m = meteors[i];
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      if (m.y > H + 80) {
        meteors.removeAt(i);
        continue;
      }
      if (m.y < -40) continue;
      if (rnd01() < .5) D.emit(m.x, m.y - 20, rnd(-20, 20), rnd(-60, -20), life: .35, r: 4, grow: 8, c: hex(0xffa94d), a: .8);
      for (final f in foes) {
        if (!f.dead && hitBox(m.x, m.y, m.w, m.h, f.x, f.y, f.w, f.h, .9)) {
          hitFoe(f, 4, f.x, f.y);
          B.add(f.x, f.y, f.w);
        }
      }
      final bb = boss;
      if (bb != null && !m.hitB && hitBox(m.x, m.y, m.w, m.h, bb.x, bb.y, bb.w, bb.h, .7)) {
        m.hitB = true;
        B.add(m.x, m.y, 90);
        bossHit(math.max(1, bb.max * .015), m.x, m.y);
      }
    }
    for (var i = foes.length - 1; i >= 0; i--) {
      final f = foes[i];
      if (f.dead) {
        foes.removeAt(i);
        continue;
      }
      f.ph += dt;
      f.flash = math.max(0, f.flash - dt);
      f.slow = math.max(0, f.slow - dt);
      final k = f.slow > 0 ? .4 : 1.0;
      f.y += f.vy * dt * k;
      f.x += f.vx * dt * k;
      if (f.wave != 0) f.x += math.sin(f.ph * 2) * f.wave * dt * 3 * k;
      if (f.swoop) f.x += sgn(mx - f.x) * 60 * dt * k;
      if (f.gun) {
        f.cd -= dt * k;
        if (f.cd <= 0) {
          f.cd = rnd(2, 3.2);
          final a = math.atan2(my - f.y, mx - f.x);
          orbs.add(_Obj(f.x, f.y + f.h / 3, math.cos(a) * 170, math.sin(a) * 170, 20, 20));
        }
      }
      if (f.y > H + 60 || f.x < -80 || f.x > W + 80) {
        foes.removeAt(i);
        continue;
      }
      if (hitBox(mx, my, bw0, bh0, f.x, f.y, f.w, f.h, .55)) {
        if (giant > 0) {
          f.dead = true;
          kill(f);
          foes.removeAt(i);
          continue;
        }
        hurt();
        foes.removeAt(i);
        B.add(f.x, f.y, f.w * 1.3);
      }
    }
    for (var i = orbs.length - 1; i >= 0; i--) {
      final o = orbs[i];
      o.x += o.vx * dt;
      o.y += o.vy * dt;
      if (o.y > H + 30 || o.y < -40 || o.x < -30 || o.x > W + 30) {
        orbs.removeAt(i);
        continue;
      }
      if (eshield > 0 && hypot(o.x - mx, o.y - my) < mh * gs * .9) {
        D.sparks(o.x, o.y, 6, 0x74c0fc, 200);
        orbs.removeAt(i);
        continue;
      }
      if (hitBox(mx, my, bw0, bh0, o.x, o.y, o.w, o.h, .5)) {
        hurt();
        orbs.removeAt(i);
      }
    }
    for (var i = coins.length - 1; i >= 0; i--) {
      final c = coins[i];
      c.vy += 260 * dt;
      if (magnet > 0 || hypot(mx - c.x, my - c.y) < magR * gs) {
        c.x += (mx - c.x) * math.min(1, dt * 8);
        c.y += (my - c.y) * math.min(1, dt * 8);
      } else {
        c.y += math.min(c.vy, 160) * dt;
      }
      if (c.y > H + 30) {
        coins.removeAt(i);
        continue;
      }
      if (hitBox(mx, my, bw0, bh0, c.x, c.y, c.w, c.h, .9)) {
        score++;
        got++;
        G.coins++;
        sfx('coin');
        coins.removeAt(i);
        D.sparks(c.x, c.y, 5, 0xffe066, 140);
        if (G.coins - lastSave >= 20) save();
      }
    }
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.y += 110 * dt;
      if (it.y > H + 40) {
        items.removeAt(i);
        continue;
      }
      if (!hitBox(mx, my, bw0, bh0, it.x, it.y, it.w, it.h, .9)) continue;
      sfx('power');
      items.removeAt(i);
      D.sparks(it.x, it.y, 14, 0x74c0fc, 260);
      pop = .3;
      switch (it.k) {
        case 'gun':
          final g = it.gun!, Gn = kGuns[g]!;
          if (!own.containsKey(g)) {
            own[g] = cur[g] = 1;
            gun = G.gun = g;
            F.text(it.x, it.y - 20, 'SÚNG MỚI: ${Gn.vi}!', Gn.c);
            sfx('win');
          } else if ((cur[g] ?? own[g]!) >= kMaxStars) {
            final b = 15 + lv ~/ 4;
            G.coins += b;
            got += b;
            score += b;
            gun = G.gun = g;
            cur[g] ??= own[g]!;
            F.text(it.x, it.y - 20, 'MAX! +$b XU', 0xffd43b);
            sfx('coin');
            D.sparks(it.x, it.y, 20, 0xffd43b, 320);
          } else {
            cur[g] = (cur[g] ?? own[g]!) + 1;
            own[g] = math.max(own[g]!, cur[g]!);
            gun = G.gun = g;
            F.text(it.x, it.y - 20, '${Gn.vi} ${'★' * cur[g]!}', Gn.c);
          }
        case 'Shield':
          shield = 10;
          F.text(it.x, it.y - 20, 'KHIÊN!', 0x74c0fc);
        case 'Bomb':
          if (G.bombs < kMaxBombs) {
            G.bombs++;
            F.text(it.x, it.y - 20, '+1 BOM', 0xff922b);
          } else {
            G.coins += 5;
            got += 5;
            F.text(it.x, it.y - 20, '+5 XU', 0xffd43b);
          }
        case 'Satellite':
          if (G.drones < kMaxDrones) {
            G.drones++;
            F.text(it.x, it.y - 20, 'MÁY BAY PHỤ!', 0x4dabf7);
          } else {
            G.coins += 5;
            got += 5;
            F.text(it.x, it.y - 20, '+5 XU', 0xffd43b);
          }
        case 'Magnet':
          magnet = 10;
          F.text(it.x, it.y - 20, 'NAM CHÂM!', 0xff6b6b);
        default:
          lives = math.min(maxLives, lives + 1);
          F.text(it.x, it.y - 20, '+❤', 0xff6b6b);
      }
      save();
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    c.save();
    SH.apply(c);
    if (sp != null) {
      gfx.tile(c, sp, bgK, 256, 0, -scrollY, -20, -20, W + 40, H + 40);
    } else {
      c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [hex(space.$1), hex(space.$2)]).createShader(Rect.fromLTWH(0, 0, W, H)));
    }
    final b = boss;
    if (b != null && b.fin) rect(c, -20, -20, W + 40, H + 40, rgba(80, 0, 60, .25));
    for (final s in stars) {
      rect(c, s.$1, s.$2, s.$3, s.$3 * (1 + s.$4 / 80), Colors.white.withValues(alpha: s.$3 / 3));
    }
    gfx.draw(c, 'Ringed planet', W * .85, (t * 8) % (H + 200) - 100, S * .2, S * .2, false, 0, .9);
    gfx.draw(c, 'Crescent moon', W * .12, ((t * 5) + H * .5) % (H + 200) - 100, S * .14, S * .14, false, 0, .8);
    D.draw(c);
    if (gun == 'beam' && end == null) {
      final bw = beamW(), top = my - mh * gs * .45, fl = .85 + math.sin(t * 40) * .15;
      final col = hex(kGuns['beam']!.c);
      rect(c, mx - bw * .9, 0, bw * 1.8, top, col.withValues(alpha: .3 * fl));
      rect(c, mx - bw / 2, 0, bw, top, col.withValues(alpha: .75 * fl));
      rect(c, mx - bw * .16, 0, bw * .32, top, Colors.white);
      circle(c, mx, top, bw * .7, Colors.white);
    }
    for (final s in shots) {
      switch (s.k) {
        case 'laser':
          if (!gfx.spr(c, sp, 'laserBlue01', s.x, s.y, 34)) rect(c, s.x - 3, s.y - 13, 6, 26, hex(0x4dabf7));
        case 'spread':
          gfx.spr(c, sp, 'laserGreen14', s.x, s.y, 20, rot: t * 12);
        case 'plasma':
          circle(c, s.x, s.y, s.w / 2, rgba(218, 119, 242, .45));
          circle(c, s.x, s.y, s.w * .32, hex(0xe599f7));
          circle(c, s.x, s.y, s.w * .15, Colors.white);
        case 'ice':
          gfx.draw(c, 'Snowflake', s.x, s.y, s.w * 1.1, s.w * 1.1, false, t * 6);
        case 'vortex':
          gfx.draw(c, 'Tornado', s.x, s.y, s.w, s.w, false, t * 14);
        default:
          gfx.spr(c, sp, 'missile', s.x, s.y, 30, rot: math.atan2(s.vy, s.vx) + math.pi / 2);
      }
    }
    for (final z in zaps) {
      final a = math.min(1.0, z.$2 * 8);
      final path = Path()..addPolygon(z.$1, false);
      c.drawPath(path, strokeP(hex(0x4dabf7, a), 9, cap: StrokeCap.round, join: StrokeJoin.round));
      c.drawPath(path, strokeP(Colors.white.withValues(alpha: a), 3, cap: StrokeCap.round, join: StrokeJoin.round));
    }
    for (final m in meteors) {
      if (m.y > -60) {
        gfx.spr(c, sp, 'meteorBrown_med1', m.x, m.y, m.h, rot: t * 5);
        gfx.anim(c, sp, 'fireB', t + m.x, m.x + 10, m.y - m.h * .6, m.h * .7, rot: math.pi - .15);
      }
    }
    for (final o in orbs) {
      if (!gfx.spr(c, sp, 'laserRed08', o.x, o.y, o.w * 1.4, rot: t * 8)) circle(c, o.x, o.y, o.w / 2, hex(0xfa5252));
    }
    for (final f in foes) {
      final k = _look[f.k] ?? 'enemyGreen1';
      final rot = f.k == 'Comet' ? f.ph * 2 : (f.k == 'Flying saucer' ? 0.0 : clamp(-f.vx / 300 + (f.wave != 0 ? math.cos(f.ph * 2) * .25 : 0) + (f.swoop ? sgn(mx - f.x) * -.25 : 0), -.5, .5));
      final al = f.flash > 0 ? .5 : 1.0;
      if (f.k == 'Flying saucer') {
        gfx.spr(c, sp, k, f.x, f.y, f.h * (1 + math.sin(f.ph * 6) * .04), rot: f.ph * 3, alpha: al);
      } else if (!gfx.spr(c, sp, k, f.x, f.y, f.h * .9, rot: rot, alpha: al)) {
        gfx.draw(c, f.k, f.x, f.y, f.w, f.h, false, 0, al);
      }
      if (f.k != 'Comet' && f.k != 'Flying saucer') gfx.anim(c, sp, 'fireB', t + f.ph, f.x, f.y - f.h * .55, f.h * .3, rot: math.pi, alpha: .8);
      if (f.slow > 0) gfx.draw(c, 'Snowflake', f.x + f.w * .35, f.y - f.h * .35, 22);
    }
    for (final co in coins) {
      gfx.coin(c, fxs, t + co.x * .01, co.x, co.y, co.w);
    }
    for (final it in items) {
      final bob = math.sin(t * 4 + it.x) * 4;
      if (it.k == 'gun') {
        gunIcon(c, gfx, sp, it.gun!, it.x, it.y + bob, 26 + math.sin(t * 8) * 2);
        if (!own.containsKey(it.gun)) Txt.draw(c, 'MỚI', it.x, it.y + bob - 32, size: 16);
      } else if (it.k == 'Shield') {
        gfx.spr(c, sp, 'powerupBlue_shield', it.x, it.y + bob, 40, rot: math.sin(t * 4) * .2);
      } else if (it.k == 'Satellite') {
        gfx.spr(c, sp, 'playerShip3_green', it.x, it.y + bob, 38, rot: math.sin(t * 4) * .2);
      } else {
        gfx.draw(c, it.k, it.x, it.y + bob, it.w, it.w, false, math.sin(t * 4) * .2);
      }
    }
    if (b != null) {
      final bk = b.fin ? 'boss2' : 'boss1', rage = b.fin && b.hp < b.max / 2;
      gfx.anim(c, sp, 'fireB', t, b.x - b.w * .2, b.y - b.h * .5, b.h * .35, rot: math.pi);
      gfx.anim(c, sp, 'fireB', t + .1, b.x + b.w * .2, b.y - b.h * .5, b.h * .35, rot: math.pi);
      if (!gfx.spr(c, sp, bk, b.x + (rage ? math.sin(t * 40) * 3 : 0), b.y, b.h * .8, rot: math.sin(b.ph * 3) * .08 + math.cos(b.ph * .9) * -.15, alpha: b.flash > 0 ? .6 : 1)) {
        gfx.draw(c, b.k, b.x, b.y, b.w, b.h);
      }
    }
    final e = end;
    if (e == null || e.win) {
      final blink = inv > 0 && (inv * 10).floor() % 2 == 0;
      if (!blink) {
        gfx.anim(c, sp, 'fire', t, mx - mw * .18 * gs, my + mh * .45 * gs, mh * .4 * gs * (1 + rnd01() * .2), rot: math.pi);
        gfx.anim(c, sp, 'fire', t + .05, mx + mw * .18 * gs, my + mh * .45 * gs, mh * .4 * gs * (1 + rnd01() * .2), rot: math.pi);
        c.save();
        c.translate(mx, my);
        c.rotate(bank * .25);
        c.scale(1 - bank.abs() * .25, 1);
        if (!gfx.spr(c, sp, giant > 0 ? 'playerShip1_red' : 'playerShip1_blue', 0, 0, mh * .8 * gs)) gfx.draw(c, 'Rocket', 0, 0, mw * gs, mh * gs, false, -math.pi / 4);
        c.restore();
        for (var k = 0; k < G.drones; k++) {
          gfx.spr(c, sp, 'playerShip3_green', mx + (k > 0 ? 1 : -1) * mw * .9 * gs, my + math.sin(t * 5 + k) * 6, mw * .4, rot: bank * .3);
        }
      }
      if (shield > 0) gfx.spr(c, sp, 'shield3', mx, my - mh * .1, mh * 1.4 * gs, alpha: .6 + .3 * math.sin(t * 8));
      if (eshield > 0) {
        gfx.spr(c, sp, 'shield3', mx, my - mh * .1, mh * 1.9 * gs, alpha: .5 + .3 * math.sin(t * 12));
        gfx.spr(c, sp, 'shield1', mx, my - mh * .1, mh * 1.6 * gs, alpha: .4);
      }
      if (magnet > 0) gfx.draw(c, 'Magnet', mx - mw * .7, my - mh * .5, 26);
    }
    B.draw(c);
    F.draw(c);
    c.restore();
    if (flash > 0) rect(c, 0, 0, W, H, rgba(255, 255, 255, flash));
    hud(c, gfx, W, score: score, time: b != null ? null : math.max(0, (midDone ? 60 : 28) - t), bossHp: b?.hp, bossMax: b?.max);
    final hs = narrow ? 22.0 : 30.0, hg = narrow ? 25.0 : 36.0;
    for (var i = 0; i < maxLives; i++) {
      final row = narrow && i >= 5 ? 1 : 0, j = row == 1 ? i - 5 : i;
      gfx.draw(c, 'Red heart', W - (narrow ? 30 : 40) - j * hg, 32.0 + row * 28, hs, hs, false, 0, i < lives ? 1 : .22);
    }
    final o = owned(), bw = barW(), stp = stepW();
    fillRR(c, gunBarX, gunBarY, bw, gunBarH, 22, rgba(0, 0, 0, .35));
    for (var i = 0; i < o.length; i++) {
      final on = o[i] == gun;
      gunIcon(c, gfx, sp, o[i], gunBarX + 24 + i * stp, gunBarY + gunBarH / 2, on ? 19 : 14, on ? 1 : .6);
    }
    final ci = o.indexOf(gun), n = cur[gun]!;
    final st = '★' * n + '☆' * (kMaxStars - n), sx = clamp(gunBarX + 24 + ci * stp - 30, gunBarX + 4, W - 110);
    Txt.draw(c, st, sx, gunBarY + gunBarH + 18, size: 18, align: TA.left, color: hex(kGuns[gun]!.c), stroke: rgba(0, 0, 0, .5));
    if (o.length > 1 && t < 6) Txt.draw(c, '👆 đổi súng', math.min(W - 100, gunBarX + bw + 8), gunBarY + 28, size: 16, align: TA.left);
    circle(c, bombBtn.dx, bombBtn.dy, btnR, G.bombs > 0 ? rgba(255, 146, 43, .9) : rgba(255, 255, 255, .35));
    strokeCircle(c, bombBtn.dx, bombBtn.dy, btnR, Colors.white, 4);
    gfx.draw(c, 'Bomb', bombBtn.dx, bombBtn.dy - 4, btnR * 1.1, btnR * 1.1, false, 0, G.bombs > 0 ? 1 : .4);
    Txt.draw(c, '×${G.bombs}', bombBtn.dx + btnR * .6, bombBtn.dy + btnR * .8, size: 22);
    for (var i = 0; i < kSkills.length; i++) {
      final s = kSkills[i], p = skBtn[i];
      final en = G.en[s.$1]!, full = en >= 1, act = (s.$1 == 'shield' && eshield > 0) || (s.$1 == 'giant' && giant > 0);
      final r = skR * (full ? 1 + math.sin(t * 6) * .06 : 1);
      circle(c, p.dx, p.dy, r, full ? hex(s.$3) : rgba(0, 0, 0, .4));
      strokeCircle(c, p.dx, p.dy, r - 3, rgba(255, 255, 255, .3), 6);
      c.drawArc(Rect.fromCircle(center: p, radius: r - 3), -math.pi / 2, math.pi * 2 * (act ? 1 : en), false, strokeP(full ? Colors.white : hex(s.$3), 6));
      gfx.draw(c, s.$2, p.dx, p.dy, r * 1.15, r * 1.15, false, 0, full || act ? 1 : .45);
    }
    if (t < 2.8) levelBanner(c, W, H, lv, 'Hạ trùm cuối', 'Kéo để lái · Nhặt quả cầu súng lên sao · Nút sáng là chiêu mạnh');
    if (e != null) banner(c, W, H, e.win ? funEndText(true, lv) : 'HẾT LƯỢT!', '$score điểm · +${got + e.bonus} xu');
  }
}

