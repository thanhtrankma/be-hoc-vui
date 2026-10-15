// ignore_for_file: prefer_initializing_formals
// Hợp đồng giữa khung màn chơi (PlayScreen) và từng trò chơi của các đảo học.
//
// Web: app.js play() dựng khung (thanh trên + stage + linh vật), rồi gọi mod.run(g, islandId, content, li) của
// games/<game>.js; run trả về Promise {stars} khi xong bài. Ở đây:
//   - GameModule.build(context, ctx) trả về widget vẽ trong vùng stage (dưới thanh trên).
//   - Trò chơi báo tiến độ bằng ctx.progress(i, n), vui/buồn bằng ctx.cheer()/ctx.sad(),
//     ghi từng câu bằng ctx.record(...), và XONG BÀI bằng ctx.finish(stars) (1..3 sao).
//   - Khung lo phần thưởng (sao, hình dán, vé, huy hiệu, thử thách ngày), nút quay lại, dừng giọng đọc.
import 'package:flutter/widgets.dart';

import '../audio/audio_service.dart';
import '../content/content.dart';
import '../i18n/i18n.dart';
import '../store/store.dart';

/// Một trò chơi của đảo học (pick, spell, count...). Mỗi lượt vào bài tạo widget mới (key mới khi "Chơi lại").
abstract class GameModule {
  const GameModule();

  /// Id game như web (island.game): 'pick', 'spell', 'count'...
  String get id;

  /// Vẽ nội dung bài li. Widget nên là StatefulWidget riêng của game, đọc mọi thứ từ ctx.
  Widget build(BuildContext context, GameContext ctx);
}

/// Kết quả bài. stars 1..3 (quiz: 0 lỗi = 3, ≤2 lỗi = 2, còn lại 1 — xem starsFor trong quiz).
class GameResult {
  const GameResult(this.stars, {this.extra = const {}});
  final int stars;
  final Map<String, Object?> extra;
}

/// Một câu đã trả lời (dùng cho Báo cáo bố mẹ và ôn tập ngắt quãng). Giống tham số q của g.record(q, picks, ms) ở web.
class QuizRecord {
  const QuizRecord({required this.answer, this.say, this.reward, this.picks = const [], this.ms = 0});

  /// Đáp án đúng (id lựa chọn: chữ, số, id mục...).
  final Object answer;

  /// Câu hỏi đã đọc và câu thưởng — dùng để tra ngược ra "mục học" (vd. vnwords:bò).
  final VoiceLine? say;
  final VoiceLine? reward;

  /// Các lựa chọn SAI bé đã chạm trước khi đúng (rỗng = đúng ngay).
  final List<Object> picks;

  /// Thời gian từ lúc hiện câu tới lúc đúng (ms).
  final int ms;
}

/// Mọi thứ một trò chơi cần. Tạo bởi PlayScreen; game không tự tạo.
class GameContext {
  GameContext({
    required this.island,
    required this.levelIndex,
    required this.level,
    required this.content,
    required this.data,
    required this.profile,
    required this.tier,
    required this.audio,
    required this.i18n,
    required this.store,
    required this.buddyImg,
    this.from,
    required bool Function() isAborted,
    required void Function(int i, int n) onProgress,
    required void Function(String anim) onBuddy,
    required void Function(bool visible) onBuddyVisible,
    required void Function(QuizRecord q) onRecord,
    required void Function(GameResult r) onFinish,
    required VoidCallback onExit,
    required Future<bool> Function(BuildContext context) onGate,
  })  : _isAborted = isAborted,
        _onProgress = onProgress,
        _onBuddy = onBuddy,
        _onBuddyVisible = onBuddyVisible,
        _onRecord = onRecord,
        _onFinish = onFinish,
        _onExit = onExit,
        _onGate = onGate;

  /// Đảo đang chơi (island.id: 'letters', 'english', 'count'...; island.game: id GameModule).
  final Island island;
  String get islandId => island.id;

  /// Chỉ số bài trong content[levelsKey] (li của web).
  final int levelIndex;

  /// Dữ liệu thô của bài (content[levelsKey][li]), vd. {"name": "1 – 3", "min": 1, "max": 3, "choices": 3, "tier": 1}.
  final Json? level;
  final Content content;
  final AppData data;

  /// Hồ sơ bé đang chơi (đọc; muốn ghi thì qua store rồi store.save()).
  final Profile profile;

  /// Cấp đang xem (1 Mầm, 2 Chồi, 3 Lớp 1, 0 = đảo không chia cấp).
  final int tier;
  final AudioService audio;
  final I18n i18n;
  final AppStore store;

  /// Hình linh vật của bé (tên emoji, vd. 'Robot').
  final String buddyImg;

  /// 'lop1' khi mở từ Học cùng lớp.
  final String? from;

  final bool Function() _isAborted;
  final void Function(int, int) _onProgress;
  final void Function(String) _onBuddy;
  final void Function(bool) _onBuddyVisible;
  final void Function(QuizRecord) _onRecord;
  final void Function(GameResult) _onFinish;
  final VoidCallback _onExit;
  final Future<bool> Function(BuildContext) _onGate;
  bool _finished = false;

  /// Bé đã rời màn (bấm quay lại): dừng mọi vòng lặp/đọc. Kiểm tra sau mỗi await.
  bool get aborted => _isAborted();

  /// Chấm tiến độ trên thanh trên: câu i (0-based) trong n câu. progress(n, n) = xong hết.
  void progress(int i, int n) => _onProgress(i, n);

  /// Linh vật nhảy mừng (đúng) / lắc đầu (sai).
  void cheer() => _onBuddy('cheer');
  void sad() => _onBuddy('sad');

  /// Ẩn/hiện linh vật góc dưới (game cần chỗ: vẽ, tập viết...).
  void hideBuddy() => _onBuddyVisible(false);
  void showBuddy() => _onBuddyVisible(true);

  /// Ghi kết quả một câu (khuôn quiz gọi). Không bao giờ làm hỏng bài nếu lỗi.
  void record(QuizRecord q) {
    try {
      _onRecord(q);
    } catch (_) {/* bỏ qua */}
  }

  /// Khoá bố mẹ (phép nhân). true = bố mẹ đã qua.
  Future<bool> gate(BuildContext context) => _onGate(context);

  /// Xong bài với số sao 1..3. Gọi một lần; lần sau bỏ qua.
  void finish(int stars, {Map<String, Object?> extra = const {}}) {
    if (_finished || aborted) return;
    _finished = true;
    _onFinish(GameResult(stars.clamp(1, 3), extra: extra));
  }

  /// Thoát bài không tính kết quả (như bấm nút quay lại).
  void exit() => _onExit();
}
