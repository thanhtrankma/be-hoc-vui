// Đảo Trí nhớ: lật thẻ tìm cặp giống nhau. Mỗi lần lật, bé nghe tên con vật/đồ vật.
// CHỦ: agent B. Port của reference/web/js/games/memory.js.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';


final GameModule memoryModule = MemoryGame();

class MemoryGame extends GameModule {
  @override
  String get id => 'memory';
  @override
  Widget build(BuildContext context, GameContext ctx) => MemoryView(ctx: ctx);
}

/// Bộ bài đang chơi (id từng thẻ theo thứ tự) — test đọc để lật đúng cặp.
@visibleForTesting
List<String>? debugMemoryDeck;

/// Sao theo số lần lật sai: ≤ số cặp = 3, ≤ 2× = 2, còn lại 1.
int memoryStars(int misses, int pairs) => misses <= pairs ? 3 : misses <= pairs * 2 ? 2 : 1;

class MemoryView extends StatefulWidget {
  const MemoryView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<MemoryView> createState() => _MemoryViewState();
}

class _MemoryViewState extends State<MemoryView> {
  GameContext get g => widget.ctx;
  late final Json lv = g.level ?? g.content.list('memoryLevels')[g.levelIndex];
  late final int pairs = asInt(lv['pairs'], 3), cols = asInt(lv['cols'], 3);
  late final List<Json> deck;
  final Set<int> open = {}, done = {};
  final List<int> picked = [];
  int found = 0, misses = 0;
  bool busy = false;

  VoiceLine? _voiceOf(Json w) => g.audio.tpl(g.i18n.lang == 'en' ? 'wordEn' : 'wordVi', w);

  @override
  void initState() {
    super.initState();
    // Bài có chủ đề lấy thẻ trong memItems, bài thường lấy kho words (con vật).
    final theme = lv['theme'];
    final pool = theme != null ? g.content.list('memItems').where((x) => x['theme'] == theme) : g.content.list('words');
    final words = sample(pool, pairs);
    g.audio.preload(words.map(_voiceOf));
    deck = shuffle([...words, ...words]);
    debugMemoryDeck = [for (final w in deck) asStr(w['id'])];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) g.progress(0, pairs);
    });
  }

  Future<void> _flip(int i) async {
    if (busy || open.contains(i) || done.contains(i)) return;
    setState(() => open.add(i));
    g.audio.sfx('flip');
    g.audio.say(_voiceOf(deck[i]));
    picked.add(i);
    if (picked.length < 2) return;
    busy = true;
    final a = picked[0], b = picked[1];
    picked.clear();
    if (deck[a]['id'] == deck[b]['id']) {
      await wait(450);
      if (!mounted || g.aborted) return;
      setState(() => done.addAll([a, b]));
      g.audio.sfx('correct');
      g.cheer();
      found++;
      g.progress(found, pairs);
      busy = false;
      if (found == pairs) {
        await wait(900);
        if (!mounted || g.aborted) return;
        g.finish(memoryStars(misses, pairs));
      }
    } else {
      misses++;
      await wait(1000);
      if (!mounted || g.aborted) return;
      setState(() => open.removeAll([a, b]));
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = (pairs * 2 / cols).ceil();
    return LayoutBuilder(builder: (context, box) {
      final gap = vwClamp(context, 10, 2, 18);
      final maxW = math.min(760.0, box.maxWidth - 24);
      final byW = (maxW - gap * (cols - 1)) / cols;
      final byH = (box.maxHeight - 24 - gap * (rows - 1)) / rows;
      final s = math.max(40.0, math.min(byW, byH));
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
          for (var r = 0; r < rows; r++)
            Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
              for (var i = r * cols; i < math.min(deck.length, (r + 1) * cols); i++)
                SizedBox(
                  key: Key('mcard-$i'),
                  width: s,
                  height: s,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _flip(i),
                    child: FlipCard(open: open.contains(i) || done.contains(i), done: done.contains(i), img: asStr(deck[i]['img'])),
                  ),
                ),
            ]),
        ]),
      );
    });
  }
}

/// Thẻ lật 3D: mặt sau ngôi sao cam, mặt trước hình; done = viền xanh + nảy.
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.open, required this.done, required this.img});
  final bool open, done;
  final String img;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final s = box.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: open ? 1 : 0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          builder: (context, t, _) {
            final front = t >= .5;
            final m = Matrix4.identity()
              ..setEntry(3, 2, 1 / 900)
              ..rotateY(math.pi * t);
            final face = front
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: _face(
                      color: done ? const Color(0xFFE7FBE9) : Colors.white,
                      shadow: done ? const Color(0xFF9FE3B0) : const Color(0x1A000000),
                      child: EmojiImage(img, size: s * .74),
                    ),
                  )
                : _face(
                    gradient: const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFFFFD27A), Color(0xFFFFB02E)], stops: [0, .6]),
                    shadow: const Color(0x1A000000),
                    child: EmojiImage('Star', size: s * .46, photo: false),
                  );
            return TweenAnimationBuilder<double>(
              tween: Tween(end: done ? 1 : 0),
              duration: const Duration(milliseconds: 500),
              builder: (context, k, child) => Transform.scale(scale: 1 + .08 * math.sin(k * math.pi), child: child),
              child: Transform(alignment: Alignment.center, transform: m, child: face),
            );
          },
        );
      });

  Widget _face({Color? color, Gradient? gradient, required Color shadow, required Widget child}) => Container(
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: child,
      );
}
