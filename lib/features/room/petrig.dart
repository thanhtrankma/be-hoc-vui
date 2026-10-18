// Khung xương thú cưng (vẽ thú có tư thế).
// CHỦ: agent D. Port của web js/games/petrig.js.
//
// Vẽ thú cưng động bằng Canvas (cún, mèo, thỏ, hamster, gấu trúc, cáo): thân, chân bước theo nhịp, đầu, tai, đuôi, mắt chớp.
// Gốc toạ độ là điểm giữa hai chân trên mặt đất; u = chiều dài thân (px). Hướng mặt sang phải, f = -1 thì lật.
// Tư thế (pose) là các số 0..1 được làm mượt dần để chuyển động tự nhiên.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:be_vui_hoc/core/ui/sprite_sheet.dart' show drawImageCentered;

/// Hình dáng một loài (kiểu chibi: đầu to, thân tròn ngắn, chân ngắn, mắt to long lanh).
class PetSpecies {
  const PetSpecies({
    required this.len,
    required this.bh,
    required this.leg,
    required this.lw,
    required this.hr,
    required this.head,
    required this.ears,
    required this.tail,
    required this.c,
    required this.dark,
    required this.belly,
    required this.ear,
    required this.nose,
    required this.inner,
    this.line,
    this.patch,
    this.legC,
    this.muzzle = false,
    this.stripes = false,
    this.bigFeet = false,
    this.cheeks = false,
    this.panda = false,
    this.mask = false,
  });
  final double len, bh, leg, lw, hr;
  final (double, double) head;

  /// floppy | pointy | long | round
  final String ears;

  /// wag | long | puff | none | fluffy
  final String tail;
  final Color c, dark, belly, ear, nose, inner;
  final Color? line, patch, legC;
  final bool muzzle, stripes, bigFeet, cheeks, panda, mask;
}

const Map<String, PetSpecies> kPetSpecies = {
  'dog': PetSpecies(len: .86, bh: .56, leg: .27, lw: .17, hr: .6, head: (.4, -.62), ears: 'floppy', tail: 'wag', muzzle: true,
      c: Color(0xFFF2C27E), dark: Color(0xFFD79A52), belly: Color(0xFFFFF6E8), ear: Color(0xFFB8773A), nose: Color(0xFF3B2A20), inner: Color(0xFFF5C6A5), patch: Color(0xFFE0A35E)),
  'cat': PetSpecies(len: .82, bh: .54, leg: .26, lw: .15, hr: .58, head: (.4, -.62), ears: 'pointy', tail: 'long', stripes: true,
      c: Color(0xFFF7B46A), dark: Color(0xFFE08B43), belly: Color(0xFFFFF3E3), ear: Color(0xFFE08B43), nose: Color(0xFFFF8FA3), inner: Color(0xFFFFC2CC)),
  'rabbit': PetSpecies(len: .76, bh: .6, leg: .2, lw: .17, hr: .56, head: (.36, -.6), ears: 'long', tail: 'puff', bigFeet: true,
      c: Color(0xFFFBFBFD), dark: Color(0xFFDDE2EA), belly: Color(0xFFFFFFFF), ear: Color(0xFFEEF0F4), line: Color(0x4D5A6478), nose: Color(0xFFFF8FA3), inner: Color(0xFFFFC9D6)),
  'hamster': PetSpecies(len: .74, bh: .66, leg: .12, lw: .13, hr: .54, head: (.3, -.42), ears: 'round', tail: 'none', cheeks: true,
      c: Color(0xFFF5BF6B), dark: Color(0xFFDC9A3C), belly: Color(0xFFFFF8E8), ear: Color(0xFFE7A24A), nose: Color(0xFFFF8FA3), inner: Color(0xFFFFC9B0)),
  'panda': PetSpecies(len: .8, bh: .6, leg: .22, lw: .19, hr: .6, head: (.36, -.6), ears: 'round', tail: 'puff', panda: true, legC: Color(0xFF2F2F38),
      c: Color(0xFFFDFDFD), dark: Color(0xFF2F2F38), belly: Color(0xFFFFFFFF), ear: Color(0xFF2F2F38), line: Color(0x403C3C50), nose: Color(0xFF2F2F38), inner: Color(0xFF55556A)),
  'fox': PetSpecies(len: .84, bh: .54, leg: .26, lw: .15, hr: .58, head: (.4, -.62), ears: 'pointy', tail: 'fluffy', muzzle: true, mask: true,
      c: Color(0xFFFB8C3C), dark: Color(0xFFE26A1C), belly: Color(0xFFFFF6EC), ear: Color(0xFFE26A1C), nose: Color(0xFF3B2A20), inner: Color(0xFFFFF0E0)),
};

/// Tư thế: các khoá như web (walk, phase, sit, lie, dip, jump, roll, shake, mouth, tongue, eye, happy, sad, lookX, lookY,
/// headRot, tailAmp, tailSpeed, earUp, blink, squash, crouch, sleep, bath).
typedef PetPose = Map<String, double>;

PetPose newPose() => {
      'walk': 0, 'phase': 0, 'sit': 0, 'lie': 0, 'dip': 0, 'jump': 0, 'roll': 0, 'shake': 0, 'mouth': 0, 'tongue': 0, 'eye': 1, 'happy': 0, 'sad': 0,
      'lookX': 0, 'lookY': 0, 'headRot': 0, 'tailAmp': .4, 'tailSpeed': 6, 'earUp': 0, 'blink': 0, 'squash': 0, 'crouch': 0, 'sleep': 0, 'bath': 0,
    };

/// Làm mượt tư thế về đích (target chỉ cần các khoá muốn đổi).
void easePose(PetPose p, Map<String, double> target, double dt, [double speed = 8]) {
  final k = math.min(1.0, dt * speed);
  target.forEach((key, v) {
    final cur = p[key] ?? 0;
    p[key] = cur + (v - cur) * k;
  });
}

/// Đồ thú cưng đeo: slot (hat | eyes | neck) → tên hình.
class PetDrawOpts {
  const PetDrawOpts({required this.u, required this.t, this.f = 1, this.dirty = 0, this.foam = const [], this.wear = const {}, this.images = const {}});
  final double u;
  final double t;
  final double f;
  final double dirty;

  /// Bọt xà phòng [x, y, r] theo toạ độ thân.
  final List<List<double>> foam;
  final Map<String, String> wear;

  /// Ảnh emoji đã tải (đồ đeo).
  final Map<String, ui.Image> images;
}

/// Điểm neo (toạ độ màn hình) để gắn hiệu ứng.
class PetAnchors {
  const PetAnchors({required this.head, required this.top, required this.mouth, required this.body, required this.hr, required this.len});
  final Offset head, top, mouth, body;
  final double hr, len;
}

Path _ellPath(double x, double y, double rx, double ry, [double rot = 0]) {
  final r = Rect.fromCenter(center: Offset.zero, width: math.max(.1, rx) * 2, height: math.max(.1, ry) * 2);
  final p = Path()..addOval(r);
  final c = math.cos(rot), s = math.sin(rot);
  return p.transform(Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, x, y, 0, 1]));
}

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

Paint _shade(double x, double y, double r, Color c, [Color light = const Color(0x8CFFFFFF)]) => Paint()
  ..shader = ui.Gradient.radial(
    Offset(x, y),
    r * 1.15,
    [Color.alphaBlend(light, c), c, c],
    [0, .45, 1],
    TileMode.clamp,
    null,
    Offset(x - r * .35, y - r * .45),
    r * .1,
  );

void _ell(Canvas cv, Paint p, double x, double y, double rx, double ry, [double rot = 0]) => cv.drawPath(_ellPath(x, y, rx, ry, rot), p);

// Chân: đùi từ hông xuống bàn chân, đầu gối cong ra sau khi chân ngắn hơn khoảng cách.
void _leg(Canvas cv, double hx, double hy, double px, double py, double l, double w, Color color, Color paw, bool back) {
  final d = math.sqrt((px - hx) * (px - hx) + (py - hy) * (py - hy));
  final bend = d < l ? math.sqrt(l * l - d * d) * .5 * (back ? 1 : -1) : 0.0;
  final mx = (hx + px) / 2 + bend, my = (hy + py) / 2;
  cv.drawPath(Path()
    ..moveTo(hx, hy)
    ..quadraticBezierTo(mx, my, px, py), _stroke(color, w));
  _ell(cv, _fill(paw), px + w * .18, py - w * .12, w * .62, w * .42);
}

/// Vẽ thú cưng tại (x, y). Trả về các điểm neo (toạ độ màn hình): head, mouth, body, top.
PetAnchors drawPet(Canvas cv, String kind, double x, double y, PetPose pp, PetDrawOpts o) {
  final s = kPetSpecies[kind] ?? kPetSpecies['dog']!;
  double p(String k) => pp[k] ?? 0;
  final u = o.u, t = o.t, f = o.f;
  final len = s.len * u, bh = s.bh * u, L = s.leg * u, lw = s.lw * u, hr = s.hr * u;
  cv.save();
  cv.translate(x, y);
  // Bóng đổ
  final air = p('jump') * u * .9;
  _ell(cv, _fill(Color.fromRGBO(0, 0, 0, .18 - math.min(.1, air / u * .1))), 0, 0, len * .62 * (1 - math.min(.4, air / u * .3)), u * .09);
  cv.scale(f, 1);
  // Lắc mình (sau khi tắm) và lăn tròn
  if (p('shake') > .01) cv.rotate(math.sin(t * 38) * .12 * p('shake'));
  final breathe = math.sin(t * (p('sleep') > .5 ? 1.6 : 3)) * .025;
  final stepBob = (math.sin(p('phase'))).abs() * u * .05 * p('walk');
  final sitDrop = p('sit') * L * .55, lieDrop = p('lie') * L * .92, crouchDrop = p('crouch') * L * .4;
  final bodyBase = L + bh * .42;
  final tilt = -p('sit') * .5 + p('crouch') * .08;
  // Tâm thân (toạ độ cục bộ, y âm là lên)
  final cy = -bodyBase + sitDrop + lieDrop + crouchDrop - air - stepBob + p('squash') * u * .06;
  final piv = Offset(-len * .38, bh * .38);
  Offset tr(double lx, double ly) {
    final rx = lx - piv.dx, ry = ly - piv.dy, c = math.cos(tilt), sn = math.sin(tilt);
    return Offset(rx * c - ry * sn + piv.dx, rx * sn + ry * c + piv.dy + cy);
  }

  if (p('roll') > .001) {
    cv.translate(0, cy);
    cv.rotate(p('roll') * math.pi * 2);
    cv.translate(0, -cy);
  }

  // Nhịp bước: chéo cặp (trước trái + sau phải).
  final stride = len * .22 * p('walk'), lift = L * .3 * p('walk');
  Offset footPos(Offset hip, double off) {
    final ph = p('phase') + off;
    final gx = hip.dx + math.sin(ph) * stride;
    var gy = -math.max(0, math.cos(ph)) * lift;
    // Chân không với tới đất (đang nhảy) thì buông thõng.
    final maxY = hip.dy + L * .98;
    if (gy > maxY) gy = maxY;
    return Offset(gx, math.min(gy, maxY));
  }

  final hipF = tr(len * .3, bh * .2), hipB = tr(-len * .3, bh * .2);
  final lying = p('lie') > .5 || p('bath') > .5;

  // --- Đuôi (sau thân) ---
  final tailBase = tr(-len * .47, -bh * .1);
  final wag = math.sin(t * p('tailSpeed')) * p('tailAmp');
  if (s.tail == 'wag') {
    final a = -1.1 + wag * .9 - p('sad') * .9;
    cv.drawPath(
        Path()
          ..moveTo(tailBase.dx, tailBase.dy)
          ..quadraticBezierTo(tailBase.dx - u * .18, tailBase.dy - u * .05, tailBase.dx + math.cos(math.pi + a) * u * .32,
              tailBase.dy + math.sin(math.pi + a) * u * .32 - u * .05),
        _stroke(s.c, lw * .75));
  } else if (s.tail == 'fluffy') {
    final sw = math.sin(t * 2.4) * .25 + wag * .5;
    cv.save();
    cv.translate(tailBase.dx, tailBase.dy);
    cv.rotate(-.5 + sw - p('sad') * .6);
    _ell(cv, _fill(s.c), -u * .26, -u * .02, u * .3, u * .14);
    _ell(cv, _fill(const Color(0xFFFFFFFF)), -u * .48, -u * .02, u * .1, u * .09);
    cv.restore();
  } else if (s.tail == 'long') {
    final sw = math.sin(t * 2.2) * .5 + wag * .4;
    final ex = tailBase.dx - u * .42, ey = tailBase.dy - u * (.35 - p('sad') * .4) + (p('lie') * u * .3);
    cv.drawPath(
        Path()
          ..moveTo(tailBase.dx, tailBase.dy)
          ..cubicTo(tailBase.dx - u * .3, tailBase.dy + u * .05, ex + sw * u * .25, ey + u * .25, ex + sw * u * .15, ey),
        _stroke(s.c, lw * .7));
    cv.drawCircle(Offset(ex + sw * u * .15, ey), lw * .05, _stroke(s.dark, lw * .72));
  }

  // --- Chân phía xa (tối hơn) ---
  final far = s.dark, near = s.legC ?? s.c, pawC = s.legC != null ? const Color(0xFF55556A) : s.belly;
  if (!lying && p('bath') < .3) {
    final hb = Offset(hipB.dx + u * .04, hipB.dy);
    if (p('sit') < .5) {
      final fp = footPos(hb, math.pi);
      _leg(cv, hb.dx, hb.dy, fp.dx, fp.dy, L, lw, far, far, true);
    }
    final hf = Offset(hipF.dx + u * .04, hipF.dy);
    final fp = footPos(hf, 0);
    _leg(cv, hf.dx, hf.dy, fp.dx, fp.dy, L, lw, far, far, false);
  }

  // --- Thân ---
  cv.save();
  cv.translate(piv.dx, piv.dy + cy);
  cv.rotate(tilt);
  cv.translate(-piv.dx, -piv.dy);
  final bodyW = len * .54 * (1 + breathe), bodyH = bh * .52 * (1 - breathe * .5) * (1 - p('squash') * .15);
  final bodyPath = _ellPath(0, 0, bodyW, bodyH);
  cv.drawPath(bodyPath, _shade(0, 0, bodyW, s.c));
  cv.drawPath(bodyPath, _stroke(s.line ?? const Color(0x1A000000), 2.5));
  _ell(cv, _fill(s.belly), len * .05, bodyH * .45, bodyW * .62, bodyH * .45);
  if (s.stripes) {
    for (var k = -2; k <= 1; k++) {
      cv.drawPath(
          Path()
            ..moveTo(k * len * .14, -bodyH * .95)
            ..quadraticBezierTo(k * len * .14 + len * .04, -bodyH * .5, k * len * .14 - len * .02, -bodyH * .2),
          _stroke(s.dark, lw * .3));
    }
  }
  if (s.patch != null) _ell(cv, _fill(s.patch!), -len * .12, -bodyH * .45, bodyW * .32, bodyH * .4, .3);
  if (s.tail == 'puff') {
    final pp2 = _ellPath(-bodyW * .95, -bodyH * .15, u * .11, u * .11);
    cv.drawPath(pp2, _fill(const Color(0xFFFFFFFF)));
    cv.drawPath(pp2, _stroke(const Color(0x0F000000), 2.5));
  }
  // Bẩn: vết bùn
  if (o.dirty > 0) {
    final mud = _fill(Color.fromRGBO(120, 78, 40, .55 * o.dirty.clamp(0, 1)));
    for (final (dx, dy, r) in const [(-.25, -.2, .09), (.15, -.35, .07), (.05, .1, .08), (-.35, .15, .06), (.3, 0.0, .05)]) {
      _ell(cv, mud, dx * len, dy * bh, r * u, r * u * .8);
    }
  }
  // Đùi sau khi ngồi / nằm
  if (p('sit') > .4 || lying) {
    _ell(cv, _shade(-len * .28, bodyH * .35, u * .2, s.c), -len * .26, bodyH * .4, u * .2, u * .16);
    _ell(cv, _fill(pawC), -len * .1, bodyH * .95, lw * .7, lw * .4);
  }
  // Bọt xà phòng
  for (final fo in o.foam) {
    final fp = _ellPath(fo[0] * len, fo[1] * bh, fo[2] * u, fo[2] * u);
    cv.drawPath(fp, _fill(const Color(0xEBFFFFFF)));
    cv.drawPath(fp, _stroke(const Color(0xCCA5D8FF), 2));
  }
  cv.restore();
  final bodyA = tr(0, -bh * .1);

  // --- Chân phía gần ---
  if (!lying && p('bath') < .3) {
    if (p('sit') < .5) {
      final fp = footPos(hipB, 0);
      _leg(cv, hipB.dx, hipB.dy, fp.dx, fp.dy, L, lw, near, pawC, true);
    }
    final fp2 = footPos(hipF, math.pi);
    _leg(cv, hipF.dx, hipF.dy, fp2.dx, fp2.dy, L, lw, near, pawC, false);
    if (s.bigFeet && p('sit') < .5) {
      final fp = footPos(hipB, 0);
      _ell(cv, _fill(pawC), fp.dx + lw * .3, fp.dy - lw * .1, lw * .9, lw * .38);
    }
  } else if (lying && p('bath') < .3) {
    // Nằm: hai chân trước duỗi ra phía trước
    final base = tr(len * .32, bh * .5);
    _ell(cv, _fill(s.c), base.dx + u * .12, -lw * .45, u * .16, lw * .5);
    _ell(cv, _fill(pawC), base.dx + u * .27, -lw * .4, lw * .55, lw * .45);
  }

  // --- Đầu ---
  final h0 = tr(s.head.$1 * len, s.head.$2 * bh * 1.4 - bh * .1);
  var hx = h0.dx, hy = h0.dy;
  // Cúi đầu ăn/uống: đầu hạ sát đất phía trước
  hx += p('dip') * u * .18;
  hy += p('dip') * ((-hr * .75) - hy);
  if (lying) hy += p('sleep') * hr * .35;
  hy += math.sin(t * 3) * u * .008 + p('sad') * hr * .15;
  final hrot = p('headRot') + tilt * .4 + p('sad') * .15 - p('dip') * .25;
  cv.save();
  cv.translate(hx, hy);
  cv.rotate(hrot);
  // Tai phía xa
  final earFlap = math.sin(t * 9) * .15 * p('walk') + p('earUp') * .4;
  _drawEar(cv, s, hr, t, pp, earFlap, true);
  // Mặt
  final face = _ellPath(0, 0, hr * (s.cheeks ? 1.08 : 1), hr * .95);
  cv.drawPath(face, _shade(0, 0, hr, s.c));
  cv.drawPath(face, _stroke(s.line ?? const Color(0x1A000000), 2.5));
  if (s.stripes) {
    for (final dx in const [-.25, 0.0, .25]) {
      cv.drawLine(Offset(dx * hr, -hr * .92), Offset(dx * hr * 1.1, -hr * .62), _stroke(s.dark, hr * .08));
    }
  }
  if (s.patch != null) _ell(cv, _fill(s.patch!), -hr * .42, -hr * .38, hr * .3, hr * .28, -.3);
  // Má phúng phính (hamster) và má hồng
  if (s.cheeks) _ell(cv, _fill(s.belly), hr * .45, hr * .35, hr * .45, hr * .38);
  final blush = _fill(const Color(0x66FF6E8C));
  _ell(cv, blush, hr * .74, hr * .22, hr * .14, hr * .09);
  _ell(cv, blush, -hr * .14, hr * .24, hr * .13, hr * .085);
  // Mõm
  final mz = s.muzzle ? Offset(hr * .66, hr * .34) : Offset(hr * .6, hr * .26);
  if (s.mask) _ell(cv, _fill(s.belly), hr * .45, hr * .38, hr * .52, hr * .42);
  if (s.muzzle) _ell(cv, _fill(s.belly), hr * .64, hr * .34, hr * .3, hr * .22);
  if (s.panda) {
    final dk = _fill(const Color(0xFF2F2F38));
    _ell(cv, dk, -hr * .02, -hr * .02, hr * .25, hr * .3, .5);
    _ell(cv, dk, hr * .5, 0, hr * .25, hr * .3, -.4);
  }
  // Miệng mở (ăn, sủa, kêu)
  final mouth = p('mouth');
  if (mouth > .05) {
    _ell(cv, _fill(const Color(0xFF7A2E3A)), mz.dx - hr * .05, mz.dy + hr * .2, hr * .16, hr * .16 * mouth + 1);
    _ell(cv, _fill(const Color(0xFFFF8FA3)), mz.dx - hr * .05, mz.dy + hr * .2 + hr * .1 * mouth, hr * .1, hr * .06 * mouth + .5);
  } else {
    final ms = _stroke(const Color(0xFF4A3328), math.max(1.5, hr * .045));
    cv.drawArc(Rect.fromCircle(center: Offset(mz.dx - hr * .12, mz.dy + hr * .1), radius: hr * .09), .2, math.pi - .4 - .2, false, ms);
    cv.drawArc(Rect.fromCircle(center: Offset(mz.dx + hr * .05, mz.dy + hr * .1), radius: hr * .09), .4, math.pi - .2 - .4, false, ms);
  }
  if (p('tongue') > .05) _ell(cv, _fill(const Color(0xFFFF6B81)), mz.dx - hr * .02, mz.dy + hr * (.28 + .12 * p('tongue')), hr * .1, hr * .16 * p('tongue'));
  final mouthA = Offset(hx + mz.dx, hy + mz.dy);
  // Mũi
  if (s.muzzle) {
    _ell(cv, _fill(s.nose), hr * .88, hr * .22, hr * .1, hr * .075);
  } else {
    cv.drawPath(
        Path()
          ..moveTo(mz.dx - hr * .08, mz.dy - hr * .04)
          ..lineTo(mz.dx + hr * .08, mz.dy - hr * .04)
          ..lineTo(mz.dx, mz.dy + hr * .05)
          ..close(),
        _fill(s.nose));
  }
  // Ria mèo
  if (kind == 'cat' || kind == 'rabbit') {
    final wp = _stroke(const Color(0x80503C32), 1.5);
    for (final k in const [-1, 0, 1]) {
      cv.drawLine(Offset(mz.dx + hr * .1, mz.dy + hr * .05 * k), Offset(mz.dx + hr * .5, mz.dy + hr * .1 * k - hr * .03), wp);
    }
  }
  // Mắt: tròn đen long lanh; nhắm khi ngủ/chớp; ^^ khi vui
  final eyeOpen = math.max(0.0, p('eye') * (1 - p('blink')) * (1 - p('sleep')));
  for (final (ex, ey, er) in [(-hr * .02, -hr * .02, hr * .2), (hr * .5, 0.0, hr * .22)]) {
    if (p('happy') > .5 || eyeOpen < .15) {
      final ep = _stroke(const Color(0xFF2B2118), math.max(2, hr * .07));
      if (p('happy') > .5 && p('sleep') < .5) {
        cv.drawArc(Rect.fromCircle(center: Offset(ex, ey + er * .3), radius: er * .7), math.pi * 1.15, math.pi * .7, false, ep);
      } else {
        cv.drawArc(Rect.fromCircle(center: Offset(ex, ey - er * .2), radius: er * .7), math.pi * .15, math.pi * .7, false, ep);
      }
    } else {
      final lx = p('lookX') * er * .25, ly = p('lookY') * er * .25;
      final eg = Paint()
        ..shader = ui.Gradient.linear(Offset(0, ey - er), Offset(0, ey + er), const [Color(0xFF1B1410), Color(0xFF3D2B20), Color(0xFF6B4A33)], const [0, .7, 1]);
      _ell(cv, eg, ex + lx * .5, ey + ly * .5, er * .8, er * 1.02 * eyeOpen);
      final wh = _fill(const Color(0xFFFFFFFF));
      _ell(cv, wh, ex + lx - er * .22, ey + ly - er * .42 * eyeOpen, er * .34, er * .34 * eyeOpen);
      _ell(cv, wh, ex + lx + er * .28, ey + ly + er * .34 * eyeOpen, er * .15, er * .15 * eyeOpen);
      _ell(cv, _fill(const Color(0x59FFFFFF)), ex + lx * .5, ey + ly * .5 + er * .55 * eyeOpen, er * .45, er * .18 * eyeOpen);
      if (p('sad') > .5) cv.drawLine(Offset(ex - er, ey - er * 1.4), Offset(ex + er * .6, ey - er * 1.1), _stroke(const Color(0xFF2B2118), hr * .05));
    }
  }
  // Tai phía gần
  _drawEar(cv, s, hr, t, pp, earFlap, false);
  cv.restore();
  cv.restore();

  // Đồ đeo (vẽ theo toạ độ màn hình, không lật để hình không bị ngược chữ)
  Offset w2(double lx, double ly) => Offset(x + lx * f, y + ly);
  final hs = w2(hx, hy);
  void img(String? name, double ix, double iy, double w, [bool flip = false, double rot = 0]) {
    if (name == null) return;
    drawImageCentered(cv, o.images[name], ix, iy, w, w, flip, rot);
  }

  img(o.wear['neck'], x + (hx - hr * .55) * f, y + hy + hr * .85, hr * .9);
  img(o.wear['eyes'], hs.dx + hr * .26 * f, hs.dy - hr * .1, hr * 1.25, f < 0);
  img(o.wear['hat'], hs.dx - hr * .05 * f, hs.dy - hr * (s.ears == 'long' ? 1.05 : .95), hr * 1.15, f < 0, -.12 * f);
  return PetAnchors(
    head: w2(hx, hy),
    top: w2(hx, hy - hr * 1.2),
    mouth: w2(mouthA.dx, mouthA.dy),
    body: w2(bodyA.dx, bodyA.dy),
    hr: hr,
    len: len,
  );
}

void _drawEar(Canvas cv, PetSpecies s, double hr, double t, PetPose pp, double flap, bool farSide) {
  double p(String k) => pp[k] ?? 0;
  cv.save();
  final col = farSide ? s.dark : s.ear;
  if (s.ears == 'floppy') {
    cv.translate(farSide ? hr * .45 : -hr * .25, -hr * .55);
    cv.rotate((farSide ? -.1 : .25) - flap - p('sad') * .1);
    _ell(cv, _fill(col), 0, hr * .45, hr * .26, hr * .55);
  } else if (s.ears == 'pointy') {
    final tw = math.sin(t * .7 + (farSide ? 1 : 0)) > .97 ? .2 : 0.0;
    cv.translate(farSide ? hr * .5 : -hr * .25, -hr * .7);
    cv.rotate((farSide ? .25 : -.2) + tw - p('sad') * .5);
    cv.drawPath(
        Path()
          ..moveTo(-hr * .26, hr * .15)
          ..lineTo(0, -hr * .45)
          ..lineTo(hr * .26, hr * .15)
          ..close(),
        _fill(col));
    if (!farSide) {
      cv.drawPath(
          Path()
            ..moveTo(-hr * .14, hr * .1)
            ..lineTo(0, -hr * .28)
            ..lineTo(hr * .14, hr * .1)
            ..close(),
          _fill(s.inner));
    }
  } else if (s.ears == 'long') {
    final sway = math.sin(t * 1.7 + (farSide ? .7 : 0)) * .08 - flap * .6;
    final droop = p('sad') * .9 + p('sleep') * 1.1;
    cv.translate(farSide ? hr * .35 : -hr * .1, -hr * .7);
    cv.rotate((farSide ? .18 : -.12) + sway - droop);
    _ell(cv, _fill(col), 0, -hr * .6, hr * .2, hr * .68);
    _ell(cv, _fill(s.inner), 0, -hr * .58, hr * .1, hr * .52);
  } else {
    cv.translate(farSide ? hr * .45 : -hr * .3, -hr * .72);
    _ell(cv, _fill(col), 0, 0, hr * .22, hr * .2);
    if (!farSide) _ell(cv, _fill(s.inner), 0, 0, hr * .12, hr * .11);
  }
  cv.restore();
}
