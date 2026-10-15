// Đảo Đọc truyện: truyện, đọc từ, xếp câu, đọc to (speech_to_text, khoá bố mẹ trước khi bật micro).
// CHỦ: agent A. Port của reference/web/js/games/read.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (readModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule readModule = ReadGame();`).
final GameModule readModule = const PlaceholderGame('read', owner: 'A', webFile: 'read.js');
