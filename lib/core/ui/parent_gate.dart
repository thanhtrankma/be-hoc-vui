// Khoá bố mẹ: phép nhân số có hai chữ số với số có một chữ số (vd. 23 × 4) — bé 6–8 tuổi chưa làm được. Mọi chỗ dành cho bố mẹ (Góc bố mẹ, chơi miễn phí,
// mua hàng/link ngoài, chia sẻ) phải qua đây — yêu cầu của App Store/Google Play cho app trẻ em.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';
import '../i18n/i18n.dart';
import 'overlay.dart';
import 'text_menu.dart';
import 'theme.dart';
import 'widgets.dart';

/// Thừa số thứ nhất 12–49, thứ hai 3–9 (kết quả 36–441, tối đa 3 chữ số).
const int kGateAMin = 12, kGateAMax = 49, kGateBMin = 3, kGateBMax = 9;

/// Test thay nguồn ngẫu nhiên để biết trước phép tính.
@visibleForTesting
Random? debugGateRandom;

/// Hỏi phép nhân; true nếu bố mẹ trả lời đúng, false nếu huỷ.
Future<bool> parentGate(BuildContext context, WidgetRef ref) async {
  final r = await showPanel<bool>(context: context, builder: (_) => const _Gate());
  return r ?? false;
}

class _Gate extends ConsumerStatefulWidget {
  const _Gate();
  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> {
  final _r = debugGateRandom ?? Random();
  late int a, b;
  String typed = '';

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  /// Phép tính mới; sau một lần trả lời sai luôn khác phép vừa hỏi (không đoán mò nhiều lần cùng một phép — Apple 1.3).
  void _newQuestion({(int, int)? not}) {
    a = kGateAMin + _r.nextInt(kGateAMax - kGateAMin + 1);
    b = kGateBMin + _r.nextInt(kGateBMax - kGateBMin + 1);
    if (not != null && (a, b) == not) a = a == kGateAMax ? kGateAMin : a + 1;
  }

  void press(String k) {
    ref.read(audioProvider).sfx('tap');
    setState(() {
      if (k == '⌫') {
        if (typed.isNotEmpty) typed = typed.substring(0, typed.length - 1);
      } else if (k == 'OK') {
        if (int.tryParse(typed) == a * b) {
          Navigator.pop(context, true);
          return;
        }
        typed = '';
        _newQuestion(not: (a, b));
        toast('✖');
      } else if (typed.length < 3) {
        typed += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final fs = baseFontSize(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      PanelTitle(i.t('gateTitle')),
      NoteText(i.t('gateHint')),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('$a × $b = ?', style: TextStyle(fontSize: fs * 2.4, fontWeight: FontWeight.w800)),
      ),
      Container(
        key: const Key('gate-ans'),
        height: 64,
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(20)),
        child: Text(typed.isEmpty ? '?' : typed, style: TextStyle(fontSize: fs * 2, fontWeight: FontWeight.w800, letterSpacing: 4)),
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'])
            Chunky(
              key: Key('gate-$k'),
              onTap: () => press(k),
              color: k == 'OK' ? AppColors.good : const Color(0xFFF3F6FB),
              shadowColor: k == 'OK' ? AppColors.goodDark : AppColors.line,
              depth: 4,
              radius: 20,
              child: Center(
                child: Text(k, style: TextStyle(fontSize: fs * 1.6, fontWeight: FontWeight.w800, color: k == 'OK' ? Colors.white : AppColors.ink)),
              ),
            ),
        ],
      ),
      PanelRow(children: [AppButton(label: i.t('cancel'), variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(context, false))]),
    ]);
  }
}

/// Nút "⚙ Bố mẹ" trên thanh trên (parentBtn của app.js): qua khoá rồi gọi onPassed.
class ParentButton extends ConsumerWidget {
  const ParentButton({super.key, required this.onPassed, this.height = 60});
  final VoidCallback onPassed;
  final double height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    return Chunky(
      key: const Key('parent-btn'),
      depth: 5,
      radius: 20,
      semanticLabel: i.t('parentArea'),
      onTap: () async {
        ref.read(audioProvider).sfx('tap');
        if (await parentGate(context, ref)) onPassed();
      },
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
            AppIconView(AppIcon.gear, size: height * .45),
            Text(i.t('parentShort'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink2, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

/// Ô nhập chữ trong bảng nổi (thay prompt() của web). null = huỷ.
Future<String?> promptPanel(BuildContext context, {required String title, String initial = '', String? hint, int maxLength = 20, String ok = 'OK', String cancel = 'Huỷ'}) {
  final c = TextEditingController(text: initial);
  return showPanel<String>(
    context: context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      TextField(
        controller: c,
        autofocus: true,
        maxLength: maxLength,
        contextMenuBuilder: safeContextMenuBuilder,
        textAlign: TextAlign.center,
        decoration: InputDecoration(hintText: hint, filled: true, fillColor: AppColors.segBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      PanelRow(children: [
        AppButton(label: cancel, variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(ctx)),
        AppButton(label: ok, variant: BtnVariant.blue, onTap: () => Navigator.pop(ctx, c.text)),
      ]),
    ]),
  );
}
