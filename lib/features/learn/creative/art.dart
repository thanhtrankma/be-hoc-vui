// Đảo Tô màu: tranh chạm-để-tô (mỗi vùng là một hình) và vẽ tự do có hình dán, lưu được ảnh — port games/art.js.
// CHỦ: agent C. Giữ nguyên tên công khai artModule (registry trỏ tới). Tranh (kPages/kPreset/PagePainter) dùng chung
// với đảo Tư duy (ghép tranh, tìm điểm khác) trong logic.dart.
//
// Lưu ảnh: web tải file PNG về máy; app ghi PNG vào thư mục tài liệu của app (art/) và ghi danh sách vào kho
// (khoá phụ 'bvh.art' của AppStore: [{file, at, kid, kind}]) — xem saveArtwork()/savedArtworks().
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

final GameModule artModule = ArtGame();

class ArtGame extends GameModule {
  @override
  String get id => 'art';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final kind = ctx.level?['kind'];
    return kind == 'draw' ? DrawView(ctx: ctx) : ColorPageView(ctx: ctx, page: (ctx.level?['page'] ?? 'house').toString());
  }
}

/// Bảng màu (PALETTE của web).
const List<Color> kArtPalette = [
  Color(0xFFFF6B6B), Color(0xFFFF922B), Color(0xFFFFD43B), Color(0xFF94D82D), Color(0xFF51CF66), //
  Color(0xFF22B8CF), Color(0xFF4DABF7), Color(0xFF4C6EF5), Color(0xFF9775FA), Color(0xFFF783AC),
  Color(0xFFA0522D), Color(0xFFFFE8CC), Color(0xFF868E96), Color(0xFF212529), Color(0xFFFFFFFF),
];

const Color kInkLine = Color(0xFF2B2D42);

// ---------- Tranh 400×300 ----------
// Mỗi vùng là một hình; vùng sau đè lên vùng trước. 'line' chỉ là nét trang trí (không tô, không chạm).
class PageShape {
  PageShape(this.path, {this.deco = false});
  final Path path;
  final bool deco;
  Rect get bounds => path.getBounds();
}

Path _rect(double x, double y, double w, double h, [double rx = 0]) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx)));
Path _circle(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
Path _ellipse(double cx, double cy, double rx, double ry, [double rotDeg = 0]) {
  final p = Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
  if (rotDeg == 0) return p;
  final a = rotDeg * math.pi / 180;
  final m = Matrix4.identity()
    ..translateByDouble(cx, cy, 0, 1)
    ..rotateZ(a)
    ..translateByDouble(-cx, -cy, 0, 1);
  return p.transform(m.storage);
}

Path _poly(String pts) {
  final n = pts.trim().split(RegExp(r'[\s,]+')).map(double.parse).toList();
  final p = Path()..moveTo(n[0], n[1]);
  for (var i = 2; i + 1 < n.length; i += 2) {
    p.lineTo(n[i], n[i + 1]);
  }
  return p..close();
}

/// Đường SVG đơn giản (M, L, Q, Z với toạ độ tuyệt đối).
Path _svgPath(String d) {
  final p = Path();
  final tok = RegExp(r'[MLQZ]|-?\d+(\.\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  double nx() => double.parse(tok[i++]);
  while (i < tok.length) {
    final c = tok[i++];
    switch (c) {
      case 'M':
        p.moveTo(nx(), nx());
      case 'L':
        p.lineTo(nx(), nx());
      case 'Q':
        p.quadraticBezierTo(nx(), nx(), nx(), nx());
      case 'Z':
        p.close();
    }
  }
  return p;
}

PageShape _line(double x1, double y1, double x2, double y2) => PageShape(Path()
  ..moveTo(x1, y1)
  ..lineTo(x2, y2), deco: true);

PageShape _r(Path p) => PageShape(p);

final Map<String, List<PageShape> Function()> _pageDefs = {
  'house': () => [
        _r(_rect(0, 0, 400, 220)), _r(_rect(0, 220, 400, 80)),
        _r(_circle(340, 58, 32)), _r(_ellipse(90, 50, 44, 18)), _r(_ellipse(200, 34, 34, 14)),
        _r(_rect(240, 66, 26, 50)), _r(_rect(110, 132, 180, 118)),
        _r(_poly('92,138 200,56 308,138')), _r(_rect(180, 182, 42, 68, 4)),
        _r(_rect(128, 156, 36, 34)), _r(_rect(236, 156, 36, 34)),
        _r(_rect(44, 180, 16, 62)), _r(_circle(52, 160, 32)),
        _r(_circle(330, 252, 9)), _r(_circle(356, 262, 9)), _r(_circle(310, 266, 9)),
      ],
  'fish': () => [
        _r(_rect(0, 0, 400, 256)), _r(_rect(0, 256, 400, 44)),
        _r(_poly('40,300 52,214 66,300')), _r(_poly('350,300 362,200 378,300')),
        _r(_poly('282,150 352,94 352,206')), _r(_poly('150,94 200,52 232,98')), _r(_poly('170,204 210,240 226,200')),
        _r(_ellipse(190, 150, 108, 64)), _r(_ellipse(210, 150, 12, 58)), _r(_ellipse(250, 150, 10, 46)),
        _r(_circle(128, 134, 16)), _r(_circle(124, 134, 7)),
        _r(_circle(80, 70, 10)), _r(_circle(64, 40, 7)), _r(_circle(86, 18, 5)),
      ],
  'flower': () => [
        _r(_rect(0, 0, 400, 300)), _r(_circle(60, 60, 30)),
        _r(_rect(195, 120, 10, 100)),
        _r(_ellipse(166, 176, 30, 13, -30)), _r(_ellipse(234, 190, 30, 13, 30)),
        _r(_rect(140, 214, 120, 20, 4)), _r(_poly('150,234 250,234 236,296 164,296')),
        for (final a in [0, 60, 120, 180, 240, 300]) _r(_circle(200 + 38 * math.cos(a * math.pi / 180), 100 + 38 * math.sin(a * math.pi / 180), 27)),
        _r(_circle(200, 100, 24)),
        _r(_ellipse(330, 80, 22, 14)), _r(_ellipse(352, 80, 22, 14)),
      ],
  'car': () => [
        _r(_rect(0, 0, 400, 230)), _r(_rect(0, 230, 400, 70)),
        _r(_rect(0, 260, 70, 10)), _r(_rect(120, 260, 70, 10)), _r(_rect(240, 260, 70, 10)),
        _r(_circle(70, 60, 28)), _r(_poly('118,152 158,96 262,96 304,152')),
        _r(_rect(56, 148, 290, 70, 22)),
        _r(_poly('134,148 166,108 206,108 206,148')), _r(_poly('216,148 216,108 254,108 286,148')),
        _r(_circle(122, 220, 30)), _r(_circle(122, 220, 12)), _r(_circle(282, 220, 30)), _r(_circle(282, 220, 12)),
        _r(_circle(332, 172, 10)), _r(_rect(60, 168, 18, 12, 3)),
      ],
  'rocket': () => [
        _r(_rect(0, 0, 400, 300)), _r(_circle(70, 230, 40)), _r(_ellipse(70, 230, 62, 12)),
        _r(_poly('330,40 336,56 352,56 339,66 344,82 330,72 316,82 321,66 308,56 324,56')),
        _r(_poly('80,50 84,60 94,60 86,66 89,76 80,70 71,76 74,66 66,60 76,60')),
        _r(_poly('170,206 200,280 230,206')),
        _r(_poly('158,160 114,224 160,210')), _r(_poly('242,160 286,224 240,210')),
        _r(_svgPath('M200,30 Q252,84 246,212 L154,212 Q148,84 200,30 Z')),
        _r(_svgPath('M200,30 Q226,56 236,84 L164,84 Q174,56 200,30 Z')),
        _r(_circle(200, 130, 24)), _r(_circle(200, 130, 15)),
      ],
  'butterfly': () => [
        _r(_rect(0, 0, 400, 300)),
        _r(_ellipse(140, 108, 66, 50, -25)), _r(_ellipse(260, 108, 66, 50, 25)),
        _r(_ellipse(152, 196, 48, 38, 20)), _r(_ellipse(248, 196, 48, 38, -20)),
        _r(_circle(128, 104, 18)), _r(_circle(272, 104, 18)), _r(_circle(150, 200, 13)), _r(_circle(250, 200, 13)),
        _r(_ellipse(200, 158, 12, 74)), _r(_circle(200, 76, 16)),
        _line(194, 64, 170, 26), _line(206, 64, 230, 26),
        _r(_circle(168, 24, 6)), _r(_circle(232, 24, 6)),
      ],
};

/// Tên các tranh có sẵn.
List<String> get kPages => _pageDefs.keys.toList();

final Map<String, List<PageShape>> _pageCache = {};

/// Mọi hình của tranh (kể cả nét trang trí), theo thứ tự vẽ.
List<PageShape> pageShapes(String page) => _pageCache[page] ??= (_pageDefs[page] ?? _pageDefs['house']!)();

/// Chỉ các vùng tô được (bỏ nét trang trí) — chỉ số vùng dùng cho màu, ghép tranh, tìm điểm khác.
List<PageShape> pageRegions(String page) => pageShapes(page).where((s) => !s.deco).toList();

Color _hex(String s) => Color(int.parse('FF${s.substring(1)}', radix: 16));

/// Màu sẵn cho từng tranh (theo thứ tự vùng, bỏ qua nét 'line') – dùng cho ghép tranh và tìm điểm khác.
final Map<String, List<Color>> kPreset = {
  'house': ['#bfe9ff', '#8ce99a', '#ffd43b', '#ffffff', '#ffffff', '#a0522d', '#ffe8cc', '#ff6b6b', '#a0522d', '#74c0fc', '#74c0fc', '#8d5524', '#51cf66', '#f783ac', '#ffd43b', '#9775fa'],
  'fish': ['#a5d8ff', '#ffe066', '#51cf66', '#40c057', '#ff922b', '#ff922b', '#ff922b', '#ffa94d', '#ffffff', '#ffffff', '#ffffff', '#212529', '#e7f5ff', '#e7f5ff', '#e7f5ff'],
  'flower': ['#e3fafc', '#ffd43b', '#40c057', '#51cf66', '#51cf66', '#d9480f', '#e8590c', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#f783ac', '#ffd43b', '#9775fa', '#b197fc'],
  'car': ['#d0ebff', '#868e96', '#ffffff', '#ffffff', '#ffffff', '#ffd43b', '#e03131', '#fa5252', '#a5d8ff', '#a5d8ff', '#343a40', '#adb5bd', '#343a40', '#adb5bd', '#ffec99', '#c92a2a'],
  'rocket': ['#1c2a4a', '#9775fa', '#e599f7', '#ffd43b', '#ffd43b', '#ff922b', '#e03131', '#e03131', '#f1f3f5', '#e03131', '#4dabf7', '#a5d8ff'],
  'butterfly': ['#ebfbee', '#ff922b', '#ff922b', '#ffd43b', '#ffd43b', '#ffffff', '#ffffff', '#ffffff', '#ffffff', '#495057', '#495057', '#495057', '#495057'],
}.map((k, v) => MapEntry(k, v.map(_hex).toList()));

/// Vùng trên cùng chứa điểm p (toạ độ tranh 400×300), -1 nếu không có.
int hitRegion(String page, Offset p) {
  final regs = pageRegions(page);
  for (var i = regs.length - 1; i >= 0; i--) {
    if (regs[i].path.contains(p)) return i;
  }
  return -1;
}

/// Vẽ tranh vào canvas (đã đặt hệ toạ độ 400×300). colors[i] = màu vùng i (thiếu = trắng);
/// hidden = vùng bị ẩn (tìm điểm khác); rings = vòng đỏ đánh dấu (tâm, bán kính).
void paintPage(Canvas canvas, String page,
    {List<Color?>? colors, Set<int> hidden = const {}, List<(Offset, double)> rings = const [], double stroke = 3}) {
  final fill = Paint()..style = PaintingStyle.fill;
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = kInkLine;
  var k = 0;
  for (final s in pageShapes(page)) {
    if (s.deco) {
      canvas.drawPath(s.path, line);
      continue;
    }
    final i = k++;
    if (hidden.contains(i)) continue;
    canvas.drawPath(s.path, fill..color = (colors != null && i < colors.length ? colors[i] : null) ?? Colors.white);
    canvas.drawPath(s.path, line);
  }
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = const Color(0xFFE03131);
  for (final (c, r) in rings) {
    canvas.drawCircle(c, r, ring);
  }
}

/// Vẽ tranh co giãn vào khung (preserveAspectRatio none). viewBox: phần tranh cần vẽ (ghép tranh cắt một mảnh).
class PagePainter extends CustomPainter {
  PagePainter(this.page, {this.colors, this.hidden = const {}, this.rings = const [], this.viewBox = const Rect.fromLTWH(0, 0, 400, 300), this.version = 0});
  final String page;
  final List<Color?>? colors;
  final Set<int> hidden;
  final List<(Offset, double)> rings;
  final Rect viewBox;

  /// Đổi số này để vẽ lại khi danh sách màu sửa tại chỗ.
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);
    canvas.translate(-viewBox.left, -viewBox.top);
    paintPage(canvas, page, colors: colors ?? kPreset[page], hidden: hidden, rings: rings);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PagePainter old) =>
      old.page != page || old.version != version || old.colors != colors || old.viewBox != viewBox || old.hidden != hidden || old.rings != rings;
}

/// Toạ độ chạm trong khung kích thước size → toạ độ tranh 400×300.
Offset toPage(Offset local, Size size) => Offset(local.dx * 400 / size.width, local.dy * 300 / size.height);

// ---------- Lưu ảnh ----------
const String kArtKv = 'bvh.art';
const int _kArtMax = 60;

/// Thư mục lưu tranh (test đặt sẵn để không cần plugin).
@visibleForTesting
Directory? debugArtDir;

Future<Directory> _artDir() async {
  final d = debugArtDir ?? Directory('${(await getApplicationDocumentsDirectory()).path}/art');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// Danh sách tranh đã lưu (mới nhất trước): {file, at, kid, kind}.
List<Map<String, dynamic>> savedArtworks(AppStore store) {
  try {
    final v = jsonDecode(store.getKv(kArtKv) ?? '[]');
    return v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : [];
  } catch (_) {
    return [];
  }
}

/// Ghi ảnh PNG và thêm vào danh sách trong kho. Trả về đường dẫn file, null nếu lỗi.
Future<String?> saveArtwork(AppStore store, Uint8List png, {required String kind}) async {
  try {
    final dir = await _artDir();
    final now = DateTime.now().millisecondsSinceEpoch;
    final f = File('${dir.path}/be-vui-hoc-$kind-$now.png');
    await f.writeAsBytes(png, flush: true);
    final list = savedArtworks(store)..insert(0, {'file': f.path, 'at': now, 'kid': store.profile?.id, 'kind': kind});
    while (list.length > _kArtMax) {
      final old = list.removeLast();
      try {
        File(old['file'].toString()).deleteSync();
      } catch (_) {/* đã mất */}
    }
    store.setKv(kArtKv, jsonEncode(list));
    return f.path;
  } catch (e) {
    debugPrint('saveArtwork: $e');
    return null;
  }
}

Future<Uint8List?> _renderPng(int w, int h, void Function(Canvas c) paint) async {
  try {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.white);
    paint(c);
    final img = await rec.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<void> _saveAndToast(GameContext g, BuildContext context, int w, int h, String kind, void Function(Canvas c) paint) async {
  final png = await _renderPng(w, h, paint);
  final path = png == null ? null : await saveArtwork(g.store, png, kind: kind);
  if (path != null && context.mounted) toast(g.i18n.t('saved'), context: context);
}

// ---------- Khối giao diện ----------
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, this.color, this.label, required this.on, required this.onTap});
  final Color? color;
  final String? label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AnimatedScale(
          scale: on ? 1.2 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color ?? Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: on ? AppColors.ink : Colors.white, width: on ? 4 : 3),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: label == null ? null : Text(label!, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

/// Bảng màu + công cụ phụ (cầu vồng, tẩy). sel = chỉ số đang chọn (màu 0..14, công cụ 15..).
class _Palette extends StatelessWidget {
  const _Palette({required this.sel, required this.onPick, this.extra = const []});
  final int sel;
  final void Function(int i) onPick;
  final List<String> extra;
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, children: [
        for (var i = 0; i < kArtPalette.length; i++) _Swatch(key: Key('sw-$i'), color: kArtPalette[i], on: sel == i, onTap: () => onPick(i)),
        for (var j = 0; j < extra.length; j++)
          _Swatch(key: Key('tool-$j'), label: extra[j], on: sel == kArtPalette.length + j, onTap: () => onPick(kArtPalette.length + j)),
      ]);
}

/// Khung tranh + bảng công cụ: dọc thì xếp chồng, ngang thì công cụ bên phải.
class _ArtLayout extends StatelessWidget {
  const _ArtLayout({required this.aspect, required this.canvas, required this.tools});
  final double aspect;
  final Widget canvas;
  final List<Widget> tools;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > c.maxHeight * 1.15;
      Widget box(double maxW, double maxH) {
        var w = math.min(maxW, 980.0), h = w / aspect;
        if (h > maxH) {
          h = maxH;
          w = h * aspect;
        }
        return Container(
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: kCardShadow),
          child: canvas,
        );
      }

      final panel = Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: tools);
      if (wide) {
        final side = math.min(340.0, c.maxWidth * .36);
        return Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: 14, children: [
          Expanded(child: Center(child: box(c.maxWidth - side - 14, c.maxHeight - 8))),
          SizedBox(width: side, child: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 8), child: panel)),
        ]);
      }
      return Column(children: [
        box(c.maxWidth, c.maxHeight * .58),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 12), child: Center(child: panel))),
      ]);
    });
  }
}

// ---------- Tranh chạm-để-tô ----------
class ColorPageView extends StatefulWidget {
  const ColorPageView({super.key, required this.ctx, required this.page});
  final GameContext ctx;
  final String page;
  @override
  State<ColorPageView> createState() => _ColorPageViewState();
}

class _ColorPageViewState extends State<ColorPageView> {
  GameContext get g => widget.ctx;
  late final int n = pageRegions(widget.page).length;
  late final List<Color?> fills = List.filled(n, Colors.white);
  final Set<int> done = {};
  int sel = 0, version = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.hideBuddy();
      g.progress(0, 1);
      g.audio.sayPhrase('artIntro');
    });
  }

  void _tapAt(Offset local, Size size) {
    final i = hitRegion(widget.page, toPage(local, size));
    if (i < 0 || finished) return;
    setState(() {
      fills[i] = kArtPalette[sel];
      done.add(i);
      version++;
    });
    g.audio.sfx('pop');
  }

  void _done() {
    if (finished) return;
    if (done.length < (n * .5).ceil()) {
      g.audio.sfx('wrong');
      g.audio.sayPhrase('colorMore');
      return;
    }
    finished = true;
    g.progress(1, 1);
    g.audio.sayPhrase('artDone');
    g.finish(3);
  }

  @override
  Widget build(BuildContext context) {
    final i = g.i18n;
    return _ArtLayout(
      aspect: 4 / 3,
      canvas: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          key: const Key('art-page'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tapAt(d.localPosition, c.biggest),
          child: CustomPaint(size: c.biggest, painter: PagePainter(widget.page, colors: fills, version: version)),
        ),
      ),
      tools: [
        _Palette(sel: sel, onPick: (k) {
          setState(() => sel = k);
          g.audio.sfx('tap');
        }),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          AppButton(
            key: const Key('art-save'),
            icon: '💾',
            label: i.t('save'),
            variant: BtnVariant.ghost,
            onTap: () => _saveAndToast(g, context, 1200, 900, widget.page, (cv) {
              cv.scale(3);
              paintPage(cv, widget.page, colors: fills);
            }),
          ),
          AppButton(key: const Key('art-done'), icon: '✔', label: i.t('done'), variant: BtnVariant.green, onTap: _done),
        ]),
      ],
    );
  }
}

// ---------- Vẽ tự do ----------
const List<String> kStamps = ['Star', 'Glowing star', 'Rainbow', 'Butterfly', 'Hibiscus', 'Sun with face', 'Cat', 'Dog', 'Rocket', 'Racing car', 'Balloon', 'Soft ice cream'];
const List<double> _sizes = [6, 12, 24];

/// Khung vẽ ảo rộng 1000 (cao 625, tỉ lệ 16:10); nét lưu theo toạ độ ảo nên xoay máy vẫn giữ hình.
const double _vw = 1000, _vh = 625;

class _Op {
  _Op.stroke(this.width, this.eraser) : kind = 0;
  _Op.stamp(this.stampName, this.at, this.width)
      : kind = 1,
        eraser = false;
  _Op.clear()
      : kind = 2,
        width = 0,
        eraser = false;
  final int kind; // 0 nét, 1 hình dán, 2 xoá hết
  final double width;
  final bool eraser;
  final List<Offset> pts = [];
  final List<Color> cols = []; // màu từng đoạn (cầu vồng đổi màu từng đoạn)
  String? stampName;
  Offset at = Offset.zero;
}

class DrawView extends StatefulWidget {
  const DrawView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<DrawView> createState() => _DrawViewState();
}

class _DrawViewState extends State<DrawView> {
  GameContext get g => widget.ctx;
  // sel: 0..14 màu, 15 cầu vồng, 16 tẩy
  int sel = 0, sizeI = 1, strokes = 0;
  String mode = 'pen'; // pen | rainbow | eraser | stamp
  String? stamp;
  double hue = 0;
  final List<_Op> ops = [];
  final List<int> undo = [];
  final ValueNotifier<int> rev = ValueNotifier(0);
  Map<String, ui.Image> stampImgs = {};
  _Op? cur;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    loadEmojiUiImages(kStamps).then((m) {
      if (mounted) setState(() => stampImgs = m);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.hideBuddy();
      g.progress(0, 1);
      g.audio.sayPhrase('drawQ');
    });
  }

  @override
  void dispose() {
    rev.dispose();
    super.dispose();
  }

  void _snap() {
    undo.add(ops.length);
    if (undo.length > 15) undo.removeAt(0);
  }

  Color _segColor() {
    if (mode == 'rainbow') {
      hue = (hue + 6) % 360;
      return HSLColor.fromAHSL(1, hue, .9, .55).toColor();
    }
    return mode == 'eraser' ? Colors.white : kArtPalette[sel.clamp(0, kArtPalette.length - 1)];
  }

  void _down(Offset local, Size size) {
    if (finished) return;
    final k = _vw / size.width, p = local * k;
    _snap();
    if (mode == 'stamp' && stamp != null) {
      final s = (70 + _sizes[sizeI] * 2) * k;
      ops.add(_Op.stamp(stamp, p, s));
      g.audio.sfx('pop');
      strokes++;
      if (strokes == 3) setState(() {});
    } else {
      final w = (mode == 'eraser' ? _sizes[sizeI] * 2.5 : _sizes[sizeI]) * k;
      final op = _Op.stroke(w, mode == 'eraser')
        ..pts.addAll([p, p + const Offset(.1, .1)])
        ..cols.add(_segColor());
      ops.add(op);
      cur = op;
    }
    rev.value++;
  }

  void _move(Offset local, Size size) {
    final op = cur;
    if (op == null) return;
    op.pts.add(local * (_vw / size.width));
    op.cols.add(_segColor());
    rev.value++;
  }

  void _up() {
    if (cur != null) {
      strokes++;
      if (strokes == 3) setState(() {});
    }
    cur = null;
  }

  void _pick(int k) {
    setState(() {
      sel = k;
      mode = k == kArtPalette.length ? 'rainbow' : k == kArtPalette.length + 1 ? 'eraser' : 'pen';
      stamp = null;
    });
    g.audio.sfx('tap');
  }

  void _pickStamp(String s) {
    setState(() {
      if (mode == 'stamp' && stamp == s) {
        mode = 'pen';
        stamp = null;
        if (sel >= kArtPalette.length) sel = 0;
        return;
      }
      mode = 'stamp';
      stamp = s;
    });
    g.audio.sfx('tap');
  }

  void _undo() {
    if (undo.isNotEmpty) {
      final n = undo.removeLast();
      ops.removeRange(n.clamp(0, ops.length), ops.length);
      rev.value++;
    }
    g.audio.sfx('pop');
  }

  void _clear() {
    _snap();
    ops.add(_Op.clear());
    rev.value++;
    g.audio.sfx('pop');
  }

  void _done() {
    if (finished || strokes < 3) return;
    finished = true;
    g.progress(1, 1);
    g.audio.sayPhrase('artDone');
    g.finish(3);
  }

  @override
  Widget build(BuildContext context) {
    final i = g.i18n;
    final ready = strokes >= 3;
    return _ArtLayout(
      aspect: 16 / 10,
      canvas: LayoutBuilder(
        builder: (context, c) => Listener(
          key: const Key('draw-canvas'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e.localPosition, c.biggest),
          onPointerMove: (e) => _move(e.localPosition, c.biggest),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: CustomPaint(size: c.biggest, painter: _DrawPainter(ops, stampImgs, rev)),
        ),
      ),
      tools: [
        _Palette(sel: mode == 'stamp' ? -1 : sel, onPick: _pick, extra: const ['🌈', '🧽']),
        Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
          for (var k = 0; k < _sizes.length; k++)
            GestureDetector(
              key: Key('size-$k'),
              onTap: () {
                setState(() => sizeI = k);
                g.audio.sfx('tap');
              },
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sizeI == k ? AppColors.ink : AppColors.line, width: 3),
                ),
                child: Container(width: _sizes[k], height: _sizes[k], decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle)),
              ),
            ),
        ]),
        SizedBox(
          height: 64,
          child: ListView(scrollDirection: Axis.horizontal, shrinkWrap: true, padding: const EdgeInsets.all(4), children: [
            for (final s in kStamps)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  key: Key('stamp-$s'),
                  onTap: () => _pickStamp(s),
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: mode == 'stamp' && stamp == s ? const Color(0xFFFFF4EE) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: mode == 'stamp' && stamp == s ? AppColors.primary : AppColors.line, width: 3),
                    ),
                    child: EmojiImage(s, photo: false),
                  ),
                ),
              ),
          ]),
        ),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          AppButton(key: const Key('draw-undo'), label: '↩️', variant: BtnVariant.ghost, onTap: _undo),
          AppButton(key: const Key('draw-clear'), label: '🗑️', variant: BtnVariant.ghost, onTap: _clear),
          AppButton(
            key: const Key('art-save'),
            icon: '💾',
            label: i.t('save'),
            variant: BtnVariant.ghost,
            onTap: () => _saveAndToast(g, context, 1200, 750, 'draw', (cv) {
              cv.scale(1200 / _vw);
              _paintOps(cv, ops, stampImgs);
            }),
          ),
          AppButton(key: const Key('art-done'), icon: '✔', label: i.t('done'), variant: BtnVariant.green, enabled: ready, onTap: ready ? _done : null),
        ]),
      ],
    );
  }
}

void _paintOps(Canvas canvas, List<_Op> ops, Map<String, ui.Image> stamps) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (final op in ops) {
    switch (op.kind) {
      case 2:
        canvas.drawRect(const Rect.fromLTWH(0, 0, _vw, _vh), Paint()..color = Colors.white);
      case 1:
        drawImageCentered(canvas, stamps[op.stampName], op.at.dx, op.at.dy, op.width);
      default:
        p.strokeWidth = op.width;
        final same = op.cols.every((c) => c == op.cols.first);
        if (same) {
          final path = Path()..moveTo(op.pts.first.dx, op.pts.first.dy);
          for (final q in op.pts.skip(1)) {
            path.lineTo(q.dx, q.dy);
          }
          canvas.drawPath(path, p..color = op.cols.first);
        } else {
          for (var k = 1; k < op.pts.length; k++) {
            canvas.drawLine(op.pts[k - 1], op.pts[k], p..color = op.cols[math.min(k - 1, op.cols.length - 1)]);
          }
        }
    }
  }
}

class _DrawPainter extends CustomPainter {
  _DrawPainter(this.ops, this.stamps, this.rev) : super(repaint: rev);
  final List<_Op> ops;
  final Map<String, ui.Image> stamps;
  final ValueNotifier<int> rev;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / _vw);
    _paintOps(canvas, ops, stamps);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawPainter old) => old.stamps != stamps || old.ops != ops;
}
