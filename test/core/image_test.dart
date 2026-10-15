// Tên hình → asset (slug như ui.js) và mọi hình được dữ liệu dùng đều có file.
import 'dart:convert';
import 'dart:io';

import 'package:be_vui_hoc/core/ui/dressed.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slug giống web', () {
    expect(slug('Red apple'), 'red-apple');
    expect(imgAsset('Red apple'), 'assets/img/red-apple.webp');
    expect(slug('1st place medal'), '1st-place-medal');
    expect(slug('Globe showing Asia-Australia'), 'globe-showing-asia-australia');
    expect(slug('T-Rex'), 't-rex');
    expect(slug('  Man superhero '), 'man-superhero');
    expect(slug('Bé Na'), 'b-na');
  });

  test('mọi hình trong app.json có file trong assets/img', () {
    final app = jsonDecode(File('assets/data/app.json').readAsStringSync()) as Map<String, dynamic>;
    final names = <String>{
      for (final k in ['mascots', 'islands', 'wardrobe', 'pets']) for (final x in app[k] as List) (x as Map)['img'] as String,
      ...(app['stickers'] as List).cast<String>(),
      ...(app['images'] as List).cast<String>(),
      'Seedling', 'Herb', 'Deciduous tree', 'Glowing star', 'Trophy', 'Joystick', 'Admission tickets', 'Paw prints', 'Star', 'Coin', 'Fire', 'Backpack', 'Sparkles',
    };
    final missing = names.where((n) => !File(imgAsset(n)).existsSync()).toList();
    expect(missing, isEmpty);
  });

  test('ảnh chụp trong photos.json đều có file', () {
    final photos = jsonDecode(File('assets/data/photos.json').readAsStringSync()) as Map<String, dynamic>;
    final missing = photos.values.map((v) => 'assets/${(v as Map)['f']}').where((f) => !File(f).existsSync()).toList();
    expect(missing, isEmpty);
  });

  test('photoAsset / groupUsesPhotos', () {
    expect(groupUsesPhotos({}, ['Cat']), false);
  });

  test('nền tủ đồ CSS → Gradient', () {
    final g = cssGradient('linear-gradient(180deg,#d0ebff,#74c0fc 60%,#ffe8a1 60%)') as LinearGradient;
    expect(g.colors.length, 3);
    expect(g.stops, [0, .6, .6]);
    expect(cssGradient('radial-gradient(circle at 30% 20%,#5f3dc4,#1a1b4b 70%)'), isA<RadialGradient>());
    expect(cssGradient(null), isNull);
  });
}
