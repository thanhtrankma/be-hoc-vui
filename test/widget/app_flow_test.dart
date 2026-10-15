// Luồng chính: Bắt đầu → tạo hồ sơ → chọn cấp → bản đồ → danh sách bài → màn chơi (game giữ chỗ) → bảng kết quả.
import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';
import 'package:be_vui_hoc/core/game/registry.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/room/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
    // Khung app được thử với game giả; game thật có test riêng trong test/features/.
    debugGameOverrides['count'] = const PlaceholderGame('count', owner: 'test', webFile: 'count.js');
    debugGameOverrides['pick'] = const PlaceholderGame('pick', owner: 'test', webFile: 'pick.js');
    debugFunOverrides['racer'] = const PlaceholderFunGame('racer', owner: 'test', webFile: 'funracer.js');
  });

  Future<(AppStore, SilentAudio)> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final store = AppStore(await SharedPreferences.getInstance());
    final audio = SilentAudio(voice: bundle.voice, store: store);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(audio),
      ],
      child: const BeVuiHocApp(),
    ));
    await tester.pumpAndSettle();
    return (store, audio);
  }

  /// Gỡ app để huỷ timer đếm giờ chơi.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('màn Bắt đầu không tràn trên máy Android hẹp (320, 360dp)', (tester) async {
    for (final size in const [Size(320, 640), Size(360, 780)]) {
      await pumpApp(tester, size: size);
      expect(tester.takeException(), isNull, reason: '$size');
      await unmount(tester);
    }
  });

  testWidgets('màn Bắt đầu như web', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('logo')), findsOneWidget);
    expect(find.text('Vừa học vừa chơi'), findsOneWidget);
    expect(find.textContaining('Bắt đầu'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Bắt đầu → tạo bé → chọn cấp → bản đồ → bài → chơi → kết quả', (tester) async {
    final (store, audio) = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('start-btn')));
    await tester.pumpAndSettle();
    expect(audio.log, contains('sfx:win'));
    // Bước 1: tên
    expect(find.text('Tên của bé là gì?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name-input')), 'Na');
    await tester.pump();
    await tester.tap(find.byKey(const Key('name-next')));
    await tester.pumpAndSettle();
    // Bước 2: linh vật
    expect(find.text('Chọn bạn đồng hành'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mascot-robot')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('lets-go')));
    await tester.pumpAndSettle();
    expect(store.profile!.name, 'Na');
    expect(store.profile!.mascot, 'robot');
    // Bản đồ: chưa có cấp → hỏi cấp
    expect(find.text('Bé học cấp nào?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tier-1')));
    await tester.pumpAndSettle();
    expect(store.profile!.tier, 1);
    expect(find.text('Chào Na!'), findsOneWidget);
    expect(find.byKey(const Key('daily')), findsOneWidget);
    // Đảo Số đếm
    await tester.scrollUntilVisible(find.byKey(const Key('island-count')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('island-count')));
    await tester.pumpAndSettle();
    expect(find.text('Số đếm'), findsOneWidget);
    expect(find.byKey(const Key('levels-done')), findsOneWidget);
    expect(audio.log, contains('say:${bundle.voice.phrase('countIntro', 'vi').key}'));
    // Bài đầu tiên của cấp Mầm
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('under-construction')), findsOneWidget);
    expect(find.byKey(const Key('play-back')), findsOneWidget);
    // Xong bài (nút thử của game giữ chỗ) → bảng kết quả, 3 sao
    await tester.tap(find.byKey(const Key('placeholder-finish')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('result-panel')), findsOneWidget);
    expect(find.text('Giỏi quá!'), findsOneWidget);
    expect(store.levelStars(store.profile!, 'count', 0), 3);
    expect(store.profile!.stars, 3);
    expect(store.tickets(store.profile!), 3); // 2 vé ban đầu + 1
    expect(find.byKey(const Key('res-next')), findsOneWidget);
    // Bài tiếp
    await tester.tap(find.byKey(const Key('res-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('under-construction')), findsOneWidget);
    // Quay lại danh sách bài: bài 1 đã có sao
    await tester.tap(find.byKey(const Key('play-back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('nhiều bé → chọn bé; khoá bố mẹ; đảo đặc biệt', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final (store, _) = await pumpApp(tester, size: const Size(1024, 1366));
    store.addProfile('An', 'superhero');
    store.addProfile('Bin', 'robot');
    store.updateProfile(store.profile!.id, {'tier': 2});
    await tester.tap(find.byKey(const Key('start-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Ai đang chơi?'), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'kids');
    await tester.tap(find.text('Bin'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'map');
    expect(find.text('Chào Bin!'), findsOneWidget);
    // Khoá bố mẹ: huỷ thì không vào
    await tester.tap(find.byKey(const Key('parent-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Dành cho bố mẹ'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(find.text('Dành cho bố mẹ'), findsNothing);
    // Đảo đặc biệt → Phòng của bé
    await tester.tap(find.byKey(const Key('island-room')));
    await tester.pumpAndSettle();
    expect(find.byType(RoomScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Khu vui chơi: trừ vé, 3 cấp mỗi vé, bảng kết quả; chơi lại bài học', (tester) async {
    final (store, _) = await pumpApp(tester);
    store.addProfile('Na', 'robot');
    store.updateProfile(store.profile!.id, {'tier': 1});
    await tester.tap(find.byKey(const Key('start-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Chào Na!'), findsOneWidget);
    // Bài học → Chơi lại dựng lại bài
    await tester.scrollUntilVisible(find.byKey(const Key('island-letters')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('island-letters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('level-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeholder-finish')));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('res-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result-panel')), findsNothing);
    expect(find.byKey(const Key('placeholder-finish')), findsOneWidget);
    await tester.tap(find.byKey(const Key('play-back')));
    await tester.pumpAndSettle();
    // Vào thẳng game Đua xe (giữ chỗ)
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final before = store.tickets(store.profile!);
    container.read(routerProvider).go('/fun/racer');
    await tester.pumpAndSettle();
    expect(store.tickets(store.profile!), before - 1);
    for (var k = 0; k < 3; k++) {
      await tester.tap(find.text('Thắng (thử)'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('fun-result')), findsOneWidget);
    expect(store.funLevel(store.profile!, 'racer'), 3);
    expect(store.profile!.best['racer'], 30);
    await unmount(tester);
  });

  testWidgets('Khu vui chơi: game không vẽ dưới tai thỏ, nút ✕ dưới hàng HUD (như .funquit)', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
    final (store, _) = await pumpApp(tester);
    store.addProfile('Na', 'robot');
    await tester.tap(find.byKey(const Key('start-btn')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    container.read(routerProvider).go('/fun/racer');
    await tester.pumpAndSettle();
    final game = tester.getRect(find.byKey(const ValueKey('fun-0')));
    expect(game.top, 62);
    expect(game.bottom, 844 - 34); // chừa vạch Home / thanh điều hướng Android
    // Trong game, MediaQuery không còn lề trên (SafeArea của game không cộng thêm lần nữa).
    expect(MediaQuery.paddingOf(tester.element(find.text('Thắng (thử)'))).top, 0);
    expect(MediaQuery.paddingOf(tester.element(find.text('Thắng (thử)'))).bottom, 0);
    expect(tester.getRect(find.byKey(const Key('fun-quit'))).top, 62 + 70);
    await unmount(tester);
  });

  testWidgets('Back của Android = nút Quay lại / ✕ của màn; panel mở thì đóng panel trước', (tester) async {
    final (store, _) = await pumpApp(tester);
    store.addProfile('Na', 'robot');
    store.updateProfile(store.profile!.id, {'tier': 1});
    await tester.tap(find.byKey(const Key('start-btn')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final router = container.read(routerProvider);
    String path() => router.routerDelegate.currentConfiguration.uri.path;
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    router.go('/island/letters');
    await tester.pumpAndSettle();
    await back();
    expect(path(), '/map');
    // Màn chơi: Back = nút quay lại (về danh sách bài), không thoát app.
    router.go('/play/letters/0');
    await tester.pumpAndSettle();
    await back();
    expect(path(), '/island/letters');
    // Game khu vui chơi (trang lồng trên /fun): Back = ✕ → về Khu vui chơi.
    router.go('/fun/racer');
    await tester.pumpAndSettle();
    expect(find.text('Thắng (thử)'), findsOneWidget);
    await back();
    expect(path(), '/fun');
    // Panel đang mở: Back đóng panel, vẫn ở màn cũ.
    router.go('/room');
    await tester.pumpAndSettle();
    showPanel<void>(context: tester.element(find.byType(RoomScreen)), builder: (c) => const Text('panel-test'));
    await tester.pumpAndSettle();
    expect(find.text('panel-test'), findsOneWidget);
    await back();
    expect(find.text('panel-test'), findsNothing);
    expect(path(), '/room');
    await back();
    expect(path(), '/map');
    await unmount(tester);
  });
}
