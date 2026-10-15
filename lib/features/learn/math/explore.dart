// Đảo Khám phá: kéo thả phân loại vào 2 giỏ.
// CHỦ: agent B. Port của reference/web/js/games/explore.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (exploreModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule exploreModule = ExploreGame();`).
final GameModule exploreModule = const PlaceholderGame('explore', owner: 'B', webFile: 'explore.js');
