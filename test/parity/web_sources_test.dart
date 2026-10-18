// Đối chiếu với bản web gốc (mã nguồn reference/web/ đã gỡ khỏi repo; dữ liệu cần so đã trích sẵn vào
// fixtures/web_sources.json lúc còn mã web): danh sách game Khu vui chơi, câu đọc (voice.json) mà JS dùng, chữ giao diện
// (i18n.js), tên hiệu ứng, hình mà JS nhắc tới, route của app.js. Mỗi mục lệch là một tính năng web có mà app thiếu
// (hoặc ngược lại) — xem docs/QA_FEATURES.md.
import 'dart:convert';
import 'dart:io';

import 'package:be_vui_hoc/app_router.dart';
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/registry.dart';
import 'package:be_vui_hoc/core/i18n/strings.dart';
import 'package:be_vui_hoc/core/ui/emoji_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, dynamic> _web = jsonDecode(File('test/parity/fixtures/web_sources.json').readAsStringSync()) as Map<String, dynamic>;
Set<String> _set(Object? l) => {for (final x in l as List) x as String};
final _dartFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
final _allDart = _dartFiles.map((f) => f.readAsStringSync()).join('\n');

bool _quoted(String key, String src) => RegExp('[\'"`]${RegExp.escape(key)}[\'"`]').hasMatch(src);

/// Khoá i18n của web cố ý bỏ trong app: hướng dẫn "Cài lên màn hình chính" chỉ dành cho bản web (PWA/Safari).
const kDroppedWebKeys = {'install', 'installBanner', 'installSteps', 'installWhy'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async => bundle = await loadContentBundle(rootBundle));

  test('Khu vui chơi: FUN_GAMES của web (fun.js) = kFunGames, cùng thứ tự, cùng thông tin, đều có module', () {
    final web = [for (final g in _web['funGames'] as List) g as Map<String, dynamic>];
    expect(web.length, 48);
    expect([for (final g in kFunGames) g.id], [for (final g in web) g['id']]);
    for (final (i, w) in web.indexed) {
      final d = kFunGames[i];
      expect([d.kind, d.img, d.vi, d.en, d.hot], [w['kind'], w['img'], w['vi'], w['en'], w['hot']], reason: d.id);
      expect('#${d.color.toRadixString(16).padLeft(8, '0').substring(2)}', w['color'], reason: d.id);
      // run: leveled(x) ↔ leveled; các game tự lo nhiều cấp (sling, coding, flow, pipes, schulte) thì không.
      expect(d.leveled, w['leveled'], reason: d.id);
      final m = funGameModuleFor(d.id);
      expect(m, isNotNull, reason: d.id);
      expect(m!.id, d.id);
    }
  });

  test('Câu đọc: mọi câu/mẫu câu JS web gọi tên đều có trong voice.json, có file giọng và được app dùng', () {
    final v = bundle.voice;
    // Đã bỏ 'praise' (tên hàm khen của game, không phải khoá voice.json) và codeRep (+ số ghép lúc chạy) lúc trích.
    final calls = _set(_web['voice']['phraseCalls']);
    final tpls = _set(_web['voice']['templateCalls']);
    expect(calls.where((k) => !v.phrases.containsKey(k)), isEmpty, reason: 'web gọi câu không có trong voice.json');
    expect(tpls.where((k) => !v.templates.containsKey(k)), isEmpty);
    // Mọi khoá voice.json mà web nhắc tới (kể cả trong mảng, vd. praise1..6) thì app cũng nhắc tới;
    // khoá ghép động (ms_, rpgZ, codeRep, retry/praise + số) kiểm riêng.
    const dynamicPrefix = ['ms_', 'rpgZ', 'codeRep', 'retry', 'praise'];
    final webUsed = _set(_web['voice']['quotedVoiceKeys']);
    expect(webUsed.where((k) => !v.phrases.containsKey(k) && !v.templates.containsKey(k)), isEmpty, reason: 'khoá web dùng đã mất khỏi voice.json');
    expect(webUsed.where((k) => !_quoted(k, _allDart) && !dynamicPrefix.any(k.startsWith)), isEmpty, reason: 'web dùng mà app không dùng');
    expect(_allDart, contains("'ms_\$id'"));
    expect(_allDart, contains("'rpgZ\$r'"));
    expect(_allDart, contains("'codeRep\${b.rep}'"));
    // Có file giọng đọc tiếng Việt cho mọi câu cố định web dùng.
    final missing = <String>[];
    for (final k in calls) {
      final a = v.assetOf(v.phrase(k, 'vi'));
      if (a == null || !File(a).existsSync()) missing.add(k);
    }
    expect(missing, isEmpty);
  });

  test('Hiệu ứng: mọi sfx web gọi có trong kSfxNames; mọi tiếng thật web dùng có file', () {
    final sfx = _set(_web['sfx']['calls']);
    // case 'x' trong sfx() của audio.js = danh sách đầy đủ
    final cases = _set(_web['sfx']['names']);
    expect(kSfxNames.toSet(), cases);
    expect(sfx.difference(kSfxNames.toSet()), isEmpty);
    final clips = _set(_web['sfx']['petClips']);
    expect(clips, isNotEmpty);
    expect(clips.where((c) => !File('assets/sfx/$c.mp3').existsSync()), isEmpty);
  });

  test('Chữ giao diện: mọi khoá i18n.js (vi + en) có trong kStrings với cùng nội dung', () {
    // Khác có chủ đích: ghi chú sao lưu nói "ứng dụng" thay vì "trình duyệt".
    const changed = {'backupNote'};
    for (final lg in ['vi', 'en']) {
      final web = (_web['i18n'][lg]['strings'] as Map).cast<String, String>();
      // Mảng (installSteps) chỉ có tên khoá
      final keys = {...web.keys, ..._set(_web['i18n'][lg]['arrayKeys'])};
      expect(keys.length, greaterThan(140));
      final dart = kStrings[lg]!;
      expect(keys.where((k) => !dart.containsKey(k) && !kDroppedWebKeys.contains(k)), isEmpty, reason: lg);
      expect(dart.keys.where(kDroppedWebKeys.contains), isEmpty, reason: 'chữ chỉ dành cho bản web');
      for (final e in web.entries) {
        if (changed.contains(e.key) || kDroppedWebKeys.contains(e.key) || dart[e.key] is! String) continue;
        expect(dart[e.key], e.value, reason: '$lg.${e.key}');
      }
    }
  });

  test('Hình: mọi tên hình trong content.json, app.json, img(\'…\') của web và EmojiImage(\'…\') của app đều có file', () {
    final c = jsonDecode(File('assets/data/content.json').readAsStringSync());
    final names = <String>{};
    // Các khoá chứa tên hình trong content.json (img, imgs, cover; 5 vị trí của bài "vị trí"; nhóm của sortSets).
    const imgKeys = {'img', 'imgs', 'cover', 'center', 'top', 'bottom', 'left', 'right', 'answer'};
    void walk(Object? o, String? key) {
      if (o is Map) {
        o.forEach((k, v) => walk(v, k as String));
      } else if (o is List) {
        for (final x in o) {
          walk(x, key);
        }
      } else if (o is String && imgKeys.contains(key)) {
        names.add(o);
      }
    }

    walk(c, null);
    // Nhóm hình của trò phân loại (categories: {animals: ['Cat', ...]}).
    for (final l in (c['categories'] as Map).values) {
      names.addAll((l as List).whereType<String>());
    }
    expect(names.length, greaterThan(500));
    final webImg = _set(_web['images']);
    final dartImg = {for (final m in RegExp(r"""EmojiImage\('([^'$]+)'""").allMatches(_allDart)) m[1]!};
    final missing = [...names, ...webImg, ...dartImg].where((n) => !File(imgAsset(n)).existsSync() && bundle.photos[n] == null).toSet();
    expect(missing, isEmpty);
  });

  test('Route: mọi màn trong route() của app.js có trong router; màn được nhớ để mở lại giống RESUME', () {
    final names = [for (final n in _web['routes'] as List) n as String];
    expect(names.length, 17);
    final routerSrc = File('lib/app_router.dart').readAsStringSync();
    for (final n in names) {
      expect(routerSrc, contains("path: '/$n"), reason: n);
    }
    expect(kResumeRoutes, [for (final n in _web['resume'] as List) n as String]);
  });
}
