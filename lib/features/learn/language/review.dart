// Ôn tập (/review, /review/all, /review/x/<mục>): dựng câu hỏi cho mục tới ngày ôn (store.dueItems), chạy bằng QuizView.
// Xong: store.recordReview(stars), +1 vé nếu bật Khu vui chơi, mốc tiến bộ.
// CHỦ: agent A. Port của reference/web/js/app.js reviewPlay()/reviewQ()/wordQ().
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/vn_text.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/learn_tracking.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';
import 'package:be_vui_hoc/features/play/finish_round.dart' show celebrate;

import 'pick.dart' show enFace;
import 'quiz.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.mode, this.item});

  /// null = mục tới ngày ôn; 'all' = bố mẹ bấm Luyện lại; 'x' = luyện một mục (item).
  final String? mode;
  final String? item;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

/// Câu ôn của một mục (key = "bộ:id"), null nếu không dựng được.
QuizQuestion? reviewQuestion({
  required String key,
  required Content content,
  required AudioService audio,
  required I18n i18n,
  required LearnTracker tracker,
  required Json learn,
}) {
  final info = tracker.itemOf(key);
  if (info == null) return null;
  final set = info.set;
  final it = info.it ?? const <String, dynamic>{};
  String s(Object? v) => v?.toString() ?? '';
  QuizChoice txt(String x) => QuizChoice(id: x, text: x, node: (_) => Text(x));
  List<String> confWith(String ns, String ans) {
    final conf = asMap(learn['conf']);
    final e = conf.entries.where((e) => e.key.startsWith('$ns|$ans|')).toList()..sort((a, b) => asInt(b.value) - asInt(a.value));
    return e.map((x) => x.key.split('|')[2]).toList();
  }

  // Nghe tiếng, nhìn hình, chọn cách viết đúng giữa các tiếng gần giống (khác dấu, khác âm đầu/vần).
  QuizQuestion wordQ(Json w, bool toneFocus) {
    final tones = {...confWith('tone', s(w['tone'])), ...shuffle(kTones)}.where((x) => x != w['tone']).toList();
    final variants = tones.map((x) => s(w['c']) + placeTone(s(w['v']), x)).toList();
    final others = content.list('vnwords').where((x) => x['w'] != w['w'] && (x['c'] == w['c'] || x['v'] == w['v'])).map((x) => s(x['w'])).toList();
    final pool = toneFocus ? variants.take(3).toList() : [...variants.take(2), ...sample(others, 1)];
    final opts = shuffle([s(w['w']), ...pool.toSet().where((x) => x != w['w']).take(3)]);
    return QuizQuestion(
      key: key,
      say: audio.tpl('vnWord', w),
      stage: (_) => QuizWordPic(s(w['img'])),
      choices: opts.map(txt).toList(),
      cls: 'syll',
      cols: opts.length,
      answer: s(w['w']),
      reward: audio.tpl('spell', w),
      rewardNode: rewardOf(img: s(w['img']), big: s(w['w'])),
    );
  }

  if (set == 'letters') {
    final ch = s(it['ch']);
    final all = content.list('letters').map((l) => s(l['ch']));
    final opts = shuffle([ch, ...{...confWith('letters', ch), ...shuffle(all)}.where((x) => x != ch).take(3)]);
    return QuizQuestion(
      key: key,
      say: audio.tpl('findLetter', it),
      label: i18n.t('findLetter'),
      choices: opts.map(txt).toList(),
      answer: ch,
      reward: audio.tpl('letterWord', it),
      rewardNode: rewardOf(img: it['img'] as String?, big: ch, small: it['word'] as String?),
    );
  }
  if (set == 'tone') {
    final id = splitKey(key).$2;
    final pool = content.list('vnwords').where((w) => w['tone'] == id).toList();
    return pool.isEmpty ? null : wordQ(sample(pool, 1).first, true);
  }
  if (set == 'vnwords') return wordQ(it, false);
  if (set == 'twoWords' || set == 'sentences') {
    final all = content.list(set);
    final opts = shuffle([it, ...sample(all.where((x) => x['img'] != it['img']), 2)]);
    final label = s(it['w'] ?? it['t']);
    return QuizQuestion(
      key: key,
      label: label,
      labelStyle: set == 'twoWords' ? 'readword' : 'readsent',
      choices: opts.map((x) => QuizChoice(id: x['id'] as Object, node: (_) => QuizImg(s(x['img'])))).toList(),
      answer: it['id'] as Object,
      reward: audio.tpl(set == 'twoWords' ? 'twoWord' : 'sentence', it),
      rewardNode: rewardOf(img: s(it['img']), big: label),
    );
  }
  if (set == 'ruleWords') {
    return QuizQuestion(
      key: key,
      say: audio.tpl('ruleSay', it),
      stage: (_) => QuizWordPic(s(it['img'])),
      choices: shuffle([s(it['w']), s(it['bad'])]).map(txt).toList(),
      cls: 'syll words',
      answer: s(it['w']),
      reward: audio.tpl('ruleSay', it),
      rewardNode: rewardOf(img: s(it['img']), big: s(it['w'])),
    );
  }
  if (kFactSets.contains(set)) {
    final add = !set.startsWith('sub'), big = !['addFacts', 'subFacts'].contains(set);
    final sign = add ? '+' : '−';
    final qk = big ? (add ? 'add100Q' : 'sub100Q') : (add ? 'addQ' : 'subQ');
    final ak = big ? (add ? 'add100A' : 'sub100A') : (add ? 'addA' : 'subA');
    final a = asInt(it['a']), b = asInt(it['b']), c = asInt(it['c']);
    return QuizQuestion(
      key: key,
      say: audio.tpl(qk, it),
      stage: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: solidShadow(AppColors.line)),
        child: Text('$a $sign $b = ?', style: TextStyle(fontSize: vwClamp(context, 48, 9, 96), fontWeight: FontWeight.w800, color: AppColors.ink)),
      ),
      choices: _near(c, 4, 0, math.max(10, c + 5)).map((k) => QuizChoice(id: k, text: '$k', node: (_) => Text('$k'))).toList(),
      cls: 'nums',
      answer: c,
      reward: audio.tpl(ak, it),
      rewardNode: (_) => Text('$a $sign $b = $c'),
    );
  }
  if (set.startsWith('en_')) {
    final lv = content.list('englishLevels').where((l) => l['set'] == set).firstOrNull;
    final say = audio.tpl(lv != null ? s(lv['tpl']) : 'wordEn', it);
    final opts = shuffle([it, ...sample(content.list(set).where((x) => x['id'] != it['id']), 3)]);
    return QuizQuestion(
      key: key,
      say: say,
      label: say?.text,
      choices: opts.map((x) => QuizChoice(id: x['id'] as Object, text: x['en'] as String?, node: (_) => enFace(x))).toList(),
      answer: it['id'] as Object,
      reward: audio.tpl('wordEn', it),
      rewardNode: (context) => RewardContent(imgWidget: enFace(it), big: s(it['en'])),
    );
  }
  return null;
}

/// Các số gần đáp án (lựa chọn sai của câu toán).
List<int> _near(int ans, int n, int lo, int hi) {
  final c = <int>{ans};
  for (var d = 1; c.length < n && d <= hi - lo; d++) {
    for (final k in shuffle([ans - d, ans + d])) {
      if (k >= lo && k <= hi && c.length < n) c.add(k);
    }
  }
  return shuffle(c);
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> with SingleTickerProviderStateMixin {
  GameContext? ctx;
  List<QuizQuestion> qs = const [];
  int gen = 0, progI = 0, progN = 0;
  bool aborted = false, none = false;
  String? curKey;
  String buddyMode = '';
  late final AnimationController buddyAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void dispose() {
    aborted = true;
    buddyAnim.dispose();
    try {
      ref.read(audioProvider).stopVoice();
    } catch (_) {/* ref đã huỷ */}
    super.dispose();
  }

  void _build() {
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (p == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return;
    }
    final tracker = ref.read(learnTrackerProvider);
    final content = ref.read(contentProvider);
    final audio = ref.read(audioProvider);
    final i18n = ref.read(i18nProvider);
    final learn = store.learn(p);
    final keys = widget.mode == 'x' && widget.item != null
        ? [Uri.decodeComponent(widget.item!)]
        : store.dueItems(p, all: widget.mode == 'all').where(tracker.reviewable).take(8).toList();
    final list = <QuizQuestion>[];
    for (var round = 0; round < 3 && keys.isNotEmpty; round++) {
      for (final k in keys) {
        final q = reviewQuestion(key: k, content: content, audio: audio, i18n: i18n, tracker: tracker, learn: learn);
        if (q != null) list.add(q);
      }
      if (list.length >= math.min(5, keys.length * 3)) break;
    }
    if (list.isEmpty) {
      none = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _nothing());
      return;
    }
    qs = shuffle(list).take(8).toList();
    final data = ref.read(appDataProvider);
    final myGen = gen;
    ctx = GameContext(
      island: data.islands.first,
      levelIndex: 0,
      level: null,
      content: content,
      data: data,
      profile: p,
      tier: 0,
      audio: audio,
      i18n: i18n,
      store: store,
      buddyImg: data.mascot(p.mascot).img,
      isAborted: () => aborted || !mounted || gen != myGen,
      onProgress: (i, n) {
        if (mounted && gen == myGen) {
          curKey = i < qs.length ? qs[i].key : null;
          setState(() {
            progI = i;
            progN = n;
          });
        }
      },
      onBuddy: (m) {
        if (!mounted) return;
        setState(() => buddyMode = m);
        buddyAnim.forward(from: 0);
      },
      onBuddyVisible: (_) {},
      onRecord: (q) => _record(q),
      onFinish: (r) => _done(r.stars),
      onExit: _back,
      onGate: (c) => parentGate(c, ref),
    );
  }

  /// Ghi câu ôn: mục của câu (+ tiếng cụ thể khi ôn dấu), cặp nhầm theo loại.
  void _record(QuizRecord q) {
    final tracker = ref.read(learnTrackerProvider);
    final content = ref.read(contentProvider);
    final k = curKey;
    if (k == null) return;
    final set = splitKey(k).$1;
    final ns = set == 'letters' ? 'letters' : set.startsWith('en_') ? set : null;
    final keys = [k];
    if (set == 'tone') {
      final w = content.list('vnwords').where((x) => x['w'] == q.answer).firstOrNull;
      if (w != null) keys.add('vnwords:${w['id']}');
    }
    tracker.recordQ(LearnTracker.skillOfSet(set), keys, ns, q);
  }

  void _back() {
    aborted = true;
    final audio = ref.read(audioProvider);
    audio.sfx('tap');
    audio.stopVoice();
    context.go('/map');
  }

  Future<void> _nothing() async {
    if (!mounted) return;
    final audio = ref.read(audioProvider);
    final i = ref.read(i18nProvider);
    audio.sayPhrase('reviewNone');
    await showPanel<void>(
      context: context,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        const EmojiImage('Glowing star', size: 110, photo: false),
        PanelTitle(i.isEn ? 'Nothing to review!' : 'Không có gì cần ôn!'),
        NoteText(i.isEn ? 'You got everything right. Let\'s learn something new!' : 'Con làm đúng hết rồi. Học bài mới thôi!'),
        PanelRow(children: [
          AppButton(key: const Key('review-map'), icon: '🗺️', label: i.t('map'), variant: BtnVariant.green, onTap: () => Navigator.pop(c)),
        ]),
      ]),
    );
    if (mounted) context.go('/map');
  }

  Future<void> _done(int stars) async {
    if (!mounted || aborted) return;
    final store = ref.read(storeProvider);
    final tracker = ref.read(learnTrackerProvider);
    final audio = ref.read(audioProvider);
    final i = ref.read(i18nProvider);
    final p = store.profile!;
    store.recordReview(stars);
    final funOn = store.funOn;
    if (funOn) store.addTickets(1);
    final ms = tracker.checkMilestones(p);
    final left = tracker.dueCount(p);
    audio.sfx('win');
    confetti(context: context);
    audio.sayPhrase('reviewDone');
    final again = await showPanel<bool>(
      context: context,
      builder: (c) => _ReviewResult(
        stars: stars,
        prizes: [
          if (funOn) Prize(img: 'Admission tickets', text: i.t('gotTicket', {'n': 1}), color: const Color(0xFFF3F0FF)),
          NoteText(left > 0
              ? (i.isEn ? '$left more to review — let\'s continue tomorrow.' : 'Còn $left chỗ cần ôn, mai mình ôn tiếp nhé.')
              : (i.isEn ? 'You reviewed everything you used to mix up!' : 'Con đã ôn hết những chỗ hay nhầm!')),
        ],
        buttons: [
          AppButton(key: const Key('review-map'), icon: '🗺️', label: i.t('map'), variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(c, false)),
          if (left > 0)
            AppButton(key: const Key('review-more'), icon: '🔁', label: i.isEn ? 'Keep reviewing' : 'Ôn tiếp', variant: BtnVariant.blue, onTap: () => Navigator.pop(c, true)),
        ],
        onStarsDone: () async {
          if (ms.isEmpty) return;
          await wait(1400);
          if (mounted) celebrate(context, ref, p, ms);
        },
      ),
    );
    if (!mounted) return;
    if (again == true) {
      setState(() {
        gen++;
        progI = progN = 0;
        ctx = null;
        none = false;
        _build();
      });
    } else {
      context.go('/map');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(storeProvider).profile;
    if (p == null) return const SizedBox();
    final size = MediaQuery.sizeOf(context);
    final buddySize = (size.width * .10).clamp(70.0, 120.0);
    final hideBuddy = size.height <= 640 && size.width > size.height;
    // Back của Android: IconBtn 'review-back' tự nhận (PopScope trong IconBtn) → _back.
    return Stack(children: [
        AppScreen(
          child: Column(children: [
            TopBar(
              leading: IconBtn(key: const Key('review-back'), icon: AppIcon.back, label: 'Back', onTap: _back),
              titleWidget: Center(child: _Progress(index: progI, total: progN)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(999)),
                child: Text(ref.watch(i18nProvider).isEn ? '🔁 Review' : '🔁 Ôn bài',
                    style: const TextStyle(color: Color(0xFF5F3DC4), fontWeight: FontWeight.w800)),
              ),
              bottomGap: 10,
            ),
            Expanded(
              child: PhotoScope(
                enabled: true,
                child: none || ctx == null
                    ? const SizedBox()
                    : QuizView(key: ValueKey('review-$gen'), ctx: ctx!, questions: qs, options: const QuizOptions(intro: 'reviewIntro'), onDone: ctx!.finish),
              ),
            ),
          ]),
        ),
        if (!hideBuddy)
          Positioned(
            left: math.max(8, MediaQuery.paddingOf(context).left),
            bottom: math.max(8, MediaQuery.paddingOf(context).bottom),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: buddyAnim,
                builder: (context, child) {
                  final t = buddyAnim.value;
                  if (buddyMode == 'cheer') {
                    final y = t < .3 ? -40 * t / .3 : t < .6 ? -40 + 20 * (t - .3) / .3 : -20 * (1 - (t - .6) / .4);
                    return Transform.translate(offset: Offset(0, y), child: child);
                  }
                  if (buddyMode == 'sad') return Transform.rotate(angle: -12 * math.sin(t * 2 * math.pi) * math.pi / 180, child: child);
                  return child!;
                },
                child: Dressed(profile: p, size: buddySize, showBg: false),
              ),
            ),
          ),
    ]);
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.total});
  final int index, total;
  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox(height: 26);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(999)),
        child: Row(spacing: 4, children: [
          for (var k = 0; k < total; k++)
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: k < index ? AppColors.good : k == index ? AppColors.sun : const Color(0xFFE6EDF6),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Bảng "🔁 Ôn xong!": sao sáng dần (380ms/sao + tiếng 'star'), vé, lời nhắn, nút.
class _ReviewResult extends ConsumerStatefulWidget {
  const _ReviewResult({required this.stars, required this.prizes, required this.buttons, required this.onStarsDone});
  final int stars;
  final List<Widget> prizes;
  final List<Widget> buttons;
  final Future<void> Function() onStarsDone;
  @override
  ConsumerState<_ReviewResult> createState() => _ReviewResultState();
}

class _ReviewResultState extends ConsumerState<_ReviewResult> {
  int lit = 0;
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var k = 0; k < widget.stars; k++) {
      await wait(380);
      if (!mounted) return;
      setState(() => lit = k + 1);
      ref.read(audioProvider).sfx('star');
    }
    await widget.onStarsDone();
  }

  @override
  Widget build(BuildContext context) => Column(key: const Key('review-result'), mainAxisSize: MainAxisSize.min, children: [
        PanelTitle(ref.watch(i18nProvider).isEn ? '🔁 Review done!' : '🔁 Ôn xong!'),
        BigStars(lit: lit),
        ...widget.prizes,
        PanelRow(children: widget.buttons),
      ]);
}
