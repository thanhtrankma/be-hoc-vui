// Bố con thi tài (/duel): hai người chơi trên một máy.
// CHỦ: agent D. Port của reference/web/js/games/duel.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (DuelScreen) vì router/registry trỏ tới.
//
// Chia đôi màn hình, cùng một câu hỏi, ai bấm đúng trước được điểm.
// Máy nằm ngang: trái (bố mẹ) – phải (bé). Máy dựng đứng: nửa trên xoay ngược cho bố mẹ ngồi đối diện.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

const int kDuelRounds = 10;
const List<String> _kPics = ['Red apple', 'Star', 'Fish', 'Soccer ball', 'Duck', 'Hibiscus', 'Balloon', 'Cupcake'];
const Color _kDuelColor = Color(0xFF845EF7);

/// Một câu hỏi: kiểu hình (count | letters | math), các lựa chọn, đáp án, câu đọc hỏi và câu đọc sau khi đúng.
class DuelQ {
  DuelQ({required this.topic, required this.choices, required this.answer, this.say, this.after, this.n = 0, this.pic = '', this.eq = ''});
  final String topic;
  final List<String> choices;
  final String answer;
  final VoiceLine? say;
  final VoiceLine? after;
  final int n;
  final String pic;
  final String eq;
}

/// Tạo câu hỏi (makeQ() của duel.js).
DuelQ makeDuelQ(String topic, Content content, AudioService audio, [math.Random? r]) {
  final rr = r ?? rng;
  if (topic == 'count') {
    final n = 1 + rr.nextInt(10);
    final pic = sample(_kPics, 1, rr).first;
    final others = shuffle([n - 2, n - 1, n + 1, n + 2].where((k) => k >= 1 && k <= 10), rr).take(2);
    final nums = content.list('nums');
    return DuelQ(
      topic: topic,
      n: n,
      pic: pic,
      choices: ['$n', for (final o in others) '$o'],
      answer: '$n',
      after: n < nums.length ? audio.tpl('num', nums[n]) : null,
    );
  }
  if (topic == 'letters') {
    final letters = content.list('letters');
    final l = sample(letters, 1, rr).first;
    final ch = asStr(l['ch']);
    final others = sample(letters.where((x) => asStr(x['ch']) != ch), 2, rr).map((x) => asStr(x['ch']));
    return DuelQ(topic: topic, choices: [ch, ...others], answer: ch, say: audio.tpl('findLetter', l), after: audio.tpl('letterWord', l));
  }
  final add = rr.nextDouble() < .5;
  final facts = content
      .list(add ? 'addFacts' : 'subFacts')
      .where((x) => asInt(x['a']) >= 1 && asInt(x['b']) >= 1 && asInt(x['a']) <= 10 && (add ? asInt(x['c']) <= 10 : true))
      .toList();
  final f = sample(facts, 1, rr).first;
  final c = asInt(f['c']);
  final others = shuffle([c - 2, c - 1, c + 1, c + 2].where((k) => k >= 0 && k <= 10), rr).take(2);
  return DuelQ(
    topic: 'math',
    eq: '${f['a']} ${add ? '+' : '−'} ${f['b']}',
    choices: ['$c', for (final o in others) '$o'],
    answer: '$c',
    say: audio.tpl(add ? 'addQ' : 'subQ', f),
    after: audio.tpl(add ? 'addA' : 'subA', f),
  );
}

class DuelScreen extends ConsumerStatefulWidget {
  const DuelScreen({super.key});
  @override
  ConsumerState<DuelScreen> createState() => _DuelScreenState();
}

class _Side {
  List<String> choices = [];
  bool locked = false;
  String? right;
  String? wrong;
}

class _DuelScreenState extends ConsumerState<DuelScreen> {
  /// null = màn chọn chủ đề.
  String? topic;
  int _gen = 0;
  final List<int> score = [0, 0];
  final List<_Side> sides = [_Side(), _Side()];
  DuelQ? q;
  bool won = false;
  int? winSide;
  Completer<void>? _round;

  AudioService get audio => ref.read(audioProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => audio.sayPhrase('duelIntro'));
  }

  @override
  void dispose() {
    _gen++;
    super.dispose();
  }

  bool _alive(int g) => mounted && g == _gen;

  void pickTopic() {
    _gen++;
    setState(() => topic = null);
    audio.sayPhrase('duelIntro');
  }

  Future<void> play(String t) async {
    final g = ++_gen;
    setState(() {
      topic = t;
      score[0] = score[1] = 0;
      q = null;
    });
    await audio.sayPhrase('ready');
    final content = ref.read(contentProvider);
    for (var r = 0; r < kDuelRounds; r++) {
      if (!_alive(g)) return;
      final nq = makeDuelQ(t, content, audio);
      final done = _round = Completer<void>();
      setState(() {
        q = nq;
        won = false;
        winSide = null;
        for (final s in sides) {
          s
            ..locked = false
            ..right = null
            ..wrong = null
            ..choices = shuffle(nq.choices);
        }
      });
      if (nq.say != null) audio.say(nq.say);
      await done.future;
    }
    if (!_alive(g)) return; // rời màn bằng back: không hiện kết quả đè màn mới
    _result();
  }

  Future<void> pickAnswer(int k, String c) async {
    final cq = q;
    final s = sides[k];
    if (cq == null || won || s.locked || topic == null) return;
    final g = _gen;
    if (c == cq.answer) {
      won = true;
      setState(() {
        score[k]++;
        s.right = c;
        winSide = k;
      });
      audio.sfx('correct');
      await Future.wait([audio.say(cq.after), wait(1100)]);
      if (_alive(g) && q == cq) _round?.complete();
    } else {
      setState(() {
        s.locked = true;
        s.wrong = c;
      });
      audio.sfx('wrong');
      await wait(1300);
      if (_alive(g) && q == cq) {
        setState(() {
          s.locked = false;
          s.wrong = null;
        });
      }
    }
  }

  void quit() {
    _gen++;
    audio.stopVoice();
    pickTopic();
  }

  Future<void> _result() async {
    final i18n = ref.read(i18nProvider);
    final store = ref.read(storeProvider);
    final data = ref.read(appDataProvider);
    final p = store.profile!;
    final kidImg = data.mascot(p.mascot).img;
    final pa = score[0], kid = score[1];
    audio.sfx('win');
    confetti(context: context);
    audio.sayPhrase(kid > pa ? 'duelKid' : pa > kid ? 'duelParent' : 'duelTie');
    final r = await showPanel<String>(
      context: context,
      builder: (ctx) {
        final fs = baseFontSize(ctx);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PanelTitle(kid > pa ? '🏆 ${p.name}' : pa > kid ? '🏆 ${i18n.t('parent')}' : '🤝'),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: fs * 2.6, fontWeight: FontWeight.w800, color: AppColors.ink2),
            child: Row(key: const Key('duel-final'), mainAxisAlignment: MainAxisAlignment.center, spacing: 16, children: [
              Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
                const EmojiImage('Woman', size: 54, photo: false),
                const EmojiImage('Man', size: 54, photo: false),
                Text('$pa'),
              ]),
              const Text(':'),
              Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [Text('$kid'), EmojiImage(kidImg, size: 54, photo: false)]),
            ]),
          ),
          PanelRow(children: [
            AppButton(key: const Key('duel-map'), icon: '🗺️', label: i18n.t('map'), variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(ctx, 'map')),
            AppButton(key: const Key('duel-rematch'), icon: '🔄', label: i18n.t('rematch'), variant: BtnVariant.blue, onTap: () => Navigator.pop(ctx, 'again')),
          ]),
        ]);
      },
    );
    if (!mounted) return;
    if (r == 'map') {
      context.go('/map');
    } else {
      pickTopic();
    }
  }

  @override
  Widget build(BuildContext context) => topic == null ? _picker(context) : _board(context);

  Widget _picker(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final data = ref.watch(appDataProvider);
    final p = ref.read(storeProvider).profile;
    if (p == null) return const SizedBox();
    final kidImg = data.mascot(p.mascot).img;
    final imgW = vwClamp(context, 64, 10, 100);
    final fs = baseFontSize(context);
    final topics = [('count', 'Abacus', i18n.t('duelCount')), ('letters', 'Books', i18n.t('duelLetters')), ('math', 'Plus', i18n.t('duelMath'))];
    return AppScreen(
      scroll: true,
      child: Column(children: [
        TopBar(
          leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                audio.sfx('tap');
                context.go('/map');
              }),
          title: i18n.t('duelTitle'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 24, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [EmojiImage('Woman', size: imgW, photo: false), EmojiImage('Man', size: imgW, photo: false)]),
            Text('VS', style: TextStyle(fontSize: fs * 2.4, fontWeight: FontWeight.w800, color: AppColors.primary)),
            EmojiImage(kidImg, size: imgW, photo: false),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 3 : 2;
            final gap = 14.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(spacing: gap, runSpacing: gap, alignment: WrapAlignment.center, children: [
              for (final (id, pic, label) in topics)
                SizedBox(
                  width: w,
                  child: Chunky(
                    key: Key('duel-topic-$id'),
                    radius: 28,
                    shadowColor: _kDuelColor.withValues(alpha: .45),
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
                    onTap: () {
                      audio.sfx('tap');
                      play(id);
                    },
                    child: Column(spacing: 8, children: [
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _kDuelColor.withValues(alpha: .15), borderRadius: BorderRadius.circular(24)),
                        child: EmojiImage(pic, photo: false),
                      ),
                      Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.1, color: AppColors.ink2)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _board(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final data = ref.watch(appDataProvider);
    final p = ref.read(storeProvider).profile!;
    final kidImg = data.mascot(p.mascot).img;
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height >= size.width;
    Widget side(int k) {
      final w = _sideView(context, k, k == 0 ? i18n.t('parent') : p.name, kidImg);
      return Expanded(child: k == 0 && portrait ? RotatedBox(quarterTurns: 2, child: w) : w);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Flex(direction: portrait ? Axis.vertical : Axis.horizontal, spacing: 10, children: [side(0), side(1)]),
          ),
          Center(child: IconBtn(key: const Key('duel-quit'), icon: AppIcon.close, size: 48, onTap: quit)),
        ]),
      ),
    );
  }

  Widget _sideView(BuildContext context, int k, String name, String kidImg) {
    final s = sides[k];
    final cq = q;
    final fs = baseFontSize(context);
    final bg = winSide == k
        ? const Color(0x4722C55E)
        : k == 0
            ? const Color(0x24845EF7)
            : const Color(0x29FF8A5B);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: s.locked ? .45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Color.alphaBlend(bg, const Color(0x8CFFFFFF)), borderRadius: BorderRadius.circular(30)),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, spacing: 10, children: [
          // Đầu: hình, tên, điểm
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [
            if (k == 0) ...[
              const EmojiImage('Woman', size: 48, photo: false),
              const EmojiImage('Man', size: 48, photo: false),
            ] else
              EmojiImage(kidImg, size: 48, photo: false),
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: fs * 1.2, color: AppColors.ink2))),
            Container(
              key: Key('dscore-$k'),
              constraints: const BoxConstraints(minWidth: 56),
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 4))]),
              child: Text('${score[k]}', style: TextStyle(fontSize: fs * 1.6, fontWeight: FontWeight.w800, color: AppColors.ink2)),
            ),
          ]),
          // Hình câu hỏi
          Expanded(child: Center(child: cq == null ? const SizedBox() : _visual(context, k, cq))),
          // Lựa chọn
          Row(spacing: 10, children: [
            for (final c in s.choices) Expanded(child: _choice(context, k, c, s)),
          ]),
        ]),
      ),
    );
  }

  Widget _visual(BuildContext context, int k, DuelQ cq) {
    switch (cq.topic) {
      case 'count':
        final w = vwClamp(context, 34, 5, 50);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SingleChildScrollView(
            child: Wrap(key: Key('dgroup-$k'), alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
              for (var i = 0; i < cq.n; i++) EmojiImage(cq.pic, size: w, photo: false),
            ]),
          ),
        );
      case 'letters':
        return GestureDetector(onTap: () => audio.say(cq.say), child: const Text('🔊', style: TextStyle(fontSize: 64)));
      default:
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(cq.eq, key: Key('deq-$k'), style: TextStyle(fontSize: vwClamp(context, 48, 8, 80), fontWeight: FontWeight.w800, color: AppColors.ink)),
        );
    }
  }

  Widget _choice(BuildContext context, int k, String c, _Side s) {
    final right = s.right == c, wrong = s.wrong == c;
    return Listener(
      key: Key('dch-$k-$c'),
      onPointerDown: (_) => pickAnswer(k, c),
      child: Container(
        constraints: BoxConstraints(minHeight: (MediaQuery.sizeOf(context).height * .12).clamp(70.0, 110.0)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: right ? AppColors.good : wrong ? const Color(0xFFFFD6D6) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 6))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(c, style: TextStyle(fontSize: vwClamp(context, 36, 6, 60), fontWeight: FontWeight.w800, color: right ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}
