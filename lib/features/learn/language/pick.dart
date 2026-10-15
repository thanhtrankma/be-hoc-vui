// Đảo Chữ cái và Tiếng Anh: nghe rồi chọn đúng chữ / hình.
// CHỦ: agent A. Port của reference/web/js/games/pick.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (pickModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule pickModule = PickGame();`).
final GameModule pickModule = const PlaceholderGame('pick', owner: 'A', webFile: 'pick.js');
