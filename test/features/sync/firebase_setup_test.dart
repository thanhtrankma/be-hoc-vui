// initFirebase() an toàn khi chạy test (không có plugin gốc); RemoteFlags trả giá trị mặc định.
import 'package:be_vui_hoc/features/sync/firebase_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bỏ qua Firebase trong test, cờ mặc định', () async {
    expect(await initFirebase(), isFalse);
    expect(FirebaseState.ready, isFalse);
    expect(FirebaseState.skippedReason, isNotNull);
    expect(RemoteFlags.syncEnabled, isTrue);
    expect(RemoteFlags.parentNotice('vi'), '');
    expect(RemoteFlags.minBuild, 0);
  });
}
