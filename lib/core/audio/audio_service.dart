// Port của js/audio.js: giọng đọc (mp3 tạo sẵn), hiệu ứng và nhạc nền.
// AudioService là hợp đồng chung; SoloudAudio (soloud_audio.dart) phát thật, SilentAudio dùng cho test (không tiếng,
// say() xong ngay). Game lấy qua ref.read(audioProvider) hoặc ctx.audio.
//
// Ngữ nghĩa giống web:
//  - say(line): cắt câu đang đọc (stopVoice) rồi đọc câu mới; Future xong khi đọc hết hoặc bị câu khác cắt ngang.
//  - sayAll([..]): đọc lần lượt; dừng nếu bị cắt.
//  - Tắt "Giọng đọc & hiệu ứng" trong cài đặt → say/sfx im lặng (Future xong ngay).
//  - Nhạc nền tự nhỏ lại (duck) khi đang đọc.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content.dart';
import '../store/store.dart';
import 'voice_data.dart';

export 'voice_data.dart';

/// Tên hiệu ứng có sẵn (sfx()). Tiếng thật (thú cưng) dùng clip('dog-bark1'...).
const List<String> kSfxNames = [
  'tap', 'flip', 'count', 'correct', 'wrong', 'star', 'win', 'pop', 'laser', 'boom', 'coin', 'jump', 'hit', 'power',
  'bark', 'meow', 'squeak', 'eat', 'splash', 'snore', 'shoot',
];

abstract class AudioService {
  AudioService({required this.voice, required this.store});

  final VoiceData voice;
  final AppStore store;

  String get lang => store.lang;
  bool get soundOn => store.soundOn;

  int _seq = 0;
  String _lastPraise = '';
  final Random _rnd = Random();

  // ---------- Phần engine (lớp con cài) ----------
  /// Khởi động engine. Không bao giờ ném lỗi ra ngoài.
  Future<void> init();

  /// Gọi ở lần chạm đầu (nút Bắt đầu): bật nhạc nếu cài đặt cho phép.
  void unlock() {}

  /// Phát một file giọng (assets/audio/x.mp3); Future xong khi phát hết hoặc bị stopVoice(). isCurrent() = còn là câu hiện tại.
  @protected
  Future<void> playVoiceAsset(String asset, bool Function() isCurrent);

  /// Dừng câu đang đọc (engine).
  @protected
  void stopVoiceEngine();

  /// Hiệu ứng tổng hợp theo tên (kSfxNames).
  void sfx(String name);

  /// Tiếng thật `assets/sfx/<name>.mp3`. Trả về hàm dừng, hoặc null nếu không phát được.
  Future<VoidCallback?> clip(String name, {double rate = 1, double vol = 1, bool loop = false});

  /// Phím đàn i (0..7 = Đô..Đô cao) hoặc tần số Hz nếu i > 7.
  void note(num i, [double dur = .9]);

  /// Tiếng động cơ cho game đua xe: level 0..1 (0 = tắt).
  void engine(double level);

  /// Áp cài đặt nhạc nền (bật/tắt). Gọi sau khi đổi setting 'music'.
  void music();

  /// Tải trước giọng đọc (không bắt buộc).
  void preload(Iterable<VoiceLine?> lines) {}

  /// Độ dài câu đọc (giây), 0 nếu không biết.
  Future<double> clipDuration(VoiceLine? line) async => 0;

  /// App vào nền / quay lại.
  void suspend() {}
  void resume() {}

  // ---------- Câu đọc (chung) ----------
  VoiceLine phrase(String key, [String? lg]) => voice.phrase(key, lg ?? lang);
  VoiceLine? tpl(String key, Map<String, dynamic> obj) => voice.tpl(key, obj);

  void stopVoice() {
    _seq++;
    stopVoiceEngine();
  }

  DateTime _sayAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Đổi màn (route() của web gọi audio.stopVoice()): cắt câu đang đọc của màn cũ. Câu vừa bắt đầu trong [fresh]
  /// gần đây được giữ — đó là câu nói kèm lệnh chuyển màn (vd. 'welcome' rồi go('/new'), 'noTicket' rồi về /fun)
  /// hoặc câu mở màn mới.
  void stopVoiceOnRoute({Duration fresh = const Duration(milliseconds: 300)}) {
    if (DateTime.now().difference(_sayAt) > fresh) stopVoice();
  }

  /// Đọc một câu; Future xong khi đọc hết (hoặc bị câu khác cắt ngang).
  Future<void> say(VoiceLine? line) async {
    if (line == null || !soundOn) return;
    final asset = voice.assetOf(line);
    stopVoice();
    _sayAt = DateTime.now();
    final my = _seq;
    if (asset == null) {
      if (line.text.isNotEmpty) debugPrint('Thiếu câu đọc: ${line.lang} ${line.text}');
      return;
    }
    await playVoiceAsset(asset, () => my == _seq);
  }

  Future<void> sayPhrase(String key) => say(phrase(key));

  /// Đọc lần lượt nhiều câu; dừng nếu bị câu khác cắt.
  Future<void> sayAll(Iterable<VoiceLine?> lines) async {
    for (final it in lines) {
      if (it == null) continue;
      final my = _seq;
      await say(it);
      if (_seq != my + 1 && soundOn) return; // say() tự tăng seq một lần; tăng thêm nghĩa là bị cắt.
    }
  }

  /// Câu khen ngẫu nhiên (không lặp liền câu trước).
  VoiceLine praiseItem() {
    final keys = ['praise1', 'praise2', 'praise3', 'praise4', 'praise5', 'praise6'].where((k) => k != _lastPraise).toList();
    _lastPraise = keys[_rnd.nextInt(keys.length)];
    return phrase(_lastPraise);
  }

  Future<void> praise() => sayPhrase('praise${1 + _rnd.nextInt(6)}');
  Future<void> retry() => sayPhrase('retry${1 + _rnd.nextInt(3)}');
}

/// Không phát tiếng (test, máy không mở được audio). say() xong ngay.
class SilentAudio extends AudioService {
  SilentAudio({VoiceData? voice, AppStore? store}) : super(voice: voice ?? VoiceData.empty, store: store ?? AppStore(null));

  /// Ghi lại các lệnh để test kiểm tra (vd. 'say:vi|Giỏi quá!', 'sfx:win').
  final List<String> log = [];

  @override
  Future<void> init() async {}
  @override
  Future<void> playVoiceAsset(String asset, bool Function() isCurrent) async => log.add('play:$asset');
  @override
  Future<void> say(VoiceLine? line) {
    if (line != null) log.add('say:${line.key}');
    return super.say(line);
  }

  @override
  void stopVoiceEngine() {}
  @override
  void sfx(String name) => log.add('sfx:$name');
  @override
  Future<VoidCallback?> clip(String name, {double rate = 1, double vol = 1, bool loop = false}) async {
    log.add('clip:$name');
    return null;
  }

  @override
  void note(num i, [double dur = .9]) => log.add('note:$i');
  @override
  void engine(double level) {}
  @override
  void music() {}
}

/// main() override bằng SoloudAudio; mặc định (test) im lặng.
final audioProvider = Provider<AudioService>((ref) {
  VoiceData? voice;
  try {
    voice = ref.read(contentBundleProvider).voice;
  } catch (_) {/* chưa nạp dữ liệu */}
  return SilentAudio(voice: voice, store: ref.read(storeProvider));
});
