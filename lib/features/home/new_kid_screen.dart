// Tạo hồ sơ (newKid() của app.js): bước 1 nhập tên, bước 2 chọn linh vật. Máy mới của nhà đã dùng app: nhập mã gia đình.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';
import '../sync/sync.dart';

class NewKidScreen extends ConsumerStatefulWidget {
  const NewKidScreen({super.key});
  @override
  ConsumerState<NewKidScreen> createState() => _NewKidScreenState();
}

class _NewKidScreenState extends ConsumerState<NewKidScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  int step = 1;
  String? chosen;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && step == 1) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get name => _name.text.trim();

  void _step2() {
    if (name.isEmpty) return;
    _focus.unfocus();
    ref.read(audioProvider).sayPhrase('pickMascot');
    setState(() => step = 2);
  }

  void _create() {
    final store = ref.read(storeProvider);
    store.addProfile(name, chosen);
    ref.read(audioProvider).sfx('win');
    confetti();
    context.go('/map');
  }

  Future<void> _join() async {
    ref.read(audioProvider).sfx('tap');
    final v = await promptPanel(context, title: 'Nhà mình đã dùng Bé Vui Học trên máy khác? Nhập mã gia đình (ở Góc bố mẹ trên máy đó):', maxLength: 24);
    if (v == null || v.trim().isEmpty || !mounted) return;
    final sync = ref.read(syncServiceProvider);
    final store = ref.read(storeProvider);
    final r = await sync.join(v);
    if (!mounted) return;
    if (r == 'ok' && store.profiles.isNotEmpty) {
      store.setActive(store.profiles.first.id);
      context.go('/kids');
    } else {
      toast(r == 'notfound' ? 'Không tìm thấy mã này' : r == 'bad' ? 'Mã gồm 16 chữ và số' : 'Chưa kết nối được, thử lại sau');
    }
  }

  @override
  Widget build(BuildContext context) => step == 1 ? _buildName(context) : _buildMascot(context);

  Widget _buildName(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final store = ref.watch(storeProvider);
    final fs = baseFontSize(context);
    final sync = ref.watch(syncServiceProvider);
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(
          leading: store.profiles.isNotEmpty
              ? IconBtn(icon: AppIcon.back, label: 'Back', onTap: () {
                  ref.read(audioProvider).sfx('tap');
                  context.go('/kids');
                })
              : null,
          title: i.t('yourName'),
        ),
        SizedBox(height: MediaQuery.sizeOf(context).height * .06),
        Column(spacing: 20, children: [
          const EmojiImage('Sparkles', size: 120, photo: false),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), boxShadow: kCardShadow),
              child: TextField(
                key: const Key('name-input'),
                controller: _name,
                focusNode: _focus,
                maxLength: 20,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _step2(),
                style: TextStyle(fontSize: fs * 1.7, fontWeight: FontWeight.w800, color: AppColors.ink),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: i.t('namePh'),
                  hintStyle: TextStyle(color: AppColors.inkSoft.withValues(alpha: .6)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Colors.white, width: 4)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: AppColors.blue, width: 4)),
                ),
              ),
            ),
          ),
          AppButton(key: const Key('name-next'), label: '${i.t('next')} ➜', enabled: name.isNotEmpty, onTap: _step2),
          if (store.profiles.isEmpty && sync.supported)
            Chunky(
              onTap: _join,
              color: AppColors.segBg,
              depth: 0,
              radius: 999,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text('🔑 Đã có mã gia đình', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }

  Widget _buildMascot(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final data = ref.watch(appDataProvider);
    final audio = ref.read(audioProvider);
    final list = data.mascots.where((m) => m.stars == 0).toList();
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(
          leading: IconBtn(icon: AppIcon.back, label: 'Back', onTap: () => setState(() => step = 1)),
          title: i.t('pickBuddy'),
        ),
        MascotGrid(
          mascots: list,
          selected: chosen,
          onPick: (m) {
            setState(() => chosen = m.id);
            audio.say(audio.tpl(i.isEn ? 'mascotEn' : 'mascotVi', m.json));
          },
        ),
        const SizedBox(height: 20),
        AppButton(key: const Key('lets-go'), label: i.t('letsGo'), variant: BtnVariant.green, big: true, enabled: chosen != null, onTap: _create),
      ]),
    );
  }
}

/// Lưới linh vật (.mascots): thẻ trắng, đang chọn viền cam; khoá (cần sao) thì mờ + nhãn ⭐n.
class MascotGrid extends ConsumerWidget {
  const MascotGrid({super.key, required this.mascots, required this.selected, required this.onPick, this.isOpen});
  final List<Mascot> mascots;
  final String? selected;
  final ValueChanged<Mascot> onPick;
  final bool Function(Mascot m)? isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.clamp(0.0, 980.0);
      final minCell = (MediaQuery.sizeOf(context).width * .28).clamp(0.0, 130.0);
      final cols = ((w + 14) / (minCell + 14)).floor().clamp(2, 8);
      final cell = (w - 14 * (cols - 1)) / cols;
      return Wrap(spacing: 14, runSpacing: 14, children: [
        for (final m in mascots)
          SizedBox(
            width: cell,
            child: _MascotCard(m: m, on: m.id == selected, open: isOpen?.call(m) ?? true, label: i.L(m), onTap: () => onPick(m)),
          ),
      ]);
    });
  }
}

class _MascotCard extends StatelessWidget {
  const _MascotCard({required this.m, required this.on, required this.open, required this.label, required this.onTap});
  final Mascot m;
  final bool on, open;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: on ? 1.04 : 1,
      duration: const Duration(milliseconds: 150),
      child: Chunky(
        key: Key('mascot-${m.id}'),
        onTap: onTap,
        pressScale: .95,
        depth: 5,
        radius: 24,
        color: on ? const Color(0xFFFFF4EE) : Colors.white,
        shadowColor: on ? const Color(0xFFFFC3A8) : AppColors.line,
        border: Border.all(color: on ? AppColors.primary : Colors.transparent, width: 4),
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
        child: Stack(clipBehavior: Clip.none, children: [
          Column(children: [
            FractionallySizedBox(
              widthFactor: .84,
              child: AspectRatio(
                aspectRatio: 1,
                child: Opacity(
                  opacity: open ? 1 : .4,
                  child: open
                      ? EmojiImage(m.img, photo: false)
                      : ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: EmojiImage(m.img, photo: false)),
                ),
              ),
            ),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink2, height: 1.15), maxLines: 2),
          ]),
          if (!open)
            Positioned(
              top: -4,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(999)),
                child: Text('⭐${m.stars}', style: const TextStyle(color: Color(0xFF6B4C00), fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
        ]),
      ),
    );
  }
}
