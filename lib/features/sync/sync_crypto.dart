// Mã hoá đồng bộ (đầu-cuối: chỉ máy có mã gia đình mới giải được). Định dạng giữ nguyên như bản đầu tiên:
//   sid  = hex(SHA-256('bvh-sync-id|' + normalize(code)))                 (tên ngăn trên máy chủ)
//   key  = PBKDF2-HMAC-SHA256(normalize(code), salt 'bvh-sync-key-v1', 150000 vòng) → AES-GCM 256
//   blob = base64(iv 12 byte + ciphertext + tag 16 byte), nội dung = JSON.stringify(store.snapshot())
// Tự kiểm: test/features/sync/sync_crypto_test.dart (vector AES-GCM / PBKDF2 cố định đã ghi lại từ WebCrypto).
// CHỦ: agent I.
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Bỏ I, L, O, 0, 1 cho khỏi nhầm khi đọc cho nhau .
const String kSyncAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const String kSyncSalt = 'bvh-sync-key-v1';
const String kSyncIdPrefix = 'bvh-sync-id|';
const int kSyncIterations = 150000;

/// normalize(): in hoa, chỉ giữ A-Z 0-9.
String normalizeCode(String? s) => (s ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// pretty(): nhóm 4 ký tự, nối bằng '-' (ABCD-EFGH-JKMN-PQRS).
String prettyCode(String? c) => normalizeCode(c).replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]}-');

/// newCode(): 16 byte ngẫu nhiên an toàn, mỗi byte % 31 → 1 ký tự (kể cả độ lệch nhẹ của phép %, giữ như bản đầu).
String newFamilyCode([Random? rnd]) {
  final r = rnd ?? Random.secure();
  return prettyCode(List.generate(16, (_) => kSyncAlphabet[r.nextInt(256) % kSyncAlphabet.length]).join());
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// Khoá suy ra từ mã gia đình.
class SyncKeys {
  SyncKeys(this.sid, this.keyBytes);
  final String sid;
  final Uint8List keyBytes;
  SecretKey get secretKey => SecretKeyData(keyBytes);
  String get keyHex => _hex(keyBytes);
}

final AesGcm _aes = AesGcm.with256bits();

/// Suy sid + khoá từ mã. Chạy thẳng trên isolate hiện tại (PBKDF2 150000 vòng tốn chừng 1 giây).
Future<SyncKeys> deriveSyncKeysDirect(String code) async {
  final n = normalizeCode(code);
  final sid = _hex((await Sha256().hash(utf8.encode('$kSyncIdPrefix$n'))).bytes);
  final pb = Pbkdf2.hmacSha256(iterations: kSyncIterations, bits: 256);
  final k = await pb.deriveKey(secretKey: SecretKeyData(utf8.encode(n)), nonce: utf8.encode(kSyncSalt));
  return SyncKeys(sid, Uint8List.fromList(await k.extractBytes()));
}

/// Như trên nhưng chạy trên isolate riêng để không giật giao diện; lỗi isolate thì chạy thẳng.
Future<SyncKeys> deriveSyncKeys(String code) async {
  try {
    final r = await Isolate.run(() async {
      final k = await deriveSyncKeysDirect(code);
      return (k.sid, k.keyBytes);
    });
    return SyncKeys(r.$1, r.$2);
  } catch (_) {
    return deriveSyncKeysDirect(code);
  }
}

/// seal(key, obj): JSON → AES-GCM → base64(iv + ct + tag). iv: chỉ test truyền vào (mặc định ngẫu nhiên 12 byte).
Future<String> sealJson(SyncKeys keys, Object? obj, {List<int>? iv}) async {
  final nonce = iv ?? _aes.newNonce();
  final box = await _aes.encrypt(utf8.encode(jsonEncode(obj)), secretKey: keys.secretKey, nonce: nonce);
  final out = BytesBuilder(copy: false)
    ..add(nonce)
    ..add(box.cipherText)
    ..add(box.mac.bytes);
  return base64Encode(out.toBytes());
}

/// open(key, blob): giải mã, JSON.parse. Sai khoá / hỏng dữ liệu → ném SecretBoxAuthenticationError / FormatException.
Future<Object?> openJson(SyncKeys keys, String blob) async {
  final u8 = base64Decode(blob);
  if (u8.length < 12 + 16) throw const FormatException('blob too short');
  final box = SecretBox(u8.sublist(12, u8.length - 16), nonce: u8.sublist(0, 12), mac: Mac(u8.sublist(u8.length - 16)));
  final plain = await _aes.decrypt(box, secretKey: keys.secretKey);
  return jsonDecode(utf8.decode(plain));
}
