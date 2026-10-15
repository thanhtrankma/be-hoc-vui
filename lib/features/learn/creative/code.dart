// Đảo Lập trình (đợt 16): bé xếp thẻ lệnh cho robot làm vườn đi tưới mầm cây — port games/code.js.
// Lõi sinh đề/chạy thử/BFS ở code_engine.dart; file này là giao diện: bàn cờ vườn, khung soạn chương trình, diễn hoạt.
// CHỦ: agent C. Giữ nguyên tên công khai codeModule (registry trỏ tới).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'code_engine.dart';
import 'common.dart';
import 'figure.dart';

final GameModule codeModule = CodeGame();

const int _kPuzzles = 3, _kTraceQ = 5;

class CodeGame extends GameModule {
  @override
  String get id => 'code';
  @override
  Widget build(BuildContext context, GameContext ctx) => CodeView(ctx: ctx);
}

// ---------- Thẻ lệnh: hình SVG (bé chưa biết đọc), chạm thì đọc tên ----------
String _arrow(String c) => '<path d="M24 5 41 23H30v19H18V23H7z" fill="$c" stroke="#fff" stroke-width="2.5" stroke-linejoin="round"/>';
const String _turn =
    '<path d="M33 42V27a10 10 0 0 0-10-10h-5" fill="none" stroke="#f76707" stroke-width="7.5" stroke-linecap="round"/><path d="M20 5 5 17l15 12z" fill="#f76707"/>';
final Map<String, String> _svg = {
  'U': _arrow('#339af0'),
  'R': '<g transform="rotate(90 24 24)">${_arrow('#339af0')}</g>',
  'D': '<g transform="rotate(180 24 24)">${_arrow('#339af0')}</g>',
  'L': '<g transform="rotate(-90 24 24)">${_arrow('#339af0')}</g>',
  'F': _arrow('#2f9e44'),
  'TL': _turn,
  'TR': '<g transform="matrix(-1 0 0 1 48 0)">$_turn</g>',
  'J':
      '<rect x="17" y="35" width="14" height="9" rx="3" fill="#a0522d"/><path d="M7 40Q24 0 39 34" fill="none" stroke="#7048e8" stroke-width="6" stroke-linecap="round"/><path d="M31 31l13-1-4 12z" fill="#7048e8"/>',
  'REP':
      '<path d="M10 26a14 14 0 0 1 24-12" fill="none" stroke="#e64980" stroke-width="6" stroke-linecap="round"/><path d="M38 6v13H25z" fill="#e64980"/><path d="M38 22a14 14 0 0 1-24 12" fill="none" stroke="#e64980" stroke-width="6" stroke-linecap="round"/><path d="M10 42V29h13z" fill="#e64980"/>',
};
const Map<String, String> _say = {
  'U': 'cmdU', 'R': 'cmdR', 'D': 'cmdD', 'L': 'cmdL', 'F': 'cmdF', 'TL': 'cmdTL', 'TR': 'cmdTR', 'J': 'cmdJ', 'W': 'cmdW', 'REP': 'cmdREP', //
};

/// Biểu tượng thẻ lệnh c.
Widget cmdIcon(String c) => c == 'W'
    ? const EmojiImage('Droplet', photo: false)
    : SvgPicture.string('<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">${_svg[c] ?? ''}</svg>');

/// Robot làm vườn (BOT áo xanh).
final Costume _gardenBot = kBot.copyWith(shirt: const Color(0xFF339AF0), pants: const Color(0xFF1971C2));

// ---------- Màn chơi ----------
class CodeView extends StatefulWidget {
  const CodeView({super.key, required this.ctx});
  final GameContext ctx;

  /// Đề đang hiện (để test tự động giải, như g.stage.dataset.sol của web).
  @visibleForTesting
  static Garden? debugPuzzle;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  GameContext get g => widget.ctx;
  Json get lv => g.level ?? const {};
  String get kind => asStr(lv['kind'], 'garden');
  bool get isTrace => kind == 'trace';
  bool get fix => kind == 'debug';

  Garden? M;
  int puzzleNo = 0; // đổi để dựng lại bàn cờ
  // --- bàn cờ ---
  late int bx, by, bdir;
  double ang = 0;
  final FigureController fig = FigureController();
  int hopN = 0, bumpN = 0;
  double hopAmt = 0;
  (int, int) bumpDir = (0, 0);
  final Set<int> wet = {};
  final Map<int, int> drops = {}; // ô → lần rơi
  List<String> flowers = [];
  bool win = false;
  (int, int)? guess, okCell, noCell;
  // --- khung soạn ---
  List<Object> prog = [];
  int target = -1;
  String? sel, hlAt, hintAt, popAt;
  int? hlR;
  bool locked = false, busy = false;
  int progShake = 0, meterShake = 0;
  Completer<int?>? _puzzleDone;
  Completer<(int, int)?>? _tap;

  @override
  void initState() {
    super.initState();
    preloadFigures();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.hideBuddy();
      isTrace ? _runTrace() : _runPuzzles();
    });
  }

  @override
  void dispose() {
    fig.dispose();
    CodeView.debugPuzzle = null;
    if (_puzzleDone?.isCompleted == false) _puzzleDone!.complete(null);
    if (_tap?.isCompleted == false) _tap!.complete(null);
    super.dispose();
  }

  bool get _gone => !mounted || g.aborted;

  void _show(Garden m, List<Object> p) {
    setState(() {
      M = m;
      CodeView.debugPuzzle = m;
      puzzleNo++;
      prog = p;
      target = -1;
      sel = hlAt = hintAt = popAt = null;
      hlR = null;
      locked = busy = false;
      win = false;
      guess = okCell = noCell = null;
      flowers = [for (final _ in m.sprouts) pick(kFlowers)];
      _reset();
    });
  }

  // ---------- Bàn cờ ----------
  void _place(int x, int y, int dir, [double hop = 0]) {
    if (x != bx) {
      fig.face = x > bx ? 1 : -1;
      fig.run(.35);
    } else if (dir == 1 || dir == 3) {
      fig.face = dir == 1 ? 1 : -1;
    }
    // Góc mũi tên hướng cộng dồn để quay đường ngắn nhất (270° → 0° không xoay ngược cả vòng)
    ang += (((dir * 90 - ang) % 360) + 540) % 360 - 180;
    bx = x;
    by = y;
    bdir = dir;
    if (hop > 0) {
      hopAmt = hop;
      hopN++;
    }
  }

  void _reset() {
    final m = M!;
    wet.clear();
    win = false;
    fig.pose = 'idle';
    bx = m.start.$1;
    by = m.start.$2;
    bdir = m.dir;
    ang = (m.dir * 90).toDouble();
    if (m.dir == 1 || m.dir == 3) fig.face = m.dir == 1 ? 1 : -1;
  }

  void _drop(int x, int y) {
    final k = y * M!.n + x;
    setState(() => drops[k] = (drops[k] ?? 0) + 1);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => drops.remove(k));
    });
  }

  /// Diễn hoạt một lượt chạy. Trả về kết quả simulate (null nếu bé thoát).
  Future<SimResult?> _play(List<Object> p) async {
    final m = M!;
    setState(_reset);
    await wait(250);
    final res = simulate(m, p);
    for (final e in res.ev) {
      if (_gone) return null;
      setState(() {
        hlAt = e.step.at;
        hlR = e.step.r;
      });
      if (e.kind == 'bump') {
        setState(() {
          bumpDir = kDirs[e.dir];
          bumpN++;
        });
        g.audio.sfx('wrong');
        await wait(550);
        break;
      }
      setState(() {
        switch (e.kind) {
          case 'move':
            _place(e.x, e.y, e.dir, 18);
            g.audio.sfx('jump');
          case 'jump':
            _place(e.x, e.y, e.dir, 70);
            g.audio.sfx('power');
          case 'turn':
            _place(e.x, e.y, e.dir);
            g.audio.sfx('tap');
        }
      });
      if (e.kind == 'water') {
        _drop(e.x, e.y);
        if (e.k >= 0) {
          g.audio.sfx('coin');
          final k = e.k;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => wet.add(k));
          });
        } else {
          g.audio.sfx('pop');
        }
      }
      await wait(e.kind == 'jump' ? 560 : 440);
    }
    if (_gone) return null;
    setState(() {
      hlAt = null;
      hlR = null;
    });
    return res;
  }

  // ---------- Câu đố xếp lệnh (garden / loop / debug) ----------
  Future<void> _runPuzzles() async {
    var fails = 0;
    final gen = kind == 'loop' ? genLoop : kind == 'debug' ? genDebug : genGarden;
    for (var i = 0; i < _kPuzzles; i++) {
      if (_gone) return;
      g.progress(i, _kPuzzles);
      final m = gen(lv);
      if (m == null) {
        debugPrint('Không sinh được đề $lv');
        continue;
      }
      if (i == 0) {
        g.audio.sayPhrase(lv['say']?.toString() ?? (kind == 'loop' ? 'codeLoopQ' : kind == 'debug' ? 'codeDebugQ' : 'codeGardenQ'));
      }
      _show(m, fix ? cloneProg(m.prog!) : (lv['hint'] == true ? [Rep(2)] : []));
      _puzzleDone = Completer();
      final f = await _puzzleDone!.future;
      if (f == null || _gone) return;
      fails += f;
    }
    g.progress(_kPuzzles, _kPuzzles);
    g.finish(fails <= 1 ? 3 : fails <= 4 ? 2 : 1);
  }

  int _fails = 0;

  Future<void> _run() async {
    if (busy || g.aborted || M == null) return;
    if (progCost(prog) == 0) {
      setState(() => progShake++);
      g.audio.sfx('pop');
      return;
    }
    setState(() {
      busy = true;
      locked = true;
    });
    final res = await _play(prog);
    if (res == null) {
      _complete(null);
      return;
    }
    if (res.win) {
      g.cheer();
      g.audio.sfx('correct');
      setState(() {
        win = true;
        fig.pose = 'cheer';
      });
      await wait(1100);
      final f = _fails;
      _fails = 0;
      _complete(f);
      return;
    }
    _fails++;
    g.sad();
    await g.audio.sayPhrase(res.bump ? 'codeBump' : 'codeMissed');
    if (_gone) return;
    if (fix && _fails >= 2) {
      setState(() => hintAt = M!.wrong);
      g.audio.sayPhrase('codeDebugHint');
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) setState(() => hintAt = null);
      });
    }
    setState(() {
      _reset();
      busy = false;
      locked = false;
    });
  }

  void _complete(int? f) {
    final c = _puzzleDone;
    if (c != null && !c.isCompleted) c.complete(f);
  }

  // ---------- Đoán robot dừng ở đâu ----------
  Future<void> _runTrace() async {
    var mistakes = 0;
    for (var q = 0; q < _kTraceQ; q++) {
      if (_gone) return;
      g.progress(q, _kTraceQ);
      final m = genTrace(lv);
      if (m == null) continue;
      _show(m, m.prog!);
      if (q == 0) g.audio.sayPhrase('codeTraceQ');
      _tap = Completer();
      final tap = await _tap!.future;
      if (tap == null || _gone) return;
      setState(() => guess = tap);
      g.audio.sfx('tap');
      final r = await _play(m.prog!);
      if (r == null) return;
      final ok = tap == m.end;
      if (ok) {
        g.audio.sfx('correct');
        g.cheer();
        setState(() {
          win = true;
          fig.pose = 'cheer';
          okCell = tap;
        });
        await wait(1100);
      } else {
        mistakes++;
        g.audio.sfx('wrong');
        g.sad();
        setState(() {
          noCell = tap;
          okCell = m.end;
        });
        await g.audio.sayPhrase('codeTraceWrong');
        await wait(600);
      }
    }
    if (_gone) return;
    g.progress(_kTraceQ, _kTraceQ);
    g.finish(mistakes == 0 ? 3 : mistakes <= 2 ? 2 : 1);
  }

  void _tapCell(int x, int y) {
    final c = _tap;
    if (c != null && !c.isCompleted && !g.aborted) c.complete((x, y));
  }

  // ---------- Khung soạn chương trình ----------
  String get mode => isTrace ? 'view' : fix ? 'fix' : 'edit';

  Object _getAt(String at) {
    final p = at.split('.').map(int.parse).toList();
    return p.length == 1 ? prog[p[0]] : (prog[p[0]] as Rep).body[p[1]];
  }

  void _tapAtom(String at) {
    if (locked || mode == 'view') return;
    final p = at.split('.').map(int.parse).toList();
    if (mode == 'fix') {
      setState(() => sel = sel == at ? null : at);
      g.audio.sfx('tap');
      return;
    }
    setState(() {
      if (p.length == 1) {
        final i = p[0];
        prog.removeAt(i);
        if (target > i) {
          target--;
        } else if (target == i) {
          target = -1;
        }
      } else {
        (prog[p[0]] as Rep).body.removeAt(p[1]);
      }
    });
    g.audio.sfx('pop');
  }

  void _tapChip(int i) {
    if (locked || mode == 'view') return;
    final b = prog[i] as Rep;
    setState(() => b.rep = b.rep >= 6 ? 2 : b.rep + 1);
    g.audio.sfx('tap');
    g.audio.sayPhrase('codeRep${b.rep}');
  }

  void _tapHead(int i) {
    if (locked || mode != 'edit') return;
    setState(() => target = target == i ? -1 : i);
    g.audio.sfx('tap');
  }

  void _kill(int i) {
    if (locked) return;
    setState(() {
      prog.removeAt(i);
      target = -1;
    });
    g.audio.sfx('pop');
  }

  void _tapPad(String c) {
    if (locked) return;
    g.audio.sayPhrase(_say[c]!);
    if (mode == 'fix') {
      final s = sel;
      if (s == null || _getAt(s) is Rep || c == 'REP') {
        setState(() => progShake++);
        g.audio.sfx('pop');
        return;
      }
      final p = s.split('.').map(int.parse).toList();
      setState(() {
        if (p.length == 1) {
          prog[p[0]] = c;
        } else {
          (prog[p[0]] as Rep).body[p[1]] = c;
        }
        popAt = s;
      });
      g.audio.sfx('tap');
      return;
    }
    if (progCost(prog) >= M!.cap) {
      setState(() => meterShake++);
      g.audio.sfx('wrong');
      g.audio.sayPhrase('codeFull');
      return;
    }
    setState(() {
      if (c == 'REP') {
        prog.add(Rep(2));
        target = prog.length - 1;
        popAt = '$target';
      } else if (target >= 0 && target < prog.length && prog[target] is Rep) {
        final b = prog[target] as Rep;
        b.body.add(c);
        popAt = '$target.${b.body.length - 1}';
      } else {
        prog.add(c);
        popAt = '${prog.length - 1}';
      }
    });
    g.audio.sfx('tap');
  }

  void _clear() {
    if (busy) return;
    setState(() {
      prog.clear();
      target = -1;
      sel = null;
    });
    g.audio.sfx('pop');
  }

  // ---------- Giao diện ----------
  @override
  Widget build(BuildContext context) {
    final m = M;
    if (m == null) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      final wide = c.maxWidth > c.maxHeight * 1.1;
      final boardSide = wide ? math.min(math.min(c.maxHeight - 8, c.maxWidth * .52), 520.0) : math.min(math.min(c.maxWidth * .94, c.maxHeight * (isTrace ? .62 : .42)), 520.0);
      final side = _side(narrow, isTrace);
      final board = KeyedSubtree(key: ValueKey('board-$puzzleNo'), child: _board(m, boardSide));
      if (wide) {
        return Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 20, children: [
          board,
          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 8), child: side))),
        ]);
      }
      return Column(children: [
        board,
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 12), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: side)))),
      ]);
    });
  }

  Widget _board(Garden m, double side) {
    final n = m.n;
    const pad = 6.0, gap = 4.0;
    final cell = (side - pad * 2 - gap * (n - 1)) / n;
    final step = cell + gap;
    final rel = !m.cmds.contains('U');
    Widget cellAt(int x, int y) {
      final i = y * n + x;
      final si = m.sprouts.indexWhere((s) => s.$1 == x && s.$2 == y);
      final isGuess = guess == (x, y), isOk = okCell == (x, y), isNo = noCell == (x, y);
      final bg = isOk
          ? const Color(0xFFB2F2BB)
          : isNo
              ? const Color(0xFFFFE3E3)
              : isGuess
                  ? const Color(0xFFFFF3BF)
                  : (x + y) % 2 == 1
                      ? const Color(0xFFC3F0CA)
                      : const Color(0xFFD3F9D8);
      final ring = isOk
          ? const Color(0xFF2F9E44)
          : isNo
              ? const Color(0xFFFA5252)
              : isGuess
                  ? const Color(0xFFFAB005)
                  : null;
      return GestureDetector(
        key: Key('cd-cell-$x-$y'),
        behavior: HitTestBehavior.opaque,
        onTapDown: isTrace ? (_) => _tapCell(x, y) : null,
        child: Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: ring == null ? null : Border.all(color: ring, width: 4)),
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            if (x == m.start.$1 && y == m.start.$2)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(cell * .14),
                  child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF40C057), width: 3))),
                ),
              ),
            if (m.rocks.contains(i)) EmojiImage('Rock', size: cell * .74, photo: false),
            if (m.logs.contains(i)) Transform.rotate(angle: -12 * math.pi / 180, child: EmojiImage('Wood', size: cell * .92, photo: false)),
            if (si >= 0)
              wet.contains(si)
                  ? PopIn(key: ValueKey('fl-$si'), child: EmojiImage(flowers[si], size: cell * .74, photo: false))
                  : Bob(amplitude: 3, period: const Duration(seconds: 2), child: EmojiImage('Seedling', size: cell * .74, photo: false)),
            if (drops.containsKey(i))
              Positioned(
                top: cell * .04,
                child: _Anim(
                  key: ValueKey('drop-$i-${drops[i]}'),
                  ms: 420,
                  builder: (t, child) => Opacity(
                    opacity: t < .6 ? t / .6 : 1 - (t - .6) / .4,
                    child: Transform.translate(offset: Offset(0, cell * .46 * (t < .6 ? -.8 + .8 * t / .6 : .2 * (t - .6) / .4)), child: Transform.scale(scale: t < .6 ? 1 : 1 - .6 * (t - .6) / .4, child: child)),
                  ),
                  child: EmojiImage('Droplet', size: cell * .46, photo: false),
                ),
              ),
          ]),
        ),
      );
    }

    final bot = SizedBox.square(
      dimension: cell,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: _Anim(
            key: ValueKey('bump-$bumpN'),
            ms: bumpN == 0 ? 0 : 400,
            builder: (t, child) {
              final k = t < .3 ? t / .3 : 1 - (t - .3) / .7;
              return Transform.translate(offset: Offset(bumpDir.$1 * cell * .2 * k, bumpDir.$2 * cell * .2 * k), child: child);
            },
            child: _Anim(
              key: ValueKey('hop-$hopN'),
              ms: hopN == 0 ? 0 : 380,
              builder: (t, child) {
                final k = t < .45 ? t / .45 : 1 - (t - .45) / .55;
                return Transform.translate(offset: Offset(0, -cell * hopAmt / 100 * k), child: child);
              },
              child: FigureView(costume: _gardenBot, size: cell, controller: fig),
            ),
          ),
        ),
        if (rel)
          Positioned(
            left: -cell * .06,
            top: -cell * .06,
            width: cell * 1.12,
            height: cell * 1.12,
            child: AnimatedRotation(
              turns: ang / 360,
              duration: Duration(milliseconds: Motion.enabled ? 300 : 0),
              child: const CustomPaint(painter: _HeadPainter()),
            ),
          ),
      ]),
    );

    return Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(color: const Color(0xFF8CE99A), borderRadius: BorderRadius.circular(22), boxShadow: solidShadow(const Color(0xFF69DB7C))),
      child: Stack(clipBehavior: Clip.none, children: [
        for (var y = 0; y < n; y++)
          for (var x = 0; x < n; x++) Positioned(left: x * step, top: y * step, child: cellAt(x, y)),
        AnimatedPositioned(
          key: const Key('cd-bot'),
          duration: Duration(milliseconds: Motion.enabled ? 350 : 0),
          left: bx * step,
          top: by * step,
          child: IgnorePointer(
            child: win && Motion.enabled
                ? Hop(height: cell * .25, period: const Duration(milliseconds: 700), child: bot)
                : bot,
          ),
        ),
      ]),
    );
  }

  Widget _side(bool narrow, bool trace) {
    final m = M!;
    final cardS = narrow ? 46.0 : 56.0, bodyS = narrow ? 40.0 : 48.0, padS = narrow ? 58.0 : 72.0;
    final progBox = Shake(
      trigger: progShake,
      child: Container(
        key: const Key('cd-prog'),
        constraints: BoxConstraints(minHeight: narrow ? 54 : 64),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: solidShadow(AppColors.line, 5)),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 10, children: [
          for (var i = 0; i < prog.length; i++)
            if (prog[i] is Rep) _block(i, prog[i] as Rep, bodyS) else _atom(prog[i] as String, '$i', cardS),
          if (mode == 'edit' && target < 0) const _Caret(),
        ]),
      ),
    );
    if (trace) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
        const Bob(amplitude: 6, period: Duration(milliseconds: 1600), child: Text('❓', style: TextStyle(fontSize: 40, height: 1))),
        progBox,
      ]);
    }
    final used = progCost(prog);
    return Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
      if (!fix)
        Shake(
          trigger: meterShake,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Wrap(key: const Key('cd-meter'), alignment: WrapAlignment.center, spacing: 5, runSpacing: 5, children: [
              for (var k = 0; k < m.cap; k++)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: k < used ? const Color(0xFF40C057) : Colors.white,
                    border: k < used ? null : Border.all(color: const Color(0xFFCED4DA), width: 2),
                  ),
                ),
            ]),
          ),
        ),
      progBox,
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        for (final c in m.cmds.where((c) => mode == 'edit' || c != 'REP'))
          SizedBox.square(
            dimension: padS,
            child: Chunky(
              key: Key('cd-pad-$c'),
              onTap: () => _tapPad(c),
              radius: 22,
              color: c == 'REP' ? const Color(0xFFFFF0F6) : Colors.white,
              padding: EdgeInsets.all(padS * .125),
              semanticLabel: g.audio.phrase(_say[c]!).text,
              child: cmdIcon(c),
            ),
          ),
      ]),
      Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
        if (!fix)
          AppButton(
            key: const Key('cd-clear'),
            label: '↺',
            variant: BtnVariant.ghost,
            minWidth: 84,
            fontSize: 26,
            onTap: _clear,
          ),
        AppButton(key: const Key('cd-run'), label: '▶', variant: BtnVariant.green, minWidth: 84, fontSize: 26, enabled: !busy, onTap: busy ? null : _run),
      ]),
    ]);
  }

  Widget _atom(String c, String at, double s) {
    final run = hlAt == at, isSel = sel == at, hint = hintAt == at;
    Widget card = AnimatedScale(
      scale: run ? 1.14 : isSel ? 1.1 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: s,
        height: s,
        padding: EdgeInsets.all(s * .1),
        decoration: BoxDecoration(
          color: run ? const Color(0xFFFFF3BF) : isSel ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: run ? const Color(0xFFFAB005) : isSel || hint ? const Color(0xFFFA5252) : const Color(0xFFDEE2E6), width: 3),
        ),
        child: cmdIcon(c),
      ),
    );
    if (hint) card = _Wiggle(child: card);
    if (popAt == at) card = PopIn(key: ValueKey('pop-$at-${prog.length}'), child: card);
    return GestureDetector(key: Key('cd-at-$at'), onTap: () => _tapAtom(at), child: card);
  }

  Widget _block(int i, Rep b, double bodyS) {
    final tgt = mode == 'edit' && target == i;
    final running = hlAt != null && hlAt!.startsWith('$i.') && hlR != null;
    final chipText = running ? '${hlR! + 1}/${b.rep}' : '×${b.rep}';
    Widget block = Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: running ? const Color(0xFFFFDEEB) : const Color(0xFFFFF0F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tgt ? const Color(0xFFE64980) : const Color(0xFFF783AC), width: 3),
        boxShadow: tgt ? const [BoxShadow(color: Color(0xFFFCC2D7), spreadRadius: 4)] : null,
      ),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
        GestureDetector(
          key: Key('cd-bhead-$i'),
          onTap: () => _tapHead(i),
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: cmdIcon('REP'),
          ),
        ),
        GestureDetector(
          key: Key('cd-chip-$i'),
          onTap: () => _tapChip(i),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFE64980), borderRadius: BorderRadius.circular(20)),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(chipText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, height: 1.9)),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
            for (var j = 0; j < b.body.length; j++) _atom(b.body[j], '$i.$j', bodyS),
            if (tgt) const _Caret(),
          ]),
        ),
      ]),
    );
    if (hintAt == '$i') block = _Wiggle(child: block);
    return Stack(clipBehavior: Clip.none, children: [
      block,
      if (mode == 'edit')
        Positioned(
          right: -12,
          top: -12,
          child: GestureDetector(
            key: Key('cd-kill-$i'),
            onTap: () => _kill(i),
            child: Semantics(
              button: true,
              label: g.i18n.t('remove'),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFFA5252), shape: BoxShape.circle),
                child: const Text('✕', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Mũi tên hướng robot (chế độ "đi tới / quay"): tam giác xanh ở mép trên, xoay theo hướng.
class _HeadPainter extends CustomPainter {
  const _HeadPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 9, 13)
      ..lineTo(size.width / 2 - 9, 13)
      ..close();
    canvas.drawPath(p.shift(const Offset(0, 1)), Paint()..color = Colors.white);
    canvas.drawPath(p, Paint()..color = const Color(0xFF2F9E44));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Con trỏ nhập (vạch xanh).
class _Caret extends StatelessWidget {
  const _Caret();
  @override
  Widget build(BuildContext context) => Container(width: 4, height: 44, decoration: BoxDecoration(color: const Color(0xFF4DABF7), borderRadius: BorderRadius.circular(2)));
}

/// Hoạt ảnh chạy một lần t: 0→1 trong ms (Motion tắt hoặc ms = 0 → t = 1 ngay).
class _Anim extends StatelessWidget {
  const _Anim({super.key, required this.ms, required this.builder, required this.child});
  final int ms;
  final Widget Function(double t, Widget child) builder;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!Motion.enabled || ms == 0) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      child: child,
      builder: (context, t, child) => builder(t, child!),
    );
  }
}

/// Lắc qua lại (gợi ý thẻ sai).
class _Wiggle extends StatelessWidget {
  const _Wiggle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LoopAnim(
        period: const Duration(milliseconds: 400),
        child: child,
        builder: (context, t, child) => Transform.rotate(angle: math.sin(t * math.pi * 2) * .12, child: child),
      );
}
