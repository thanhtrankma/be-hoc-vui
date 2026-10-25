import 'package:be_vui_hoc/features/learn/language/read.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

class FakeRecognizer implements Recognizer {
  FakeRecognizer(this.heard, {this.ok = true});
  final String Function() heard;
  final bool ok;
  int inits = 0, listens = 0;
  @override
  Future<bool> init() async {
    inits++;
    return ok;
  }

  @override
  Future<void> listen({required void Function(List<String> alts) onResult, required void Function() onError, required void Function() onEnd}) async {
    listens++;
    onResult([heard()]);
    onEnd();
  }

  @override
  Future<void> stop() async {}
}

Future<int> levelOf(WidgetTester tester, String kind, {bool last = false}) async {
  final b = await tester.runAsync(testBundle);
  final l = b!.content.list('readLevels');
  return last ? l.lastIndexWhere((x) => x['kind'] == kind) : l.indexWhere((x) => x['kind'] == kind);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('Đọc truyện: lật hết trang rồi trả lời đúng → 3 sao ($size)', (tester) async {
      final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'story'), size: size);
      await settle(tester, 1000);
      expect(find.byKey(const Key('story-next')), findsOneWidget);
      for (var k = 0; k < 20 && find.byKey(const Key('story-next')).evaluate().isNotEmpty; k++) {
        await tester.tap(find.byKey(const Key('story-next')));
        await settle(tester, 1000);
      }
      expect(run.audio.log, contains('sfx:flip'));
      await answerQuiz(tester, run);
      expect(run.stars, 3);
      expect(run.progressI, run.progressN);
      await unmount(tester);
    });
  }

  testWidgets('Đọc truyện: chạm một từ thì đọc từ đó', (tester) async {
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'story', last: true));
    await settle(tester, 1000);
    run.audio.log.clear();
    final words = find.byWidgetPredicate((w) => w is GestureDetector && w.child is Row);
    await tester.tap(words.first);
    await tester.pump();
    expect(run.audio.log.any((l) => l.startsWith('say:')), isTrue);
    await unmount(tester);
  });

  Future<void> typeWord(WidgetTester tester, {bool wrongTone = false}) async {
    final t = DictationView.debugTarget!;
    await tester.tap(find.byKey(ValueKey('dkey-c-${t['c']}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('dkey-v-${t['v']}')));
    await tester.pump();
    var tone = t['t']!;
    if (wrongTone) tone = tone == 'ngang' ? 'sắc' : 'ngang';
    final f = find.byKey(ValueKey('dkey-t-$tone'));
    await tester.tap(f);
    await settle(tester, 2000);
  }

  testWidgets('Nghe – viết: ghép đúng 6 tiếng → 3 sao; sai dấu một lần vẫn 3 sao', (tester) async {
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'dictation'));
    await settle(tester, 500);
    // Lần đầu sai dấu (bài này có ngang/huyền/sắc).
    await typeWord(tester, wrongTone: true);
    expect(run.audio.log, contains('sfx:wrong'));
    // Sau khi sai, chỉ ô dấu bị xoá: chọn lại dấu đúng.
    await tester.tap(find.byKey(ValueKey('dkey-t-${DictationView.debugTarget!['t']}')));
    await settle(tester, 2000);
    for (var k = 1; k < 6; k++) {
      await typeWord(tester);
    }
    expect(run.stars, 3);
    await unmount(tester);
  });

  testWidgets('Nghe – viết bài Học cùng lớp (know) trên màn ngang', (tester) async {
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'dictation', last: true), size: const Size(844, 390));
    await settle(tester, 500);
    for (var k = 0; k < 6; k++) {
      await typeWord(tester);
    }
    expect(run.stars, 3);
    await unmount(tester);
  });

  testWidgets('Bé đọc to: bố mẹ chấm "Đúng rồi" cả 6 từ → 3 sao', (tester) async {
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'aloud'), prefs: {'bvh.micOK': '0'});
    await settle(tester, 500);
    expect(find.byKey(const Key('aloud-mic')), findsNothing);
    for (var k = 0; k < 6; k++) {
      await tester.tap(find.byKey(const Key('aloud-ok')));
      await settle(tester, 500);
    }
    expect(run.stars, 3);
    await unmount(tester);
  });

  testWidgets('Bé đọc to: bật micro (bố mẹ đồng ý + khoá) rồi nhận giọng đúng', (tester) async {
    String word = '';
    final fake = FakeRecognizer(() => 'con $word nhé');
    AloudView.debugRecognizer = () => fake;
    addTearDown(() => AloudView.debugRecognizer = null);
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'aloud'));
    await settle(tester, 500);
    word = tester.widget<Text>(find.byKey(const Key('aloud-word'))).data!;
    await tester.tap(find.byKey(const Key('aloud-mic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mic-yes')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mic-yes')));
    await settle(tester, 1000);
    expect(run.store.getKv('bvh.micOK'), '1');
    expect(fake.listens, 1);
    expect(run.audio.log, contains('sfx:correct'));
    // Từ sau: nghe sai → báo lại, bố mẹ bỏ qua các từ còn lại.
    word = 'xxx';
    await tester.tap(find.byKey(const Key('aloud-mic')));
    await settle(tester, 500);
    expect(run.audio.log, contains('sfx:wrong'));
    expect(fake.listens, 2);
    expect(tester.widget<Text>(find.byKey(const Key('aloud-status'))).data, contains('xxx'));
    for (var k = 1; k < 6; k++) {
      await tester.tap(find.byKey(const Key('aloud-skip')));
      await settle(tester, 300);
    }
    expect(run.stars, 3);
    await unmount(tester);
  });

  testWidgets('Bé đọc to: quyền micro bị từ chối → xoá đồng ý, lần bấm sau phải qua bảng hỏi + khoá bố mẹ lại', (tester) async {
    final fake = FakeRecognizer(() => '', ok: false);
    AloudView.debugRecognizer = () => fake;
    addTearDown(() => AloudView.debugRecognizer = null);
    var gates = 0;
    final run = await pumpGame(tester, readModule, 'read', await levelOf(tester, 'aloud'), gate: () {
      gates++;
      return true;
    });
    await settle(tester, 500);
    await tester.tap(find.byKey(const Key('aloud-mic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mic-yes')));
    await settle(tester, 1000);
    expect(gates, 1);
    expect(fake.inits, 1);
    expect(fake.listens, 0);
    expect(run.store.getKv('bvh.micOK'), '0');
    // Bấm 🎤 lần nữa: không được hỏi quyền hệ thống thẳng — phải qua bảng "Bật micro?" và khoá bố mẹ trước.
    await tester.tap(find.byKey(const Key('aloud-mic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mic-yes')), findsOneWidget);
    expect(fake.inits, 1);
    await tester.tap(find.byKey(const Key('mic-yes')));
    await settle(tester, 1000);
    expect(gates, 2);
    expect(fake.inits, 2);
    expect(run.store.getKv('bvh.micOK'), '0');
    await unmount(tester);
  });
}
