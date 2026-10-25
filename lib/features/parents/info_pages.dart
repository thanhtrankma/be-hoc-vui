// Trang thông tin trong app: Giới thiệu, Chính sách quyền riêng tư, Ghi công (nguồn ảnh, âm thanh, hình game).
// Nội dung đóng gói sẵn (assets/legal/*.md, cùng nguồn với trang web hosting/public/ — xem hosting/build_pages.py),
// đọc được khi không có mạng. Chỉ mở sau khoá bố mẹ (Góc bố mẹ, hoặc link ở màn Bắt đầu qua parentGate):
// mọi link ra ngoài trên các trang này cũng vì thế đã qua khoá.
// Trang mở bằng Navigator.push (không phải route của go_router) để mở được cả từ màn Bắt đầu trước khi bé bấm ▶.
// CHỦ: agent I.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'parents.dart';
import 'settings.dart';

/// Trang web công khai của app (Firebase Hosting, project bevuihoc-app).
const String kWebBase = 'https://bevuihoc-app.web.app';
const String kAboutUrl = '$kWebBase/';
const String kPrivacyUrl = '$kWebBase/privacy';
const String kPrivacyUrlEn = '$kWebBase/privacy/en';
const String kCreditsUrl = '$kWebBase/credits';

/// Mở một trang thông tin đè lên màn hiện tại (nền trời đục, không mây chạy, để không lộ màn bên dưới).
Future<void> openInfoPage(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.skyTop, AppColors.skyBottom, Color(0xFFFFF7E0)],
            stops: [0, .7, 1],
          ),
        ),
        child: page,
      ),
    ));

/// Khung chung: nút quay lại + tiêu đề + nội dung cuộn.
class _InfoScaffold extends ConsumerWidget {
  const _InfoScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScreen(
        scroll: true,
        maxWidth: 820,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
          TopBar(
            leading: IconBtn(
              key: const Key('info-back'),
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                // pop() (không phải maybePop): nút này bọc PopScope(canPop: false) gọi lại chính nó khi bấm Back.
                Navigator.of(context).pop();
              },
            ),
            title: title,
          ),
          ...children,
        ]),
      );
}

// ---------------------------------------------------------------- Markdown đơn giản
/// Vẽ một tập con markdown: '# ' tiêu đề, '## ' mục, '- ' gạch đầu dòng, **đậm**, đoạn cách bằng dòng trống.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.source, {super.key});
  final String source;

  static List<InlineSpan> _inline(String s, TextStyle bold) {
    final out = <InlineSpan>[];
    final parts = s.split('**');
    for (var k = 0; k < parts.length; k++) {
      if (parts[k].isEmpty) continue;
      out.add(TextSpan(text: parts[k], style: k.isOdd ? bold : null));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    final body = TextStyle(fontSize: fs * .95, height: 1.45, color: AppColors.ink);
    final bold = const TextStyle(fontWeight: FontWeight.w800);
    final blocks = <Widget>[];
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      blocks.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: Text.rich(TextSpan(children: _inline(para.join(' '), bold)), style: body)));
      para.clear();
    }

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        flush();
      } else if (line.startsWith('# ')) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(line.substring(2), style: TextStyle(fontSize: fs * 1.45, fontWeight: FontWeight.w800, color: AppColors.ink2, height: 1.2)),
        ));
      } else if (line.startsWith('## ')) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(line.substring(3), style: TextStyle(fontSize: fs * 1.15, fontWeight: FontWeight.w800, color: AppColors.ink2)),
        ));
      } else if (line.startsWith('- ')) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: body.copyWith(fontWeight: FontWeight.w800)),
            Expanded(child: Text.rich(TextSpan(children: _inline(line.substring(2), bold)), style: body)),
          ]),
        ));
      } else {
        para.add(line);
      }
    }
    flush();
    return SelectionArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks));
  }
}

/// Đọc `assets/legal/<name>_<lang>.md` (không có bản tiếng Anh thì dùng tiếng Việt).
class _LegalText extends ConsumerStatefulWidget {
  const _LegalText(this.name);
  final String name;
  @override
  ConsumerState<_LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends ConsumerState<_LegalText> {
  Future<String>? _text;
  String? _lang;

  Future<String> _load(String lang) async {
    final io = ref.read(parentsIoProvider);
    try {
      return await io.loadAssetText('assets/legal/${widget.name}_$lang.md');
    } catch (_) {
      return io.loadAssetText('assets/legal/${widget.name}_vi.md');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(i18nProvider).lang;
    if (_lang != lang) {
      _lang = lang;
      _text = _load(lang);
    }
    return FutureBuilder<String>(
      future: _text,
      builder: (context, snap) => snap.hasData
          ? SimpleMarkdown(snap.data!, key: Key('legal-${widget.name}'))
          : snap.hasError
              ? const SizedBox.shrink()
              : const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    );
  }
}

// ---------------------------------------------------------------- Chính sách quyền riêng tư
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final io = ref.read(parentsIoProvider);
    return _InfoScaffold(title: i.isEn ? 'Privacy policy' : 'Quyền riêng tư', children: [
      const CardBox(child: _LegalText('privacy')),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        SmallBtn(
          key: const Key('privacy-web'),
          label: i.isEn ? '🌐 Open the web version' : '🌐 Xem bản trên web',
          onTap: () => io.openUrl(i.isEn ? kPrivacyUrlEn : kPrivacyUrl),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Giới thiệu
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    return _InfoScaffold(title: i.isEn ? 'About' : 'Giới thiệu', children: [
      const CardBox(child: _LegalText('about')),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        SmallBtn(key: const Key('about-credits'), label: '🖼️ ${i.t('credits')}', onTap: () => openInfoPage(context, const CreditsScreen())),
        SmallBtn(
          key: const Key('about-privacy'),
          label: i.isEn ? '🔒 Privacy policy' : '🔒 Chính sách quyền riêng tư',
          onTap: () => openInfoPage(context, const PrivacyScreen()),
        ),
        SmallBtn(key: const Key('about-version'), label: 'Bé Vui Học $kAppVersion'),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Ghi công
/// Danh sách tác giả: ảnh (photos.json, mỗi ảnh dẫn tới trang gốc trên Wikimedia), tiếng thú cưng, hình game, phông chữ.
class CreditsList extends ConsumerStatefulWidget {
  const CreditsList({super.key, this.sprites = true});

  /// Kèm hình trong game (assets/sprites/CREDITS.txt) và phông chữ / hình hoạt hình.
  final bool sprites;
  @override
  ConsumerState<CreditsList> createState() => _CreditsListState();
}

class _CreditsListState extends ConsumerState<CreditsList> {
  String? _sfx, _sprites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final io = ref.read(parentsIoProvider);
    Future<String> read(String p) async {
      try {
        return await io.loadAssetText(p);
      } catch (_) {
        return '';
      }
    }

    final sfx = await read('assets/sfx/CREDITS.txt');
    final sprites = widget.sprites ? await read('assets/sprites/CREDITS.txt') : null;
    if (mounted) {
      setState(() {
        _sfx = sfx;
        _sprites = sprites;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final photos = ref.watch(contentBundleProvider).photos;
    final io = ref.read(parentsIoProvider);
    const small = TextStyle(fontSize: 13, color: AppColors.inkSoft);
    const head = TextStyle(fontWeight: FontWeight.w800);
    final linkStyle = small.copyWith(color: AppColors.blueDark, decoration: TextDecoration.underline);
    WidgetSpan link(String label, String url) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(onTap: () => io.openUrl(url), child: Text(label, style: linkStyle)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        key: const Key('credits-modified'),
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
            i.isEn
                ? 'Photos were resized/cropped and converted to WebP for use in the app. Each line: photo — author — license — original file.'
                : 'Ảnh đã thu nhỏ/cắt và đổi sang định dạng WebP để dùng trong ứng dụng. Mỗi dòng: ảnh — tác giả — giấy phép — tệp gốc.',
            style: small),
      ),
      for (final e in photos.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: e.key, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
              TextSpan(text: ' — ${(e.value.by ?? '').isEmpty ? '?' : e.value.by} — '),
              // Giấy phép dẫn tới creativecommons.org, ảnh dẫn tới trang tệp gốc trên Wikimedia (ghi công CC BY / BY-SA). Đã qua khoá bố mẹ.
              if (e.value.licUrl != null) link(e.value.lic!, e.value.licUrl!) else TextSpan(text: e.value.lic ?? ''),
              const TextSpan(text: ' — '),
              if (e.value.src != null)
                link('Wikimedia Commons', e.value.src!)
              else
                const TextSpan(text: 'Wikimedia Commons'),
            ]),
            style: small,
          ),
        ),
      const SizedBox(height: 8),
      Text(i.t('creditsSfx'), style: head),
      if (_sfx != null) SelectableText(_sfx!, style: small, contextMenuBuilder: safeContextMenuBuilder),
      if (widget.sprites) ...[
        const SizedBox(height: 8),
        Text(i.isEn ? 'Game pictures:' : 'Hình trong game:', style: head),
        if (_sprites != null) SelectableText(_sprites!, style: small, contextMenuBuilder: safeContextMenuBuilder),
        const SizedBox(height: 8),
        Text(i.isEn ? 'Cartoons and font:' : 'Hình hoạt hình và phông chữ:', style: head),
        const SelectableText(
            'Fluent Emoji — Microsoft — MIT License — https://github.com/microsoft/fluentui-emoji\n'
            'Baloo 2 — Ek Type — SIL Open Font License 1.1 — https://github.com/EkType/Baloo2',
            style: small,
            contextMenuBuilder: safeContextMenuBuilder),
      ],
    ]);
  }
}

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final photos = ref.watch(contentBundleProvider).photos;
    final io = ref.read(parentsIoProvider);
    return _InfoScaffold(title: i.t('credits'), children: [
      ParentsSection(title: i.t('credits'), children: [
        LeftNote(i.t('creditsNote', {'n': photos.length})),
        const SizedBox(height: 10),
        const CreditsList(key: Key('credits-list')),
      ]),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        SmallBtn(key: const Key('credits-web'), label: i.isEn ? '🌐 Open the web version' : '🌐 Xem bản trên web', onTap: () => io.openUrl(kCreditsUrl)),
      ]),
    ]);
  }
}
