// Đảo Âm nhạc: đàn mộc cầm, bài hát, Simon. Âm thanh: ctx.audio.note(i).
// CHỦ: agent B. Port của reference/web/js/games/music.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (musicModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule musicModule = MusicGame();`).
final GameModule musicModule = const PlaceholderGame('music', owner: 'B', webFile: 'music.js');
