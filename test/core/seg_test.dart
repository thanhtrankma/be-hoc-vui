// Seg (nút chọn một như cài đặt Bật/Tắt): các lựa chọn nằm cùng hàng trên điện thoại, không giãn hết bề ngang.
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Seg: hai lựa chọn nằm cùng một hàng trong khung hẹp', (tester) async {
    var picked = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 340,
            child: Align(
              alignment: Alignment.centerRight,
              child: Seg<String>(options: const [('vi', 'Tiếng Việt'), ('en', 'English')], value: 'vi', onPick: (v) => picked = v),
            ),
          ),
        ),
      ),
    ));
    final vi = tester.getRect(find.text('Tiếng Việt'));
    final en = tester.getRect(find.text('English'));
    expect(en.center.dy, closeTo(vi.center.dy, .5), reason: 'cùng một hàng');
    expect(en.left, greaterThan(vi.right));
    // Mỗi nút chỉ rộng vừa chữ, không chiếm cả 340px.
    final seg = tester.getRect(find.byType(Seg<String>));
    expect(seg.width, lessThan(340));
    expect(seg.height, lessThan(70));
    await tester.tap(find.text('English'));
    expect(picked, 'en');
  });
}
