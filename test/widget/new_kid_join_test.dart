// Màn tạo bé: nút "🔑 Đã có mã gia đình" (kết nối máy chủ đồng bộ) phải qua khoá bố mẹ trước khi hỏi mã; chữ có bản tiếng Anh.
import 'dart:math';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/home/new_kid_screen.dart';
import 'package:be_vui_hoc/features/sync/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// nextInt luôn trả 0 → phép tính 12 × 3 = 36.
class _Zero implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });
  tearDown(() => debugGateRandom = null);

  Future<AppStore> pump(WidgetTester tester, {String lang = 'vi'}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.setSetting('lang', lang);
    final sync = SyncService(store, backend: MemorySyncBackend());
    final router = GoRouter(navigatorKey: rootNavigatorKey, initialLocation: '/new', routes: [
      GoRoute(path: '/new', builder: (c, s) => const NewKidScreen()),
      GoRoute(path: '/kids', builder: (c, s) => const Scaffold(body: Text('route:kids'))),
      GoRoute(path: '/map', builder: (c, s) => const Scaffold(body: Text('route:map'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(SilentAudio(voice: bundle.voice, store: store)),
        syncServiceProvider.overrideWithValue(sync),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> answer(WidgetTester tester, String s) async {
    for (final ch in RegExp(r'OK|.').allMatches(s).map((m) => m[0]!)) {
      await tester.tap(find.byKey(Key('gate-$ch')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('"Đã có mã gia đình": khoá bố mẹ trước, huỷ thì không hỏi mã; đúng thì mới hỏi mã', (tester) async {
    debugGateRandom = _Zero();
    await pump(tester);
    expect(find.text('🔑 Đã có mã gia đình'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-family')));
    await tester.pumpAndSettle();
    expect(find.text('Dành cho bố mẹ'), findsOneWidget);
    expect(find.textContaining('Nhập mã gia đình'), findsNothing);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nhập mã gia đình'), findsNothing);

    await tester.tap(find.byKey(const Key('join-family')));
    await tester.pumpAndSettle();
    await answer(tester, '36OK');
    expect(find.text('Dành cho bố mẹ'), findsNothing);
    expect(find.textContaining('Nhập mã gia đình'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.text('Mã gồm 16 chữ và số'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('tiếng Anh: nút, bảng hỏi mã và thông báo có bản tiếng Anh', (tester) async {
    debugGateRandom = _Zero();
    await pump(tester, lang: 'en');
    expect(find.text('🔑 I have a family code'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-family')));
    await tester.pumpAndSettle();
    await answer(tester, '36OK');
    expect(find.textContaining('Enter the family code'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.text('The code has 16 letters and digits'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
