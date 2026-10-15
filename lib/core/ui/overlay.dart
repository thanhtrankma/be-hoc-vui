// Bảng nổi (.overlay .panel), thông báo nhỏ (toast), pháo giấy (confetti), dòng phần thưởng (.prize), 3 sao lớn (.bigstars).
// Gọi được không cần context nhờ rootNavigatorKey (router dùng chung khoá này).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'emoji_image.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// Khoá Navigator gốc của app (go_router dùng). toast()/confetti() lấy overlay từ đây.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

BuildContext? get rootContext => rootNavigatorKey.currentContext;

/// Mở bảng nổi giữa màn (overlay của web). Trả về giá trị Navigator.pop(context, v).
/// dismissible: chạm nền tối để đóng (web không có; mặc định tắt).
Future<T?> showPanel<T>({
  BuildContext? context,
  required WidgetBuilder builder,
  bool dismissible = false,
  double maxWidth = 560,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 28, 24, 26),
  Color color = Colors.white,
}) {
  final ctx = context ?? rootContext;
  if (ctx == null) return Future.value(null);
  return showGeneralDialog<T>(
    context: ctx,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: 'overlay',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, a, b) => Panel(maxWidth: maxWidth, padding: padding, color: color, child: Builder(builder: builder)),
    transitionBuilder: (context, a, b, child) {
      final pop = CurvedAnimation(parent: a, curve: const Cubic(.3, 1.6, .6, 1));
      return Stack(children: [
        // Nền tối mờ + blur 4px
        Positioned.fill(
          child: FadeTransition(
            opacity: a,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: const ColoredBox(color: AppColors.overlayScrim)),
          ),
        ),
        FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(pop), child: child)),
      ]);
    },
  );
}

/// Khung bảng trắng bo 36 ở giữa màn, cuộn được nếu dài.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.maxWidth = 560, this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 26), this.color = Colors.white});
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: h * .92),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), offset: Offset(0, 14)), BoxShadow(color: Color(0x40000000), offset: Offset(0, 24), blurRadius: 60)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: SingleChildScrollView(
                    padding: padding,
                    child: DefaultTextStyle.merge(textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink), child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề bảng (.panel h2: 1.8em).
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: baseFontSize(context) * 1.8, fontWeight: FontWeight.w800, height: 1.1, color: AppColors.ink2)),
      );
}

/// Ghi chú nhỏ màu nhạt (.note).
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key, this.textAlign = TextAlign.center});
  final String text;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, textAlign: textAlign, style: TextStyle(color: AppColors.inkSoft, fontSize: baseFontSize(context) * .92)),
      );
}

/// Hàng nút cuối bảng (.panel .row): giữa, xuống dòng khi hẹp.
class PanelRow extends StatelessWidget {
  const PanelRow({super.key, required this.children, this.alignment = WrapAlignment.center});
  final List<Widget> children;
  final WrapAlignment alignment;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Wrap(alignment: alignment, spacing: 12, runSpacing: 14, children: children),
      );
}

/// Dòng phần thưởng (.prize): hình nhún + chữ, nền vàng nhạt.
class Prize extends StatelessWidget {
  const Prize({super.key, required this.img, required this.text, this.color = AppColors.prize, this.onTap});
  final String img;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 14, children: [
        Hop(child: EmojiImage(img, size: 64)),
        Flexible(child: Text(text, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
    return onTap == null ? body : GestureDetector(onTap: onTap, child: body);
  }
}

/// 3 sao lớn của bảng kết quả; lit = số sao đã sáng (tăng dần để có hiệu ứng).
class BigStars extends StatelessWidget {
  const BigStars({super.key, required this.lit, this.total = 3});
  final int lit;
  final int total;
  @override
  Widget build(BuildContext context) {
    final s = vwClamp(context, 70, 14, 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 8, children: [
        for (var k = 0; k < total; k++)
          AnimatedScale(
            scale: k < lit ? 1 : .7,
            duration: const Duration(milliseconds: 350),
            curve: const Cubic(.3, 1.6, .6, 1),
            child: k < lit
                ? EmojiImage('Star', size: s, photo: false)
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix([.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, .25, 0]),
                    child: EmojiImage('Star', size: s, photo: false),
                  ),
          ),
      ]),
    );
  }
}

// ---------- Toast ----------
OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// Thông báo nhỏ ở đáy màn, tự tắt sau 2,4 giây.
void toast(String text, {BuildContext? context}) {
  final overlay = context != null ? Overlay.maybeOf(context, rootOverlay: true) : rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      bottom: 28 + MediaQuery.paddingOf(context).bottom,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
              child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: kFontFamily, fontSize: 17)),
            ),
          ),
        ),
      ),
    ),
  );
  _toastEntry = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(milliseconds: 2400), () {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  });
}

// ---------- Pháo giấy ----------
/// n mảnh giấy màu rơi từ trên xuống (~4 giây). Tắt hoạt ảnh (test) thì bỏ qua.
void confetti({int n = 70, BuildContext? context}) {
  if (!Motion.enabled) return;
  final overlay = context != null ? Overlay.maybeOf(context, rootOverlay: true) : rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => IgnorePointer(child: _Confetti(n: n, onDone: () => entry.remove())));
  overlay.insert(entry);
}

class _Piece {
  _Piece(math.Random r, this.color)
      : left = r.nextDouble(),
        dur = 1.8 + r.nextDouble() * 1.6,
        delay = r.nextDouble() * .4,
        dx = r.nextDouble() * 200 - 100,
        rot = (r.nextDouble() * 900 - 450) * math.pi / 180;
  final double left, dur, delay, dx, rot;
  final Color color;
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.n, required this.onDone});
  final int n;
  final VoidCallback onDone;
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..forward().whenComplete(widget.onDone);
  late final List<_Piece> _pieces = () {
    final r = math.Random();
    return [for (var i = 0; i < widget.n; i++) _Piece(r, AppColors.confetti[i % AppColors.confetti.length])];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      // RepaintBoundary: mảnh giấy rơi không bắt cả lớp overlay (bảng kết quả, nền mờ) vẽ lại mỗi khung hình.
      RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c)));
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.anim) : super(repaint: anim);
  final List<_Piece> pieces;
  final Animation<double> anim;
  static final Paint _paint = Paint();
  static final RRect _shape = RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -9, 12, 18), const Radius.circular(3));
  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 4;
    for (final p in pieces) {
      final k = ((t - p.delay) / p.dur).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final x = p.left * size.width + p.dx * k;
      final y = -20 + (size.height * 1.1 + 20) * k;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot * k);
      canvas.drawRRect(_shape, _paint..color = p.color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.pieces != pieces;
}

/// Hộp xác nhận Có/Không (thay confirm() của web).
Future<bool> confirmPanel(String text, {String yes = 'Đồng ý', String no = 'Huỷ', BuildContext? context}) async {
  final r = await showPanel<bool>(
    context: context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      PanelRow(children: [
        AppButton(label: no, variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(ctx, false)),
        AppButton(label: yes, variant: BtnVariant.blue, onTap: () => Navigator.pop(ctx, true)),
      ]),
    ]),
  );
  return r ?? false;
}
