// ignore_for_file: non_constant_identifier_names
// Lõi chung cho game đối kháng (phần lõi của funvs1.js): chọn chế độ (máy / hai người), nhân vật hai bên,
// bảng điểm, màn mở đầu, chữ kết thúc, trời + mây, chạy-nhảy, bóng nảy, húc bóng.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';
import 'package:flutter/material.dart';

import 'act_core.dart';
import 'act_ui.dart';

const Color kBlue = Color(0xFF339AF0), kRed = Color(0xFFFA5252);

/// Kết quả một trận: winner 1 = bé (xanh), 2 = đối thủ (đỏ), 0 = hoà.
class VsEnd {
  const VsEnd(this.winner, this.score);
  final int winner, score;
}

/// Kết quả gửi khung (versus() của web).
FunResult vsResult(VsEnd r, String mode) {
  if (mode == 'pvp') {
    return FunResult(pvp: true, score: 0, win: false, title: r.winner == 1 ? '🏆 Bên XANH thắng!' : (r.winner == 2 ? '🏆 Bên ĐỎ thắng!' : '🤝 Hoà!'));
  }
  return FunResult(win: r.winner == 1, score: r.score);
}

Costume withShirt(Costume c, Color shirt) => Costume(base: c.base, shirt: shirt, pants: c.pants, hair: c.hair, hat: c.hat);

/// Lớp nền game đối kháng.
abstract class VsGame extends ActGame {
  VsGame({required this.ctx, required super.gfx, required this.mode}) : super(audio: ctx.audio, lv: ctx.level);
  final FunGameContext ctx;

  /// 'bot' | 'pvp'
  final String mode;
  bool get pvp => mode == 'pvp';
  late final List<Costume> COS = [heroOf(ctx.heroImg), pvp ? kDad : kBot];
  final Fxb F = Fxb();
  final Camera C = Camera();
  CButtons? B;
  final List<double> pops = [0, 0];

  @override
  void down(Ptr p) {
    B?.press(p);
    onDown(p);
  }

  void onDown(Ptr p) {}

  /// Bảng điểm hai bên (scoreBar).
  void scoreBar(Canvas c, int a, int b, int need) {
    fillRR(c, W / 2 - 120, 8, 240, 54, 27, rgba(0, 0, 0, .35));
    drawHead(c, W / 2 - 92, 37, 16, COS[0], face: 1);
    drawHead(c, W / 2 + 92, 37, 16, COS[1], face: -1);
    Txt.draw(c, '$a', W / 2 - 34, 47, size: (34 * (1 + bump(pops[0]) * .6)).roundToDouble(), color: hex(0x74c0fc));
    Txt.draw(c, ':', W / 2, 45, size: 34);
    Txt.draw(c, '$b', W / 2 + 34, 47, size: (34 * (1 + bump(pops[1]) * .6)).roundToDouble(), color: hex(0xff8787));
    if (need > 0) Txt.draw(c, 'Ai $need điểm trước thì thắng', W / 2, 78, size: 16, w: FontWeight.w700, stroke: rgba(0, 0, 0, .55), strokeW: 4);
  }

  void vsIntro(Canvas c, String goal, String hint) {
    if (pvp) {
      rect(c, 0, H / 2 - 80, W, 160, rgba(0, 0, 0, .4));
      Txt.draw(c, 'HAI NGƯỜI', W / 2, H / 2 - 18, size: 44, color: hex(0xffd43b));
      Txt.draw(c, '🎯 $goal', W / 2, H / 2 + 18, size: 22, w: FontWeight.w700);
      Txt.draw(c, hint, W / 2, H / 2 + 50, size: math.min(17, (W - 24) / math.max(1, hint.length) * 1.9), w: FontWeight.w600);
    } else {
      levelBanner(c, W, H, lv, goal, hint);
    }
  }

  void endVs(Canvas c, int winner, String sub) => banner(
      c,
      W,
      H,
      pvp ? (winner == 1 ? 'XANH THẮNG!' : (winner == 2 ? 'ĐỎ THẮNG!' : 'HOÀ!')) : (winner == 1 ? funEndText(true, lv) : (winner == 2 ? 'MÁY THẮNG RỒI!' : 'HOÀ!')),
      sub);

  void decay(List<double> arr, double dt, [double k = 2.5]) {
    for (var i = 0; i < arr.length; i++) {
      arr[i] = math.max(0, arr[i] - dt * k);
    }
  }

  /// Nút ◀ ▶ ⬆ hai bên (sideControls).
  CButtons sideControls(double r) {
    final by = H - r - 14;
    return CButtons(this, [
      CBtn('l1', r + 14, by, r, '◀'),
      CBtn('r1', r * 3.4 + 14, by, r, '▶'),
      CBtn('j1', r * 5.8 + 14, by, r, '⬆', kBlue),
      if (pvp) ...[
        CBtn('l2', W - r * 3.4 - 14, by, r, '◀'),
        CBtn('r2', W - r - 14, by, r, '▶'),
        CBtn('j2', W - r * 5.8 - 14, by, r, '⬆', kRed),
      ],
    ]);
  }
}

/// Trời gradient theo cảnh.
void sky(Canvas c, double w, double h, FunTheme th) => c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(th.sky[0]), Color(th.sky[1])]).createShader(Rect.fromLTWH(0, 0, w, h)));

/// Mây trôi.
void clouds(Canvas c, double w, double h, double t, [int n = 4, double y0 = .08]) {
  final col = rgba(255, 255, 255, .75);
  for (var i = 0; i < n; i++) {
    final x = ((i * w / n + t * (10 + i * 4)) % (w + 200)) - 100, y = h * (y0 + (i % 3) * .05), s = 26.0 + (i % 2) * 12;
    circle(c, x, y, s, col);
    circle(c, x + s, y - s * .4, s * .9, col);
    circle(c, x + s * 2, y, s * .8, col);
  }
}

/// Người chơi bóng (runner): tăng/giảm tốc có quán tính, bụi khi chạy đà và tiếp đất.
class Runner {
  Runner(this.x, this.y, this.w);
  double x, y, vx = 0, vy = 0, w;
}

void runStep(ActGame g, Runner p, bool l, bool r, bool j, double dt, double ground, double grav, Fxb F, {double sp = .62, double jump = 1.55}) {
  final S = g.S;
  final dir = (r ? 1 : 0) - (l ? 1 : 0), was = p.vx;
  p.vx = approach(p.vx, dir * S * sp, p.y < ground - 1 ? 4 : 12, dt);
  if (dir != 0 && was.abs() < S * .1 && p.vx.abs() >= S * .1) F.dust(p.x, ground, 3, -dir.toDouble());
  p.x += p.vx * dt;
  if (j && p.y >= ground) {
    p.vy = -S * jump;
    g.sfx('jump');
    F.dust(p.x, ground, 4);
  }
  p.vy += grav * dt;
  p.y += p.vy * dt;
  if (p.y >= ground) {
    if (p.vy > S * .6) F.dust(p.x, ground, 5);
    p.y = ground;
    p.vy = 0;
  }
}

class Ball {
  Ball(this.x, this.y, this.vx, this.vy, this.r);
  double x, y, vx, vy, r, rot = 0, sq = 0, spin = 0, born = 0;
}

/// Bóng có xoáy và dẹt khi nảy.
void drawBall(Canvas c, Gfx g, String img, Ball b, [double scale = 1]) {
  final q = b.sq, r = b.r * scale;
  c.save();
  c.translate(b.x, b.y + r * q * .5);
  c.scale(1 + q, 1 - q);
  if (g.imgs[img] != null) {
    g.draw(c, img, 0, 0, r * 2, r * 2, false, b.rot);
  } else {
    circle(c, 0, 0, r, Colors.white);
    strokeCircle(c, 0, 0, r, hex(0x212529), 2);
  }
  c.restore();
}

/// Bóng va vào đầu/thân người chơi: phản xạ theo pháp tuyến + cộng vận tốc người chơi.
bool headHit(ActGame g, Ball ball, double hx, double hy, double rr, Runner p, double minSp, double up, Fxb F) {
  final dx = ball.x - hx, dy = ball.y - hy, d = hypot(dx, dy);
  if (d >= rr || d == 0) return false;
  final nx = dx / d, ny = dy / d;
  ball.x = hx + nx * rr;
  ball.y = hy + ny * rr;
  final rvx = ball.vx - p.vx, rvy = ball.vy - p.vy, rel = rvx * nx + rvy * ny;
  if (rel < 0) {
    ball.vx -= 1.8 * rel * nx;
    ball.vy -= 1.8 * rel * ny;
  }
  ball.vx += p.vx * .5;
  ball.vy += math.min(0, p.vy) * .4;
  final sp = hypot(ball.vx, ball.vy);
  if (sp < minSp) {
    ball.vx = nx * minSp;
    ball.vy = ny * minSp;
  }
  ball.vy -= up;
  ball.sq = .25;
  ball.spin = (ball.vx - p.vx) * .02;
  g.sfx('pop');
  F.ring(hx + nx * rr * .8, hy + ny * rr * .8, 22, 0xffffff, 4);
  return true;
}

/// Widget bọc: chọn chế độ (nhớ trong vé) → tải hình → chơi → ctx.finish(kết quả).
class VsView extends StatefulWidget {
  const VsView({super.key, required this.ctx, required this.title, required this.imgs, required this.create, this.sheets = const [], this.mode});
  final FunGameContext ctx;
  final String title;
  final List<String> imgs, sheets;
  final VsGame Function(FunGameContext ctx, Gfx gfx, String mode) create;

  /// Test: bỏ qua màn chọn chế độ.
  final String? mode;
  @override
  State<VsView> createState() => _VsViewState();
}

class _VsViewState extends State<VsView> {
  late final ActSession ses = actSession(widget.ctx);
  Gfx? gfx;
  String? mode;
  VsGame? game;

  @override
  void initState() {
    super.initState();
    mode = widget.mode ?? ses.data['vs'] as String?;
    Gfx.load(widget.imgs, widget.sheets).then((g) {
      if (!mounted) return;
      setState(() {
        gfx = g;
        _maybeStart();
      });
    });
  }

  void _maybeStart() {
    if (gfx != null && mode != null && game == null) game = widget.create(widget.ctx, gfx!, mode!);
  }

  @override
  Widget build(BuildContext context) {
    if (mode == null) {
      return VsModePick(
        title: widget.title,
        level: widget.ctx.level,
        onPick: (m) {
          widget.ctx.audio.sfx('power');
          ses.data['vs'] = m;
          setState(() {
            mode = m;
            _maybeStart();
          });
        },
      );
    }
    final g = game;
    if (g == null) return const ActLoading(color: Color(0xFF74C0FC));
    return ActGameView(ctx: widget.ctx, game: g, toResult: (r) => vsResult(r as VsEnd, mode!), onResult: (r) => actSessionDone(ses, widget.ctx, r));
  }
}

/// Module đối kháng chung.
class VsModule extends FunGameModule {
  const VsModule(this.id, this.title, this.imgs, this.create, {this.sheets = const []});
  @override
  final String id;
  final String title;
  final List<String> Function(int lv) imgs;
  final List<String> sheets;
  final VsGame Function(FunGameContext ctx, Gfx gfx, String mode) create;
  @override
  Widget build(BuildContext context, FunGameContext ctx) => VsView(ctx: ctx, title: title, imgs: imgs(ctx.level), sheets: sheets, create: create);
}
