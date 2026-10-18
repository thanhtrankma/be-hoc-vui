// Đảo Đọc truyện: truyện tranh chữ sáng theo giọng đọc (chạm từ để nghe), nghe – viết chính tả, bé đọc to.
// CHỦ: agent A. Port của web js/games/read.js. Đọc to dùng speech_to_text (hỏi bố mẹ + khoá bố mẹ trước lần bật micro đầu).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/vn_text.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'fx.dart';
import 'quiz.dart';
import 'spell.dart' show spellPool;

final GameModule readModule = ReadGame();

class ReadGame extends GameModule {
  @override
  String get id => 'read';
  @override
  Widget build(BuildContext context, GameContext ctx) {
    final lv = ctx.level ?? const {};
    return switch (lv['kind']) {
      'dictation' => DictationView(ctx: ctx),
      'aloud' => AloudView(ctx: ctx),
      _ => StoryView(ctx: ctx),
    };
  }
}

String _s(Object? v) => v?.toString() ?? '';
VoiceLine? _line(GameContext g, String text) => g.audio.tpl('storyLine', {'t': text});
VoiceLine? _wordV(GameContext g, String w) => g.audio.tpl('storyWord', {'w': w.toLowerCase()});
VoiceLine _praise(GameContext g) => g.audio.phrase('praise${1 + math.Random().nextInt(6)}');

/// Thẻ thưởng chung (.reward .card) cho các màn không dùng QuizView.
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          key: const Key('read-reward'),
          color: const Color(0xB8E6F7FF),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RewardIn(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFFFF3BF), width: 4),
                    boxShadow: kCardShadow,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
}

/// Cột nội dung rộng `width`, tự thu nhỏ cả khối nếu cao quá vùng chơi (máy ngang thấp).
class _FitColumn extends StatelessWidget {
  const _FitColumn({required this.children, this.maxWidth = 900, this.spacing = 12});
  final List<Widget> children;
  final double maxWidth;
  final double spacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = math.min(box.maxWidth, maxWidth);
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: w, child: Column(mainAxisSize: MainAxisSize.min, spacing: spacing, children: children)),
          ),
        );
      });
}

// =================================================================================================================
// Truyện tranh

class StoryView extends StatefulWidget {
  const StoryView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<StoryView> createState() => _StoryViewState();
}

/// Một từ trong dòng truyện: chữ + phần dấu câu theo sau.
class _Tok {
  _Tok(this.text, [this.word, this.tail = '']);
  final String text;
  final String? word;
  final String tail;
}

final RegExp _wordRe = RegExp(r'^([0-9A-Za-z_À-ỹ]+)(.*)$', unicode: true);

List<_Tok> _tokens(String text) {
  final out = <_Tok>[];
  for (final tok in text.split(RegExp(r'\s+'))) {
    if (tok.isEmpty) continue;
    final m = _wordRe.firstMatch(tok);
    out.add(m == null ? _Tok(tok) : _Tok(tok, m[1], m[2] ?? ''));
  }
  return out;
}

class _StoryViewState extends State<StoryView> {
  GameContext get g => widget.ctx;
  late final Json lv = g.level ?? const {};
  late final Json st = g.content.list('stories').firstWhere((s) => s['id'] == lv['story'], orElse: () => const {});
  late final List<Json> pages = asMapList(st['pages']);
  late final List<Json> qs = asMapList(st['qs']);
  int page = 0;
  bool quiz = false;
  bool reading = false, readOnce = false;
  int readGen = 0;

  /// Dòng/từ đang sáng; các từ đã đọc (xanh).
  int hlLine = -1, hlWord = -1;
  final Set<(int, int)> readWords = {};
  final List<Timer> timers = [];
  bool get dead => !mounted || g.aborted;
  int get total => pages.length + qs.length;

  @override
  void initState() {
    super.initState();
    g.audio.preload([_line(g, '${_s(st['title'])}.'), for (final p in pages) ...asStrList(p['lines']).map((l) => _line(g, l))]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dead) return;
      g.hideBuddy();
      if (pages.isEmpty) {
        setState(() => quiz = true);
        return;
      }
      _showPage();
    });
  }

  @override
  void dispose() {
    for (final t in timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _showPage() {
    g.progress(page, total);
    _readAll();
  }

  List<String> get _lines => asStrList(pages[page]['lines']);

  Future<void> _readAll() async {
    final my = ++readGen;
    setState(() => reading = true);
    bool alive() => !dead && my == readGen;
    if (page == 0) await g.audio.say(_line(g, '${_s(st['title'])}.'));
    final lines = _lines;
    for (var k = 0; k < lines.length; k++) {
      if (!alive()) return;
      await _readLine(k, lines[k], alive);
      await wait(250);
    }
    if (!alive()) return;
    setState(() {
      reading = false;
      readOnce = true;
    });
  }

  /// Đọc một dòng, tô sáng từng từ theo thời gian ước lượng (độ dài chữ và dấu câu).
  Future<void> _readLine(int li, String text, bool Function() alive) async {
    final item = _line(g, text);
    final dur = await g.audio.clipDuration(item);
    if (!alive()) return;
    final toks = _tokens(text).where((t) => t.word != null).toList();
    final weights = toks.map((t) => t.word!.length + 2 + (RegExp(r'[,.!?]').hasMatch(t.tail) ? 4 : 0)).toList();
    final sum = weights.fold<int>(0, (a, b) => a + b);
    final totalW = sum == 0 ? 1 : sum;
    final p = g.audio.say(item);
    var acc = 0;
    final mine = <Timer>[];
    for (var i = 0; i < toks.length; i++) {
      final at = (acc / totalW) * dur * 1000 * .96;
      acc += weights[i];
      mine.add(Timer(Duration(milliseconds: at.round()), () {
        if (!alive()) return;
        setState(() {
          hlLine = li;
          hlWord = i;
          readWords.add((li, i));
        });
      }));
    }
    timers.addAll(mine);
    await p;
    for (final t in mine) {
      t.cancel();
    }
    if (!mounted) return;
    setState(() {
      hlLine = hlWord = -1;
      for (var i = 0; i < toks.length; i++) {
        readWords.add((li, i));
      }
    });
  }

  void _again() {
    g.audio.stopVoice();
    _readAll();
  }

  void _next() {
    if (!readOnce) return;
    g.audio.stopVoice();
    g.audio.sfx('flip');
    readGen++;
    if (page + 1 >= pages.length) {
      setState(() => quiz = true);
      return;
    }
    setState(() {
      page++;
      readOnce = false;
      readWords.clear();
      hlLine = hlWord = -1;
    });
    _showPage();
  }

  List<QuizQuestion> _questions() => qs.map((q) {
        List<QuizChoice> choices;
        if (q['img'] is List) {
          choices = shuffle(asStrList(q['img'])).map((x) => QuizChoice(id: x, node: (_) => QuizImg(x))).toList();
        } else if (q['color'] is List) {
          choices = shuffle(q['color'] as List).map((c) {
            final name = _s((c as List)[0]);
            return QuizChoice(id: name, text: name, node: (_) => Swatch(parseColor(_s(c[1]))));
          }).toList();
        } else {
          choices = shuffle(asStrList(q['text'])).map((x) => QuizChoice(id: x, text: x, node: (_) => Text(x))).toList();
        }
        return QuizQuestion(
          say: _line(g, _s(q['q'])),
          label: _s(q['q']),
          choices: choices,
          answer: _s(q['a']),
          reward: _praise(g),
          cls: q['text'] != null ? 'syll' : null,
        );
      }).toList();

  late final List<QuizQuestion> _qs = _questions();

  @override
  Widget build(BuildContext context) {
    if (quiz) {
      return QuizView(
        ctx: g,
        questions: _qs,
        options: const QuizOptions(intro: 'storyQ'),
        onProgress: (i, n) => g.progress(pages.length + i, total),
        onDone: g.finish,
      );
    }
    if (pages.isEmpty) return const SizedBox();
    final pg = pages[page];
    final mq = MediaQuery.sizeOf(context);
    final fs = baseFontSize(context);
    final short = mq.height < 560;
    final imgSize = short ? math.min(vwClamp(context, 110, 22, 240), mq.height * .26) : (mq.width <= 560 ? vwClamp(context, 120, 38, 170) : vwClamp(context, 150, 22, 240));
    final lineFont = vwClamp(context, 26, 4, 40);
    final imgs = asStrList(pg['imgs']);
    final usePhotos = imgs.length < 2 || groupUsesPhotos(_photos(context), imgs);
    return _FitColumn(spacing: short ? 8 : 14, children: [
      if (page == 0) Text(_s(st['title']), textAlign: TextAlign.center, style: TextStyle(fontSize: fs * 1.6, fontWeight: FontWeight.w800, color: AppColors.ink)),
      PhotoScope(
        enabled: usePhotos && PhotoScope.of(context),
        child: Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 10, children: [
          for (final (k, x) in imgs.indexed) Bob(delay: Duration(milliseconds: 400 * k), child: EmojiImage(x, size: imgSize)),
        ]),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: kCardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (li, text) in asStrList(pg['lines']).indexed)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _lineWidget(li, text, lineFont)),
        ]),
      ),
      Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 10, children: [
        AppButton(key: const Key('story-again'), icon: '🔊', label: g.i18n.t('readAgain'), variant: BtnVariant.ghost, enabled: !reading, onTap: _again),
        AppButton(key: const Key('story-next'), label: '${g.i18n.t('nextPage')} ➜', variant: BtnVariant.green, enabled: readOnce, onTap: _next),
      ]),
    ]);
  }

  Map<String, PhotoInfo> _photos(BuildContext context) {
    try {
      return ProviderScopeReader.photos(context);
    } catch (_) {
      return const {};
    }
  }

  Widget _lineWidget(int li, String text, double font) {
    final toks = _tokens(text);
    var wi = -1;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 2, children: [
      for (final t in toks)
        if (t.word == null)
          Text('${t.text} ', style: TextStyle(fontSize: font, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.ink))
        else
          Builder(builder: (context) {
            wi++;
            final idx = wi;
            final hl = hlLine == li && hlWord == idx;
            final read = readWords.contains((li, idx));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => g.audio.say(_wordV(g, t.word!)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: hl ? AppColors.sun : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(t.word!,
                      style: TextStyle(fontSize: font, fontWeight: FontWeight.w700, height: 1.45, color: hl ? AppColors.ink : read ? const Color(0xFF1C7ED6) : AppColors.ink)),
                ),
                Text('${t.tail} ', style: TextStyle(fontSize: font, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.ink)),
              ]),
            );
          }),
    ]);
  }
}

/// Đọc bảng ảnh chụp từ ProviderScope (không bắt widget phải là Consumer).
class ProviderScopeReader {
  static Map<String, PhotoInfo> photos(BuildContext context) =>
      ProviderScope.containerOf(context, listen: false).read(contentBundleProvider).photos;
}

// =================================================================================================================
// Nghe – viết: ghép âm đầu + vần + dấu

const List<String> _vowels = ['a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư', 'y'];

class DictationView extends StatefulWidget {
  const DictationView({super.key, required this.ctx});
  final GameContext ctx;

  /// Tiếng đang hỏi {c, v, t} (để test chơi tự động).
  @visibleForTesting
  static Map<String, String>? debugTarget;
  @override
  State<DictationView> createState() => _DictationViewState();
}

class _DictationViewState extends State<DictationView> {
  GameContext get g => widget.ctx;
  late final Json lv = g.level ?? const {};
  late final List<Json> words = sequence(spellPool(g.content, lv).where((w) => asStrList(lv['tones']).contains(w['tone'])).toList(), 6);
  int i = 0, mistakes = 0;
  String? pc, pv, pt;
  final Set<String> bad = {};
  int badGen = 0;
  bool started = false, checking = false, reward = false;
  List<String> keys = const [];
  String? stepKey;
  bool get dead => !mounted || g.aborted;
  Json get w => words[i];

  @override
  void initState() {
    super.initState();
    g.audio.preload(words.expand((w) => [g.audio.tpl('vnWord', w), g.audio.tpl('spell', w)]));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (dead) return;
    g.hideBuddy();
    if (words.isEmpty) {
      g.finish(3);
      return;
    }
    await g.audio.sayPhrase('dictIntro');
    if (dead) return;
    _word();
  }

  void _word() {
    g.progress(i, words.length);
    DictationView.debugTarget = {'c': _s(w['c']), 'v': _s(w['v']), 't': _s(w['tone'])};
    setState(() {
      started = true;
      pc = pv = pt = null;
      bad.clear();
      reward = false;
    });
    g.audio.say(g.audio.tpl('vnWord', w));
    _step();
  }

  void _step() {
    final k = pc == null ? 'c' : pv == null ? 'v' : pt == null ? 't' : null;
    if (k == null) {
      _check();
      return;
    }
    // Bàn phím vần: vần đúng + vài vần gây nhiễu (không bày hết 40 vần). Học cùng lớp (lv.know): chỉ âm, vần, dấu đã học.
    final know = lv['know'] is Map ? asMap(lv['know']) : null;
    final cons = g.content.strings('consonants');
    final List<String> list;
    if (k == 'c') {
      list = know != null ? cons.where((c) => asStrList(know['c']).contains(c)).toList() : cons;
    } else if (k == 'v') {
      final src = know != null ? asStrList(know['v']) : [..._vowels, if (lv['pool'] != null) ...g.content.strings('rimes')];
      list = shuffle([_s(w['v']), ...sample(src.where((r) => r != w['v']).toSet(), 11)]);
    } else {
      list = know != null ? kTones.where((x) => asStrList(know['t']).contains(x)).toList() : kTones;
    }
    setState(() {
      stepKey = k;
      keys = list;
    });
  }

  void _key(String x) {
    if (checking) return;
    g.audio.sfx('tap');
    setState(() {
      if (stepKey == 'c') pc = x;
      if (stepKey == 'v') pv = x;
      if (stepKey == 't') pt = x;
    });
    _step();
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
      keys = const [];
      stepKey = null;
    });
    final okC = pc == w['c'], okV = pv == w['v'], okT = pt == w['tone'];
    if (okC && okV && okT) {
      g.audio.sfx('correct');
      g.cheer();
      setState(() => reward = true);
      await Future.wait([g.audio.say(g.audio.tpl('spell', w)), wait(1200)]);
      if (dead) return;
      checking = false;
      if (i + 1 >= words.length) {
        g.progress(words.length, words.length);
        g.finish(starsFor(math.max(0, mistakes - 1)));
        return;
      }
      i++;
      _word();
      return;
    }
    mistakes++;
    g.audio.sfx('wrong');
    g.sad();
    setState(() {
      badGen++;
      if (!okC) bad.add('c');
      if (!okV) bad.add('v');
      if (!okT) bad.add('t');
    });
    await wait(900);
    if (dead) return;
    setState(() {
      bad.clear();
      if (!okC) pc = null;
      if (!okV) pv = pt = null;
      if (!okT) pt = null;
      checking = false;
    });
    g.audio.say(g.audio.tpl('vnWord', w));
    _step();
  }

  /// Chạm ô đã chọn để chọn lại.
  void _clear(String k) {
    if (checking) return;
    setState(() {
      if (k == 'c') pc = null;
      if (k == 'v') pv = pt = null;
      if (k == 't') pt = null;
    });
    _step();
  }

  String get _shown => (pc ?? '') + (pv != null ? (pt != null ? placeTone(pv!, pt!) : pv!) : '');

  @override
  Widget build(BuildContext context) {
    if (!started || words.isEmpty) return const SizedBox();
    final mq = MediaQuery.sizeOf(context);
    final narrow = mq.width <= 600;
    final short = mq.height < 560;
    final cols = stepKey == 'c' ? (narrow ? 5 : short ? 12 : 8) : (narrow ? 4 : 6);
    final slot = short ? 72.0 : 90.0;
    return Stack(children: [
      _FitColumn(spacing: short ? 8 : 12, children: [
        Chunky(
          key: const Key('dict-speak'),
          onTap: () => g.audio.say(g.audio.tpl('vnWord', w)),
          radius: 999,
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🔊', style: TextStyle(fontSize: 26)),
          ),
        ),
        // Ba ô 90 + khe vừa sát 320dp → thu nhỏ nhẹ thay vì tràn 2px.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: [
            _slot('c', pc, slot),
            _slot('v', pv == null ? null : (pt != null ? placeTone(pv!, pt!) : pv), slot),
            _slot('t', pt, slot, tone: true),
          ]),
        ),
        SizedBox(
          height: vwClamp(context, 48, 8, 80) * 1.15,
          child: Text(_shown, key: const Key('dict-word'), style: TextStyle(fontSize: vwClamp(context, 48, 8, 80), fontWeight: FontWeight.w800, height: 1.1, color: AppColors.ink)),
        ),
        Text(stepKey == null ? ' ' : g.i18n.t({'c': 'stepC', 'v': 'stepV', 't': 'stepT'}[stepKey]!),
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft, fontSize: baseFontSize(context))),
        LayoutBuilder(builder: (context, box) {
          const gap = 8.0;
          final kw = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final x in keys)
              SizedBox(
                key: ValueKey('dkey-$stepKey-$x'),
                width: kw,
                child: Chunky(
                  onTap: () => _key(x),
                  radius: 18,
                  depth: 5,
                  child: SizedBox(
                    height: short ? 54 : 64,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(stepKey == 't' ? placeTone(pv ?? '', x) : x,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ]),
      if (reward)
        _RewardCard(child: RewardContent(img: _s(w['img']), big: _s(w['w']))),
    ]);
  }

  Widget _slot(String k, String? val, double size, {bool tone = false}) {
    final on = val != null;
    final isBad = bad.contains(k);
    return ShakeOnce(
      trigger: isBad ? badGen : -1,
      child: Chunky(
        key: Key('dslot-$k'),
        onTap: () => _clear(k),
        radius: 22,
        depth: 5,
        color: isBad ? const Color(0xFFFFE3E3) : Colors.white,
        child: Container(
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: tone && on
              ? ToneMark(val, size: size * .5)
              : Text(val ?? '?', style: TextStyle(fontSize: tone ? 22 : size * 48 / 90, fontWeight: FontWeight.w800, color: on ? AppColors.ink : const Color(0xFFC7D3E3))),
        ),
      ),
    );
  }
}

// =================================================================================================================
// Bé đọc to: nhận giọng (nếu máy hỗ trợ) hoặc bố mẹ chấm

/// Nhận giọng nói: bọc speech_to_text để test thay được.
abstract class Recognizer {
  /// Khởi động (xin quyền micro + nhận giọng). false = máy không hỗ trợ / bị từ chối.
  Future<bool> init();

  /// Nghe một lần (tiếng Việt); onResult nhận các phương án nhận được.
  Future<void> listen({required void Function(List<String> alts) onResult, required void Function() onError, required void Function() onEnd});
  Future<void> stop();
}

class SpeechRecognizer implements Recognizer {
  final SpeechToText _stt = SpeechToText();
  void Function()? _onError, _onEnd;
  bool _ok = false;

  /// Kênh native (MainActivity.kt / AppDelegate.swift): máy có nhận giọng tiếng Việt ngay trên máy không.
  static const _native = MethodChannel('bvh/speech');

  @override
  Future<bool> init() async {
    // Chỉ nhận giọng trên máy, không gửi giọng bé lên máy chủ (chính sách app trẻ em). Android thiếu bộ nhận tại chỗ thì
    // speech_to_text âm thầm dùng bản qua mạng, nên phải hỏi trước; không có thì coi như máy không nghe được (bố mẹ chấm).
    try {
      if (await _native.invokeMethod<bool>('onDeviceAvailable') != true) return _ok = false;
    } catch (_) {
      return _ok = false;
    }
    try {
      _ok = await _stt.initialize(
        onError: (SpeechRecognitionError e) => _onError?.call(),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _onEnd?.call();
        },
      );
    } catch (_) {
      _ok = false;
    }
    return _ok;
  }

  @override
  Future<void> listen({required void Function(List<String> alts) onResult, required void Function() onError, required void Function() onEnd}) async {
    _onError = onError;
    _onEnd = onEnd;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          if (!r.finalResult) return;
          onResult(r.alternates.map((a) => a.recognizedWords).toList());
        },
        listenOptions: SpeechListenOptions(localeId: 'vi_VN', onDevice: true, partialResults: false, cancelOnError: true, listenFor: const Duration(seconds: 8), pauseFor: const Duration(seconds: 3)),
      );
    } catch (_) {
      onError();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.cancel();
    } catch (_) {/* bỏ qua */}
  }
}

const String kMicKey = 'bvh.micOK';

String _norm(String s) => nfc(s.toLowerCase()).replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ');

class AloudView extends StatefulWidget {
  const AloudView({super.key, required this.ctx});
  final GameContext ctx;

  /// Test thay bộ nhận giọng.
  @visibleForTesting
  static Recognizer Function()? debugRecognizer;

  @override
  State<AloudView> createState() => _AloudViewState();
}

class _AloudViewState extends State<AloudView> {
  GameContext get g => widget.ctx;
  late final List<Json> words = sample(g.content.list('vnwords'), 6);
  late final Recognizer rec = AloudView.debugRecognizer?.call() ?? SpeechRecognizer();
  bool recReady = false;
  int i = 0;
  bool started = false, done = false, listening = false, micShown = true;
  String status = '';
  bool get dead => !mounted || g.aborted;
  String? get micPref => g.store.getKv(kMicKey);

  /// Bố mẹ đã chọn "Không bật" thì như máy không có micro.
  late final bool useMic = micPref != '0';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    if (listening) rec.stop();
    super.dispose();
  }

  Future<void> _start() async {
    if (dead) return;
    g.hideBuddy();
    await g.audio.sayPhrase(useMic ? 'aloudIntro' : 'aloudParent');
    if (dead) return;
    _word();
  }

  void _word() {
    g.progress(i, words.length);
    setState(() {
      started = true;
      done = false;
      listening = false;
      micShown = useMic;
      status = useMic ? '' : g.i18n.t('micOff');
    });
  }

  Future<void> _win() async {
    if (done) return;
    done = true;
    if (listening) rec.stop();
    g.audio.sfx('correct');
    g.cheer();
    await g.audio.say(_praise(g));
    _next();
  }

  void _skip() {
    if (done) return;
    done = true;
    if (listening) rec.stop();
    _next();
  }

  void _next() {
    if (dead) return;
    if (i + 1 >= words.length) {
      g.progress(words.length, words.length);
      g.finish(3);
      return;
    }
    i++;
    _word();
  }

  /// Hỏi bố mẹ một lần trước lần bấm micro đầu tiên (giọng bé chỉ được nhận ngay trên máy).
  Future<bool> _consent() async {
    if (micPref == '1') return true;
    final en = g.i18n.isEn;
    final yes = await showPanel<bool>(
      context: context,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        PanelTitle(en ? '🎤 Turn on the microphone?' : '🎤 Bật micro?'),
        NoteText(en
            ? 'Your child\'s voice is recognized right on this device and is never sent anywhere. Bé Vui Học does not record or keep your child\'s voice.'
            : 'Giọng của bé được nhận ngay trên máy này, không gửi đi đâu. Bé Vui Học không ghi âm và không lưu giọng của bé.'),
        const SizedBox(height: 8),
        NoteText(en ? 'If you say no, listen to your child and tap “Correct”.' : 'Không bật thì bố mẹ nghe bé đọc rồi bấm “Đúng rồi”.'),
        PanelRow(children: [
          AppButton(key: const Key('mic-yes'), label: en ? 'Parents agree' : 'Bố mẹ đồng ý', variant: BtnVariant.green, onTap: () => Navigator.pop(c, true)),
          AppButton(key: const Key('mic-no'), label: en ? 'Not now' : 'Không bật', variant: BtnVariant.ghostPanel, onTap: () => Navigator.pop(c, false)),
        ]),
      ]),
    );
    if (!mounted) return false;
    if (yes == true) {
      if (!await g.gate(context)) return false;
    }
    g.store.setKv(kMicKey, yes == true ? '1' : '0');
    return yes == true;
  }

  Future<void> _mic() async {
    if (done || listening) return;
    final my = i;
    if (!await _consent()) {
      if (!mounted) return;
      setState(() {
        micShown = false;
        status = g.i18n.t('micOff');
      });
      return;
    }
    if (dead || done || my != i) return;
    if (!recReady) {
      recReady = await rec.init();
      if (dead || my != i) return;
      if (!recReady) {
        setState(() => status = g.i18n.t('micNA'));
        return;
      }
    }
    g.audio.stopVoice();
    setState(() {
      listening = true;
      status = g.i18n.t('listening');
    });
    final target = _norm(_s(words[my]['w'])).trim();
    await rec.listen(
      onResult: (alts) {
        if (dead || my != i || done) return;
        final norm = alts.map(_norm).toList();
        if (norm.any((a) => a.split(RegExp(r'\s+')).contains(target))) {
          _win();
        } else {
          setState(() => status = '“${norm.isEmpty ? '' : norm.first.trim()}”');
          g.audio.sfx('wrong');
          g.audio.sayPhrase('aloudTry');
        }
      },
      onError: () {
        if (!dead && my == i) setState(() => status = g.i18n.t('micNA'));
      },
      onEnd: () {
        if (!dead) setState(() => listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!started) return const SizedBox();
    final w = words[i];
    final short = MediaQuery.sizeOf(context).height < 560;
    return _FitColumn(spacing: short ? 10 : 16, maxWidth: 700, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: kCardShadow),
        child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, spacing: 20, children: [
          EmojiImage(_s(w['img']), size: vwClamp(context, 100, 16, 150)),
          Text(_s(w['w']), key: const Key('aloud-word'), style: TextStyle(fontSize: vwClamp(context, 64, 11, 110), fontWeight: FontWeight.w800, color: AppColors.ink)),
        ])),
      ),
      if (micShown)
        Pulse(
          on: listening,
          scale: 1.08,
          child: Chunky(
            key: const Key('aloud-mic'),
            onTap: _mic,
            radius: 55,
            depth: 8,
            color: listening ? AppColors.good : AppColors.bad,
            shadowColor: listening ? AppColors.goodDark : const Color(0xFFC92A2A),
            child: const SizedBox(width: 110, height: 110, child: Center(child: Text('🎤', style: TextStyle(fontSize: 52)))),
          ),
        ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, minHeight: 24),
        child: Text(status, key: const Key('aloud-status'), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkSoft, fontSize: baseFontSize(context))),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(999)),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
          Text(g.i18n.t('parentCheck'), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          _smallBtn(const Key('aloud-ok'), '✔ ${g.i18n.t('correct')}', _win, good: true),
          _smallBtn(const Key('aloud-again'), '🔊', () => g.audio.say(g.audio.tpl('vnWord', w))),
          _smallBtn(const Key('aloud-skip'), '${g.i18n.t('skip')} ➜', _skip),
        ]),
      ),
    ]);
  }

  Widget _smallBtn(Key key, String label, VoidCallback onTap, {bool good = false}) => Chunky(
        key: key,
        onTap: onTap,
        radius: 999,
        depth: 0,
        color: good ? const Color(0xFFD3F9D8) : const Color(0xFFEEF3F9),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 46,
          child: Center(
            widthFactor: 1,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: good ? const Color(0xFF1B7A35) : AppColors.ink)),
          ),
        ),
      );
}
