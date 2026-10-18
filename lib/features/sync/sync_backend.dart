// Nơi giữ bản đồng bộ đã mã hoá, tách khỏi SyncService để thay được: Cloud Firestore (firestore_sync_backend.dart)
// trên máy thật, MemorySyncBackend (bộ nhớ) trong test.
// Hợp đồng (giữ nguyên ngữ nghĩa của API đồng bộ cũ):
//   get(sid)              → SyncDoc {v, blob} | null (chưa có / đã xoá)
//   put(sid, base, blob)  → SyncPut.ok(v mới = base + 1) nếu v trên máy chủ == base (chưa có = 0),
//                           ngược lại SyncPut.conflict(v hiện tại, blob hiện tại) để gộp rồi thử lại
//   delete(sid)           → xoá ngăn
// Lỗi mạng ném SyncOfflineException; lỗi máy chủ khác ném SyncServerError.
// CHỦ: agent I.
import 'dart:async';

/// Một bản trên máy chủ: phiên bản + khối byte đã mã hoá (base64 iv + ct + tag).
class SyncDoc {
  const SyncDoc(this.v, this.blob);
  final int v;
  final String blob;
}

/// Kết quả put: ok (v mới) hoặc xung đột (bản hiện có trên máy chủ; blob null nếu ngăn vừa bị xoá).
class SyncPut {
  const SyncPut.ok(this.v)
      : conflict = false,
        blob = null;
  const SyncPut.conflict(this.v, this.blob) : conflict = true;
  final bool conflict;
  final int v;
  final String? blob;
}

/// Mất mạng / máy chủ không trả lời (Góc bố mẹ hiện "mất mạng").
class SyncOfflineException implements Exception {
  const SyncOfflineException([this.message = 'offline']);
  final String message;
  @override
  String toString() => message;
}

/// Lỗi máy chủ khác (bị từ chối, dữ liệu hỏng...) — Góc bố mẹ hiện "máy chủ".
class SyncServerError implements Exception {
  SyncServerError(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class SyncBackend {
  Future<SyncDoc?> get(String sid);
  Future<SyncPut> put(String sid, {required int base, required String blob});
  Future<void> delete(String sid);
}

/// Bản trong bộ nhớ (test, chạy thử không có Firebase). Cùng ngữ nghĩa với Firestore + firestore.rules.
class MemorySyncBackend implements SyncBackend {
  final Map<String, SyncDoc> boxes = {};

  /// Nhật ký gọi: 'GET sid', 'PUT sid', 'DELETE sid'.
  final List<String> log = [];

  /// true: mọi lệnh ném SyncOfflineException.
  bool offline = false;

  /// Khác null: mọi lệnh ném SyncServerError(serverError).
  String? serverError;

  /// Gọi sau mỗi get (test chen bản khác vào giữa GET và PUT).
  FutureOr<void> Function(String sid)? afterGet;

  void _check() {
    if (offline) throw const SyncOfflineException();
    if (serverError != null) throw SyncServerError(serverError!);
  }

  @override
  Future<SyncDoc?> get(String sid) async {
    _check();
    log.add('GET $sid');
    final d = boxes[sid];
    await afterGet?.call(sid);
    return d;
  }

  @override
  Future<SyncPut> put(String sid, {required int base, required String blob}) async {
    _check();
    log.add('PUT $sid');
    final cur = boxes[sid];
    final v = cur?.v ?? 0;
    if (v != base) return SyncPut.conflict(v, cur?.blob);
    boxes[sid] = SyncDoc(v + 1, blob);
    return SyncPut.ok(v + 1);
  }

  @override
  Future<void> delete(String sid) async {
    _check();
    log.add('DELETE $sid');
    boxes.remove(sid);
  }
}
