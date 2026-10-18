// Bằng khen: ảnh PNG 1080×1350 (tỉ lệ bài đăng Facebook) vẽ ngay trên máy — port certImage() + certificate() của app.js.
// Không gửi gì đi: ảnh vẽ bằng Canvas rồi đưa vào bảng chia sẻ của máy (share_plus).
// CHỦ: agent I. Màn kết thúc bài (features/play/finish_round.dart của Foundation) có thể gọi showCertificate()
// thay bản chỉ chia sẻ chữ của nó.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Trang giới thiệu công khai của app (Firebase Hosting), dùng khi chia sẻ (không gắn tham số theo dõi).
const String kShareUrl = 'https://bevuihoc-app.web.app/';
const String kAppPitch =
    'Bé Vui Học: ứng dụng học mà chơi miễn phí cho bé 3–6 tuổi. Ghép vần, đếm số, toán, tiếng Anh, có lộ trình theo thứ tự bài sách lớp 1. Không quảng cáo, không cần tài khoản.';

/// 'YYYY-MM-DD' → 'DD/MM/YYYY' (fmtDate của web).
String fmtDate(String? d) => d == null || d.isEmpty ? '' : d.split('-').reversed.join('/');

/// Dữ liệu một bằng khen.
class CertData {
  const CertData({required this.name, required this.text, required this.img, required this.when, required this.stars, this.showName = true});
  final String name;
  final String text;
  final String img;
  final String when;
  final int stars;
  final bool showName;
  CertData withName(bool v) => CertData(name: name, text: text, img: img, when: when, stars: stars, showName: v);
}

CertData certDataFor(WidgetRef ref, Profile p, String id) {
  final tracker = ref.read(learnTrackerProvider);
  final store = ref.read(storeProvider);
  final info = tracker.msInfo(id, ref.read(i18nProvider).lang);
  final msAt = asMap(store.learn(p)['msAt'])[id] as String? ?? store.today();
  return CertData(name: p.name, text: info.text, img: info.img, when: fmtDate(msAt), stars: p.stars);
}

const double kCertW = 1080, kCertH = 1350;

/// Chia dòng theo bề rộng (wrapText của web).
List<String> wrapWords(String text, double maxW, double Function(String) measure) {
  final out = <String>[];
  var line = '';
  for (final w in text.split(' ')) {
    final t = line.isEmpty ? w : '$line $w';
    if (measure(t) > maxW && line.isNotEmpty) {
      out.add(line);
      line = w;
    } else {
      line = t;
    }
  }
  if (line.isNotEmpty) out.add(line);
  return out;
}

TextPainter _tp(String s, double size, FontWeight w, Color c) => TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: kFontFamily, fontSize: size, fontWeight: w, color: c, height: 1)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

/// Vẽ chữ giữa theo đường chân chữ y (textBaseline = alphabetic như canvas web).
void _centerText(Canvas c, String s, double y, double size, FontWeight w, Color color) {
  final tp = _tp(s, size, w, color);
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  tp.paint(c, Offset(kCertW / 2 - tp.width / 2, y - base));
}

/// Vẽ bằng khen lên canvas (đúng toạ độ certImage() của web).
void paintCertificate(Canvas c, CertData d, {ui.Image? medal, ui.Image? pic}) {
  const w = kCertW, h = kCertH;
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), const [Color(0xFFFFF9E6), Color(0xFFFFE8CC)]),
  );
  c.drawRRect(RRect.fromLTRBR(30, 30, w - 30, h - 30, const Radius.circular(44)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0xFFF59F00));
  c.drawRRect(RRect.fromLTRBR(58, 58, w - 58, h - 58, const Radius.circular(30)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFD43B));
  void img(ui.Image? im, double x, double y, double s) {
    if (im == null) return;
    paintImage(canvas: c, rect: Rect.fromLTWH(x, y, s, s), image: im, fit: BoxFit.contain, filterQuality: FilterQuality.high);
  }

  img(medal, w / 2 - 80, 92, 160);
  _centerText(c, 'BẰNG KHEN', 360, 112, FontWeight.w800, const Color(0xFFD9480F));
  _centerText(c, d.showName ? 'Bé Vui Học trân trọng tặng bé' : 'Bé Vui Học trân trọng tặng bé yêu', 430, 44, FontWeight.w600, const Color(0xFF495057));
  var y = 430.0;
  if (d.showName) {
    var fs = 120.0;
    while (_tp(d.name, fs, FontWeight.w800, Colors.black).width > w - 220 && fs > 60) {
      fs -= 6;
    }
    _centerText(c, d.name, y += 140, fs, FontWeight.w800, const Color(0xFF1C7ED6));
  }
  img(pic, w / 2 - 140, y += 40, 280);
  y += 280;
  for (final ln in wrapWords(d.text, w - 200, (s) => _tp(s, 58, FontWeight.w700, Colors.black).width)) {
    _centerText(c, ln, y += 78, 58, FontWeight.w700, const Color(0xFF212529));
  }
  _centerText(c, 'Ngày ${d.when} · ${d.stars} sao', y += 72, 40, FontWeight.w600, const Color(0xFF868E96));
  c.drawRRect(RRect.fromLTRBR(110, h - 230, w - 110, h - 90, const Radius.circular(70)), Paint()..color = const Color(0xFFF59F00));
  _centerText(c, 'Bé Vui Học', h - 165, 50, FontWeight.w800, Colors.white);
  _centerText(c, 'Học mà chơi cho bé 3–6 tuổi', h - 118, 34, FontWeight.w600, Colors.white);
}

/// Vẽ bằng khen ra ui.Image 1080×1350.
Future<ui.Image> renderCertificate(CertData d) async {
  final imgs = await loadEmojiUiImages(['Sports medal', d.img]);
  final rec = ui.PictureRecorder();
  paintCertificate(Canvas(rec), d, medal: imgs['Sports medal'], pic: imgs[d.img]);
  return rec.endRecording().toImage(kCertW.toInt(), kCertH.toInt());
}

/// Ảnh PNG của bằng khen (null nếu lỗi).
Future<Uint8List?> certificatePng(CertData d) async {
  try {
    final im = await renderCertificate(d);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    im.dispose();
    return bytes?.buffer.asUint8List();
  } catch (e) {
    debugPrint('[cert] $e');
    return null;
  }
}

/// Lời giới thiệu kèm ảnh khi khoe.
String certShareText(CertData d) =>
    '${d.showName ? 'Bé ${d.name}' : 'Bé nhà mình'} vừa được bằng khen: ${d.text} Học miễn phí ở Bé Vui Học: $kShareUrl';

/// Mở bảng chia sẻ của máy với ảnh PNG; không tạo được ảnh thì chia sẻ chữ.
Future<void> shareCertificate(CertData d, {Rect? origin}) async {
  final png = await certificatePng(d);
  final text = certShareText(d);
  if (png == null) {
    toast('Chưa tạo được ảnh, bố mẹ chụp màn hình nhé');
    await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
    return;
  }
  await SharePlus.instance.share(ShareParams(
    text: text,
    files: [XFile.fromData(png, mimeType: 'image/png', name: 'bang-khen-be-vui-hoc.png')],
    fileNameOverrides: const ['bang-khen-be-vui-hoc.png'],
    sharePositionOrigin: origin,
  ));
}

/// Bằng khen có tên bé để bố mẹ khoe người thân (certificate() của app.js).
/// parent = true khi mở từ Báo cáo (đã qua khoá bố mẹ), không thì nút khoe hỏi phép tính.
Future<void> showCertificate(BuildContext context, WidgetRef ref, Profile p, String id, {bool parent = false}) {
  ref.read(audioProvider).sayPhrase('cert');
  final d = certDataFor(ref, p, id);
  return showPanel<void>(context: context, builder: (c) => CertificatePanel(data: d, profile: p, parent: parent));
}

class CertificatePanel extends ConsumerStatefulWidget {
  const CertificatePanel({super.key, required this.data, required this.profile, this.parent = false});
  final CertData data;
  final Profile profile;
  final bool parent;
  @override
  ConsumerState<CertificatePanel> createState() => _CertificatePanelState();
}

class _CertificatePanelState extends ConsumerState<CertificatePanel> {
  bool showName = true;

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final d = widget.data.withName(showName);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      CertificateCard(data: d, profile: widget.profile),
      const SizedBox(height: 8),
      InkWell(
        key: const Key('cert-name'),
        onTap: () => setState(() => showName = !showName),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(value: showName, onChanged: (v) => setState(() => showName = v ?? true)),
          const Flexible(child: Text('Hiện tên bé trên ảnh', style: TextStyle(color: AppColors.inkSoft))),
        ]),
      ),
      PanelRow(children: [
        AppButton(label: i.t('close'), variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(context)),
        Builder(
          builder: (bc) => AppButton(
            key: const Key('cert-share'),
            icon: '📤',
            label: 'Khoe với người thân',
            variant: BtnVariant.green,
            onTap: () async {
              ref.read(audioProvider).sfx('tap');
              if (!widget.parent && !await parentGate(context, ref)) return;
              if (!bc.mounted) return;
              final box = bc.findRenderObject() as RenderBox?;
              final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
              await shareCertificate(d, origin: origin);
            },
          ),
        ),
      ]),
    ]);
  }
}

/// Bằng khen trên màn (bản xem trước, giống .cert của web).
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.data, required this.profile});
  final CertData data;
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF9E6), Color(0xFFFFE8CC)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF59F00), width: 6),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD43B), width: 2)),
        child: Column(spacing: 6, children: [
          const EmojiImage('Sports medal', size: 70, photo: false),
          const Text('BẰNG KHEN', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFFD9480F), height: 1)),
          Text(data.showName ? 'Bé Vui Học trân trọng tặng bé' : 'Bé Vui Học trân trọng tặng bé yêu',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF495057))),
          if (data.showName) Text(data.name, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1C7ED6), height: 1.1)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
              Dressed(profile: profile, size: 80),
              EmojiImage(data.img, size: 90, photo: false),
            ]),
          ),
          Text(data.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('📅 ${data.when} · ⭐ ${data.stars} sao', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
        ]),
      ),
    );
  }
}
