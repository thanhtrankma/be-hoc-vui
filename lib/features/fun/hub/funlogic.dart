// Game trí tuệ: lập trình robot, nối dây màu, dẫn nước, bảng số thần tốc (port reference/web/js/games/funlogic.js).
// CHỦ: agent E. Đề sinh ngẫu nhiên theo cấp, luôn có lời giải. Mỗi lượt 3 câu đố (bảng số: 2 bảng); mỗi câu là một cấp:
// giải xong lên cấp ngay (ctx.levelUp()), câu sau khó hơn. Không "leveled": tự trả FunResult(lvUp:, ups:).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/creative/figure.dart' show FigureView, kBot;

import 'funcore.dart';

/// id game → module (khoá trùng FUN_GAMES).
final Map<String, FunGameModule> funlogicGames = {
  'coding': _LogicModule('coding', 'codingQ', 3, (ctx, lv, onDone) => CodingPuzzle(key: ValueKey('coding-$lv'), lv: lv, ctx: ctx, onSolved: onDone)),
  'flow': _LogicModule('flow', 'flowQ', 3, (ctx, lv, onDone) => FlowPuzzle(key: ValueKey('flow-$lv'), lv: lv, ctx: ctx, onSolved: onDone)),
  'pipes': _LogicModule('pipes', 'pipesQ', 3, (ctx, lv, onDone) => PipesPuzzle(key: ValueKey('pipes-$lv'), lv: lv, ctx: ctx, onSolved: onDone)),
  'schulte': _LogicModule('schulte', 'schulteQ', 2, (ctx, lv, onDone) => SchultePuzzle(key: ValueKey('schulte-$lv'), lv: lv, ctx: ctx, onSolved: onDone)),
};

typedef LogicMake = Widget Function(FunGameContext ctx, int lv, void Function(int score) onDone);

const Map<String, List<int>> kDirs = {
  'u': [0, -1],
  'r': [1, 0],
  'd': [0, 1],
  'l': [-1, 0],
};
const Map<String, String> _arrow = {'u': '⬆️', 'r': '➡️', 'd': '⬇️', 'l': '⬅️'};

class _LogicModule extends FunGameModule {
  const _LogicModule(this.id, this.intro, this.n, this.make);
  @override
  final String id;
  final String intro;
  final int n;
  final LogicMake make;
  @override
  Widget build(BuildContext context, FunGameContext ctx) => LogicSessions(ctx: ctx, intro: intro, n: n, make: make);
}

/// Khung chung: tiêu đề, "Cấp n", chấm tiến độ, vùng câu đố; mỗi câu xong → lên cấp + "⭐ Lên cấp n!" (sessions()).
class LogicSessions extends StatefulWidget {
  const LogicSessions({super.key, required this.ctx, required this.intro, required this.n, required this.make});
  final FunGameContext ctx;
  final String intro;
  final int n;
  final LogicMake make;
  @override
  State<LogicSessions> createState() => _LogicSessionsState();
}

class _LogicSessionsState extends State<LogicSessions> {
  int i = 0, score = 0;
  String? pop;
  bool busy = false;

  FunGameContext get ctx => widget.ctx;
  int get lv => math.min(kFunMax - 1, ctx.level + i);

  @override
  void initState() {
    super.initState();
    ctx.audio.sayPhrase(widget.intro);
  }

  Future<void> _solved(int r) async {
    if (busy || !mounted || !ctx.alive) return;
    busy = true;
    score += r;
    ctx.audio.sfx('power');
    ctx.levelUp();
    final en = ctx.i18n.isEn;
    setState(() => pop = '⭐ ${lv + 1 >= kFunMax ? (en ? 'Top level!' : 'Cấp cao nhất!') : (en ? 'Level ${lv + 2}!' : 'Lên cấp ${lv + 2}!')}');
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted || !ctx.alive) return;
    if (i + 1 >= widget.n) {
      setState(() {
        i = widget.n;
        pop = null;
      });
      ctx.finish(FunResult(win: true, score: score, lvUp: true, ups: widget.n));
      return;
    }
    setState(() {
      i++;
      pop = null;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fs = baseFontSize(context);
    final def = funGameDef(ctx.gameId);
    final title = def == null ? ctx.gameId : ctx.i18n.L(def);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE7F5FF), Color(0xFFFFF9DB)])),
      child: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 4, children: [
                  Text(title, style: TextStyle(fontSize: fs * 1.3, fontWeight: FontWeight.w800, color: AppColors.ink2)),
                  Container(
                    key: const Key('lg-lvl'),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(999)),
                    child: Text('${ctx.i18n.t('level')} ${lv + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF5C4400), fontSize: fs * 1.05)),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                    for (var k = 0; k < widget.n; k++)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: k < i ? AppColors.good : (k == i ? AppColors.sun : const Color(0xFFDEE2E6))),
                      ),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(child: i < widget.n ? Center(child: widget.make(ctx, lv, _solved)) : const SizedBox()),
            ]),
          ),
          if (pop != null)
            Center(
              child: RiseIn(
                index: 0,
                child: Container(
                  key: const Key('lvup'),
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: kCardShadow),
                  child: Text(pop!, style: TextStyle(fontSize: fs * 2, fontWeight: FontWeight.w800, color: const Color(0xFFE67700))),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Nảy nhẹ (scale 1 → k → 1) mỗi khi [trigger] đổi.
class _Bounce extends StatelessWidget {
  const _Bounce({required this.trigger, required this.child, this.k = 1.18, this.ms = 300, this.delayMs = 0});
  final Object trigger;
  final Widget child;
  final double k;
  final int ms, delayMs;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(trigger),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: ms + delayMs),
        builder: (context, v, child) {
          final d = delayMs / (ms + delayMs);
          final x = v <= d ? 0.0 : (v - d) / (1 - d);
          return Transform.scale(scale: 1 + (k - 1) * math.sin(x * math.pi), child: child);
        },
        child: child,
      );
}

// =================================================================================================================
// 1. Lập trình robot
// =================================================================================================================

class CodingLevel {
  CodingLevel({required this.n, required this.start, required this.goal, required this.rocks, required this.coins, required this.max, required this.path});
  final int n;
  final List<int> start, goal;
  final List<List<int>> rocks, coins, path;
  final int max;
}

/// Sinh đề lập trình robot (codingLevel()). path = đường đi mẫu (lời giải).
CodingLevel codingLevel(int lv) {
  final n = lv < 6 ? 5 : (lv < 18 ? 6 : (lv < 36 ? 7 : 8));
  final len = math.min(24, lv < 9 ? 4 + lv : 13 + (lv - 9) ~/ 4), spare = lv < 20 ? 3 : (lv < 40 ? 2 : 1);
  for (var tries = 0; tries < 400; tries++) {
    final start = [0, rng.nextInt(n)];
    final path = [start];
    final seen = {start.join(',')};
    var ok = true;
    while (path.length <= len) {
      final x = path.last[0], y = path.last[1];
      final opts = shuffle(kDirs.values).map((d) => [x + d[0], y + d[1]]).where((p) => p[0] >= 0 && p[1] >= 0 && p[0] < n && p[1] < n && !seen.contains(p.join(','))).toList();
      if (opts.isEmpty) {
        ok = false;
        break;
      }
      path.add(opts.first);
      seen.add(opts.first.join(','));
    }
    if (!ok) continue;
    final goal = path.last;
    if ((goal[0] - start[0]).abs() + (goal[1] - start[1]).abs() < math.min(len, 3)) continue;
    final rocks = <List<int>>[];
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!seen.contains('$x,$y') && rng.nextDouble() < .3) rocks.add([x, y]);
      }
    }
    return CodingLevel(n: n, start: start, goal: goal, rocks: rocks, coins: shuffle(path.sublist(2, path.length - 1)).take(lv < 20 ? 2 : 3).toList(), max: path.length - 1 + spare, path: path);
  }
  // Rất hiếm: đề đơn giản đi thẳng.
  return CodingLevel(n: n, start: [0, 0], goal: [3, 0], rocks: const [], coins: const [], max: 3 + spare, path: [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0]
  ]);
}

class CodingPuzzle extends StatefulWidget {
  const CodingPuzzle({super.key, required this.lv, required this.ctx, required this.onSolved, this.level});
  final int lv;
  final FunGameContext ctx;
  final void Function(int score) onSolved;

  /// Đề cố định (kiểm thử); null = sinh ngẫu nhiên.
  final CodingLevel? level;
  @override
  State<CodingPuzzle> createState() => CodingPuzzleState();
}

class CodingPuzzleState extends State<CodingPuzzle> {
  late final CodingLevel L = widget.level ?? codingLevel(widget.lv);
  late final Set<String> rock = L.rocks.map((p) => p.join(',')).toSet();
  final prog = <String>[];
  bool busy = false, won = false;
  late List<int> pos = [...L.start];
  int tries = 0, hop = 0, bump = 0, face = 1, runIdx = -1;
  List<int> bumpDir = const [0, 0];
  Set<String> coinsLeft = {};
  int popSlot = -1;

  @override
  void initState() {
    super.initState();
    coinsLeft = L.coins.map((p) => p.join(',')).toSet();
  }

  FunGameContext get ctx => widget.ctx;

  void _add(String d) {
    if (prog.length >= L.max || busy) return;
    ctx.audio.sfx('tap');
    setState(() {
      prog.add(d);
      popSlot = prog.length - 1;
    });
  }

  void _place(List<int> p, {bool doHop = true}) {
    if (p[0] != pos[0]) face = p[0] > pos[0] ? 1 : -1;
    pos = p;
    if (doHop) hop++;
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> run() async {
    if (busy || prog.isEmpty) return;
    setState(() {
      busy = true;
      tries++;
      _place([...L.start]);
      coinsLeft = L.coins.map((p) => p.join(',')).toSet();
    });
    var got = 0;
    await _wait(250);
    for (var i = 0; i < prog.length; i++) {
      if (!mounted || !ctx.alive) return;
      setState(() => runIdx = i);
      final d = kDirs[prog[i]]!;
      final nx = pos[0] + d[0], ny = pos[1] + d[1];
      if (nx < 0 || ny < 0 || nx >= L.n || ny >= L.n || rock.contains('$nx,$ny')) {
        ctx.audio.sfx('wrong');
        setState(() {
          bump++;
          bumpDir = d;
        });
        await _wait(600);
        break;
      }
      setState(() => _place([nx, ny]));
      ctx.audio.sfx('jump');
      if (coinsLeft.remove('$nx,$ny')) {
        got++;
        ctx.audio.sfx('coin');
      }
      await _wait(420);
    }
    if (!mounted || !ctx.alive) return;
    setState(() => runIdx = -1);
    if (pos[0] == L.goal[0] && pos[1] == L.goal[1]) {
      setState(() => won = true);
      widget.onSolved(math.max(3, 12 - tries * 2) + got * 2);
      return;
    }
    ctx.audio.sfx('wrong');
    await _wait(400);
    if (!mounted) return;
    setState(() {
      _place([...L.start]);
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final size = math.min(math.min(mq.width * .92, mq.height * .62), 560.0);
    final n = L.n, inner = size - 12, cell = inner / n;
    final grid = SizedBox.square(
      key: const Key('code-grid'),
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFFB2F2BB), borderRadius: BorderRadius.circular(20)),
        child: Stack(clipBehavior: Clip.none, children: [
          for (var y = 0; y < n; y++)
            for (var x = 0; x < n; x++)
              Positioned(
                left: 6 + x * cell + 2,
                top: 6 + y * cell + 2,
                width: cell - 4,
                height: cell - 4,
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFEBFBEE), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: rock.contains('$x,$y')
                      ? EmojiImage('Rock', size: cell * .76, photo: false)
                      : (x == L.goal[0] && y == L.goal[1])
                          ? AnimatedRotation(
                              turns: won ? 1 : 0,
                              duration: const Duration(milliseconds: 700),
                              child: AnimatedScale(scale: won ? 1.3 : 1, duration: const Duration(milliseconds: 700), child: EmojiImage('Glowing star', size: cell * .76, photo: false)),
                            )
                          : L.coins.any((p) => p[0] == x && p[1] == y)
                              ? AnimatedSlide(
                                  offset: coinsLeft.contains('$x,$y') ? Offset.zero : const Offset(0, -1.6),
                                  duration: const Duration(milliseconds: 450),
                                  child: AnimatedOpacity(
                                      opacity: coinsLeft.contains('$x,$y') ? 1 : 0, duration: const Duration(milliseconds: 450), child: EmojiImage('Coin', size: cell * .5, photo: false)),
                                )
                              : null,
                ),
              ),
          // Robot người que màu xanh do bé lập trình
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            left: 6 + pos[0] * cell,
            top: 6 + pos[1] * cell,
            width: cell,
            height: cell,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('hop$hop-$bump'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 350),
                builder: (context, v, child) {
                  final up = hop == 0 ? 0.0 : -math.sin(v * math.pi) * cell * .22;
                  return Transform.translate(offset: Offset(0, up), child: child);
                },
                child: _Shake(
                  trigger: bump,
                  dir: bumpDir,
                  amount: cell * .18,
                  child: FigureView(costume: kBot.copyWith(shirt: const Color(0xFF339AF0), pants: const Color(0xFF1971C2)), size: cell, pose: won ? 'cheer' : (busy ? 'run' : 'idle'), face: face),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    final progEl = Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
      for (var i = 0; i < L.max; i++)
        GestureDetector(
          key: Key('cslot-$i'),
          onTap: () {
            if (busy || i >= prog.length) return;
            ctx.audio.sfx('pop');
            setState(() => prog.removeAt(i));
          },
          child: AnimatedScale(
            scale: runIdx == i ? 1.12 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: runIdx == i ? const Color(0xFFFFF3BF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i < prog.length ? const Color(0xFF40C057) : const Color(0xFFCED4DA), width: 3),
              ),
              child: i < prog.length ? _Bounce(trigger: popSlot == i ? 'p$i-${prog.length}' : 'n', k: popSlot == i ? 1.2 : 1, child: Text(_arrow[prog[i]]!, style: const TextStyle(fontSize: 26))) : null,
            ),
          ),
        ),
    ]);
    final pad = Wrap(spacing: 10, children: [
      for (final d in _arrow.keys)
        Chunky(
          key: Key('cbtn-$d'),
          onTap: () => _add(d),
          radius: 22,
          depth: 6,
          child: SizedBox.square(dimension: 76, child: Center(child: Text(_arrow[d]!, style: const TextStyle(fontSize: 40)))),
        ),
    ]);
    final side = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
        progEl,
        pad,
        Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
          AppButton(
              key: const Key('code-clear'),
              label: '↺',
              variant: BtnVariant.ghost,
              onTap: () {
                if (busy) return;
                ctx.audio.sfx('pop');
                setState(prog.clear);
              }),
          AppButton(key: const Key('code-run'), icon: '▶', label: ctx.i18n.isEn ? 'Run' : 'Chạy', variant: BtnVariant.green, onTap: run),
        ]),
      ]),
    );
    return SingleChildScrollView(
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 22, runSpacing: 16, children: [grid, side]),
    );
  }
}

/// Rung ngang/dọc theo hướng dir khi trigger đổi (robot đâm vào đá).
class _Shake extends StatelessWidget {
  const _Shake({required this.trigger, required this.dir, required this.amount, required this.child});
  final int trigger;
  final List<int> dir;
  final double amount;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, child) {
        final k = v < .3 ? v / .3 : 1 - (v - .3) / .7;
        return Transform.translate(offset: Offset(dir[0] * amount * k, dir[1] * amount * k), child: child);
      },
      child: child,
    );
  }
}

// =================================================================================================================
// 2. Nối dây màu
// =================================================================================================================

const List<Color> kFlowColors = [Color(0xFFFA5252), Color(0xFF4C6EF5), Color(0xFF40C057), Color(0xFFFAB005), Color(0xFFBE4BDB), Color(0xFFFD7E14), Color(0xFF15AABF), Color(0xFFE64980), Color(0xFF868E96)];

class FlowLevel {
  FlowLevel(this.n, this.segs);
  final int n;

  /// Các đoạn đường (đáp án), mỗi đoạn là danh sách ô [x, y]; hai đầu là hai chấm cùng màu.
  final List<List<List<int>>> segs;
}

/// Đường đi qua mọi ô (Hamilton) bằng "backbite", rồi cắt thành các đoạn ≥ 3 ô (flowLevel()).
FlowLevel flowLevel(int lv) {
  final n = lv < 4 ? 4 : (lv < 10 ? 5 : (lv < 20 ? 6 : (lv < 32 ? 7 : (lv < 46 ? 8 : 9))));
  var path = <List<int>>[];
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      path.add([y.isOdd ? n - 1 - x : x, y]);
    }
  }
  int idx(List<int> p) => p[1] * n + p[0];
  for (var it = 0; it < n * n * 30; it++) {
    if (rng.nextBool()) path = path.reversed.toList();
    final e = path.last;
    final nb = shuffle(kDirs.values).map((d) => [e[0] + d[0], e[1] + d[1]]).firstWhere((p) => p[0] >= 0 && p[1] >= 0 && p[0] < n && p[1] < n);
    final pos = {for (var i = 0; i < path.length; i++) idx(path[i]): i};
    final j = pos[idx(nb)];
    if (j == null || j == path.length - 2) continue;
    path = [...path.sublist(0, j + 1), ...path.sublist(j + 1).reversed];
  }
  final k = math.min(kFlowColors.length, n == 4 ? 3 : n);
  final cuts = <List<List<int>>>[];
  var rest = path.length, start = 0;
  for (var c = 0; c < k; c++) {
    final remaining = k - c;
    const minLen = 3;
    final maxLen = rest - minLen * (remaining - 1);
    final len = c == k - 1 ? rest : math.max(minLen, math.min(maxLen, (rest / remaining + (rng.nextDouble() - .5) * 3).round()));
    cuts.add(path.sublist(start, start + len));
    start += len;
    rest -= len;
  }
  return FlowLevel(n, cuts);
}

class FlowPuzzle extends StatefulWidget {
  const FlowPuzzle({super.key, required this.lv, required this.ctx, required this.onSolved, this.level});
  final int lv;
  final FunGameContext ctx;
  final void Function(int score) onSolved;
  final FlowLevel? level;
  @override
  State<FlowPuzzle> createState() => FlowPuzzleState();
}

class FlowPuzzleState extends State<FlowPuzzle> {
  late final FlowLevel L = widget.level ?? flowLevel(widget.lv);
  late final int n = L.n;
  late final List<int> owner = List.filled(n * n, -1);
  late final Map<int, int> dots = {
    for (final (c, s) in L.segs.indexed) ...{s.first[1] * n + s.first[0]: c, s.last[1] * n + s.last[0]: c}
  };
  late final List<List<int>> paths = [for (final _ in L.segs) <int>[]];
  int? cur;
  bool solved = false;
  int pulse = 0;
  final Map<int, int> cellPulse = {};

  /// Đáp án dạng chỉ số ô (data-sol của web; dùng cho kiểm thử).
  List<List<int>> get solution => [for (final s in L.segs) s.map((p) => p[1] * n + p[0]).toList()];

  bool _done(int c) {
    final p = paths[c];
    return p.length > 1 && dots[p.first] == c && dots[p.last] == c && p.first != p.last;
  }

  bool _adj(int a, int b) => ((a - b).abs() == 1 && a ~/ n == b ~/ n) || (a - b).abs() == n;

  void _clearPath(int c) {
    for (final i in paths[c]) {
      owner[i] = -1;
    }
    paths[c] = [];
  }

  void _cutAfter(List<int> p, int k) {
    for (final j in p.sublist(k + 1)) {
      owner[j] = -1;
    }
    p.removeRange(k + 1, p.length);
  }

  void down(int i) {
    if (solved) return;
    setState(() {
      if (dots.containsKey(i)) {
        cur = dots[i];
        _clearPath(cur!);
        paths[cur!] = [i];
        owner[i] = cur!;
        widget.ctx.audio.sfx('tap');
      } else if (owner[i] >= 0) {
        cur = owner[i];
        final p = paths[cur!];
        _cutAfter(p, p.indexOf(i));
      } else {
        cur = null;
      }
    });
  }

  void move(int i) {
    final c = cur;
    if (c == null || solved) return;
    final p = paths[c];
    if (p.isEmpty || i == p.last) return;
    setState(() {
      if (p.length > 1 && i == p[p.length - 2]) {
        owner[p.removeLast()] = -1;
        return;
      }
      if (!_adj(i, p.last) || _done(c)) return;
      if (dots.containsKey(i) && dots[i] != c) return;
      if (owner[i] >= 0 && owner[i] != c) _clearPath(owner[i]);
      if (owner[i] == c) {
        _cutAfter(p, p.indexOf(i));
      } else {
        p.add(i);
        owner[i] = c;
        widget.ctx.audio.sfx('count');
        cellPulse[i] = ++pulse;
      }
      if (_done(c)) {
        widget.ctx.audio.sfx('star');
        for (final j in paths[c]) {
          cellPulse[j] = ++pulse;
        }
        cur = null;
      }
      if (List.generate(paths.length, (k) => k).every(_done)) {
        solved = true;
        final full = owner.every((o) => o >= 0);
        widget.ctx.audio.sfx('win');
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onSolved(10 + (full ? 5 : 0));
        });
      }
    });
  }

  void up() => cur = null;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final size = math.min(math.min(mq.width * .92, mq.height * .7), 600.0);
    final cell = (size - 12) / n;
    int? at(Offset o) {
      final x = ((o.dx - 6) / cell).floor(), y = ((o.dy - 6) / cell).floor();
      if (x < 0 || y < 0 || x >= n || y >= n) return null;
      return y * n + x;
    }

    return Listener(
      key: const Key('flow-grid'),
      onPointerDown: (e) {
        final i = at(e.localPosition);
        if (i != null) down(i);
      },
      onPointerMove: (e) {
        final i = at(e.localPosition);
        if (i != null) move(i);
      },
      onPointerUp: (_) => up(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF343A40),
          borderRadius: BorderRadius.circular(18),
          boxShadow: solved ? const [BoxShadow(color: AppColors.good, spreadRadius: 6)] : null,
        ),
        child: Stack(children: [
          for (var i = 0; i < n * n; i++)
            Positioned(
              left: 6 + (i % n) * cell + 1.5,
              top: 6 + (i ~/ n) * cell + 1.5,
              width: cell - 3,
              height: cell - 3,
              child: _Bounce(
                trigger: cellPulse[i] ?? 0,
                k: 1.08,
                ms: 200,
                child: CustomPaint(painter: _FlowCell(i, n, owner[i], dots[i], paths)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _FlowCell extends CustomPainter {
  _FlowCell(this.i, this.n, this.owner, this.dot, List<List<int>> paths)
      : sig = [for (final (c, p) in paths.indexed) if (p.contains(i)) '$c:${_nbs(p, i)}'].join('|');
  final int i, n, owner;
  final int? dot;
  final String sig;

  static String _nbs(List<int> p, int i) {
    final k = p.indexOf(i);
    return [if (k > 0) p[k - 1], if (k < p.length - 1) p[k + 1]].join(',');
  }

  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(8)), Paint()..color = const Color(0xFF212529));
    if (owner >= 0) c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(8)), Paint()..color = kFlowColors[owner].withValues(alpha: .25));
    for (final part in sig.split('|')) {
      if (part.isEmpty) continue;
      final ci = int.parse(part.split(':')[0]);
      final nbs = part.split(':')[1];
      if (nbs.isEmpty) continue;
      final p = Paint()..color = kFlowColors[ci];
      for (final js in nbs.split(',')) {
        final j = int.parse(js);
        final w = s.width, h = s.height;
        final r = j == i - 1
            ? Rect.fromLTRB(0, h * .36, w * .5, h * .64)
            : j == i + 1
                ? Rect.fromLTRB(w * .5, h * .36, w, h * .64)
                : j < i
                    ? Rect.fromLTRB(w * .36, 0, w * .64, h * .5)
                    : Rect.fromLTRB(w * .36, h * .5, w * .64, h);
        c.drawRect(r, p);
      }
    }
    if (dot != null) {
      final r = s.width * .34;
      c.drawCircle(s.center(Offset.zero), r, Paint()..color = kFlowColors[dot!]);
      c.drawArc(Rect.fromCircle(center: s.center(Offset.zero), radius: r - 2.5), .3, math.pi - .6, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0x33000000));
    }
  }

  @override
  bool shouldRepaint(covariant _FlowCell o) => o.owner != owner || o.sig != sig || o.dot != dot;
}

// =================================================================================================================
// 3. Dẫn nước: xoay ống
// =================================================================================================================

const Map<String, String> _rot = {'u': 'r', 'r': 'd', 'd': 'l', 'l': 'u'};
const Map<String, String> _opp = {'u': 'd', 'd': 'u', 'l': 'r', 'r': 'l'};

class PipeTile {
  PipeTile(this.open, this.path);
  Set<String> open;
  final bool path;
  int rot = 0, need = 0;
}

class PipeLevel {
  PipeLevel(this.n, this.sy, this.ey, this.tiles);
  final int n, sy, ey;
  final List<PipeTile> tiles;
}

/// Sinh đề dẫn nước (pipeLevel()). Ô trên đường: need = số lần xoay để về đúng.
PipeLevel pipeLevel(int lv) {
  final n = lv < 4 ? 4 : (lv < 10 ? 5 : (lv < 22 ? 6 : (lv < 40 ? 7 : 8)));
  for (;;) {
    final sy = rng.nextInt(n), ey = rng.nextInt(n);
    final path = [
      [0, sy]
    ];
    final seen = {'0,$sy'};
    var ok = false;
    for (var steps = 0; steps < 200; steps++) {
      final x = path.last[0], y = path.last[1];
      if (x == n - 1 && y == ey) {
        ok = true;
        break;
      }
      final opts = shuffle(kDirs.values).map((d) => [x + d[0], y + d[1]]).where((p) => p[0] >= 0 && p[1] >= 0 && p[0] < n && p[1] < n && !seen.contains(p.join(','))).toList();
      if (opts.isEmpty) break;
      // Ưu tiên đi sang phải (sort theo x giảm dần, có ngẫu nhiên)
      final right = rng.nextDouble() < .6;
      if (right) opts.sort((p, q) => q[0] - p[0]);
      path.add(opts.first);
      seen.add(opts.first.join(','));
    }
    if (!ok || path.length < n + 1) continue;
    final tiles = List<PipeTile?>.filled(n * n, null);
    for (final (i, p) in path.indexed) {
      final x = p[0], y = p[1];
      final open = <String>{};
      final prev = i == 0 ? [-1, y] : path[i - 1], next = i == path.length - 1 ? [n, y] : path[i + 1];
      for (final q in [prev, next]) {
        open.add(q[0] < x ? 'l' : (q[0] > x ? 'r' : (q[1] < y ? 'u' : 'd')));
      }
      tiles[y * n + x] = PipeTile(open, true);
    }
    const shapes = [
      ['l', 'r'],
      ['u', 'r'],
      ['u', 'r', 'd']
    ];
    for (var i = 0; i < n * n; i++) {
      tiles[i] ??= PipeTile(shapes[rng.nextInt(3)].toSet(), false);
    }
    // Xáo hướng
    for (final t in tiles) {
      t!.rot = 0;
      final k = rng.nextInt(4);
      t.need = (4 - k) % 4;
      for (var r = 0; r < k; r++) {
        t.open = t.open.map((d) => _rot[d]!).toSet();
        t.rot += 90;
      }
    }
    final tl = tiles.cast<PipeTile>();
    if (tl[sy * n].open.contains('l') && tl[ey * n + n - 1].open.contains('r') && pipeFlow(tl, n, sy, ey).reached) continue;
    return PipeLevel(n, sy, ey, tl);
  }
}

/// Nước chảy từ trái (hàng sy) qua các ống thông nhau; reached = tới mép phải hàng ey (flowFrom()).
({Set<int> wet, bool reached}) pipeFlow(List<PipeTile> tiles, int n, int sy, int ey) {
  final wet = <int>{};
  if (!tiles[sy * n].open.contains('l')) return (wet: wet, reached: false);
  final q = [
    [0, sy]
  ];
  wet.add(sy * n);
  while (q.isNotEmpty) {
    final p = q.removeAt(0);
    for (final d in tiles[p[1] * n + p[0]].open) {
      final nx = p[0] + kDirs[d]![0], ny = p[1] + kDirs[d]![1];
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
      final j = ny * n + nx;
      if (wet.contains(j) || !tiles[j].open.contains(_opp[d])) continue;
      wet.add(j);
      q.add([nx, ny]);
    }
  }
  return (wet: wet, reached: wet.contains(ey * n + n - 1) && tiles[ey * n + n - 1].open.contains('r'));
}

class PipesPuzzle extends StatefulWidget {
  const PipesPuzzle({super.key, required this.lv, required this.ctx, required this.onSolved, this.level});
  final int lv;
  final FunGameContext ctx;
  final void Function(int score) onSolved;
  final PipeLevel? level;
  @override
  State<PipesPuzzle> createState() => PipesPuzzleState();
}

class PipesPuzzleState extends State<PipesPuzzle> {
  late final PipeLevel L = widget.level ?? pipeLevel(widget.lv);
  late final int n = L.n;
  // Hình gốc (chưa xoay) để vẽ; xoay bằng góc rot.
  late final List<Set<String>> base = [
    for (final t in L.tiles)
      () {
        var o = {...t.open};
        for (var r = 0; r < (t.rot ~/ 90) % 4; r++) {
          o = o.map((d) => const {'u': 'l', 'r': 'u', 'd': 'r', 'l': 'd'}[d]!).toSet();
        }
        return o;
      }()
  ];
  Set<int> wet = {};
  bool solved = false;
  int moves = 0;
  final Map<int, int> taps = {};

  @override
  void initState() {
    super.initState();
    wet = pipeFlow(L.tiles, n, L.sy, L.ey).wet;
  }

  void tap(int i) {
    if (solved) return;
    final t = L.tiles[i];
    setState(() {
      t.open = t.open.map((d) => _rot[d]!).toSet();
      t.rot += 90;
      moves++;
      taps[i] = (taps[i] ?? 0) + 1;
      final f = pipeFlow(L.tiles, n, L.sy, L.ey);
      wet = f.wet;
      if (f.reached) solved = true;
    });
    widget.ctx.audio.sfx('tap');
    if (solved) {
      widget.ctx.audio.sfx('win');
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) widget.onSolved(math.max(4, 15 - moves ~/ 4));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final width = math.min(math.min(mq.width * .84, mq.height * .66), 560.0);
    final gridSize = width - 92;
    final cell = (gridSize - 16) / n;
    return SizedBox(
      width: width,
      height: gridSize,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 46,
          top: 0,
          width: gridSize,
          height: gridSize,
          child: Container(
            key: const Key('pipe-grid'),
            decoration: BoxDecoration(
              color: const Color(0xFFE9C79A),
              borderRadius: BorderRadius.circular(18),
              boxShadow: solved ? const [BoxShadow(color: Color(0xFF4DABF7), spreadRadius: 6)] : null,
            ),
            child: Stack(children: [
              for (var i = 0; i < n * n; i++)
                Positioned(
                  left: 8 + (i % n) * cell + 2,
                  top: 8 + (i ~/ n) * cell + 2,
                  width: cell - 4,
                  height: cell - 4,
                  child: GestureDetector(
                    key: Key('pipe-$i'),
                    onTap: () => tap(i),
                    child: _Bounce(
                      trigger: solved && wet.contains(i) ? 'w$i' : (taps[i] ?? 0),
                      k: solved && wet.contains(i) ? 1.12 : .9,
                      ms: solved ? 300 : 200,
                      delayMs: solved ? (i % n) * 70 : 0,
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFFFFF4E6), borderRadius: BorderRadius.circular(10)),
                        child: AnimatedRotation(
                          turns: L.tiles[i].rot / 360,
                          duration: const Duration(milliseconds: 200),
                          child: CustomPaint(painter: _PipePainter(base[i], wet.contains(i)), size: Size.square(cell - 4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        Positioned(left: 0, top: (L.sy + .5) / n * gridSize - 24, child: const EmojiImage('Droplet', size: 48, photo: false)),
        Positioned(
          right: -4,
          top: (L.ey + .5) / n * gridSize - 28,
          child: solved ? RiseIn(index: 0, child: const EmojiImage('Sunflower', size: 56, photo: false)) : const EmojiImage('Seedling', size: 56, photo: false),
        ),
      ]),
    );
  }
}

class _PipePainter extends CustomPainter {
  _PipePainter(this.open, this.wet);
  final Set<String> open;
  final bool wet;
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 100;
    final path = Path();
    const arms = {'u': Offset(50, 0), 'r': Offset(100, 50), 'd': Offset(50, 100), 'l': Offset(0, 50)};
    for (final d in arms.keys) {
      if (!open.contains(d)) continue;
      path
        ..moveTo(50 * k, 50 * k)
        ..lineTo(arms[d]!.dx * k, arms[d]!.dy * k);
    }
    c.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 34 * k
      ..color = const Color(0xFF868E96));
    c.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18 * k
      ..color = wet ? const Color(0xFF4DABF7) : const Color(0xFFE9ECEF));
    c.drawCircle(Offset(50 * k, 50 * k), 15 * k, Paint()..color = wet ? const Color(0xFF1C7ED6) : const Color(0xFF868E96));
  }

  @override
  bool shouldRepaint(covariant _PipePainter o) => o.wet != wet || o.open != open;
}

// =================================================================================================================
// 4. Bảng số thần tốc
// =================================================================================================================

class SchultePuzzle extends StatefulWidget {
  const SchultePuzzle({super.key, required this.lv, required this.ctx, required this.onSolved});
  final int lv;
  final FunGameContext ctx;
  final void Function(int score) onSolved;
  @override
  State<SchultePuzzle> createState() => SchultePuzzleState();
}

class SchultePuzzleState extends State<SchultePuzzle> {
  static const colors = [Color(0xFFFF8787), Color(0xFF74C0FC), Color(0xFF8CE99A), Color(0xFFFFD43B), Color(0xFFB197FC), Color(0xFFFFA94D)];
  late final int n = widget.lv < 3 ? 3 : (widget.lv < 10 ? 4 : (widget.lv < 30 ? 5 : 6));
  late final int total = n * n;
  late final bool down = widget.lv >= 8 && widget.lv % 3 == 2;
  late final List<int> nums = shuffle(List.generate(total, (i) => i + 1));
  late int next = down ? total : 1;
  int mistakes = 0, found = 0, tenths = 0;
  final hit = <int>{};
  final shake = <int, int>{};
  Timer? _timer;
  bool done = false;

  /// Số cần tìm (cho kiểm thử).
  int get target => next;

  @override
  void initState() {
    super.initState();
    _sayNum(next);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && !done) setState(() => tenths++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sayNum(int v) {
    final c = widget.ctx.content, a = widget.ctx.audio;
    final cal = c.list('calNums'), n100 = c.list('nums100');
    if (v - 1 < cal.length) {
      a.say(a.tpl('numBig', cal[v - 1]));
    } else if (v < n100.length) {
      a.say(a.tpl('n100', n100[v]));
    }
  }

  void tap(int v) {
    if (done || hit.contains(v)) return;
    final a = widget.ctx.audio;
    if (v != next) {
      mistakes++;
      a.sfx('wrong');
      setState(() => shake[v] = (shake[v] ?? 0) + 1);
      return;
    }
    a.sfx('count');
    setState(() {
      hit.add(v);
      next += down ? -1 : 1;
      found++;
    });
    if (found >= total) {
      done = true;
      _timer?.cancel();
      final sec = tenths / 10;
      a.sfx('win');
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onSolved(math.max(5, (total * 2 - sec - mistakes * 2).round()));
      });
      return;
    }
    _sayNum(next);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final fs = baseFontSize(context);
    final size = math.min(math.min(mq.width * .92, mq.height * .66), 560.0);
    final cell = (size - (n - 1) * 8) / n;
    final en = widget.ctx.i18n.isEn;
    return Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
      Row(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: down ? (en ? 'Count down! Find ' : 'Đếm ngược! Tìm số ') : (en ? 'Find ' : 'Tìm số ')),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _Bounce(
                trigger: next,
                k: 1.4,
                ms: 260,
                child: Container(
                  key: const Key('schulte-next'),
                  constraints: BoxConstraints(minWidth: fs * 1.4 * 1.6),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(12)),
                  child: Text('$next', textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
          style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        Text('${(tenths / 10).toStringAsFixed(1)}s', style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w800, color: AppColors.inkSoft, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      SizedBox.square(
        dimension: size,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in nums)
            _ShakeX(
              trigger: shake[v] ?? 0,
              child: GestureDetector(
                key: Key('sgc-$v'),
                onTap: () => tap(v),
                child: AnimatedScale(
                  scale: hit.contains(v) ? .9 : 1,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: hit.contains(v) ? .25 : 1,
                    duration: const Duration(milliseconds: 280),
                    child: Container(
                      width: cell,
                      height: cell,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors[v % colors.length],
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [BoxShadow(color: Color(0x26000000), offset: Offset(0, -6), spreadRadius: -3, blurStyle: BlurStyle.inner)],
                      ),
                      child: Text('$v',
                          style: TextStyle(
                              fontSize: (cell * .42).clamp(22.0, 52.0),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 2))])),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Lắc ngang khi chạm sai (.shake).
class _ShakeX extends StatelessWidget {
  const _ShakeX({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, child) => Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * 8 * (1 - v), 0), child: child),
      child: child,
    );
  }
}
