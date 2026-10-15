// Mọi bài của mọi đảo trong dữ liệu web (content.json, cách chọn danh sách như levelsOf() của app.js) đều dựng được
// game thật (không phải chỗ trống "Đang xây dựng") và chạy ~1,2 giây không lỗi — ở cỡ điện thoại 390×844.
// Khác narrow_sweep_test (chỉ các kiểu bài khác nhau, 3 cỡ màn): ở đây là TỪNG bài một.
import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/levels.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Số bài mỗi đảo trong dữ liệu web (levelsOf: letterLevels, englishLevels, `<game>Levels`).
const kWebLevelCounts = {
  'letters': 32, 'spell': 247, 'trace': 28, 'read': 105, 'count': 19, 'math': 48, 'life': 10, 'english': 34,
  'memory': 14, 'logic': 25, 'code': 20, 'arcade': 10, 'music': 7, 'art': 7, 'explore': 41,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });

  test('đủ 15 đảo học, số bài từng đảo đúng như dữ liệu web', () {
    expect({for (final isl in bundle.data.gameIslands) isl.id: levelsOf(isl, bundle.content).length}, kWebLevelCounts);
  });

  for (final islId in kWebLevelCounts.keys) {
    testWidgets('đảo $islId: mọi bài dựng được game và chạy không lỗi', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = AppStore((await tester.runAsync(SharedPreferences.getInstance))!);
      final p = store.addProfile('Na', 'robot');
      store.updateProfile(p.id, {'tier': 3});
      store.setSetting('limit', 0);
      final audio = SilentAudio(voice: bundle.voice, store: store);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          contentBundleProvider.overrideWithValue(bundle),
          storeProvider.overrideWith((ref) => store),
          audioProvider.overrideWithValue(audio),
          startedProvider.overrideWith((ref) => true),
        ],
        child: const BeVuiHocApp(),
      ));
      await tester.pump();
      final router = ProviderScope.containerOf(tester.element(find.byType(BeVuiHocApp))).read(routerProvider);
      final problems = <String>[];
      final old = FlutterError.onError;
      var where = '';
      FlutterError.onError = (d) => problems.add('[$where] ${d.exceptionAsString().split('\n').first}');
      try {
        final isl = bundle.data.island(islId)!;
        for (final l in levelsOf(isl, bundle.content)) {
          where = '/play/$islId/${l.i}';
          router.go(where);
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          for (var t = 0; t < 12; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final e = tester.takeException();
          if (e != null) problems.add('[$where] $e');
          if (find.byKey(const Key('under-construction')).evaluate().isNotEmpty || find.byKey(const Key('placeholder-finish')).evaluate().isNotEmpty) {
            problems.add('[$where] chưa có game');
          }
          if (find.byKey(const Key('play-back')).evaluate().isEmpty) problems.add('[$where] không mở được màn chơi');
        }
        router.go('/map');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 6));
      } finally {
        FlutterError.onError = old;
      }
      expect(problems, isEmpty, reason: problems.take(20).join('\n'));
      expect(router, isA<GoRouter>());
    });
  }
}
