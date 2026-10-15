// Tổng hợp âm thanh thành file WAV trong bộ nhớ, thay cho Web Audio của audio.js (tone(), sfx(), note(), nhạc nền).
// Hàm thuần (không phụ thuộc engine) nên chạy được trong isolate và test được.
import 'dart:math';
import 'dart:typed_data';

const int kSynthRate = 22050;

/// Một nốt như tone(freq, start, dur, {type, vol, to}) của web.
class Tone {
  const Tone(this.freq, this.start, this.dur, {this.type = 'sine', this.vol = .5, this.to});
  final double freq;
  final double start;
  final double dur;

  /// sine | triangle | square | sawtooth
  final String type;
  final double vol;

  /// Tần số cuối (trượt mũ), null = giữ nguyên.
  final double? to;
}

double _osc(String type, double phase) {
  final p = phase - phase.floorToDouble();
  switch (type) {
    case 'square':
      return p < .5 ? 1 : -1;
    case 'sawtooth':
      return 2 * p - 1;
    case 'triangle':
      return p < .5 ? 4 * p - 1 : 3 - 4 * p;
    default:
      return sin(2 * pi * p);
  }
}

/// Trộn các nốt thành mẫu PCM float (gain = âm lượng bus, vd. sfx .5).
Float64List renderTones(List<Tone> tones, {double gain = 1, double? length, int rate = kSynthRate}) {
  var end = 0.0;
  for (final t in tones) {
    end = max(end, t.start + t.dur + .03);
  }
  final n = ((length ?? end) * rate).ceil();
  final out = Float64List(n);
  for (final t in tones) {
    final s0 = (t.start * rate).floor();
    // Có length: phần vượt quá quấn về đầu (vòng lặp liền); không có: cắt ở cuối.
    final raw1 = ((t.start + t.dur + .02) * rate).ceil();
    final s1 = length == null ? min(n, raw1) : raw1;
    var phase = 0.0;
    for (var s = max(0, s0); s < s1; s++) {
      final tt = s / rate - t.start;
      if (tt < 0) continue;
      final k = (tt / t.dur).clamp(0.0, 1.0);
      final f = t.to == null ? t.freq : t.freq * pow(t.to! / t.freq, k);
      phase += f / rate;
      // Bao âm: 0.0001 → vol trong 12 ms (mũ), rồi vol → 0.0001 tới cuối nốt (mũ).
      double g;
      if (tt < .012) {
        g = 0.0001 * pow(t.vol / 0.0001, tt / .012);
      } else if (tt <= t.dur) {
        g = t.vol * pow(0.0001 / t.vol, (tt - .012) / max(.001, t.dur - .012));
      } else {
        g = 0;
      }
      out[s % n] += _osc(t.type, phase) * g * gain;
    }
  }
  return out;
}

/// PCM float → WAV 16-bit mono.
Uint8List toWav(Float64List samples, {int rate = kSynthRate}) {
  final n = samples.length;
  final b = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Hiệu ứng giống hệt bảng sfx() của web (bus sfx .5 đã nhân sẵn khi render).
Map<String, List<Tone>> sfxRecipes([Random? rnd]) {
  final r = rnd ?? Random(7);
  List<Tone> seq(List<double> fs, double step, double dur, String type, double vol) =>
      [for (var i = 0; i < fs.length; i++) Tone(fs[i], i * step, dur, type: type, vol: vol)];
  return {
    'tap': const [Tone(520, 0, .09, to: 880, vol: .35)],
    'flip': const [Tone(380, 0, .12, type: 'triangle', to: 1100, vol: .3)],
    'count': const [Tone(700, 0, .14, type: 'triangle', vol: .4), Tone(1050, .05, .12, vol: .2)],
    'correct': seq([523, 659, 784, 1047], .07, .22, 'triangle', .45),
    'wrong': const [Tone(300, 0, .28, to: 170, vol: .4), Tone(240, .12, .26, to: 140, vol: .3)],
    'star': const [Tone(1320, 0, .25, type: 'triangle', vol: .4), Tone(1760, .08, .3, vol: .3)],
    'win': [for (final x in const [[523, 0], [659, .12], [784, .24], [1047, .4], [784, .55], [1047, .7]]) Tone(x[0].toDouble(), x[1].toDouble(), .3, type: 'triangle', vol: .45)],
    'pop': const [Tone(900, 0, .07, to: 300, vol: .3)],
    'laser': const [Tone(1400, 0, .09, type: 'square', to: 500, vol: .07)],
    'boom': const [Tone(220, 0, .3, type: 'triangle', to: 50, vol: .5), Tone(660, 0, .12, to: 1500, vol: .15)],
    'coin': const [Tone(988, 0, .08, type: 'square', vol: .1), Tone(1319, .07, .18, type: 'square', vol: .1)],
    'jump': const [Tone(330, 0, .18, type: 'triangle', to: 880, vol: .3)],
    'hit': const [Tone(160, 0, .35, type: 'sawtooth', to: 60, vol: .18)],
    'power': seq([523, 659, 784, 1047, 1319], .05, .15, 'square', .08),
    'bark': const [Tone(620, 0, .09, type: 'square', to: 300, vol: .14), Tone(560, .16, .12, type: 'square', to: 260, vol: .14)],
    'meow': const [Tone(520, 0, .45, type: 'triangle', to: 880, vol: .25), Tone(880, .25, .3, type: 'triangle', to: 600, vol: .2)],
    'squeak': const [Tone(1500, 0, .08, to: 2200, vol: .15), Tone(1700, .1, .08, to: 2400, vol: .12)],
    'eat': [for (final d in const [0, .14, .28]) Tone(180, d.toDouble(), .07, type: 'square', to: 90, vol: .12)],
    'splash': [for (var k = 0; k < 6; k++) Tone(1200 + r.nextDouble() * 1500, k * .05, .06, vol: .08)],
    'snore': const [Tone(110, 0, .8, type: 'sawtooth', to: 80, vol: .05)],
    'shoot': const [Tone(700, 0, .12, type: 'triangle', to: 1600, vol: .2)],
  };
}

/// Đàn: 8 phím Đô Rê Mi Fa Son La Si Đô (C4–C5), tiếng mộc cầm.
const List<double> kNotes = [261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9, 523.3];
List<Tone> noteRecipe(double f, [double dur = .9]) =>
    [Tone(f, 0, dur, vol: .55), Tone(f * 2, 0, dur * .45, vol: .18), Tone(f * 4.01, 0, .12, type: 'triangle', vol: .08)];

// ---- Nhạc nền: hộp nhạc ngũ cung, nhịp nhẹ, tự lặp (port music()/schedule() của web) ----
const List<double> _scale = [523, 587, 659, 784, 880, 1047, 1175, 1319];
const List<List<double>> _chords = [[261, 329, 392], [220, 261, 329], [174, 220, 261], [196, 246, 293]];

/// Một vòng nhạc 64 nhịp (~21,8 giây) dạng WAV, đuôi nốt cuối quấn về đầu để lặp liền.
Uint8List renderMusicLoop(int seed) {
  final r = Random(seed);
  const beat = .34;
  List<double> makeMelody() {
    final m = <double>[];
    var i = 2;
    const steps = [-2, -1, -1, 0, 1, 1, 2];
    for (var n = 0; n < 32; n++) {
      i = (i + steps[r.nextInt(steps.length)]).clamp(0, _scale.length - 1);
      m.add(n % 8 == 7 || r.nextDouble() < .18 ? 0 : _scale[i]);
    }
    return m;
  }

  final melody = makeMelody();
  final tones = <Tone>[];
  for (var step = 0; step < 64; step++) {
    final t = step * beat;
    final n = melody[step % 32];
    if (n > 0) tones.add(Tone(n, t, .5, vol: .5));
    if (step % 4 == 0) {
      for (final f in _chords[(step ~/ 8) % 4]) {
        tones.add(Tone(f, t, 1.3, type: 'triangle', vol: .16));
      }
    }
  }
  // length = đúng 64 nhịp; renderTones cộng phần thừa vào đầu (s % n) nên vòng lặp liền mạch.
  return toWav(renderTones(tones, length: 64 * beat));
}
