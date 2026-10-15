// Đảo Tô màu + Lập trình: chơi hết một bài (tô tranh, vẽ tự do, tưới mầm, đoán đích) với SilentAudio;
// lưu tranh vào kho; dựng mọi bài ở các cỡ màn (điện thoại dọc/ngang, máy tính bảng) không tràn.
import 'dart:io';
import 'dart:typed_data';

import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/features/learn/creative/art.dart';
import 'package:be_vui_hoc/features/learn/creative/code.dart';
import 'package:be_vui_hoc/features/learn/creative/code_engine.dart';
import 'package:be_vui_hoc/features/learn/creative/logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  setUpAll(loadBundle);

  test('tranh: đủ vùng như bảng màu sẵn, chạm trúng vùng trên cùng', () {
    for (final page in kPages) {
      expect(pageRegions(page).length, kPreset[page]!.length, reason: page);
    }
    // nhà: cửa (vùng 8) nằm trên tường (vùng 6)
    expect(hitRegion('house', const Offset(200, 220)), 8);
    expect(hitRegion('house', const Offset(10, 10)), 0);
    expect(hitRegion('butterfly', const Offset(200, 158)), 9);
  });

  test('saveArtwork ghi file và danh sách trong kho', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addProfile('Na', 'robot');
    final dir = await Directory.systemTemp.createTemp('art');
    debugArtDir = dir;
    final path = await saveArtwork(store, Uint8List.fromList([137, 80, 78, 71]), kind: 'house');
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    final list = savedArtworks(store);
    expect(list.single['kind'], 'house');
    expect(list.single['kid'], store.profile!.id);
    debugArtDir = null;
    await dir.delete(recursive: true);
  });

  testWidgets('Tô tranh: tô ít quá thì nhắc, tô đủ rồi Xong → 3 sao', (tester) async {
    final p = await pumpGame(tester, artModule, 'art', levelOf('artLevels', 'color'));
    await tester.pump();
    expect(p.buddyVisible, isFalse);
    expect(p.audio.log.any((l) => l.startsWith('say:')), isTrue);
    await tester.tap(find.byKey(const Key('art-done')));
    await tester.pump();
    expect(p.stars, isNull);
    expect(p.audio.log, contains('sfx:wrong'));
    const page = 'house';
    final r = tester.getRect(find.byKey(const Key('art-page')));
    final regs = pageRegions(page);
    var k = 0;
    for (var i = 0; i < regs.length; i++) {
      // điểm trên cùng thuộc vùng i
      final b = regs[i].bounds;
      Offset? pt;
      for (var y = b.top + 1; y < b.bottom && pt == null; y += 2) {
        for (var x = b.left + 1; x < b.right; x += 2) {
          if (hitRegion(page, Offset(x, y)) == i) {
            pt = Offset(x, y);
            break;
          }
        }
      }
      if (pt == null) continue;
      await tester.tap(find.byKey(Key('sw-${k++ % kArtPalette.length}')));
      await tester.tapAt(r.topLeft + Offset(pt.dx * r.width / 400, pt.dy * r.height / 300));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('art-done')));
    await tester.pump();
    expect(p.stars, 3);
    expect(p.progress, (1, 1));
    await unmount(tester, p);
  });

  testWidgets('Vẽ tự do: 3 nét (bút, cầu vồng, hình dán) rồi Xong → 3 sao; hoàn tác/xoá', (tester) async {
    final p = await pumpGame(tester, artModule, 'art', levelOf('artLevels', 'draw'), size: const Size(844, 390));
    final c = tester.getRect(find.byKey(const Key('draw-canvas')));
    await tester.dragFrom(c.center, const Offset(60, 20));
    await tester.pump();
    await tester.tap(find.byKey(const Key('art-done')), warnIfMissed: false);
    await tester.pump();
    expect(p.stars, isNull); // chưa đủ 3 nét
    await tester.tap(find.byKey(const Key('tool-0'))); // cầu vồng
    await tester.dragFrom(c.center + const Offset(-80, -30), const Offset(90, 40));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('stamp-Star')));
    await tester.tap(find.byKey(const Key('stamp-Star')));
    await tester.tapAt(c.center + const Offset(-120, 10));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('draw-undo')));
    await tester.tap(find.byKey(const Key('draw-undo')));
    await tester.tap(find.byKey(const Key('draw-clear')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('art-done')));
    await tester.tap(find.byKey(const Key('art-done')));
    await tester.pump();
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  Future<void> tapCmds(WidgetTester tester, List<Object> sol) async {
    for (final it in sol) {
      final c = it as String;
      await tester.ensureVisible(find.byKey(Key('cd-pad-$c')));
      await tester.tap(find.byKey(Key('cd-pad-$c')));
      await tester.pump();
    }
  }

  testWidgets('Lập trình — Tưới mầm cây: 3 đề, giải bằng lời giải ngắn nhất → 3 sao', (tester) async {
    final p = await pumpGame(tester, codeModule, 'code', levelOf('codeLevels', 'garden', 'Tưới mầm cây'));
    for (var i = 0; i < 3; i++) {
      await pumpUntil(tester, () => CodeView.debugPuzzle != null && p.progress.$1 == i);
      final m = CodeView.debugPuzzle!;
      if (i == 0) {
        // chạy chương trình rỗng → rung, không chạy
        await tester.ensureVisible(find.byKey(const Key('cd-run')));
        await tester.tap(find.byKey(const Key('cd-run')));
        await tester.pump();
      }
      await tapCmds(tester, m.sol);
      await tester.ensureVisible(find.byKey(const Key('cd-run')));
      await tester.tap(find.byKey(const Key('cd-run')));
      await pumpUntil(tester, () => p.progress.$1 > i || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    expect(p.audio.log, contains('sfx:coin'));
    await unmount(tester, p);
  });

  testWidgets('Lập trình — Lặp lại: dựng thẻ lặp bằng chạm (×n, đầu khối) → 3 sao', (tester) async {
    final p = await pumpGame(tester, codeModule, 'code', levelOf('codeLevels', 'loop', 'Lặp lại hàng cây'), size: const Size(1024, 768));
    for (var i = 0; i < 3; i++) {
      await pumpUntil(tester, () => CodeView.debugPuzzle != null && p.progress.$1 == i);
      final m = CodeView.debugPuzzle!;
      for (final it in m.sol) {
        if (it is Rep) {
          final blk = m.sol.indexOf(it);
          await tester.tap(find.byKey(const Key('cd-pad-REP')));
          await tester.pump();
          for (final c in it.body) {
            await tester.tap(find.byKey(Key('cd-pad-$c')));
            await tester.pump();
          }
          for (var r = 2; r < it.rep; r++) {
            await tester.tap(find.byKey(Key('cd-chip-$blk')));
            await tester.pump();
          }
          await tester.tap(find.byKey(Key('cd-bhead-$blk'))); // ra khỏi khối
          await tester.pump();
        } else {
          await tester.tap(find.byKey(Key('cd-pad-$it')));
          await tester.pump();
        }
      }
      await tester.tap(find.byKey(const Key('cd-run')));
      await pumpUntil(tester, () => p.progress.$1 > i || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  testWidgets('Lập trình — Tìm thẻ sai: thay thẻ sai bằng thẻ đúng → 3 sao', (tester) async {
    final p = await pumpGame(tester, codeModule, 'code', levelOf('codeLevels', 'debug', 'Tìm thẻ sai'));
    for (var i = 0; i < 3; i++) {
      await pumpUntil(tester, () => CodeView.debugPuzzle != null && p.progress.$1 == i);
      final m = CodeView.debugPuzzle!;
      final at = m.wrong!;
      final right = m.sol[int.parse(at)] as String;
      await tester.ensureVisible(find.byKey(Key('cd-at-$at')));
      await tester.tap(find.byKey(Key('cd-at-$at')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(Key('cd-pad-$right')));
      await tester.tap(find.byKey(Key('cd-pad-$right')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('cd-run')));
      await tester.tap(find.byKey(const Key('cd-run')));
      await pumpUntil(tester, () => p.progress.$1 > i || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  testWidgets('Lập trình — Robot dừng ở đâu: đoán đúng 5 câu → 3 sao', (tester) async {
    final p = await pumpGame(tester, codeModule, 'code', levelOf('codeLevels', 'trace', 'Robot dừng ở đâu?'));
    for (var q = 0; q < 5; q++) {
      await pumpUntil(tester, () => CodeView.debugPuzzle != null && p.progress.$1 == q);
      await tester.pump(const Duration(milliseconds: 50));
      final end = CodeView.debugPuzzle!.end!;
      await tester.tap(find.byKey(Key('cd-cell-${end.$1}-${end.$2}')));
      await pumpUntil(tester, () => p.progress.$1 > q || p.stars != null);
    }
    await pumpUntil(tester, () => p.stars != null);
    expect(p.stars, 3);
    await unmount(tester, p);
  });

  // Dựng mọi bài ở các cỡ màn: không lỗi tràn khung.
  for (final size in const [Size(390, 844), Size(844, 390), Size(1024, 1366), Size(1366, 1024)]) {
    testWidgets('dựng mọi bài ở cỡ ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      for (final (key, game, mod) in [('logicLevels', 'logic', logicModule), ('codeLevels', 'code', codeModule), ('artLevels', 'art', artModule)]) {
        final n = bundle.content.list(key).length;
        for (var li = 0; li < n; li++) {
          final p = await pumpGame(tester, mod, game, li, size: size);
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull, reason: '$game $li');
          await unmount(tester, p);
        }
      }
    });
  }
}
