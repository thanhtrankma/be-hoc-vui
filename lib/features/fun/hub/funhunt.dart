// Săn quái vật (port web js/games/funhunt.js): kiểu "survivor" nhìn từ trên xuống. Kéo ngón tay để chạy
// (cần điều khiển ảo hiện ở chỗ chạm), bé TỰ BẮN quái gần nhất. Quái đến theo đợt, hết giờ thì trùm ra. Quái chết rơi ngọc;
// đầy thanh ngọc → dừng game, chọn 1 trong 3 thẻ skill (12 skill × 5 cấp).
// Mọi skill + cấp skill lưu vào carry (ctx.saveGear / FunResult.carry), mang sang cấp sau/lượt sau (trần tổng cấp kHuntCap).
// Xu tích vào carry.coins, mua nâng cấp vĩnh viễn ở "Kho vũ khí" (chỉ hiện ở cấp đầu của lượt); ở đó bé bật/tắt skill.
// CHỦ: agent E.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/ui/ui.dart' hide lerp, approach;
import 'package:be_vui_hoc/features/learn/creative/figure.dart' show drawFigure, heroOf, petBuddy, PetBuddy, Costume;

import 'funcore.dart';
import 'funfx.dart';

/// id game → module.
final Map<String, FunGameModule> funhuntGames = {'hunt': const HuntModule()};

/// Một skill (atk = vũ khí đánh quái; phải còn ít nhất 1 vũ khí bật).
class HuntSkill {
  const HuntSkill(this.img, this.vi, this.en, this.c, {this.atk = false});
  final String img, vi, en;
  final Color c;
  final bool atk;
}

const Map<String, HuntSkill> kHuntSkills = {
  'gun': HuntSkill('Water pistol', 'Súng nước', 'Water gun', Color(0xFF4DABF7), atk: true),
  'knife': HuntSkill('Dagger', 'Dao bay', 'Flying knives', Color(0xFFADB5BD), atk: true),
  'bolt': HuntSkill('High voltage', 'Tia sét', 'Lightning', Color(0xFFFCC419), atk: true),
  'fire': HuntSkill('Fire', 'Cầu lửa', 'Fireball', Color(0xFFFF922B), atk: true),
  'frost': HuntSkill('Snowflake', 'Vòng băng', 'Frost ring', Color(0xFF74C0FC), atk: true),
  'boom': HuntSkill('Boomerang', 'Bumerang', 'Boomerang', Color(0xFFE8590C), atk: true),
  'meteor': HuntSkill('Comet', 'Sao băng', 'Meteor', Color(0xFFF06595), atk: true),
  'pet': HuntSkill('Dog face', 'Cún đánh hộ', 'Helper pup', Color(0xFFB7793F), atk: true),
  'magnet': HuntSkill('Magnet', 'Nam châm', 'Magnet', Color(0xFFFA5252)),
  'shoes': HuntSkill('Running shoe', 'Giày nhanh', 'Fast shoes', Color(0xFF20C997)),
  'heart': HuntSkill('Red heart', 'Thêm tim', 'Extra heart', Color(0xFFFF6B6B)),
  'armor': HuntSkill('Shield', 'Khiên', 'Shield', Color(0xFF748FFC)),
};
final List<String> _sk = kHuntSkills.keys.toList();
const int kHuntSkillMax = 5;

/// 12 skill × 5 = 60 cấp, trần tổng 45: phải chọn món mình thích.
const int kHuntCap = 45;

/// Nâng cấp vĩnh viễn mua bằng xu ở Kho vũ khí.
const Map<String, HuntSkill> kHuntPerm = {
  'hp': HuntSkill('Red heart', 'Máu', 'Health', Color(0xFFFF6B6B)),
  'speed': HuntSkill('Running shoe', 'Chạy', 'Speed', Color(0xFF20C997)),
  'power': HuntSkill('Flexed biceps', 'Sức mạnh', 'Power', Color(0xFFF08C00)),
  'gem': HuntSkill('Gem stone', 'Ngọc', 'Gems', Color(0xFFCC5DE8)),
};
const int kHuntPermMax = 5;

/// 80, 120, 160, 200, 240 xu (một cấp ~25 xu, một lượt 3 cấp ~50-80 xu).
int huntPrice(int n) => 80 + n * 40;

/// Kho đồ của bé (carry).
class HuntCarry {
  HuntCarry({required this.coins, required this.skills, required this.perm, required this.off});
  int coins;
  final Map<String, int> skills;
  final Map<String, int> perm;
  List<String> off;

  int get total => _sk.fold(0, (s, k) => s + skills[k]!);
  Json toJson() => {'v': 1, 'coins': coins, 'skills': {...skills}, 'perm': {...perm}, 'off': [...off]};
}

/// int(v, a, b) của web: Math.max(a, Math.min(b, Math.floor(+v || 0))) — +v như JS ("3.7" → 3, true → 1).
int _int(Object? v, int a, int b) {
  double d;
  if (v is num) {
    d = v.toDouble();
  } else if (v is bool) {
    d = v ? 1 : 0;
  } else if (v is String) {
    final t = v.trim();
    d = t.isEmpty ? 0 : (double.tryParse(t) ?? double.nan);
  } else {
    d = v == null ? 0 : double.nan;
  }
  if (d.isNaN || d == 0) return math.max(a, math.min(b, 0));
  if (d.isInfinite) return d > 0 ? b : a;
  return math.max(a, math.min(b, d.floor()));
}

/// Đọc carry phòng thủ: thiếu trường thì mặc định. Súng nước tối thiểu cấp 1 (món chính).
HuntCarry readHuntCarry(Object? c) {
  final m = c is Map ? c : const {};
  final sk = m['skills'] is Map ? m['skills'] as Map : const {};
  final pm = m['perm'] is Map ? m['perm'] as Map : const {};
  final skills = {for (final k in _sk) k: _int(sk[k], 0, kHuntSkillMax)};
  final perm = {for (final k in kHuntPerm.keys) k: _int(pm[k], 0, kHuntPermMax)};
  if (skills['gun'] == 0) skills['gun'] = 1;
  final off = m['off'] is List ? (m['off'] as List).map((e) => '$e').where((k) => kHuntSkills.containsKey(k) && skills[k]! > 0).toList() : <String>[];
  return HuntCarry(coins: _int(m['coins'], 0, 10000000), skills: skills, perm: perm, off: off);
}

/// Gộp: đồ sở hữu không bao giờ giảm so với bản đã lưu.
Json mergeHuntCarry(Object? old, HuntCarry cur) {
  final o = readHuntCarry(old), out = readHuntCarry(cur.toJson());
  for (final k in _sk) {
    out.skills[k] = math.max(o.skills[k]!, out.skills[k]!);
  }
  for (final k in kHuntPerm.keys) {
    out.perm[k] = math.max(o.perm[k]!, out.perm[k]!);
  }
  return out.toJson();
}

String _stars(int n, [int m = 5]) => '★' * n + '☆' * math.max(0, m - n);

// =================================================================================================================
// Module: Kho vũ khí (cấp đầu của lượt) rồi chơi
// =================================================================================================================

class HuntModule extends FunGameModule {
  const HuntModule();
  @override
  String get id => 'hunt';
  @override
  Widget build(BuildContext context, FunGameContext ctx) => HuntRun(ctx: ctx);
}

class HuntRun extends StatefulWidget {
  const HuntRun({super.key, required this.ctx, this.bot = false, this.turbo = 1});
  final FunGameContext ctx;

  /// Lái tự động + số bước mô phỏng mỗi khung (kiểm thử).
  final bool bot;
  final int turbo;
  @override
  State<HuntRun> createState() => _HuntRunState();
}

class _HuntRunState extends State<HuntRun> {
  late bool shop;
  late final HuntCarry C = readHuntCarry(widget.ctx.carry);
  late final Json saved = readHuntCarry(widget.ctx.carry).toJson();

  /// Game tạo một lần (build() chạy lại khi xoay máy... không được tạo game mới).
  late final HuntGame game = HuntGame(widget.ctx, carry: C, saved: saved, bot: widget.bot, turbo: widget.turbo);

  @override
  void initState() {
    super.initState();
    // Kho vũ khí chỉ ở cấp đầu của vé (web: opts._huntShop dùng chung các cấp của vé = ctx.ticket).
    shop = widget.ctx.ticket['_huntShop'] != true;
    widget.ctx.ticket['_huntShop'] = true;
  }

  void _save() => widget.ctx.saveGear(mergeHuntCarry(saved, C));

  void _end(FunResult r) => widget.ctx.finish(r);

  @override
  Widget build(BuildContext context) {
    if (shop) {
      return HuntArmory(
        ctx: widget.ctx,
        carry: C,
        save: _save,
        onPlay: () => setState(() => shop = false),
      );
    }
    return ColoredBox(
      color: funTheme(widget.ctx.level).groundColor,
      child: FunCanvas(game: game, onEnd: _end),
    );
  }
}

/// Kho vũ khí: mua nâng cấp vĩnh viễn bằng xu, bật/tắt skill đã có (armory()).
class HuntArmory extends StatefulWidget {
  const HuntArmory({super.key, required this.ctx, required this.carry, required this.save, required this.onPlay});
  final FunGameContext ctx;
  final HuntCarry carry;
  final VoidCallback save;
  final VoidCallback onPlay;
  @override
  State<HuntArmory> createState() => _HuntArmoryState();
}

class _HuntArmoryState extends State<HuntArmory> {
  String? bought;
  int buyN = 0;

  HuntCarry get C => widget.carry;

  void _buy(String k) {
    final a = widget.ctx.audio;
    final n = C.perm[k]!, cost = huntPrice(n);
    if (n >= kHuntPermMax || C.coins < cost) {
      a.sfx('wrong');
      return;
    }
    setState(() {
      C.coins -= cost;
      C.perm[k] = n + 1;
      bought = k;
      buyN++;
    });
    a.sfx('power');
    widget.save();
  }

  void _toggle(String k) {
    final a = widget.ctx.audio;
    setState(() {
      if (C.off.contains(k)) {
        C.off = C.off.where((x) => x != k).toList();
      } else if (kHuntSkills[k]!.atk && !_sk.any((x) => x != k && kHuntSkills[x]!.atk && C.skills[x]! > 0 && !C.off.contains(x))) {
        a.sfx('wrong');
        return;
      } else {
        C.off = [...C.off, k];
      }
      a.sfx('tap');
      widget.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    final en = widget.ctx.i18n.isEn;
    final fs = baseFontSize(context);
    final w = MediaQuery.sizeOf(context).width;
    final cols = w <= 640 ? 2 : 4;
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(color: Color(0x40000000), offset: Offset(0, 3))]);
    final owned = _sk.where((k) => C.skills[k]! > 0).toList();
    return DecoratedBox(
      key: const Key('hunt-shop'),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5F3DC4), Color(0xFF845EF7)])),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 64, 14, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(spacing: 12, children: [
                Text(en ? '🛡️ Armory' : '🛡️ Kho vũ khí', style: white.copyWith(fontSize: fs * 2)),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 2, 22, 2),
                  decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(30)),
                  child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
                    const EmojiImage('Coin', size: 48, photo: false),
                    Text('${C.coins}', key: const Key('hunt-coins'), style: white.copyWith(fontSize: fs * 2)),
                  ]),
                ),
                LayoutBuilder(builder: (context, box) {
                  final cw = (box.maxWidth - 12 * (cols - 1)) / cols;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final k in kHuntPerm.keys) SizedBox(width: cw, child: _permCard(k, en, fs)),
                  ]);
                }),
                Text(en ? '🎒 My gear' : '🎒 Đồ của bé', style: white.copyWith(fontSize: fs * 1.4)),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  for (final k in owned)
                    GestureDetector(
                      key: Key('hunt-sk-$k'),
                      onTap: () => _toggle(k),
                      child: Opacity(
                        opacity: C.off.contains(k) ? .35 : 1,
                        child: Container(
                          width: 74,
                          padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
                          decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: kHuntSkills[k]!.c, width: 3)),
                          child: Stack(children: [
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              EmojiImage(kHuntSkills[k]!.img, size: 50, photo: false),
                              Text('★' * C.skills[k]!, maxLines: 1, style: TextStyle(color: const Color(0xFFFAB005), fontSize: fs * .72, height: 1.2)),
                            ]),
                            if (C.off.contains(k)) const Positioned(top: 0, right: 6, child: Text('✖', style: TextStyle(color: Color(0xFFE03131), fontSize: 22, fontWeight: FontWeight.w800))),
                          ]),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                Chunky(
                  key: const Key('hunt-play'),
                  onTap: () {
                    widget.ctx.audio.sfx('tap');
                    widget.onPlay();
                  },
                  color: const Color(0xFF40C057),
                  shadowColor: const Color(0xFF2B8A3E),
                  depth: 7,
                  radius: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 6),
                  child: Text(en ? 'Play ▶' : 'Chơi ▶', style: white.copyWith(fontSize: fs * 2.2)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permCard(String k, bool en, double fs) {
    final p = kHuntPerm[k]!, n = C.perm[k]!, max = n >= kHuntPermMax, cost = huntPrice(n), ok = !max && C.coins >= cost;
    Widget card = Opacity(
      opacity: max || ok ? 1 : .55,
      child: Chunky(
        key: Key('hunt-perm-$k'),
        onTap: () => _buy(k),
        radius: 24,
        depth: 6,
        shadowColor: const Color(0x33000000),
        border: Border.all(color: p.c, width: 4),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EmojiImage(p.img, size: 84, photo: false),
          Text(en ? p.en : p.vi, style: TextStyle(color: p.c, fontWeight: FontWeight.w800, fontSize: fs * 1.3, height: 1.1)),
          Text(_stars(n), style: TextStyle(color: const Color(0xFFFAB005), fontSize: fs * 1.3, letterSpacing: 1, height: 1.2)),
          max
              ? Text('✔ MAX', style: TextStyle(color: const Color(0xFF2F9E44), fontWeight: FontWeight.w800, fontSize: fs * 1.4))
              : Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
                  const EmojiImage('Coin', size: 30, photo: false),
                  Text('$cost', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: fs * 1.4)),
                ]),
        ]),
      ),
    );
    if (bought == k) {
      card = TweenAnimationBuilder<double>(
        key: ValueKey('buy$buyN'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, v, child) => Transform.scale(scale: 1 + math.sin(v * math.pi) * .12, child: child),
        child: card,
      );
    }
    return card;
  }
}

// =================================================================================================================
// Game
// =================================================================================================================

class _Kind {
  const _Kind(this.a, {this.fly = false, this.hp = 1, this.sp = 1, this.sz = 1, this.r = false, this.zig = false, this.hop = false, this.shoot = false});
  final String a;
  final bool fly, r, zig, hop, shoot;
  final double hp, sp, sz;
}

// Quái thường (sprite Kenney plat/enemies, creatures/flyers). hp/sp/sz: hệ số; r: hình gốc quay mặt sang phải.
const List<_Kind> _kinds = [
  _Kind('slime'),
  _Kind('mouse', hp: .8, sp: 1.45, sz: .85),
  _Kind('bee', hp: .7, sp: 1.3, sz: .85, zig: true),
  _Kind('fly', fly: true, hp: 1.2, sp: 1.2, r: true, zig: true),
  _Kind('ladybug', hp: 1.4, sp: 1.1, sz: .95),
  _Kind('worm', hp: 1.6, sp: .85),
  _Kind('sslime', hp: 2.2, sp: .95, sz: 1.05),
  _Kind('frog', hp: 1.8, sp: .7, hop: true),
  _Kind('fslime', hp: 2.4, sp: .9, sz: 1.05, shoot: true),
  _Kind('snail', hp: 3.5, sp: .6, sz: 1.2),
];
const List<(String, String, String)> _bosses = [('bslime', 'Vua slime', 'Slime king'), ('dragon', 'Rồng', 'Dragon'), ('Ogre', 'Quỷ khổng lồ', 'Giant ogre')];
const _kindColors = [Color(0xFF69DB7C), Color(0xFFADB5BD), Color(0xFFFCC419), Color(0xFF495057), Color(0xFFFA5252), Color(0xFFF783AC), Color(0xFF748FFC), Color(0xFF51CF66), Color(0xFFFF922B), Color(0xFFB7793F)];

class _Foe {
  _Foe(this.k, this.x, this.y, this.h, this.hp, this.sp, {this.elite = false}) : r = h * .42, max = hp;
  final _Kind k;
  double x, y, h, r, hp, max, sp;
  double ph = rand(0, 6), slow = 0, flash = 0, kh = 0, bh = 0, vx = 0, sc = rand(2, 5), hopT = rand(1, 2);
  final bool elite;
  bool dead = false;
  // Trùm
  double ring = 2.5, sum = 5, dash = 4, dashT = 0, aim = 0, dx = 0, dy = 0;
}

class _Shot {
  _Shot(this.k, this.x, this.y, {this.vx = 0, this.vy = 0, required this.r, required this.dmg, required this.life, this.pierce = 1, this.rad = 0, this.a = 0, this.dist = 0});
  final String k;
  double x, y, vx, vy, r, dmg, life, rad, a, dist;
  int pierce;
  double t = 0;
  final hit = <_Foe>{};
}

class _Pickup {
  _Pickup(this.x, this.y, {this.v = 1, this.k = 'gem_blue', this.heart = false, this.fly = false});
  double x, y;
  int v;
  String k;
  final bool heart;
  bool fly;
}

class _Pet {
  _Pet(this.x, this.y, this.rig);
  double x, y, cd = 0;
  int face = 1;
  bool mv = false;
  final PetBuddy rig;
}

class _Card {
  _Card(this.list, {required this.lift});
  final List<String> list;
  double t = 0, done = 0;
  bool lift;
  int sel = -1;
  final rects = <Rect>[];
}

/// Một cấp Săn quái vật.
class HuntGame extends FunCanvasGame {
  HuntGame(super.ctx, {HuntCarry? carry, Json? saved, this.bot = false, this.turbo = 1})
      : C = carry ?? readHuntCarry(ctx.carry),
        saved = saved ?? readHuntCarry(ctx.carry).toJson();

  final HuntCarry C;
  final Json saved;
  final bool bot;
  final int turbo;

  late final (String, String, String) bk = _bosses[(lv ~/ 10) % _bosses.length];

  @override
  List<String> get images => [
        ctx.heroImg, th.sun, ...th.deco, 'Ogre', 'Collision', ...kHuntSkills.values.map((s) => s.img), ...kHuntPerm.values.map((p) => p.img), //
      ];
  @override
  List<String> get sheetNames => ['plat/enemies', 'creatures/flyers', 'plat/tiles', 'fxa/fx'];

  final F = FunFx();
  final D = Dust(220);
  final B = Booms(null, 28);
  final sh = Shaker();
  late double diag, U, fsz, jr;
  late final double pw = 1 + .12 * C.perm['power']!;
  late final double power = math.min(1, (C.total + C.perm.values.fold(0, (a, b) => a + b)) / (kHuntCap + 20));
  // Cấp: quái đông, nhanh, trâu dần; trùm mạnh dần. Đồ mạnh thì quái/trùm tăng máu nhẹ.
  late final int dur = ramp(lv, 55, 75).round();
  late final double hpK = (1 + 11 * math.pow(ramp(lv, 0, 1), 1.4)) * (1 + 1.5 * power * power);
  late double spK;
  late final int capN = ramp(lv, 32, 60).round();
  late final double spawnBase = ramp(lv, 1.05, .3);

  // Bé
  double meX = 0, meY = 0, meR = 0, meInv = 0, meMv = 0, meShieldT = 0, meT = 0;
  int meHp = 0, meMax = 0, meFace = 1;
  bool meShield = false;

  final foes = <_Foe>[];
  final shots = <_Shot>[];
  final eshots = <_Shot>[];
  final gems = <_Pickup>[];
  final coins = <_Pickup>[];
  final zaps = <List<double>>[]; // x, y, life, seed
  final meteors = <List<double>>[]; // x, y, t, dur, dmg, rad
  final pets = <_Pet>[];
  final cd = <String, double>{'gun': .6, 'bolt': 1.2, 'fire': 1.5, 'boom': 1, 'meteor': 2};
  bool cdAlt = false;
  double t = 0, xp = 0, spawnT = 2.5, endT = 0, knifeA = 0;
  int score = 0, earned = 0, kills = 0, wave = 0, pickQ = 0;
  _Foe? _boss;
  bool bossDone = false;
  FunResult? end;
  ({String s, double t, Color c})? msg;
  _Card? _card;
  late final Costume fig = heroOf(ctx.heroImg);

  // Cần ảo
  int? joyId;
  double joyBx = 0, joyBy = 0, joyX = 0, joyY = 0;

  int L(String k) => C.skills[k]! > 0 && !C.off.contains(k) ? C.skills[k]! : 0;
  int get total => C.total;
  int maxHp() => 5 + C.perm['hp']! + L('heart');
  double speed() => S * .3 * (1 + .06 * L('shoes') + .04 * C.perm['speed']!);
  int need() {
    final n = total;
    return n >= kHuntCap ? 40 + lv : (3 + n * 1.5 + n * n * .04).round();
  }

  bool get cardOpen => _card != null;

  /// Trạng thái cho kiểm thử.
  List<String> get cardOptions => _card?.list ?? const [];
  List<Rect> get cardRects => _card?.rects ?? const [];
  bool get bossOn => _boss != null && !_boss!.dead;
  int get hp => meHp;
  int get foeCount => foes.length;

  @override
  void init() {
    diag = math.sqrt(W * W + H * H) / 2;
    U = math.max(S, 460);
    fsz = U * .085;
    jr = math.min(70, S * .11);
    spK = S * ramp(lv, .085, .18);
    meR = U * .038;
    meMax = meHp = maxHp();
    xp = need() * .2 * C.perm['gem']!;
    if (xp >= need()) {
      xp = 0;
      pickQ = 1;
    }
    _syncPets();
  }

  void _syncPets() {
    final n = L('pet') > 0 ? (L('pet') >= 4 ? 2 : 1) : 0;
    while (pets.length < n) {
      pets.add(_Pet(meX - 40 * (pets.length + 1), meY + 30, petBuddy('dog')));
    }
  }

  void _save() => ctx.saveGear(mergeHuntCarry(saved, C));

  // ---- Điều khiển ----
  @override
  void pointerDown(Offset p, int id) {
    if (_card != null) {
      _tapCard(p.dx, p.dy);
      return;
    }
    if (end != null) return;
    joyId = id;
    joyBx = joyX = p.dx;
    joyBy = joyY = p.dy;
  }

  @override
  void pointerMove(Offset p, int id, bool down) {
    if (id != joyId) return;
    joyX = p.dx;
    joyY = p.dy;
  }

  @override
  void pointerUp(Offset p, int id) {
    if (id == joyId) joyId = null;
    _card?.lift = true;
  }

  // ---- Thẻ chọn skill ----
  void _makeCard() {
    final atTop = total >= kHuntCap;
    final avail = atTop ? <String>[] : _sk.where((k) => C.skills[k]! < kHuntSkillMax).toList();
    // Ưu tiên vũ khí bé đã có (lên sao) và luôn có ít nhất 1 vũ khí đánh quái nếu còn
    double wt(String k) => (C.skills[k]! > 0 ? 2 : 1) * (kHuntSkills[k]!.atk ? 1.3 : 1);
    final opts = <String>[];
    final pool = [...avail];
    while (opts.length < 3 && pool.isNotEmpty) {
      var r = rng.nextDouble() * pool.fold(0.0, (s, k) => s + wt(k));
      var i = 0;
      for (; i < pool.length - 1; i++) {
        r -= wt(pool[i]);
        if (r <= 0) break;
      }
      opts.add(pool.removeAt(i));
    }
    if (opts.isNotEmpty && !opts.any((o) => kHuntSkills[o]!.atk)) {
      final a = pool.where((k) => kHuntSkills[k]!.atk).toList();
      if (a.isNotEmpty) opts[opts.length - 1] = pick(a);
    }
    if (opts.length < 3) opts.add('coins');
    if (opts.length < 3) opts.add('heal');
    _card = _Card(opts, lift: joyId == null && !bot);
    joyId = null;
    sfx('star');
  }

  /// Chọn thẻ thứ i (chạm hoặc kiểm thử).
  void choose(int i) {
    final cd0 = _card;
    if (cd0 == null || i >= cd0.list.length) return;
    final o = cd0.list[i];
    cd0.sel = i;
    cd0.done = .35;
    if (o == 'coins') {
      earned += 5;
      C.coins += 5;
      F.text(meX, meY - 60, '+5', const Color(0xFFFFD43B));
      sfx('coin');
    } else if (o == 'heal') {
      meHp = maxHp();
      F.text(meX, meY - 60, '+❤', const Color(0xFFFF6B6B));
      sfx('power');
    } else {
      C.skills[o] = math.min(kHuntSkillMax, C.skills[o]! + 1);
      C.off = C.off.where((x) => x != o).toList();
      if (o == 'heart') {
        meMax = maxHp();
        meHp = math.min(meMax, meHp + 2);
      }
      if (o == 'pet') _syncPets();
      if (o == 'armor') meShieldT = 0;
      sfx('power');
      D.sparks(meX, meY, 20, kHuntSkills[o]!.c, 320);
    }
    _save();
  }

  void _tapCard(double x, double y) {
    final c = _card;
    if (c == null || c.sel >= 0 || c.t < .45 || !c.lift) return;
    for (final (i, r) in c.rects.indexed) {
      if (r.contains(Offset(x, y))) choose(i);
    }
  }

  // ---- Quái ----
  bool _visible(_Foe o, [double pad = 0]) => (o.x - meX).abs() < W / 2 + pad && (o.y - meY).abs() < H / 2 + pad;

  _Foe? _spawnFoe(_Kind? kind, [double? x, double? y, bool elite = false]) {
    if (foes.length >= capN) return null;
    if (x == null || y == null) {
      final a = rand(0, 6.283), d = diag + 40;
      x = meX + math.cos(a) * d;
      y = meY + math.sin(a) * d;
    }
    final k = kind ?? _kinds[0], sz = fsz * k.sz * (elite ? 1.7 : 1), hp = k.hp * hpK * (elite ? 10 : 1) * (1 + t / dur * .4);
    final f = _Foe(k, x, y, sz, hp, spK * k.sp * rand(.9, 1.1) * (elite ? .8 : 1), elite: elite);
    foes.add(f);
    return f;
  }

  List<_Kind> _poolNow() => _kinds.sublist(0, math.min(_kinds.length, 2 + wave + lv ~/ 5));

  void _hurtFoe(_Foe f, double dmg, [Color c = Colors.white]) {
    if (f.dead) return;
    f.hp -= dmg;
    f.flash = .08;
    if (f == _boss) {
      if (rng.nextDouble() < .3) D.sparks(f.x, f.y, 4, c, 200);
      return;
    }
    if (f.hp <= 0) _killFoe(f);
  }

  void _killFoe(_Foe f) {
    f.dead = true;
    kills++;
    B.add(f.x, f.y, f.h * 1.3);
    D.sparks(f.x, f.y, 8, const Color(0xFFFFE066), 260);
    score += f.elite ? 5 : 1;
    if (f.elite) {
      gems.add(_Pickup(f.x, f.y, v: 10, k: 'gem_red'));
      for (var i = 0; i < 3; i++) {
        coins.add(_Pickup(f.x + rand(-30, 30), f.y + rand(-30, 30)));
      }
      if (rng.nextDouble() < .3) coins.add(_Pickup(f.x, f.y, heart: true));
      sfx('boom');
      sh.add(5);
    } else {
      if (gems.length < 140) {
        final v = lv >= 30 && rng.nextDouble() < .15 ? 3 : 1;
        gems.add(_Pickup(f.x, f.y, v: v, k: v == 3 ? 'gem_green' : 'gem_blue'));
      } else {
        gems[kills % gems.length].v += 1; // nhiều ngọc quá: dồn vào ngọc cũ
      }
      if (gems.last.v == 3) gems.last.k = 'gem_green';
      if (rng.nextDouble() < .04) {
        coins.add(_Pickup(f.x, f.y));
      } else if (rng.nextDouble() < .012) {
        coins.add(_Pickup(f.x, f.y, heart: true)); // tim rơi: hồi 1 máu
      }
      if (rng.nextDouble() < .25) sfx('pop');
    }
  }

  _Foe? _nearest(double x, double y, [double maxD = 1e9]) {
    _Foe? best;
    var bd = maxD * maxD;
    for (final f in foes) {
      if (f.dead) continue;
      final d = (f.x - x) * (f.x - x) + (f.y - y) * (f.y - y);
      if (d < bd) {
        bd = d;
        best = f;
      }
    }
    final b = _boss;
    if (b != null && !b.dead) {
      final d = (b.x - x) * (b.x - x) + (b.y - y) * (b.y - y);
      if (d < bd) best = b;
    }
    return best;
  }

  List<_Foe> _allTargets() => [...foes.where((f) => !f.dead), if (_boss != null && !_boss!.dead) _boss!];

  void _area(double x, double y, double rad, double dmg, Color c) {
    for (final f in _allTargets()) {
      if (math.sqrt((f.x - x) * (f.x - x) + (f.y - y) * (f.y - y)) < rad + f.r) _hurtFoe(f, dmg, c);
    }
  }

  void _startBoss() {
    final hp = ramp(lv, 40, 1200) * (1 + 1.5 * power * power), a = rand(0, 6.283);
    _boss = _Foe(const _Kind('boss'), meX + math.cos(a) * diag * .9, meY + math.sin(a) * diag * .9, S * .3, hp, S * ramp(lv, .07, .12))..r = S * .12;
    _boss!.ph = 0;
    msg = (s: tr('${bk.$2.toUpperCase()} ĐÃ TỚI!', '${bk.$3.toUpperCase()} IS HERE!'), t: 2.2, c: const Color(0xFFFF6B6B));
    sfx('power');
    sh.add(10);
  }

  void _hurtMe([int n = 1]) {
    if (meInv > 0 || end != null) return;
    if (meShield) {
      meShield = false;
      meInv = .8;
      meShieldT = 0;
      sfx('pop');
      D.sparks(meX, meY, 14, const Color(0xFF748FFC), 260);
      return;
    }
    meHp -= n;
    meInv = 1.3 + .1 * L('armor');
    sfx('hit');
    sh.add(8);
    D.sparks(meX, meY, 12, const Color(0xFFFF8787), 280);
    if (meHp <= 0) {
      meHp = 0;
      _finish(false);
    }
  }

  void _finish(bool win) {
    if (end != null) return;
    if (win) {
      final b = 5 + lv ~/ 5;
      earned += b;
      C.coins += b;
      score += 50;
      sfx('win');
    }
    score += earned;
    end = FunResult(win: win, score: score, carry: mergeHuntCarry(saved, C));
    endT = 0;
  }

  // ---- Một bước mô phỏng ----
  void _step(double dt) {
    final cdx = _card;
    if (cdx != null) {
      cdx.t += dt;
      if (bot && cdx.t > .5 && cdx.sel < 0) choose(0);
      if (cdx.sel >= 0) {
        cdx.done -= dt;
        if (cdx.done <= 0) {
          _card = null;
          pickQ = math.max(0, pickQ - 1);
        }
      }
      return;
    }
    if (pickQ > 0) {
      _makeCard();
      return;
    }
    t += dt;
    meT += dt;
    F.update(dt);
    D.update(dt);
    B.update(dt);
    sh.update(dt);
    if (msg != null) {
      final m = msg!;
      msg = m.t - dt <= 0 ? null : (s: m.s, t: m.t - dt, c: m.c);
    }
    if (end != null) return;
    // Di chuyển
    var mx = 0.0, my = 0.0;
    if (joyId != null) {
      final dx = joyX - joyBx, dy = joyY - joyBy, d = math.sqrt(dx * dx + dy * dy);
      if (d > 8) {
        final k = math.min(1, d / jr);
        mx = dx / d * k;
        my = dy / d * k;
      }
      if (d > jr) {
        joyBx = joyX - dx / d * jr;
        joyBy = joyY - dy / d * jr;
      }
    } else if (bot) {
      (mx, my) = _botMove();
    } else {
      bool k(LogicalKeyboardKey a, LogicalKeyboardKey b) => keys.contains(a) || keys.contains(b);
      mx = (k(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD) ? 1 : 0) - (k(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA) ? 1.0 : 0);
      my = (k(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS) ? 1 : 0) - (k(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW) ? 1.0 : 0);
      final d = math.sqrt(mx * mx + my * my);
      if (d > 1) {
        mx /= d;
        my /= d;
      }
    }
    final sp = speed();
    meX += mx * sp * dt;
    meY += my * sp * dt;
    meMv = math.sqrt(mx * mx + my * my);
    if (mx.abs() > .15) meFace = mx > 0 ? 1 : -1;
    meInv = math.max(0, meInv - dt);
    if (L('armor') > 0 && !meShield) {
      meShieldT += dt;
      if (meShieldT >= 13 - 2 * L('armor')) {
        meShield = true;
        meShieldT = 0;
        sfx('pop');
      }
    }

    // Đợt quái + sinh quái
    final nw = math.min(3, (t / (dur / 4)).floor());
    if (nw > wave && t < dur) {
      wave = nw;
      msg = (s: tr('ĐỢT ${wave + 1}!', 'WAVE ${wave + 1}!'), t: 1.6, c: const Color(0xFFFFD43B));
      sfx('power');
      // Vòng vây: quái xếp vòng quanh bé + 1 quái to (elite)
      final n = ramp(lv, 8, 16).round(), pool = _poolNow(), k = pick(pool);
      for (var i = 0; i < n; i++) {
        final a = i / n * 6.283;
        _spawnFoe(k, meX + math.cos(a) * diag * .95, meY + math.sin(a) * diag * .95);
      }
      _spawnFoe(pick(pool), null, null, true);
    }
    if (t > 2.5) {
      spawnT -= dt;
      final rate = _boss != null ? 2.2 : 1 - .45 * math.min(1, t / dur);
      if (spawnT <= 0) {
        spawnT = spawnBase * rate * rand(.8, 1.2);
        final g = _boss != null ? 1 : 1 + t ~/ 25 + lv ~/ 15, pool = _poolNow();
        for (var i = 0; i < g; i++) {
          _spawnFoe(pick(pool));
        }
      }
    }
    if (t >= dur && _boss == null && !bossDone) _startBoss();

    // Quái đi về phía bé
    final frostR = L('frost') > 0 ? S * (.13 + .025 * L('frost')) : 0.0, frostSlow = .55 - .05 * L('frost'), frostDps = (.6 + .35 * L('frost')) * pw;
    for (final f in foes) {
      if (f.dead) continue;
      f.ph += dt;
      f.flash = math.max(0, f.flash - dt);
      f.kh = math.max(0, f.kh - dt);
      f.bh = math.max(0, f.bh - dt);
      var dx = meX - f.x, dy = meY - f.y;
      var d = math.sqrt(dx * dx + dy * dy);
      if (d == 0) d = 1;
      dx /= d;
      dy /= d;
      var v = f.sp * (f.slow > 0 ? frostSlow : 1);
      f.slow = math.max(0, f.slow - dt);
      if (f.k.hop) {
        f.hopT -= dt;
        v *= f.hopT < .35 ? 3.2 : .25;
        if (f.hopT <= 0) f.hopT = rand(1.2, 2);
      }
      if (f.k.zig) {
        final z = math.sin(f.ph * f.sc) * .7, ox = -dy * z, oy = dx * z;
        dx += ox;
        dy += oy;
      }
      f.x += dx * v * dt;
      f.y += dy * v * dt;
      f.vx = dx;
      if (d > diag * 1.8) {
        // quái bị bỏ xa: đưa ra phía trước
        final a = (meMv > .1 ? math.atan2(my, mx) : rand(0, 6.283)) + rand(-.8, .8), dd = diag + 40;
        f.x = meX + math.cos(a) * dd;
        f.y = meY + math.sin(a) * dd;
      }
      if (frostR > 0 && d < frostR + f.r) {
        f.slow = .3;
        _hurtFoe(f, frostDps * dt, const Color(0xFF74C0FC));
      }
      if (f.k.shoot && lv >= 12 && d < diag) {
        f.sc -= dt * .3;
        if (f.sc <= 0) {
          f.sc = rand(3, 5) * ramp(lv, 1.3, .8);
          if (eshots.length < 40) eshots.add(_Shot('e', f.x, f.y, vx: dx * S * .32, vy: dy * S * .32, r: S * .022, dmg: 1, life: 4));
        }
      }
      if (!f.dead && d < f.r + meR) _hurtMe(f.elite && lv >= 40 ? 2 : 1);
    }
    // Quái không chồng lên nhau
    for (var i = 0; i < foes.length; i++) {
      final a = foes[i];
      for (var j = i + 1; j < foes.length; j++) {
        final b = foes[j], dx = b.x - a.x, dy = b.y - a.y, rr = (a.r + b.r) * .85, d2 = dx * dx + dy * dy;
        if (d2 < rr * rr && d2 > .01) {
          final d = math.sqrt(d2), p = (rr - d) / 2 / d;
          a.x -= dx * p;
          a.y -= dy * p;
          b.x += dx * p;
          b.y += dy * p;
        }
      }
    }

    // Trùm
    final b = _boss;
    if (b != null && !b.dead) {
      b.ph += dt;
      b.flash = math.max(0, b.flash - dt);
      b.kh = math.max(0, b.kh - dt);
      b.bh = math.max(0, b.bh - dt);
      final dx = meX - b.x, dy = meY - b.y;
      var d = math.sqrt(dx * dx + dy * dy);
      if (d == 0) d = 1;
      final rage = b.hp < b.max / 2;
      if (b.dashT > 0) {
        b.dashT -= dt;
        if (b.aim > 0) {
          b.aim -= dt;
        } else {
          b.x += b.dx * b.sp * 4.5 * dt;
          b.y += b.dy * b.sp * 4.5 * dt;
        }
      } else {
        final v = b.sp * (b.slow > 0 ? .7 : 1);
        b.x += dx / d * v * dt;
        b.y += dy / d * v * dt;
      }
      b.slow = math.max(0, b.slow - dt);
      if (frostR > 0 && d < frostR + b.r) {
        b.slow = .3;
        _hurtFoe(b, frostDps * dt, const Color(0xFF74C0FC));
      }
      b.ring -= dt;
      b.sum -= dt;
      b.dash -= dt;
      if (b.ring <= 0) {
        b.ring = ramp(lv, 3.4, 1.7) * (rage ? .75 : 1);
        final n = ramp(lv, 6, 16).round(), off = rng.nextDouble(), v = S * ramp(lv, .24, .38);
        for (var i = 0; i < n && eshots.length < 80; i++) {
          final a = (i + off) / n * 6.283;
          eshots.add(_Shot('e', b.x, b.y, vx: math.cos(a) * v, vy: math.sin(a) * v, r: S * .026, dmg: 1, life: 5));
        }
        sfx('boom');
        sh.add(4);
      }
      if (b.sum <= 0) {
        b.sum = ramp(lv, 7, 4);
        final pool = _poolNow();
        for (var i = 0; i < 3 + lv ~/ 15; i++) {
          _spawnFoe(pick(pool), b.x + rand(-80, 80), b.y + rand(-80, 80));
        }
      }
      if (lv >= 15 && b.dash <= 0 && b.dashT <= 0) {
        b.dash = ramp(lv, 6, 3.5);
        b.dashT = 1.15;
        b.aim = .65;
        b.dx = dx / d;
        b.dy = dy / d;
        F.text(b.x, b.y - b.h * .6, '!!', const Color(0xFFFF6B6B));
      }
      if (d < b.r + meR) _hurtMe(lv >= 30 ? 2 : 1);
      if (b.hp <= 0) {
        b.dead = true;
        bossDone = true;
        for (var k = 0; k < 8; k++) {
          B.add(b.x + rand(-b.h * .4, b.h * .4), b.y + rand(-b.h * .4, b.h * .4), rand(90, 160));
        }
        D.sparks(b.x, b.y, 30, const Color(0xFFFFD43B), 420);
        sh.add(16);
        for (var i = 0; i < 10; i++) {
          coins.add(_Pickup(b.x + rand(-60, 60), b.y + rand(-60, 60), fly: true));
        }
        for (final f in foes) {
          if (!f.dead) _killFoe(f);
        }
        for (final g in gems) {
          g.fly = true;
        }
        eshots.clear();
        endT = 1.6; // chờ xu/ngọc bay về rồi mới kết thúc
      }
    }
    if (bossDone && end == null) {
      endT -= dt;
      if (endT <= 0) _finish(true);
    }
    _weapons(dt);
  }

  void _weapons(double dt) {
    final tgtR = diag * 1.05;
    final b = _boss;
    if (L('gun') > 0) {
      cd['gun'] = cd['gun']! - dt;
      if (cd['gun']! <= 0) {
        final f = b != null && !b.dead && _visible(b) && (cdAlt = !cdAlt) ? b : _nearest(meX, meY, tgtR);
        if (f != null) {
          final l = L('gun');
          cd['gun'] = .62 - .06 * l;
          final n = const [1, 1, 2, 2, 3][l - 1], a0 = math.atan2(f.y - meY, f.x - meX);
          for (var i = 0; i < n && shots.length < 90; i++) {
            final a = a0 + (i - (n - 1) / 2) * .14;
            shots.add(_Shot('gun', meX, meY, vx: math.cos(a) * S * 1.1, vy: math.sin(a) * S * 1.1, r: S * .016 + l, dmg: (1 + .3 * (l - 1)) * pw, life: 1.2, pierce: l >= 5 ? 2 : 1));
          }
          meFace = f.x > meX ? 1 : -1;
          if (rng.nextDouble() < .4) sfx('laser');
        }
      }
    }
    if (L('fire') > 0) {
      cd['fire'] = cd['fire']! - dt;
      if (cd['fire']! <= 0) {
        final f = _nearest(meX, meY, tgtR);
        if (f != null) {
          final l = L('fire');
          cd['fire'] = 2.4 - .25 * l;
          for (var i = 0; i < (l >= 4 ? 2 : 1) && shots.length < 90; i++) {
            final a = math.atan2(f.y - meY, f.x - meX) + (i > 0 ? .35 : 0);
            shots.add(_Shot('fire', meX, meY, vx: math.cos(a) * S * .6, vy: math.sin(a) * S * .6, r: S * .03, dmg: (3 + l) * pw, rad: S * (.09 + .015 * l), life: 1.4));
          }
        }
      }
    }
    if (L('boom') > 0) {
      cd['boom'] = cd['boom']! - dt;
      if (cd['boom']! <= 0) {
        final f = _nearest(meX, meY, tgtR);
        if (f != null) {
          final l = L('boom');
          cd['boom'] = 2 - .2 * l;
          final n = const [1, 1, 2, 2, 3][l - 1], a0 = math.atan2(f.y - meY, f.x - meX);
          for (var i = 0; i < n && shots.length < 90; i++) {
            shots.add(_Shot('boom', meX, meY, a: a0 + (i - (n - 1) / 2) * .6, dist: S * .45, r: S * .035, dmg: (1.5 + .4 * l) * pw, life: 1.2));
          }
        }
      }
    }
    if (L('bolt') > 0) {
      cd['bolt'] = cd['bolt']! - dt;
      if (cd['bolt']! <= 0) {
        final l = L('bolt'), list = _allTargets().where((f) => _visible(f)).toList();
        if (list.isNotEmpty) {
          cd['bolt'] = 2.6 - .3 * l;
          for (var i = 0; i < const [1, 2, 2, 3, 4][l - 1] && list.isNotEmpty; i++) {
            final f = list.removeAt(rng.nextInt(list.length));
            zaps.add([f.x, f.y, .22, rng.nextDouble() * 99]);
            _hurtFoe(f, (3 + 1.2 * l) * pw, const Color(0xFFFCC419));
            D.sparks(f.x, f.y, 8, const Color(0xFFFFF3BF), 240);
          }
          sfx('laser');
        }
      }
    }
    if (L('meteor') > 0) {
      cd['meteor'] = cd['meteor']! - dt;
      if (cd['meteor']! <= 0) {
        final l = L('meteor'), list = _allTargets().where((f) => _visible(f)).toList();
        cd['meteor'] = 4.2 - .5 * l;
        for (var i = 0; i < const [1, 1, 2, 2, 3][l - 1]; i++) {
          final f = b != null && !b.dead && _visible(b) && rng.nextDouble() < .5 ? b : (list.isNotEmpty ? pick(list) : null);
          meteors.add([f?.x ?? meX + rand(-W / 3, W / 3), f?.y ?? meY + rand(-H / 3, H / 3), 0, .6 + i * .12, (4 + 1.5 * l) * pw, S * .11]);
        }
      }
    }
    final tg = _allTargets(); // một mảng mục tiêu cho cả khung
    // Dao bay xoay quanh
    if (L('knife') > 0) {
      knifeA += dt * 3.4;
      final l = L('knife'), r = S * .14, kr = S * .035;
      for (var i = 0; i < l; i++) {
        final a = knifeA + i / l * 6.283, kx = meX + math.cos(a) * r, ky = meY + math.sin(a) * r;
        for (final f in tg) {
          if (!f.dead && f.kh <= 0 && math.sqrt((f.x - kx) * (f.x - kx) + (f.y - ky) * (f.y - ky)) < f.r + kr) {
            f.kh = .35;
            _hurtFoe(f, (1.2 + .35 * l) * pw, const Color(0xFFDEE2E6));
            D.sparks(kx, ky, 4, Colors.white, 200);
          }
        }
      }
    }
    // Đạn bay
    for (var i = shots.length - 1; i >= 0; i--) {
      final s = shots[i];
      s.life -= dt;
      if (s.k == 'boom') {
        s.t += dt;
        final k = s.t / 1.2, d = math.sin(math.min(1, k) * math.pi) * s.dist; // bay ra rồi quay về
        s.x = meX + math.cos(s.a) * d;
        s.y = meY + math.sin(s.a) * d;
        for (final f in tg) {
          if (!f.dead && f.bh <= 0 && math.sqrt((f.x - s.x) * (f.x - s.x) + (f.y - s.y) * (f.y - s.y)) < f.r + s.r) {
            f.bh = .3;
            _hurtFoe(f, s.dmg, const Color(0xFFE8590C));
          }
        }
        if (s.t >= 1.2) shots.removeAt(i);
        continue;
      }
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      var gone = s.life <= 0;
      if (!gone) {
        for (final f in tg) {
          if (f.dead) continue;
          if (math.sqrt((f.x - s.x) * (f.x - s.x) + (f.y - s.y) * (f.y - s.y)) > f.r + s.r || s.hit.contains(f)) continue;
          if (s.k == 'fire') {
            gone = true;
            break;
          }
          _hurtFoe(f, s.dmg, const Color(0xFF74C0FC));
          s.hit.add(f);
          if (--s.pierce <= 0) {
            gone = true;
            break;
          }
        }
      }
      if (gone) {
        if (s.k == 'fire') {
          _area(s.x, s.y, s.rad, s.dmg, const Color(0xFFFF922B));
          B.add(s.x, s.y, s.rad * 2.2);
          D.sparks(s.x, s.y, 12, const Color(0xFFFF922B), 300);
          sh.add(2);
          sfx('boom');
        }
        shots.removeAt(i);
      }
    }
    for (var i = meteors.length - 1; i >= 0; i--) {
      final m = meteors[i];
      m[2] += dt;
      if (m[2] >= m[3]) {
        _area(m[0], m[1], m[5], m[4], const Color(0xFFF06595));
        B.add(m[0], m[1], m[5] * 2.4);
        D.debris(m[0], m[1], 10, const Color(0xFF868E96), 300);
        sh.add(4);
        sfx('boom');
        meteors.removeAt(i);
      }
    }
    for (var i = zaps.length - 1; i >= 0; i--) {
      zaps[i][2] -= dt;
      if (zaps[i][2] <= 0) zaps.removeAt(i);
    }
    // Cún đánh hộ
    for (final p in pets) {
      final l = L('pet'), f = _nearest(p.x, p.y, diag);
      var tx = meX - meFace * S * .08, ty = meY + S * .05;
      if (f != null) {
        tx = f.x;
        ty = f.y;
      }
      final dx = tx - p.x, dy = ty - p.y;
      var d = math.sqrt(dx * dx + dy * dy);
      if (d == 0) d = 1;
      final v = S * (.42 + .03 * l);
      if (d > 6) {
        p.x += dx / d * math.min(d, v * dt);
        p.y += dy / d * math.min(d, v * dt);
        p.face = dx > 0 ? 1 : -1;
      }
      p.mv = d > 10;
      p.rig.update(dt, p.mv);
      if (math.sqrt((p.x - meX) * (p.x - meX) + (p.y - meY) * (p.y - meY)) > diag * 1.2) {
        p.x = meX;
        p.y = meY;
      }
      p.cd -= dt;
      if (f != null && p.cd <= 0 && d < f.r + S * .04) {
        p.cd = .8 - .05 * l;
        _hurtFoe(f, (1.5 + .7 * l) * pw, const Color(0xFFB7793F));
        D.sparks(f.x, f.y, 5, Colors.white, 200);
        if (rng.nextDouble() < .3) sfx('bark');
      }
    }
    foes.removeWhere((f) => f.dead);
    // Đạn quái
    for (var i = eshots.length - 1; i >= 0; i--) {
      final s = eshots[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
      if (s.life <= 0) {
        eshots.removeAt(i);
        continue;
      }
      if (math.sqrt((s.x - meX) * (s.x - meX) + (s.y - meY) * (s.y - meY)) < s.r + meR * .8) {
        eshots.removeAt(i);
        _hurtMe(1);
      }
    }
    // Ngọc + xu: trong tầm nam châm thì bay về bé
    final magR = U * (.18 + .06 * L('magnet'));
    for (var i = gems.length - 1; i >= 0; i--) {
      final g = gems[i], dx = meX - g.x, dy = meY - g.y, d = math.sqrt(dx * dx + dy * dy);
      if (d < magR) g.fly = true;
      if (g.fly) {
        final v = S * 1.4 * dt;
        g.x += dx / (d == 0 ? 1 : d) * math.min(d, v);
        g.y += dy / (d == 0 ? 1 : d) * math.min(d, v);
      }
      if (d < meR + 10) {
        gems.removeAt(i);
        xp += g.v;
        score += g.v > 1 ? 1 : 0;
        if (rng.nextDouble() < .3) sfx('coin');
        if (xp >= need()) {
          xp -= need();
          pickQ++;
        }
      }
    }
    for (var i = coins.length - 1; i >= 0; i--) {
      final c = coins[i], dx = meX - c.x, dy = meY - c.y, d = math.sqrt(dx * dx + dy * dy);
      if (d < magR) c.fly = true;
      if (c.fly) {
        final v = S * 1.4 * dt;
        c.x += dx / (d == 0 ? 1 : d) * math.min(d, v);
        c.y += dy / (d == 0 ? 1 : d) * math.min(d, v);
      }
      if (d < meR + 12) {
        coins.removeAt(i);
        if (c.heart) {
          meHp = math.min(meMax, meHp + 1);
          sfx('power');
          F.text(c.x, c.y - 20, '+❤', const Color(0xFFFF6B6B));
        } else {
          earned++;
          C.coins++;
          sfx('coin');
          F.text(c.x, c.y - 20, '+1', const Color(0xFFFFD43B));
        }
      }
    }
  }

  // Lái tự động khi kiểm thử: đi lang thang, nhặt ngọc gần, né quái sát người.
  ({double x, double y})? _wp;
  double _wpT = 0;
  (double, double) _botMove() {
    _wpT -= 1 / 60;
    if (_wp == null || _wpT <= 0 || math.sqrt(math.pow(_wp!.x - meX, 2) + math.pow(_wp!.y - meY, 2)) < 20) {
      _wp = (x: meX + rand(-S * .6, S * .6), y: meY + rand(-S * .6, S * .6));
      _wpT = rand(1.5, 3);
    }
    var ax = _wp!.x - meX, ay = _wp!.y - meY;
    var dw = math.sqrt(ax * ax + ay * ay);
    if (dw == 0) dw = 1;
    ax /= dw;
    ay /= dw;
    for (final g in gems) {
      final dx = g.x - meX, dy = g.y - meY, d = math.sqrt(dx * dx + dy * dy);
      if (d < S * .3) {
        ax += dx / (d == 0 ? 1 : d);
        ay += dy / (d == 0 ? 1 : d);
        break;
      }
    }
    for (final f in [...foes.map((f) => (f.x, f.y, f.r)), ...eshots.map((s) => (s.x, s.y, s.r)), if (_boss != null && !_boss!.dead) (_boss!.x, _boss!.y, _boss!.r)]) {
      final dx = meX - f.$1, dy = meY - f.$2, d = math.sqrt(dx * dx + dy * dy), r = f.$3 + S * .2;
      if (d < r && d > 0) {
        ax += dx / d * 1.5;
        ay += dy / d * 1.5;
      }
    }
    var d = math.sqrt(ax * ax + ay * ay);
    if (d == 0) d = 1;
    return (ax / d, ay / d);
  }

  @override
  FunResult? update(double dt) {
    for (var i = 0; i < turbo && !(end != null && i > 0); i++) {
      _step(dt);
    }
    if (end != null) {
      endT += dt;
      if (endT > (end!.win ? 2 : 2.2)) return end;
    }
    return null;
  }

  // ---- Vẽ ----
  static double _hash(double i, double j) {
    final s = math.sin(i * 127.1 + j * 311.7) * 43758.5453;
    return s - s.floorToDouble();
  }

  void _drawFoe(Canvas c, _Foe f) {
    final en = sheets['plat/enemies'], fly = sheets['creatures/flyers'];
    final flip = f.k.r ? f.vx < 0 : f.vx > 0, sq = 1 + math.sin(f.ph * 10) * .06;
    fillEllipse(c, f.x, f.y + f.h * .42, f.h * .36, f.h * .1, const Color(0x2E000000));
    c.save();
    c.translate(f.x, f.y + f.h * .45);
    c.scale(1 / sq, sq);
    final a = f.flash > 0 ? .55 : 1.0;
    final ok = f.k.fly ? anim(c, fly, 'fly', f.ph, 0, -f.h * .45, f.h, flip: flip, alpha: a) : anim(c, en, f.k.a, f.ph, 0, -f.h * .45, f.h, flip: flip, alpha: a);
    if (!ok) fillCircle(c, 0, -f.h * .45, f.r, _kindColors[_kinds.indexOf(f.k).clamp(0, _kindColors.length - 1)].withValues(alpha: a));
    c.restore();
    if (f.slow > 0) fillCircle(c, f.x, f.y, f.r * 1.1, const Color(0x5974C0FC));
    if (f.elite) {
      c.drawRect(Rect.fromLTWH(f.x - f.h * .4, f.y - f.h * .62, f.h * .8, 7), Paint()..color = const Color(0x59000000));
      c.drawRect(Rect.fromLTWH(f.x - f.h * .4, f.y - f.h * .62, f.h * .8 * math.max(0, f.hp / f.max), 7), Paint()..color = const Color(0xFFFF6B6B));
    }
  }

  void _drawBoss(Canvas c, _Foe b) {
    final en = sheets['plat/enemies'], fly = sheets['creatures/flyers'];
    final a = b.flash > 0 ? .6 : 1.0, flip = meX > b.x;
    fillEllipse(c, b.x, b.y + b.h * .42, b.h * .38, b.h * .1, const Color(0x38000000));
    if (b.aim > 0) {
      c.drawLine(
          Offset(b.x, b.y),
          Offset(b.x + b.dx * b.sp * 4.5 * .5, b.y + b.dy * b.sp * 4.5 * .5),
          Paint()
            ..color = Color.fromRGBO(255, 60, 60, .4 + .4 * math.sin(t * 30))
            ..strokeWidth = b.r * 1.4);
    }
    final jx = b.hp < b.max / 2 ? math.sin(t * 50) * 2 : 0.0;
    var ok = true;
    if (bk.$1 == 'dragon') {
      ok = anim(c, fly, 'dragon', b.ph, b.x + jx, b.y + math.sin(b.ph * 3) * 8, b.h * .85, flip: !flip, alpha: a);
    } else if (bk.$1 == 'Ogre') {
      ok = img.has('Ogre');
      img.draw(c, 'Ogre', b.x + jx, b.y, b.h, flip: flip, rot: math.sin(b.ph * 6) * .06, alpha: a);
    } else {
      final sq = 1 + math.sin(b.ph * 5) * .07;
      c.save();
      c.translate(b.x + jx, b.y + b.h * .45);
      c.scale(sq, 1 / sq);
      ok = anim(c, en, b.hp < b.max / 2 ? 'fslime' : 'bslime', b.ph, 0, -b.h * .45, b.h, flip: flip, alpha: a);
      c.restore();
    }
    if (!ok) fillCircle(c, b.x, b.y, b.r, const Color(0xFF7048E8).withValues(alpha: a));
    if (b.slow > 0) {
      c.drawCircle(Offset(b.x, b.y), b.r * 1.2, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xB374C0FC));
    }
  }

  void _drawWorld(Canvas c) {
    final tl = sheets['plat/tiles'], fxs = sheets['fxa/fx'];
    B.fx = fxs;
    c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = th.groundColor);
    c.save();
    sh.apply(c);
    c.translate((W / 2 - meX).roundToDouble(), (H / 2 - meY).roundToDouble());
    // Nền: cỏ lấm tấm + cảnh trang trí theo ô lưới (vẽ ô nhìn thấy)
    const g = 170.0;
    final i0 = ((meX - W / 2) / g).floor() - 1, i1 = ((meX + W / 2) / g).floor() + 1, j0 = ((meY - H / 2) / g).floor() - 1, j1 = ((meY + H / 2) / g).floor() + 1;
    final grass = Paint()..color = th.edgeColor.withValues(alpha: .45);
    for (var i = i0; i <= i1; i++) {
      for (var j = j0; j <= j1; j++) {
        final r = _hash(i.toDouble(), j.toDouble()), x = i * g + r * g, y = j * g + _hash(j.toDouble(), i.toDouble()) * g;
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: (16 + r * 14) * 2, height: (6 + r * 4) * 2), grass);
      }
    }
    for (var i = i0; i <= i1; i++) {
      for (var j = j0; j <= j1; j++) {
        final r = _hash(i + 7.0, j - 3.0);
        if (r < .16) img.draw(c, th.deco[(r * 100).floor() % th.deco.length], i * g + g / 2, j * g + g / 2, S * .1 + r * 120);
      }
    }
    for (final gm in gems) {
      if (!spr(c, tl, gm.k, gm.x, gm.y, gm.v >= 10 ? 40 : (gm.v >= 3 ? 32 : 26))) fillCircle(c, gm.x, gm.y, 8, gm.v >= 10 ? const Color(0xFFFA5252) : const Color(0xFF4DABF7));
    }
    for (final cn in coins) {
      if (cn.heart) {
        img.draw(c, 'Red heart', cn.x, cn.y + math.sin(t * 4) * 3, 34);
      } else {
        coin(c, fxs, t + cn.x * .01, cn.x, cn.y, 30, img['Coin']);
      }
    }
    // Vòng băng quanh bé
    if (L('frost') > 0) {
      final r = S * (.13 + .025 * L('frost'));
      fillCircle(c, meX, meY, r, const Color(0x38A5D8FF));
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xBF74C0FC);
      final segs = math.max(8, (2 * math.pi * r / 20).floor()), off = t * 30 / r;
      for (var k = 0; k < segs; k++) {
        c.drawArc(Rect.fromCircle(center: Offset(meX, meY), radius: r), k / segs * 2 * math.pi + off, math.pi / segs, false, dash);
      }
      for (var i = 0; i < 3; i++) {
        final a = t * 1.2 + i * 2.094;
        img.draw(c, 'Snowflake', meX + math.cos(a) * r, meY + math.sin(a) * r, 26, rot: t * 2);
      }
    }
    for (final m in meteors) {
      final k = m[2] / m[3];
      final ring = Offset(m[0], m[1]);
      c.drawCircle(ring, m[5] * (1.2 - k * .2), Paint()..color = Color.fromRGBO(240, 101, 149, k * .3));
      c.drawCircle(ring, m[5] * (1.2 - k * .2), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xCCF06595));
    }
    for (final f in foes) {
      _drawFoe(c, f);
    }
    for (final p in pets) {
      p.rig.draw(c, p.x, p.y + U * .03, U * .045, p.face);
    }
    final b = _boss;
    if (b != null && !b.dead) _drawBoss(c, b);
    D.draw(c);
    B.draw(c); // nổ vẽ dưới bé để bé luôn nhìn thấy mình
    // Bé (người que mặc theo linh vật), nhấp nháy khi vừa trúng đòn
    if (!(meInv > 0 && (meInv * 10).floor() % 2 == 0)) {
      final fh = U * .14;
      drawFigure(c, meX, meY + fh * .45, fh, fig, pose: meMv > .1 ? 'run' : 'idle', t: meT, face: meFace, weaponImage: L('gun') > 0 ? img['Water pistol'] : null);
    }
    if (meShield) {
      fillCircle(c, meX, meY, U * .085, const Color(0x26748FFC));
      c.drawCircle(Offset(meX, meY), U * .085, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xE6748FFC));
    }
    if (L('knife') > 0) {
      final l = L('knife'), r = S * .14;
      for (var i = 0; i < l; i++) {
        final a = knifeA + i / l * 6.283;
        img.draw(c, 'Dagger', meX + math.cos(a) * r, meY + math.sin(a) * r, S * .07, rot: a + math.pi * 1.25);
      }
    }
    for (final s in shots) {
      if (s.k == 'gun') {
        fillCircle(c, s.x, s.y, s.r, const Color(0xFF1C7ED6));
        fillCircle(c, s.x - s.r * .3, s.y - s.r * .3, s.r * .45, const Color(0xFFA5D8FF));
      } else if (s.k == 'fire') {
        img.draw(c, 'Fire', s.x, s.y, s.r * 2.6, rot: math.atan2(s.vy, s.vx) + math.pi / 2);
      } else {
        img.draw(c, 'Boomerang', s.x, s.y, s.r * 2.4, rot: s.t * 14);
      }
    }
    for (final m in meteors) {
      final k = m[2] / m[3];
      img.draw(c, 'Comet', m[0] + (1 - k) * S * .5, m[1] - (1 - k) * S * .8, S * .1, rot: -.6);
    }
    for (final s in eshots) {
      if (!spr(c, tl, 'fireball', s.x, s.y, s.r * 2.6, rot: math.atan2(s.vy, s.vx) + math.pi)) fillCircle(c, s.x, s.y, s.r, const Color(0xFFFF6B6B));
    }
    // Tia sét: đường gấp khúc từ trên trời xuống
    for (final z in zaps) {
      final a = (z[2] / .22).clamp(0.0, 1.0);
      for (final (lw, col) in [(8.0, const Color(0xFFFCC419)), (3.0, Colors.white)]) {
        final p = Path()..moveTo(z[0] + 20, z[1] - H * .6);
        for (var k = 1; k <= 6; k++) {
          p.lineTo(z[0] + (k < 6 ? (_hash(z[3], k.toDouble()) - .5) * 50 : 0), z[1] - H * .6 * (1 - k / 6));
        }
        c.drawPath(p, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lw
          ..color = col.withValues(alpha: a));
      }
    }
    F.draw(c);
    c.restore();
  }

  void _drawHud(Canvas c) {
    final tl = sheets['plat/tiles'];
    final b = _boss;
    funHud(c, W, score: C.coins, time: b != null || bossDone ? null : math.max(0, dur - t), bossHp: b != null && !b.dead ? b.hp : null, bossMax: b?.max);
    // Tim
    final n = meMax, narrow = W < 640, hs = math.min(28.0, (narrow ? W * .6 : W * .36) / n), x0 = W - 14 - hs / 2, hy = narrow ? 78.0 : 32.0;
    for (var i = 0; i < n; i++) {
      img.draw(c, 'Red heart', x0 - i * hs * 1.05, hy, hs * .95, alpha: i < meHp ? 1 : .22);
    }
    if (meShield) img.draw(c, 'Shield', x0 - n * hs * 1.05 - 6, hy, hs);
    // Thanh ngọc (kinh nghiệm) dưới cùng
    final by = H - 18, bw = W - 70, k = math.min(1.0, xp / need());
    fillRRect(c, 50, by - 9, bw, 18, 9, const Color(0x59000000));
    if (k > .02) fillRRect(c, 52, by - 7, (bw - 4) * k, 14, 7, total >= kHuntCap ? const Color(0xFFFFD43B) : const Color(0xFF4DABF7));
    if (!spr(c, tl, 'gem_blue', 30, by, 30)) fillCircle(c, 30, by, 10, const Color(0xFF4DABF7));
    // Skill đang có: hình + sao
    final own = _sk.where((q) => C.skills[q]! > 0).toList(), iz = math.min(44.0, (W - 20) / math.max(1, own.length) - 4);
    for (final (i, q) in own.indexed) {
      final x = 10 + iz / 2 + i * (iz + 4), y = by - 22 - iz / 2, off = C.off.contains(q);
      fillRRect(c, x - iz / 2, y - iz / 2, iz, iz + 8, 10, const Color(0xBFFFFFFF));
      img.draw(c, kHuntSkills[q]!.img, x, y - 2, iz * .78, alpha: off ? .3 : 1);
      FunText.draw(c, '★' * C.skills[q]!, x, y + iz / 2 + 4, size: math.max(8, iz * .22), color: const Color(0xFFF59F00));
    }
    // Cần điều khiển ảo
    if (joyId != null) {
      fillCircle(c, joyBx, joyBy, jr, const Color(0x40FFFFFF));
      c.drawCircle(Offset(joyBx, joyBy), jr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xB3FFFFFF));
      final dx = joyX - joyBx, dy = joyY - joyBy, d = math.sqrt(dx * dx + dy * dy), m = math.min(d, jr) / (d == 0 ? 1 : d);
      fillCircle(c, joyBx + dx * m, joyBy + dy * m, jr * .45, const Color(0xD9FFFFFF));
    }
    final m = msg;
    if (m != null) FunText.draw(c, m.s, W / 2, H * .3, size: math.min(54, W * .09), color: m.c, stroke: const Color(0x66000000), strokeWidth: 6, alpha: math.min(1, m.t * 2));
  }

  void _drawCards(Canvas c) {
    final cd0 = _card!;
    c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0x9E140A3C));
    FunText.draw(c, total >= kHuntCap ? tr('ĐỒ ĐÃ MẠNH NHẤT!', 'GEAR IS MAXED!') : tr('CHỌN SỨC MẠNH!', 'PICK A POWER!'), W / 2, math.min(H * .16, 96), size: math.min(46, W * .085), color: const Color(0xFFFFD43B));
    final n = cd0.list.length, wide = W > H * 1.05, pop = math.min(1.0, cd0.t / .25);
    cd0.rects.clear();
    for (final (i, o) in cd0.list.indexed) {
      double x, y, w, hh;
      if (wide) {
        w = math.min(250, (W - 80) / 3);
        hh = math.min(H * .6, w * 1.4);
        x = W / 2 + (i - (n - 1) / 2) * (w + 24) - w / 2;
        y = H * .55 - hh / 2;
      } else {
        w = math.min(W - 40, 360);
        hh = math.min((H * .72) / 3 - 14, 170);
        x = W / 2 - w / 2;
        y = H * .22 + i * (hh + 14);
      }
      cd0.rects.add(Rect.fromLTWH(x, y, w, hh));
      final s2 = cd0.sel == i ? 1.08 : (cd0.sel >= 0 ? .9 : pop), cxm = x + w / 2, cym = y + hh / 2;
      c.save();
      c.translate(cxm, cym);
      c.scale(s2, s2);
      c.translate(-cxm, -cym);
      final dim = cd0.sel >= 0 && cd0.sel != i ? .4 : 1.0;
      final sk = kHuntSkills[o];
      final col = sk?.c ?? (o == 'coins' ? const Color(0xFFFAB005) : const Color(0xFFFF6B6B));
      fillRRect(c, x, y, w, hh, 22, Colors.white.withValues(alpha: dim));
      strokeRRect(c, x, y, w, hh, 22, col.withValues(alpha: dim), 6);
      final im = sk?.img ?? (o == 'coins' ? 'Coin' : 'Red heart');
      final name = sk != null ? (en ? sk.en : sk.vi) : (o == 'coins' ? tr('+5 xu', '+5 coins') : tr('Hồi đầy máu', 'Full health'));
      final lvNow = sk != null ? C.skills[o]! : 0;
      if (wide) {
        final iz = math.min(w * .62, hh * .48);
        img.draw(c, im, cxm, y + hh * .33, iz, rot: math.sin(cd0.t * 3 + i) * .08, alpha: dim);
        FunText.draw(c, name, cxm, y + hh * .7, size: math.min(30, w * .13), color: col, alpha: dim, fit: w - 12);
        if (sk != null) FunText.draw(c, _stars(lvNow + 1), cxm, y + hh * .87, size: math.min(30, w * .12), color: const Color(0xFFFAB005), alpha: dim);
      } else {
        final iz = hh * .72;
        img.draw(c, im, x + 16 + iz / 2, cym, iz, rot: math.sin(cd0.t * 3 + i) * .08, alpha: dim);
        FunText.draw(c, name, x + 30 + iz, cym - 4, size: math.min(30, w * .085), color: col, align: TextAlign.left, alpha: dim, fit: w - 40 - iz);
        if (sk != null) FunText.draw(c, _stars(lvNow + 1), x + 30 + iz, cym + 30, size: math.min(28, w * .07), color: const Color(0xFFFAB005), align: TextAlign.left, alpha: dim);
      }
      if (sk != null && lvNow == 0) {
        fillRRect(c, x + w - 78, y - 12, 84, 32, 16, const Color(0xFFE03131).withValues(alpha: dim));
        FunText.draw(c, tr('MỚI!', 'NEW!'), x + w - 36, y + 11, size: 20, alpha: dim);
      }
      c.restore();
    }
  }

  @override
  void paint(Canvas c) {
    _drawWorld(c);
    _drawHud(c);
    if (t < 2.8 && _card == null) {
      funLevelBanner(c, W, H, lv, tr('Sống $dur giây · Hạ ${bk.$2.toLowerCase()}', 'Survive $dur s · Defeat the ${bk.$3.toLowerCase()}'),
          tr('Kéo ngón tay để chạy · Bé tự bắn quái', 'Drag your finger to run · You shoot by yourself'), en);
    }
    if (_card != null) _drawCards(c);
    final e = end;
    if (e != null) funBanner(c, W, H, e.win ? funEnd(true, lv, en) : tr('HẾT MÁU!', 'OUT OF HEALTH!'), tr('${e.score} điểm', '${e.score} points'));
  }
}
