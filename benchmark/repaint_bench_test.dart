// ignore_for_file: invalid_use_of_visible_for_testing_member
// Đo trên máy tính (không cần thiết bị), không phụ thuộc tốc độ máy: mỗi khung hình phải GHI LẠI bao nhiêu
// display list (PictureLayer mới) và bao nhiêu byte lệnh vẽ — tức là việc của luồng UI khi vẽ (paint) + việc
// luồng raster phải phát lại. Ít hơn = nhẹ hơn trên máy thật. Chạy riêng (không nằm trong `flutter test` mặc định):
//   flutter test benchmark/repaint_bench_test.dart
// In ra dòng "BENCH|{json}" cho từng kịch bản (xem docs/PERF.md).
import 'dart:convert';

import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late ContentBundle bundle;

/// Gom mọi PictureLayer đang có trên cây lớp.
void _collect(Layer? l, List<PictureLayer> out) {
  if (l == null) return;
  if (l is PictureLayer) out.add(l);
  if (l is ContainerLayer) {
    for (Layer? c = l.firstChild; c != null; c = c.nextSibling) {
      _collect(c, out);
    }
  }
}

List<PictureLayer> _pictures(WidgetTester tester) {
  final out = <PictureLayer>[];
  for (final v in tester.binding.renderViews) {
    _collect(v.debugLayer, out);
  }
  return out;
}

/// Chạy [frames] khung 16 ms (kèm [each] trước mỗi khung) và đếm display list được ghi lại.
Future<Map<String, num>> _measure(WidgetTester tester, int frames, {Future<void> Function(int i)? each}) async {
  var prev = _pictures(tester).toSet();
  var newPics = 0, newBytes = 0, total = 0, painted = 0;
  final types = <String, int>{};
  debugOnProfilePaint = (ro) {
    painted++;
    final k = ro.runtimeType.toString();
    types[k] = (types[k] ?? 0) + 1;
  };
  for (var i = 0; i < frames; i++) {
    if (each != null) await each(i);
    await tester.pump(const Duration(milliseconds: 16));
    final now = _pictures(tester);
    total += now.length;
    for (final p in now) {
      if (!prev.contains(p)) {
        newPics++;
        newBytes += p.picture?.approximateBytesUsed ?? 0;
      }
    }
    prev = now.toSet();
  }
  debugOnProfilePaint = null;
  final top = (types.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(4).map((e) => '${e.key}:${e.value ~/ frames}').join(' ');
  debugPrint('  top painted/frame: $top');
  return {'frames': frames, 'paints_per_frame': (painted / frames).round(), 'pics_per_frame': (newPics / frames * 10).round() / 10, 'kb_per_frame': (newBytes / frames / 1024 * 10).round() / 10, 'layers': (total / frames).round()};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    bundle = await loadContentBundle(rootBundle);
  });

  Future<(ProviderContainer, AppStore)> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore((await tester.runAsync(SharedPreferences.getInstance))!);
    final p = store.addProfile('Na', 'robot');
    store.updateProfile(p.id, {'tier': 1});
    p.json['tickets'] = 9999;
    p.json['pet'] = <String, dynamic>{
      'type': 'dog', 'name': 'Cún', 'xp': 40, 'food': 70, 'water': 70, 'clean': 80, 'happy': 80, 'energy': 90,
      'last': store.now().millisecondsSinceEpoch, 'wear': <String, dynamic>{},
    };
    store.save();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(SilentAudio(voice: bundle.voice, store: store)),
        startedProvider.overrideWith((ref) => true),
      ],
      child: const BeVuiHocApp(),
    ));
    await tester.pump();
    return (ProviderScope.containerOf(tester.element(find.byType(BeVuiHocApp))), store);
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String path) async {
    c.read(routerProvider).go(path);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  void report(String name, Map<String, num> m) => debugPrint('BENCH|${jsonEncode({name: m})}');

  testWidgets('repaint benchmark', (tester) async {
    final (c, _) = await pumpApp(tester);
    Future<void> scenario(String name, String path, int frames, {Future<void> Function(int i)? each}) async {
      await go(tester, c, path);
      report(name, await _measure(tester, frames, each: each));
    }

    await scenario('start_idle', '/', 120);
    await scenario('map_idle', '/map', 120);
    await scenario('map_scroll', '/map', 60, each: (i) async {
      await tester.dragFrom(const Offset(195, 500), Offset(0, i < 30 ? -40 : 40));
    });
    await scenario('island_idle', '/island/count', 120);
    await scenario('fun_hub_scroll', '/fun', 60, each: (i) async {
      await tester.dragFrom(const Offset(195, 500), Offset(0, i < 30 ? -40 : 40));
    });
    await scenario('pet_room', '/pet', 120);
    await scenario('trace_idle', '/play/trace/0', 120);
    // Bảng vẽ: 120 nét rồi đo lúc đang vẽ nét tiếp theo.
    await go(tester, c, '/play/art/0');
    final pad = find.byKey(const Key('draw-canvas'));
    if (pad.evaluate().isNotEmpty) {
      final r = tester.getRect(pad);
      for (var k = 0; k < 120; k++) {
        await tester.dragFrom(r.topLeft + Offset(10 + (k * 7) % (r.width - 40), 10 + (k * 13) % (r.height - 40)), const Offset(25, 18));
      }
      await tester.pump();
      final g = await tester.startGesture(r.center);
      report('draw_pad_120_strokes', await _measure(tester, 60, each: (i) => g.moveBy(Offset(i.isEven ? 3 : -2, 2))));
      await g.up();
    }
    await unmount(tester);
  });
}
