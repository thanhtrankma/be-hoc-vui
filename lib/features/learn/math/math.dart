// Đảo Toán vui: cộng trừ, so sánh, đồng hồ, hình khối, lời văn.
// CHỦ: agent B. Port của reference/web/js/games/math.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (mathModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule mathModule = MathGame();`).
final GameModule mathModule = const PlaceholderGame('math', owner: 'B', webFile: 'math.js');
