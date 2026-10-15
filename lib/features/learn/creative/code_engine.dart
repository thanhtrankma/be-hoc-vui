// Lõi thuần (không giao diện) của đảo Lập trình — port phần sinh đề / chạy thử / BFS của games/code.js.
// 4 kiểu bài: garden (tìm đường, tưới), loop (thẻ lặp lại), debug (sửa một thẻ sai), trace (đoán robot dừng ở đâu).
// Đề sinh rồi kiểm bằng BFS: số ô lệnh = lời giải ngắn nhất + dư. Bài lặp sinh từ chương trình đáp án, và lời giải
// KHÔNG lặp ngắn nhất phải dài hơn số ô, nên bé buộc phải dùng thẻ lặp lại.
import 'dart:math' as math;

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/ui/utils.dart' show shuffle;

const List<(int, int)> kDirs = [(0, -1), (1, 0), (0, 1), (-1, 0)]; // 0 lên, 1 phải, 2 xuống, 3 trái
const Map<String, int> kAbs = {'U': 0, 'R': 1, 'D': 2, 'L': 3};
const List<String> kFlowers = ['Sunflower', 'Tulip', 'Blossom', 'Hibiscus'];

final math.Random _rng = math.Random();
int _rand(int a, int b) => a + _rng.nextInt(b - a + 1);
T _pick<T>(List<T> a) => a[_rng.nextInt(a.length)];

/// Khối lặp {rep, body: [lệnh]} (không lồng nhau). Chương trình = List<Object> gồm String (lệnh) và Rep.
class Rep {
  Rep(this.rep, [List<String>? body]) : body = body ?? [];
  int rep;
  final List<String> body;
  Rep clone() => Rep(rep, [...body]);
  @override
  String toString() => '{rep: $rep, body: $body}';
}

int progCost(List<Object> prog) => prog.fold(0, (n, it) => n + (it is Rep ? 1 + it.body.length : 1));
List<Object> cloneProg(List<Object> prog) => [for (final it in prog) it is Rep ? it.clone() : it];

class Step {
  const Step(this.c, this.at, {this.blk, this.r});
  final String c;
  final String at; // '3' hoặc '1.2' (khối 1, thẻ 2)
  final int? blk;
  final int? r;
}

List<Step> flatProg(List<Object> prog) {
  final out = <Step>[];
  for (var i = 0; i < prog.length; i++) {
    final it = prog[i];
    if (it is Rep) {
      for (var r = 0; r < it.rep; r++) {
        for (var j = 0; j < it.body.length; j++) {
          out.add(Step(it.body[j], '$i.$j', blk: i, r: r));
        }
      }
    } else {
      out.add(Step(it as String, '$i'));
    }
  }
  return out;
}

bool _isMove(String c) => kAbs.containsKey(c) || c == 'F' || c == 'J';

/// Một đề: khu vườn n×n. Ô = y * n + x.
class Garden {
  Garden({
    required this.n,
    required this.start,
    required this.dir,
    Set<int>? rocks,
    Set<int>? logs,
    List<(int, int)>? sprouts,
    this.cap = 99,
    this.sol = const [],
    this.cmds = const [],
    this.prog,
    this.wrong,
    this.end,
  })  : rocks = rocks ?? {},
        logs = logs ?? {},
        sprouts = sprouts ?? [];
  final int n;
  final (int, int) start;
  final int dir;
  final Set<int> rocks, logs;
  final List<(int, int)> sprouts;
  final int cap;
  final List<Object> sol;
  final List<String> cmds;

  /// debug: chương trình có lỗi; trace: chương trình cho xem.
  final List<Object>? prog;

  /// debug: vị trí thẻ sai ('i' hoặc 'i.j').
  final String? wrong;

  /// trace: ô robot dừng.
  final (int, int)? end;

  Garden copyWith({Set<int>? rocks, int? cap, List<Object>? sol, List<String>? cmds, List<Object>? prog, String? wrong}) => Garden(
        n: n,
        start: start,
        dir: dir,
        rocks: rocks ?? this.rocks,
        logs: logs,
        sprouts: sprouts,
        cap: cap ?? this.cap,
        sol: sol ?? this.sol,
        cmds: cmds ?? this.cmds,
        prog: prog ?? this.prog,
        wrong: wrong ?? this.wrong,
        end: end,
      );

  bool free(int x, int y) => x >= 0 && y >= 0 && x < n && y < n && !rocks.contains(y * n + x) && !logs.contains(y * n + x);
}

class SimEvent {
  const SimEvent(this.step, this.kind, this.x, this.y, this.dir, {this.k = -1});
  final Step step;
  final String kind; // move | jump | turn | water | bump
  final int x, y, dir;
  final int k; // water: mầm vừa tưới (-1 = tưới chỗ không có mầm / mầm đã ướt)
}

class SimResult {
  SimResult(this.ev, this.x, this.y, this.dir, this.wet, this.win, {this.bump = false});
  final List<SimEvent> ev;
  final int x, y, dir;
  final Set<int> wet;
  final bool win, bump;
}

/// Chạy chương trình, trả về các bước để diễn hoạt. Dừng ngay khi tưới đủ (bé không bị phạt vì thừa lệnh).
SimResult simulate(Garden m, List<Object> prog) {
  var (x, y) = m.start;
  var dir = m.dir;
  final wet = <int>{}, ev = <SimEvent>[], k = m.sprouts.length;
  SimResult done({bool bump = false}) => SimResult(ev, x, y, dir, wet, k > 0 && wet.length == k, bump: bump);
  for (final st in flatProg(prog)) {
    final c = st.c;
    if (_isMove(c)) {
      if (kAbs.containsKey(c)) dir = kAbs[c]!;
      final s = c == 'J' ? 2 : 1, nx = x + kDirs[dir].$1 * s, ny = y + kDirs[dir].$2 * s;
      if (!m.free(nx, ny)) {
        ev.add(SimEvent(st, 'bump', x, y, dir));
        return done(bump: true);
      }
      x = nx;
      y = ny;
      ev.add(SimEvent(st, c == 'J' ? 'jump' : 'move', x, y, dir));
    } else if (c == 'TL' || c == 'TR') {
      dir = (dir + (c == 'TR' ? 1 : 3)) % 4;
      ev.add(SimEvent(st, 'turn', x, y, dir));
    } else if (c == 'W') {
      final i = m.sprouts.indexWhere((s) => s.$1 == x && s.$2 == y);
      final fresh = i >= 0 && !wet.contains(i);
      if (fresh) wet.add(i);
      ev.add(SimEvent(st, 'water', x, y, dir, k: fresh ? i : -1));
      if (k > 0 && wet.length == k) return done();
    }
  }
  return done();
}

/// BFS lời giải KHÔNG lặp ngắn nhất với bộ lệnh cmds. Trả về (len, prog) hoặc null.
({int len, List<String> prog})? shortest(Garden m, List<String> cmds) {
  final n = m.n, k = m.sprouts.length, full = (1 << k) - 1, abs = cmds.contains('U');
  final sp = {for (var i = 0; i < k; i++) m.sprouts[i].$2 * n + m.sprouts[i].$1: i};
  int key(int x, int y, int d, int mm) => ((mm * 4 + d) * n + y) * n + x;
  final s0 = (m.start.$1, m.start.$2, abs ? 0 : m.dir, 0);
  final prev = <int, (int, String)?>{key(s0.$1, s0.$2, s0.$3, s0.$4): null};
  var q = [s0];
  while (q.isNotEmpty) {
    final nq = <(int, int, int, int)>[];
    for (final s in q) {
      final (x, y, d, mm) = s;
      if (mm == full) {
        final prog = <String>[];
        for (var kk = key(x, y, d, mm); prev[kk] != null; kk = prev[kk]!.$1) {
          prog.insert(0, prev[kk]!.$2);
        }
        return (len: prog.length, prog: prog);
      }
      for (final c in cmds) {
        (int, int, int, int)? t;
        if (_isMove(c)) {
          final dd = kAbs[c] ?? d, st = c == 'J' ? 2 : 1, nx = x + kDirs[dd].$1 * st, ny = y + kDirs[dd].$2 * st;
          if (m.free(nx, ny)) t = (nx, ny, abs ? 0 : dd, mm);
        } else if (c == 'TL' || c == 'TR') {
          t = (x, y, (d + (c == 'TR' ? 1 : 3)) % 4, mm);
        } else if (c == 'W') {
          final i = sp[y * n + x];
          if (i != null && (mm >> i & 1) == 0) t = (x, y, d, mm | 1 << i);
        }
        if (t == null) continue;
        final kk = key(t.$1, t.$2, t.$3, t.$4);
        if (prev.containsKey(kk)) continue;
        prev[kk] = (key(x, y, d, mm), c);
        nq.add(t);
      }
    }
    q = nq;
  }
  return null;
}

List<String> atoms(List<String> cmds) => cmds.where((c) => c != 'REP').toList();

List<String> _cmdsOf(Json o) => (o['cmds'] as List? ?? const []).map((e) => e.toString()).toList();
double _num(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : d;

/// Bài tìm đường: rải mầm, đá, (hàng khúc gỗ) ngẫu nhiên rồi lọc bằng BFS.
Garden? genGarden(Json o) {
  final all = _cmdsOf(o), cmds = atoms(all), abs = cmds.contains('U');
  final n = _int(o['n'], 4), kk = _int(o['k'], 1);
  for (var tries = 0; tries < 400; tries++) {
    final rocks = <int>{}, logs = <int>{};
    if (o['jump'] == true) {
      // một hàng rào khúc gỗ chắn ngang vườn, chỉ nhảy qua được
      final col = _rng.nextDouble() < .5, at = _rand(1, n - 2);
      for (var i = 0; i < n; i++) {
        logs.add(col ? i * n + at : at * n + i);
      }
    }
    List<int> empty() => shuffle([for (var i = 0; i < n * n; i++) if (!logs.contains(i) && !rocks.contains(i)) i]);
    for (final i in empty()) {
      if (_rng.nextDouble() < _num(o['rocks'])) rocks.add(i);
    }
    final cells = empty();
    if (cells.length < kk + 1) continue;
    final s = cells.removeLast();
    final m = Garden(
      n: n,
      start: (s % n, s ~/ n),
      dir: abs ? 1 : _rand(0, 3),
      rocks: rocks,
      logs: logs,
      sprouts: [for (final i in cells.take(kk)) (i % n, i ~/ n)],
    );
    final res = shortest(m, cmds);
    if (res == null || res.len < _int(o['min']) || res.len > _int(o['max'], 99)) continue;
    if (o['detour'] == true) {
      final free = shortest(m.copyWith(rocks: {}), cmds);
      if (free != null && free.len >= res.len) continue; // phải có đường vòng thật
    }
    if (o['jump'] == true && shortest(m, cmds.where((c) => c != 'J').toList()) != null) continue; // phải dùng thẻ nhảy
    return m.copyWith(cap: res.len + _int(o['spare']), sol: res.prog, cmds: all);
  }
  return null;
}

class _Walk {
  _Walk(this.x, this.y, this.dir, this.seen, this.waters, this.mids);
  final int x, y, dir;
  final Set<int> seen;
  final List<(int, int)> waters;
  final Set<int> mids;
}

/// Đi thử một chương trình trên vườn trống: các ô đi qua, ô tưới, ô bị nhảy qua (để đặt khúc gỗ).
_Walk? _walkEmpty(List<Object> prog, int n, (int, int) start, int dir) {
  var (x, y) = start;
  final seen = <int>{y * n + x}, waters = <(int, int)>[], mids = <int>{};
  for (final st in flatProg(prog)) {
    final c = st.c;
    if (_isMove(c)) {
      if (kAbs.containsKey(c)) dir = kAbs[c]!;
      final s = c == 'J' ? 2 : 1, nx = x + kDirs[dir].$1 * s, ny = y + kDirs[dir].$2 * s;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) return null;
      if (s == 2) mids.add((y + kDirs[dir].$2) * n + x + kDirs[dir].$1);
      x = nx;
      y = ny;
      seen.add(y * n + x);
    } else if (c == 'TL' || c == 'TR') {
      dir = (dir + (c == 'TR' ? 1 : 3)) % 4;
    } else if (c == 'W') {
      if (waters.any((w) => w.$1 == x && w.$2 == y)) return null;
      waters.add((x, y));
    }
  }
  for (final m in mids) {
    if (seen.contains(m)) return null;
  }
  return _Walk(x, y, dir, seen, waters, mids);
}

/// Mẫu chương trình có lặp (thân lặp dùng TR, mirror đổi sang TL).
final Map<String, List<Object> Function()> kLoops = {
  'row': () => [Rep(_rand(3, 5), ['F', 'W'])],
  'gap': () => [Rep(_rand(2, 3), ['F', 'F', 'W'])],
  'stairs': () => [Rep(_rand(3, 4), ['F', 'TR', 'F', 'TL', 'W'])],
  'square': () => [Rep(4, ['F', 'F', 'W', 'TR'])],
  'jumps': () => [Rep(_rand(2, 3), ['J', 'W'])],
  'corner': () => [Rep(_rand(3, 4), ['F', 'W']), 'TR', Rep(_rand(2, 4), ['F', 'W'])],
  'zigzag': () => [Rep(2, ['F', 'F', 'W', 'TR', 'F', 'TR', 'F', 'F', 'W', 'TL', 'F', 'TL'])],
};

String _mir(String c) => c == 'TR' ? 'TL' : c == 'TL' ? 'TR' : c;
List<Object> _mirror(List<Object> prog) => [for (final it in prog) it is Rep ? Rep(it.rep, it.body.map(_mir).toList()) : _mir(it as String)];

Garden? genLoop(Json o) {
  final all = _cmdsOf(o), cmds = atoms(all);
  final loops = (o['loops'] is List ? o['loops'] as List : const ['row']).map((e) => e.toString()).toList();
  final n = _int(o['n'], 6);
  for (var tries = 0; tries < 400; tries++) {
    var prog = kLoops[_pick(loops)]!();
    if (_rng.nextDouble() < .5) prog = _mirror(prog);
    final start = (_rand(0, n - 1), _rand(0, n - 1)), dir = _rand(0, 3);
    final w = _walkEmpty(prog, n, start, dir);
    if (w == null || w.waters.isEmpty) continue;
    final rocks = <int>{};
    for (var i = 0; i < n * n; i++) {
      if (!w.seen.contains(i) && !w.mids.contains(i) && _rng.nextDouble() < _num(o['rocks'])) rocks.add(i);
    }
    final m = Garden(n: n, start: start, dir: dir, rocks: rocks, logs: {...w.mids}, sprouts: w.waters);
    final cap = progCost(prog) + _int(o['spare']);
    final res = shortest(m, cmds);
    if (res == null || res.len <= cap) continue; // không dùng lặp mà vẫn vừa số ô thì bài vô nghĩa
    if (!simulate(m, prog).win) continue;
    return m.copyWith(cap: cap, sol: prog, cmds: all);
  }
  return null;
}

/// Bài sửa lỗi: lấy lời giải đúng, đổi đúng một thẻ (hoặc số lần lặp) sao cho chạy sai.
Garden? genDebug(Json o) {
  final cmds = atoms(_cmdsOf(o));
  for (var tries = 0; tries < 60; tries++) {
    final m = o['loops'] != null ? genLoop(o) : genGarden(o);
    if (m == null) continue;
    final spots = <(int, int?, bool)>[]; // (i, j, rep)
    for (var i = 0; i < m.sol.length; i++) {
      final it = m.sol[i];
      if (it is Rep) {
        spots.add((i, null, true));
        for (var j = 0; j < it.body.length; j++) {
          spots.add((i, j, false));
        }
      } else {
        spots.add((i, null, false));
      }
    }
    for (var t = 0; t < 20; t++) {
      final sp = _pick(spots), prog = cloneProg(m.sol);
      if (sp.$3) {
        final r = (prog[sp.$1] as Rep).rep + _pick<int>(const [-1, 1]);
        if (r < 2 || r > 6) continue;
        (prog[sp.$1] as Rep).rep = r;
      } else {
        final old = sp.$2 == null ? prog[sp.$1] as String : (prog[sp.$1] as Rep).body[sp.$2!];
        final nw = _pick(cmds.where((c) => c != old).toList());
        if (sp.$2 == null) {
          prog[sp.$1] = nw;
        } else {
          (prog[sp.$1] as Rep).body[sp.$2!] = nw;
        }
      }
      if (simulate(m, prog).win) continue;
      return m.copyWith(prog: prog, wrong: sp.$2 == null ? '${sp.$1}' : '${sp.$1}.${sp.$2}');
    }
  }
  return null;
}

/// Bài đoán đích: chương trình ngẫu nhiên đi trong vườn, ô cuối khác ô đầu.
Garden? genTrace(Json o) {
  final cmds = atoms(_cmdsOf(o)), n = _int(o['n'], 4), loops = o['loops'] == true;
  for (var tries = 0; tries < 500; tries++) {
    final start = (_rand(0, n - 1), _rand(0, n - 1)), dir = cmds.contains('U') ? 1 : _rand(0, 3);
    List<Object> prog;
    if (loops) {
      final body = List.generate(_rand(2, 3), (_) => _pick(cmds));
      if (!body.any((c) => c == 'F' || kAbs.containsKey(c))) continue;
      prog = [Rep(_rand(2, 3), body)];
      if (_rng.nextDouble() < .5) prog.add(_pick(cmds));
    } else {
      prog = List.generate(_rand(_int(o['min'], 2), _int(o['max'], 3)), (_) => _pick(cmds));
    }
    if (!loops && !cmds.contains('U') && (prog.last == 'TL' || prog.last == 'TR')) continue;
    final w = _walkEmpty(prog, n, start, dir);
    if (w == null || (w.x == start.$1 && w.y == start.$2)) continue;
    if ((w.x - start.$1).abs() + (w.y - start.$2).abs() < 2 && _rng.nextDouble() < .7) continue;
    return Garden(n: n, start: start, dir: dir, prog: prog, end: (w.x, w.y), cmds: _cmdsOf(o));
  }
  return null;
}
