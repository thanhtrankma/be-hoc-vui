// Mô phỏng phòng thú cưng (phần logic + vẽ của petScreen() trong reference/web/js/games/pet.js).
// Con vật động (vẽ bằng petrig.dart) tự đi lại trong phòng, có tiếng kêu thật. Bé chạm để chơi, vuốt để cưng nựng,
// chạm sàn để gọi lại; cho ăn/uống vào bát, ném bóng, tắm, đưa đi ngủ, đeo đồ.
// Chỉ số giảm theo giờ thật (kể cả khi tắt app) nhưng không bao giờ về 0: thú cưng chỉ buồn và cần bé, không ốm, không chết.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/sprite_sheet.dart' show drawImageCentered;
import 'package:be_vui_hoc/core/ui/utils.dart' show rand, pick;

import 'petrig.dart';

/// [khoá chỉ số, hình, mức giảm mỗi giờ].
const List<(String, String, double)> kPetStats = [
  ('food', 'Meat on bone', 9), ('water', 'Droplet', 11), ('clean', 'Soap', 6), ('happy', 'Red heart', 7), ('energy', 'High voltage', 6),
];
const double kPetFloor = 8;
const int kPetXpPerLv = 60;
const int kPetMaxLv = 10;

double _clamp(num v) => math.max(kPetFloor, math.min(100, v.toDouble()));
double petStat(Json pet, String k) => asDouble(pet[k], 50);
int petLevel(Json pet) => math.min(kPetMaxLv, 1 + (asDouble(pet['xp']) / kPetXpPerLv).floor());

/// Cập nhật chỉ số theo thời gian đã trôi qua (tick() của pet.js).
Json petTick(Json pet, DateTime now) {
  final ms = now.millisecondsSinceEpoch;
  final last = pet['last'] == null ? ms : asInt(pet['last']);
  final hours = math.min(48.0, (ms - last) / 36e5);
  if (hours > 0) {
    for (final (k, _, rate) in kPetStats) {
      pet[k] = _clamp(petStat(pet, k) - rate * hours * (k == 'energy' && pet['sleeping'] == true ? -3 : 1));
    }
  }
  pet['last'] = ms;
  return pet;
}

/// Gọi khi bé học xong một bài (onLesson() của pet.js). Khung màn chơi của Foundation đã làm việc này; để đây cho đủ API.
bool petOnLesson(Profile p, AppStore store) {
  final pet = p.pet;
  if (pet == null) return false;
  petTick(pet, store.now());
  pet['happy'] = _clamp(petStat(pet, 'happy') + 8);
  pet['xp'] = asDouble(pet['xp']) + 5;
  store.save();
  return true;
}

/// Tiếng kêu thật theo loài (assets/sfx). Hamster dùng tiếng thỏ cao giọng hơn.
class PetVoice {
  const PetVoice(this.talk, this.sad, this.rate, [this.purr]);
  final List<String> talk;
  final List<String> sad;
  final double rate;
  final String? purr;
}

const Map<String, PetVoice> kPetVoice = {
  'dog': PetVoice(['dog-bark1', 'dog-bark2', 'dog-bark3'], ['dog-whine'], 1.12),
  'cat': PetVoice(['cat-meow1', 'cat-meow2', 'cat-meow3'], ['cat-meow1'], 1, 'cat-purr'),
  'rabbit': PetVoice(['rabbit-1', 'rabbit-2', 'rabbit-3'], ['rabbit-2'], 1),
  'hamster': PetVoice(['rabbit-1', 'rabbit-2', 'rabbit-3'], ['rabbit-2'], 1.5),
  'panda': PetVoice(['rabbit-1', 'rabbit-3'], ['rabbit-2'], .75),
  'fox': PetVoice(['dog-bark2', 'dog-bark3'], ['dog-whine'], 1.45),
};
PetVoice petVoiceOf(String id) => kPetVoice[id] ?? kPetVoice['dog']!;

/// Hình dùng trong phòng (tải trước cho canvas).
const List<String> kPetSprites = [
  'Red heart', 'Sparkles', 'Droplet', 'Zzz', 'Bubbles', 'Thought balloon', 'Musical note', 'Glowing star', 'Shower', 'Sponge',
  'Meat on bone', 'High voltage', 'Soap', 'Crescent moon', 'Sun', 'Potted plant', 'Framed picture', 'Teddy bear', 'Tennis', 'Yarn', 'Softball',
];

class PetActor {
  double x = .5, z = .6, f = 1;
  String st = 'idle';
  double tm = 1.5;
  Offset? tgt; // (x, z)
  VoidCallback? onArrive;
  double speed = .28;
  final PetPose p = newPose();
  List<List<double>> foam = [];
  String? bubble;
}

class PetBall {
  PetBall(this.x, this.z);
  double x, z, h = 0, vx = 0, vz = 0, vh = 0;
  bool held = false;
  int bats = 0;
}

class PetBowl {
  PetBowl(this.x, this.z);
  final double x, z;
  int n = 0;
  String food = '';
}

class PetPart {
  PetPart(this.x, this.y, this.im, this.vx, this.vy, this.life, this.size, this.g) : max = life;
  double x, y, vx, vy, life;
  final double max, size, g;
  final String im;
}

class PetTouch {
  PetTouch(this.x, this.y, this.t, {this.ball = false}) : lx = x, ly = y;
  final double x, y, t;
  final bool ball;
  double moved = 0, lx, ly, vx = 0, vy = 0;
}

/// Toàn bộ trạng thái phòng thú cưng. Widget gọi update(dt) mỗi khung hình và paint(canvas) để vẽ.
class PetSim extends ChangeNotifier {
  PetSim({
    required this.pet,
    required this.kind,
    required this.data,
    required this.audio,
    required this.store,
    required this.tr,
    this.onUi,
    this.onToast,
    this.onConfetti,
  }) : lv = petLevel(pet) {
    bowlF.food = kind.foods.isNotEmpty ? kind.foods.first : 'Bone';
  }

  final Json pet;
  final PetKind kind;
  final AppData data;
  final AudioService audio;
  final AppStore store;

  /// t() của i18n.
  final String Function(String key) tr;
  VoidCallback? onUi;
  void Function(String text)? onToast;
  VoidCallback? onConfetti;

  Map<String, ui.Image> images = {};
  bool alive = true;

  PetVoice get v => petVoiceOf(kind.id);
  VoiceLine? voice(String key) => audio.tpl(key, {'p': kind.p});

  String mode = 'home';
  int lv;
  double W = 600, H = 400;

  // Sàn nhà: z = 0 (sát tường) .. 1 (sát bé). Toạ độ màn hình và cỡ theo chiều sâu.
  double get floorTop => H * .46;
  double sy(double z) => floorTop + 18 + z * (H * .95 - floorTop - 18);
  double kz(double z) => .78 + .32 * z;
  double unit(double z) => math.min(W * .29, H * .4) * kz(z) * (.86 + lv * .025);
  double toZ(double y) => ((y - floorTop - 18) / (H * .95 - floorTop - 18)).clamp(0.0, 1.0);

  final PetBowl bed = PetBowl(.15, .22);
  final PetBowl bowlF = PetBowl(.74, .12);
  final PetBowl bowlW = PetBowl(.87, .28);
  PetBall? ball;
  Offset? tub; // (x, z)
  double foamProg = 0;
  bool rinsing = false;
  final PetActor a = PetActor();
  final List<PetPart> parts = [];
  double time = 0, blinkT = 2, lastSave = 0, lastBars = 0, lastMeow = -1;
  List<double> taps = [];
  PetTouch? touching;
  Offset? follow; // (x, z)
  Future<VoidCallback?>? _purr;
  bool scrubbing = false;
  PetAnchors? _an;
  final List<(double, VoidCallback)> _later = [];

  /// Điểm neo của lần vẽ trước (chưa vẽ thì ước lượng).
  PetAnchors get an {
    if (_an != null) return _an!;
    final u = unit(a.z), x = a.x * W, y = sy(a.z);
    return PetAnchors(head: Offset(x + u * .35, y - u), top: Offset(x + u * .35, y - u * 1.5), mouth: Offset(x + u * .5, y - u * .8), body: Offset(x, y - u * .5), hr: u * .6, len: u * .8);
  }

  void after(double sec, VoidCallback fn) => _later.add((time + sec, fn));

  void save() {
    pet['last'] = store.now().millisecondsSinceEpoch;
    store.save();
  }

  void resize(double w, double h) {
    W = math.max(280, w);
    H = math.max(260, h);
  }

  // ---------- Âm thanh ----------
  void speak([bool sad = false]) {
    if (time - lastMeow < .6) return;
    lastMeow = time;
    a.p['mouth'] = 1;
    after(.35, () => a.p['mouth'] = 0);
    audio.clip(pick(sad ? v.sad : v.talk), rate: v.rate * rand(.95, 1.08)).then((stop) {
      if (stop == null) audio.sfx(kind.sound);
    });
  }

  void startPurr() {
    if (v.purr != null && _purr == null) _purr = audio.clip(v.purr!, loop: true, vol: .8);
  }

  void stopPurr() {
    final p = _purr;
    if (p != null) {
      p.then((s) => s?.call());
      _purr = null;
    }
  }

  // ---------- Hiệu ứng nổi ----------
  void float(double x, double y, String im, {double vy = -60, double life = 1.2, double size = 34, double? vx, double g = 0}) =>
      parts.add(PetPart(x, y, im, vx ?? rand(-15, 15), vy, life, size, g));
  void hearts(double x, double y, [int n = 3, String im = 'Red heart']) {
    for (var i = 0; i < n; i++) {
      float(x + rand(-20, 20), y + rand(-10, 10), im, vy: rand(-90, -50), size: rand(24, 36));
    }
  }

  // ---------- Hành vi ----------
  void set(String st, [double tm = 0]) {
    a.st = st;
    a.tm = tm;
  }

  void goTo(double x, double z, double speed, [VoidCallback? then]) {
    a.tgt = Offset(x.clamp(.08, .92), z.clamp(0.0, 1.0));
    a.speed = speed;
    a.onArrive = then;
    set('walk');
  }

  static const _busy = ['eat', 'drink', 'sleep', 'tub', 'shake', 'carry', 'react', 'petted'];
  bool get busy => _busy.contains(a.st);

  /// Chỉ số đang thấp nhất (< 35), nếu có.
  String? urgent() {
    final low = kPetStats.where((s) => petStat(pet, s.$1) < 35).toList()..sort((x, y) => petStat(pet, x.$1).compareTo(petStat(pet, y.$1)));
    return low.isEmpty ? null : low.first.$1;
  }

  void gain(Map<String, double> fields, double xp) {
    final before = petLevel(pet);
    fields.forEach((k, val) => pet[k] = _clamp(petStat(pet, k) + val));
    pet['xp'] = asDouble(pet['xp']) + xp;
    lv = petLevel(pet);
    if (lv > before) {
      onConfetti?.call();
      audio.sfx('win');
      audio.say(voice('petGrow'));
      final hasItem = data.petItems.any((i) => i.lv == lv);
      if (hasItem) {
        after(2.6, () {
          if (!alive) return;
          onToast?.call('🎁 ${tr('petNewItem')}');
          audio.sayPhrase('petNewItem');
        });
      }
    }
    onUi?.call();
  }

  // Quyết định việc tiếp theo khi rảnh.
  void decide() {
    if (mode == 'bath' && tub != null) {
      return goTo(tub!.dx, tub!.dy, .32, () {
        set('tub');
        audio.sfx('splash');
      });
    }
    if (ball != null && !ball!.held) return chaseBall();
    if (petStat(pet, 'food') < 45 && bowlF.n > 0) {
      return goTo(bowlF.x - .07, bowlF.z + .04, .3, () {
        a.f = 1;
        set('eat', 1.1);
      });
    }
    if (petStat(pet, 'water') < 45 && bowlW.n > 0) {
      return goTo(bowlW.x - .07, bowlW.z + .04, .3, () {
        a.f = 1;
        set('drink', 1);
      });
    }
    if (petStat(pet, 'energy') < 22) return goTo(bed.x, bed.z + .05, .2, () => set('sleep', 25));
    final need = urgent();
    if (need == 'food' || need == 'water') {
      final b = need == 'food' ? bowlF : bowlW;
      return goTo(b.x - .1, b.z + .1, .22, () {
        a.f = 1;
        set('beg', 4);
        speak(true);
        a.bubble = need;
      });
    }
    final r = math.Random().nextDouble();
    if (need == 'clean' && r < .4) return set('scratch', 1.6);
    if (r < .38) return goTo(rand(.12, .88), rand(.15, .95), rand(.14, .2), () => set('idle', rand(1, 2.5)));
    if (r < .55) return set('sit', rand(3, 5));
    if (r < .65 && petStat(pet, 'energy') < 70) return set('lie', rand(4, 7));
    if (r < .75) return set('sniff', rand(1.5, 2.5));
    if (r < .85 && petStat(pet, 'happy') > 60) {
      return goTo(.5 + rand(-.15, .15), .93, .24, () {
        set('look', 3);
        speak();
      });
    }
    if (r < .93 && petStat(pet, 'happy') > 70) return set('hop', 1.2);
    set('idle', rand(1.5, 3));
  }

  void chaseBall() {
    final b = ball;
    if (b == null) return;
    a.bubble = null;
    final sgn = (b.x - a.x) == 0 ? 1.0 : (b.x - a.x).sign;
    goTo(b.x - .05 * sgn, b.z, .5, () {
      final b = ball;
      if (b == null || b.held || b.h > .1) return set('idle', .2);
      a.f = b.x >= a.x ? 1 : -1;
      if (kind.id == 'dog') {
        b.held = true;
        set('carry');
        speak();
        goTo(.5, .95, .35, dropBall);
      } else {
        // Mèo, thỏ, hamster: đẩy/đập bóng lăn tiếp.
        b.vx = a.f * rand(.3, .7);
        b.vz = rand(-.4, .4);
        b.vh = kind.id == 'cat' ? 1.2 : .5;
        audio.sfx('pop');
        a.p['jump'] = kind.id == 'cat' ? .3 : .1;
        hearts(an.top.dx, an.top.dy, 1);
        gain({'happy': 6, 'energy': -3, 'food': -1}, 2);
        b.bats++;
        if (b.bats >= 3) {
          b.bats = 0;
          set('sit', 2.5);
        } else {
          set('idle', .5);
        }
      }
    });
  }

  void dropBall() {
    final b = ball;
    if (b == null) return set('idle', 1);
    b
      ..held = false
      ..x = a.x + a.f * .06
      ..z = math.min(1, a.z + .02)
      ..h = .05
      ..vx = 0
      ..vz = 0
      ..vh = 0;
    a.f = 1;
    set('look', 2.5);
    speak();
    hearts(an.top.dx, an.top.dy, 3);
    gain({'happy': 10, 'energy': -5, 'food': -2}, 4);
  }

  void throwBall(double vx, double vz, double vh) {
    ball ??= PetBall(.5, .95);
    final b = ball!;
    if (b.held) return;
    b
      ..vx = vx
      ..vz = vz
      ..vh = vh
      ..held = false;
    audio.sfx('jump');
    if (!['sleep', 'tub', 'shake'].contains(a.st)) {
      a.p['earUp'] = 1;
      after(.35, chaseBall);
    }
  }

  // ---------- Chạm ----------
  bool onPet(double x, double y) {
    final n = an;
    return math.sqrt(math.pow(x - n.body.dx, 2) + math.pow((y - n.body.dy) * 1.2, 2)) < n.len * .62 ||
        math.sqrt(math.pow(x - n.head.dx, 2) + math.pow(y - n.head.dy, 2)) < n.hr * 1.25;
  }

  Offset? ballXY() {
    final b = ball;
    return b == null ? null : Offset(b.x * W, sy(b.z) - b.h * H * .5 - unit(b.z) * .1);
  }

  void pointerDown(Offset pos) {
    final x = pos.dx, y = pos.dy;
    if (mode == 'bath' && a.st == 'tub') {
      scrubbing = true;
      scrub(x, y);
      return;
    }
    if (onPet(x, y)) {
      if (a.st == 'sleep') {
        set('wake', 1.2);
        audio.sfx('tap');
        pet['sleeping'] = false;
        return;
      }
      touching = PetTouch(x, y, time);
      return;
    }
    final b = ballXY();
    if (b != null && !ball!.held && (Offset(x, y) - b).distance < 60) {
      touching = PetTouch(x, y, time, ball: true);
      return;
    }
    if (busy && a.st != 'react') return;
    // Chạm sàn: gọi bạn ấy chạy lại (mèo rình rồi vồ).
    if (y > floorTop) {
      follow = Offset(x / W, toZ(y));
      a.p['earUp'] = 1;
      if (math.Random().nextDouble() < .5) speak();
    }
  }

  void pointerMove(Offset pos, bool down) {
    final x = pos.dx, y = pos.dy;
    if (scrubbing) return scrub(x, y);
    if (follow != null && down) {
      follow = Offset(x / W, toZ(math.max(floorTop, y)));
      return;
    }
    final tc = touching;
    if (tc == null) return;
    final d = (Offset(x, y) - Offset(tc.lx, tc.ly)).distance;
    if (tc.ball) {
      tc.vx = x - tc.lx;
      tc.vy = y - tc.ly;
      tc.lx = x;
      tc.ly = y;
      ball!
        ..x = x / W
        ..z = toZ(math.max(floorTop, y))
        ..h = 0;
      return;
    }
    tc.moved += d;
    tc.lx = x;
    tc.ly = y;
    if (tc.moved > 30) {
      // Vuốt ve
      if (a.st != 'petted') {
        set('petted', 1.5);
        a.tgt = null;
        startPurr();
      }
      a.tm = 1.2;
      if (tc.moved > 70) {
        tc.moved = 31;
        hearts(x, y - 20, 1);
        pet['happy'] = _clamp(petStat(pet, 'happy') + 1.5);
        pet['xp'] = asDouble(pet['xp']) + .4;
        if (math.Random().nextDouble() < .12) speak();
      }
    }
  }

  void pointerUp() {
    if (scrubbing) {
      scrubbing = false;
      return;
    }
    if (follow != null) {
      follow = null;
      if (a.st == 'walk' || a.st == 'follow') set('sit', 2.5);
      return;
    }
    final tc = touching;
    if (tc == null) return;
    touching = null;
    if (tc.ball) {
      throwBall(tc.vx / W * 18, -tc.vy.abs() / H * 14 - .2, .9);
      return;
    }
    if (a.st == 'petted') {
      stopPurr();
      save();
      if (petStat(pet, 'happy') > 80 && math.Random().nextDouble() < .4) audio.say(voice('petLove'));
      set('idle', 1);
      return;
    }
    if (time - tc.t < .4) tap();
  }

  void tap() {
    taps = taps.where((x) => time - x < 1.4).toList()..add(time);
    a.tgt = null;
    final top = an.top;
    if (taps.length >= 3) {
      taps = [];
      set('roll', 1);
      audio.sfx('jump');
      speak();
      hearts(top.dx, top.dy, 4, 'Sparkles');
      gain({'happy': 6}, 2);
      return;
    }
    final r = math.Random().nextDouble();
    a.f = 1;
    if (r < .4) {
      set('react', .8);
      a.p['jump'] = .35;
      speak();
    } else if (r < .7) {
      set('react', 1.1);
      a.p['tongue'] = 1;
      a.p['happy'] = 1;
      audio.sfx('pop');
      hearts(top.dx, top.dy, 2);
    } else {
      set('react', 1);
      speak();
      a.p['headRot'] = .3;
    }
    gain({'happy': 3}, 1);
  }

  // ---------- Tắm ----------
  void scrub(double x, double y) {
    if (!onPet(x, y) || foamProg >= 100) return;
    foamProg += 1.2;
    final rr = math.Random();
    if (rr.nextDouble() < .35 && a.foam.length < 22) {
      final n = an;
      a.foam.add([((x - n.body.dx) * a.f / n.len).clamp(-.5, .5), ((y - n.body.dy) / (n.len * .5)).clamp(-.8, .5), rand(.06, .12)]);
      if (rr.nextDouble() < .4) audio.sfx('pop');
    }
    if (rr.nextDouble() < .2) float(x, y, 'Bubbles', vy: -40, size: rand(18, 30));
    if (foamProg >= 100) onUi?.call(); // hiện nút Xả nước
  }

  void rinse() {
    if (rinsing || tub == null) return;
    rinsing = true;
    onUi?.call();
    var n = 0;
    void step() {
      if (!alive) return;
      final b = an;
      for (var k = 0; k < 4; k++) {
        float(b.body.dx + rand(-b.len * .6, b.len * .6), b.top.dy - 60, 'Droplet', vy: 260, size: 18, g: 400, life: .8);
      }
      if (n % 4 == 0) audio.sfx('splash');
      if (++n > 22) {
        a.foam = [];
        foamProg = 0;
        rinsing = false;
        gain({'clean': 100, 'happy': 6}, 8);
        audio.sayPhrase('petClean');
        // Nhảy ra khỏi chậu và lắc mình cho khô
        a.p['jump'] = .6;
        set('shake', 1.6);
        a.x = math.min(.9, (tub?.dx ?? .5) + .16);
        tub = null;
        mode = 'home';
        onUi?.call();
        return;
      }
      after(.07, step);
    }

    step();
  }

  // ---------- Nút hành động ----------
  void setMode(String m) {
    if (mode == 'bath' && m != 'bath') {
      tub = null;
      a.foam = [];
      foamProg = 0;
      rinsing = false;
      if (a.st == 'tub') set('idle', .5);
    }
    mode = m;
    if (m == 'play') {
      ball = PetBall(.5, .97);
      if (petStat(pet, 'energy') < 15) {
        audio.say(voice('petSleepy'));
      } else {
        a.p['earUp'] = 1;
        speak();
      }
    } else if (m == 'bath') {
      startBath();
    }
    if (m != 'play' && ball != null && !ball!.held) ball = null;
    onUi?.call();
  }

  /// Bấm nút hành động (feed/water/bath/play/sleep/wear).
  void action(String m) {
    audio.sfx('tap');
    if (m == 'water') return giveWater();
    if (m == 'sleep') return goSleep();
    setMode(mode == m ? 'home' : m);
  }

  void feed(String food) {
    if (petStat(pet, 'food') >= 95) {
      a.p['headRot'] = -.3;
      set('react', .6);
      audio.say(voice('petFull'));
      return;
    }
    bowlF.food = food;
    bowlF.n = 3;
    audio.sfx('pop');
    float(bowlF.x * W, sy(bowlF.z) - 40, 'Sparkles', size: 26);
    if (a.st == 'sleep') return;
    a.bubble = null;
    speak();
    goTo(bowlF.x - .07, bowlF.z + .04, .4, () {
      a.f = 1;
      set('eat', .5);
    });
  }

  void giveWater() {
    if (petStat(pet, 'water') >= 95) {
      set('react', .6);
      a.p['headRot'] = -.3;
      return;
    }
    bowlW.n = 3;
    audio.sfx('splash');
    float(bowlW.x * W, sy(bowlW.z) - 40, 'Droplet', size: 22);
    if (a.st == 'sleep') return;
    a.bubble = null;
    goTo(bowlW.x - .07, bowlW.z + .04, .4, () {
      a.f = 1;
      set('drink', .5);
    });
  }

  void throwToy() => throwBall(rand(-.6, .6), rand(-1.1, -.6), 1.1);

  void startBath() {
    tub = const Offset(.5, .55);
    a.foam = [];
    foamProg = 0;
    audio.sayPhrase('petScrub');
    goTo(tub!.dx, tub!.dy, .3, () {
      set('tub');
      audio.sfx('splash');
      a.f = 1;
    });
  }

  void goSleep() {
    if (a.st == 'sleep') {
      set('wake', 1.2);
      pet['sleeping'] = false;
      return;
    }
    setMode('home');
    audio.say(voice('petNight'));
    goTo(bed.x, bed.z + .02, .34, () {
      a.f = 1;
      set('sleep', 40);
    });
  }

  Map<String, String> get wear => {for (final e in asMap(pet['wear']).entries) e.key: e.value.toString()};

  /// Đeo/bỏ một món đồ thú cưng. Trả về false nếu chưa mở khoá.
  bool toggleWear(PetItem it) {
    if (lv < it.lv) {
      audio.sfx('wrong');
      onToast?.call('${tr('level')} ${it.lv}');
      return false;
    }
    final w = wear;
    if (w[it.slot] == it.img) {
      w.remove(it.slot);
    } else {
      w[it.slot] = it.img;
    }
    pet['wear'] = w;
    audio.sfx('pop');
    save();
    set('look', 2);
    a.p['happy'] = 1;
    onUi?.call();
    return true;
  }

  /// Chào bé khi vào phòng.
  void greet() {
    final need = urgent();
    a.x = .5;
    a.z = .7;
    after(.6, () {
      if (!alive) return;
      if (need != null) {
        final key = const {'food': 'petHungry', 'water': 'petThirsty', 'clean': 'petDirty', 'energy': 'petSleepy', 'happy': 'petSad'}[need]!;
        speak(true);
        audio.say(voice(key));
      } else {
        speak();
        a.p['jump'] = .4;
        set('look', 2.5);
        audio.say(voice('petLove'));
      }
    });
  }

  // ---------- Vòng lặp ----------
  void update(double dt) {
    time += dt;
    // Việc hẹn giờ (setTimeout của web) chạy theo đồng hồ mô phỏng.
    if (_later.isNotEmpty) {
      final due = _later.where((e) => e.$1 <= time).toList();
      _later.removeWhere((e) => e.$1 <= time);
      for (final e in due) {
        e.$2();
      }
    }
    final P = a.p;
    double p(String k) => P[k] ?? 0;
    // Chớp mắt
    blinkT -= dt;
    if (blinkT < 0) {
      P['blink'] = 1;
      if (blinkT < -.12) {
        P['blink'] = 0;
        blinkT = rand(2, 5);
      }
    }
    // Theo ngón tay
    final fl = follow;
    if (fl != null && !busy) {
      final dx = fl.dx - a.x, dz = fl.dy - a.z;
      if (math.sqrt(dx * dx + dz * .6 * dz * .6) > .06) {
        a.tgt = Offset(fl.dx - (dx == 0 ? 0 : dx.sign) * .05, fl.dy);
        a.speed = kind.id == 'cat' ? .42 : .38;
        a.onArrive = null;
        a.st = 'walk';
      } else if (kind.id == 'cat' && a.st != 'pounce') {
        set('pounce', .7);
        P['jump'] = .45;
        audio.sfx('jump');
      } else if (a.st == 'walk') {
        set('look', .5);
      }
    }
    // Đi tới đích
    final tg = a.tgt;
    if (tg != null && a.st == 'walk') {
      final dx = tg.dx - a.x, dz = tg.dy - a.z, d = math.sqrt(dx * dx + dz * dz);
      final vv = a.speed * dt;
      if (d <= vv || d < .005) {
        a.x = tg.dx;
        a.z = tg.dy;
        a.tgt = null;
        final fn = a.onArrive;
        a.onArrive = null;
        if (fn != null) {
          fn();
        } else {
          set('idle', rand(1, 2));
        }
      } else {
        a.x += dx / d * vv;
        a.z += dz / d * vv;
        if (dx.abs() > .01) a.f = dx > 0 ? 1 : -1;
        P['phase'] = p('phase') + vv * 38 / math.max(.6, kz(a.z));
      }
    }
    // Bóng: lăn trên sàn, nảy, chậm dần.
    final b = ball;
    if (b != null && !b.held) {
      b.vh -= 3.2 * dt;
      b.h += b.vh * dt;
      if (b.h < 0) {
        b.h = 0;
        if (b.vh.abs() > .4) audio.sfx('pop');
        b.vh = -b.vh * .45;
        if (b.vh.abs() < .15) b.vh = 0;
      }
      b.x += b.vx * dt;
      b.z += b.vz * dt;
      final fr = b.h > 0 ? .995 : math.pow(.25, dt).toDouble();
      b.vx *= fr;
      b.vz *= fr;
      if (b.x < .05 || b.x > .95) {
        b.vx *= -.6;
        b.x = b.x.clamp(.05, .95);
      }
      if (b.z < 0 || b.z > 1) {
        b.vz *= -.6;
        b.z = b.z.clamp(0.0, 1.0);
      }
      // Bóng dừng mà bạn ấy đang đuổi chỗ cũ: cập nhật đích
      if (a.st == 'walk' && a.speed >= .5 && a.tgt != null) {
        a.tgt = Offset(b.x - .05 * ((b.x - a.x) == 0 ? 1 : (b.x - a.x).sign), b.z);
      }
    }
    // Trạng thái
    a.tm -= dt;
    final T = <String, double>{
      'walk': 0, 'sit': 0, 'lie': 0, 'dip': 0, 'sleep': 0, 'happy': 0, 'sad': 0, 'crouch': 0, 'tongue': 0, 'headRot': 0, 'roll': 0, 'bath': 0,
      'shake': 0, 'earUp': 0, 'squash': 0,
    };
    final low = urgent();
    T['sad'] = low != null && !['petted', 'react', 'roll', 'eat', 'drink'].contains(a.st) ? .7 : 0;
    final happy = petStat(pet, 'happy');
    T['tailAmp'] = happy > 70 ? .7 : happy > 40 ? .4 : .15;
    T['tailSpeed'] = happy > 70 ? 14 : 6;
    final an0 = an;
    switch (a.st) {
      case 'walk':
        T['walk'] = a.speed > .35 ? 1 : .8;
        T['tailAmp'] = .6;
      case 'sit':
        T['sit'] = 1;
        if (a.tm <= 0) decide();
      case 'look':
        T['sit'] = 1;
        T['happy'] = happy > 70 ? 1 : 0;
        T['tailAmp'] = .9;
        T['tailSpeed'] = 16;
        T['headRot'] = math.sin(time * 2) * .12;
        if (a.tm <= 0) decide();
      case 'lie':
        T['lie'] = 1;
        if (a.tm <= 0) decide();
      case 'sniff':
        T['dip'] = .55 + math.sin(time * 12) * .08;
        T['walk'] = .3;
        a.x = (a.x + a.f * .02 * dt).clamp(.05, .95);
        P['phase'] = p('phase') + dt * 3;
        if (a.tm <= 0) decide();
      case 'hop':
        T['happy'] = 1;
        T['tailAmp'] = 1;
        T['tailSpeed'] = 18;
        if ((a.tm * 3).floor() != ((a.tm + dt) * 3).floor()) P['jump'] = .35;
        if (a.tm <= 0) decide();
      case 'beg':
        T['sit'] = 1;
        T['sad'] = 1;
        if (a.tm <= 0) {
          a.bubble = null;
          decide();
        }
      case 'scratch':
        T['sit'] = 1;
        T['headRot'] = .3;
        P['phase'] = p('phase') + dt * 25;
        T['walk'] = .3;
        if (math.Random().nextDouble() < dt * 3) float(an0.body.dx, an0.body.dy, 'Sparkles', size: 16);
        if (a.tm <= 0) decide();
      case 'eat':
      case 'drink':
        final eating = a.st == 'eat';
        T['dip'] = 1;
        T['happy'] = .4;
        P['mouth'] = math.max(0, math.sin(time * 14)) * .8;
        T['tongue'] = eating ? 0 : math.max(0, math.sin(time * 10));
        if (a.tm <= 0) {
          final bw = eating ? bowlF : bowlW;
          if (bw.n > 0) {
            bw.n--;
            a.tm = 1.1;
            if (eating) {
              audio.sfx('eat');
              gain({'food': 14, 'happy': 2}, 3);
              float(an0.mouth.dx, an0.mouth.dy - 10, 'Sparkles', size: 20);
            } else {
              audio.sfx('splash');
              gain({'water': 18}, 2);
              float(an0.mouth.dx, an0.mouth.dy, 'Droplet', size: 16, vy: -40);
            }
          }
          if (bw.n <= 0 || petStat(pet, eating ? 'food' : 'water') >= 99) {
            P['mouth'] = 0;
            set('react', 1);
            P['tongue'] = 1;
            T['happy'] = 1;
            P['jump'] = .25;
            if (eating || math.Random().nextDouble() < .5) audio.sayPhrase(eating ? 'petYum' : 'petDrink');
          }
        }
      case 'sleep':
        T['lie'] = 1;
        T['sleep'] = 1;
        T['tailAmp'] = .05;
        pet['sleeping'] = true;
        if (math.Random().nextDouble() < dt * .8) float(an0.top.dx + 20, an0.top.dy, 'Zzz', vy: -30, size: 30, life: 2);
        if (math.Random().nextDouble() < dt * .3) audio.sfx('snore');
        pet['energy'] = _clamp(petStat(pet, 'energy') + dt * 4);
        if (petStat(pet, 'energy') >= 100 || a.tm <= 0) {
          pet['sleeping'] = false;
          set('wake', 1.2);
          gain({}, 3);
        }
      case 'wake':
        T['sit'] = 1;
        P['mouth'] = math.max(0, math.sin((1.2 - a.tm) * 3));
        pet['sleeping'] = false;
        if (a.tm <= 0) {
          P['mouth'] = 0;
          speak();
          decide();
        }
      case 'petted':
        T['happy'] = 1;
        T['sit'] = .6;
        T['tailAmp'] = 1;
        T['tailSpeed'] = 16;
        T['headRot'] = -.15;
        if (a.tm <= 0) {
          stopPurr();
          set('idle', 1);
        }
      case 'react':
        T['happy'] = p('tongue') > .3 ? 1 : T['happy']!;
        if (a.tm <= 0) {
          P['tongue'] = 0;
          decide();
        }
      case 'roll':
        T['roll'] = math.min(1, 1 - a.tm);
        T['happy'] = 1;
        if (a.tm <= 0) {
          P['roll'] = 0;
          set('react', .6);
          P['jump'] = .3;
        }
      case 'pounce':
        T['crouch'] = a.tm > .45 ? 1 : 0;
        T['happy'] = 1;
        if (a.tm <= 0) set(follow != null ? 'look' : 'idle', .5);
      case 'carry':
      case 'tub':
        final inTub = a.st == 'tub';
        T['bath'] = inTub ? 1 : 0;
        T['sit'] = inTub ? .3 : 0;
        T['happy'] = inTub && a.foam.length > 6 ? 1 : 0;
      case 'shake':
        T['shake'] = 1;
        T['happy'] = 1;
        if (math.Random().nextDouble() < dt * 25) {
          float(an0.body.dx + rand(-40, 40), an0.body.dy, 'Droplet', vx: rand(-160, 160), vy: rand(-160, -40), g: 500, size: 14, life: .7);
        }
        if (a.tm <= 0) {
          set('hop', 1);
          speak();
        }
      default:
        if (a.tm <= 0) decide();
    }
    if (a.st == 'carry') T['walk'] = 1;
    easePose(P, T, dt, a.st == 'roll' ? 30 : 7);
    // Nhảy: rơi tự nhiên
    P['jump'] = math.max(0, p('jump') - dt * 1.4 * (p('jump') > .2 ? 1 : 1.6));
    if (!['eat', 'drink', 'wake', 'react'].contains(a.st) && p('mouth') > 0) P['mouth'] = math.max(0, p('mouth') - dt * 2);
    // Nhìn theo ngón tay / bóng
    final look = ball != null && !ball!.held ? ball!.x : follow != null ? follow!.dx : .5;
    P['lookX'] = (p('lookX') + ((look - a.x) * a.f * 3 - p('lookX')) * math.min(1, dt * 4)).clamp(-1.0, 1.0);
    // Hạt hiệu ứng
    for (var i = parts.length - 1; i >= 0; i--) {
      final q = parts[i];
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      q.vy += q.g * dt;
      q.life -= dt;
      if (q.life <= 0) parts.removeAt(i);
    }
    // Lưu và cập nhật thanh chỉ số định kỳ
    if (time - lastSave > 5) {
      lastSave = time;
      save();
    }
    if (time - lastBars > 1) {
      lastBars = time;
      lv = petLevel(pet);
      onUi?.call();
    }
    notifyListeners();
  }

  // ---------- Vẽ ----------
  void _spr(Canvas c, String name, double x, double y, double w, {double? h, double rot = 0, double alpha = 1}) =>
      drawImageCentered(c, images[name], x, y, w, h ?? w, false, rot, alpha);

  void _drawRoom(Canvas c) {
    final ft = floorTop, night = a.st == 'sleep', bath = mode == 'bath';
    // Tường
    c.drawRect(
        Rect.fromLTWH(0, 0, W, ft),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, ft), bath ? const [Color(0xFFD0EBFF), Color(0xFFE7F5FF)] : const [Color(0xFFFFE3EC), Color(0xFFFFF0F6)]));
    final stripe = Paint()..color = bath ? const Color(0x99FFFFFF) : const Color(0x59FFC0D6);
    if (bath) {
      for (var y = 20.0; y < ft; y += 34) {
        c.drawRect(Rect.fromLTWH(0, y, W, 2), stripe);
      }
      for (var x = 0.0; x < W; x += 34) {
        c.drawRect(Rect.fromLTWH(x, 0, 2, ft), stripe);
      }
    } else {
      for (var x = 0.0; x < W; x += 80) {
        c.drawRect(Rect.fromLTWH(x, 0, 40, ft), stripe);
      }
    }
    // Cửa sổ: ngày/đêm
    final wx = W * .1, wy = H * .08, ww = math.min(W * .2, 150.0), wh = ww * .8;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wx - 8, wy - 8, ww + 16, wh + 16), const Radius.circular(14)), Paint()..color = const Color(0xFFFFFFFF));
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(wx, wy, ww, wh), const Radius.circular(8)),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, wy), Offset(0, wy + wh), night ? const [Color(0xFF1B1F4B), Color(0xFF3B3F8F)] : const [Color(0xFF74C0FC), Color(0xFFD0EBFF)]));
    _spr(c, night ? 'Crescent moon' : 'Sun', wx + ww * .7, wy + wh * .35, ww * .32);
    final white = Paint()..color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(wx + ww / 2 - 3, wy, 6, wh), white);
    c.drawRect(Rect.fromLTWH(wx, wy + wh / 2 - 3, ww, 6), white);
    if (!bath) _spr(c, 'Framed picture', W * .8, H * .18, math.min(W * .14, 100));
    // Sàn
    c.drawRect(
        Rect.fromLTWH(0, ft, W, H - ft),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, ft), Offset(0, H), bath ? const [Color(0xFFA5D8FF), Color(0xFFD0EBFF)] : const [Color(0xFFE8C39E), Color(0xFFF3D5B5)]));
    final ln = Paint()
      ..color = const Color(0x0F000000)
      ..strokeWidth = 2;
    for (var k = -6; k <= 12; k++) {
      c.drawLine(Offset(W / 2 + k * 60, ft), Offset(W / 2 + k * 140 - W * .3, H), ln);
    }
    c.drawRect(Rect.fromLTWH(0, ft - 4, W, 6), Paint()..color = const Color(0x14000000));
    if (!bath) {
      // Thảm tròn
      c.drawOval(Rect.fromCenter(center: Offset(W * .5, sy(.62)), width: W * .52, height: (H - ft) * .4), Paint()..color = const Color(0x59FF92AA));
      _spr(c, 'Potted plant', W * .94, sy(0) - H * .05, math.min(W * .12, 90));
    }
  }

  void _oval(Canvas c, double x, double y, double rx, double ry, Color col) =>
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2), Paint()..color = col);

  void _bedDraw(Canvas c) {
    final x = bed.x * W, y = sy(bed.z), s = unit(bed.z) * 1.1;
    _oval(c, x, y, s * .75, s * .24, const Color(0xFF9775FA));
    _oval(c, x, y - s * .05, s * .62, s * .17, const Color(0xFFB197FC));
    _oval(c, x, y - s * .06, s * .5, s * .11, const Color(0xFFE5DBFF));
  }

  void _bowlDraw(Canvas c, PetBowl b, Color color, bool food) {
    final x = b.x * W, y = sy(b.z), s = unit(b.z) * .42;
    _oval(c, x, y + 3, s * .62, s * .14, const Color(0x1F000000));
    c.drawPath(
        Path()
          ..moveTo(x - s * .6, y - s * .3)
          ..lineTo(x + s * .6, y - s * .3)
          ..lineTo(x + s * .45, y)
          ..lineTo(x - s * .45, y)
          ..close(),
        Paint()..color = color);
    c.drawRect(Rect.fromLTWH(x - s * .5, y - s * .22, s, s * .06), Paint()..color = const Color(0x59FFFFFF));
    final fy = y - s * .3;
    if (b.n > 0) {
      if (food) {
        for (var k = 0; k < b.n + 1; k++) {
          _spr(c, b.food, x + (k - b.n / 2) * s * .3, fy - s * .1, s * .5);
        }
      } else {
        _oval(c, x, fy, s * .58, s * (.06 + b.n * .02), const Color(0xFF4DABF7));
        _oval(c, x - s * .2, fy - s * .02, s * .12, s * .03, const Color(0x99FFFFFF));
      }
    } else {
      _oval(c, x, fy, s * .58, s * .1, const Color(0x40000000));
    }
  }

  void _drawBall(Canvas c) {
    final b = ball;
    if (b == null) return;
    final s = unit(b.z) * .3;
    double bx, by;
    if (b.held && _an != null) {
      bx = _an!.mouth.dx + a.f * s * .3;
      by = _an!.mouth.dy + s * .2;
    } else {
      bx = b.x * W;
      by = sy(b.z) - b.h * H * .5 - s * .5;
      _oval(c, bx, sy(b.z), s * .5 * (1 - math.min(.5, b.h)), s * .14, const Color(0x26000000));
    }
    _spr(c, kind.toy, bx, by, s, rot: b.x * 30);
  }

  void _tubBack(Canvas c) {
    final x = tub!.dx * W, y = sy(tub!.dy), s = unit(tub!.dy);
    _oval(c, x, y - s * .38, s * .72, s * .16, const Color(0xFFE7F5FF));
    _oval(c, x, y - s * .36, s * .64, s * .12, const Color(0xFF74C0FC));
  }

  void _tubFront(Canvas c) {
    final x = tub!.dx * W, y = sy(tub!.dy), s = unit(tub!.dy);
    final path = Path()
      ..moveTo(x - s * .72, y - s * .38)
      ..quadraticBezierTo(x - s * .7, y, x - s * .4, y)
      ..lineTo(x + s * .4, y)
      ..quadraticBezierTo(x + s * .7, y, x + s * .72, y - s * .38)
      ..quadraticBezierTo(x, y - s * .22, x - s * .72, y - s * .38);
    c.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
    c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFA5D8FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    for (var k = 0; k < 6; k++) {
      _spr(c, 'Bubbles', x - s * .55 + k * s * .22, y - s * .36 + math.sin(time * 2 + k) * 3, s * .2);
    }
  }

  void paint(Canvas c) {
    _drawRoom(c);
    final s = unit(a.z);
    final petC = petStat(pet, 'clean');
    // Sắp các vật theo chiều sâu z.
    final objs = <(double, void Function())>[
      (bed.z, () => _bedDraw(c)),
      (bowlF.z, () => _bowlDraw(c, bowlF, const Color(0xFFFF6B6B), true)),
      (bowlW.z, () => _bowlDraw(c, bowlW, const Color(0xFF4DABF7), false)),
      (
        a.z + .001,
        () {
          if (tub != null) _tubBack(c);
          final inTub = a.st == 'tub' && tub != null;
          final y = sy(a.z) - (inTub ? s * .25 : 0);
          _an = drawPet(c, kind.id, a.x * W, y, a.p,
              PetDrawOpts(u: s, t: time, f: a.f, wear: wear, dirty: petC < 40 ? (40 - petC) / 30 : 0, foam: a.foam, images: images));
          if (inTub) _tubFront(c);
        }
      ),
    ];
    if (ball != null && !ball!.held) objs.add((ball!.z, () => _drawBall(c)));
    objs.sort((x, y) => x.$1.compareTo(y.$1));
    for (final o in objs) {
      o.$2();
    }
    if (ball != null && ball!.held) _drawBall(c);
    // Bong bóng suy nghĩ: đang cần gì
    final need = a.bubble ?? (['idle', 'sit', 'lie'].contains(a.st) ? urgent() : null);
    if (need != null && a.st != 'sleep' && _an != null) {
      final bx = _an!.top.dx + s * .35 * a.f, by = _an!.top.dy - s * .25 + math.sin(time * 2) * 4;
      _spr(c, 'Thought balloon', bx, by, s * .55);
      _spr(c, need == 'food' ? bowlF.food : kPetStats.firstWhere((x) => x.$1 == need).$2, bx, by - s * .04, s * .26);
    }
    // Ban đêm khi ngủ
    if (a.st == 'sleep') c.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = const Color(0x61141846));
    for (final q in parts) {
      _spr(c, q.im, q.x, q.y, q.size, alpha: math.min(1, q.life / q.max * 2));
    }
    if (mode == 'bath' && a.st == 'tub' && foamProg < 100) {
      final w = math.min(260.0, W * .5);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(W / 2 - w / 2, 12, w, 18), const Radius.circular(9)), Paint()..color = const Color(0x40000000));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(W / 2 - w / 2 + 3, 15, (w - 6) * foamProg / 100, 12), const Radius.circular(6)),
          Paint()..color = const Color(0xFF74C0FC));
    }
  }

  @override
  void dispose() {
    alive = false;
    stopPurr();
    _later.clear();
    super.dispose();
  }
}
