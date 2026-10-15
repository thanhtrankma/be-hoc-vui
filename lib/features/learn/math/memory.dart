// Đảo Trí nhớ: lật thẻ tìm cặp.
// CHỦ: agent B. Port của reference/web/js/games/memory.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (memoryModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule memoryModule = MemoryGame();`).
final GameModule memoryModule = const PlaceholderGame('memory', owner: 'B', webFile: 'memory.js');
