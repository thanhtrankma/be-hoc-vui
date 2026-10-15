// Đảo Ghép vần: dấu thanh, âm đầu, vần, ghép tiếng, nghe đánh vần, đọc từ, xếp câu, chính tả, đọc câu, điền từ.
// CHỦ: agent A. Port của reference/web/js/games/spell.js. placeTone() ở core/content/vn_text.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/content/vn_text.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'fx.dart';
import 'quiz.dart';

export 'package:be_vui_hoc/core/content/vn_text.dart' show placeTone;

final GameModule spellModule = SpellGame();

class SpellGame extends GameModule {
  @override
  String get id => 'spell';
  @override
  Widget build(BuildContext context, GameContext ctx) => SpellView(ctx: ctx);
}

/// Câu dẫn theo loại bài (KINDS của web).
const Map<String, String> kSpellIntro = {
  'rule': 'ruleQ',
  'readsent': 'readSentQ',
  'cloze': 'clozeQ',
  'readword': 'readWordQ',
  'sentence': 'sentIntro',
  'tone': 'toneQ',
  'onset': 'onsetQ',
  'rime': 'rimeQ',
  'build': 'onsetQ',
  'listen': 'listenQ',
};

class SpellView extends StatefulWidget {
  const SpellView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<SpellView> createState() => _SpellViewState();
}

class _SpellViewState extends State<SpellView> {
  late final Json lv = widget.ctx.level ?? const {};
  late final List<QuizQuestion> qs = spellQuestions(widget.ctx, lv);
  @override
  Widget build(BuildContext context) => QuizView(
        ctx: widget.ctx,
        questions: qs,
        options: QuizOptions(intro: kSpellIntro[lv['kind']], combo: true, minRewardMs: 800, fly: true),
        onDone: widget.ctx.finish,
      );
}

const List<String> _vowels1 = ['a', 'ă', 'â', 'e', 'ê', 'i', 'o', 'ô', 'ơ', 'u', 'ư'];

/// Âm dễ lẫn chính tả: không đưa làm lựa chọn sai của nhau.
const Map<String, List<String>> _twins = {
  'c': ['k', 'q'],
  'k': ['c', 'q'],
  'g': ['gh'],
  'gh': ['g'],
  'ng': ['ngh'],
  'd': ['gi'],
};

String _s(Object? v) => v?.toString() ?? '';

/// Tiếng theo bài: lv.words (bài sách), lv.rimes (nhóm vần), pool 'all' / 'rime' (vần nhiều chữ) / mặc định (vần một chữ).
List<Json> spellPool(Content content, Json lv) {
  final words = lv['words'] is List ? asStrList(lv['words']) : null;
  final rimes = lv['rimes'] is List ? asStrList(lv['rimes']) : null;
  return content.list('vnwords').where((w) {
    final v = _s(w['v']);
    if (words != null) return words.contains(w['w']);
    if (rimes != null) return rimes.contains(v);
    return lv['pool'] == 'all' || (lv['pool'] == 'rime' ? v.length > 1 : v.length == 1);
  }).toList();
}

Json? _know(Json lv) => lv['know'] is Map ? asMap(lv['know']) : null;

List<Json> _knownWords(Content content, Json lv) {
  final k = _know(lv);
  if (k == null) return [];
  final c = asStrList(k['c']), v = asStrList(k['v']), t = asStrList(k['t']);
  return content.list('vnwords').where((w) => c.contains(w['c']) && v.contains(w['v']) && t.contains(w['tone'])).toList();
}

String _syll(Json w, String tone) => _s(w['c']) + placeTone(_s(w['v']), tone);

QuizChoice _txt(String x) => QuizChoice(id: x, text: x, node: (_) => Text(x));
QuizChoice _pic(Json x) => QuizChoice(id: x['id'] as Object, node: (_) => QuizImg(_s(x['img'])));

// ---- Thẻ thưởng đánh vần nhanh: chữ sáng lần lượt theo nhịp "bờ o bo, huyền bò!" ----

/// Nhịp tương đối của từng phần (phần trước dấu phẩy và tiếng cuối dài hơn).
const Map<int, List<double>> _beats = {
  5: [1, 1, 1.35, 1, 1.25],
  3: [1, 1.3, 1.25],
};

/// Thẻ đánh vần: hình + "b + o → bo + ` → bò", các phần sáng dần theo độ dài câu đọc (giây).
class SpellCard extends StatelessWidget {
  const SpellCard({super.key, required this.w, required this.seconds});
  final Json w;
  final double seconds;
  @override
  Widget build(BuildContext context) {
    final toned = w['tone'] != 'ngang';
    final parts = <(String, Object)>[
      ('on', _s(w['c'])),
      ('rime', _s(w['v'])),
      if (toned) ('base', _s(w['base'])),
      if (toned) ('tone', _s(w['tone'])),
      ('word', _s(w['w'])),
    ];
    final seps = toned ? ['+', '→', '+', '→'] : ['+', '→'];
    final beats = _beats[parts.length] ?? List.filled(parts.length, 1.0);
    final sum = beats.fold<double>(0, (a, b) => a + b);
    final total = (seconds > 0 ? seconds : 1.2) * 1000;
    final at = <double>[];
    var t = 0.0;
    for (var k = 0; k < parts.length; k++) {
      at.add(t);
      t += total * beats[k] / sum;
    }
    final spFont = vwClamp(context, 28, 7.4, 56);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      EmojiImage(_s(w['img']), size: vwClamp(context, 110, 17, 170)),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.min(MediaQuery.sizeOf(context).width * .92, 640)),
        child: OneShot(
          key: const Key('spell-line'),
          duration: Duration(milliseconds: (total + 450).round()),
          builder: (context, prog, _) {
            final ms = prog * (total + 450);
            final children = <Widget>[];
            for (var k = 0; k < parts.length; k++) {
              final lit = ms >= at[k];
              if (k > 0) children.add(_SpSep(seps[k - 1], lit: lit));
              children.add(_SpPart(kind: parts[k].$1, value: parts[k].$2, lit: lit, litT: lit ? ((ms - at[k]) / (parts[k].$1 == 'word' ? 450 : 320)).clamp(0.0, 1.0) : 0, font: spFont));
            }
            return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: children);
          },
        ),
      ),
    ]);
  }
}

class _SpSep extends StatelessWidget {
  const _SpSep(this.t, {required this.lit});
  final String t;
  final bool lit;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: lit ? 1 : .28,
        duration: const Duration(milliseconds: 150),
        child: Text(t, style: TextStyle(fontSize: vwClamp(context, 18, 4, 32), fontWeight: FontWeight.w800, color: const Color(0xFFADB5BD))),
      );
}

class _SpPart extends StatelessWidget {
  const _SpPart({required this.kind, required this.value, required this.lit, required this.litT, required this.font});
  final String kind;
  final Object value;
  final bool lit;
  final double litT;
  final double font;
  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      'on' => const Color(0xFF1971C2),
      'rime' => const Color(0xFFE8590C),
      'tone' => const Color(0xFF9C36B5),
      'word' => AppColors.ink,
      _ => const Color(0xFF5C6B80),
    };
    final size = kind == 'word' ? vwClamp(context, 44, 11, 88) : font;
    final bg = !lit
        ? (kind == 'word' ? const Color(0xFFFFF9DB) : const Color(0xFFF1F5FB))
        : (kind == 'word' ? const Color(0xFFFFE066) : const Color(0xFFE7FBE9));
    final Widget inner = kind == 'tone'
        ? SizedBox(height: font * 1.1, child: Center(widthFactor: 1, child: ToneMark('$value', size: vwClamp(context, 20, 4.6, 38), color: color)))
        : Text('$value', style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.1, color: color));
    // spLit: 50% scale 1.22; spWord: 40% scale 1.3 xoay -3°.
    final bump = math.sin(litT * math.pi);
    final scale = lit ? 1 + (kind == 'word' ? .3 : .22) * bump : .9;
    return Opacity(
      opacity: lit ? 1 : .28,
      child: Transform.rotate(
        angle: kind == 'word' ? -3 * bump * math.pi / 180 : 0,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: inner,
          ),
        ),
      ),
    );
  }
}

const List<String> _praiseKeys = ['praise1', 'praise2', 'praise3', 'praise4', 'praise5', 'praise6'];

QuizReward _fastSpell(GameContext g, Json w) =>
    QuizReward(say: [g.audio.tpl('spellFast', w)], timedNode: (context, dur) => SpellCard(w: w, seconds: dur), minMs: 700);

QuizReward _wordPraise(GameContext g, Json w) => QuizReward(
      say: [g.audio.tpl('vnSay', w), g.audio.praiseItem()],
      node: (context) => RewardContent(img: _s(w['img']), big: _s(w['w'])),
      minMs: 700,
    );

/// Đánh vần nhanh khi bé vừa chọn sai, ở bước cuối Ghép tiếng, và xen kẽ câu đúng; còn lại đọc tiếng + lời khen.
QuizReward Function({required bool missed, required int streak}) _spellReward(GameContext g, Json w, [bool always = false]) =>
    ({required bool missed, required int streak}) => always || missed || streak % 2 == 1 ? _fastSpell(g, w) : _wordPraise(g, w);

List<VoiceLine> _preWord(GameContext g, Json w) =>
    [g.audio.tpl('spellFast', w), g.audio.tpl('vnSay', w), ..._praiseKeys.map(g.audio.phrase)].whereType<VoiceLine>().toList();

Widget _wordStage(Json w, List<Widget> show) => QuizWordRow(children: [QuizWordPic(_s(w['img'])), QuizWordShow(children: show)]);

List<QuizQuestion> _toneQ(GameContext g, Json lv) {
  final tones = asStrList(lv['tones']);
  final n = asInt(lv['choices'], 3);
  final pool = spellPool(g.content, lv).where((w) => tones.contains(w['tone'])).toList();
  return sequence(pool, kRound).map((w) {
    final others = shuffle(tones.where((t) => t != w['tone']));
    final extra = shuffle(kTones.where((t) => !tones.contains(t)));
    final opts = shuffle([_s(w['tone']), ...[...others, ...extra].take(n - 1)]);
    return QuizQuestion(
      say: g.audio.tpl('vnAsk', w),
      stage: (_) => QuizWordPic(_s(w['img'])),
      choices: opts.map((t) => QuizChoice(id: t, text: _syll(w, t), node: (_) => Text(_syll(w, t)))).toList(),
      cls: 'syll',
      cols: n > 4 ? 3 : n,
      answer: _s(w['tone']),
      pickReward: _spellReward(g, w),
      preload: _preWord(g, w),
    );
  }).toList();
}

List<String> _onsetChoices(Content content, Json w, int n, Json lv) {
  final ban = {_s(w['c']), ...?_twins[w['c']]};
  final cons = content.strings('consonants');
  final k = _know(lv);
  final known = k != null ? asStrList(k['c']).where((c) => cons.contains(c) && !ban.contains(c)).toList() : <String>[];
  // Bài đầu (mới học 1-2 âm): bớt số lựa chọn chứ không bày âm chưa học.
  if (k != null && known.isNotEmpty) return shuffle([_s(w['c']), ...sample(known, math.min(n - 1, known.length))]);
  return shuffle([_s(w['c']), ...sample(cons.where((c) => !ban.contains(c)), n - 1)]);
}

List<String> _rimeChoices(Content content, Json w, int n, Json lv) {
  final k = _know(lv);
  final v = _s(w['v']), tone = _s(w['tone']);
  final tones = k != null ? asStrList(k['t']) : kTones;
  final sameV = tones.where((t) => t != tone).map((t) => placeTone(v, t)).toList();
  // Vần khác cùng dấu: ưu tiên vần đầu giống (an/ang/anh/at…), rồi mới tới vần bất kỳ.
  final knownV = k != null ? asStrList(k['v']).where((r) => r != v).toList() : <String>[];
  final others = knownV.length >= 3 ? knownV : [...content.strings('rimes'), ..._vowels1].where((r) => r != v).toList();
  final near = others.where((r) => r.isNotEmpty && v.isNotEmpty && (r[0] == v[0] || r.length == v.length));
  final sameT = sample({...near, ...others}.map((r) => placeTone(r, tone)), n);
  final out = <String>{_s(w['vt']), ...sample(sameV, ((n - 1) / 2).ceil()), ...sameT.take((n - 1) ~/ 2)};
  // Thiếu (trùng chữ) thì bù vần khác để đủ số thẻ.
  for (final r in sameT) {
    if (out.length >= math.max(n, 3)) break;
    out.add(r);
  }
  return shuffle(out).take(math.max(n, 3)).toList();
}

List<QuizQuestion> _onsetQ(GameContext g, Json lv) {
  final n = asInt(lv['choices'], 3);
  return sequence(spellPool(g.content, lv), kRound).map((w) => QuizQuestion(
        say: g.audio.tpl('vnAsk', w),
        stage: (_) => _wordStage(w, [const QuizBlank(), Text(_s(w['vt']))]),
        choices: _onsetChoices(g.content, w, n, lv).map(_txt).toList(),
        cls: 'syll',
        answer: _s(w['c']),
        pickReward: _spellReward(g, w),
        preload: _preWord(g, w),
      )).toList();
}

List<QuizQuestion> _rimeQ(GameContext g, Json lv) {
  final n = asInt(lv['choices'], 3);
  return sequence(spellPool(g.content, lv), kRound).map((w) => QuizQuestion(
        say: g.audio.tpl('vnAsk', w),
        stage: (_) => _wordStage(w, [Text(_s(w['c'])), const QuizBlank()]),
        choices: _rimeChoices(g.content, w, n, lv).map(_txt).toList(),
        cls: 'syll',
        answer: _s(w['vt']),
        pickReward: _spellReward(g, w),
        preload: _preWord(g, w),
      )).toList();
}

/// Ghép tiếng: mỗi từ 2 bước (chọn âm đầu rồi chọn vần), cuối cùng nghe đánh vần.
List<QuizQuestion> _buildQ(GameContext g, Json lv) {
  final n = asInt(lv['choices'], 3);
  return sample(spellPool(g.content, lv), kRound ~/ 2).expand((w) => [
        QuizQuestion(
          say: g.audio.tpl('vnAsk', w),
          stage: (_) => _wordStage(w, [const QuizBlank(slot: 0), const QuizBlank(slot: 1)]),
          choices: _onsetChoices(g.content, w, n, lv).map(_txt).toList(),
          cls: 'syll',
          answer: _s(w['c']),
        ),
        // Bước 2 đã nghe đề ở bước 1: chỉ nhắc lại tiếng cho gọn.
        QuizQuestion(
          say: g.audio.tpl('vnSay', w),
          stage: (_) => _wordStage(w, [Text(_s(w['c'])), const QuizBlank()]),
          choices: _rimeChoices(g.content, w, n, lv).map(_txt).toList(),
          cls: 'syll',
          answer: _s(w['vt']),
          pickReward: _spellReward(g, w, true),
          preload: _preWord(g, w),
        ),
      ]).toList();
}

/// Hình gây nhiễu: ưu tiên tiếng cùng nhóm vần của bài, thiếu thì lấy thêm từ cả kho; không trùng hình,
/// không lấy hình cùng nhóm dễ lẫn với đáp án (content.confuse: hoa/bông/sen, tàu/thuyền…).
List<Json> _distractors(Content content, Json lv, Json w, int n) {
  final seen = <String>{_s(w['img'])};
  final out = <Json>[];
  final grp = <String>{
    for (final gr in (content['confuse'] as List? ?? const []))
      if (gr is List && gr.contains(w['w'])) ...gr.map((e) => '$e'),
  };
  void add(List<Json> list) {
    for (final x in shuffle(list)) {
      if (out.length >= n) break;
      if (!seen.contains(_s(x['img'])) && !grp.contains(x['w'])) {
        seen.add(_s(x['img']));
        out.add(x);
      }
    }
  }

  final all = content.list('vnwords');
  add(spellPool(content, lv));
  add(_knownWords(content, lv));
  add(all.where((x) => lv['pool'] != 'rime' || _s(x['v']).length > 1).toList());
  add(all);
  return out;
}

List<QuizQuestion> _listenQ(GameContext g, Json lv) {
  final n = asInt(lv['choices'], 3);
  return sequence(spellPool(g.content, lv), kRound).map((w) => QuizQuestion(
        say: g.audio.tpl('spell', w),
        label: '🔤',
        choices: shuffle([w, ..._distractors(g.content, lv, w, n - 1)]).map(_pic).toList(),
        // Đề đã là đánh vần: thưởng chỉ đọc tiếng + lời khen.
        answer: w['id'] as Object,
        pickReward: ({required bool missed, required int streak}) => _wordPraise(g, w),
        preload: _preWord(g, w),
      )).toList();
}

/// Đọc từ hai tiếng (không đọc to đề, bé tự đọc) rồi chọn hình. Bài "hard": các lựa chọn chung một tiếng.
List<QuizQuestion> _readWordQ(GameContext g, Json lv) {
  final all = g.content.list('twoWords');
  final n = asInt(lv['choices'], 4);
  return sample(all, kRound).map((w) {
    final parts = _s(w['w']).split(' ');
    final first = parts.first, second = parts.length > 1 ? parts[1] : '';
    final share = all.where((x) => x != w && (_s(x['w']).startsWith('$first ') || _s(x['w']).endsWith(' $second'))).toList();
    final others = all.where((x) => x != w).toList();
    final wrong = lv['hard'] == true ? sample(share.length >= n - 1 ? share : others, n - 1) : sample(others, n - 1);
    return QuizQuestion(
      label: _s(w['w']),
      labelStyle: 'readword',
      choices: shuffle([w, ...wrong]).map(_pic).toList(),
      answer: w['id'] as Object,
      reward: g.audio.tpl('twoWord', w),
      rewardNode: rewardOf(img: _s(w['img']), big: _s(w['w'])),
    );
  }).toList();
}

Widget _sentStage(Json st, List<Widget> words) =>
    QuizWordRow(children: [QuizWordPic(_s(st['img'])), QuizSent(children: words)]);

WidgetBuilder _sentReward(Json st) =>
    (context) => RewardContent(img: _s(st['img']), big: _s(st['t']), bigSize: vwClamp(context, 34, 6, 60));

/// Xếp chữ thành câu: mỗi lần chạm chọn chữ tiếp theo, câu hiện dần; xong thì đọc cả câu.
List<QuizQuestion> _sentenceQ(GameContext g, Json lv) {
  final long = asInt(lv['max']) >= 5;
  final pool = g.content.list('sentences').where((x) => long ? asStrList(x['words']).length >= 5 : asStrList(x['words']).length <= 4).toList();
  return sample(pool, long ? 4 : 5).expand((st) {
    final words = asStrList(st['words']);
    return [
      for (var i = 0; i < words.length; i++)
        QuizQuestion(
          stage: (_) => _sentStage(st, [for (var k = 0; k < words.length; k++) k < i ? Text(words[k]) : QuizBlank(slot: k, minWidthEm: 1.6)]),
          choices: shuffle(words.sublist(i)).map(_txt).toList(),
          cls: 'syll words',
          answer: words[i],
          reward: i == words.length - 1 ? g.audio.tpl('sentence', st) : null,
          rewardNode: i == words.length - 1 ? _sentReward(st) : null,
        ),
    ];
  }).toList();
}

/// Chính tả c/k, g/gh, ng/ngh: nghe từ, nhìn hình, chọn cách viết đúng.
List<QuizQuestion> _ruleQ(GameContext g, Json lv) {
  final pool = g.content.list('ruleWords').where((w) => w['grp'] == lv['grp']).toList();
  return sequence(pool, kRound).map((w) => QuizQuestion(
        say: g.audio.tpl('ruleSay', w),
        stage: (_) => QuizWordPic(_s(w['img'])),
        choices: shuffle([_s(w['w']), _s(w['bad'])]).map(_txt).toList(),
        cls: 'syll words',
        answer: _s(w['w']),
        reward: g.audio.tpl('ruleSay', w),
        rewardNode: rewardOf(img: _s(w['img']), big: _s(w['w'])),
      )).toList();
}

/// Đọc câu (không đọc to), chọn hình đúng với câu.
List<QuizQuestion> _readSentQ(GameContext g, Json lv) {
  final all = g.content.list('sentences');
  final n = asInt(lv['choices'], 3);
  return sample(all, kRound).map((st) => QuizQuestion(
        label: _s(st['t']),
        labelStyle: 'readsent',
        choices: shuffle([st, ...sample(all.where((x) => x['img'] != st['img']), n - 1)]).map(_pic).toList(),
        answer: st['id'] as Object,
        reward: g.audio.tpl('sentence', st),
        rewardNode: _sentReward(st),
      )).toList();
}

/// Điền từ còn thiếu vào câu (bỏ trống một từ, không phải từ đầu câu).
List<QuizQuestion> _clozeQ(GameContext g, Json lv) {
  final all = g.content.list('sentences');
  final n = asInt(lv['choices'], 3);
  final pool = {for (final x in all) ...asStrList(x['words']).skip(1).map((w) => w.toLowerCase())}.toList();
  final rnd = math.Random();
  return sample(all, kRound).map((st) {
    final words = asStrList(st['words']);
    final k = 1 + rnd.nextInt(math.max(1, words.length - 1));
    final ans = words[k];
    final lower = words.map((x) => x.toLowerCase()).toSet();
    final wrong = sample(pool.where((w) => !lower.contains(w)), n - 1);
    return QuizQuestion(
      stage: (_) => _sentStage(st, [for (var i = 0; i < words.length; i++) i == k ? QuizBlank(slot: i, minWidthEm: 1.6) : Text(words[i])]),
      choices: shuffle([ans, ...wrong]).map(_txt).toList(),
      cls: 'syll words',
      answer: ans,
      reward: g.audio.tpl('sentence', st),
      rewardNode: _sentReward(st),
    );
  }).toList();
}

/// Dựng câu hỏi cho một bài Ghép vần (dùng lại được cho Học cùng lớp / ôn tập).
List<QuizQuestion> spellQuestions(GameContext g, Json lv) => switch (lv['kind']) {
      'tone' => _toneQ(g, lv),
      'onset' => _onsetQ(g, lv),
      'rime' => _rimeQ(g, lv),
      'build' => _buildQ(g, lv),
      'listen' => _listenQ(g, lv),
      'readword' => _readWordQ(g, lv),
      'sentence' => _sentenceQ(g, lv),
      'rule' => _ruleQ(g, lv),
      'readsent' => _readSentQ(g, lv),
      'cloze' => _clozeQ(g, lv),
      _ => const [],
    };
