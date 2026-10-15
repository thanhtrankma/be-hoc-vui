// Phòng thú cưng (/pet): nhận nuôi, cho ăn, tắm, chơi, ngủ. Khi bé học xong một bài, khung màn chơi đã cộng p.pet.happy/xp (như web).
// CHỦ: agent D. Port của reference/web/js/games/pet.js (petScreen + adopt). Logic/vẽ phòng ở pet_sim.dart, vẽ con vật ở petrig.dart.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (PetScreen) vì router/registry trỏ tới.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'pet_sim.dart';
import 'petrig.dart';

export 'pet_sim.dart' show petTick, petOnLesson, petLevel;

class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});
  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  /// Loài đang đặt tên (bước 2 của nhận nuôi).
  PetKind? naming;

  void exit() {
    ref.read(audioProvider).sayPhrase('petWash');
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    if (p.pet != null) return _PetRoom(key: const ValueKey('pet-room'), onExit: exit);
    if (naming != null) {
      return _NamePet(
        kind: naming!,
        onBack: () => setState(() => naming = null),
        onDone: () => setState(() => naming = null),
      );
    }
    return _Adopt(onExit: exit, onPick: (k) => setState(() => naming = k)); // web: adopt() dùng chung onExit (nói 'petWash')
  }
}

// ---------- Con vật động nhỏ (thẻ nhận nuôi, màn đặt tên) ----------
class _MiniPet extends StatefulWidget {
  const _MiniPet({required this.kind, this.big = false, this.phase = 0});
  final String kind;
  final bool big;
  final double phase;
  @override
  State<_MiniPet> createState() => _MiniPetState();
}

class _MiniPetState extends State<_MiniPet> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final PetPose P = newPose();
  final ValueNotifier<double> _t = ValueNotifier(0);
  Duration _last = Duration.zero;
  final _r = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration el) {
    final dt = math.min(.05, (el - _last).inMicroseconds / 1e6);
    _last = el;
    final tt = _t.value + dt;
    if (widget.big) {
      // Màn đặt tên: ngồi vẫy đuôi, lúc lúc cười
      easePose(P, {'sit': 1, 'happy': math.sin(tt) > .3 ? 1 : 0, 'tailAmp': 1, 'tailSpeed': 16}, dt, 5);
    } else {
      // Thẻ: đi tại chỗ rồi ngồi cười
      final cyc = (tt + widget.phase) % 6;
      easePose(P, {'sit': cyc > 3.5 ? 1 : 0, 'happy': cyc > 4.5 ? 1 : 0, 'tailAmp': .8, 'tailSpeed': 12}, dt, 5);
      if (cyc < 3.5) P['phase'] = P['phase']! + dt * 9;
      P['walk'] = P['walk']! + ((cyc < 3.5 ? 1 : 0) - P['walk']!) * math.min(1, dt * 5);
    }
    if (_r.nextDouble() < dt * .3) {
      P['blink'] = 1;
    } else {
      P['blink'] = P['blink']! * .7;
    }
    _t.value = tt;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.big;
    return AspectRatio(
      aspectRatio: big ? 36 / 28 : 32 / 26,
      child: RepaintBoundary(child: CustomPaint(painter: _MiniPainter(widget.kind, P, _t, big, widget.phase))),
    );
  }
}

class _MiniPainter extends CustomPainter {
  _MiniPainter(this.kind, this.pose, this.t, this.big, this.phase) : super(repaint: t);
  final String kind;
  final PetPose pose;
  final ValueNotifier<double> t;
  final bool big;
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    // Khung gốc 320×260 (thẻ) hoặc 360×280 (màn đặt tên), co theo kích thước thật.
    final bw = big ? 360.0 : 320.0, bh = big ? 280.0 : 260.0;
    canvas.save();
    canvas.scale(size.width / bw, size.height / bh);
    drawPet(canvas, kind, bw / 2, big ? 266 : 232, pose, PetDrawOpts(u: big ? 146 : 106, t: t.value + phase));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => true;
}

// ---------- Nhận nuôi: mỗi thẻ có con vật động chạy tại chỗ ----------
class _Adopt extends ConsumerStatefulWidget {
  const _Adopt({required this.onExit, required this.onPick});
  final VoidCallback onExit;
  final ValueChanged<PetKind> onPick;
  @override
  ConsumerState<_Adopt> createState() => _AdoptState();
}

class _AdoptState extends ConsumerState<_Adopt> with SayOnOpen {
  @override
  String? get openPhrase => 'petPick';

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final data = ref.watch(appDataProvider);
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 900 ? 4 : w >= 560 ? 3 : 2;
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(leading: IconBtn(icon: AppIcon.back, onTap: widget.onExit), title: i18n.t('petAdopt')),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: .82,
          children: [
            for (final (i, k) in data.pets.indexed)
              Chunky(
                key: Key('adopt-${k.id}'),
                radius: 30,
                onTap: () => widget.onPick(k),
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: Center(child: _MiniPet(kind: k.id, phase: i * 1.3))),
                  const SizedBox(height: 6),
                  // Ô có tỉ lệ cố định: tên dài/chữ to thì thu nhỏ trên một dòng.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(i18n.L(k), maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * 1.2, color: AppColors.ink2)),
                  ),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

class _NamePet extends ConsumerStatefulWidget {
  const _NamePet({required this.kind, required this.onBack, required this.onDone});
  final PetKind kind;
  final VoidCallback onBack;
  final VoidCallback onDone;
  @override
  ConsumerState<_NamePet> createState() => _NamePetState();
}

class _NamePetState extends ConsumerState<_NamePet> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final k = widget.kind;
    _c = TextEditingController(text: k.names.isNotEmpty ? k.names.first : '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = ref.read(audioProvider);
      final v = petVoiceOf(k.id);
      audio.clip(v.talk.first, rate: v.rate).then((stop) {
        if (stop == null) audio.sfx(k.sound);
      });
      audio.say(audio.tpl('petHello', {'p': k.p}));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void adopt() {
    final name = _c.text.trim();
    if (name.isEmpty) return;
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (p == null) return;
    p.json['pet'] = <String, dynamic>{
      'type': widget.kind.id, 'name': name, 'xp': 0, 'food': 70, 'water': 70, 'clean': 80, 'happy': 80, 'energy': 90,
      'last': store.now().millisecondsSinceEpoch, 'wear': <String, dynamic>{},
    };
    store.save();
    confetti(context: context);
    ref.read(audioProvider).sfx('win');
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final k = widget.kind;
    final fs = baseFontSize(context);
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(leading: IconBtn(icon: AppIcon.back, onTap: widget.onBack), title: i18n.t('petName')),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: _MiniPet(kind: k.id, big: true)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            key: const Key('pet-name-input'),
            controller: _c,
            maxLength: 14,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w800, color: AppColors.ink),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.line, width: 3)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final n in k.names)
            Chunky(
              radius: 999,
              depth: 4,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              onTap: () {
                _c.text = n;
                ref.read(audioProvider).sfx('tap');
                setState(() {});
              },
              child: Text(n, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs, color: AppColors.ink2)),
            ),
        ]),
        const SizedBox(height: 18),
        AppButton(key: const Key('pet-adopt-btn'), icon: '❤️', label: i18n.t('petAdoptBtn'), variant: BtnVariant.green, big: true, onTap: adopt),
      ]),
    );
  }
}

// ---------- Phòng thú cưng ----------
class _PetRoom extends ConsumerStatefulWidget {
  const _PetRoom({super.key, required this.onExit});
  final VoidCallback onExit;
  @override
  ConsumerState<_PetRoom> createState() => _PetRoomState();
}

const List<String> _kActions = ['feed', 'water', 'bath', 'play', 'sleep', 'wear'];

class _PetRoomState extends ConsumerState<_PetRoom> with SingleTickerProviderStateMixin {
  late final PetSim sim;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeProvider);
    final data = ref.read(appDataProvider);
    final p = store.profile!;
    // Bảo đảm p.pet là Map<String, dynamic> thật để ghi thẳng vào hồ sơ.
    final pet = p.json['pet'] = Map<String, dynamic>.of(asMap(p.json['pet']));
    petTick(pet, store.now());
    pet['sleeping'] = false;
    final kind = data.pet(asStr(pet['type']));
    sim = PetSim(
      pet: pet,
      kind: kind,
      data: data,
      audio: ref.read(audioProvider),
      store: store,
      tr: (k) => ref.read(i18nProvider).t(k),
      onUi: () {
        if (mounted) setState(() {});
      },
      onToast: (s) {
        if (mounted) toast(s, context: context);
      },
      onConfetti: () {
        if (mounted) confetti(context: context);
      },
    );
    sim.greet();
    loadEmojiUiImages([...kPetSprites, ...kind.foods, kind.toy, ...data.petItems.map((i) => i.img)]).then((m) {
      if (mounted) sim.images = m;
    });
    _ticker = createTicker((el) {
      final dt = math.min(.05, (el - _last).inMicroseconds / 1e6);
      _last = el;
      sim.update(dt);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    final store = sim.store;
    sim.pet['last'] = store.now().millisecondsSinceEpoch;
    sim.dispose();
    // Lưu sau khi cây widget mở khoá (không gọi notifyListeners giữa lúc tháo màn).
    scheduleMicrotask(() {
      try {
        store.save();
      } catch (_) {/* store đã đóng (thoát app) */}
    });
    super.dispose();
  }

  void exit() {
    sim.alive = false;
    sim.stopPurr();
    sim.save();
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final kind = sim.kind;
    final pet = sim.pet;
    final fs = baseFontSize(context);
    // Màn thấp (điện thoại xoay ngang): không đủ chỗ cho phòng ≥ 260 + khay + nút → cuộn cả trang như web.
    final short = MediaQuery.sizeOf(context).height < 600;
    return AppScreen(
      scroll: short,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(spacing: 10, children: [
        TopBar(
          bottomGap: 0,
          leading: IconBtn(icon: AppIcon.back, onTap: exit),
          titleWidget: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${asStr(pet['name'])} '),
              TextSpan(text: '· ${i18n.t('level')} ${sim.lv}', style: TextStyle(color: const Color(0xFFE67700), fontSize: vwClamp(context, 22, 2.4, 36, 10) * .7)),
            ]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: vwClamp(context, 22, 2.4, 36, 10), fontWeight: FontWeight.w800, color: AppColors.ink2),
          ),
        ),
        _bars(context, kind),
        _fill(
          short,
          Container(
            constraints: const BoxConstraints(minHeight: 260),
            decoration: BoxDecoration(color: const Color(0xFFFFF0F6), borderRadius: BorderRadius.circular(30), boxShadow: kCardShadow),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (context, c) {
              sim.resize(c.maxWidth, c.maxHeight);
              return Listener(
                key: const Key('pet-canvas'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => sim.pointerDown(e.localPosition),
                onPointerMove: (e) => sim.pointerMove(e.localPosition, e.buttons != 0),
                onPointerUp: (_) => sim.pointerUp(),
                onPointerCancel: (_) => sim.pointerUp(),
                // RepaintBoundary: phòng vẽ lại 60 hình/giây, không kéo theo thanh chỉ số và các nút xung quanh.
                child: RepaintBoundary(child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _RoomPainter(sim))),
              );
            }),
          ),
        ),
        ConstrainedBox(constraints: const BoxConstraints(minHeight: 72), child: Center(child: _tray(context, i18n, fs))),
        _actions(context, i18n, kind),
      ]),
    );
  }

  /// Phòng chiếm phần còn lại của màn; màn thấp (đang cuộn) thì cao cố định 260 (min-height của web).
  Widget _fill(bool short, Widget child) => short ? SizedBox(height: 260, child: child) : Expanded(child: child);

  Widget _bars(BuildContext context, PetKind kind) {
    Widget bar(String icon, double v, {bool xp = false, Key? key}) {
      final low = !xp && v < 35;
      final colors = xp ? const [Color(0xFFFAB005), Color(0xFFFFD43B)] : low ? const [Color(0xFFFF6B6B), Color(0xFFFFA94D)] : const [Color(0xFF51CF66), Color(0xFF94D82D)];
      final bw = vwClamp(context, 54, 9, 90);
      return Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(color: low ? const Color(0xFFFFF0F0) : const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          EmojiImage(icon, size: 30, photo: false),
          Container(
            width: bw,
            height: 12,
            decoration: BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (v / 100).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(6))),
            ),
          ),
        ]),
      );
    }

    final pet = sim.pet;
    final xpv = sim.lv >= kPetMaxLv ? 100.0 : (asDouble(pet['xp']) % kPetXpPerLv) / kPetXpPerLv * 100;
    return Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
      for (final (k, icon, _) in kPetStats) bar(k == 'food' && kind.foods.isNotEmpty ? kind.foods.first : icon, petStat(pet, k), key: Key('pbar-$k')),
      bar('Glowing star', xpv, xp: true),
    ]);
  }

  Widget _square(BuildContext context, {required Key key, required String img, required VoidCallback onTap, bool on = false, bool locked = false, String? badge}) {
    return Chunky(
      key: key,
      onTap: onTap,
      radius: 22,
      depth: 5,
      border: on ? Border.all(color: AppColors.good, width: 4) : null,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Opacity(
            opacity: locked ? .4 : 1,
            child: ColorFiltered(
              colorFilter: locked ? const ColorFilter.matrix(_grey) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: EmojiImage(img, size: 52, photo: false),
            ),
          ),
          if (badge != null)
            Positioned(
              bottom: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(999)),
                child: Text(badge, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tray(BuildContext context, I18n i18n, double fs) {
    final kind = sim.kind;
    Widget note(String s) => Text(s, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft, fontSize: fs * .9));
    switch (sim.mode) {
      case 'feed':
        return Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          for (final f in kind.foods) _square(context, key: Key('food-$f'), img: f, onTap: () => sim.feed(f)),
        ]);
      case 'play':
        return Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _square(context, key: const Key('pet-toy'), img: kind.toy, onTap: sim.throwToy),
          note(i18n.t('petPlayTip')),
        ]);
      case 'wear':
        final w = sim.wear;
        return Wrap(spacing: 12, runSpacing: 14, alignment: WrapAlignment.center, children: [
          for (final it in sim.data.petItems)
            _square(context,
                key: Key('pwear-${it.img}'),
                img: it.img,
                on: w[it.slot] == it.img,
                locked: sim.lv < it.lv,
                badge: sim.lv < it.lv ? '🔒 ${it.lv}' : null,
                onTap: () => sim.toggleWear(it)),
        ]);
      case 'bath':
        if (sim.rinsing) return const SizedBox();
        if (sim.foamProg >= 100) {
          return AppButton(key: const Key('pet-rinse'), icon: '🚿', label: i18n.t('petRinse'), variant: BtnVariant.blue, onTap: sim.rinse);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            const EmojiImage('Sponge', size: 44, photo: false),
            Flexible(child: Text(i18n.t('petScrubTip'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs, color: AppColors.ink))),
          ]),
        );
      default:
        return note(i18n.t('petTip'));
    }
  }

  Widget _actions(BuildContext context, I18n i18n, PetKind kind) {
    final imgs = {'feed': kind.foods.isNotEmpty ? kind.foods.first : 'Bone', 'water': 'Droplet', 'bath': 'Bathtub', 'play': kind.toy, 'sleep': 'Crescent moon', 'wear': 'Ribbon'};
    final labels = {'feed': 'petFeed', 'water': 'petWater', 'bath': 'petBath', 'play': 'petPlay', 'sleep': 'petSleep', 'wear': 'petWear'};
    return Row(spacing: 8, children: [
      for (final m in _kActions)
        Expanded(
          child: Chunky(
            key: Key('pact-$m'),
            radius: 20,
            depth: 5,
            color: sim.mode == m ? const Color(0xFFFFF3BF) : Colors.white,
            shadowColor: sim.mode == m ? const Color(0xFFFFD43B) : AppColors.line,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            onTap: () => sim.action(m),
            child: Column(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
              EmojiImage(imgs[m]!, size: 44, photo: false),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(i18n.t(labels[m]!), maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * .85, color: AppColors.ink2)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

const List<double> _grey = [
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  .2126, .7152, .0722, 0, 0, //
  0, 0, 0, 1, 0,
];

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.sim) : super(repaint: sim);
  final PetSim sim;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    sim.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => old.sim != sim;
}
