// resumeRoute() của app.js: máy tắt app khi đang ở nền thì bấm Bắt đầu quay về đúng màn bé đang ở (chỉ các màn RESUME,
// không nhớ màn đang chơi /fun/<id>, /rpg/<r>/<s>). App nhớ kèm giờ (không có "phiên tab" như sessionStorage).
import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('nhớ màn RESUME, bỏ màn đang chơi, hết hạn sau kResumeFor', () async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 10, 15, 9);
    final s = AppStore(await SharedPreferences.getInstance(), clock: () => now);
    saveResumeRoute(s, '/island/count');
    expect(resumeRoute(s), '/island/count');
    saveResumeRoute(s, '/fun');
    expect(resumeRoute(s), '/fun');
    saveResumeRoute(s, '/fun/racer');
    expect(resumeRoute(s), isNull);
    saveResumeRoute(s, '/rpg');
    expect(resumeRoute(s), '/rpg');
    saveResumeRoute(s, '/rpg/2/3');
    expect(resumeRoute(s), isNull);
    saveResumeRoute(s, '/play/count/2');
    expect(resumeRoute(s), isNull);
    saveResumeRoute(s, '/lop1');
    now = now.add(const Duration(minutes: 30));
    expect(resumeRoute(s), '/lop1');
    now = now.add(kResumeFor);
    expect(resumeRoute(s), isNull);
  });

  test('đổi màn dừng câu đang đọc của màn cũ, giữ câu vừa nói kèm lệnh chuyển màn', () async {
    final a = _StopCounter();
    a.stopVoiceOnRoute();
    expect(a.stops, 1); // chưa đọc gì từ lâu → dừng
    await a.say(const VoiceLine('vi', 'x'));
    final before = a.stops;
    a.stopVoiceOnRoute(); // vừa nói xong lệnh → giữ
    expect(a.stops, before);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    a.stopVoiceOnRoute();
    expect(a.stops, before + 1);
  });
}

class _StopCounter extends SilentAudio {
  int stops = 0;
  @override
  void stopVoiceEngine() => stops++;
}
