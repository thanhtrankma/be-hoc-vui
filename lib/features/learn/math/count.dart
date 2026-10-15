// Đảo Số đếm: chạm từng hình để đếm rồi chọn số.
// CHỦ: agent B. Port của reference/web/js/games/count.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (countModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule countModule = CountGame();`).
final GameModule countModule = const PlaceholderGame('count', owner: 'B', webFile: 'count.js');
