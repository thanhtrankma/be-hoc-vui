// Khu vui chơi (/fun): danh sách game theo nhóm, thẻ "Nhân vật của bé" (p.look), nút bố mẹ chơi miễn phí; game Ná thần kỳ.
// CHỦ: agent E. Port của web js/games/fun.js + app.js funZone()/lookCard()/fillGrids().
// Mở game: context.go('/fun/<id>') — khung FunPlayScreen (Foundation) lo trừ vé, chơi 3 cấp/vé, bảng kết quả, kỷ lục.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';

import 'funcore.dart';

// =================================================================================================================
// Màn Khu vui chơi
// =================================================================================================================

/// Đã đọc lời chào Khu vui chơi trong phiên này (funZone.said).
bool _funIntroSaid = false;

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class FunHubScreen extends ConsumerStatefulWidget {
  const FunHubScreen({super.key});
  @override
  ConsumerState<FunHubScreen> createState() => _FunHubScreenState();
}

class _FunHubScreenState extends ConsumerState<FunHubScreen> {
  @override
  void initState() {
    super.initState();
    _applyLook();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_funIntroSaid) {
        _funIntroSaid = true;
        ref.read(audioProvider).sayPhrase('funIntro');
      }
    });
  }

  /// Nhân vật bé chọn (p.look) áp cho mọi game có nhân vật của bé (applyLook()).
  void _applyLook() {
    final p = ref.read(storeProvider).profile;
    if (p == null) return;
    setPlayer(ref.read(appDataProvider).mascot(p.mascot).img, p.look);
  }

  void _openGame(FunGameDef gm) {
    final store = ref.read(storeProvider);
    final audio = ref.read(audioProvider);
    final p = store.profile;
    if (p == null) return;
    if (!ref.read(parentFunProvider) && store.tickets(p) <= 0) {
      audio.sfx('wrong');
      audio.sayPhrase('noTicket');
      toast(ref.read(i18nProvider).t('noTicket'), context: context);
      return;
    }
    audio.sfx('tap');
    context.go('/fun/${gm.id}');
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    final i = ref.watch(i18nProvider);
    final audio = ref.read(audioProvider);
    final parentFun = ref.watch(parentFunProvider);
    if (p == null) return const SizedBox();
    final fs = baseFontSize(context);

    Widget card(FunGameDef gm, {bool hot = false}) => FunGameCard(
          key: Key('fungame-${gm.id}'),
          img: gm.img,
          title: i.L(gm),
          sub: '${i.t('level')} ${store.funLevel(p, gm.id) + 1}/$kFunMax · 🏆 ${asInt(p.best[gm.id])}',
          color: gm.colorValue,
          hot: hot,
          onTap: () => _openGame(gm),
        );

    final rpgLv = asInt(asMap(p.json['rpg'])['lv'], 1);
    final rpgCard = FunGameCard(
      key: const Key('fungame-rpg'),
      img: 'Crossed swords',
      title: i.isEn ? 'Adventure world' : 'Thế giới phiêu lưu',
      sub: i.isEn ? 'Role play · Level ${math.max(1, rpgLv)}' : 'Nhập vai · Cấp ${math.max(1, rpgLv)}',
      color: const Color(0xFF7048E8),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7048E8), Color(0xFFC2255C)]),
      hot: true,
      onTap: () {
        audio.sfx('tap');
        context.go('/rpg');
      },
    );

    final groups = <(String, List<Widget>)>[
      (i.t('funHot'), [rpgCard, for (final g in kFunGames.where((g) => g.hot)) card(g, hot: true)]),
      for (final (kind, title) in [('action', 'funAction'), ('vs', 'funVs'), ('casual', 'funCasual'), ('brain', 'funBrain')])
        (i.t(title), [for (final g in kFunGames.where((g) => g.kind == kind && !g.hot)) card(g)]),
    ];

    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(
          leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                audio.sfx('tap');
                context.go('/map');
              }),
          title: i.t('funZone'),
          trailing: Pill(key: const Key('fun-tickets'), children: [const EmojiImage('Admission tickets', size: 34, photo: false), Text('${store.tickets(p)}')]),
        ),
        Text(i.t('funHow'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft, fontSize: fs * .95)),
        const SizedBox(height: 8),
        const LookCard(),
        const SizedBox(height: 6),
        _ParentFunRow(on: parentFun),
        for (final (gi, (title, cards)) in groups.indexed)
          if (cards.isNotEmpty) ...[
            Align(alignment: Alignment.centerLeft, child: _SectionTitle(title)),
            const SizedBox(height: 12),
            FunGrid(key: Key('fungrid-$gi'), children: cards),
          ],
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 22),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xD9FFFFFF), borderRadius: BorderRadius.circular(999), boxShadow: solidShadow(AppColors.line, 4)),
        child: Text(text, style: TextStyle(fontSize: baseFontSize(context) * 1.2, fontWeight: FontWeight.w800, color: AppColors.ink2)),
      );
}

/// Nút "Bố mẹ chơi (không cần vé)" / dải "Bố mẹ đang chơi miễn phí · Thoát".
class _ParentFunRow extends ConsumerWidget {
  const _ParentFunRow({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final fs = baseFontSize(context);
    final small = TextStyle(fontWeight: FontWeight.w800, fontSize: fs * .9, color: AppColors.ink);
    if (on) {
      return Center(
        child: Container(
          key: const Key('parentfun-on'),
          padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
          decoration: BoxDecoration(color: const Color(0xFFFFF3BF), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: [
            Flexible(child: Text('👨‍👩‍👦 ${i.t('parentFunOn')}', style: small)),
            Chunky(
              key: const Key('parentfun-exit'),
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                ref.read(parentFunProvider.notifier).state = false;
              },
              depth: 3,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(i.t('exitParent'), style: small),
            ),
          ]),
        ),
      );
    }
    return Center(
      child: Chunky(
        key: const Key('parentfun-btn'),
        onTap: () async {
          ref.read(audioProvider).sfx('tap');
          if (await parentGate(context, ref)) ref.read(parentFunProvider.notifier).state = true;
        },
        depth: 4,
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text('👨‍👩‍👦 ${i.t('parentPlay')}', style: small),
      ),
    );
  }
}

/// Lưới thẻ game: số cột theo bề rộng (minmax(min(220px, 42vw), 1fr)); hàng cuối thiếu thì thẻ cuối kéo dài kín hàng
/// và chuyển sang bố cục ngang (fillGrids()).
class FunGrid extends StatelessWidget {
  const FunGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.sizeOf(context).width;
    final gap = (vw * .02).clamp(12.0, 18.0);
    return LayoutBuilder(builder: (context, box) {
      final minW = math.min(220.0, vw * .42);
      final cols = math.max(1, ((box.maxWidth + gap) / (minW + gap)).floor());
      final rows = <Widget>[];
      for (var s = 0; s < children.length; s += cols) {
        final row = children.sublist(s, math.min(children.length, s + cols));
        final missing = cols - row.length;
        rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: [
            for (final (k, c) in row.indexed)
              Expanded(
                flex: k == row.length - 1 ? missing + 1 : 1,
                child: k == row.length - 1 && missing > 0 && cols > 1 ? _Wide(child: c) : c,
              ),
          ]),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: gap, children: rows);
    });
  }
}

/// Đánh dấu thẻ kéo dài (bố cục ngang).
class _Wide extends InheritedWidget {
  const _Wide({required super.child});
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Thẻ một game (.fungame): nền màu game, hình nảy, tên, viên "Cấp x/60 · 🏆 kỷ lục".
class FunGameCard extends StatelessWidget {
  const FunGameCard({super.key, required this.img, required this.title, required this.sub, required this.color, this.gradient, this.hot = false, required this.onTap});
  final String img, title, sub;
  final Color color;
  final Gradient? gradient;
  final bool hot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = context.getInheritedWidgetOfExactType<_Wide>() != null;
    final fs = baseFontSize(context);
    final narrow = MediaQuery.sizeOf(context).width <= 480;
    final imgSize = vwClamp(context, 76, 12, 130);
    final name = Text(title,
        textAlign: wide ? TextAlign.left : TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fs * (narrow ? 1.1 : 1.35), height: 1.15, shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 2))]));
    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 14, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(sub, maxLines: 1, style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: fs * (narrow ? .75 : .85)))),
    );
    final pic = EmojiImage(img, size: imgSize, photo: false);
    final body = wide
        ? Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 16, children: [
            pic,
            Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [name, pill])),
          ])
        : Column(mainAxisSize: MainAxisSize.min, spacing: 6, children: [pic, name, pill]);
    return Chunky(
      onTap: onTap,
      color: color,
      gradient: gradient ?? RadialGradient(center: const Alignment(0, -.5), radius: .9, colors: [Color.lerp(color, Colors.white, .45)!, color], stops: const [0, .6]),
      shadowColor: const Color(0x2E000000),
      depth: 8,
      radius: 28,
      pressScale: .97,
      border: hot ? Border.all(color: const Color(0xFFFFD43B), width: 4) : null,
      padding: EdgeInsets.fromLTRB(10, hot ? 22 : 18, 10, 14),
      semanticLabel: title,
      child: Center(child: body),
    );
  }
}

/// Thẻ "Nhân vật của bé": bé trai / bé gái, màu áo, mũ. Mặc định theo linh vật (chưa có p.look). Lưu p.look.
class LookCard extends ConsumerWidget {
  const LookCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final p = store.profile;
    if (p == null) return const SizedBox();
    final i = ref.watch(i18nProvider);
    final mascotImg = ref.watch(appDataProvider).mascot(p.mascot).img;
    final lk = p.look ?? {'base': costumeOf(mascotImg).base == 'girl' ? 'girl' : 'boy'};
    final cos = lookOf(lk);
    final narrow = MediaQuery.sizeOf(context).width <= 480;
    final fs = baseFontSize(context);

    void choose(Map<String, dynamic> fields) {
      ref.read(audioProvider).sfx('tap');
      final look = {...lk, ...fields};
      store.updateProfile(p.id, {'look': look});
      setPlayer(mascotImg, look);
    }

    final sw = narrow ? 32.0 : 36.0, hb = narrow ? 42.0 : 46.0;
    return CardBox(
      key: const Key('lookcard'),
      padding: EdgeInsets.all(narrow ? 10 : 14),
      child: Row(crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center, spacing: narrow ? 10 : 14, children: [
        Container(
          decoration: BoxDecoration(gradient: const RadialGradient(center: Alignment(0, .4), colors: [Color(0xFFE7F5FF), Color(0x00E7F5FF)]), borderRadius: BorderRadius.circular(24)),
          child: FigureView(costume: cos, size: narrow ? 84 : 110, pose: 'cheer'),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            Text(i.isEn ? "${p.name}'s character" : 'Nhân vật của ${p.name}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs, color: AppColors.ink2)),
            Seg<String>(
              options: [('boy', i.isEn ? '👦 Boy' : '👦 Bé trai'), ('girl', i.isEn ? '👧 Girl' : '👧 Bé gái')],
              value: asStr(lk['base'], 'boy'),
              onPick: (v) => choose({'base': v}),
            ),
            Wrap(spacing: 10, runSpacing: 8, children: [
              for (final c in kLookShirts)
                GestureDetector(
                  key: Key('shirt-${_hex(c)}'),
                  onTap: () => choose({'shirt': _hex(c)}),
                  child: Container(
                    width: sw,
                    height: sw,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: cos.shirt == c ? AppColors.ink : AppColors.line, spreadRadius: cos.shirt == c ? 3 : 1)],
                    ),
                  ),
                ),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final hat in kLookHats)
                GestureDetector(
                  key: Key('hat-${hat ?? 'none'}'),
                  onTap: () => choose({'hat': hat}),
                  child: Container(
                    width: hb,
                    height: hb,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lk['hat'] == hat ? Colors.white : const Color(0xFFEEF3F9),
                      borderRadius: BorderRadius.circular(14),
                      border: lk['hat'] == hat ? Border.all(color: AppColors.ink, width: 3) : null,
                    ),
                    child: hat == null
                        ? Text('✖', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft, fontSize: fs))
                        : EmojiImage(hat, size: hb * .72, photo: false),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// =================================================================================================================
// Game: Ná thần kỳ (kéo – ngắm – thả, rèn độ chính xác). Không "leveled": tự chơi tối đa 3 cấp/lượt.
// =================================================================================================================

/// Game của file fun.js.
final Map<String, FunGameModule> funGames = {'sling': const SlingModule()};

class SlingModule extends FunGameModule {
  const SlingModule();
  @override
  String get id => 'sling';
  @override
  Widget build(BuildContext context, FunGameContext ctx) => _SlingRun(ctx: ctx);
}

/// Một lượt Ná: tối đa 3 cấp liên tiếp; trúng hết thì lên cấp, hết bóng thì dừng (sling()).
class _SlingRun extends StatefulWidget {
  const _SlingRun({required this.ctx});
  final FunGameContext ctx;
  @override
  State<_SlingRun> createState() => _SlingRunState();
}

class _SlingRunState extends State<_SlingRun> {
  int k = 0, total = 0;

  void _end(FunResult r) {
    final ctx = widget.ctx;
    if (!ctx.alive) return;
    total += r.score;
    if (!r.win) {
      ctx.finish(FunResult(win: k > 0, score: total, lvUp: k > 0, ups: k));
      return;
    }
    ctx.levelUp();
    if (k == 2) {
      ctx.finish(FunResult(win: true, score: total, lvUp: true, ups: 3));
      return;
    }
    setState(() => k++);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF74C0FC),
        child: FunCanvas(
          key: ValueKey(k),
          game: SlingGame(widget.ctx, level: math.min(kFunMax - 1, widget.ctx.level + k), last: k == 2),
          onEnd: _end,
        ),
      );
}

class _Target {
  _Target(this.k, this.x, this.y, this.w, this.ph) : y0 = y;
  final String k;
  final double x, y0, w;
  double y, ph;
  bool alive = true;
}

class _Wall {
  _Wall(this.x, this.y, this.w, this.h, {this.fly = false}) : y0 = y;
  final double x, w, h, y0;
  double y, ph = 0;
  final bool fly;
}

/// Một cấp Ná (slingLevel()).
class SlingGame extends FunCanvasGame {
  SlingGame(super.ctx, {required this.level, this.last = false});
  final int level;
  final bool last;
  static const tg = ['Alien monster', 'Ghost', 'Bullseye'];

  @override
  int get lv => level;
  @override
  List<String> get images => [...tg, 'Soccer ball', 'Cloud', th.sun];

  final F = FunFx();
  late double ground, ax, ay, maxPull, R, G;
  static const power = 8.2;
  // Cấp: nhiều mục tiêu hơn, di chuyển nhanh hơn, thêm tường (cấp 36+ có tường bay), ít bóng dư, đường ngắm ngắn dần.
  late final int nT = math.min(7, 3 + lv ~/ 6);
  late final bool moving = lv >= 3;
  late final double mvSp = ramp(lv, 1.2, 2.6), mvAmp = ramp(lv, .05, .1);
  final targets = <_Target>[];
  final walls = <_Wall>[];
  final clouds = <List<double>>[];
  double bx = 0, by = 0, bvx = 0, bvy = 0, bt = 0, t = 0, endT = 0;
  bool fly = false;
  Offset? drag;
  late int balls = nT + math.max(1, 3 - lv ~/ 20);
  int score = 0;
  FunResult? end;

  @override
  void init() {
    ground = H * .86;
    ax = W * .17;
    ay = ground - S * .24;
    maxPull = S * .2;
    R = S * .035;
    G = S * 1.9;
    for (var i = 0; i < nT; i++) {
      final x = W * (.52 + .4 * (i + .5) / nT) + rand(-20, 20), y = ground - rand(.08, .5) * H;
      targets.add(_Target(pick(tg), x, y, S * .1, rand(0, 6)));
    }
    if (lv >= 1) walls.add(_Wall(W * .42, ground - S * .26, S * .04, S * .26));
    if (lv >= 15) walls.add(_Wall(W * .66, ground - S * .17, S * .04, S * .17));
    if (lv >= 35) walls.add(_Wall(W * .32, ground - S * .55, S * .04, S * .16, fly: true));
    for (var i = 0; i < 4; i++) {
      clouds.add([rand(0, W), rand(20, H * .3), rand(70, 120)]);
    }
    bx = ax;
    by = ay;
  }

  /// Mục tiêu còn sống (cho kiểm thử).
  List<Offset> get aliveTargets => [for (final t in targets) if (t.alive) Offset(t.x, t.y)];
  bool get flying => fly;

  @override
  void pointerDown(Offset p, int id) {
    if (fly || end != null || balls <= 0) return;
    if ((p - Offset(ax, ay)).distance < S * .2) drag = p;
  }

  @override
  void pointerMove(Offset p, int id, bool down) {
    if (drag != null) drag = p;
  }

  Offset _pull() {
    var d = drag! - Offset(ax, ay);
    if (d.distance > maxPull) d = d * (maxPull / d.distance);
    return d;
  }

  @override
  void pointerUp(Offset p, int id) {
    if (drag == null) return;
    final d = _pull();
    drag = null;
    if (d.distance < S * .03) {
      bx = ax;
      by = ay;
      return;
    }
    bx = ax + d.dx;
    by = ay + d.dy;
    bvx = -d.dx * power;
    bvy = -d.dy * power;
    fly = true;
    bt = 0;
    balls--;
    sfx('shoot');
  }

  void _reset() {
    bx = ax;
    by = ay;
    bvx = bvy = 0;
    fly = false;
    bt = 0;
    if (targets.every((tg) => !tg.alive)) {
      end = FunResult(win: true, score: score + balls * 3);
      sfx('win');
    } else if (balls <= 0) {
      end = FunResult(win: false, score: score);
    }
  }

  @override
  FunResult? update(double dt) {
    t += dt;
    for (final c in clouds) {
      c[0] -= 12 * dt;
      if (c[0] < -120) c[0] = W + 120;
    }
    for (final tg in targets) {
      if (moving && tg.alive) {
        tg.ph += dt;
        tg.y = tg.y0 + math.sin(tg.ph * mvSp) * S * mvAmp;
      }
    }
    for (final w in walls) {
      if (w.fly) {
        w.ph += dt;
        w.y = w.y0 + math.sin(w.ph * 1.3) * S * .2;
      }
    }
    if (end != null) {
      endT += dt;
      F.update(dt);
      return endT > 2 ? end : null;
    }
    if (fly) {
      // Chia nhỏ bước để bóng nhanh không xuyên qua mục tiêu.
      for (var k = 0; k < 4; k++) {
        final d = dt / 4;
        bvy += G * d;
        bx += bvx * d;
        by += bvy * d;
        bt += d;
        for (final tg in targets) {
          if (tg.alive && (bx - tg.x).abs() < tg.w / 2 + R && (by - tg.y).abs() < tg.w / 2 + R) {
            tg.alive = false;
            score += 10;
            sfx('boom');
            F.burst(tg.x, tg.y, 22);
            F.star(tg.x, tg.y);
            F.text(tg.x, tg.y - 40, '+10', const Color(0xFFFFD43B));
          }
        }
        for (final w in walls) {
          if (bx + R > w.x && bx - R < w.x + w.w && by + R > w.y && by - R < w.y + w.h) {
            bvx = -bvx.abs() * .4;
            bx = w.x - R;
            sfx('pop');
          }
        }
        if (by + R > ground) {
          by = ground - R;
          bvy *= -.35;
          bvx *= .7;
          if (bvy.abs() < 60) bvy = 0;
        }
      }
      if (bx > W + 60 || bx < -60 || bt > 4 || (bvy == 0 && bvx.abs() < 30)) _reset();
    }
    F.update(dt);
    return null;
  }

  @override
  void paint(Canvas c) {
    funSky(c, W, ground, th.skyTop, th.skyBottom);
    img.draw(c, th.sun, W * .88, H * .14, S * .14);
    for (final cl in clouds) {
      img.draw(c, 'Cloud', cl[0], cl[1], cl[2], h: cl[2] * .6);
    }
    c.drawRect(Rect.fromLTWH(0, ground, W, H - ground), Paint()..color = th.groundColor);
    c.drawRect(Rect.fromLTWH(0, ground, W, 8), Paint()..color = th.edgeColor);
    for (final w in walls) {
      fillRRect(c, w.x, w.y, w.w, w.h, 6, const Color(0xFFA0522D));
      for (var y = w.y + 14; y < w.y + w.h; y += 22) {
        c.drawRect(Rect.fromLTWH(w.x, y, w.w, 3), Paint()..color = const Color(0x26000000));
      }
    }
    for (final tg in targets) {
      if (!tg.alive) continue;
      fillRRect(c, tg.x - tg.w * .6, tg.y + tg.w * .45, tg.w * 1.2, 12, 5, const Color(0xFFC08552));
      if (!moving) c.drawRect(Rect.fromLTWH(tg.x - 5, tg.y + tg.w * .45 + 12, 10, ground - tg.y - tg.w * .45 - 12), Paint()..color = const Color(0xFFA0522D));
      img.draw(c, tg.k, tg.x, tg.y, tg.w);
    }
    // Ná
    final wood = Paint()
      ..color = const Color(0xFF8D5524)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawPath(
        Path()
          ..moveTo(ax, ground)
          ..lineTo(ax, ay + S * .06)
          ..lineTo(ax - S * .05, ay - S * .02)
          ..moveTo(ax, ay + S * .06)
          ..lineTo(ax + S * .05, ay - S * .02),
        wood);
    var x = bx, y = by;
    if (drag != null) {
      final d = _pull();
      x = ax + d.dx;
      y = ay + d.dy;
      // Đường ngắm: dài ở cấp thấp, ngắn dần khi lên cấp.
      var px = x, py = y, vx = -d.dx * power, vy = -d.dy * power;
      final dots = math.max(6, 34 - lv * .9).round();
      for (var i = 0; i < dots; i++) {
        for (var k = 0; k < 3; k++) {
          vy += G * .012;
          px += vx * .012;
          py += vy * .012;
        }
        fillCircle(c, px, py, math.max(2, 6 - i * .15), const Color(0xF2FFFFFF));
      }
    }
    if (!fly) {
      c.drawPath(
          Path()
            ..moveTo(ax - S * .05, ay - S * .02)
            ..lineTo(x, y)
            ..lineTo(ax + S * .05, ay - S * .02),
          Paint()
            ..color = const Color(0xFF5C3D1E)
            ..strokeWidth = 5
            ..style = PaintingStyle.stroke);
    }
    if (balls > 0 || fly) img.draw(c, 'Soccer ball', x, y, R * 2.2, rot: fly ? bt * 10 : 0);
    for (var i = 0; i < balls - (fly ? 0 : 1); i++) {
      img.draw(c, 'Soccer ball', 30 + i * 30.0, ground + 30, 24);
    }
    F.draw(c);
    funHud(c, W, score: score);
    if (t < 2.5 && end == null) {
      funBanner(c, W, H, '${en ? 'LEVEL' : 'CẤP'} ${lv + 1}', tr('${funThemeName(lv)} · Bắn trúng $nT mục tiêu', '${funThemeName(lv, true)} · Hit $nT targets'));
    }
    final e = end;
    if (e != null) {
      funBanner(c, W, H, e.win ? (last ? tr('🎯 TRÚNG HẾT!', '🎯 ALL HIT!') : tr('⭐ LÊN CẤP ${math.min(kFunMax, lv + 2)}!', '⭐ LEVEL ${math.min(kFunMax, lv + 2)}!')) : tr('HẾT BÓNG!', 'OUT OF BALLS!'),
          tr('${e.score} điểm', '${e.score} points'));
    }
  }
}
