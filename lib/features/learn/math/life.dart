// Đảo Toán đời sống: siêu thị, cân, lịch...
// CHỦ: agent B. Port của reference/web/js/games/life.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (lifeModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule lifeModule = LifeGame();`).
final GameModule lifeModule = const PlaceholderGame('life', owner: 'B', webFile: 'life.js');
