// Góc bố mẹ (/parent): cài đặt, các bé, sao lưu/khôi phục (store.exportData/importData), đồng bộ, góp ý, giới thiệu, ghi công.
// Đã qua khoá bố mẹ trước khi vào (ParentButton). Link ra ngoài app chỉ có ở đây (chính sách app trẻ em).
// CHỦ: agent I. Port của reference/web/js/app.js parent().
// Khác web: bỏ thẻ "Ủng hộ cà phê" (QR chuyển khoản — App Store/Google Play không cho nhận tiền ngoài IAP trong app trẻ em)
// và thẻ "Cài lên màn hình chính" (chỉ dành cho PWA); thêm thẻ Phiên bản.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/sync/firebase_setup.dart';
import 'package:be_vui_hoc/features/tiers/tier_picker.dart';

import 'certificate.dart';
import 'settings.dart';
import 'sync_card.dart';

/// Phiên bản hiển thị (khớp pubspec.yaml `version`).
const String kAppVersion = '1.0.0';
const String kZaloUrl = 'https://zalo.me/0888998098';
const String kAboutUrl = 'https://datpilot.com/be-vui-hoc';
const String kCreditsUrl = 'https://datpilot.com/be-vui-hoc/ghi-cong';

/// Lưu / mở file sao lưu và link ngoài. Test override bằng bản giả.
class ParentsIo {
  const ParentsIo();

  /// Lưu file sao lưu (hộp thoại Lưu của máy; không được thì bảng chia sẻ). true nếu đã lưu/chia sẻ.
  Future<bool> saveBackup(String fileName, String json) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    try {
      final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'application/json', type: FileType.custom, allowedExtensions: const ['json']);
      return uri != null;
    } catch (_) {
      final r = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: fileName)],
        fileNameOverrides: [fileName],
      ));
      return r.status == ShareResultStatus.success;
    }
  }

  /// Chọn file sao lưu, trả về nội dung (null = huỷ).
  Future<String?> pickBackup() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
    if (f == null) return null;
    return utf8.decode(await f.readAsBytes(), allowMalformed: true);
  }

  Future<void> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> shareText(String text, {String? subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject));

  Future<String> loadAssetText(String path) => rootBundle.loadString(path);
}

final parentsIoProvider = Provider<ParentsIo>((ref) => const ParentsIo());

class ParentsScreen extends ConsumerWidget {
  const ParentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final i = ref.watch(i18nProvider);
    final notice = RemoteFlags.parentNotice(i.lang);
    return AppScreen(
      scroll: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
        TopBar(
          leading: IconBtn(
            key: const Key('parent-back'),
            icon: AppIcon.back,
            label: 'Back',
            onTap: () {
              ref.read(audioProvider).sfx('tap');
              context.go(store.profile != null ? '/map' : '/kids');
            },
          ),
          title: i.t('parentArea'),
        ),
        if (notice.isNotEmpty) ParentsSection(title: '📢', color: AppColors.prize, children: [LeftNote(notice)]),
        const SettingsCard(),
        const KidsCard(),
        const BackupCard(),
        const SyncCard(),
        const FeedbackCard(),
        const ShareCard(),
        const CreditsCard(),
        ParentsSection(title: i.t('version'), children: [LeftNote('Bé Vui Học $kAppVersion')]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Các bé
class KidsCard extends ConsumerWidget {
  const KidsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final i = ref.watch(i18nProvider);
    final data = ref.watch(appDataProvider);
    final content = ref.watch(contentProvider);
    final totalLevels = data.islands.where((x) => !x.soon && x.route == null).fold<int>(0, (n, isl) => n + levelsOf(isl, content).length);
    return ParentsSection(title: i.t('kids'), children: [
      for (final p in store.profiles)
        Container(
          key: ValueKey('kid-${p.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            Row(spacing: 12, children: [
              EmojiImage(data.mascot(p.mascot).img, size: 56, photo: false),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                  Text(
                    '⭐ ${p.stars} · ${i.t('levelsDone', {'a': p.levels.values.where((x) => asInt(x) > 0).length, 'b': totalLevels})} · '
                    '${i.t('rounds', {'n': p.rounds})} · ${i.t('today', {'n': (asInt(p.usage[store.today()]) / 60).round()})}',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
                  ),
                  WeekBars(profile: p),
                ]),
              ),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SmallBtn(
                key: Key('report-${p.id}'),
                label: '📊 Báo cáo của con',
                onTap: () {
                  ref.read(audioProvider).sfx('tap');
                  context.go('/report/${p.id}');
                },
              ),
              SmallBtn(key: Key('tier-${p.id}'), label: '🌱 ${i.t('tier')}: ${tierOf(p.tier).textOf(i.lang)}', onTap: () => chooseTier(context, ref, p)),
              SmallBtn(
                key: Key('rename-${p.id}'),
                label: i.t('rename'),
                onTap: () async {
                  final v = await promptPanel(context, title: i.t('newName'), initial: p.name, cancel: i.t('cancel'));
                  final n = (v ?? '').trim();
                  if (n.isNotEmpty) store.updateProfile(p.id, {'name': n.length > 20 ? n.substring(0, 20) : n});
                },
              ),
              SmallBtn(
                key: Key('remove-${p.id}'),
                label: i.t('remove'),
                danger: true,
                onTap: () async {
                  if (await confirmPanel(i.t('confirmRemove', {'name': p.name}), context: context, yes: i.t('remove'), no: i.t('cancel'))) {
                    store.removeProfile(p.id);
                  }
                },
              ),
            ]),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: SmallBtn(key: const Key('add-kid'), label: '+ ${i.t('addKid')}', onTap: () => context.go('/new')),
      ),
    ]);
  }
}

/// Cột phút học 7 ngày (weekBars của web).
class WeekBars extends ConsumerWidget {
  const WeekBars({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final now = store.now();
    final days = [
      for (var k = 6; k >= 0; k--)
        () {
          final d = now.subtract(Duration(days: k));
          return (d.day, (asInt(profile.usage[AppStore.dayKey(d)]) / 60).round());
        }(),
    ];
    final mx = days.fold<int>(10, (m, d) => d.$2 > m ? d.$2 : m);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 44,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, spacing: 4, children: [
          for (final (day, m) in days)
            Expanded(
              child: Tooltip(
                message: '$m′',
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: 4 + 26 * m / mx,
                    decoration: BoxDecoration(color: m > 0 ? AppColors.blue : AppColors.line, borderRadius: BorderRadius.circular(4)),
                  ),
                  Text('$day', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, height: 1.2)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Sao lưu
class BackupCard extends ConsumerWidget {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(i18nProvider);
    final store = ref.read(storeProvider);
    final io = ref.read(parentsIoProvider);
    return ParentsSection(title: i.t('backup'), children: [
      LeftNote(i.t('backupNote')),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SmallBtn(
          key: const Key('backup-download'),
          label: '⬇️ ${i.t('download')}',
          onTap: () async {
            try {
              await io.saveBackup('be-vui-hoc-${store.today()}.json', store.exportData());
            } catch (_) {
              toast('Chưa lưu được file');
            }
          },
        ),
        SmallBtn(
          key: const Key('backup-restore'),
          label: '⬆️ ${i.t('restore')}',
          onTap: () async {
            String? text;
            try {
              text = await io.pickBackup();
            } catch (_) {
              text = null;
            }
            if (text == null) return;
            try {
              store.importData(text);
              toast(i.t('restored'));
            } catch (_) {
              toast(i.t('badFile'));
            }
          },
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Góp ý, giới thiệu
class FeedbackCard extends ConsumerWidget {
  const FeedbackCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final io = ref.read(parentsIoProvider);
    return ParentsSection(title: '💬 Góp ý, báo lỗi', children: [
      const LeftNote(
          'Bố mẹ thấy bài sai, game lỗi hay muốn thêm bài gì thì nhắn Zalo DatPilot 0888 998 098 (ghi máy đang dùng, ví dụ iPad, Android). Lỗi làm app thoát đột ngột được gửi tự động (không kèm tên bé hay dữ liệu học).'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SmallBtn(key: const Key('link-zalo'), label: '💬 Nhắn Zalo', onTap: () => io.openUrl(kZaloUrl)),
        SmallBtn(key: const Key('link-about'), label: 'ℹ️ Giới thiệu', onTap: () => io.openUrl(kAboutUrl)),
        SmallBtn(
          key: const Key('mic-reset'),
          label: '🎤 Hỏi lại về micro',
          onTap: () {
            ref.read(storeProvider).setKv('bvh.micOK', null);
            toast('Lần sau bé bấm 🎤 app sẽ hỏi lại bố mẹ');
          },
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Giới thiệu cho bạn bè
class ShareCard extends ConsumerWidget {
  const ShareCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final io = ref.read(parentsIoProvider);
    return ParentsSection(title: '📣 Giới thiệu cho bạn bè', children: [
      const LeftNote('Bé Vui Học miễn phí. Bố mẹ thấy có ích thì gửi giúp vào nhóm Zalo của lớp hoặc bạn bè có con nhỏ nhé.'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SmallBtn(key: const Key('share-app'), label: '📤 Chia sẻ Zalo, Facebook, Messenger…', onTap: () => io.shareText('$kAppPitch ${shareLink('app')}', subject: 'Bé Vui Học')),
        SmallBtn(
          key: const Key('copy-link'),
          label: '📋 Chép link',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: '$kAppPitch ${shareLink('link')}'));
            toast('Đã chép link, dán vào Zalo hoặc Facebook nhé');
          },
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Nguồn ảnh và âm thanh (Ghi công)
class CreditsCard extends ConsumerStatefulWidget {
  const CreditsCard({super.key});
  @override
  ConsumerState<CreditsCard> createState() => _CreditsCardState();
}

class _CreditsCardState extends ConsumerState<CreditsCard> {
  bool _open = false;
  String? _sfx;

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    if (_open && _sfx == null) {
      try {
        final t = await ref.read(parentsIoProvider).loadAssetText('assets/sfx/CREDITS.txt');
        if (mounted) setState(() => _sfx = t);
      } catch (_) {
        if (mounted) setState(() => _sfx = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    final photos = ref.watch(contentBundleProvider).photos;
    final io = ref.read(parentsIoProvider);
    const small = TextStyle(fontSize: 13, color: AppColors.inkSoft);
    return ParentsSection(title: i.t('credits'), children: [
      LeftNote(i.t('creditsNote', {'n': photos.length})),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SmallBtn(key: const Key('credits-show'), label: '${_open ? '▾' : '▸'} ${i.t('creditsShow')}', onTap: _toggle),
        SmallBtn(key: const Key('link-credits'), label: '🌐 Ghi công (web)', onTap: () => io.openUrl(kCreditsUrl)),
      ]),
      if (_open) ...[
        const SizedBox(height: 10),
        for (final e in photos.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: e.key, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                TextSpan(text: ' — ${e.value.by ?? '?'} — ${e.value.lic ?? ''} — '),
                // Như web: mỗi ảnh dẫn tới trang tệp gốc trên Wikimedia (ghi công CC BY / BY-SA). Đã qua khoá bố mẹ.
                if (e.value.src != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => io.openUrl(e.value.src!),
                      child: Text('Wikimedia Commons', style: small.copyWith(color: AppColors.blueDark, decoration: TextDecoration.underline)),
                    ),
                  )
                else
                  const TextSpan(text: 'Wikimedia Commons'),
              ]),
              style: small,
            ),
          ),
        const SizedBox(height: 8),
        Text(i.t('creditsSfx'), style: const TextStyle(fontWeight: FontWeight.w800)),
        if (_sfx != null) SelectableText(_sfx!, style: small),
      ],
    ]);
  }
}
