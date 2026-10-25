// Menu chọn chữ an toàn: không có Look Up / Search Web / Share (iOS) hay mục "process text" của app khác (Android) —
// các mục này mở app/trình duyệt khác không qua khoá bố mẹ. Mọi ô nhập/chữ chọn được trong lib/ phải dùng safeContextMenuBuilder.
import 'dart:io';

import 'package:be_vui_hoc/core/ui/text_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safeContextMenuItems chỉ giữ cắt/chép/dán/chọn tất cả', () {
    void noop() {}
    final all = [
      for (final t in ContextMenuButtonType.values) ContextMenuButtonItem(type: t, onPressed: noop, label: t.name),
    ];
    expect(safeContextMenuItems(all).map((b) => b.type).toSet(), {
      ContextMenuButtonType.cut,
      ContextMenuButtonType.copy,
      ContextMenuButtonType.paste,
      ContextMenuButtonType.selectAll,
    });
  });

  Future<EditableTextState> pumpField(WidgetTester tester, {required bool safe}) async {
    final c = TextEditingController(text: 'Bông hoa');
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: safe ? TextField(controller: c, contextMenuBuilder: safeContextMenuBuilder) : TextField(controller: c),
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();
    state.showToolbar();
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('iOS: menu mặc định có Look Up / Search Web / Share; menu an toàn thì không', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpField(tester, safe: false);
      final defaults = tester.state<EditableTextState>(find.byType(EditableText)).contextMenuButtonItems.map((b) => b.type).toSet();
      expect(defaults, containsAll([ContextMenuButtonType.lookUp, ContextMenuButtonType.searchWeb, ContextMenuButtonType.share]));

      await pumpField(tester, safe: true);
      expect(find.byType(SystemContextMenu), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Cut'), findsOneWidget);
      for (final label in ['Look Up', 'Search Web', 'Share...', 'Share']) {
        expect(find.text(label), findsNothing, reason: label);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android: menu an toàn không có mục ngoài cắt/chép/dán/chọn tất cả', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpField(tester, safe: true);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Translate'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('mọi TextField / TextFormField / SelectableText / EditableText trong lib/ dùng safeContextMenuBuilder', () {
    final widget = RegExp(r'\b(TextField|TextFormField|SelectableText|EditableText|CupertinoTextField)\(');
    final bad = <String>[];
    var seen = 0;
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      expect(RegExp(r'SystemContextMenu[.(]').hasMatch(src), isFalse, reason: '${f.path} dùng menu hệ thống iOS (không lọc được)');
      for (final m in widget.allMatches(src)) {
        seen++;
        // Tìm dấu ")" đóng lời gọi để chỉ xét tham số của chính widget này.
        var depth = 0, end = m.end - 1;
        for (; end < src.length; end++) {
          final ch = src[end];
          if (ch == '(') depth++;
          if (ch == ')' && --depth == 0) break;
        }
        if (!src.substring(m.start, end).contains('contextMenuBuilder: safeContextMenuBuilder')) {
          bad.add('${f.path}:${'\n'.allMatches(src.substring(0, m.start)).length + 1} ${m[1]}');
        }
      }
    }
    expect(seen, greaterThanOrEqualTo(6));
    expect(bad, isEmpty);
  });
}
