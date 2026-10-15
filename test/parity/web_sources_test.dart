// Đối chiếu tự động với mã nguồn web gốc (reference/web/): danh sách game Khu vui chơi, câu đọc (voice.json) mà JS
// dùng, chữ giao diện (i18n.js), tên hiệu ứng, hình được dữ liệu/JS/Dart nhắc tới, route của app.js.
// Mỗi mục lệch là một tính năng web có mà app thiếu (hoặc ngược lại) — xem docs/QA_FEATURES.md.
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

final _webFiles = Directory('reference/web/js').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.js')).toList();
final _webJs = {for (final f in _webFiles) f.path: f.readAsStringSync()};
final _allJs = _webJs.values.join('\n');
final _dartFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
final _allDart = _dartFiles.map((f) => f.readAsStringSync()).join('\n');

bool _quoted(String key, String src) => RegExp('[\'"`]${RegExp.escape(key)}[\'"`]').hasMatch(src);

/// Đọc một object literal JS đơn giản (khoá không ngoặc, chuỗi '...'), đủ cho FUN_GAMES / bảng T của i18n.js.
Map<String, String> _jsFields(String obj) => {
      for (final m in RegExp(r"(\w+):\s*('(?:[^'\\]|\\.)*'|true|false|[\d.]+)").allMatches(obj))
        m[1]!: m[2]!.startsWith("'") ? m[2]!.substring(1, m[2]!.length - 1).replaceAll(r"\'", "'") : m[2]!,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;
  setUpAll(() async => bundle = await loadContentBundle(rootBundle));

  test('Khu vui chơi: FUN_GAMES của web (fun.js) = kFunGames, cùng thứ tự, cùng thông tin, đều có module', () {
    final src = _webJs.entries.firstWhere((e) => e.key.endsWith('games/fun.js')).value;
    final block = src.substring(src.indexOf('export const FUN_GAMES = ['), src.indexOf('];', src.indexOf('export const FUN_GAMES = [')));
    final web = [for (final m in RegExp(r'\{id: [^\n]*\}').allMatches(block)) _jsFields(m[0]!)];
    expect(web.length, 48);
    expect([for (final g in kFunGames) g.id], [for (final g in web) g['id']]);
    for (final (i, w) in web.indexed) {
      final d = kFunGames[i];
      expect([d.kind, d.img, d.vi, d.en, d.hot], [w['kind'], w['img'], w['vi'], w['en'], w['hot'] == 'true'], reason: d.id);
      expect('#${d.color.toRadixString(16).padLeft(8, '0').substring(2)}', w['color'], reason: d.id);
      // run: leveled(x) ↔ leveled; các game tự lo nhiều cấp (sling, coding, flow, pipes, schulte) thì không.
      final runSrc = RegExp('id: \'${d.id}\'[^\\n]*?run: (.*?), levels').firstMatch(block)![1]!;
      expect(d.leveled, runSrc.startsWith('leveled('), reason: d.id);
      final m = funGameModuleFor(d.id);
      expect(m, isNotNull, reason: d.id);
      expect(m!.id, d.id);
    }
  });

  test('Câu đọc: mọi câu/mẫu câu JS web gọi tên đều có trong voice.json, có file mp3 và được app dùng', () {
    final v = bundle.voice;
    final calls = <String>{};
    for (final m in RegExp(r"""(?:sayPhrase|phrase)\(['"](\w+)['"]""").allMatches(_allJs)) {
      calls.add(m[1]!);
    }
    final tpls = <String>{for (final m in RegExp(r"""tpl\(['"](\w+)['"]""").allMatches(_allJs)) m[1]!};
    // 'praise' trong logic/read/life là tên hàm khen của game (không phải khoá voice.json); codeRep + số ghép lúc chạy.
    calls.removeAll(['praise', 'codeRep']);
    expect(calls.where((k) => !v.phrases.containsKey(k)), isEmpty, reason: 'web gọi câu không có trong voice.json');
    expect(tpls.where((k) => !v.templates.containsKey(k)), isEmpty);
    // Mọi khoá voice.json mà web nhắc tới (kể cả trong mảng, vd. praise1..6) thì app cũng nhắc tới;
    // khoá ghép động (ms_, rpgZ, codeRep, retry/praise + số) kiểm riêng.
    const dynamicPrefix = ['ms_', 'rpgZ', 'codeRep', 'retry', 'praise'];
    final webUsed = [...v.phrases.keys, ...v.templates.keys].where((k) => _quoted(k, _allJs)).toList();
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
    final sfx = {for (final m in RegExp(r"""sfx\(['"](\w+)['"]\)""").allMatches(_allJs)) m[1]!};
    // case 'x' trong sfx() của audio.js = danh sách đầy đủ
    final audio = _webJs.entries.firstWhere((e) => e.key.endsWith('/audio.js')).value;
    final body = audio.substring(audio.indexOf('export function sfx('), audio.indexOf('// ---- Tiếng thật'));
    final cases = [for (final m in RegExp(r"case '(\w+)'").allMatches(body)) m[1]!];
    expect(kSfxNames.toSet(), cases.toSet());
    expect(sfx.difference(kSfxNames.toSet()), isEmpty);
    final pet = _webJs.entries.firstWhere((e) => e.key.endsWith('games/pet.js')).value;
    final clips = {for (final m in RegExp(r"'((?:dog|cat|bunny|bird|hamster|duck|chick|pig|cow|horse|frog)[\w-]*\d)'").allMatches(pet)) m[1]!};
    expect(clips, isNotEmpty);
    expect(clips.where((c) => !File('assets/sfx/$c.mp3').existsSync()), isEmpty);
  });

  test('Chữ giao diện: mọi khoá i18n.js (vi + en) có trong kStrings với cùng nội dung', () {
    final src = File('reference/web/js/i18n.js').readAsStringSync();
    final en = src.indexOf('\n  en: {');
    final parts = {'vi': src.substring(src.indexOf('\n  vi: {'), en), 'en': src.substring(en, src.indexOf('\n};', en))};
    // Khác có chủ đích: ghi chú sao lưu nói "ứng dụng" thay vì "trình duyệt".
    const changed = {'backupNote'};
    for (final lg in ['vi', 'en']) {
      final web = _jsFields(parts[lg]!);
      // Mảng (installSteps) không đọc bằng _jsFields
      final keys = {...web.keys, for (final m in RegExp(r'(\w+): \[').allMatches(parts[lg]!)) m[1]!};
      expect(keys.length, greaterThan(140));
      final dart = kStrings[lg]!;
      expect(keys.where((k) => !dart.containsKey(k)), isEmpty, reason: lg);
      for (final e in web.entries) {
        if (changed.contains(e.key) || dart[e.key] is! String) continue;
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
    final webImg = {for (final m in RegExp(r"""\bimg\('([A-Z][^']*)'""").allMatches(_allJs)) m[1]!};
    final dartImg = {for (final m in RegExp(r"""EmojiImage\('([^'$]+)'""").allMatches(_allDart)) m[1]!};
    final missing = [...names, ...webImg, ...dartImg].where((n) => !File(imgAsset(n)).existsSync() && bundle.photos[n] == null).toSet();
    expect(missing, isEmpty);
  });

  test('Route: mọi màn trong route() của app.js có trong router; màn được nhớ để mở lại giống RESUME', () {
    final app = File('reference/web/js/app.js').readAsStringSync();
    final sw = app.substring(app.indexOf('switch (name) {', app.indexOf('function route(')));
    final names = [for (final m in RegExp(r"case '(\w+)':").allMatches(sw.substring(0, sw.indexOf('default:')))) m[1]!];
    expect(names.length, 17);
    final routerSrc = File('lib/app_router.dart').readAsStringSync();
    for (final n in names) {
      expect(routerSrc, contains("path: '/$n"), reason: n);
    }
    final resume = RegExp(r"const RESUME = \[([^\]]*)\]").firstMatch(app)![1]!.replaceAll("'", '').split(', ');
    expect(kResumeRoutes, resume);
  });
}
