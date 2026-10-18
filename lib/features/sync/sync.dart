// Đồng bộ nhiều máy bằng "mã gia đình" (PBKDF2 + AES-GCM, mã hoá đầu-cuối), bản mã lưu trên Cloud Firestore.
// CHỦ: agent I. Giữ nguyên API của SyncService (màn tạo hồ sơ gọi join()).
// Nơi lưu: SyncBackend (sync_backend.dart) — FirestoreSyncBackend trên máy thật, MemorySyncBackend trong test.
// Dữ liệu: store.snapshot() / store.mergeRemote(remote) / store.onSave; trạng thái lưu ở store.getKv('bvh.sync')
// dạng JSON {code, v, at, err, dirty}.
//
// Không email, không mật khẩu, không tên thật: từ mã suy ra sid (tên ngăn trên máy chủ) và khoá AES-GCM.
// Dữ liệu mã hoá trên máy rồi mới gửi, máy chủ chỉ giữ một khối byte không đọc được. Chỉ chạy khi bố mẹ bật.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_vui_hoc/core/store/store.dart';

import 'firestore_sync_backend.dart';
import 'sync_backend.dart';
import 'sync_crypto.dart';

export 'sync_backend.dart';
export 'sync_crypto.dart' show normalizeCode, prettyCode, newFamilyCode;

/// Kết quả: 'ok' | 'notfound' | 'bad' (mã sai định dạng) | 'offline' (lỗi mạng/máy chủ) | 'off' (chưa bật).
typedef SyncResult = String;

const String kSyncKv = 'bvh.sync';

class SyncService with WidgetsBindingObserver {
  SyncService(
    this.store, {
    SyncBackend? backend,
    this.debounce = const Duration(seconds: 20),
    this.timeout = const Duration(seconds: 20),
    Future<SyncKeys> Function(String code)? derive,
    DateTime Function()? clock,
  })  : backend = backend ?? FirestoreSyncBackend(timeout: timeout),
        _derive = derive ?? deriveSyncKeys,
        _clock = clock ?? DateTime.now {
    _st = _load();
  }

  final AppStore store;
  /// Nơi giữ bản mã hoá (Firestore / bộ nhớ).
  final SyncBackend backend;
  final Duration debounce;
  final Duration timeout;
  final Future<SyncKeys> Function(String code) _derive;
  final DateTime Function() _clock;

  late Map<String, dynamic> _st;
  SyncKeys? _keys;
  Future<SyncResult>? _busy;
  Timer? _timer;
  void Function()? _onMerged;
  bool _inited = false;

  /// Lượt đang chạy đã xoá cờ dirty để đẩy (lỗi giữa chừng thì bật lại).
  bool _unsent = false;

  /// Đổi trạng thái (bật/tắt, lần đồng bộ gần nhất) — Góc bố mẹ nghe để vẽ lại.
  final ValueNotifier<int> changes = ValueNotifier(0);

  Map<String, dynamic> _load() {
    try {
      final s = store.getKv(kSyncKv);
      final j = s == null ? null : jsonDecode(s);
      if (j is Map) return j.cast<String, dynamic>();
    } catch (_) {/* bỏ qua */}
    return {};
  }

  void _keep() {
    try {
      store.setKv(kSyncKv, jsonEncode(_st));
    } catch (_) {/* bỏ qua */}
    changes.value++;
  }

  /// Máy hỗ trợ đồng bộ (app: luôn có crypto; Firebase chưa sẵn sàng thì lượt đồng bộ báo 'offline').
  bool get supported => true;

  /// Mã gia đình đang dùng (null = chưa bật).
  String? get code => _st['code'] as String?;
  int get lastAt => (_st['at'] as num?)?.toInt() ?? 0;
  String? get lastErr => _st['err'] as String?;

  /// Máy này có thay đổi chưa đẩy lên (giữ qua lần mở app sau).
  bool get dirty => _st['dirty'] == true;

  /// Phiên bản bản trên máy chủ mà máy này đã gộp.
  int get version => (_st['v'] as num?)?.toInt() ?? 0;

  /// Đang chạy một lượt đồng bộ.
  bool get busy => _busy != null;

  bool _merge(Object? remote) {
    final changed = store.mergeRemote(remote);
    if (changed) _onMerged?.call();
    return changed;
  }

  // Một lượt: kéo bản trên máy chủ (gộp nếu khác), rồi đẩy bản đã gộp. mode 'create' | 'join' | null.
  Future<SyncResult> _round(String? mode) async {
    _keys ??= await _derive(code!);
    final sid = _keys!.sid;
    var base = 0;
    if (mode != 'create') {
      final d = await backend.get(sid).timeout(timeout);
      if (d == null) {
        if (mode == 'join') return 'notfound';
        base = 0; // ngăn bị xoá trên máy chủ: tạo lại từ máy này
      } else {
        if (d.v != _st['v']) _merge(await openJson(_keys!, d.blob));
        base = d.v;
        if (base == _st['v'] && !dirty && mode != 'join') return 'ok';
      }
    }
    // Đẩy với kiểm tra phiên bản (giao dịch Firestore): xung đột → gộp bản mới nhất rồi thử lại, tối đa 3 lần.
    for (var k = 0; k < 3; k++) {
      if (dirty) _unsent = true;
      _st['dirty'] = false;
      final blob = await sealJson(_keys!, store.snapshot());
      final w = await backend.put(sid, base: base, blob: blob).timeout(timeout);
      if (!w.conflict) {
        _st['v'] = w.v;
        return 'ok';
      }
      if (w.blob != null) _merge(await openJson(_keys!, w.blob!));
      base = w.v;
    }
    throw SyncServerError('conflict');
  }

  Future<SyncResult> _syncNow([String? mode]) {
    if (code == null) return Future.value('off');
    final cur = _busy;
    if (cur != null) return cur;
    final wasDirty = dirty;
    final f = () async {
      try {
        final res = await _round(mode);
        if (res == 'ok') {
          _st['at'] = _clock().millisecondsSinceEpoch;
          _st['err'] = null;
        }
        _keep();
        return res;
      } catch (e) {
        // 'offline' khi mất mạng / quá giờ, còn lại là thông điệp lỗi (Góc bố mẹ hiện "máy chủ").
        _st['err'] = e is SyncOfflineException || e is TimeoutException ? 'offline' : e.toString();
        // Đẩy lỗi giữa chừng: giữ lại cờ dirty để lần sau đẩy lại.
        // (Kể cả thay đổi xảy ra trong lúc lượt này đang chạy: cờ đã bị xoá trước khi đẩy.)
        if (wasDirty || _unsent) _st['dirty'] = true;
        _keep();
        return 'offline';
      } finally {
        _unsent = false;
        _busy = null;
      }
    }();
    _busy = f;
    return f;
  }

  /// Đồng bộ ngay (nút "Đồng bộ ngay", lúc mở app, khi chuyển nền).
  Future<SyncResult> syncNow() => _syncNow();

  /// Bật trên máy đầu tiên: tạo mã mới, đẩy dữ liệu lên.
  Future<SyncResult> create() async {
    _st = {'code': newFamilyCode(), 'v': 0};
    _keys = null;
    _keep();
    final r = await _syncNow('create');
    if (r != 'ok') _reset();
    return r;
  }

  /// Máy thứ hai: nhập mã, kéo dữ liệu về gộp với máy này.
  Future<SyncResult> join(String c) async {
    if (normalizeCode(c).length != 16) return 'bad';
    _st = {'code': prettyCode(c), 'v': 0};
    _keys = null;
    _keep();
    final r = await _syncNow('join');
    if (r != 'ok') _reset();
    return r;
  }

  void _reset() {
    _st = {};
    _keys = null;
    _timer?.cancel();
    _keep();
  }

  /// Ngắt máy này (dữ liệu trên máy vẫn giữ). wipeServer: xoá luôn bản trên máy chủ.
  Future<void> leave({bool wipeServer = false}) async {
    if (wipeServer && code != null) {
      try {
        _keys ??= await _derive(code!);
        await backend.delete(_keys!.sid).timeout(timeout);
      } catch (_) {/* bỏ qua */}
    }
    _reset();
  }

  /// Gắn vào store.onSave, kéo bản mới lúc mở app. onMerged: có dữ liệu mới từ máy khác.
  /// Tự đồng bộ: lúc mở app, [debounce] (20 giây) sau mỗi lần lưu, khi app chuyển nền (còn thay đổi chưa đẩy),
  /// và khi app mở lại từ nền.
  void init({void Function()? onMerged}) {
    _onMerged = onMerged;
    store.onSave = _onSave;
    if (!_inited) {
      _inited = true;
      WidgetsBinding.instance.addObserver(this);
    }
    if (code != null) syncNow();
  }

  void _onSave() {
    if (code == null) return;
    if (!dirty) {
      _st['dirty'] = true;
      _keep();
    }
    _timer?.cancel();
    _timer = Timer(debounce, syncNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (code == null) return;
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && dirty) {
      _timer?.cancel();
      syncNow();
    } else if (state == AppLifecycleState.resumed) {
      syncNow();
    }
  }

  void dispose() {
    _timer?.cancel();
    if (_inited) WidgetsBinding.instance.removeObserver(this);
    if (store.onSave == _onSave) store.onSave = null;
    changes.dispose();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final s = SyncService(ref.read(storeProvider));
  ref.onDispose(s.dispose);
  return s;
});
