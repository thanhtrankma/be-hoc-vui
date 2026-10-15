// figure.dart: API trang phục giữ nguyên, nạp sprite thật, đổi màu áo trên sprite, vẽ mọi tư thế/chân dung/thú.
import 'dart:ui' as ui;

import 'package:be_vui_hoc/core/ui/motion.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _poses = ['idle', 'run', 'walk', 'sprint', 'jump', 'fall', 'punch', 'kick', 'flykick', 'swing', 'throw', 'block', 'hurt', 'sit', 'pull', 'cheer', 'talk', 'interact', 'show'];

Future<ui.Image> _render(void Function(Canvas c) paint, [int w = 120, int h = 160]) {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  return rec.endRecording().toImage(w, h);
}

Future<List<int>> _pixels(ui.Image img) async => (await img.toByteData())!.buffer.asUint8List().toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trang phục: costumeOf, lookOf, setPlayer/heroOf', () {
    expect(costumeOf('Princess').hat, 'Crown');
    expect(costumeOf('Robot').base, 'robot');
    expect(costumeOf('Không có').base, 'boy');
    final look = lookOf({'base': 'girl', 'shirt': '#e03131', 'hat': 'Top hat'});
    expect(look.shirt, const Color(0xFFE03131));
    expect(look.pants, isNull);
    setPlayer('Robot', {'base': 'girl', 'shirt': '#e03131'});
    expect(heroOf().base, 'girl');
    expect(heroOf('Robot').base, 'girl');
    expect(heroOf('Princess').base, 'girl');
    expect(heroOf('Princess').hat, 'Crown');
    setPlayer('Robot', null);
    expect(heroOf('Robot').base, 'robot');
    expect(figureSize(100).w, closeTo(78, .01));
    expect(kFriends.length, 4);
    expect(kLookHats.first, isNull);
  });

  testWidgets('nạp sprite thật, đổi màu áo, vẽ mọi tư thế + mũ + vũ khí + chân dung + thú', (tester) async {
    await tester.runAsync(() async {
      await preloadFigures();
      expect(figuresReady, isTrue);
      // đổi màu áo thay đổi điểm ảnh
      final red = await _pixels(await _render((c) => drawFigure(c, 60, 156, 130, const Costume(base: 'boy', shirt: Color(0xFFE03131)), shadow: false)));
      final blue = await _pixels(await _render((c) => drawFigure(c, 60, 156, 130, const Costume(base: 'boy', shirt: Color(0xFF1C7ED6)), shadow: false)));
      expect(red.any((v) => v != 0), isTrue);
      expect(red, isNot(equals(blue)));
      // mọi tư thế, mọi base, mũ, vũ khí (tên hình) không lỗi
      for (final base in ['boy', 'girl', 'kid', 'dad', 'robot']) {
        for (final pose in _poses) {
          await _render((c) => drawFigure(c, 60, 156, 130, Costume(base: base, hat: 'Crown', hair: const Color(0xFF8D5524)),
              pose: pose, t: 1.3, act: .5, face: -1, weapon: 'Dagger', team: Colors.red, alpha: .8));
          await _render((c) => drawFigure(c, 60, 156, 130, Costume(base: base), pose: pose, noHead: true));
        }
        await _render((c) => drawHead(c, 60, 60, 40, Costume(base: base, hat: 'racing'), face: -1, hurt: true));
      }
      for (final kind in ['dog', 'cat', 'fox', 'rabbit', 'hamster', 'panda']) {
        final pet = petBuddy(kind)..update(.1, true);
        await _render((c) => pet.draw(c, 60, 150, 50, -1));
      }
    });
    Motion.enabled = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: FigureView(costume: costumeOf('Princess'), size: 120))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FigureView + PetView dựng được (không hoạt ảnh)', (tester) async {
    Motion.enabled = false;
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        FigureView(costume: kBot, size: 100, controller: FigureController(pose: 'cheer')),
        const PetView(kind: 'cat', size: 80),
      ]),
    ));
    expect(find.byType(FigureView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
