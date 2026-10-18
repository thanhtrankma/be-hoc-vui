// Tủ đồ (mua/đeo đồ cho linh vật). Store: store.buy(item), store.equip(slot, id), store.wallet(p). Widget linh vật mặc đồ: Dressed (core/ui/dressed.dart).
// CHỦ: agent D. Port của web js/app.js room() / SLOTS.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Các ngăn tủ đồ: mũ, kính, đồ cầm tay, nền.
const List<(String, String)> kWardrobeSlots = [('hat', '🎩'), ('eyes', '🕶️'), ('hand', '🎈'), ('bg', '🖼️')];

/// Kết quả bấm một món đồ.
enum WardTap { equipped, removed, bought, needMore }

/// Bấm một món: đã có → đeo/bỏ; chưa có → mua bằng ví sao (đủ sao thì mua và đeo luôn).
WardTap tapWardrobeItem(AppStore store, AudioService audio, WardrobeItem w, {BuildContext? context}) {
  final p = store.profile!;
  final have = p.owned.contains(w.id), on = p.outfit[w.slot] == w.id;
  if (have) {
    store.equip(w.slot, on ? null : w.id);
    audio.sfx('pop');
    return on ? WardTap.removed : WardTap.equipped;
  }
  if (store.buy(w)) {
    audio.sfx('win');
    confetti(n: 30, context: context);
    audio.sayPhrase('buyOk');
    return WardTap.bought;
  }
  audio.sfx('wrong');
  audio.sayPhrase('needMore');
  return WardTap.needMore;
}

/// Khung tủ đồ: hàng chọn ngăn + lưới đồ của ngăn đó.
class WardrobeShop extends ConsumerStatefulWidget {
  const WardrobeShop({super.key});
  @override
  ConsumerState<WardrobeShop> createState() => _WardrobeShopState();
}

/// Ngăn đang mở (giữ khi quay lại phòng, như biến roomSlot của web).
String _roomSlot = 'hat';

class _WardrobeShopState extends ConsumerState<WardrobeShop> {
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    final data = ref.watch(appDataProvider);
    final i18n = ref.watch(i18nProvider);
    final p = store.profile!;
    final owned = p.owned.toSet();
    final o = p.outfit;
    final fs = baseFontSize(context);
    return Column(spacing: 12, children: [
      // Hàng chọn ngăn (.seg với biểu tượng to)
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.segBg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
          for (final (k, ic) in kWardrobeSlots)
            GestureDetector(
              key: Key('slot-$k'),
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                setState(() => _roomSlot = k);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 56, minWidth: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: k == _roomSlot ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: k == _roomSlot ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2))] : null,
                ),
                child: Text(ic, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ]),
      ),
      LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 130).floor().clamp(2, 6);
        final items = data.wardrobe.where((w) => w.slot == _roomSlot).toList();
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .86,
          children: [
            for (final w in items)
              Chunky(
                key: Key('ward-${w.id}'),
                radius: 22,
                depth: 5,
                pressScale: .94,
                color: o[w.slot] == w.id ? const Color(0xFFF0FFF4) : Colors.white,
                border: Border.all(color: o[w.slot] == w.id ? AppColors.good : Colors.transparent, width: 4),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                onTap: () => tapWardrobeItem(store, ref.read(audioProvider), w, context: context),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 2, children: [
                  Expanded(
                    child: w.bg != null && w.slot == 'bg'
                        ? AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(gradient: cssGradient(w.bg), borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.all(8),
                              child: EmojiImage(w.img, photo: false),
                            ),
                          )
                        : EmojiImage(w.img, photo: false),
                  ),
                  Text(i18n.L(w.json), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs * .85, color: AppColors.ink2, height: 1.1)),
                  if (owned.contains(w.id))
                    Text(o[w.slot] == w.id ? '✔' : i18n.t('wear'), style: TextStyle(color: AppColors.good, fontWeight: FontWeight.w800, fontSize: fs * .9))
                  else
                    Text('⭐ ${w.price}', style: TextStyle(color: const Color(0xFFB07D00), fontWeight: FontWeight.w800, fontSize: fs * .9)),
                ]),
              ),
          ],
        );
      }),
    ]);
  }
}
