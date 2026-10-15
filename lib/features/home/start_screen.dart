// Màn Bắt đầu (start() của app.js): 4 linh vật nhảy, logo "Bé Vui Học", "Vừa học vừa chơi", nút ▶ Bắt đầu.
// Lần chạm đầu bật âm thanh/nhạc nền rồi đi tiếp: chưa có bé → tạo hồ sơ; 1 bé → bản đồ; nhiều bé → chọn bé.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_router.dart';
import '../../core/audio/audio_service.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  void _start(BuildContext context, WidgetRef ref) {
    final audio = ref.read(audioProvider);
    final store = ref.read(storeProvider);
    audio.unlock();
    audio.music();
    ref.read(startedProvider.notifier).state = true;
    audio.sfx('win');
    final p = store.profile;
    if (store.profiles.isEmpty) {
      audio.sayPhrase('welcome');
      context.go('/new');
    } else if (store.profiles.length == 1 && p != null) {
      context.go('/map');
    } else {
      context.go('/kids');
    }
  }

  Future<void> _link(BuildContext context, WidgetRef ref, String path) async {
    // Link ra ngoài app phải qua khoá bố mẹ (chính sách app trẻ em).
    if (!await parentGate(context, ref)) return;
    await launchUrl(Uri.parse('https://datpilot.com$path'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final w = MediaQuery.sizeOf(context).width;
    final logo = (w * .09).clamp(54.0, 96.0);
    final mascot = (w * .13).clamp(80.0, 150.0);
    final fs = baseFontSize(context);
    final logoStyle = TextStyle(
      fontSize: logo,
      fontWeight: FontWeight.w800,
      height: 1,
      color: Colors.white,
      shadows: const [Shadow(color: AppColors.primary, offset: Offset(0, 5)), Shadow(color: Color(0x59E86A3A), offset: Offset(0, 10), blurRadius: 22)],
    );
    return AppScreen(
      child: Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Đoàn linh vật nhảy lần lượt
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 18),
              child: Row(mainAxisSize: MainAxisSize.min, spacing: (w * .02).clamp(8.0, 24.0), children: [
                for (final (k, n) in const ['Man superhero', 'Robot', 'T-rex', 'Princess'].indexed)
                  Hop(delay: Duration(milliseconds: 1600 - k * 200), child: EmojiImage(n, size: mascot, photo: false)),
              ]),
            ),
            Text.rich(
              key: const Key('logo'),
              TextSpan(children: [
                const TextSpan(text: 'Bé '),
                TextSpan(
                  text: 'Vui',
                  style: logoStyle.copyWith(
                    color: AppColors.sun,
                    shadows: const [Shadow(color: AppColors.sunDark, offset: Offset(0, 5)), Shadow(color: Color(0x4DE0A800), offset: Offset(0, 10), blurRadius: 22)],
                  ),
                ),
                const TextSpan(text: ' Học'),
              ]),
              style: logoStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(999)),
              child: Text(i.t('tagline'), style: TextStyle(fontSize: fs * 1.35, fontWeight: FontWeight.w600, color: AppColors.ink2)),
            ),
            const SizedBox(height: 18),
            _Pulse(
              child: AppButton(
                key: const Key('start-btn'),
                big: true,
                icon: '▶',
                label: i.t('start'),
                // min-width: min(320px, 80vw) tính cả lề trong của nút
                minWidth: ((w * .8).clamp(0.0, 320.0) - fs * 1.5 * 1.8 * 2).clamp(0.0, 320.0),
                onTap: () => _start(context, ref),
              ),
            ),
            const SizedBox(height: 18),
            DefaultTextStyle.merge(
              style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.inkSoft),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(onTap: () => _link(context, ref, '/be-vui-hoc'), child: const Text('Giới thiệu')),
                const Text(' · ', style: TextStyle(decoration: TextDecoration.none)),
                GestureDetector(onTap: () => _link(context, ref, '/be-vui-hoc/ghi-cong'), child: const Text('Ghi công')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Nút Bắt đầu phập phồng (ctaPulse 2.2s).
class _Pulse extends StatelessWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LoopAnim(
        period: const Duration(milliseconds: 2200),
        child: child,
        builder: (context, t, child) {
          final k = t < .5 ? t * 2 : 2 - t * 2;
          final e = k * k * (3 - 2 * k);
          return Transform.scale(scale: 1 + .05 * e, child: child);
        },
      );
}
