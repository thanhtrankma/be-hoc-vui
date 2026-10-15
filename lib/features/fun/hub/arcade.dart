// Đảo Trò chơi nhanh (đảo học, mở từ bản đồ): bóng bay chữ cái, đua xe trả lời...
// CHỦ: agent E. Port của reference/web/js/games/arcade.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (arcadeModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule arcadeModule = ArcadeGame();`).
final GameModule arcadeModule = const PlaceholderGame('arcade', owner: 'E', webFile: 'arcade.js');
