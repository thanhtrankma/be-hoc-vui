// Cài đặt: store.setSetting(k, v) (lang, music, sound, limit, lockOrder, fun, ticketsPer) + tặng vé. Nhạc nền tự bật/tắt theo setting.
// CHỦ: agent I. Port của reference/web/js/app.js parent() phần Cài đặt (thẻ đầu tiên của Góc bố mẹ).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Đổi một cài đặt như set() trong parent() của web (music → bật/tắt nhạc nền ngay).
void applySetting(WidgetRef ref, String k, Object? v) {
  ref.read(storeProvider).setSetting(k, v);
  if (k == 'music') ref.read(audioProvider).music();
}

/// Tặng 3 vé cho một bé (giữ nguyên bé đang chơi).
void giveTickets(AppStore store, String kidId, [int n = 3]) {
  final cur = store.activeId;
  store.setActive(kidId);
  store.addTickets(n);
  if (cur != null) store.setActive(cur);
}

class SettingsCard extends ConsumerWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final i = ref.watch(i18nProvider);
    final s = store.settings;
    void set(String k, Object? v) {
      ref.read(audioProvider).sfx('tap');
      applySetting(ref, k, v);
    }

    Widget opt(String key, String label, Widget child) => Padding(
          key: Key('opt-$key'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), child],
          ),
        );
    Widget onOff(String k) => Seg<bool>(options: [(true, i.t('on')), (false, i.t('off'))], value: s[k] != false, onPick: (v) => set(k, v));

    return ParentsSection(
      title: i.t('settings'),
      children: [
        opt('lang', i.t('language'), Seg<String>(options: const [('vi', 'Tiếng Việt'), ('en', 'English')], value: store.lang, onPick: (v) => set('lang', v))),
        opt('music', i.t('music'), onOff('music')),
        opt('sound', i.t('sound'), onOff('sound')),
        opt(
          'limit',
          i.t('limit'),
          Seg<int>(
            options: [(0, i.t('off')), (15, '15′'), (20, '20′'), (30, '30′'), (45, '45′')],
            value: store.limitMinutes,
            onPick: (v) => set('limit', v),
          ),
        ),
        opt('lockOrder', i.t('lockOrder'), Seg<bool>(options: [(true, i.t('on')), (false, i.t('off'))], value: store.lockOrder, onPick: (v) => set('lockOrder', v))),
        opt('fun', i.t('funZone'), onOff('fun')),
        opt('ticketsPer', i.t('ticketsPer'), Seg<int>(options: const [(1, '1 🎟️'), (2, '2 🎟️')], value: store.ticketsPer, onPick: (v) => set('ticketsPer', v))),
        opt(
          'give',
          i.t('giveTickets'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in store.profiles)
              SmallBtn(
                key: Key('give-${k.id}'),
                label: '${k.name} (🎟️ ${store.tickets(k)}) +3',
                onTap: () {
                  giveTickets(store, k.id);
                  toast('${k.name} +3 🎟️');
                },
              ),
          ]),
        ),
      ],
    );
  }
}

/// Thẻ một mục của Góc bố mẹ (.card.section): tiêu đề h3 + nội dung.
class ParentsSection extends StatelessWidget {
  const ParentsSection({super.key, required this.title, required this.children, this.color = Colors.white});
  final String title;
  final List<Widget> children;
  final Color color;
  @override
  Widget build(BuildContext context) => CardBox(
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(fontSize: baseFontSize(context) * 1.25, fontWeight: FontWeight.w800, color: AppColors.ink2)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

/// Nút nhỏ (.small-btn).
class SmallBtn extends StatelessWidget {
  const SmallBtn({super.key, required this.label, this.onTap, this.danger = false});
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Chunky(
        onTap: onTap,
        depth: 3,
        radius: 999,
        color: danger ? const Color(0xFFFFECEC) : const Color(0xFFF3F6FB),
        shadowColor: danger ? const Color(0xFFFFC9C9) : AppColors.line,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        semanticLabel: label,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: danger ? const Color(0xFFD63939) : AppColors.ink)),
      );
}

/// Ghi chú trái (.note trong thẻ).
class LeftNote extends StatelessWidget {
  const LeftNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => NoteText(text, textAlign: TextAlign.start);
}
