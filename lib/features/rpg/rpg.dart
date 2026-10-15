// ignore_for_file: non_constant_identifier_names
// Thế giới phiêu lưu (/rpg): làng, cửa hàng, đồng đội, chọn vùng/màn, chơi một màn (/rpg/<vùng>/<màn>), bảng kết quả.
// CHỦ: agent H. Port của reference/web/js/games/rpg.js + app.js rpgTown()/rpgPlay().
// Một nhân vật đi qua 10 vùng đất, mỗi vùng một kiểu chơi, 5 màn + 1 trùm. Cấp, kinh nghiệm, vàng, trang bị, đồng đội
// lưu ở p.rpg (cùng định dạng JSON với web). Mỗi màn tốn 1 vé (bố mẹ chơi thử: không tốn vé, không lưu).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart' show parentFunProvider;
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';

import 'rpgcore.dart';
import 'rpgzones1.dart';
import 'rpgzones2.dart';

// ---------- Dữ liệu ----------
class RpgZone {
  const RpgZone(this.id, this.vi, this.img, this.boss, this.color, this.def);
  final String id, vi, img, boss;
  final int color;
  final ZoneDef def;
}

final List<RpgZone> kZones = [
  RpgZone('forest', 'Rừng Xanh', 'Deciduous tree', 'Troll', 0xFF2F9E44, forest),
  RpgZone('sea', 'Biển Ngọc', 'Sailboat', 'Squid', 0xFF1971C2, sea),
  RpgZone('mine', 'Hang Mỏ', 'Pick', 'Spider', 0xFF795548, mine),
  RpgZone('snow', 'Xứ Tuyết', 'Snowman', 'Mammoth', 0xFF4DABF7, snow),
  RpgZone('desert', 'Sa Mạc', 'Cactus', 'Scorpion', 0xFFF08C00, desert),
  RpgZone('sky', 'Thành Mây', 'Eagle', 'Cloud with lightning', 0xFF7048E8, sky),
  RpgZone('candy', 'Rừng Kẹo', 'Lollipop', 'Spider', 0xFFE64980, candy),
  RpgZone('volcano', 'Núi Lửa', 'Volcano', 'T-Rex', 0xFFE8590C, volcano),
  RpgZone('swamp', 'Đầm Lầy Ma', 'Ghost', 'Ghost', 0xFF5F3DC4, swamp),
  RpgZone('castle', 'Lâu Đài Rồng', 'Castle', 'Dragon', 0xFFC92A2A, castle),
];

/// Cấp nên có của vùng r.
int recLevel(int r) => 1 + r * 4;

class RpgItem {
  const RpgItem(this.img, this.vi, this.cost, {this.atk = 0, this.def = 0, this.hp = 0, this.txt = '', this.spd = 0, this.gold = 0, this.crit = 0, this.regen = 0, this.xp = 0});
  final String img, vi, txt;
  final int cost, atk, def, hp;
  final double spd, gold, crit, regen, xp;
}

const List<RpgItem> kWeapons = [
  RpgItem('Wood', 'Gậy gỗ', 0),
  RpgItem('Dagger', 'Dao găm', 60, atk: 5),
  RpgItem('Bow and arrow', 'Cung tên', 200, atk: 12),
  RpgItem('Hammer', 'Búa thần', 450, atk: 20),
  RpgItem('Axe', 'Rìu chiến', 800, atk: 30),
  RpgItem('Crossed swords', 'Song kiếm', 1300, atk: 42),
  RpgItem('Trident emblem', 'Đinh ba', 2000, atk: 56),
  RpgItem('Magic wand', 'Đũa phép', 3000, atk: 72),
];
const List<RpgItem> kArmors = [
  RpgItem('Coat', 'Áo khoác', 0),
  RpgItem('Military helmet', 'Mũ sắt', 100, def: 3, hp: 20),
  RpgItem('Shield', 'Khiên', 300, def: 7, hp: 50),
  RpgItem('Martial arts uniform', 'Áo võ', 650, def: 12, hp: 90),
  RpgItem('Kimono', 'Áo choàng phép', 1100, def: 18, hp: 140),
  RpgItem('Crown', 'Vương miện', 1800, def: 26, hp: 200),
];
const List<RpgItem> kCharms = [
  RpgItem('Running shoe', 'Giày gió', 150, spd: .2, txt: 'Chạy nhanh hơn'),
  RpgItem('Four leaf clover', 'Cỏ may mắn', 250, gold: .3, txt: 'Thêm 30% vàng'),
  RpgItem('Ring', 'Nhẫn sức mạnh', 400, crit: .15, txt: 'Hay đánh chí mạng'),
  RpgItem('Nazar amulet', 'Bùa hồi máu', 650, regen: .01, txt: 'Tự hồi máu'),
  RpgItem('Sports medal', 'Huy chương', 900, xp: .3, txt: 'Thêm 30% kinh nghiệm'),
];

class RpgPet {
  const RpgPet(this.id, this.vi, this.txt, this.unlock);
  final String id, vi, txt;

  /// Vùng phải thắng trùm để mở (-1 = có sẵn).
  final int unlock;
}

const List<RpgPet> kPets = [
  RpgPet('dog', 'Cún con', 'Chạy tới cắn quái', -1),
  RpgPet('fairy', 'Mèo thần', 'Hồi máu cho bé', 2),
  RpgPet('dragon', 'Cáo lửa', 'Phun lửa vào quái', 5),
];
const int kPotionCost = 25, kMaxPot = 5, kMaxLv = 50;

class _Npc {
  const _Npc(this.c, this.wp, this.name, this.tips);
  final Costume c;
  final String? wp;
  final String name;
  final List<String> tips;
}

/// Bạn phiêu lưu trong làng (máy), nói mẹo chơi.
final List<_Npc> _npcs = [
  _Npc(kAllies[0].c, 'Magic wand', 'Bé Mây', const ['Mua vũ khí mới ở cửa hàng để đánh mạnh hơn!', 'Ở Đầm Lầy Ma, bấm 💡 để ma bị choáng.']),
  _Npc(kAllies[1].c, 'Bow and arrow', 'Bé Lá', const ['Ở Sa Mạc, ô màu đỏ là gần kho báu đó!', 'Thua thì về làng mua áo giáp rồi thử lại nhé.']),
  _Npc(kAllies[2].c, 'Dagger', 'Bé Gió', const ['Ở Xứ Tuyết, bấm 👊 khi vạch ở ô xanh để đánh thật mạnh!', 'Thấy vòng đỏ dưới đất thì chạy ra ngoài ngay!']),
  _Npc(costumeOf('Princess'), null, 'Công chúa', const ['Rồng Lửa ở cuối bản đồ. Cả làng trông cậy vào bé!', 'Ở Rừng Kẹo, chạm vào lính để nâng cấp.']),
];

// ---------- Lưu trữ (p.rpg) ----------
/// p.rpg = {lv, xp, gold, w, a, c, ownW, ownA, ownC, pet, pot, prog{vùng: số màn đã qua}} — giống web.
extension type RpgSave(Json json) {
  int get lv => asInt(json['lv'], 1);
  set lv(int v) => json['lv'] = v;
  int get xp => asInt(json['xp']);
  set xp(int v) => json['xp'] = v;
  int get gold => asInt(json['gold']);
  set gold(int v) => json['gold'] = v;
  int get w => asInt(json['w']).clamp(0, kWeapons.length - 1);
  set w(int v) => json['w'] = v;
  int get a => asInt(json['a']).clamp(0, kArmors.length - 1);
  set a(int v) => json['a'] = v;
  int? get c {
    final v = json['c'];
    if (v == null) return null;
    final i = asInt(v);
    return i >= 0 && i < kCharms.length ? i : null;
  }

  set c(int? v) => json['c'] = v;
  String? get pet => json['pet'] as String?;
  set pet(String? v) => json['pet'] = v;
  int get pot => asInt(json['pot']);
  set pot(int v) => json['pot'] = v;
  List<int> _ints(String k) {
    final v = json[k];
    if (v is List<int>) return v;
    final l = v is List ? v.map((e) => asInt(e)).toList() : <int>[];
    json[k] = l;
    return l;
  }

  List<int> get ownW => _ints('ownW');
  List<int> get ownA => _ints('ownA');
  List<int> get ownC => _ints('ownC');
  Map<String, dynamic> get prog {
    final v = json['prog'];
    if (v is Map<String, dynamic>) return v;
    final m = v is Map ? v.map((k, val) => MapEntry('$k', val)) : <String, dynamic>{};
    json['prog'] = m;
    return m;
  }

  /// Số màn đã qua của vùng r.
  int progOf(int r) => asInt(prog['$r']);
}

RpgSave rpgOf(Profile p) {
  if (p.json['rpg'] is! Map) {
    p.json['rpg'] = <String, dynamic>{
      'lv': 1,
      'xp': 0,
      'gold': 30,
      'w': 0,
      'a': 0,
      'c': null,
      'ownW': [0],
      'ownA': [0],
      'ownC': <int>[],
      'pet': 'dog',
      'pot': 2,
      'prog': <String, dynamic>{},
    };
  } else if (p.json['rpg'] is! Map<String, dynamic>) {
    p.json['rpg'] = Map<String, dynamic>.from(p.json['rpg'] as Map);
  }
  return RpgSave(p.json['rpg'] as Json);
}

int needXp(int lv) => 30 + lv * 20;

RpgStats rpgStats(RpgSave R) {
  final w = kWeapons[R.w], a = kArmors[R.a], c = R.c != null ? kCharms[R.c!] : null;
  return RpgStats(
    lv: R.lv,
    atk: 10 + R.lv * 3 + w.atk,
    def: a.def + R.lv ~/ 2,
    maxhp: 80 + R.lv * 15 + a.hp,
    spd: 1 + (c?.spd ?? 0),
    crit: .05 + (c?.crit ?? 0),
    goldMul: 1 + (c?.gold ?? 0),
    xpMul: 1 + (c?.xp ?? 0),
    regen: c?.regen ?? 0,
  );
}

bool unlockedZone(RpgSave R, int r) => r == 0 || R.progOf(r - 1) >= kStages;
bool canPlay(Profile p, int r, int s) {
  final R = rpgOf(p);
  return r >= 0 && r < kZones.length && s >= 0 && s < kStages && unlockedZone(R, r) && s <= R.progOf(r);
}

bool petOk(RpgSave R, RpgPet pt) => pt.unlock < 0 || R.progOf(pt.unlock) >= kStages;

/// Kết quả một màn đã cộng thưởng.
class StageOutcome {
  StageOutcome({required this.win, required this.gold, required this.xp, required this.kills, required this.r, required this.s});
  final bool win;
  final int gold, xp, kills, r, s;
  int ups = 0, lv = 0;
  bool cleared = false;
  RpgPet? unlocked;
}

/// Cộng thưởng sau màn (phần sau `z.run()` của playStage ở web). free = bố mẹ chơi thử: không lưu.
StageOutcome applyStage(Profile p, int r, int s, RunResult res, {bool free = false}) {
  final R = rpgOf(p), st = rpgStats(R), boss = s == kStages - 1;
  final first = res.win && s >= R.progOf(r);
  final bonusXp = res.win ? ((20 + r * 25 + s * 6) * (boss ? 3 : 1) * (first ? 1 : .5)).round() : 0;
  final bonusGold = res.win ? ((15 + r * 15) * (boss ? 3 : 1) * (first ? 1 : .5) * st.goldMul).round() : 0;
  final out = StageOutcome(win: res.win, gold: res.gold + bonusGold, xp: ((res.xp + bonusXp) * st.xpMul).round(), kills: res.kills, r: r, s: s)..lv = R.lv;
  if (free) return out;
  R.gold += out.gold;
  R.pot = res.potions;
  if (first) {
    R.prog['$r'] = s + 1;
    if (s == kStages - 1) {
      out.cleared = true;
      out.unlocked = kPets.where((pt) => pt.unlock == r).firstOrNull;
    }
  }
  R.xp += out.xp;
  while (R.lv < kMaxLv && R.xp >= needXp(R.lv)) {
    R.xp -= needXp(R.lv);
    R.lv++;
    out.ups++;
  }
  if (R.lv >= kMaxLv) R.xp = 0;
  out.lv = R.lv;
  return out;
}

/// Mua đồ trong cửa hàng: trừ vàng. false = chưa đủ vàng.
bool rpgBuy(RpgSave R, int cost, VoidCallback then) {
  if (R.gold < cost) return false;
  R.gold -= cost;
  then();
  return true;
}

/// Hình cần cho thẻ nhân vật, cửa hàng (dùng cho kiểm tra asset).
List<String> rpgAllImages() => {
      for (final z in kZones) ...[z.img, z.boss, ...z.def.imgs],
      for (final it in [...kWeapons, ...kArmors, ...kCharms]) it.img,
      ...kBaseImgs,
      'Locked', 'Admission tickets', 'Test tube', 'Trophy', 'Glowing star', 'Coin',
    }.toList();

// ---------- Làng ----------
class RpgTownScreen extends ConsumerStatefulWidget {
  const RpgTownScreen({super.key, this.quiet = false});

  /// Không đọc lời chào (quay lại từ cửa hàng...).
  final bool quiet;
  @override
  ConsumerState<RpgTownScreen> createState() => _RpgTownScreenState();
}

class _RpgTownScreenState extends ConsumerState<RpgTownScreen> {
  late final _Npc npc = _npcs[rnd.nextInt(_npcs.length)];
  late final String tip = npc.tips[rnd.nextInt(npc.tips.length)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(storeProvider).profile == null) return;
      if (!widget.quiet) ref.read(audioProvider).sayPhrase('rpgTown');
    });
  }

  AudioService get audio => ref.read(audioProvider);

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    if (p == null) return const AppScreen(child: SizedBox());
    final free = ref.watch(parentFunProvider);
    final R = rpgOf(p), st = rpgStats(R);
    final heroImg = ref.read(appDataProvider).mascot(p.mascot).img;
    setPlayer(heroImg, p.look); // trang phục bé tự chọn (applyLook của web); chỉ đặt biến, không lưu
    final fs = baseFontSize(context);
    final maxed = R.lv >= kMaxLv;
    Widget chip(Widget icon, String v, int c) => Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [icon, Text(v, style: const TextStyle(fontWeight: FontWeight.w800))]),
        );
    Widget emoji(String s) => Text(s, style: TextStyle(fontSize: fs * .95));
    final heroCard = CardBox(
      padding: const EdgeInsets.all(14),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 10, children: [
        SizedBox(
          width: 170,
          height: 160,
          child: Stack(children: [
            Positioned(left: 0, top: 0, child: FigureView(costume: heroOf(heroImg), size: 150)),
            if (R.pet != null) Positioned(right: 0, bottom: 0, child: PetView(kind: kPetRig[R.pet] ?? 'dog', size: 70)),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 8, children: [
            Row(spacing: 10, children: [
              Text('Cấp ${R.lv}', key: const Key('rpg-lv'), style: TextStyle(fontSize: fs * 1.3, fontWeight: FontWeight.w800, color: AppColors.ink2)),
              Expanded(
                child: Stack(alignment: Alignment.center, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: maxed ? 1 : (R.xp / needXp(R.lv)).clamp(0, 1).toDouble(),
                      minHeight: 22,
                      backgroundColor: const Color(0xFFE9ECEF),
                      color: const Color(0xFFFFD43B),
                    ),
                  ),
                  Text(maxed ? 'Cấp cao nhất' : '${R.xp}/${needXp(R.lv)} kinh nghiệm', style: TextStyle(fontSize: fs * .75, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              chip(emoji('❤️'), '${st.maxhp}', 0xFFFFE3E3),
              chip(emoji('⚔️'), '${st.atk}', 0xFFFFF4E6),
              chip(emoji('🛡'), '${st.def}', 0xFFE7F5FF),
              chip(const EmojiImage('Coin', size: 22, photo: false), '${R.gold}', 0xFFFFF9DB),
              chip(emoji('🧪'), '${R.pot}', 0xFFEBFBEE),
            ]),
            Wrap(spacing: 10, runSpacing: 10, children: [
              AppButton(key: const Key('rpg-shop'), icon: '🛒', label: 'Cửa hàng', variant: BtnVariant.blue, onTap: () {
                audio.sfx('tap');
                rpgShop(context, ref).then((_) => _refresh());
              }),
              AppButton(key: const Key('rpg-pets'), icon: '🐾', label: 'Đồng đội', variant: BtnVariant.ghost, onTap: () {
                audio.sfx('tap');
                rpgPetPicker(context, ref).then((_) => _refresh());
              }),
            ]),
          ]),
        ),
      ]),
    );
    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
        TopBar(
          bottomGap: 0,
          leading: IconBtn(icon: AppIcon.back, label: 'Quay lại', onTap: () => context.go('/fun')),
          title: '⚔️ Thế giới phiêu lưu',
          trailing: Pill(children: [const EmojiImage('Admission tickets', size: 28, photo: false), Text(free ? '∞' : '${store.tickets(p)}', key: const Key('rpg-tickets'))]),
        ),
        if (free) const NoteText('👨‍👩‍👦 Bố mẹ chơi thử: không tốn vé, không lưu tiến độ'),
        const RpgVillage(),
        heroCard,
        Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: 10, children: [
          FigureView(costume: npc.c, size: 76),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: kCardShadow),
              child: Text.rich(TextSpan(children: [TextSpan(text: '${npc.name}: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: tip)])),
            ),
          ),
        ]),
        const Padding(padding: EdgeInsets.only(top: 6), child: ScreenTitle('🗺️ Bản đồ thế giới')),
        LayoutBuilder(builder: (context, box) {
          final cols = math.max(2, (box.maxWidth / 180).floor());
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (var r = 0; r < kZones.length; r++) SizedBox(width: w, child: _zoneTile(R, r)),
          ]);
        }),
      ]),
    );
  }

  Widget _zoneTile(RpgSave R, int r) {
    final z = kZones[r], open = unlockedZone(R, r), done = R.progOf(r);
    final col = Color(z.color);
    return Opacity(
      opacity: open ? 1 : .55,
      child: Chunky(
        key: Key('rpg-zone-$r'),
        onTap: () {
          if (!open) {
            audio.sfx('wrong');
            toast('Thắng trùm ${kZones[r - 1].vi} để mở vùng này', context: context);
            return;
          }
          audio.sfx('tap');
          rpgStagePicker(context, ref, r);
        },
        radius: 24,
        border: Border.all(color: col, width: 3),
        shadowColor: col,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              child: Text('${r + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
          ]),
          EmojiImage(open ? z.img : 'Locked', size: 64, photo: false),
          Text(z.vi, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('Nên cấp ${recLevel(r)}', style: TextStyle(fontSize: baseFontSize(context) * .8, color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 3, children: [
            for (var s = 0; s < kStages; s++)
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s < done ? col : const Color(0xFFE9ECEF), shape: BoxShape.circle),
                child: s == kStages - 1 ? const Text('👑', style: TextStyle(fontSize: 9)) : null,
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Bảng chọn màn của vùng r.
Future<void> rpgStagePicker(BuildContext context, WidgetRef ref, int r) {
  final store = ref.read(storeProvider), audio = ref.read(audioProvider);
  final p = store.profile!, R = rpgOf(p), z = kZones[r], done = R.progOf(r);
  final free = ref.read(parentFunProvider);
  return showPanel<void>(
    context: context,
    builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 8, children: [EmojiImage(z.img, size: 56, photo: false), Flexible(child: PanelTitle(z.vi))]),
      NoteText('Cấp nên có: ${recLevel(r)} · Bé đang cấp ${R.lv}'),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (var s = 0; s < kStages; s++)
          () {
            final open = s <= done, boss = s == kStages - 1, cleared = s < done;
            return Opacity(
              opacity: open ? 1 : .5,
              child: Chunky(
                key: Key('rpg-stage-$s'),
                radius: 20,
                color: cleared ? const Color(0xFFEBFBEE) : (boss ? const Color(0xFFFFF0F6) : Colors.white),
                border: Border.all(color: boss ? const Color(0xFFE64980) : AppColors.line, width: 3),
                onTap: () {
                  if (!open) {
                    audio.sfx('wrong');
                    return;
                  }
                  if (!free && store.tickets(p) <= 0) {
                    audio.sfx('wrong');
                    audio.sayPhrase('noTicket');
                    toast('Hết vé rồi! Học thêm một bài để có vé nhé', context: c);
                    return;
                  }
                  Navigator.pop(c);
                  context.go('/rpg/$r/$s');
                },
                child: Container(
                  width: 84,
                  constraints: const BoxConstraints(minHeight: 92),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, spacing: 2, children: [
                    if (boss) EmojiImage(z.boss, size: 40, photo: false) else Text('${s + 1}', style: TextStyle(fontSize: baseFontSize(c) * 1.6, fontWeight: FontWeight.w800)),
                    Text(boss ? 'Trùm' : 'Màn ${s + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(cleared ? '✔' : (open ? '' : '🔒')),
                  ]),
                ),
              ),
            );
          }(),
      ]),
      if (!free) const NoteText('🎟️ Mỗi màn tốn 1 vé'),
      PanelRow(children: [AppButton(label: 'Đóng', variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(c))]),
    ]),
  );
}

/// Cửa hàng: vũ khí, áo giáp, bùa, bình máu.
Future<void> rpgShop(BuildContext context, WidgetRef ref) {
  final store = ref.read(storeProvider), audio = ref.read(audioProvider);
  final R = rpgOf(store.profile!);
  var tab = 'w';
  return showPanel<void>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      void buy(int cost, VoidCallback then) {
        if (!rpgBuy(R, cost, then)) {
          audio.sfx('wrong');
          toast('Chưa đủ vàng', context: c);
          return;
        }
        audio.sfx('coin');
        confetti(n: 30, context: c);
        store.save();
        set(() {});
      }

      Widget row(String key, RpgItem it, bool owned, bool using, VoidCallback onBuy, VoidCallback onUse, String stat) => Container(
            key: Key('rpg-item-$key'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: using ? const Color(0xFFEBFBEE) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: using ? const Color(0xFF51CF66) : Colors.transparent, width: 2),
            ),
            child: Row(spacing: 10, children: [
              EmojiImage(it.img, size: 48, photo: false),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.vi, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(stat, style: TextStyle(fontSize: baseFontSize(c) * .8, color: AppColors.inkSoft)),
                ]),
              ),
              if (using)
                const Text('Đang dùng', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2B8A3E)))
              else if (owned)
                _SmallBtn(
                    key: Key('rpg-use-$key'),
                    label: 'Dùng',
                    onTap: () {
                      onUse();
                      audio.sfx('tap');
                      store.save();
                      set(() {});
                    })
              else
                _SmallBtn(
                    key: Key('rpg-buy-$key'),
                    coin: true,
                    label: '${it.cost}',
                    poor: R.gold < it.cost,
                    onTap: () => buy(it.cost, () {
                          onBuy();
                          onUse();
                        })),
            ]),
          );
      final List<Widget> list = switch (tab) {
        'w' => [
            for (var i = 0; i < kWeapons.length; i++)
              row('w$i', kWeapons[i], R.ownW.contains(i), R.w == i, () => R.ownW.add(i), () => R.w = i, '⚔️ +${kWeapons[i].atk} sức đánh'),
          ],
        'a' => [
            for (var i = 0; i < kArmors.length; i++)
              row('a$i', kArmors[i], R.ownA.contains(i), R.a == i, () => R.ownA.add(i), () => R.a = i, '🛡 +${kArmors[i].def} giáp · ❤️ +${kArmors[i].hp}'),
          ],
        'c' => [
            for (var i = 0; i < kCharms.length; i++) row('c$i', kCharms[i], R.ownC.contains(i), R.c == i, () => R.ownC.add(i), () => R.c = i, kCharms[i].txt),
          ],
        _ => [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(18)),
              child: Row(spacing: 10, children: [
                const EmojiImage('Test tube', size: 48, photo: false),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bình máu (${R.pot}/$kMaxPot)', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Hồi một nửa máu khi bấm 🧪', style: TextStyle(fontSize: baseFontSize(c) * .8, color: AppColors.inkSoft)),
                  ]),
                ),
                if (R.pot >= kMaxPot)
                  const Text('Đầy túi', style: TextStyle(fontWeight: FontWeight.w700))
                else
                  _SmallBtn(key: const Key('rpg-buy-pot'), coin: true, label: '$kPotionCost', poor: R.gold < kPotionCost, onTap: () => buy(kPotionCost, () => R.pot = R.pot + 1)),
              ]),
            ),
          ],
      };
      return Column(key: const Key('rpg-shop-panel'), mainAxisSize: MainAxisSize.min, children: [
        const PanelTitle('🛒 Cửa hàng'),
        Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 6, children: [
          const EmojiImage('Coin', size: 28, photo: false),
          Text('Bé có ${R.gold} vàng', key: const Key('rpg-gold'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Seg<String>(
          options: const [('w', '⚔️ Vũ khí'), ('a', '🛡 Áo giáp'), ('c', '✨ Bùa'), ('p', '🧪 Bình máu')],
          value: tab,
          onPick: (v) {
            audio.sfx('tap');
            set(() => tab = v);
          },
        ),
        const SizedBox(height: 10),
        ...list,
        PanelRow(children: [AppButton(key: const Key('rpg-shop-done'), label: 'Xong', onTap: () => Navigator.pop(c))]),
      ]);
    }),
  );
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({super.key, required this.label, required this.onTap, this.coin = false, this.poor = false});
  final String label;
  final VoidCallback onTap;
  final bool coin, poor;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: poor ? .55 : 1,
        child: Chunky(
          onTap: onTap,
          radius: 999,
          depth: 4,
          color: coin ? const Color(0xFFFFF3BF) : const Color(0xFFE7F5FF),
          shadowColor: coin ? const Color(0xFFF5C518) : const Color(0xFF74C0FC),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
            if (coin) const EmojiImage('Coin', size: 20, photo: false),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// Chọn đồng đội.
Future<void> rpgPetPicker(BuildContext context, WidgetRef ref) {
  final store = ref.read(storeProvider), audio = ref.read(audioProvider);
  final R = rpgOf(store.profile!);
  return showPanel<void>(
    context: context,
    builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      const PanelTitle('🐾 Đồng đội'),
      const NoteText('Chọn một bạn đi phiêu lưu cùng bé'),
      const SizedBox(height: 10),
      for (final pt in kPets)
        () {
          final ok = petOk(R, pt), using = R.pet == pt.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: using ? const Color(0xFFEBFBEE) : const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(18)),
            child: Row(spacing: 10, children: [
              ok ? PetView(kind: kPetRig[pt.id] ?? 'dog', size: 64) : const EmojiImage('Locked', size: 56, photo: false),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pt.vi, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(ok ? pt.txt : 'Thắng trùm ${kZones[pt.unlock].vi} để mở', style: TextStyle(fontSize: baseFontSize(c) * .8, color: AppColors.inkSoft)),
                ]),
              ),
              if (using)
                const Text('Đang đi cùng', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2B8A3E)))
              else if (ok)
                _SmallBtn(
                    key: Key('rpg-pet-${pt.id}'),
                    label: 'Chọn',
                    onTap: () {
                      R.pet = pt.id;
                      store.save();
                      audio.sfx('tap');
                      Navigator.pop(c);
                    }),
            ]),
          );
        }(),
      PanelRow(children: [AppButton(label: 'Đóng', variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(c))]),
    ]),
  );
}

/// Cảnh làng động: lát ô Kenney Tiny Town (cỏ, đường đất, nhà, cây, hàng rào), bạn bè đi lại trên đường,
/// dừng chào rồi đi tiếp. Dừng khi rời trang (Ticker huỷ cùng widget).
class RpgVillage extends StatefulWidget {
  const RpgVillage({super.key, this.height = 190});
  final double height;
  @override
  State<RpgVillage> createState() => _RpgVillageState();
}

class _Walker {
  _Walker(this.n, this.x, this.v);
  final _Npc n;
  double x, v, pause = 0;
  bool wave = false;
}

class _RpgVillageState extends State<RpgVillage> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  RpgArt? _art;
  ui.Picture? _bg;
  double _bgW = 0, _w = 360;
  Duration _last = Duration.zero;
  late final List<_Walker> _walkers = [for (var i = 0; i < _npcs.length; i++) _Walker(_npcs[i], 60.0 + i * 140, (i.isOdd ? -1 : 1) * (38.0 + i * 7))];

  @override
  void initState() {
    super.initState();
    rpgArtLoader([for (final n in _npcs) ?n.wp], const ['kenney-tiny-town/town']).then((a) {
      if (mounted) setState(() => _art = a);
    });
    if (Motion.enabled) _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration e) {
    final dt = math.min(.05, (e - _last).inMicroseconds / 1e6);
    _last = e;
    final W = _w;
    for (final k in _walkers) {
      if (k.pause > 0) {
        k.pause -= dt;
        if (k.pause <= 0) k.v = -k.v;
      } else {
        k.x += k.v * dt;
        if (k.x < 30 || k.x > W - 30 || rnd.nextDouble() < dt * .12) {
          k.x = clamp(k.x, 30, math.max(30, W - 30));
          k.pause = 1.2 + rnd.nextDouble() * 1.5;
          k.wave = rnd.nextDouble() < .5;
        }
      }
    }
    _clock.value += dt;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    _bg?.dispose();
    super.dispose();
  }

  ui.Picture? _background(double W, double hh) {
    final T = _art?.sheets['kenney-tiny-town/town'];
    if (T == null || T.image == null) return null;
    if (_bg != null && _bgW == W) return _bg;
    _bg?.dispose();
    _bgW = W;
    return _bg = prerender(Pen(_art!), (g) {
      const ts = 38.0;
      final cols = (W / ts).ceil() + 1, rows = (hh / ts).ceil();
      var seed = 3;
      double rd() {
        seed = (seed * 9301 + 49297) % 233280;
        return seed / 233280;
      }

      void put(String fr, double x, double y, [double w = ts, double h = ts]) => g.tile(T, fr, x, y, w, h);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          put(rd() < .85 ? 't0' : (rd() < .5 ? 't1' : 't2'), x * ts, y * ts);
        }
      }
      const pathY = 3 * ts;
      for (var x = 0; x < cols; x++) {
        put(x % 3 != 0 ? 't40' : 't39', x * ts, pathY);
      }
      // Nhà mái đỏ / mái xanh xen kẽ, cây, hàng rào, giếng, tổ ong, bia tập bắn
      for (var i = 0, x = 1; x < cols - 3; i++, x += 6) {
        final red = i % 2 == 0, X = x * ts;
        put(red ? 't52' : 't48', X, 0);
        put(red ? 't53' : 't49', X + ts, 0);
        put(red ? 't54' : 't50', X + ts * 2, 0);
        put(red ? 't64' : 't60', X, ts);
        put(red ? 't65' : 't61', X + ts, ts);
        put(red ? 't66' : 't62', X + ts * 2, ts);
        put(red ? 't72' : 't76', X, ts * 2);
        put(red ? 't74' : 't78', X + ts, ts * 2);
        put(red ? 't75' : 't79', X + ts * 2, ts * 2);
        put(const ['t16', 't28', 't15', 't27'][i % 4], X + ts * 3.4, ts * 1.4, ts * 1.2, ts * 1.2);
        put(const ['t94', 't83', 't95', 't104'][i % 4], X + ts * 4.4, ts * 2);
        put('t44', X - ts * .2, ts * 4);
        put('t45', X + ts * .8, ts * 4);
        put('t45', X + ts * 1.8, ts * 4);
        put('t46', X + ts * 2.8, ts * 4);
        put(const ['t29', 't17', 't5'][i % 3], X + ts * 4.2, ts * 4.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        _w = box.maxWidth.isFinite ? box.maxWidth : 360;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 4))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              key: const Key('rpg-village'),
              size: Size(_w, widget.height),
              painter: _VillagePainter(this),
            ),
          ),
        );
      });
}

class _VillagePainter extends CustomPainter {
  _VillagePainter(this.s) : super(repaint: s._clock);
  final _RpgVillageState s;
  @override
  void paint(Canvas canvas, Size size) {
    final bg = s._background(size.width, size.height);
    if (bg != null) {
      canvas.drawPicture(bg);
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF8CE99A));
    }
    const feet = 3 * 38.0 + 34;
    final t = s._clock.value;
    final ws = [...s._walkers]..sort((a, b) => a.x.compareTo(b.x));
    for (var i = 0; i < ws.length; i++) {
      final k = ws[i];
      drawFigure(canvas, k.x, feet + (i % 2) * 6, 64, k.n.c,
          pose: k.pause > 0 ? (k.wave ? 'cheer' : 'idle') : 'run', t: t * (k.pause > 0 ? 1 : .7) + i, face: k.v > 0 ? 1 : -1, weaponImage: k.n.wp == null ? null : s._art?.imgs[k.n.wp]);
    }
  }

  @override
  bool shouldRepaint(covariant _VillagePainter old) => true;
}

// ---------- Chơi một màn ----------
/// Một màn RPG (`/rpg/<vùng>/<màn>`): trừ vé (trừ khi bố mẹ chơi), chơi, bảng kết quả.
class RpgStageScreen extends ConsumerStatefulWidget {
  const RpgStageScreen({super.key, required this.zone, required this.stage});
  final int zone;
  final int stage;

  /// Test: nhận màn vừa tạo (để điều khiển/thắng ngay).
  @visibleForTesting
  static void Function(RpgStage stage)? debugOnStage;

  @override
  ConsumerState<RpgStageScreen> createState() => _RpgStageScreenState();
}

class _RpgStageScreenState extends ConsumerState<RpgStageScreen> {
  bool free = false, alive = true;
  int run = 0;
  ZoneCtx? Z;
  RpgArt? art;
  RpgFlame? game;

  int get r => widget.zone;
  int get s => widget.stage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  AudioService get audio => ref.read(audioProvider);

  Future<void> _start() async {
    if (!mounted) return;
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (p == null || !store.funOn) {
      context.go('/map');
      return;
    }
    free = ref.read(parentFunProvider);
    final valid = r >= 0 && r < kZones.length && s >= 0 && s < kStages;
    if (!valid || (!free && !canPlay(p, r, s))) {
      context.go('/rpg');
      return;
    }
    if (!free && !store.useTicket()) {
      audio.sayPhrase('noTicket');
      context.go('/rpg');
      return;
    }
    final heroImg = ref.read(appDataProvider).mascot(p.mascot).img;
    setPlayer(heroImg, p.look);
    final R = rpgOf(p), st = rpgStats(R), z = kZones[r];
    final ctx = ZoneCtx(st: st, heroImg: heroImg, weaponImg: kWeapons[R.w].img, pet: R.pet, potions: R.pot, r: r, s: s);
    audio.sayPhrase(ctx.boss ? 'rpgBoss' : 'rpgZ$r');
    final myRun = ++run;
    final a = await rpgArtLoader([heroImg, ctx.weaponImg, ...kBaseImgs, ...z.def.imgs], kRpgSheets);
    if (!mounted || myRun != run) return;
    setState(() {
      Z = ctx;
      art = a;
      game = null;
    });
  }

  RpgFlame _makeGame(Size size) {
    final W = math.max(320.0, size.width), H = math.max(320.0, size.height);
    final stage = kZones[r].def.make(Z!, art!, W, H, audio);
    RpgStageScreen.debugOnStage?.call(stage);
    final myRun = run;
    return RpgFlame(stage, (res) => WidgetsBinding.instance.addPostFrameCallback((_) => _done(res, myRun)));
  }

  void _done(RunResult res, int myRun) {
    if (!mounted || !alive || myRun != run) return;
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (p == null) return;
    final out = applyStage(p, r, s, res, free: free);
    if (!free) store.save();
    _result(out);
  }

  void _quit() {
    alive = false;
    audio.stopVoice();
    context.go('/rpg');
  }

  /// Chơi lại cùng màn (đường dẫn không đổi nên tự dựng lại).
  void _restart() {
    setState(() {
      game?.stage.dispose();
      game = null;
      art = null;
      Z = null;
    });
    _start();
  }

  void _result(StageOutcome res) {
    final store = ref.read(storeProvider);
    final p = store.profile!;
    final z = kZones[res.r];
    if (res.win) {
      audio.sfx('win');
      confetti(context: context);
      audio.sayPhrase(res.cleared ? 'rpgClear' : (res.ups > 0 ? 'rpgLevelUp' : 'youWin'));
    } else {
      audio.sayPhrase('rpgLose');
    }
    final nextS = res.win ? res.s + 1 : res.s, nextR = nextS >= kStages ? res.r + 1 : res.r, nS = nextS >= kStages ? 0 : nextS;
    final canNext = nextR < kZones.length && (free || canPlay(p, nextR, nS));
    final hasTicket = free || store.tickets(p) > 0;
    final fs = baseFontSize(context);
    showPanel<void>(
      context: context,
      builder: (c) => Column(key: const Key('rpg-result'), mainAxisSize: MainAxisSize.min, children: [
        PanelTitle(res.win ? (res.cleared ? '👑 Giải cứu ${z.vi}!' : '🏆 Chiến thắng!') : '💫 Hết máu rồi!'),
        Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            const EmojiImage('Coin', size: 40, photo: false),
            Text('+${res.gold}', style: TextStyle(fontSize: fs * 1.5, fontWeight: FontWeight.w800)),
          ]),
          Text('⭐ +${res.xp} kinh nghiệm', style: TextStyle(fontSize: fs * 1.2, fontWeight: FontWeight.w800)),
        ]),
        if (res.ups > 0 && !free) Prize(img: 'Glowing star', text: 'Lên cấp ${res.lv}! Mạnh hơn rồi đó'),
        if (res.unlocked != null && !free)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.prize, borderRadius: BorderRadius.circular(24)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 14, children: [
              PetView(kind: kPetRig[res.unlocked!.id] ?? 'dog', size: 76),
              Flexible(child: Text('Mở khoá đồng đội: ${res.unlocked!.vi}!', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
        if (res.cleared && nextR < kZones.length && !free) Prize(img: kZones[nextR].img, text: 'Mở vùng mới: ${kZones[nextR].vi}'),
        if (res.cleared && nextR >= kZones.length && !free) const Prize(img: 'Trophy', text: 'Bé đã đánh bại Rồng Lửa! Anh hùng của cả làng!'),
        if (!res.win) const NoteText('Về làng mua vũ khí, áo giáp hoặc bình máu rồi thử lại nhé!'),
        if (free) const NoteText('👨‍👩‍👦 Bố mẹ chơi thử nên không lưu'),
        PanelRow(children: [
          AppButton(key: const Key('rpg-home'), icon: '🏘️', label: 'Về làng', variant: BtnVariant.ghostPanel, onTap: () {
            Navigator.pop(c);
            alive = false;
            context.go('/rpg');
          }),
          if (canNext && hasTicket)
            AppButton(
              key: const Key('rpg-next'),
              icon: res.win ? '▶' : '🔄',
              label: '${res.win ? 'Màn tiếp' : 'Thử lại'}${free ? '' : ' (🎟️ 1)'}',
              variant: BtnVariant.blue,
              onTap: () {
                Navigator.pop(c);
                if (nextR == r && nS == s) {
                  _restart();
                } else {
                  context.go('/rpg/$nextR/$nS');
                }
              },
            )
          else if (!hasTicket)
            AppButton(icon: '📚', label: 'Học để có vé', variant: BtnVariant.green, onTap: () {
              Navigator.pop(c);
              alive = false;
              context.go('/map');
            }),
        ]),
      ]),
    );
  }

  @override
  void dispose() {
    alive = false;
    run++;
    game?.stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = Z != null && art != null;
    return Scaffold(
      backgroundColor: const Color(0xFF101228),
      body: Stack(fit: StackFit.expand, children: [
        if (ready)
          SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final g = game ??= _makeGame(box.biggest);
              return RpgGameView(key: ValueKey('rpg-game-$run'), game: g);
            }),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconBtn(key: const Key('rpg-quit'), icon: AppIcon.close, size: 48, label: 'Đóng', onTap: _quit),
            ),
          ),
        ),
      ]),
    );
  }
}
