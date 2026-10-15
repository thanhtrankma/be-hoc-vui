// Đảo Khám phá (Tự nhiên & Xã hội): xếp từng hình vào đúng nhóm. Kéo thả hoặc chạm vào giỏ đều được.
// CHỦ: agent B. Port của reference/web/js/games/explore.js.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/learn/language/quiz.dart';

import 'common.dart';

final GameModule exploreModule = ExploreGame();

class ExploreGame extends GameModule {
  @override
  String get id => 'explore';
  @override
  Widget build(BuildContext context, GameContext ctx) => ExploreView(ctx: ctx);
}

const int _round = 8;

/// Bên đúng ('a'|'b') của hình đang xếp — test đọc.
@visibleForTesting
String? debugExploreSide;

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  GameContext get g => widget.ctx;
  late final Json lv = g.level ?? g.content.list('exploreLevels')[g.levelIndex];
  late final Json set = g.content.list('sortSets').firstWhere((s) => s['id'] == lv['set'], orElse: () => g.content.list('sortSets').first);
  late final Json sa = asMap(set['a']), sb = asMap(set['b']);
  late final List<Json> items;
  final Map<String, List<String>> bins = {'a': [], 'b': []};
  int idx = -1, mistakes = 0, shake = 0;
  bool busy = false, flying = false;
  String? over;
  Json? fact;
  Completer<void>? _placed;

  bool get gone => !mounted || g.aborted;
  VoiceLine? nameOf(String name) => g.audio.tpl('sortName', {'name': name});

  @override
  void initState() {
    super.initState();
    final all = asMapList(set['items']);
    final a = all.where((i) => i['side'] == 'a'), b = all.where((i) => i['side'] == 'b');
    items = shuffle([...sample(a, _round ~/ 2), ...sample(b, _round ~/ 2)]);
    g.audio.preload([...items.map((i) => nameOf(asStr(i['name']))), nameOf(asStr(sa['vi'])), nameOf(asStr(sb['vi']))]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (gone) return;
    g.progress(0, items.length);
    await g.audio.sayPhrase('exploreIntro');
    if (gone) return;
    await g.audio.say(nameOf(asStr(sa['vi'])));
    if (gone) return;
    await g.audio.say(nameOf(asStr(sb['vi'])));
    for (var i = 0; i < items.length; i++) {
      if (gone) return;
      setState(() {
        idx = i;
        busy = false;
        flying = false;
      });
      debugExploreSide = asStr(items[i]['side']);
      g.audio.say(nameOf(asStr(items[i]['name'])));
      _placed = Completer<void>();
      await _placed!.future;
      if (gone) return;
      g.progress(i + 1, items.length);
    }
    // Câu giải thích ngắn của bộ (nếu có): hiện chữ và đọc to.
    final f = g.content.list('exploreFacts').where((x) => x['set'] == set['id']).firstOrNull;
    if (f != null && !gone) {
      setState(() {
        idx = -1;
        fact = f;
      });
      await Future.wait([g.audio.say(g.audio.tpl('exploreFact', f)), wait(1500)]);
      if (gone) return;
    }
    g.finish(starsFor(mistakes));
  }

  Future<void> _drop(String side) async {
    if (busy || idx < 0) return;
    busy = true;
    final it = items[idx];
    if (side == it['side']) {
      g.audio.sfx('correct');
      g.cheer();
      setState(() {
        flying = true;
        bins[side]!.add(asStr(it['img']));
      });
      await wait(350);
      _placed?.complete();
    } else {
      mistakes++;
      g.audio.sfx('wrong');
      g.sad();
      setState(() => shake++);
      await g.audio.retry();
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth <= 640;
      final it = idx >= 0 ? items[idx] : null;
      final cardImg = vwClamp(context, 130, 19, 190).clamp(80.0, box.maxHeight * (narrow ? .22 : .4));
      final card = it == null
          ? const SizedBox()
          : _SortCard(key: ValueKey('card-$idx'), img: asStr(it['img']), name: asStr(it['name']), size: cardImg, flying: flying, shake: shake);
      final slot = Center(
        child: it == null
            ? const SizedBox()
            : Draggable<String>(
                data: 'card',
                maxSimultaneousDrags: busy ? 0 : 1,
                feedback: Material(color: Colors.transparent, child: Transform.rotate(angle: .05, child: _SortCard(img: asStr(it['img']), name: asStr(it['name']), size: cardImg, lifted: true))),
                childWhenDragging: Opacity(opacity: .25, child: card),
                child: GestureDetector(key: const Key('sort-card'), onTap: () => g.audio.say(nameOf(asStr(it['name']))), child: card),
              ),
      );
      Widget basket(String side, Json d) => Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (_) {
                setState(() => over = side);
                return true;
              },
              onLeave: (_) => setState(() => over = null),
              onAcceptWithDetails: (_) {
                setState(() => over = null);
                _drop(side);
              },
              builder: (context, cand, rej) => GestureDetector(
                key: Key('basket-$side'),
                onTap: () => _drop(side),
                child: _Basket(d: d, side: side, over: over == side, bin: bins[side]!, label: g.i18n.L(d)),
              ),
            ),
          );
      final Widget body = narrow
          ? Column(spacing: 12, children: [
              SizedBox(height: cardImg + 70, child: slot),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [basket('a', sa), basket('b', sb)])),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 20, children: [
              basket('a', sa),
              Expanded(child: slot),
              basket('b', sb),
            ]);
      return Stack(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: body),
        if (fact != null)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xB8E6F7FF),
              child: Center(
                child: PopIn(
                  child: CardBox(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * .8 > 560 ? 560 : box.maxWidth * .8),
                      child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
                        EmojiImage(asStr(sa['img']), size: 120, photo: false),
                        Text(asStr(fact!['fact']),
                            key: const Key('explore-fact'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: baseFontSize(context) * 1.25, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.3)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _SortCard extends StatelessWidget {
  const _SortCard({super.key, required this.img, required this.name, required this.size, this.flying = false, this.lifted = false, this.shake = 0});
  final String img, name;
  final double size;
  final bool flying, lifted;
  final int shake;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: lifted ? const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 20), blurRadius: 40)] : kCardShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
        EmojiImage(img, size: size),
        Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * 1.15, color: AppColors.ink)),
      ]),
    );
    return AnimatedOpacity(
      opacity: flying ? 0 : 1,
      duration: const Duration(milliseconds: 300),
      child: AnimatedScale(scale: flying ? .3 : 1, duration: const Duration(milliseconds: 300), child: Shake(trigger: shake, child: card)),
    );
  }
}

class _Basket extends StatelessWidget {
  const _Basket({required this.d, required this.side, required this.over, required this.bin, required this.label});
  final Json d;
  final String side;
  final bool over;
  final List<String> bin;
  final String label;
  @override
  Widget build(BuildContext context) {
    final hImg = vwClamp(context, 60, 11, 120);
    return AnimatedScale(
      scale: over ? 1.04 : 1,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: over ? const Color(0xFFF0FFF4) : Colors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: over ? AppColors.good : const Color(0xFFC7D3E3), width: 5),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(children: [
            EmojiImage(asStr(d['img']), size: hImg, photo: false),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: baseFontSize(context) * 1.2, height: 1.1, color: AppColors.ink)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
              for (final im in bin) PopIn(child: EmojiImage(im, size: 40, photo: false)),
            ]),
          ]),
        ),
      ),
    );
  }
}
