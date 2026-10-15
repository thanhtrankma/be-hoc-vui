// Động cơ màn chơi (không cần Flame/ảnh): cả 10 vùng chạy + vẽ không lỗi, đánh thắng một trận thật,
// hết máu thì thua, joystick di chuyển, trận theo lượt ở Xứ Tuyết, đào kho báu ở Sa Mạc.
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/features/rpg/rpg.dart';
import 'package:be_vui_hoc/features/rpg/rpgcore.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 900, _h = 540, _dt = 1 / 60;

ZoneCtx _z(int r, int s, {int atk = 30, int maxhp = 200, String? pet = 'dog', int potions = 2}) => ZoneCtx(
      st: RpgStats(lv: 5, atk: atk, def: 3, maxhp: maxhp),
      heroImg: 'Robot',
      weaponImg: 'Dagger',
      pet: pet,
      potions: potions,
      r: r,
      s: s,
    );

RpgStage _make(int r, ZoneCtx z, {double w = _w, double h = _h}) => kZones[r].def.make(z, RpgArt.empty(), w, h, SilentAudio());

void _render(RpgStage st) {
  final rec = ui.PictureRecorder();
  st.render(ui.Canvas(rec));
  rec.endRecording().dispose();
}

/// Chạy tối đa `secs` giây; mỗi bước gọi `each`. Trả kết quả nếu màn kết thúc.
RunResult? _run(RpgStage st, double secs, [void Function(double t)? each]) {
  var t = 0.0;
  var n = 0;
  while (t < secs) {
    each?.call(t);
    final r = st.update(_dt);
    if (n++ % 20 == 0) _render(st);
    if (r != null) return r;
    t += _dt;
  }
  return null;
}

/// Bấm một nút tròn trên màn (chạm xuống rồi nhấc).
void _tap(RpgStage st, Btn b, int id) {
  st.M.down(id, b.x, b.y);
  st.M.up(id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var r = 0; r < kZones.length; r++) {
    for (final s in [0, 3, kStages - 1]) {
      test('vùng ${kZones[r].vi} màn ${s + 1}: chạy 8 giây + vẽ không lỗi (ngang + dọc)', () {
        for (final size in [(_w, _h), (390.0, 760.0)]) {
          final st = _make(r, _z(r, s), w: size.$1, h: size.$2);
          // Chạm lung tung để thử mọi nhánh điều khiển
          _run(st, 8, (t) {
            final k = (t * 60).round();
            if (k % 45 == 0) {
              st.M.down(k, st.W * ((k * 37) % 100) / 100, st.H * ((k * 53) % 100) / 100);
              st.M.move(k, st.W * .3, st.H * .5);
              st.M.up(k);
            }
          });
          _render(st);
          st.dispose();
        }
      });
    }
  }

  test('Rừng Xanh: đánh thắng trận thật (đứng chém quái tới gần)', () {
    final st = _make(0, _z(0, 0, atk: 400, maxhp: 99999)) as Arena;
    final atk = st.btnList.firstWhere((b) => b.id == 'atk');
    var id = 100;
    final res = _run(st, 90, (t) {
      if ((t * 60).round() % 15 == 0) _tap(st, atk, id++);
    });
    expect(res, isNotNull);
    expect(res!.win, isTrue);
    expect(res.kills, greaterThanOrEqualTo(6));
    expect(res.xp, greaterThan(0));
  });

  test('hết máu thì thua; bình máu giảm khi dùng', () {
    final z = _z(9, 0, atk: 1, maxhp: 30, potions: 1);
    final st = _make(9, z) as Arena;
    st.hero.hp = 10;
    final pot = st.btnList.firstWhere((b) => b.id == 'pot');
    st.introT = 0;
    _tap(st, pot, 1);
    st.update(_dt);
    expect(z.potions, 0);
    final res = _run(st, 120);
    expect(res, isNotNull);
    expect(res!.win, isFalse);
    expect(res.potions, 0);
  });

  test('joystick: kéo nửa trái màn hình thì bé đi', () {
    final st = _make(0, _z(0, 0)) as Arena;
    st.introT = 0;
    final x0 = st.hero.x;
    st.M.down(1, 150, 300);
    st.M.move(1, 230, 300);
    for (var i = 0; i < 30; i++) {
      st.update(_dt);
    }
    st.M.up(1);
    expect(st.hero.x, greaterThan(x0 + 20));
    // Phím mũi tên
    final y0 = st.hero.y;
    st.keys.add('arrowup');
    for (var i = 0; i < 30; i++) {
      st.update(_dt);
    }
    expect(st.hero.y, lessThan(y0 - 20));
  });

  test('Xứ Tuyết: trận theo lượt (⚔️ rồi 👊) tới khi thắng', () {
    final st = _make(3, _z(3, 0, atk: 500, maxhp: 99999, pet: null));
    var id = 1;
    final res = _run(st, 60, (t) {
      if ((t * 60).round() % 20 != 0) return;
      // Bấm nút đang hiện (⚔️ khi chọn, 👊 khi canh vạch)
      for (final b in (st as dynamic).game.acts as List<Btn>) {
        if (!b.hidden && (b.id == 'atk' || b.id == 'go')) {
          _tap(st, b, id++);
          break;
        }
      }
    });
    expect(res, isNotNull);
    expect(res!.win, isTrue);
    expect(res.kills, greaterThan(0));
  });

  test('debugWin kết thúc màn bằng chiến thắng sau bảng kết thúc', () {
    for (var r = 0; r < kZones.length; r++) {
      final st = _make(r, _z(r, 1));
      st.debugWin();
      final res = _run(st, 3);
      expect(res?.win, isTrue, reason: kZones[r].id);
    }
  });
}
