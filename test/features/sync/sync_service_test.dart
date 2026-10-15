// SyncService: luồng create / join / tự đồng bộ / xung đột 409 / mất mạng / leave — máy chủ giả (MockClient), không gọi mạng thật.
import 'dart:convert';

import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/features/sync/sync.dart';
import 'package:be_vui_hoc/features/sync/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Máy chủ giả theo hợp đồng sync.js: GET → {v, blob} | 404; PUT {base, blob} → {v} | 409 {v, blob}; DELETE.
class FakeServer {
  final Map<String, Map<String, dynamic>> boxes = {};
  final List<String> log = [];
  bool offline = false;

  late final MockClient client = MockClient((req) async {
    if (offline) throw http.ClientException('no network');
    final sid = req.url.pathSegments.last;
    log.add('${req.method} $sid');
    expect(req.url.toString(), startsWith('https://datpilot.com/api/bvh/sync/'));
    final cur = boxes[sid];
    switch (req.method) {
      case 'GET':
        return cur == null ? http.Response('{"error":"notfound"}', 404) : http.Response(jsonEncode(cur), 200);
      case 'PUT':
        expect(req.headers['content-type'], startsWith('application/json'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        final v = (cur?['v'] as int?) ?? 0;
        if (body['base'] != v) return http.Response(jsonEncode(cur), 409);
        boxes[sid] = {'v': v + 1, 'blob': body['blob']};
        return http.Response(jsonEncode({'v': v + 1}), 200);
      case 'DELETE':
        boxes.remove(sid);
        return http.Response('{"ok":true}', 200);
    }
    return http.Response('', 405);
  });
}

final Map<String, SyncKeys> _keyCache = {};
Future<SyncKeys> cachedDerive(String code) async => _keyCache[normalizeCode(code)] ??= await deriveSyncKeysDirect(code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> newStore([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return AppStore(await SharedPreferences.getInstance());
  }

  SyncService svc(AppStore s, FakeServer srv, {Duration debounce = const Duration(seconds: 20)}) =>
      SyncService(s, client: srv.client, derive: cachedDerive, debounce: debounce);

  Future<Map<String, dynamic>> serverData(FakeServer srv, String code) async {
    final k = await cachedDerive(code);
    return (await openJson(k, srv.boxes[k.sid]!['blob'] as String)) as Map<String, dynamic>;
  }

  test('create: tạo mã, đẩy bản mã hoá lên, lưu trạng thái bvh.sync như web', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final s = svc(a, srv);
    expect(s.code, isNull);
    expect(await s.create(), 'ok');
    expect(s.code, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$')));
    expect(srv.log, ['PUT ${(await cachedDerive(s.code!)).sid}']); // create: không GET trước
    final kv = jsonDecode(a.getKv('bvh.sync')!) as Map;
    expect(kv['code'], s.code);
    expect(kv['v'], 1);
    expect(kv['dirty'], false);
    expect(kv['at'], isA<int>());
    final remote = await serverData(srv, s.code!);
    expect((remote['profiles'] as List).single['name'], 'Na');
    expect(remote.keys, containsAll(['profiles', 'settings', 'gone', 'smt']));
  });

  test('join trên máy thứ hai: gộp hồ sơ hai chiều; mã sai định dạng / không có', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final sa = svc(a, srv);
    await sa.create();

    final b = await newStore();
    b.addProfile('Bin', 'dog');
    final sb = svc(b, srv);
    expect(await sb.join('abc'), 'bad');
    expect(await sb.join('ZZZZ-ZZZZ-ZZZZ-ZZZZ'), 'notfound');
    expect(sb.code, isNull);
    expect(b.getKv('bvh.sync'), '{}');
    expect(await sb.join(sa.code!.toLowerCase().replaceAll('-', ' ')), 'ok');
    expect(sb.code, sa.code);
    expect(b.profiles.map((p) => p.name), containsAll(['Na', 'Bin']));
    // Máy A kéo về thấy cả Bin.
    var merged = false;
    sa.init(onMerged: () => merged = true);
    expect(await sa.syncNow(), 'ok');
    expect(merged, isTrue);
    expect(a.profiles.map((p) => p.name), containsAll(['Na', 'Bin']));
    sa.dispose();
  });

  test('lưu → cờ dirty → tự đẩy sau debounce; không đổi gì thì chỉ GET', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final s = svc(a, srv, debounce: const Duration(milliseconds: 50));
    await s.create();
    s.init();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    srv.log.clear();
    expect(await s.syncNow(), 'ok');
    expect(srv.log.map((e) => e.split(' ').first), ['GET']);

    srv.log.clear();
    a.addTickets(3);
    expect(s.dirty, isTrue);
    expect(jsonDecode(a.getKv('bvh.sync')!)['dirty'], true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(srv.log.map((e) => e.split(' ').first), ['GET', 'PUT']);
    expect(s.dirty, isFalse);
    expect(a.tickets(a.profile!), 5);
    final remote = await serverData(srv, s.code!);
    expect((remote['profiles'] as List).single['tickets'], 5);
    s.dispose();
  });

  test('máy chủ có bản mới hơn: kéo về gộp rồi đẩy bản gộp', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final sa = svc(a, srv);
    await sa.create();
    final b = await newStore();
    final sb = svc(b, srv);
    expect(await sb.join(sa.code!), 'ok');
    // B thêm bé mới và đẩy lên (v=3) trong khi A vẫn nghĩ v=1.
    sb.init();
    await sb.syncNow();
    b.addProfile('Bin', 'dog');
    expect(sb.dirty, isTrue);
    expect(await sb.syncNow(), 'ok');
    // A thêm bé khác rồi đồng bộ: GET thấy v khác → gộp → PUT.
    a.addProfile('Tí', 'fox');
    sa.init();
    final r = await sa.syncNow();
    expect(r, 'ok');
    final names = ((await serverData(srv, sa.code!))['profiles'] as List).map((p) => p['name']).toSet();
    expect(names, {'Na', 'Bin', 'Tí'});
    expect(a.profiles.map((p) => p.name).toSet(), {'Na', 'Bin', 'Tí'});
    sa.dispose();
  });

  test('PUT bị 409 thật (máy chủ đổi giữa GET và PUT)', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final sa = svc(a, srv);
    await sa.create();
    final k = await cachedDerive(sa.code!);
    // Chen một bản khác vào ngay sau GET đầu tiên.
    final other = await newStore();
    other.addProfile('Mít', 'bear');
    var injected = true;
    final client = MockClient((req) async {
      final res = await srv.client.send(http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes);
      final out = await http.Response.fromStream(res);
      if (req.method == 'GET' && !injected) {
        injected = true;
        srv.boxes[k.sid] = {'v': 7, 'blob': await sealJson(k, other.snapshot())};
      }
      return out;
    });
    final s2 = SyncService(a, client: client, derive: cachedDerive);
    s2.init();
    await s2.syncNow();
    injected = false;
    a.addTickets(1);
    final r = await s2.syncNow();
    expect(r, 'ok');
    expect(a.profiles.map((p) => p.name).toSet(), {'Na', 'Mít'});
    expect(srv.boxes[k.sid]!['v'], 8);
    s2.dispose();
  });

  test('mất mạng: trả offline, ghi lastErr, giữ cờ dirty để đẩy lại', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final s = svc(a, srv);
    await s.create();
    s.init();
    a.addTickets(1);
    expect(s.dirty, isTrue);
    srv.offline = true;
    expect(await s.syncNow(), 'offline');
    expect(s.lastErr, 'offline');
    expect(s.dirty, isTrue);
    srv.offline = false;
    expect(await s.syncNow(), 'ok');
    expect(s.lastErr, isNull);
    expect(s.dirty, isFalse);
    s.dispose();
  });

  test('create khi mất mạng: không giữ mã', () async {
    final srv = FakeServer()..offline = true;
    final a = await newStore();
    final s = svc(a, srv);
    expect(await s.create(), 'offline');
    expect(s.code, isNull);
  });

  test('lỗi máy chủ 500: lastErr = http 500', () async {
    final a = await newStore();
    a.setKv('bvh.sync', jsonEncode({'code': 'ABCD-EFGH-JKMN-PQ23', 'v': 1}));
    final s = SyncService(a, client: MockClient((_) async => http.Response('oops', 500)), derive: cachedDerive);
    expect(s.code, 'ABCD-EFGH-JKMN-PQ23');
    expect(await s.syncNow(), 'offline');
    expect(s.lastErr, 'http 500');
  });

  test('leave: ngắt máy (giữ dữ liệu); wipeServer gửi DELETE', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final s = svc(a, srv);
    await s.create();
    final sid = (await cachedDerive(s.code!)).sid;
    await s.leave();
    expect(s.code, isNull);
    expect(srv.boxes.containsKey(sid), isTrue);
    expect(a.profiles.length, 1);
    expect(await s.syncNow(), 'off');

    await s.create();
    final sid2 = (await cachedDerive(s.code!)).sid;
    await s.leave(wipeServer: true);
    expect(srv.boxes.containsKey(sid2), isFalse);
    expect(srv.log.last, 'DELETE $sid2');
  });

  test('chạy song song: dùng chung một lượt (busy)', () async {
    final srv = FakeServer();
    final a = await newStore();
    a.addProfile('Na', 'cat');
    final s = svc(a, srv);
    await s.create();
    srv.log.clear();
    final f1 = s.syncNow(), f2 = s.syncNow();
    expect(identical(f1, f2), isTrue);
    await Future.wait([f1, f2]);
    expect(srv.log.length, 1);
  });

  test('trạng thái đọc lại từ bvh.sync (định dạng web)', () async {
    final a = await newStore({'bvh.sync': jsonEncode({'code': 'ABCD-EFGH-JKMN-PQ23', 'v': 4, 'at': 123, 'err': 'offline', 'dirty': true})});
    final s = SyncService(a, client: MockClient((_) async => http.Response('', 500)));
    expect(s.code, 'ABCD-EFGH-JKMN-PQ23');
    expect(s.lastAt, 123);
    expect(s.lastErr, 'offline');
    expect(s.dirty, isTrue);
    expect(s.version, 4);
    expect(s.supported, isTrue);
  });
}
