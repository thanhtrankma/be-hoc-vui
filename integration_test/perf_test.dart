// Đo hiệu năng trên máy thật / emulator (xem docs/PERF.md).
//   flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d emulator-5554
// Mỗi kịch bản: ghi FrameTiming (build/raster/tổng) trong lúc thao tác, kèm RSS + bộ đệm ảnh sau kịch bản.
// Kết quả: dòng "PERF|{json}" trên log + build/perf_*.json (do test_driver ghi).
// PERF_ONLY=snake,runner (dart-define) → chỉ chạy các kịch bản đó.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/audio/soloud_audio.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _only = String.fromEnvironment('PERF_ONLY');
const _budgetUs = 16667; // 60 Hz

final Map<String, Object?> _results = {};

double _pct(List<int> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * p).round();
  return sorted[i] / 1000;
}

Map<String, Object?> _stats(List<FrameTiming> t) {
  final build = [for (final f in t) f.buildDuration.inMicroseconds]..sort();
  final raster = [for (final f in t) f.rasterDuration.inMicroseconds]..sort();
  final total = [for (final f in t) f.totalSpan.inMicroseconds]..sort();
  double avg(List<int> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length / 1000;
  final jank = t.where((f) => f.buildDuration.inMicroseconds > _budgetUs || f.rasterDuration.inMicroseconds > _budgetUs).length;
  double r(double v) => (v * 100).roundToDouble() / 100;
  return {
    'frames': t.length,
    'build_avg': r(avg(build)),
    'build_p90': r(_pct(build, .9)),
    'build_p99': r(_pct(build, .99)),
    'raster_avg': r(avg(raster)),
    'raster_p90': r(_pct(raster, .9)),
    'raster_p99': r(_pct(raster, .99)),
    'total_p90': r(_pct(total, .9)),
    'worst': r(total.isEmpty ? 0 : total.last / 1000),
    'jank_frames': jank,
    'jank_pct': r(t.isEmpty ? 0 : jank * 100 / t.length),
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('perf scenarios', (tester) async {
    Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

    // ---------- Khởi động (như main(), bỏ Firebase) ----------
    final sw = Stopwatch()..start();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final bundle = await loadContentBundle();
    final tContent = sw.elapsedMilliseconds;
    final store = AppStore(prefs);
    final audio = SoloudAudio(voice: bundle.voice, store: store);
    final audioSw = Stopwatch()..start();
    final audioInit = audio.init().then((_) => audioSw.elapsedMilliseconds);
    // Bé có sẵn tiến độ + thú cưng + nhiều vé.
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
        audioProvider.overrideWithValue(audio),
      ],
      child: const BeVuiHocApp(),
    ));
    await binding.waitUntilFirstFrameRasterized;
    final tFirst = sw.elapsedMilliseconds;
    final tAudio = await audioInit;
    _results['startup'] = {'content_ms': tContent, 'first_frame_ms': tFirst, 'audio_init_ms': tAudio};
    debugPrint('PERF|${jsonEncode({'startup': _results['startup']})}');

    final container = ProviderScope.containerOf(tester.element(find.byType(BeVuiHocApp)));
    GoRouter router() => container.read(routerProvider);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final rnd = math.Random(7);

    Future<void> measure(String name, Future<void> Function() body, {String? go, int settle = 1500}) async {
      if (_only.isNotEmpty && !_only.split(',').contains(name)) return;
      try {
        if (go != null) {
          router().go(go);
          await wait(settle);
        }
        await wait(1200); // xả FrameTiming cũ (máy gửi theo lô)
        final frames = <FrameTiming>[];
        void cb(List<FrameTiming> t) => frames.addAll(t);
        SchedulerBinding.instance.addTimingsCallback(cb);
        await body();
        await wait(1200);
        SchedulerBinding.instance.removeTimingsCallback(cb);
        final s = _stats(frames);
        s['rss_mb'] = (ProcessInfo.currentRss / 1048576).round();
        s['img_cache_mb'] = (imageCache.currentSizeBytes / 1048576 * 10).round() / 10;
        s['img_live'] = imageCache.liveImageCount;
        _results[name] = s;
        debugPrint('PERF|${jsonEncode({name: s})}');
      } catch (e, st) {
        debugPrint('PERF|${jsonEncode({name: 'ERROR $e'})}\n$st');
        _results[name] = 'ERROR $e';
      }
    }

    Future<void> tapAt(Offset o) async {
      await tester.tapAt(o);
    }

    Future<void> drag(Offset from, Offset by, {int steps = 12, int ms = 16}) async {
      final g = await tester.startGesture(from);
      for (var i = 0; i < steps; i++) {
        await g.moveBy(by / steps.toDouble());
        await wait(ms);
      }
      await g.up();
    }

    Future<void> tapKey(String k) async {
      final f = find.byKey(Key(k));
      if (f.evaluate().isNotEmpty) await tester.tap(f.first, warnIfMissed: false);
    }

    Finder keyPrefix(String pre) =>
        find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(pre)).hitTestable();

    // Chơi chung cho game canvas/Flame: chạm, vuốt 4 hướng, giữ.
    Future<void> play(int ms) async {
      final c = size.center(Offset.zero);
      final end = DateTime.now().add(Duration(milliseconds: ms));
      var k = 0;
      while (DateTime.now().isBefore(end)) {
        switch (k++ % 5) {
          case 0:
            await tapAt(c + Offset(rnd.nextDouble() * 120 - 60, rnd.nextDouble() * 160));
          case 1:
            await drag(c, const Offset(120, 0), steps: 6);
          case 2:
            await drag(c, const Offset(0, -120), steps: 6);
          case 3:
            await drag(c, const Offset(-120, 0), steps: 6);
          default:
            await drag(c, const Offset(0, 120), steps: 6);
        }
        await wait(250);
      }
    }

    // ---------- Màn đầu → bản đồ ----------
    await measure('start_idle', () => wait(3000));
    await measure('start_to_map', () async {
      await tapKey('start-btn');
      await wait(3000);
    });
    await measure('map_scroll', () async {
      final c = size.center(Offset.zero);
      for (var i = 0; i < 3; i++) {
        await tester.flingFrom(c, const Offset(0, -500), 1500);
        await wait(900);
      }
      for (var i = 0; i < 3; i++) {
        await tester.flingFrom(c, const Offset(0, 500), 1500);
        await wait(900);
      }
    }, go: '/map');
    await measure('island_open', () async {
      router().go('/island/count');
      await wait(2500);
      final c = size.center(Offset.zero);
      await tester.flingFrom(c, const Offset(0, -400), 1200);
      await wait(1200);
    }, go: '/map');
    await measure('quiz_play', () async {
      final end = DateTime.now().add(const Duration(seconds: 14));
      while (DateTime.now().isBefore(end)) {
        final ch = keyPrefix('choice-');
        final n = ch.evaluate().length;
        if (n > 0) {
          await tester.tap(ch.at(rnd.nextInt(n)), warnIfMissed: false);
        } else {
          await tapKey('res-next');
        }
        await wait(700);
      }
    }, go: '/play/letters/0', settle: 2500);
    await measure('trace_draw', () async {
      final b = find.byKey(const Key('trace-board'));
      if (b.evaluate().isEmpty) return;
      final r = tester.getRect(b.first);
      for (var i = 0; i < 8; i++) {
        await drag(r.topLeft + Offset(r.width * (.2 + .08 * i), r.height * .2), Offset(r.width * .1, r.height * .6), steps: 30);
        await wait(200);
      }
    }, go: '/play/trace/0', settle: 2500);
    await measure('draw_free', () async {
      final b = find.byKey(const Key('draw-canvas'));
      if (b.evaluate().isEmpty) return;
      final r = tester.getRect(b.first);
      for (var i = 0; i < 8; i++) {
        await drag(r.center + Offset(-r.width * .3, -r.height * .3 + i * 20), Offset(r.width * .6, r.height * .2), steps: 30);
        await wait(150);
      }
    }, go: '/play/art/0', settle: 2500);
    await measure('color_page', () async {
      final b = find.byKey(const Key('art-page'));
      if (b.evaluate().isEmpty) return;
      final r = tester.getRect(b.first);
      for (var i = 0; i < 12; i++) {
        await tapKey('sw-${i % 8}');
        await wait(150);
        await tapAt(r.topLeft + Offset(r.width * (.15 + .7 * rnd.nextDouble()), r.height * (.15 + .7 * rnd.nextDouble())));
        await wait(350);
      }
    }, go: '/play/art/1', settle: 2500);
    await measure('pet_room', () async {
      await wait(2000);
      await tapKey('pet-toy');
      await wait(2500);
      final f = keyPrefix('food-');
      if (f.evaluate().isNotEmpty) await tester.tap(f.first, warnIfMissed: false);
      await wait(2500);
    }, go: '/pet', settle: 2500);
    await measure('fun_hub_scroll', () async {
      final c = size.center(Offset.zero);
      for (var i = 0; i < 4; i++) {
        await tester.flingFrom(c, const Offset(0, -600), 2000);
        await wait(900);
      }
      for (var i = 0; i < 4; i++) {
        await tester.flingFrom(c, const Offset(0, 600), 2000);
        await wait(900);
      }
    }, go: '/fun', settle: 2500);

    // ---------- Game canvas + Flame ----------
    for (final g in const ['snake', 'runner', 'pacman', 'match3', 'breakout', 'hero', 'hunt', 'racer', 'shooter', 'tank', 'fighter']) {
      await measure('game_$g', () async {
        for (final k in const ['shop-play', 'hero-play', 'hunt-play', 'vs-bot']) {
          if (find.byKey(Key(k)).evaluate().isNotEmpty) {
            await tapKey(k);
            await wait(1500);
            break;
          }
        }
        await play(9000);
      }, go: '/fun/$g', settle: 3000);
      router().go('/fun');
      await wait(800);
    }

    // ---------- RPG ----------
    await measure('rpg_town', () => wait(4000), go: '/rpg', settle: 2500);
    await measure('rpg_stage', () => play(10000), go: '/rpg/0/0', settle: 3500);
    router().go('/map');
    await wait(1500);

    // ---------- Âm thanh: nạp (giải mã) file Opus giọng đọc theo yêu cầu ----------
    if (_only.isEmpty || _only.split(',').contains('audio')) {
      try {
        final assets = bundle.voice.index.values.toList()..shuffle(math.Random(3));
        final times = <int>[];
        for (final a in assets.take(30)) {
          final s = Stopwatch()..start();
          final src = await SoLoud.instance.loadAsset('assets/audio/$a');
          times.add(s.elapsedMicroseconds);
          await SoLoud.instance.disposeSource(src);
        }
        times.sort();
        _results['audio_voice_load'] = {
          'n': times.length,
          'avg_ms': (times.reduce((a, b) => a + b) / times.length / 1000).toStringAsFixed(1),
          'p90_ms': _pct(times, .9).toStringAsFixed(1),
          'max_ms': (times.last / 1000).toStringAsFixed(1),
        };
      } catch (e) {
        _results['audio_voice_load'] = 'ERROR $e';
      }
      debugPrint('PERF|${jsonEncode({'audio_voice_load': _results['audio_voice_load']})}');
    }

    binding.reportData = {'perf': _results};
    await tester.pumpWidget(const SizedBox());
    await wait(500);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
