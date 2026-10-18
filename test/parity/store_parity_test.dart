// Đối chiếu store: phát lại đúng các thao tác mà store.js THẬT của web đã chạy (fixtures/web_store_trace.json, ghi lại bằng
// Node lúc mã web còn trong repo; mã web và công cụ sinh đã gỡ, bản ghi giữ nguyên) trên AppStore và so kết quả + toàn bộ
// JSON lưu sau từng bước.
// Bỏ qua các dấu giờ tuyệt đối (mt, smt, created, giá trị gone) vì phụ thuộc múi giờ máy chạy; ngày (YYYY-MM-DD, dayNum) vẫn so.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Random trả cùng dãy với Math.random đã thay trong Node: nextInt(n) = floor(x * n) như web.
class SeqRandom implements Random {
  SeqRandom(this.seq);
  final List<double> seq;
  int i = 0;
  @override
  double nextDouble() => seq[i++ % seq.length];
  @override
  int nextInt(int max) => (nextDouble() * max).floor();
  @override
  bool nextBool() => nextDouble() < .5;
}

/// Bỏ dấu giờ tuyệt đối; giữ nguyên phần còn lại.
Object? norm(Object? v, [String? key]) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (!const {'mt', 'smt', 'created', 'exported'}.contains(e.key)) e.key: key == 'gone' ? 'ts' : norm(e.value, e.key as String),
    };
  }
  if (v is List) return [for (final x in v) norm(x)];
  if (v is double && v == v.roundToDouble()) return v.toInt();
  return v;
}

void main() {
  final trace = jsonDecode(File('test/parity/fixtures/web_store_trace.json').readAsStringSync()) as Map<String, dynamic>;

  test('store.dart chạy giống hệt store.js của web (${(trace['ops'] as List).length} thao tác)', () async {
    var at = <int>[2026, 10, 14, 9, 0];
    DateTime clock() => DateTime(at[0], at[1], at[2], at[3], at[4]);
    SharedPreferences.setMockInitialValues({kStoreKey: jsonEncode(trace['init'])});
    final prefs = await SharedPreferences.getInstance();
    final s = AppStore(prefs, clock: clock, random: SeqRandom([for (final x in trace['random'] as List) (x as num).toDouble()]));

    for (final (n, raw) in (trace['ops'] as List).indexed) {
      final o = raw as Map<String, dynamic>;
      at = [for (final x in o['at'] as List) x as int];
      final a = o['args'] as List;
      final p = s.profile;
      Object? res;
      switch (o['op']) {
        case 'recordRound':
          res = s.recordRound(a[0] as String, a[1] as int, a[2] as int, (a[3] as List).cast<String>());
        case 'levelStars':
          res = s.levelStars(p!, a[0] as String, a[1] as int);
        case 'addUsage':
          s.addUsage(a[0] as int);
        case 'overLimit':
          res = s.overLimit();
        case 'addBonus':
          s.addBonus(a[0] as int);
        case 'setSetting':
          s.setSetting(a[0] as String, a[1]);
        case 'buy':
          res = s.buy(WardrobeItem.fromJson((a[0] as Map).cast<String, dynamic>()));
        case 'wallet':
          res = s.wallet(p!);
        case 'equip':
          s.equip(a[0] as String, a[1] as String?);
        case 'daily':
          res = s.daily((a[0] as List).cast<String>());
        case 'dailyProgress':
          res = s.dailyProgress(a[0] as String);
        case 'dailyProgressAll':
          final d = p!.json['daily'];
          res = [for (final id in d is Map ? List<String>.from(d['tasks'] as List) : <String>[]) s.dailyProgress(id)];
        case 'newBadges':
          res = s.newBadges((a[0] as List).cast<String>());
        case 'tickets':
          res = s.tickets(p!);
        case 'addTickets':
          s.addTickets(a[0] as int);
        case 'useTicket':
          res = s.useTicket();
        case 'saveBest':
          res = s.saveBest(a[0] as String, a[1] as int);
        case 'funLevelUp':
          s.funLevelUp(a[0] as String);
        case 'funLevel':
          res = s.funLevel(p!, a[0] as String);
        case 'saveGear':
          s.saveGear(a[0] as String, (a[1] as Map?)?.cast<String, dynamic>());
        case 'recordAnswer':
          res = s.recordAnswer(a[0] as String, (a[1] as List).cast<String>(), a[2] as bool, (a[3] as List).cast<String>(), a[4] as int);
        case 'dueItems':
          res = s.dueItems(p!, all: a[0] as bool);
        case 'recordReview':
          s.recordReview(a[0] as int);
        case 'addMilestones':
          res = s.addMilestones((a[0] as List).cast<String>());
        case 'updateProfile':
          s.updateProfile(a[0] as String, (a[1] as Map).cast<String, dynamic>());
        case 'setActive':
          s.setActive(a[0] as String);
        case 'mergeRemote':
          res = s.mergeRemote(jsonDecode(jsonEncode(a[0])));
        case 'removeProfile':
          s.removeProfile(a[0] as String);
        case 'exportImport':
          final txt = s.exportData();
          s.importData(txt);
          res = (jsonDecode(txt) as Map)['app'];
        case 'importBad':
          try {
            s.importData(a[0] as String);
            res = 'ok';
          } catch (_) {
            res = 'error';
          }
        default:
          fail('thao tác lạ ${o['op']}');
      }
      final why = 'bước $n: ${o['op']} ${jsonEncode(a).substring(0, min(80, jsonEncode(a).length))}';
      expect(norm(jsonDecode(jsonEncode(res))), norm(o['result']), reason: '$why → kết quả');
      final state = {...s.snapshot(), 'active': s.profile?.id};
      expect(norm(jsonDecode(jsonEncode(state))), norm(o['state']), reason: '$why → trạng thái lưu');
    }
  });
}
