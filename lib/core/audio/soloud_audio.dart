// Âm thanh thật bằng flutter_soloud: giọng đọc Opus (.ogg), hiệu ứng tổng hợp sẵn (synth.dart), tiếng thật sfx/*.mp3,
// đàn, động cơ xe, nhạc nền lặp. Lỗi engine (máy không có loa, simulator lạ) → im lặng, không làm hỏng app.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_service.dart';
import 'synth.dart';

class SoloudAudio extends AudioService {
  SoloudAudio({required super.voice, required super.store});

  SoLoud get _sl => SoLoud.instance;
  bool _ok = false;

  // Bus (âm lượng tương đối như web): giọng 1, hiệu ứng .5 (đã nhân khi tổng hợp), nhạc .07 (đang đọc: .025).
  static const double _voiceVol = 1, _clipVol = .5, _musicVol = .07 / kMusicGain, _musicDuck = .025 / kMusicGain;

  final Map<String, AudioSource> _sfx = {};
  final Map<String, AudioSource> _notes = {};
  final Map<String, Future<AudioSource?>> _clips = {};

  // Bộ nhớ đệm giọng đọc (LRU nhỏ): câu hay dùng không phải giải mã lại.
  final Map<String, Future<AudioSource?>> _voices = {};
  final List<String> _voiceOrder = [];
  static const int _voiceCache = 48;

  SoundHandle? _current;
  AudioSource? _musicSrc;
  SoundHandle? _musicHandle;
  bool _ducked = false;
  bool _suspended = false;
  _Engine? _eng;

  @override
  Future<void> init() async {
    try {
      await _sl.init(bufferSize: 1024, channels: Channels.mono);
      _ok = true;
      // Tổng hợp ở isolate khác (giống nhạc nền) để không chặn khung hình của màn Bắt đầu.
      final bank = await compute(renderSynthBank, null);
      for (final name in sfxRecipes().keys) {
        _sfx[name] = await _sl.loadMem('sfx_$name.wav', bank['sfx_$name']!);
      }
      for (var i = 0; i < kNotes.length; i++) {
        _notes['$i'] = await _sl.loadMem('note_$i.wav', bank['note_$i']!);
      }
      store.addListener(_onSettings);
    } catch (e) {
      debugPrint('SoLoud không khởi động được: $e');
      _ok = false;
    }
  }

  bool _lastMusic = true;
  void _onSettings() {
    if (store.musicOn != _lastMusic) {
      _lastMusic = store.musicOn;
      music();
    }
  }

  bool _unlocked = false;
  @override
  void unlock() {
    _unlocked = true;
  }

  // ---------- Giọng đọc ----------
  Future<AudioSource?> _loadVoice(String asset) {
    final hit = _voices[asset];
    if (hit != null) {
      _voiceOrder
        ..remove(asset)
        ..add(asset);
      return hit;
    }
    final f = _sl.loadAsset(asset).then<AudioSource?>((s) => s).catchError((Object e) {
      debugPrint('Không nạp được giọng đọc $asset: $e');
      _voices.remove(asset);
      return null;
    });
    _voices[asset] = f;
    _voiceOrder.add(asset);
    while (_voiceOrder.length > _voiceCache) {
      final old = _voiceOrder.removeAt(0);
      final src = _voices.remove(old);
      src?.then((s) {
        if (s != null) _sl.disposeSource(s);
      });
    }
    return f;
  }

  @override
  void preload(Iterable<VoiceLine?> lines) {
    if (!_ok) return;
    for (final l in lines) {
      final a = voice.assetOf(l);
      if (a != null) _loadVoice(a);
    }
  }

  @override
  Future<double> clipDuration(VoiceLine? line) async {
    final a = voice.assetOf(line);
    if (!_ok || a == null) return 0;
    final s = await _loadVoice(a);
    return s == null ? 0 : _sl.getLength(s).inMilliseconds / 1000;
  }

  @override
  Future<void> playVoiceAsset(String asset, bool Function() isCurrent) async {
    if (!_ok) return;
    final src = await _loadVoice(asset);
    if (src == null || !isCurrent()) return;
    final h = _sl.play(src, volume: _voiceVol);
    _current = h;
    _duck(true);
    // Chờ hết câu (hoặc bị stopVoice cắt).
    while (_sl.getIsValidVoiceHandle(h) && isCurrent()) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (_current == h) {
      _current = null;
      _duck(false);
    }
  }

  @override
  void stopVoiceEngine() {
    final h = _current;
    _current = null;
    if (h != null && _ok) {
      try {
        _sl.stop(h);
      } catch (_) {/* đã dừng */}
      _duck(false);
    }
  }

  // ---------- Hiệu ứng ----------
  @override
  void sfx(String name) {
    if (!_ok || !soundOn || _suspended) return;
    final s = _sfx[name];
    if (s == null) return;
    try {
      _sl.play(s);
    } catch (_) {}
  }

  @override
  Future<VoidCallback?> clip(String name, {double rate = 1, double vol = 1, bool loop = false}) async {
    if (!_ok || !soundOn) return null;
    final src = await (_clips[name] ??= _sl.loadAsset('assets/sfx/$name.mp3').then<AudioSource?>((s) => s).catchError((Object e) {
          debugPrint('Không nạp được âm thanh assets/sfx/$name.mp3: $e');
          return null;
        }));
    if (src == null) return null;
    final h = _sl.play(src, volume: vol * _clipVol, looping: loop);
    if (rate != 1) _sl.setRelativePlaySpeed(h, rate);
    return () {
      try {
        _sl.fadeVolume(h, 0, const Duration(milliseconds: 150));
        _sl.scheduleStop(h, const Duration(milliseconds: 200));
      } catch (_) {}
    };
  }

  @override
  void note(num i, [double dur = .9]) {
    if (!_ok || !soundOn) return;
    final idx = i.toInt();
    if (i == idx && idx >= 0 && idx < kNotes.length && dur == .9) {
      _sl.play(_notes['$idx']!);
      return;
    }
    final f = (i >= 0 && i < kNotes.length && i == idx) ? kNotes[idx] : i.toDouble();
    final key = '${f.toStringAsFixed(1)}_$dur';
    final cached = _notes[key];
    if (cached != null) {
      _sl.play(cached);
      return;
    }
    _sl.loadMem('note_$key.wav', toWav(renderTones(noteRecipe(f, dur), gain: .5))).then((s) {
      _notes[key] = s;
      _sl.play(s);
    }).catchError((_) {});
  }

  // ---------- Động cơ xe ----------
  @override
  void engine(double level) {
    if (!_ok || !soundOn) return;
    if (_eng == null && level > 0) {
      _eng = _Engine();
      _eng!.start(_sl);
    }
    final e = _eng;
    if (e == null) return;
    if (level <= 0) {
      _eng = null;
      e.stop(_sl);
      return;
    }
    e.set(_sl, level);
  }

  // ---------- Nhạc nền ----------
  double get _musicLevel => store.musicOn ? (_ducked ? _musicDuck : _musicVol) : 0;

  void _duck(bool on) {
    _ducked = on;
    final h = _musicHandle;
    if (h != null && _ok) {
      try {
        _sl.fadeVolume(h, _musicLevel, const Duration(milliseconds: 300));
      } catch (_) {}
    }
  }

  @override
  void music() {
    if (!_ok || !_unlocked) return;
    if (store.musicOn && _musicHandle == null) {
      _startMusic();
    } else if (!store.musicOn && _musicHandle != null) {
      final h = _musicHandle!;
      _musicHandle = null;
      try {
        _sl.fadeVolume(h, 0, const Duration(milliseconds: 300));
        _sl.scheduleStop(h, const Duration(milliseconds: 350));
      } catch (_) {}
    }
  }

  Future<void> _startMusic() async {
    try {
      _musicSrc ??= await _sl.loadMem('music.wav', await compute(renderMusicLoop, Random().nextInt(1 << 30)));
      if (_musicHandle != null || !store.musicOn) return;
      final h = _sl.play(_musicSrc!, volume: 0, looping: true);
      _musicHandle = h;
      _sl.fadeVolume(h, _musicLevel, const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint('Nhạc nền lỗi: $e');
    }
  }

  // Web: ctx.suspend()/resume() khi ẩn/hiện trang — TẤT CẢ tiếng dừng tại chỗ (nhạc, câu đang đọc, động cơ xe,
  // tiếng thật lặp như mèo rừ rừ) rồi phát tiếp đúng chỗ khi quay lại. stopAudioDevice giữ nguyên mọi voice.
  @override
  void suspend() {
    _suspended = true;
    if (!_ok) return;
    final h = _musicHandle;
    if (h != null) _sl.setPause(h, true);
    _sl.stopAudioDevice(force: true).catchError((Object _) {});
  }

  @override
  void resume() {
    _suspended = false;
    if (!_ok) return;
    _sl.startAudioDevice().catchError((Object _) {});
    final h = _musicHandle;
    if (h != null) _sl.setPause(h, false);
  }
}

/// Động cơ: sóng răng cưa + vuông, tần số và âm lượng theo ga.
class _Engine {
  AudioSource? _a, _b;
  SoundHandle? _ha, _hb;
  double _level = 0;

  Future<void> start(SoLoud sl) async {
    try {
      _a = await sl.loadWaveform(WaveForm.saw, false, 1, 0);
      _b = await sl.loadWaveform(WaveForm.square, false, 1, 0);
      // Web: cả hai sóng qua bộ lọc thông thấp 400 + 900·ga Hz (tiếng ầm ấm, không rè).
      try {
        _a!.filters.biquadFilter.activate();
        _b!.filters.biquadFilter.activate();
      } catch (_) {}
      _ha = sl.play(_a!, volume: 0, looping: true);
      _hb = sl.play(_b!, volume: 0, looping: true);
      set(sl, _level);
    } catch (_) {}
  }

  void set(SoLoud sl, double level) {
    _level = level;
    final a = _a, b = _b, ha = _ha, hb = _hb;
    if (a == null || b == null || ha == null || hb == null) return;
    try {
      sl.setWaveformFreq(a, 55 + level * 110);
      sl.setWaveformFreq(b, 27 + level * 55);
      try {
        a.filters.biquadFilter.frequency(soundHandle: ha).value = 400 + level * 900;
        b.filters.biquadFilter.frequency(soundHandle: hb).value = 400 + level * 900;
      } catch (_) {}
      // Một gain chung .05 + .05·ga cho cả hai sóng, qua bus hiệu ứng .5 (như web).
      final v = (.05 + level * .05) * .5;
      sl.fadeVolume(ha, v, const Duration(milliseconds: 80));
      sl.fadeVolume(hb, v, const Duration(milliseconds: 80));
    } catch (_) {}
  }

  void stop(SoLoud sl) {
    for (final h in [_ha, _hb]) {
      if (h == null) continue;
      try {
        sl.fadeVolume(h, 0, const Duration(milliseconds: 150));
        sl.scheduleStop(h, const Duration(milliseconds: 300));
      } catch (_) {}
    }
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      for (final s in [_a, _b]) {
        if (s != null) sl.disposeSource(s);
      }
    });
  }
}
