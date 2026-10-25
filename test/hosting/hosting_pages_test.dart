// Trang web Firebase Hosting (hosting/public/, sinh bằng `python3 hosting/build_pages.py`) khớp nguồn trong app
// (assets/legal/*.md, photos.json) và tự chứa: không script, không phông/stylesheet ngoài, không trình theo dõi.
import 'dart:convert';
import 'dart:io';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:flutter_test/flutter_test.dart';

String _esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

void main() {
  final pages = {
    'index.html': ['assets/legal/about_vi.md', 'assets/legal/about_en.md'],
    'privacy/index.html': ['assets/legal/privacy_vi.md'],
    'privacy/en/index.html': ['assets/legal/privacy_en.md'],
    'credits/index.html': <String>[],
    '404.html': <String>[],
  };

  for (final MapEntry(key: page, value: sources) in pages.entries) {
    test('hosting/public/$page: có, tự chứa, khớp nguồn', () {
      final f = File('hosting/public/$page');
      expect(f.existsSync(), isTrue, reason: 'chạy python3 hosting/build_pages.py');
      final html = f.readAsStringSync();
      expect(html, startsWith('<!doctype html>'));
      expect(html, contains('name="viewport"'));
      expect(html.toLowerCase(), isNot(contains('<script')));
      expect(html, isNot(contains('<link')));
      expect(html, isNot(contains('@import')));
      expect(html, isNot(contains('fonts.googleapis')));
      expect(html.toLowerCase(), isNot(contains('pilot.com'))); // không còn link trang web cũ
      for (final src in sources) {
        final md = File(src).readAsStringSync();
        for (final line in md.split('\n').where((l) => l.startsWith('#'))) {
          final text = line.replaceFirst(RegExp(r'^#+ '), '').replaceAll('**', '');
          expect(html, contains(_esc(text)), reason: '$page thiếu mục "$text" của $src — chạy lại build_pages.py');
        }
      }
    });
  }

  test('chính sách: ngày hiệu lực, email liên hệ, vùng máy chủ, link bản web', () {
    for (final src in ['assets/legal/privacy_vi.md', 'assets/legal/privacy_en.md']) {
      final md = File(src).readAsStringSync();
      expect(md, contains('beatgone2503@gmail.com'));
      expect(md, contains('asia-southeast1'));
      expect(md, contains('Remote Config')); // nói rõ là không dùng
      expect(md, contains('https://bevuihoc-app.web.app/privacy'));
    }
    expect(File('assets/legal/privacy_vi.md').readAsStringSync(), contains('25/10/2026'));
    expect(File('assets/legal/privacy_en.md').readAsStringSync(), contains('25 October 2026'));
  });

  test('ghi công: mọi ảnh trong photos.json và mọi file CREDITS của sprites có trên trang', () {
    final html = File('hosting/public/credits/index.html').readAsStringSync();
    final photos = (jsonDecode(File('assets/data/photos.json').readAsStringSync()) as Map).cast<String, dynamic>();
    for (final e in photos.entries) {
      expect(html, contains('<td>${_esc(e.key)}</td>'), reason: e.key);
    }
    final credits = Directory('assets/sprites').listSync(recursive: true).whereType<File>().where((f) => f.uri.pathSegments.last.toUpperCase().startsWith('CREDITS'));
    expect(credits, isNotEmpty);
    for (final f in credits) {
      final first = f.readAsStringSync().trim().split('\n').first;
      expect(html, contains(_esc(first).split(' — ').first), reason: f.path);
    }
    expect(html, contains('Fluent Emoji'));
  });

  test('ghi công ảnh: ảnh CC BY / BY-SA đều có tác giả; giấy phép có link; ghi rõ ảnh đã thu nhỏ/cắt', () {
    final html = File('hosting/public/credits/index.html').readAsStringSync();
    final photos = (jsonDecode(File('assets/data/photos.json').readAsStringSync()) as Map).cast<String, dynamic>();
    for (final e in photos.entries) {
      final p = PhotoInfo.fromJson((e.value as Map).cast<String, dynamic>());
      if ((p.lic ?? '').contains('BY')) {
        expect(p.by?.trim(), isNotEmpty, reason: '${e.key}: giấy phép ${p.lic} bắt buộc ghi tác giả');
        expect(p.licUrl, isNotNull, reason: '${e.key}: ${p.lic}');
      }
      if (p.licUrl != null) expect(html, contains('<a href="${p.licUrl}">${_esc(p.lic!)}</a>'), reason: e.key);
    }
    expect(photoLicenseUrl('CC BY-SA 4.0'), 'https://creativecommons.org/licenses/by-sa/4.0/');
    expect(photoLicenseUrl('CC BY 2.0'), 'https://creativecommons.org/licenses/by/2.0/');
    expect(photoLicenseUrl('CC BY-SA 2.0 de'), 'https://creativecommons.org/licenses/by-sa/2.0/de/');
    expect(photoLicenseUrl('CC0'), 'https://creativecommons.org/publicdomain/zero/1.0/');
    expect(photoLicenseUrl('Public domain'), isNull);
    expect(html, contains('thu nhỏ/cắt'));
    expect(html, contains('resized/cropped'));
  });

  test('chính sách: khớp khai báo cửa hàng (thu "nội dung khác do người dùng tạo" khi bật đồng bộ, IP do Google xử lý)', () {
    final vi = File('assets/legal/privacy_vi.md').readAsStringSync();
    final en = File('assets/legal/privacy_en.md').readAsStringSync();
    expect(vi, contains('nội dung khác do người dùng tạo'));
    expect(en, contains('other user-generated content'));
    expect(vi, contains('địa chỉ IP'));
    expect(en, contains('IP address'));
    expect(vi, contains('6–8 tuổi'));
    expect(en, contains('aged 6–8'));
  });

  test('firebase.json: hosting + luật Firestore', () {
    final j = jsonDecode(File('firebase.json').readAsStringSync()) as Map;
    expect(j['hosting']['public'], 'hosting/public');
    expect(j['firestore']['rules'], 'firestore.rules');
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("match /syncs/{sid}"));
    expect(rules, contains("allow list: if false;"));
    expect(rules, contains("'^[0-9a-f]{64}\$'"));
  });
}
