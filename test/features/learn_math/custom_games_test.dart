// Chơi hết một bài của các màn tự dựng: siêu thị, cân, thứ, lịch, trí nhớ, khám phá, âm nhạc.
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/learn/math/explore.dart';
import 'package:be_vui_hoc/features/learn/math/life.dart';
import 'package:be_vui_hoc/features/learn/math/memory.dart';
import 'package:be_vui_hoc/features/learn/math/music.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });

  int lifeLi(String kind, [int types = 0]) =>
      bundle.content.list('lifeLevels').indexWhere((l) => l['kind'] == kind && (types == 0 || l['types'] == types));

  for (final (types, size) in [(1, const Size(390, 844)), (3, const Size(1024, 768))]) {
    testWidgets('Siêu thị $types món: lấy đúng hàng → 3 sao', (tester) async {
      final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('shop', types), size: size);
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.buddyVisible, isFalse);
      for (var r = 0; r < 5; r++) {
        await pumpUntil(tester, () => h.progI == r && find.byKey(const Key('deliver')).evaluate().isNotEmpty);
        final order = debugLifeAnswer as Map<String, int>;
        expect(order.length, types);
        for (final e in order.entries) {
          for (var k = 0; k < e.value; k++) {
            await tester.tap(find.byKey(Key('shelf-${e.key}')));
            await tester.pump();
          }
        }
        await tester.tap(find.byKey(const Key('deliver')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await pumpUntil(tester, () => h.stars != null);
      expect(h.stars, 3);
      expect(h.audio.log.where((l) => l == 'sfx:correct').length, 5);
      await unmount(tester);
    });
  }

  testWidgets('Siêu thị: giao sai rồi bớt hàng thừa → 2 sao', (tester) async {
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('shop', 1));
    for (var r = 0; r < 5; r++) {
      await pumpUntil(tester, () => h.progI == r && find.byKey(const Key('deliver')).evaluate().isNotEmpty);
      final order = debugLifeAnswer as Map<String, int>;
      final e = order.entries.first;
      for (var k = 0; k < e.value + (r == 0 ? 1 : 0); k++) {
        await tester.tap(find.byKey(Key('shelf-${e.key}')));
        await tester.pump();
      }
      if (r == 0) {
        await tester.tap(find.byKey(const Key('deliver')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(h.audio.log, contains('sfx:wrong'));
        await tester.tap(find.byKey(Key('bitem-${e.key}-0')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('deliver')));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 2);
    await unmount(tester);
  });

  testWidgets('Cân đĩa: chọn bên nặng → 3 sao', (tester) async {
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('weight'), size: const Size(390, 844));
    for (var r = 0; r < 6; r++) {
      await pumpUntil(tester, () => h.progI == r && find.byKey(const Key('w-a')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Key('w-$debugLifeAnswer')));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 3);
    await unmount(tester);
  });

  testWidgets('Thứ trong tuần: chọn đúng ngày → 3 sao', (tester) async {
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('week'), size: const Size(390, 844));
    for (var r = 0; r < 6; r++) {
      await pumpUntil(tester, () => h.progI == r && find.byKey(const Key('day-0')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Key('day-$debugLifeAnswer')));
      await tester.pump(const Duration(milliseconds: 1500));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 3);
    await unmount(tester);
  });

  testWidgets('Thứ trong tuần trên điện thoại nhỏ, chữ to: ô ngày không tràn', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('week'), size: const Size(320, 640));
    await pumpUntil(tester, () => find.byKey(const Key('day-0')).evaluate().isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(h.stars, isNull);
    await unmount(tester);
  });

  testWidgets('Siêu thị trên điện thoại: giỏ đủ bề ngang, nút Giao hàng ở dưới, kệ không bị đẩy khi thêm hàng', (tester) async {
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('shop', 1), size: const Size(390, 844));
    await pumpUntil(tester, () => find.byKey(const Key('deliver')).evaluate().isNotEmpty);
    final basket = tester.getRect(find.byKey(const Key('basket')));
    final deliver = tester.getRect(find.byKey(const Key('deliver')));
    expect(deliver.top, greaterThan(basket.bottom), reason: 'nút nằm dưới giỏ');
    final order = debugLifeAnswer as Map<String, int>;
    final shelfKey = Key('shelf-${order.keys.first}');
    final y0 = tester.getRect(find.byKey(shelfKey)).top;
    for (var k = 0; k < 5; k++) {
      await tester.tap(find.byKey(shelfKey));
      await tester.pump();
    }
    expect(tester.getRect(find.byKey(shelfKey)).top, y0, reason: '5 món vẫn vừa một hàng giỏ');
    expect(h.stars, isNull);
    await unmount(tester);
  });

  testWidgets('Xem lịch: tìm đúng ngày → 3 sao', (tester) async {
    final h = await pumpGame(tester, bundle, lifeModule, island: 'life', li: lifeLi('calendar'));
    for (var r = 0; r < 5; r++) {
      await pumpUntil(tester, () => h.progI == r && find.byKey(const Key('cd-1')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Key('cd-$debugLifeAnswer')));
      await tester.pump(const Duration(milliseconds: 1000));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 3);
    expect(h.buddyVisible, isFalse);
    await unmount(tester);
  });

  for (final (li, size) in [(0, const Size(390, 844)), (4, const Size(1024, 768)), (12, const Size(844, 390))]) {
    testWidgets('Trí nhớ bài $li: lật đúng cặp → 3 sao', (tester) async {
      final h = await pumpGame(tester, bundle, memoryModule, island: 'memory', li: li, size: size);
      final deck = debugMemoryDeck!;
      final pairs = bundle.content.list('memoryLevels')[li]['pairs'] as int;
      expect(deck.length, pairs * 2);
      // Một lần lật sai trước (vẫn 3 sao vì ≤ số cặp).
      final j = deck.indexWhere((x) => x != deck[0]);
      await tester.tap(find.byKey(const Key('mcard-0')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(Key('mcard-$j')));
      await tester.pump(const Duration(milliseconds: 1200));
      final done = <int>{};
      for (var i = 0; i < deck.length; i++) {
        if (done.contains(i)) continue;
        final k = deck.indexWhere((x) => x == deck[i], i + 1);
        done.addAll([i, k]);
        await tester.tap(find.byKey(Key('mcard-$i')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(Key('mcard-$k')));
        await tester.pump(const Duration(milliseconds: 600));
      }
      await pumpUntil(tester, () => h.stars != null);
      expect(h.stars, 3);
      expect(h.progI, pairs);
      expect(h.audio.log, contains('sfx:flip'));
      await unmount(tester);
    });
  }

  test('memoryStars', () {
    expect(memoryStars(3, 3), 3);
    expect(memoryStars(6, 3), 2);
    expect(memoryStars(7, 3), 1);
  });

  for (final (li, size) in [(0, const Size(1024, 768)), (1, const Size(390, 844))]) {
    testWidgets('Khám phá bài $li: xếp đúng giỏ → 3 sao', (tester) async {
      final h = await pumpGame(tester, bundle, exploreModule, island: 'explore', li: li, size: size);
      for (var i = 0; i < 8; i++) {
        await pumpUntil(tester, () => h.progI == i && find.byKey(const Key('sort-card')).evaluate().isNotEmpty);
        if (h.progN == 0) break;
        await tester.tap(find.byKey(Key('basket-$debugExploreSide')));
        await tester.pump(const Duration(milliseconds: 500));
      }
      await pumpUntil(tester, () => h.stars != null);
      expect(h.stars, 3);
      expect(h.progI, h.progN);
      await unmount(tester);
    });
  }

  testWidgets('Khám phá: kéo thả vào giỏ sai → bớt sao, đúng thì qua', (tester) async {
    final h = await pumpGame(tester, bundle, exploreModule, island: 'explore', li: 0);
    await pumpUntil(tester, () => find.byKey(const Key('sort-card')).evaluate().isNotEmpty);
    final wrong = debugExploreSide == 'a' ? 'b' : 'a';
    await tester.drag(find.byKey(const Key('sort-card')), tester.getCenter(find.byKey(Key('basket-$wrong'))) - tester.getCenter(find.byKey(const Key('sort-card'))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.audio.log, contains('sfx:wrong'));
    await tester.drag(
        find.byKey(const Key('sort-card')), tester.getCenter(find.byKey(Key('basket-$debugExploreSide'))) - tester.getCenter(find.byKey(const Key('sort-card'))));
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.progI, 1);
    for (var i = 1; i < 8; i++) {
      await pumpUntil(tester, () => h.progI == i && find.byKey(const Key('sort-card')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Key('basket-$debugExploreSide')));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 2);
    await unmount(tester);
  });

  int musicLi(String kind) => bundle.content.list('musicLevels').indexWhere((l) => l['kind'] == kind);

  testWidgets('Đàn tự do: gõ 8 phím rồi Xong → 3 sao', (tester) async {
    final h = await pumpGame(tester, bundle, musicModule, island: 'music', li: musicLi('free'), size: const Size(844, 390));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.buddyVisible, isFalse);
    await tester.tap(find.byKey(const Key('music-done')));
    await tester.pump();
    expect(h.stars, isNull);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(Key('xkey-$i')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(h.audio.log.where((l) => l.startsWith('note:')).length, 8);
    await tester.tap(find.byKey(const Key('music-done')));
    await tester.pump();
    expect(h.stars, 3);
    await unmount(tester);
  });

  testWidgets('Học bài hát: nghe mẫu rồi gõ đúng các nốt → 3 sao', (tester) async {
    final li = musicLi('song');
    final h = await pumpGame(tester, bundle, musicModule, island: 'music', li: li, size: const Size(390, 844));
    final lv = bundle.content.list('musicLevels')[li];
    final notes = (bundle.content.list('songs').firstWhere((s) => s['id'] == lv['song'])['notes'] as List).cast<int>();
    await tester.tap(find.byKey(const Key('music-listen')));
    await tester.pump(Duration(milliseconds: 420 * notes.length + 500));
    expect(h.audio.log.where((l) => l.startsWith('note:')).length, notes.length);
    // Một phím sai.
    await tester.tap(find.byKey(Key('xkey-${(notes[0] + 1) % 8}')));
    await tester.pump(const Duration(milliseconds: 100));
    for (final n in notes) {
      await tester.tap(find.byKey(Key('xkey-$n')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 3);
    expect(h.progI, notes.length);
    await unmount(tester);
  });

  testWidgets('Nhắc lại giai điệu: nhắc đúng tới mục tiêu → 3 sao', (tester) async {
    final li = musicLi('simon');
    final goal = bundle.content.list('musicLevels')[li]['goal'] as int;
    final h = await pumpGame(tester, bundle, musicModule, island: 'music', li: li);
    await pumpUntil(tester, () => debugSimonSeq != null);
    var len = 0;
    while (h.stars == null && len < goal) {
      final seq = List.of(debugSimonSeq!);
      len = seq.length;
      await tester.pump(Duration(milliseconds: 700 + seq.length * 520 + 300));
      for (final i in seq) {
        await tester.tap(find.byKey(Key('pad-$i')));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 100));
      if (len < goal) expect(debugSimonSeq!.length, len + 1);
    }
    await pumpUntil(tester, () => h.stars != null);
    expect(h.stars, 3);
    expect(h.progI, goal);
    await unmount(tester);
  });
}
