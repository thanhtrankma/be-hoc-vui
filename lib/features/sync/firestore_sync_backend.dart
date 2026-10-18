// SyncBackend trên Cloud Firestore (project bevuihoc-app, vùng asia-southeast1 / Singapore).
// Tài liệu: syncs/{sid}, sid = hex SHA-256 suy từ mã gia đình (sync_crypto.dart); trường {v: int, blob: string, at: serverTimestamp}.
// blob đã mã hoá AES-GCM trên máy bằng khoá suy từ mã gia đình: máy chủ (và nhà phát triển) không đọc được.
// Luật bảo vệ: firestore.rules ở gốc repo (chỉ get/create/update/delete đúng một ngăn theo sid, không list, v tăng đúng 1).
// Bộ nhớ đệm ngoại tuyến của Firestore TẮT (persistenceEnabled: false) để kết quả luôn là của máy chủ:
// mất mạng thì báo 'offline' như API cũ thay vì ghi tạm vào máy rồi đẩy sau.
// CHỦ: agent I.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_setup.dart';
import 'sync_backend.dart';

const String kSyncCollection = 'syncs';

class FirestoreSyncBackend implements SyncBackend {
  FirestoreSyncBackend({FirebaseFirestore? db, this.timeout = const Duration(seconds: 20)}) : _injected = db;

  final FirebaseFirestore? _injected;
  final Duration timeout;
  static bool _configured = false;

  FirebaseFirestore get _db {
    if (_injected != null) return _injected;
    // Firebase chưa khởi động (chạy test, cấu hình lỗi): coi như mất mạng, app vẫn chạy.
    if (!FirebaseState.ready) throw const SyncOfflineException('offline');
    final db = FirebaseFirestore.instance;
    if (!_configured) {
      _configured = true;
      try {
        db.settings = const Settings(persistenceEnabled: false);
      } catch (_) {/* đã dùng trước đó: giữ cài đặt cũ */}
    }
    return db;
  }

  DocumentReference<Map<String, dynamic>> _doc(String sid) => _db.collection(kSyncCollection).doc(sid);

  Future<T> _guard<T>(Future<T> Function() job) async {
    try {
      return await job();
    } on FirebaseException catch (e) {
      if (const {'unavailable', 'deadline-exceeded'}.contains(e.code)) throw SyncOfflineException(e.code);
      throw SyncServerError('firestore ${e.code}');
    }
  }

  static SyncDoc? _parse(DocumentSnapshot<Map<String, dynamic>> s) {
    if (!s.exists) return null;
    final d = s.data()!;
    final v = d['v'], blob = d['blob'];
    if (v is! num || blob is! String) throw SyncServerError('bad doc');
    return SyncDoc(v.toInt(), blob);
  }

  @override
  Future<SyncDoc?> get(String sid) => _guard(() async => _parse(await _doc(sid).get(const GetOptions(source: Source.server))));

  @override
  Future<SyncPut> put(String sid, {required int base, required String blob}) => _guard(() {
        final ref = _doc(sid);
        // Đọc v trong giao dịch; khác base → trả bản hiện có để gộp (không ghi). Bằng → ghi v + 1.
        return _db.runTransaction<SyncPut>((tx) async {
          final cur = _parse(await tx.get(ref));
          final v = cur?.v ?? 0;
          if (v != base) return SyncPut.conflict(v, cur?.blob);
          tx.set(ref, {'v': base + 1, 'blob': blob, 'at': FieldValue.serverTimestamp()});
          return SyncPut.ok(base + 1);
        }, timeout: timeout);
      });

  @override
  Future<void> delete(String sid) => _guard(() => _doc(sid).delete());
}
