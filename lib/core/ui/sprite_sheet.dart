// Sprite sheet có khung hoạt ảnh (port games/sheets.js; hạ tầng dùng chung cho game canvas/Flame).
// Mỗi gói: assets/sprites/<gói>/<tên>.webp + <tên>.json dạng
//   {"frames": {"walk0": [x, y, w, h, ox?, oy?], ...}, "anims": {"walk": {"frames": [...], "fps": 10, "loop": true}},
//    "anchor": [0.5, 1], "size": [W, H]?}
// anchor: điểm gốc (0.5,1 = giữa chân). size (nếu có): khung logic, khung đã cắt viền ghi thêm ox, oy.
// Dùng:  final s = await loadSheet('toon/boy');  drawAnim(canvas, s, 'walk', t, x, y, h, flip: true);
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'emoji_image.dart';

class SpriteAnim {
  const SpriteAnim({required this.frames, this.fps = 10, this.loop = true});
  final List<String> frames;
  final double fps;
  final bool loop;
}

class SpriteSheet {
  SpriteSheet({required this.name, required this.image, required this.frames, required this.anims, required this.anchor, this.size, required this.meta});
  final String name;
  final ui.Image? image;

  /// tên khung → [x, y, w, h, ox, oy]
  final Map<String, List<double>> frames;
  final Map<String, SpriteAnim> anims;
  final Offset anchor;
  final Size? size;
  final Map<String, dynamic> meta;

  /// Tỉ lệ rộng/cao của khung (aspect() trong funfx.js).
  double aspect(String frame) {
    final f = frames[frame];
    return f == null ? 1 : f[2] / f[3];
  }
}

final Map<String, Future<SpriteSheet?>> _sheets = {};

/// Tải một sheet theo tên 'gói/tên' (vd. 'play/kidboy'). Lỗi → null.
Future<SpriteSheet?> loadSheet(String name) => _sheets[name] ??= () async {
      try {
        final meta = jsonDecode(await rootBundle.loadString('assets/sprites/$name.json')) as Map<String, dynamic>;
        final img = await loadUiImage('assets/sprites/$name.webp');
        final frames = <String, List<double>>{};
        (meta['frames'] as Map? ?? {}).forEach((k, v) {
          if (v is List) frames[k.toString()] = v.map((e) => (e as num).toDouble()).toList();
        });
        final anims = <String, SpriteAnim>{};
        (meta['anims'] as Map? ?? {}).forEach((k, v) {
          if (v is Map) {
            anims[k.toString()] = SpriteAnim(
              frames: (v['frames'] as List? ?? []).map((e) => e.toString()).toList(),
              fps: (v['fps'] as num? ?? 10).toDouble(),
              loop: v['loop'] != false,
            );
          }
        });
        final a = meta['anchor'] as List?;
        final s = meta['size'] as List?;
        return SpriteSheet(
          name: name,
          image: img,
          frames: frames,
          anims: anims,
          anchor: a == null ? const Offset(.5, 1) : Offset((a[0] as num).toDouble(), (a[1] as num).toDouble()),
          size: s == null ? null : Size((s[0] as num).toDouble(), (s[1] as num).toDouble()),
          meta: meta,
        );
      } catch (_) {
        _sheets.remove(name);
        return null;
      }
    }();

Future<List<SpriteSheet?>> loadSheets(Iterable<String> names) => Future.wait(names.map(loadSheet));

/// Khung theo thời gian t (giây) của một hoạt ảnh (không có thì 'idle', rồi khung đầu).
String frameAt(SpriteSheet sheet, String anim, double t) {
  final a = sheet.anims[anim] ?? sheet.anims['idle'] ?? SpriteAnim(frames: [sheet.frames.keys.first], fps: 1);
  final n = a.frames.length;
  var i = (t * a.fps).floor();
  i = !a.loop ? (i < n - 1 ? i : n - 1) : ((i % n) + n) % n;
  return a.frames[i];
}

/// Vẽ một khung, h = chiều cao hiển thị (rộng tự theo tỉ lệ). image: vẽ từ ảnh khác cùng bố cục (bản đổi màu áo).
/// Trả về false nếu không vẽ được (thiếu khung/ảnh).
bool drawFrame(Canvas canvas, SpriteSheet? sheet, String frame, double x, double y, double h,
    {bool flip = false, double rot = 0, double alpha = 1, ui.Image? image, double sy = 1}) {
  final f = sheet?.frames[frame];
  final im = image ?? sheet?.image;
  if (sheet == null || f == null || im == null) return false;
  final sx = f[0], sy0 = f[1], sw = f[2], sh = f[3];
  final ox = f.length > 4 ? f[4] : 0.0, oy = f.length > 5 ? f[5] : 0.0;
  final fw = sheet.size?.width ?? sw, fh = sheet.size?.height ?? sh;
  final k = h / fh;
  canvas.save();
  canvas.translate(x, y);
  if (rot != 0) canvas.rotate(rot);
  if (flip) canvas.scale(-1, 1);
  if (sy != 1) canvas.scale(1, sy);
  final dst = Rect.fromLTWH((ox - fw * sheet.anchor.dx) * k, (oy - fh * sheet.anchor.dy) * k, sw * k, sh * k);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (alpha < 1) paint.color = Color.fromRGBO(0, 0, 0, alpha);
  canvas.drawImageRect(im, Rect.fromLTWH(sx, sy0, sw, sh), dst, paint);
  canvas.restore();
  return true;
}

bool drawAnim(Canvas canvas, SpriteSheet? sheet, String anim, double t, double x, double y, double h,
        {bool flip = false, double rot = 0, double alpha = 1, ui.Image? image, double sy = 1}) =>
    sheet != null && drawFrame(canvas, sheet, frameAt(sheet, anim, t), x, y, h, flip: flip, rot: rot, alpha: alpha, image: image, sy: sy);

/// Vẽ hình emoji (ui.Image đã tải) căn giữa tại (x, y), rộng w cao h — như draw(ctx, name, x, y, w, h) của funcore.js.
void drawImageCentered(Canvas canvas, ui.Image? img, double x, double y, double w, [double? h, bool flip = false, double rot = 0, double alpha = 1]) {
  if (img == null) return;
  final hh = h ?? w;
  canvas.save();
  canvas.translate(x, y);
  if (rot != 0) canvas.rotate(rot);
  if (flip) canvas.scale(-1, 1);
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (alpha < 1) paint.color = Color.fromRGBO(0, 0, 0, alpha);
  canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: w, height: hh), paint);
  canvas.restore();
}

/// Hiệu năng: cảnh tĩnh nhiều lệnh vẽ (nền lát ô: hàng trăm drawImageRect mỗi khung khi phát lại Picture) được
/// chụp thành MỘT ảnh ở độ phân giải thật của màn hình, trả về Picture chỉ vẽ ảnh đó (1 lệnh vẽ). Cùng điểm ảnh → hình như cũ.
/// [pic] được giải phóng; lỗi/quá lớn thì trả lại chính [pic].
ui.Picture flattenPicture(ui.Picture pic, double w, double h, {double x = 0, double y = 0, ui.FilterQuality filter = ui.FilterQuality.none}) {
  try {
    final views = ui.PlatformDispatcher.instance.views;
    final dpr = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
    final pw = (w * dpr).ceil(), ph = (h * dpr).ceil();
    if (pw <= 0 || ph <= 0 || pw > 4096 || ph > 4096) return pic;
    final r1 = ui.PictureRecorder();
    ui.Canvas(r1)
      ..scale(dpr)
      ..translate(-x, -y)
      ..drawPicture(pic);
    final p1 = r1.endRecording();
    final img = p1.toImageSync(pw, ph);
    p1.dispose();
    final r2 = ui.PictureRecorder();
    ui.Canvas(r2).drawImageRect(img, ui.Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()), ui.Rect.fromLTWH(x, y, pw / dpr, ph / dpr),
        ui.Paint()..filterQuality = filter);
    img.dispose(); // Picture giữ tham chiếu riêng tới ảnh
    pic.dispose();
    return r2.endRecording();
  } catch (_) {
    return pic;
  }
}
