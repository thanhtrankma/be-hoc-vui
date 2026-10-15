// Đảo Âm nhạc: đàn mộc cầm 8 phím, học bài hát theo phím sáng, trò nhắc lại giai điệu.
// CHỦ: agent B. Port của reference/web/js/games/music.js. Âm thanh: ctx.audio.note(i).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'common.dart';

final GameModule musicModule = MusicGame();

class MusicGame extends GameModule {
  @override
  String get id => 'music';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final lv = ctx.level ?? ctx.content.list('musicLevels')[ctx.levelIndex];
    return switch (asStr(lv['kind'])) {
      'free' => FreeView(ctx: ctx),
      'simon' => SimonView(ctx: ctx, goal: asInt(lv['goal'], 4)),
      _ => SongView(
          ctx: ctx,
          notes: [
            for (final n in (ctx.content.list('songs').firstWhere((s) => s['id'] == lv['song'], orElse: () => {'notes': [0]})['notes'] as List)) asInt(n)
          ],
          title: ctx.i18n.isEn
              ? asStr(ctx.content.list('songs').firstWhere((s) => s['id'] == lv['song'], orElse: () => lv)['en'], asStr(lv['name']))
              : asStr(lv['name']),
        ),
    };
  }
}

const List<String> _namesVi = ['Đô', 'Rê', 'Mi', 'Fa', 'Son', 'La', 'Si', 'Đô'];
const List<String> _namesEn = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti', 'Do'];
const List<Color> _colors = [
  Color(0xFFFF6B6B), Color(0xFFFF922B), Color(0xFFFFC93C), Color(0xFF51CF66), Color(0xFF22B8CF), Color(0xFF4C6EF5), Color(0xFF9C5CF5), Color(0xFFF06595),
];

/// Sao bài hát theo số phím sai: ≤3 = 3, ≤8 = 2, còn lại 1.
int songStars(int mistakes) => mistakes <= 3 ? 3 : mistakes <= 8 ? 2 : 1;

/// Mộc cầm 8 phím (.xylo): phím ngắn dần, chạm (pointer down) là kêu ngay.
class Xylophone extends StatelessWidget {
  const Xylophone({super.key, required this.onKey, this.hits = const [], this.nopes = const [], this.next, required this.en});
  final void Function(int i) onKey;

  /// Đếm số lần mỗi phím được gõ / gõ sai (đổi số = chạy hiệu ứng).
  final List<int> hits;
  final List<int> nopes;

  /// Phím cần gõ tiếp (sáng viền).
  final int? next;
  final bool en;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final h = math.min(380.0, box.maxHeight);
        final gap = vwClamp(context, 4, 1, 10);
        return Container(
          height: h,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA0522D), Color(0xFF7A3E1D)]),
            borderRadius: BorderRadius.circular(26),
            boxShadow: solidShadow(const Color(0xFF5C2E14), 10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, spacing: gap, children: [
            for (var i = 0; i < 8; i++)
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: (100 - i * 6) / 100,
                  child: Listener(
                    key: Key('xkey-$i'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => onKey(i),
                    child: _Key(i: i, label: (en ? _namesEn : _namesVi)[i], hit: i < hits.length ? hits[i] : 0, nope: i < nopes.length ? nopes[i] : 0, next: next == i),
                  ),
                ),
              ),
          ]),
        );
      });
}

class _Key extends StatelessWidget {
  const _Key({required this.i, required this.label, required this.hit, required this.nope, required this.next});
  final int i, hit, nope;
  final String label;
  final bool next;
  @override
  Widget build(BuildContext context) {
    final c = _colors[i];
    final fs = vwClamp(context, 14, 2, 22);
    Widget bar = Container(
      decoration: BoxDecoration(
        color: c,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, .3], colors: [Color.alphaBlend(const Color(0x59FFFFFF), c), c]),
        borderRadius: BorderRadius.circular(14),
        border: next ? Border.all(color: Colors.white, width: 6) : null,
        boxShadow: [
          const BoxShadow(color: Color(0x40000000), offset: Offset(0, 4)),
          if (next) const BoxShadow(color: AppColors.sun, blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        _dot(),
        const Spacer(),
        _dot(),
        const SizedBox(height: 10),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fs, shadows: const [Shadow(color: Color(0x40000000), offset: Offset(0, 2))])),
        const SizedBox(height: 10),
      ]),
    );
    // Phím cần gõ nhấp nhô (keyframes glow).
    if (next) {
      bar = LoopAnim(
        period: const Duration(seconds: 1),
        child: bar,
        builder: (context, t, child) => Transform.translate(offset: Offset(0, -6 * (1 - math.cos(t * 2 * math.pi)) / 2), child: child),
      );
    }
    return Shake(trigger: nope, child: _Hit(trigger: hit, child: bar));
  }

  Widget _dot() => Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xB3FFFFFF), shape: BoxShape.circle));
}

/// keyframes hit: lún xuống, sáng lên rồi trở lại (.25s).
class _Hit extends StatefulWidget {
  const _Hit({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  State<_Hit> createState() => _HitState();
}

class _HitState extends State<_Hit> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  @override
  void didUpdateWidget(_Hit old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final k = math.sin(_c.value * math.pi);
          return Transform.translate(
            offset: Offset(0, 4 * k),
            child: Transform.scale(
              scaleY: 1 - .06 * k,
              child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: .25 * k), BlendMode.srcATop), child: child),
            ),
          );
        },
      );
}

mixin _KeysMixin<T extends StatefulWidget> on State<T> {
  final List<int> hits = List.filled(8, 0), nopes = List.filled(8, 0);
  GameContext get g;
  void press(int i) {
    g.audio.note(i);
    setState(() => hits[i]++);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) g.hideBuddy();
    });
  }
}

// ---------------------------------------------------------------- Đàn tự do

class FreeView extends StatefulWidget {
  const FreeView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<FreeView> createState() => _FreeViewState();
}

class _FreeViewState extends State<FreeView> with _KeysMixin {
  @override
  GameContext get g => widget.ctx;
  int taps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      g.progress(0, 1);
      g.audio.sayPhrase('freeQ');
    });
  }

  @override
  Widget build(BuildContext context) => _MusicLayout(
        keyboard: Xylophone(
          en: g.i18n.isEn,
          hits: hits,
          nopes: nopes,
          onKey: (i) {
            press(i);
            taps++;
          },
        ),
        bottom: AppButton(
          key: const Key('music-done'),
          icon: '✔',
          label: g.i18n.t('done'),
          variant: BtnVariant.green,
          enabled: taps >= 8,
          onTap: () {
            g.progress(1, 1);
            g.finish(3);
          },
        ),
      );
}

/// Khung: (tiêu đề) + đàn co theo chiều cao + nút dưới.
class _MusicLayout extends StatelessWidget {
  const _MusicLayout({this.title, required this.keyboard, required this.bottom});
  final String? title;
  final Widget keyboard;
  final Widget bottom;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(spacing: 14, children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: solidShadow(AppColors.line, 4)),
              child: Text('🎵 $title', style: TextStyle(fontSize: baseFontSize(context) * 1.4, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ),
          Flexible(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900, maxHeight: 380), child: keyboard))),
          bottom,
        ]),
      );
}

// ---------------------------------------------------------------- Học bài hát

class SongView extends StatefulWidget {
  const SongView({super.key, required this.ctx, required this.notes, required this.title});
  final GameContext ctx;
  final List<int> notes;
  final String title;
  @override
  State<SongView> createState() => _SongViewState();
}

class _SongViewState extends State<SongView> with _KeysMixin {
  @override
  GameContext get g => widget.ctx;
  int pos = 0, mistakes = 0;
  bool demo = false, finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      g.progress(0, widget.notes.length);
      g.audio.sayPhrase('songQ');
    });
  }

  Future<void> _key(int i) async {
    if (demo || finished) return;
    press(i);
    if (i == widget.notes[pos]) {
      setState(() => pos++);
      g.progress(pos, widget.notes.length);
      if (pos == widget.notes.length) {
        setState(() => finished = true);
        g.audio.sfx('correct');
        g.cheer();
        await wait(500);
        if (!mounted || g.aborted) return;
        g.finish(songStars(mistakes));
      }
    } else {
      mistakes++;
      setState(() => nopes[i]++);
    }
  }

  Future<void> _listen() async {
    if (demo) return;
    setState(() => demo = true);
    g.audio.stopVoice();
    for (final n in widget.notes) {
      if (!mounted || g.aborted) return;
      press(n);
      await wait(420);
    }
    if (mounted) setState(() => demo = false);
  }

  @override
  Widget build(BuildContext context) => _MusicLayout(
        title: widget.title,
        keyboard: Xylophone(en: g.i18n.isEn, hits: hits, nopes: nopes, next: demo || finished ? null : widget.notes[pos], onKey: _key),
        bottom: AppButton(key: const Key('music-listen'), icon: '▶', label: g.i18n.t('listen'), variant: BtnVariant.blue, enabled: !demo, onTap: _listen),
      );
}

// ---------------------------------------------------------------- Nhắc lại giai điệu

/// Chuỗi Simon hiện tại (test đọc).
@visibleForTesting
List<int>? debugSimonSeq;

class SimonView extends StatefulWidget {
  const SimonView({super.key, required this.ctx, required this.goal});
  final GameContext ctx;
  final int goal;
  @override
  State<SimonView> createState() => _SimonViewState();
}

class _SimonViewState extends State<SimonView> {
  GameContext get g => widget.ctx;
  static const _pads = [(0, Color(0xFFFF6B6B)), (2, Color(0xFFFFC93C)), (4, Color(0xFF51CF66)), (7, Color(0xFF4C6EF5))];
  List<int> seq = [];
  int input = 0, mistakes = 0;
  bool listening = false, done = false;
  final Set<int> lit = {};

  /// Đang chờ bé gõ (test đọc).
  bool get isListening => listening;

  bool get gone => !mounted || g.aborted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (gone) return;
      g.hideBuddy();
      g.progress(0, widget.goal);
      await g.audio.sayPhrase('simonQ');
      if (gone) return;
      seq = [rnd(4), rnd(4)];
      debugSimonSeq = seq;
      _play();
    });
  }

  Future<void> _flash(int i) async {
    g.audio.note(_pads[i].$1, .6);
    setState(() => lit.add(i));
    await wait(380);
    if (!mounted) return;
    setState(() => lit.remove(i));
    await wait(140);
  }

  Future<void> _play() async {
    setState(() => listening = false);
    await wait(600);
    for (final i in List.of(seq)) {
      if (gone) return;
      await _flash(i);
    }
    if (gone) return;
    input = 0;
    setState(() => listening = true);
  }

  Future<void> _tap(int i) async {
    if (!listening || done) return;
    g.audio.note(_pads[i].$1, .5);
    setState(() => lit.add(i));
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => lit.remove(i));
    });
    if (i != seq[input]) {
      mistakes++;
      setState(() => listening = false);
      g.audio.sfx('wrong');
      g.sad();
      await wait(700);
      if (gone) return;
      _play();
      return;
    }
    input++;
    if (input == seq.length) {
      setState(() => listening = false);
      g.progress(seq.length, widget.goal);
      if (seq.length >= widget.goal) {
        done = true;
        g.audio.sfx('correct');
        g.cheer();
        await wait(600);
        if (gone) return;
        g.finish(starsFor(mistakes));
        return;
      }
      g.audio.sfx('star');
      g.cheer();
      seq = [...seq, rnd(4)];
      debugSimonSeq = seq;
      if (seq.length == 3) await g.audio.sayPhrase('simonMore');
      if (gone) return;
      _play();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final side = math.min(520.0, math.min(box.maxWidth * .86, box.maxHeight - 24));
        final gap = vwClamp(context, 12, 2.5, 22);
        final pad = (side - gap) / 2;
        Widget padW(int i) {
          final on = lit.contains(i);
          final c = _pads[i].$2;
          return Listener(
            key: Key('pad-$i'),
            onPointerDown: (_) => _tap(i),
            child: AnimatedScale(
              scale: on ? 1.05 : 1,
              duration: const Duration(milliseconds: 100),
              child: AnimatedOpacity(
                opacity: on ? 1 : .55,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: pad,
                  height: pad,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(32),
                    border: const Border(bottom: BorderSide(color: Color(0x2E000000), width: 10)),
                    boxShadow: on ? [BoxShadow(color: c, blurRadius: 30)] : null,
                  ),
                ),
              ),
            ),
          );
        }

        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, spacing: gap, children: [
            Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [padW(0), padW(1)]),
            Row(mainAxisSize: MainAxisSize.min, spacing: gap, children: [padW(2), padW(3)]),
          ]),
        );
      });
}
