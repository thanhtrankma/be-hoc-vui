// Đảo Chữ cái và Tiếng Anh: nghe rồi chọn đúng chữ / hình.
// CHỦ: agent A. Port của web js/games/pick.js.
import 'package:flutter/material.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

import 'quiz.dart';

final GameModule pickModule = PickGame();

class PickGame extends GameModule {
  @override
  String get id => 'pick';
  @override
  Widget build(BuildContext context, GameContext ctx) => PickView(ctx: ctx);
}

class PickView extends StatefulWidget {
  const PickView({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<PickView> createState() => _PickViewState();
}

class _PickViewState extends State<PickView> {
  late final List<QuizQuestion> qs = widget.ctx.islandId == 'letters'
      ? letterQuestions(widget.ctx, widget.ctx.levelIndex)
      : englishQuestions(widget.ctx, widget.ctx.levelIndex);
  @override
  Widget build(BuildContext context) => QuizView(ctx: widget.ctx, questions: qs, onDone: widget.ctx.finish);
}

/// Từ ví dụ cho mỗi chữ: lấy ngẫu nhiên trong letterWords (nhiều từ) để mỗi lần học một khác.
Json _wordFor(Content content, String ch) {
  final ws = content.list('letterWords').where((w) => w['ch'] == ch).toList();
  if (ws.isEmpty) {
    final l = content.list('letters').firstWhere((l) => l['ch'] == ch, orElse: () => {'ch': ch});
    return {...l, 'tplKey': 'letterWord'};
  }
  return {...sample(ws, 1).first, 'tplKey': 'letterWord2'};
}

VoiceLine? _letterRewardSay(GameContext g, Json w) => g.audio.tpl(w['tplKey'] as String, w);
WidgetBuilder _letterRewardNode(Json w) =>
    (context) => RewardContent(img: w['img'] as String?, big: w['ch'] as String?, small: w['word'] as String?);

QuizChoice _txt(String x) => QuizChoice(id: x, text: x, node: (_) => Text(x));

List<QuizQuestion> letterQuestions(GameContext g, int li) {
  final content = g.content;
  final lv = content.level('letterLevels', li) ?? const {};
  final letters = content.list('letters');
  final by = {for (final l in letters) l['ch'] as String: l};
  final all = letters.map((l) => l['ch'] as String).toList();
  final isAll = lv['targets'] == 'all';
  final targets = isAll ? all : asStrList(lv['targets']);
  final pool = isAll ? all : [...targets, ...asStrList(lv['extra'])];
  final n = asInt(lv['choices'], li < 2 ? 3 : 4);
  List<String> others(String ch) => sample(pool.where((x) => x != ch), n - 1);
  final kind = lv['kind'];
  // Nhìn hình (nghe tên) chọn chữ đầu tiên của từ.
  if (kind == 'initial') {
    final ws = content.list('letterWords').where((w) => w['first'] == true && targets.contains(w['ch'])).toList();
    return sequence(ws, kRound).map((w0) {
      final w = {...w0, 'tplKey': 'letterWord2'};
      final ch = w['ch'] as String;
      return QuizQuestion(
        say: g.audio.tpl('initialQ', w),
        label: g.i18n.t('initialQ'),
        stage: (_) => QuizWordPic(w['img'] as String),
        choices: shuffle([ch, ...others(ch)]).map(_txt).toList(),
        answer: ch,
        reward: _letterRewardSay(g, w),
        rewardNode: _letterRewardNode(w),
      );
    }).toList();
  }
  // Thấy chữ in hoa, tìm chữ thường tương ứng.
  final upper = kind == 'upper';
  return sequence(targets, kRound).map((ch) {
    final w = _wordFor(content, ch);
    return QuizQuestion(
      say: g.audio.tpl('findLetter', by[ch] ?? {'ch': ch}),
      label: upper ? ch.toUpperCase() : g.i18n.t('findLetter'),
      labelStyle: upper ? 'upper' : null,
      choices: shuffle([ch, ...others(ch)]).map(_txt).toList(),
      answer: ch,
      reward: _letterRewardSay(g, w),
      rewardNode: _letterRewardNode(w),
    );
  }).toList();
}

/// Mặt thẻ tiếng Anh: hình, chấm màu hoặc chữ số.
Widget enFace(Json item) {
  if (item['img'] != null) return QuizImg(item['img'] as String);
  if (item['color'] != null) return Swatch(parseColor(item['color'] as String?));
  return Text('${item['digit'] ?? item['en']}');
}

List<QuizQuestion> englishQuestions(GameContext g, int li) {
  final content = g.content;
  final lv = content.level('englishLevels', li) ?? const {};
  final set = content.list(lv['set'] as String? ?? '');
  return sequence(set, kRound).map((item) {
    final prompt = g.audio.tpl(lv['tpl'] as String? ?? 'wordEn', item);
    return QuizQuestion(
      say: prompt,
      label: prompt?.text,
      choices: shuffle([item, ...sample(set.where((x) => x['id'] != item['id']), 3)])
          .map((x) => QuizChoice(id: x['id'] as Object, text: x['en'] as String?, node: (_) => enFace(x)))
          .toList(),
      answer: item['id'] as Object,
      reward: g.audio.tpl('wordEn', item),
      rewardNode: (context) => RewardContent(imgWidget: _RewardFace(item), big: item['en'] as String?),
    );
  }).toList();
}

class _RewardFace extends StatelessWidget {
  const _RewardFace(this.item);
  final Json item;
  @override
  Widget build(BuildContext context) {
    if (item['img'] != null) return EmojiImage(item['img'] as String, size: vwClamp(context, 140, 22, 220));
    if (item['color'] != null) return Swatch(parseColor(item['color'] as String?), size: vwClamp(context, 120, 18, 180));
    return Text('${item['digit']}', style: TextStyle(fontSize: vwClamp(context, 80, 12, 140), fontWeight: FontWeight.w800, height: 1));
  }
}
