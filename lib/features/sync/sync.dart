// Đồng bộ nhiều máy bằng "mã gia đình" (PBKDF2 + AES-GCM, API datpilot.com/api/bvh/sync), tương thích bản web.
// CHỦ: agent I. Port của reference/web/js/sync.js. Giữ nguyên API của SyncService (màn tạo hồ sơ gọi join()).
// Dữ liệu: store.snapshot() / store.mergeRemote(remote) / store.onSave; trạng thái lưu ở store.getKv('bvh.sync')
// cùng định dạng JSON với localStorage của web: {code, v, at, err, dirty}.
//
// Không email, không mật khẩu, không tên thật: từ mã suy ra sid (tên ngăn trên máy chủ) và khoá AES-GCM.
// Dữ liệu mã hoá trên máy rồi mới gửi, máy chủ chỉ giữ một khối byte không đọc được. Chỉ chạy khi bố mẹ bật.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:be_vui_hoc/core/store/store.dart';

import 'sync_crypto.dart';

export 'sync_crypto.dart' show normalizeCode, prettyCode, newFamilyCode;

/// Kết quả: 'ok' | 'notfound' | 'bad' (mã sai định dạng) | 'offline' (lỗi mạng/máy chủ) | 'off' (chưa bật).
/// (Web trả 'error' cho lỗi mạng/máy chủ; bản app gọi là 'offline' theo hợp đồng của Foundation.)
typedef SyncResult = String;

const String kSyncApi = 'https://datpilot.com/api/bvh/sync/';
const String kSyncKv = 'bvh.sync';

/// Lỗi HTTP / xung đột (Error('http 500'), Error('conflict') của web).
class SyncHttpError implements Exception {
  SyncHttpError(this.message);
  final String message;
  @override
  String toString() => message;
}

class SyncService with WidgetsBindingObserver {
  SyncService(
    this.store, {
    http.Client? client,
    this.api = kSyncApi,
    this.debounce = const Duration(seconds: 20),
    this.timeout = const Duration(seconds: 20),
    Future<SyncKeys> Function(String code)? derive,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _derive = derive ?? deriveSyncKeys,
        _clock = clock ?? DateTime.now {
    _st = _load();
  }

  final AppStore store;
  final String api;
  final Duration debounce;
  final Duration timeout;
  final http.Client _client;
  final Future<SyncKeys> Function(String code) _derive;
  final DateTime Function() _clock;

  late Map<String, dynamic> _st;
  SyncKeys? _keys;
  Future<SyncResult>? _busy;
  Timer? _timer;
  void Function()? _onMerged;
  bool _inited = false;

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

  /// Máy hỗ trợ đồng bộ (app: luôn có crypto + mạng).
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

  Uri _url() => Uri.parse('$api${_keys!.sid}');

  Map<String, dynamic> _json(http.Response r) {
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map) throw SyncHttpError('bad json');
    return j.cast<String, dynamic>();
  }

  bool _merge(Object? remote) {
    final changed = store.mergeRemote(remote);
    if (changed) _onMerged?.call();
    return changed;
  }

  // Một lượt: kéo bản trên máy chủ (gộp nếu khác), rồi đẩy bản đã gộp. mode 'create' | 'join' | null.
  Future<SyncResult> _round(String? mode) async {
    _keys ??= await _derive(code!);
    var base = 0;
    if (mode != 'create') {
      final r = await _client.get(_url(), headers: const {'cache-control': 'no-store'}).timeout(timeout);
      if (r.statusCode == 404) {
        if (mode == 'join') return 'notfound';
        base = 0; // ngăn bị xoá trên máy chủ (hoặc quá hạn): tạo lại từ máy này
      } else if (r.statusCode < 200 || r.statusCode > 299) {
        throw SyncHttpError('http ${r.statusCode}');
      } else {
        final j = _json(r);
        final v = (j['v'] as num?)?.toInt() ?? 0;
        if (v != _st['v']) _merge(await openJson(_keys!, j['blob'] as String));
        base = v;
        if (base == _st['v'] && !dirty && mode != 'join') return 'ok';
      }
    }
    for (var k = 0; k < 3; k++) {
      _st['dirty'] = false;
      final blob = await sealJson(_keys!, store.snapshot());
      final w = await _client.put(_url(), headers: const {'content-type': 'application/json'}, body: jsonEncode({'base': base, 'blob': blob})).timeout(timeout);
      if (w.statusCode >= 200 && w.statusCode <= 299) {
        _st['v'] = _json(w)['v'];
        return 'ok';
      }
      if (w.statusCode == 409) {
        final j = _json(w);
        _merge(await openJson(_keys!, j['blob'] as String));
        base = (j['v'] as num?)?.toInt() ?? 0;
        continue;
      }
      throw SyncHttpError('http ${w.statusCode}');
    }
    throw SyncHttpError('conflict');
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
        // Web: 'offline' khi mất mạng, còn lại là thông điệp lỗi (Góc bố mẹ hiện "máy chủ").
        _st['err'] = e is http.ClientException || e is TimeoutException ? 'offline' : e.toString();
        // Đẩy lỗi giữa chừng: giữ lại cờ dirty để lần sau đẩy lại (web làm mất cờ trong trường hợp này).
        if (wasDirty) _st['dirty'] = true;
        _keep();
        return 'offline';
      } finally {
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
        await _client.delete(_url()).timeout(timeout);
      } catch (_) {/* bỏ qua */}
    }
    _reset();
  }

  /// Gắn vào store.onSave, kéo bản mới lúc mở app. onMerged: có dữ liệu mới từ máy khác.
  /// Tự đồng bộ: lúc mở app, [debounce] (20 giây) sau mỗi lần lưu, khi app chuyển nền (còn thay đổi chưa đẩy),
  /// và khi app mở lại từ nền (thay sự kiện 'online' của web).
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
