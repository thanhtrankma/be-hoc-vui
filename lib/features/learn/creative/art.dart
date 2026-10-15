// Đảo Tô màu: tô tranh, vẽ tự do, đóng dấu hình.
// CHỦ: agent C. Port của reference/web/js/games/art.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (artModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule artModule = ArtGame();`).
final GameModule artModule = const PlaceholderGame('art', owner: 'C', webFile: 'art.js');
