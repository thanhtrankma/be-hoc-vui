// Tự kiểm mã hoá đồng bộ: vector AES-GCM / PBKDF2 / SHA-256 cố định (webcrypto_vectors.json, sinh bằng WebCrypto của Node qua
// tool/webcrypto_vectors.mjs — một bản cài đặt độc lập của cùng thuật toán). Bản web đã gỡ; vector giữ làm chuẩn định dạng.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:be_vui_hoc/features/sync/sync_crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vec = jsonDecode(File('test/features/sync/webcrypto_vectors.json').readAsStringSync()) as Map<String, dynamic>;
  List<int> unhex(String h) => [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
  late SyncKeys keys;

  setUpAll(() async {
    keys = await deriveSyncKeysDirect(vec['code'] as String);
  });

  test('normalize / pretty / newCode đúng định dạng', () {
    expect(normalizeCode(' abcd-efgh jkmn_pq23 '), 'ABCDEFGHJKMNPQ23');
    expect(prettyCode('abcdefghjkmnpq23'), 'ABCD-EFGH-JKMN-PQ23');
    expect(prettyCode('abcde'), 'ABCD-E');
    for (var k = 0; k < 50; k++) {
      final c = newFamilyCode();
      expect(c, matches(RegExp(r'^[A-HJKMNP-Z2-9]{4}(-[A-HJKMNP-Z2-9]{4}){3}$')));
      expect(normalizeCode(c).length, 16);
    }
    // Cùng nguồn byte → cùng mã (x % 31).
    final r = Random(1);
    final bytes = List.generate(16, (_) => r.nextInt(256));
    final r2 = Random(1);
    expect(newFamilyCode(r2), prettyCode(bytes.map((x) => kSyncAlphabet[x % 31]).join()));
  });

  test('sid và khoá PBKDF2 trùng WebCrypto', () async {
    expect(keys.sid, vec['sid']);
    expect(keys.keyHex, vec['key']);
    // Mã viết thường / có khoảng trắng vẫn ra cùng khoá (normalize trước).
    final k2 = await deriveSyncKeysDirect('abcd efgh-jkmn-pq23');
    expect(k2.sid, vec['sid']);
  });

  test('giải mã blob do WebCrypto tạo', () async {
    final obj = await openJson(keys, vec['blob'] as String);
    expect(obj, jsonDecode(vec['plain'] as String));
    expect(((obj as Map)['profiles'] as List).first['name'], 'Bé Na 🐰');
  });

  test('Dart mã hoá cùng IV ra đúng từng byte như vector', () async {
    final blob = await sealJson(keys, jsonDecode(vec['plain'] as String), iv: unhex(vec['iv'] as String));
    expect(blob, vec['blob']);
  });

  test('blob IV ngẫu nhiên: Dart tự mở được, sai khoá thì báo lỗi', () async {
    final data = {'profiles': [], 'settings': {'lang': 'en'}, 'gone': {}, 'smt': 5};
    final a = await sealJson(keys, data), b = await sealJson(keys, data);
    expect(a, isNot(b));
    expect(base64Decode(a).length, 12 + utf8.encode(jsonEncode(data)).length + 16);
    expect(await openJson(keys, a), data);
    final wrong = SyncKeys(keys.sid, Uint8List.fromList(keys.keyBytes.map((x) => x ^ 1).toList()));
    expect(() => openJson(wrong, a), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('Node WebCrypto giải mã được blob do Dart tạo (bỏ qua nếu không có node)', () async {
    final node = await _which('node');
    if (node == null) {
      markTestSkipped('node không có trên máy');
      return;
    }
    final data = {'profiles': [{'id': 'x', 'name': 'Tí ✨', 'stars': 3, 'mt': 1}], 'settings': {}, 'gone': {}, 'smt': 0};
    final blob = await sealJson(keys, data);
    final r = await Process.run(node, ['test/features/sync/tool/webcrypto_vectors.mjs', 'open', vec['code'] as String, blob]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(jsonDecode((r.stdout as String).trim()), data);
  });
}

Future<String?> _which(String bin) async {
  try {
    final r = await Process.run('which', [bin]);
    final p = (r.stdout as String).trim();
    return r.exitCode == 0 && p.isNotEmpty ? p : null;
  } catch (_) {
    return null;
  }
}
