// Màn Bắt đầu: "Giới thiệu · Ghi công" là trang trong app dành cho người lớn → phải qua khoá bố mẹ (chính sách app trẻ em).
import 'dart:io';

import 'package:be_vui_hoc/app.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/parents/parents.dart';
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
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentBundleProvider.overrideWithValue(bundle),
        storeProvider.overrideWith((ref) => store),
        audioProvider.overrideWithValue(SilentAudio(voice: bundle.voice, store: store)),
        parentsIoProvider.overrideWithValue(const _DiskIo()),
      ],
      child: const BeVuiHocApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> answerGate(WidgetTester tester, {int delta = 0}) async {
    final q = tester.widget<Text>(find.textContaining(' × ')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!) + delta}'.split('')) {
      await tester.tap(find.byKey(Key('gate-$ch')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('gate-OK')));
    await tester.pumpAndSettle();
  }

  testWidgets('Giới thiệu: huỷ khoá → không mở; đúng → trang Giới thiệu trong app, quay lại màn Bắt đầu', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('start-about')));
    expect(find.text('Dành cho bố mẹ'), findsOneWidget);
    await tap(tester, find.text('Huỷ'));
    expect(find.byKey(const Key('legal-about')), findsNothing);

    await tap(tester, find.byKey(const Key('start-about')));
    await answerGate(tester);
    expect(find.byKey(const Key('legal-about')), findsOneWidget);
    await tap(tester, find.byKey(const Key('about-privacy')));
    expect(find.byKey(const Key('legal-privacy')), findsOneWidget);
    await tap(tester, find.byKey(const Key('info-back')));
    await tap(tester, find.byKey(const Key('info-back')));
    expect(find.byKey(const Key('legal-about')), findsNothing);
    expect(find.byKey(const Key('start-btn')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Ghi công: trả lời sai vẫn khoá; đúng → danh sách ghi công trong app', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('start-credits')));
    await answerGate(tester, delta: 1);
    expect(find.text('Dành cho bố mẹ'), findsOneWidget);
    expect(find.byKey(const Key('credits-list')), findsNothing);
    await answerGate(tester);
    expect(find.byKey(const Key('credits-list')), findsOneWidget);
    expect(find.textContaining('Kenney'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

/// Đọc asset thẳng từ ổ đĩa (rootBundle cần IO thật, không chạy trong FakeAsync của testWidgets).
class _DiskIo extends ParentsIo {
  const _DiskIo();
  @override
  Future<String> loadAssetText(String path) async => File(path).readAsStringSync();
}
