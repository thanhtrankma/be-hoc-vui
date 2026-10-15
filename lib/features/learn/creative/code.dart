// Đảo Lập trình: điều khiển robot bằng lệnh.
// CHỦ: agent C. Port của reference/web/js/games/code.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (codeModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule codeModule = CodeGame();`).
final GameModule codeModule = const PlaceholderGame('code', owner: 'C', webFile: 'code.js');
