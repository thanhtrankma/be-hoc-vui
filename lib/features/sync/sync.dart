// Đồng bộ nhiều máy bằng "mã gia đình" (PBKDF2 + AES-GCM, API datpilot.com/api/bvh/sync), tương thích bản web.
// CHỦ: agent I. Port của reference/web/js/sync.js. Giữ nguyên API của SyncService (màn tạo hồ sơ gọi join()).
// Dữ liệu: store.snapshot() / store.mergeRemote(remote) / store.onSave; trạng thái lưu ở store.getKv('bvh.sync').
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/store/store.dart';

/// Kết quả: 'ok' | 'notfound' | 'bad' (mã sai định dạng) | 'offline' (lỗi mạng/máy chủ).
typedef SyncResult = String;

class SyncService {
  SyncService(this.store);
  final AppStore store;

  /// Máy hỗ trợ đồng bộ (bản app: luôn true khi agent I làm xong).
  bool get supported => false;

  /// Mã gia đình đang dùng (null = chưa bật).
  String? get code => null;
  int get lastAt => 0;
  String? get lastErr => null;

  /// Gắn vào store.onSave, kéo bản mới lúc mở app. onMerged: có dữ liệu mới từ máy khác.
  void init({void Function()? onMerged}) {}
  Future<SyncResult> create() async => 'offline';
  Future<SyncResult> join(String code) async => 'offline';
  Future<SyncResult> syncNow() async => 'offline';
  Future<void> leave({bool wipeServer = false}) async {}
}

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref.read(storeProvider)));
