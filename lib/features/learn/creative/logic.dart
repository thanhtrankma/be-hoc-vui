// Đảo Tư duy: ghép bóng, dãy quy luật, mê cung, sudoku...
// CHỦ: agent C. Port của reference/web/js/games/logic.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (logicModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule logicModule = LogicGame();`).
final GameModule logicModule = const PlaceholderGame('logic', owner: 'C', webFile: 'logic.js');
