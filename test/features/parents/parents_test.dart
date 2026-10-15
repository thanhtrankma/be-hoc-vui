// Góc bố mẹ, Báo cáo của con, bằng khen PNG. Không gọi mạng / file thật: ParentsIo và máy chủ đồng bộ đều là bản giả.
import 'dart:convert';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/parents/certificate.dart';
import 'package:be_vui_hoc/features/parents/parents.dart';
import 'package:be_vui_hoc/features/parents/report.dart';
import 'package:be_vui_hoc/features/sync/sync.dart';
import 'package:be_vui_hoc/features/sync/sync_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeIo extends ParentsIo {
  FakeIo();
  final saved = <String, String>{};
  final opened = <String>[];
  final shared = <String>[];
  String? toPick;
  @override
  Future<bool> saveBackup(String fileName, String json) async {
    saved[fileName] = json;
    return true;
  }

  @override
  Future<String?> pickBackup() async => toPick;
  @override
  Future<void> openUrl(String url) async => opened.add(url);
  @override
  Future<void> shareText(String text, {String? subject}) async => shared.add(text);
  @override
  Future<String> loadAssetText(String path) async => 'Tiếng thú cưng: test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  final now = DateTime(2026, 10, 15, 10);
  setUpAll(() async {
    Motion.enabled = false;
    bundle = await loadContentBundle(rootBundle);
  });

  Future<AppStore> newStore([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return AppStore(await SharedPreferences.getInstance(), clock: () => now);
  }

  // Máy chủ đồng bộ giả (không gọi datpilot.com thật).
  final boxes = <String, Map<String, dynamic>>{};
  final mock = MockClient((req) async {
    final sid = req.url.pathSegments.last;
    if (req.method == 'GET') return boxes[sid] == null ? http.Response('', 404) : http.Response(jsonEncode(boxes[sid]), 200);
    if (req.method == 'PUT') {
      final b = jsonDecode(req.body) as Map;
      final v = ((boxes[sid]?['v'] as int?) ?? 0) + 1;
      boxes[sid] = {'v': v, 'blob': b['blob']};
      return http.Response(jsonEncode({'v': v}), 200);
    }
    boxes.remove(sid);
    return http.Response('{}', 200);
  });
  final keyCache = <String, SyncKeys>{};
  Future<SyncKeys> derive(String c) async => keyCache[normalizeCode(c)] ??= await deriveSyncKeysDirect(c);

  Future<(AppStore, FakeIo, GoRouter, SilentAudio, SyncService)> pump(WidgetTester tester, AppStore store, {String at = '/parent'}) async {
    tester.view.physicalSize = const Size(430, 932) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final io = FakeIo();
    final audio = SilentAudio(voice: bundle.voice, store: store);
    final sync = SyncService(store, client: mock, derive: derive);
    Widget stub(String name) => Scaffold(body: Text('route:$name'));
    final router = GoRouter(navigatorKey: rootNavigatorKey, initialLocation: at, routes: [
      GoRoute(path: '/parent', builder: (c, s) => const ParentsScreen()),
      GoRoute(path: '/report/:id', builder: (c, s) => ReportScreen(kidId: s.pathParameters['id']!)),
      GoRoute(path: '/map', builder: (c, s) => stub('map')),
      GoRoute(path: '/kids', builder: (c, s) => stub('kids')),
      GoRoute(path: '/new', builder: (c, s) => stub('new')),
      GoRoute(path: '/review/:mode', builder: (c, s) => stub('review/${s.pathParameters['mode']}')),
      GoRoute(path: '/review/:mode/:item', builder: (c, s) => stub('review/${s.pathParameters['mode']}/${s.pathParameters['item']}')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(audio),
        parentsIoProvider.overrideWithValue(io),
        syncServiceProvider.overrideWithValue(sync),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    ));
    await tester.pumpAndSettle();
    return (store, io, router, audio, sync);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); // toast tự tắt
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String mascotId() => bundle.data.mascots.first.id;

  testWidgets('Góc bố mẹ: đủ các thẻ, đổi cài đặt, đổi ngôn ngữ', (tester) async {
    final store = await newStore();
    store.addProfile('Na', mascotId());
    final (_, _, router, audio, _) = await pump(tester, store);
    expect(find.text('Góc bố mẹ'), findsOneWidget);
    for (final t in ['Cài đặt', 'Các bé', 'Sao lưu tiến độ', '📱 Dùng trên nhiều máy', '💬 Góp ý, báo lỗi', '📣 Giới thiệu cho bạn bè', 'Nguồn ảnh và âm thanh', 'Phiên bản']) {
      await tester.scrollUntilVisible(find.text(t), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(t), findsOneWidget, reason: t);
    }
    Future<void> pick(String opt, String label) async {
      final f = find.descendant(of: find.byKey(Key('opt-$opt')), matching: find.text(label));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await pick('limit', '30′');
    expect(store.limitMinutes, 30);
    await pick('music', 'Tắt');
    expect(store.musicOn, isFalse);
    await pick('fun', 'Tắt');
    await pick('ticketsPer', '2 🎟️');
    await pick('lockOrder', 'Bật');
    expect(store.funOn, isFalse);
    expect(store.ticketsPer, 2);
    expect(store.lockOrder, isTrue);
    await pick('lang', 'English');
    expect(store.lang, 'en');
    expect(find.text('Parents'), findsOneWidget);
    expect(audio.log, contains('sfx:tap'));
    // Nút quay lại: có bé → bản đồ.
    await tapKey(tester, 'parent-back');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
  });

  testWidgets('Các bé: tặng vé (giữ bé đang chơi), đổi tên, xoá, thêm bé, mở báo cáo', (tester) async {
    final store = await newStore();
    final a = store.addProfile('Na', mascotId());
    final b = store.addProfile('Bin', mascotId());
    store.setActive(a.id);
    final (_, _, router, _, _) = await pump(tester, store);
    await tapKey(tester, 'give-${b.id}');
    expect(store.tickets(store.profileById(b.id)!), 5);
    expect(store.activeId, a.id);
    await settle(tester);

    await tapKey(tester, 'rename-${b.id}');
    await tester.enterText(find.byType(TextField), 'Bin Bin');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(store.profileById(b.id)!.name, 'Bin Bin');

    await tapKey(tester, 'remove-${b.id}');
    expect(find.textContaining('Xoá hồ sơ của Bin Bin'), findsOneWidget);
    await tester.tap(find.text('Xoá').last);
    await tester.pumpAndSettle();
    expect(store.profileById(b.id), isNull);
    expect(store.profiles.length, 1);

    await tapKey(tester, 'report-${a.id}');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/report/${a.id}');
    expect(find.text('📊 Báo cáo của Na'), findsOneWidget);
  });

  testWidgets('Sao lưu: tải file đúng định dạng web; khôi phục; file sai', (tester) async {
    final store = await newStore();
    store.addProfile('Na', mascotId());
    final (_, io, _, _, _) = await pump(tester, store);
    await tapKey(tester, 'backup-download');
    expect(io.saved.keys.single, 'be-vui-hoc-2026-10-15.json');
    final j = jsonDecode(io.saved.values.single) as Map;
    expect(j['app'], 'be-vui-hoc');
    expect(j['version'], 1);
    expect((j['data']['profiles'] as List).single['name'], 'Na');

    final other = await newStore();
    other.addProfile('Mít', mascotId());
    io.toPick = other.exportData();
    await tapKey(tester, 'backup-restore');
    expect(store.profiles.map((p) => p.name), ['Mít']);
    expect(find.text('Đã khôi phục tiến độ'), findsOneWidget);
    await settle(tester);

    io.toPick = '{"hello":1}';
    await tapKey(tester, 'backup-restore');
    expect(find.text('File không đúng'), findsOneWidget);
    expect(store.profiles.map((p) => p.name), ['Mít']);
    await settle(tester);
  });

  testWidgets('Đồng bộ: tạo mã → hiện mã che, Hiện mã, ngắt máy', (tester) async {
    final store = await newStore();
    store.addProfile('Na', mascotId());
    final (_, _, _, _, sync) = await pump(tester, store);
    await tester.scrollUntilVisible(find.byKey(const Key('sync-create')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('sync-join')), findsOneWidget);
    final r = await tester.runAsync(() => sync.create());
    expect(r, 'ok');
    await tester.pumpAndSettle();
    final c = sync.code!;
    expect(find.text('••••-••••-••••-${c.substring(15)}'), findsOneWidget);
    expect(find.textContaining('Lần đồng bộ gần nhất'), findsOneWidget);
    await tapKey(tester, 'sync-show');
    expect(find.text(c), findsOneWidget);
    await tapKey(tester, 'sync-leave');
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();
    expect(sync.code, isNull);
    expect(find.byKey(const Key('sync-create')), findsOneWidget);
    expect(boxes.isNotEmpty, isTrue); // bản trên máy chủ vẫn giữ
  });

  testWidgets('Góp ý, chia sẻ, ghi công: link ra ngoài qua ParentsIo', (tester) async {
    final store = await newStore();
    store.addProfile('Na', mascotId());
    store.setKv('bvh.micOK', '1');
    final (_, io, _, _, _) = await pump(tester, store);
    await tapKey(tester, 'link-zalo');
    await tapKey(tester, 'link-about');
    await tapKey(tester, 'mic-reset');
    expect(store.getKv('bvh.micOK'), isNull);
    await settle(tester);
    await tapKey(tester, 'share-app');
    await tapKey(tester, 'credits-show');
    await tester.pumpAndSettle();
    expect(find.textContaining('Tiếng thú cưng: test'), findsOneWidget);
    await tapKey(tester, 'link-credits');
    expect(io.opened, ['https://zalo.me/0888998098', 'https://datpilot.com/be-vui-hoc', 'https://datpilot.com/be-vui-hoc/ghi-cong']);
    expect(io.shared.single, contains('https://datpilot.com/be-vui-hoc?src=app'));
  });

  group('Báo cáo', () {
    Future<(AppStore, Profile)> seeded() async {
      final store = await newStore();
      final p = store.addProfile('Na', mascotId());
      // b ↔ d nhầm hai chiều, 3 lần; chữ a đúng.
      store.recordAnswer('letters', ['letters:b'], false, ['letters|b|d'], 3000);
      store.recordAnswer('letters', ['letters:b'], false, ['letters|b|d'], 3000);
      store.recordAnswer('letters', ['letters:d'], false, ['letters|d|b'], 3000);
      store.recordAnswer('letters', ['letters:a'], true, [], 2000);
      store.recordAnswer('math', ['addFacts:2,3'], true, [], 2000);
      store.recordAnswer('math', ['addFacts:9,8'], false, [], 2000);
      store.recordRound('letters', 0, 3, const []);
      store.addUsage(600);
      store.addMilestones(['l10', 'w10']);
      return (store, store.profileById(p.id)!);
    }

    test('ReportModel: gộp cặp nhầm hai chiều, nhóm phép tính, mục tiêu tiếp', () async {
      final (store, p) = await seeded();
      final m = ReportModel(
        store: store,
        tracker: LearnTracker(content: bundle.content, data: bundle.data, voice: bundle.voice, store: store),
        content: bundle.content,
        data: bundle.data,
        lang: 'vi',
      );
      final weak = m.weakList(p);
      expect(weak.first.text, 'b ↔ d');
      expect(weak.first.n, 3);
      expect(weak.first.key, 'letters:b');
      expect(weak.first.conf, isTrue);
      final rows = m.skillRows(p);
      final letters = rows.firstWhere((r) => r.id == 'letters');
      expect(letters.main, startsWith('Nhận ra 1/'));
      expect(letters.acc, '25% đúng ngay · 4 câu');
      final math = rows.firstWhere((r) => r.id == 'math');
      expect(math.main, 'Cộng trừ trong 10: 100% đúng (1 câu)');
      expect(math.extra, 'Cộng trừ đến 20: 0% đúng (1 câu)');
      expect(m.nextGoal(p), 'Còn 10 nữa là con đọc đúng 10 tiếng.');
      final days = m.days(p);
      expect(days.length, 7);
      expect(days.last.wd, 'Nay');
      expect(days.last.min, 10);
      expect(days.last.les, 1);
      expect(days.last.stars, 3);
      expect(days[5].wd, 'T4'); // 14/10/2026 là thứ Tư
    });

    testWidgets('màn báo cáo: tổng quan, kỹ năng, hay nhầm → ôn tập, mốc → bằng khen', (tester) async {
      final (store, p) = await seeded();
      final (_, _, _, _, _) = await pump(tester, store, at: '/report/${p.id}');
      expect(find.text('📊 Báo cáo của Na'), findsOneWidget);
      expect(find.textContaining('Tuần này Na học 1/7 ngày, 10 phút, 1 bài'), findsOneWidget);
      expect(find.text('Nay'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('ms-w10')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Con đã đọc đúng 10 tiếng!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ms-w10')));
      await tester.pumpAndSettle();
      expect(find.text('BẰNG KHEN'), findsOneWidget);
      expect(find.text('Khoe với người thân'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cert-name')));
      await tester.pumpAndSettle();
      expect(find.text('Bé Vui Học trân trọng tặng bé yêu'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byKey(const ValueKey('weak-b ↔ d')), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('weak-b ↔ d')));
      await tester.pumpAndSettle();
      expect(find.text('route:review/x/letters:b'), findsOneWidget);
      expect(store.activeId, p.id);
    });

    testWidgets('bé không có → về Góc bố mẹ', (tester) async {
      final store = await newStore();
      store.addProfile('Na', mascotId());
      final (_, _, router, _, _) = await pump(tester, store, at: '/report/nope');
      expect(router.routerDelegate.currentConfiguration.uri.path, '/parent');
    });
  });

  testWidgets('bằng khen PNG 1080×1350', (tester) async {
    const d = CertData(name: 'Nguyễn Thị Na', text: 'Con đã đọc đúng 10 tiếng!', img: 'Open book', when: '15/10/2026', stars: 42);
    final png = await tester.runAsync(() => certificatePng(d));
    expect(png, isNotNull);
    final b = png!;
    expect(b.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final bd = ByteData.sublistView(b);
    expect(bd.getUint32(16), 1080);
    expect(bd.getUint32(20), 1350);
    expect(certShareText(d), 'Bé Nguyễn Thị Na vừa được bằng khen: Con đã đọc đúng 10 tiếng! Học miễn phí ở Bé Vui Học: https://datpilot.com/be-vui-hoc?src=giaykhen');
    expect(certShareText(d.withName(false)), startsWith('Bé nhà mình vừa được bằng khen'));
    expect(wrapWords('a bb ccc dddd', 6, (s) => s.length.toDouble()), ['a bb', 'ccc', 'dddd']);
  });
}
