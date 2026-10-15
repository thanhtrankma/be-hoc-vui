// Đảo Tư duy: ghép bóng, quy luật, tìm hình khác nhóm, mê cung, sudoku hình 4×4, ghép tranh, sắp xếp trình tự,
// tìm điểm khác — port games/logic.js.
// CHỦ: agent C. Giữ nguyên tên công khai logicModule (registry trỏ tới).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/models.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'art.dart';
import 'common.dart';

final GameModule logicModule = LogicGame();

const int _kRound = 6;

class LogicGame extends GameModule {
  @override
  String get id => 'logic';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final lv = ctx.level ?? const {};
    return switch (lv['kind']) {
      'maze' => MazeView(ctx: ctx, size: asInt(lv['size'], 5)),
      'sudoku' => SudokuView(ctx: ctx, blanks: asInt(lv['blanks'], 4)),
      'jigsaw' => JigsawView(ctx: ctx, page: asStr(lv['page'], 'house'), cols: asInt(lv['pieces'], 2), rows: asInt(lv['rows'] ?? lv['pieces'], 2)),
      'seq' => SeqView(ctx: ctx, sets: (lv['sets'] as List? ?? const []).map((e) => e.toString()).toList()),
      'spot' => SpotView(ctx: ctx, page: asStr(lv['page'], 'fish'), diffs: asInt(lv['diffs'], 3)),
      _ => _LogicQuiz(ctx: ctx),
    };
  }
}

// ---------- Ghép bóng / Quy luật / Khác nhóm (khuôn quiz) ----------
List<List<String>> _cats(GameContext g) =>
    g.content.map('categories').values.whereType<List>().map((l) => l.map((e) => e.toString()).toList()).toList();

VoiceLine _praise(GameContext g) => g.audio.phrase('praise${1 + rng.nextInt(6)}');

Widget _img(String name, {bool photo = true, double size = 200}) => EmojiImage(name, size: size, photo: photo);

/// Dữ liệu một câu (tách khỏi widget để test).
class LogicQ {
  LogicQ({required this.kind, required this.choices, required this.answer, this.seq = const []});
  final String kind;
  final List<String> choices;
  final String answer;
  final List<String> seq; // pattern: dãy đã hiện
}

List<LogicQ> makeLogicQuestions(String kind, Json lv, List<List<String>> cats) {
  switch (kind) {
    case 'shadow':
      return List.generate(_kRound, (_) {
        final cat = pick(cats);
        final opts = sample(cat, asInt(lv['choices'], 3));
        return LogicQ(kind: kind, choices: shuffle(opts), answer: opts[0]);
      });
    case 'pattern':
      final pats = (lv['patterns'] as List? ?? const ['AB']).map((e) => e.toString()).toList();
      return List.generate(_kRound, (_) {
        final pat = pick(pats);
        final letters = pat.split('').toSet().toList();
        final pool = sample(cats.expand((c) => c).toSet(), letters.length + 1);
        final map = {for (var i = 0; i < letters.length; i++) letters[i]: pool[i]};
        final len = pat.length;
        final shown = len * 2 + rng.nextInt(len);
        final seq = List.generate(shown + 1, (i) => map[pat[i % len]]!);
        final ans = seq[shown];
        final choices = shuffle({ans, ...map.values, pool[letters.length]}).take(3).toList();
        if (!choices.contains(ans)) choices[0] = ans;
        return LogicQ(kind: kind, choices: shuffle(choices), answer: ans, seq: seq.sublist(0, shown));
      });
    default: // odd
      return List.generate(_kRound, (_) {
        final ab = sample(cats, 2);
        final same = sample(ab[0], asInt(lv['choices'], 4) - 1), diff = sample(ab[1], 1)[0];
        return LogicQ(kind: 'odd', choices: shuffle([...same, diff]), answer: diff);
      });
  }
}

class _LogicQuiz extends StatefulWidget {
  const _LogicQuiz({required this.ctx});
  final GameContext ctx;
  @override
  State<_LogicQuiz> createState() => _LogicQuizState();
}

class _LogicQuizState extends State<_LogicQuiz> {
  late final List<LogicQ> qs = makeLogicQuestions(asStr(widget.ctx.level?['kind'], 'odd'), widget.ctx.level ?? const {}, _cats(widget.ctx));

  @override
  Widget build(BuildContext context) {
    final g = widget.ctx;
    final questions = [
      for (final q in qs) _toQuiz(context, g, q),
    ];
    return QuizView(ctx: g, questions: questions, onDone: g.finish);
  }

  QuizQuestion _toQuiz(BuildContext context, GameContext g, LogicQ q) {
    switch (q.kind) {
      case 'shadow':
        return QuizQuestion(
          say: g.audio.phrase('shadowQ'),
          stage: (context) {
            final s = vwClamp(context, 120, 24, 230).clamp(math.min(80.0, MediaQuery.sizeOf(context).height * .28), MediaQuery.sizeOf(context).height * .28).toDouble();
            return EmojiImage(q.answer, size: s, photo: false, color: Colors.black.withValues(alpha: .78), colorBlendMode: BlendMode.srcIn);
          },
          choices: [for (final x in q.choices) QuizChoice(id: x, node: (_) => _img(x, photo: false))],
          answer: q.answer,
          reward: _praise(g),
          rewardNode: (_) => _img(q.answer, photo: false, size: 160),
        );
      case 'pattern':
        final photo = usePhotos(context, [...q.seq, ...q.choices]);
        return QuizQuestion(
          say: g.audio.phrase('patternQ'),
          stage: (context) => _PatternRow(seq: q.seq, photo: photo),
          choices: [for (final x in q.choices) QuizChoice(id: x, node: (_) => _img(x, photo: photo))],
          answer: q.answer,
          reward: _praise(g),
          rewardNode: (_) => _img(q.answer, photo: photo, size: 160),
        );
      default:
        final photo = usePhotos(context, q.choices);
        return QuizQuestion(
          say: g.audio.phrase('oddQ'),
          choices: [for (final x in q.choices) QuizChoice(id: x, node: (_) => _img(x, photo: photo))],
          answer: q.answer,
          reward: _praise(g),
          rewardNode: (_) => _img(q.answer, photo: photo, size: 160),
        );
    }
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.seq, required this.photo});
  final List<String> seq;
  final bool photo;
  @override
  Widget build(BuildContext context) {
    final s = vwClamp(context, 46, 8.5, 92);
    Widget tile(Widget child, {bool q = false}) => Container(
          width: s,
          height: s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: q ? Colors.white : Colors.white.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(18),
            border: q ? Border.all(color: AppColors.sun, width: 4) : null,
          ),
          child: child,
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        for (final x in seq) tile(EmojiImage(x, size: s * .8, photo: photo)),
        tile(Text('?', style: TextStyle(fontSize: s * .5, fontWeight: FontWeight.w800, color: const Color(0xFFE0A800))), q: true),
      ]),
    );
  }
}

// ---------- Mê cung: sinh bằng DFS, bé kéo ngón tay (hoặc chạm ô kề) để đi tới ngôi sao ----------
/// walls[y][x] = [trên, phải, dưới, trái] (true = có tường).
List<List<List<bool>>> makeMaze(int n, [math.Random? r]) {
  final walls = List.generate(n, (_) => List.generate(n, (_) => [true, true, true, true]));
  final seen = List.generate(n, (_) => List.filled(n, false));
  final stack = <(int, int)>[(0, 0)];
  seen[0][0] = true;
  const dirs = [(0, -1, 0, 2), (1, 0, 1, 3), (0, 1, 2, 0), (-1, 0, 3, 1)];
  while (stack.isNotEmpty) {
    final (x, y) = stack.last;
    final next = shuffle(dirs, r).where((d) {
      final nx = x + d.$1, ny = y + d.$2;
      return nx >= 0 && ny >= 0 && nx < n && ny < n && !seen[ny][nx];
    }).firstOrNull;
    if (next == null) {
      stack.removeLast();
      continue;
    }
    final (dx, dy, w1, w2) = next;
    walls[y][x][w1] = false;
    walls[y + dy][x + dx][w2] = false;
    seen[y + dy][x + dx] = true;
    stack.add((x + dx, y + dy));
  }
  return walls;
}

class MazeView extends StatefulWidget {
  const MazeView({super.key, required this.ctx, required this.size});
  final GameContext ctx;
  final int size;

  /// Tường của mê cung đang chơi (để test).
  @visibleForTesting
  static List<List<List<bool>>>? debugWalls;
  @override
  State<MazeView> createState() => _MazeViewState();
}

class _MazeViewState extends State<MazeView> {
  GameContext get g => widget.ctx;
  int get n => widget.size;
  late final walls = MazeView.debugWalls = makeMaze(n);
  final List<(int, int)> path = [(0, 0)];
  int cx = 0, cy = 0;
  bool won = false;

  @override
  void initState() {
    super.initState();
    walls;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.audio.sayPhrase('mazeQ');
      g.progress(0, 1);
    });
  }

  bool _canGo(int x, int y) {
    final dx = x - cx, dy = y - cy;
    if (dx.abs() + dy.abs() != 1) return false;
    final w = walls[cy][cx];
    return !((dx == 1 && w[1]) || (dx == -1 && w[3]) || (dy == 1 && w[2]) || (dy == -1 && w[0]));
  }

  Future<void> _moveTo(int x, int y) async {
    // Đi lùi thì xoá vết; đi tới thì nối vết.
    final back = path.length > 1 && path[path.length - 2] == (x, y);
    setState(() {
      if (back) {
        path.removeLast();
      } else {
        path.add((x, y));
      }
      cx = x;
      cy = y;
    });
    g.audio.sfx('tap');
    if (x == n - 1 && y == n - 1) {
      won = true;
      g.audio.sfx('correct');
      g.cheer();
      g.progress(1, 1);
      await wait(700);
      if (mounted) g.finish(3);
    }
  }

  void _handle(Offset local, double side, bool down) {
    if (won) return;
    final c = side / (n * 100 + 16) * 100, o = side / (n * 100 + 16) * 8;
    final x = ((local.dx - o) / c).floor(), y = ((local.dy - o) / c).floor();
    if (x == cx && y == cy) return;
    if (_canGo(x, y)) {
      _moveTo(x, y);
    } else if (down) {
      g.audio.sfx('pop');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(math.min(c.maxWidth, c.maxHeight), 640.0);
      final k = side / (n * 100 + 16), cell = 100 * k, o = 8 * k;
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: Listener(
            key: const Key('maze'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _handle(e.localPosition, side, true),
            onPointerMove: (e) => _handle(e.localPosition, side, false),
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _MazePainter(walls, List.of(path), n))),
              Positioned(
                left: o + (n - 1) * cell + 12 * k,
                top: o + (n - 1) * cell + 12 * k,
                child: EmojiImage('Glowing star', size: cell - 24 * k, photo: false),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: o + cx * cell + 8 * k,
                top: o + cy * cell + 8 * k,
                child: EmojiImage(g.buddyImg, key: const Key('maze-me'), size: cell - 16 * k, photo: false),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter(this.walls, this.path, this.n);
  final List<List<List<bool>>> walls;
  final List<(int, int)> path;
  final int n;
  @override
  void paint(Canvas canvas, Size size) {
    const c = 100.0;
    final w = n * c;
    canvas.scale(size.width / (w + 16));
    canvas.translate(8, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, w), const Radius.circular(18)), Paint()..color = Colors.white);
    final trail = Path()..moveTo(path.first.$1 * c + c / 2, path.first.$2 * c + c / 2);
    for (final (a, b) in path.skip(1)) {
      trail.lineTo(a * c + c / 2, b * c + c / 2);
    }
    canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFD43B).withValues(alpha: .7));
    final wall = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5B6B88);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final wl = walls[y][x], X = x * c, Y = y * c;
        if (wl[0]) canvas.drawLine(Offset(X, Y), Offset(X + c, Y), wall);
        if (wl[3]) canvas.drawLine(Offset(X, Y), Offset(X, Y + c), wall);
        if (y == n - 1 && wl[2]) canvas.drawLine(Offset(X, Y + c), Offset(X + c, Y + c), wall);
        if (x == n - 1 && wl[1]) canvas.drawLine(Offset(X + c, Y), Offset(X + c, Y + c), wall);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => old.path.length != path.length || old.path.last != path.last;
}

// ---------- Sudoku 4×4 bằng hình ----------
List<List<int>> makeSudoku([math.Random? r]) {
  const base = [
    [0, 1, 2, 3],
    [2, 3, 0, 1],
    [1, 0, 3, 2],
    [3, 2, 1, 0],
  ];
  final rr = r ?? rng;
  final sym = shuffle([0, 1, 2, 3], r);
  final rows = [...shuffle([0, 1], r), ...shuffle([2, 3], r)];
  final cols = [...shuffle([0, 1], r), ...shuffle([2, 3], r)];
  final band = rr.nextDouble() < .5 ? [0, 1, 2, 3] : [2, 3, 0, 1];
  final stack = rr.nextDouble() < .5 ? [0, 1, 2, 3] : [2, 3, 0, 1];
  return [
    for (final row in band) [for (final col in stack) sym[base[rows[row]][cols[col]]]],
  ];
}

class SudokuView extends StatefulWidget {
  const SudokuView({super.key, required this.ctx, required this.blanks});
  final GameContext ctx;
  final int blanks;

  /// Lời giải đang chơi (để test): sol[hàng][cột] = chỉ số hình.
  @visibleForTesting
  static List<List<int>>? debugSolution;
  @override
  State<SudokuView> createState() => _SudokuViewState();
}

class _SudokuViewState extends State<SudokuView> {
  GameContext get g => widget.ctx;
  late final List<String> pics = sample(g.content.map('categories')['animals'] is List ? (g.content.map('categories')['animals'] as List).map((e) => e.toString()) : const ['Cat', 'Dog', 'Pig', 'Cow'], 4);
  late final List<List<int>> sol = SudokuView.debugSolution = makeSudoku();
  late final Set<int> blanks = sample(List.generate(16, (i) => i), widget.blanks).toSet();
  final Set<int> filled = {};
  final Map<int, int> shakes = {};
  int? selected;
  int mistakes = 0;
  bool done = false;
  late bool photo;

  int get left => blanks.length - filled.length;

  @override
  void initState() {
    super.initState();
    sol;
    selected = _firstEmpty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.audio.sayPhrase('sudokuQ');
      g.progress(0, blanks.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    photo = usePhotos(context, pics);
  }

  /// Ô đáp án (để test): chỉ số hình đúng của ô i.
  int answerAt(int i) => sol[i ~/ 4][i % 4];

  int? _firstEmpty() {
    for (var i = 0; i < 16; i++) {
      if (blanks.contains(i) && !filled.contains(i)) return i;
    }
    return null;
  }

  Future<void> _pick(int k) async {
    final s = selected;
    if (s == null || done) return;
    if (answerAt(s) == k) {
      setState(() {
        filled.add(s);
        selected = _firstEmpty();
      });
      g.audio.sfx('correct');
      g.cheer();
      g.progress(filled.length, blanks.length);
      if (left == 0) {
        done = true;
        await wait(700);
        if (mounted) g.finish(starsFor(mistakes));
      }
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      g.sad();
      setState(() => shakes[s] = (shakes[s] ?? 0) + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > c.maxHeight * 1.2;
      // Dọc: 4 nút bảng chọn + 3 khe 12 phải vừa bề ngang (máy 320dp).
      final palBtn = wide ? math.min(100.0, (c.maxHeight - 40) / 4.6) : math.min((c.maxWidth * .14).clamp(64.0, 100.0), (c.maxWidth - 36) / 4);
      final gridSide = wide ? math.min(c.maxHeight - 8, math.min(460.0, c.maxWidth - palBtn * 2.6)) : math.min(math.min(c.maxWidth * .92, 460.0), c.maxHeight - palBtn - 40);
      final grid = Container(
        width: gridSide,
        height: gridSide,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF5B6B88), borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          for (var r = 0; r < 4; r++) ...[
            if (r > 0) SizedBox(height: r == 2 ? 12 : 6),
            Expanded(
              child: Row(children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) SizedBox(width: col == 2 ? 12 : 6),
                  Expanded(child: _cell(r * 4 + col)),
                ],
              ]),
            ),
          ],
        ]),
      );
      final pal = [
        for (var k = 0; k < 4; k++)
          SizedBox.square(
            dimension: palBtn,
            child: Chunky(
              key: Key('sudoku-pal-$k'),
              onTap: () => _pick(k),
              radius: 22,
              child: Center(child: EmojiImage(pics[k], size: palBtn * .78, photo: photo)),
            ),
          ),
      ];
      return Center(
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, spacing: 24, children: [
                grid,
                SizedBox(width: palBtn * 2 + 12, child: Wrap(spacing: 12, runSpacing: 12, children: pal)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, spacing: 18, children: [grid, Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: pal)]),
      );
    });
  }

  Widget _cell(int i) {
    final given = !blanks.contains(i), isFilled = filled.contains(i), sel = selected == i;
    final bg = given
        ? const Color(0xFFF8FAFC)
        : isFilled
            ? const Color(0xFFE7FBE9)
            : sel
                ? const Color(0xFFFFF9DB)
                : const Color(0xFFEEF6FF);
    Widget content = const SizedBox.expand();
    if (given || isFilled) {
      content = LayoutBuilder(builder: (context, c) => Center(child: EmojiImage(pics[answerAt(i)], size: c.maxWidth * .78, photo: photo)));
      if (isFilled) content = PopIn(child: content);
    }
    return Shake(
      trigger: shakes[i] ?? 0,
      child: GestureDetector(
        key: Key('sudoku-cell-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (given || isFilled || done) return;
          setState(() => selected = i);
          g.audio.sfx('tap');
        },
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: sel && !isFilled ? Border.all(color: AppColors.sun, width: 5) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

// ---------- Ghép tranh: kéo mảnh (hoặc chạm mảnh rồi chạm ô) vào đúng chỗ ----------
class JigsawView extends StatefulWidget {
  const JigsawView({super.key, required this.ctx, required this.page, required this.cols, required this.rows});
  final GameContext ctx;
  final String page;
  final int cols, rows;
  @override
  State<JigsawView> createState() => _JigsawViewState();
}

class _JigsawViewState extends State<JigsawView> {
  GameContext get g => widget.ctx;
  int get n => widget.cols * widget.rows;
  late final List<int> tray = shuffle(List.generate(n, (i) => i));
  final Set<int> placed = {};
  final Map<int, int> shakes = {};
  int? selected;
  int mistakes = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.hideBuddy();
      g.progress(0, n);
      g.audio.sayPhrase('jigsawQ');
    });
  }

  Rect _vb(int i) {
    final w = 400 / widget.cols, h = 300 / widget.rows;
    return Rect.fromLTWH((i % widget.cols) * w, (i ~/ widget.cols) * h, w, h);
  }

  Future<void> _place(int piece, int slot) async {
    if (done) return;
    if (piece != slot || placed.contains(slot)) {
      mistakes++;
      g.audio.sfx('wrong');
      setState(() => shakes[piece] = (shakes[piece] ?? 0) + 1);
      return;
    }
    setState(() {
      tray.remove(piece);
      placed.add(slot);
      if (selected == piece) selected = null;
    });
    g.audio.sfx('correct');
    g.cheer();
    g.progress(placed.length, n);
    if (placed.length == n) {
      setState(() => done = true);
      await wait(900);
      if (mounted) g.finish(starsFor(math.max(0, mistakes - 1)));
    }
  }

  Widget _pieceArt(int i) => CustomPaint(painter: PagePainter(widget.page, viewBox: _vb(i)), child: const SizedBox.expand());

  @override
  Widget build(BuildContext context) {
    final aspect = (400 / widget.cols) / (300 / widget.rows);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > c.maxHeight * 1.25;
      var pw = math.min(150.0, 560 / widget.cols);
      double bw, bh;
      if (wide) {
        bw = math.min(math.min(620.0, c.maxWidth * .6), (c.maxHeight - 8) * 4 / 3);
      } else {
        // Màn thấp/hẹp: thu nhỏ mảnh ghép tới khi bảng (≥ 160) + khay vừa chiều cao, không tràn xuống dưới.
        double trayH() => (n / math.max(1, ((c.maxWidth + 10) / (pw + 10)).floor())).ceil() * (pw / aspect + 10);
        while (pw > 36 && c.maxHeight - trayH() - 14 < math.min(160.0, c.maxWidth) * 3 / 4) {
          pw *= .9;
        }
        bw = math.min(math.min(620.0, c.maxWidth), math.max(120.0, (c.maxHeight - trayH() - 14)) * 4 / 3);
      }
      bh = bw * 3 / 4;
      final board = SizedBox(
        width: bw,
        height: bh,
        child: Stack(children: [
          if (!done)
            Positioned.fill(
              child: Opacity(
                opacity: .18,
                child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CustomPaint(painter: PagePainter(widget.page))),
              ),
            ),
          Positioned.fill(
            child: Container(
              padding: EdgeInsets.all(done ? 0 : 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: done ? AppColors.good : const Color(0xFFA5C8F0), width: 3),
              ),
              child: Column(children: [
                for (var r = 0; r < widget.rows; r++)
                  Expanded(
                    child: Row(children: [
                      for (var col = 0; col < widget.cols; col++) Expanded(child: _slot(r * widget.cols + col)),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      );
      final pieceW = wide ? math.min(pw, (c.maxWidth - bw - 40) / 2 - 10) : pw;
      final trayW = Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [for (final i in tray) _piece(i, pieceW, pieceW / aspect)],
      );
      return Center(
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, spacing: 18, children: [board, SizedBox(width: pieceW * 2 + 12, child: SingleChildScrollView(child: trayW))])
            : Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [board, trayW]),
      );
    });
  }

  Widget _slot(int i) {
    final ok = placed.contains(i);
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => !done,
      onAcceptWithDetails: (d) => _place(d.data, i),
      builder: (context, cand, _) => GestureDetector(
        key: Key('jslot-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final s = selected;
          if (s != null && tray.contains(s)) _place(s, i);
        },
        child: Padding(
          padding: EdgeInsets.all(done ? 0 : 1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(done ? 0 : 8),
            child: ok
                ? PopIn(child: _pieceArt(i))
                : Container(color: cand.isNotEmpty ? const Color(0x33FFC93C) : Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _piece(int i, double w, double h) {
    final art = Container(
      width: w,
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: selected == i ? Border.all(color: AppColors.sun, width: 5) : null,
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: _pieceArt(i),
    );
    return Shake(
      key: ValueKey('jshake-$i'),
      trigger: shakes[i] ?? 0,
      child: Draggable<int>(
        data: i,
        feedback: Transform.scale(scale: 1.05, child: Material(color: Colors.transparent, child: art)),
        childWhenDragging: Opacity(opacity: .3, child: art),
        child: GestureDetector(
          key: Key('jpiece-$i'),
          onTap: () {
            setState(() => selected = i);
            g.audio.sfx('tap');
          },
          child: art,
        ),
      ),
    );
  }
}

// ---------- Sắp xếp trình tự: chạm hình để đưa vào ô trống tiếp theo ----------
class SeqView extends StatefulWidget {
  const SeqView({super.key, required this.ctx, required this.sets});
  final GameContext ctx;
  final List<String> sets;
  @override
  State<SeqView> createState() => _SeqViewState();
}

class _SeqViewState extends State<SeqView> {
  GameContext get g => widget.ctx;
  late final List<Json> sets = [
    for (final id in widget.sets) ...g.content.list('sequences').where((s) => s['id'] == id),
  ];
  int r = 0, mistakes = 0;
  bool busy = true, started = false;
  late List<int?> slots;
  late List<int> tray;
  final Set<int> okSlots = {};
  final Map<int, int> shakes = {};

  Json get st => sets[r];
  List<(String, String)> get steps => [
        for (final s in (st['steps'] as List? ?? const []))
          if (s is List && s.length >= 2) (s[0].toString(), s[1].toString()),
      ];

  @override
  void initState() {
    super.initState();
    _setup();
    g.audio.preload([for (final s in sets) for (final x in (s['steps'] as List? ?? const [])) if (x is List) g.audio.tpl('seqStep', {'name': x[1]})]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _setup() {
    if (sets.isEmpty) return;
    slots = List.filled(steps.length, null);
    tray = shuffle(List.generate(steps.length, (i) => i));
    okSlots.clear();
  }

  Future<void> _start() async {
    if (sets.isEmpty) {
      g.finish(3);
      return;
    }
    await g.audio.sayPhrase('seqQ');
    if (!mounted || g.aborted) return;
    g.progress(0, sets.length);
    setState(() {
      busy = false;
      started = true;
    });
  }

  VoiceLine? _stepLine(int k) => g.audio.tpl('seqStep', {'name': steps[k].$2});

  Future<void> _tapCard(int k) async {
    if (busy) return;
    final at = slots.indexOf(k);
    if (at < 0) {
      final empty = slots.indexOf(null);
      if (empty < 0) return;
      setState(() {
        tray.remove(k);
        slots[empty] = k;
      });
      g.audio.sfx('pop');
      g.audio.say(_stepLine(k));
      if (!slots.contains(null)) await _check();
    } else {
      setState(() {
        slots[at] = null;
        tray.add(k);
      });
      g.audio.sfx('tap');
    }
  }

  Future<void> _check() async {
    busy = true;
    final wrong = [for (var i = 0; i < slots.length; i++) if (slots[i] != i) i];
    if (wrong.isEmpty) {
      g.audio.sfx('correct');
      g.cheer();
      for (var i = 0; i < slots.length; i++) {
        if (!mounted || g.aborted) return;
        setState(() => okSlots.add(i));
        await g.audio.say(_stepLine(i));
      }
      await wait(500);
      if (!mounted || g.aborted) return;
      if (r + 1 >= sets.length) {
        g.progress(sets.length, sets.length);
        g.finish(starsFor(mistakes));
        return;
      }
      setState(() {
        r++;
        _setup();
        busy = false;
      });
      g.progress(r, sets.length);
      return;
    }
    mistakes++;
    g.audio.sfx('wrong');
    g.sad();
    setState(() {
      for (final i in wrong) {
        shakes[i] = (shakes[i] ?? 0) + 1;
      }
    });
    await g.audio.sayPhrase('seqWrong');
    if (!mounted || g.aborted) return;
    setState(() {
      for (final i in wrong) {
        tray.add(slots[i]!);
        slots[i] = null;
      }
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const SizedBox();
    final fs = baseFontSize(context);
    final photo = usePhotos(context, steps.map((s) => s.$1));
    final n = steps.length;
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final titleH = fs * 1.4 * 1.5 + 12;
      final byW = (math.min(c.maxWidth, 860) - gap * (n - 1)) / n;
      final byH = ((c.maxHeight - titleH - 16 * 2) / 2) * .9;
      final cw = math.max(40.0, math.min(byW, byH));
      final ch = cw / .9;
      Widget card(int k) => SizedBox(
            width: cw,
            height: ch,
            child: Chunky(
              key: Key('seq-card-$k'),
              onTap: () => _tapCard(k),
              radius: 20,
              depth: 5,
              padding: const EdgeInsets.all(6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 4, children: [
                EmojiImage(steps[k].$1, size: cw * .62, photo: photo),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(steps[k].$2, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * .85, height: 1.1)),
                  ),
                ),
              ]),
            ),
          );
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: solidShadow(AppColors.line, 4)),
            child: Text(g.i18n.L(st['name']), style: TextStyle(fontSize: fs * 1.4, fontWeight: FontWeight.w800)),
          ),
          Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
            for (var i = 0; i < n; i++)
              Shake(
                trigger: shakes[i] ?? 0,
                child: Container(
                  key: Key('seq-slot-$i'),
                  width: cw,
                  height: ch,
                  decoration: BoxDecoration(
                    color: okSlots.contains(i) ? const Color(0xFFE7FBE9) : Colors.white.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: okSlots.contains(i) ? AppColors.good : const Color(0xFFC7D3E3), width: 4),
                  ),
                  child: Stack(children: [
                    Positioned(left: 8, top: 2, child: Text('${i + 1}', style: TextStyle(color: const Color(0xFFA5B4C8), fontSize: fs * 1.2, fontWeight: FontWeight.w800))),
                    if (slots[i] != null) Positioned.fill(child: Padding(padding: const EdgeInsets.all(3), child: card(slots[i]!))),
                  ]),
                ),
              ),
          ]),
          SizedBox(
            height: ch,
            child: Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [for (final k in tray) card(k)]),
          ),
        ]),
      );
    });
  }
}

// ---------- Tìm điểm khác nhau ----------
const List<Color> _diffColors = [Color(0xFFE03131), Color(0xFF1971C2), Color(0xFF2F9E44), Color(0xFFF08C00), Color(0xFF9C36B5), Color(0xFF212529)];

class SpotView extends StatefulWidget {
  const SpotView({super.key, required this.ctx, required this.page, required this.diffs});
  final GameContext ctx;
  final String page;
  final int diffs;

  /// Các vùng khác nhau còn lại (để test).
  @visibleForTesting
  static Set<int>? debugDiffs;
  @override
  State<SpotView> createState() => _SpotViewState();
}

class _SpotViewState extends State<SpotView> {
  GameContext get g => widget.ctx;
  late final List<PageShape> regions = pageRegions(widget.page);
  late final List<Color> colorsA = List.of(kPreset[widget.page]!);
  late final List<Color> colorsB = List.of(colorsA);
  final Set<int> hiddenB = {};

  /// Các vùng khác nhau còn lại (để test).
  late final Set<int> diffs;
  final List<(Offset, double)> rings = [];
  int found = 0, mistakes = 0, shakeA = 0, shakeB = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    // Bỏ 2 vùng nền đầu tiên; vùng nhỏ thì ẩn hẳn, vùng lớn thì đổi màu.
    final cands = [for (var i = 2; i < regions.length; i++) i];
    diffs = SpotView.debugDiffs = sample(cands, widget.diffs).toSet();
    for (final i in diffs) {
      final bb = regions[i].bounds;
      if (bb.width * bb.height < 2500 && rng.nextDouble() < .5) {
        hiddenB.add(i);
      } else {
        final cur = colorsB[i];
        colorsB[i] = pick(_diffColors.where((c) => c != cur).toList());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g.aborted) return;
      g.hideBuddy();
      g.progress(0, diffs.length);
      g.audio.sayPhrase('spotQ');
    });
  }

  Future<void> _tap(bool b, Offset local, Size size) async {
    if (done) return;
    final i = hitRegion(widget.page, toPage(local, size));
    if (diffs.contains(i)) {
      final bb = regions[i].bounds;
      setState(() {
        diffs.remove(i);
        rings.add((bb.center, math.max(14.0, math.max(bb.width, bb.height) / 2 + 6)));
        found++;
      });
      g.audio.sfx('correct');
      g.cheer();
      g.progress(found, widget.diffs);
      if (diffs.isEmpty) {
        done = true;
        await wait(900);
        if (mounted) g.finish(starsFor(math.max(0, mistakes - 2)));
      }
    } else {
      // Chạm vùng nền lớn không tính lỗi để bé đỡ nản; chỉ rung nhẹ.
      if (i > 1) mistakes++;
      g.audio.sfx('pop');
      setState(() => b ? shakeB++ : shakeA++);
    }
  }

  Widget _pic(bool b, double w) => Shake(
        trigger: b ? shakeB : shakeA,
        child: Container(
          width: w,
          height: w * .75,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: kCardShadow),
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              key: Key(b ? 'spot-b' : 'spot-a'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _tap(b, d.localPosition, c.biggest),
              child: CustomPaint(
                size: c.biggest,
                painter: PagePainter(widget.page, colors: b ? colorsB : colorsA, hidden: b ? hiddenB : const {}, rings: List.of(rings), version: rings.length),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final portrait = c.maxHeight > c.maxWidth;
      final w = portrait ? math.min(math.min(c.maxWidth, 560.0), (c.maxHeight - 14) / 2 * 4 / 3) : math.min(math.min((c.maxWidth - 14) / 2, 560.0), c.maxHeight * 4 / 3);
      return Center(
        child: portrait
            ? Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [_pic(false, w), _pic(true, w)])
            : Row(mainAxisSize: MainAxisSize.min, spacing: 14, children: [_pic(false, w), _pic(true, w)]),
      );
    });
  }
}
