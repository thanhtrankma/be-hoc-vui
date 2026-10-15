// Siêu nhân diệt quái vật.
// CHỦ: agent F. Port của reference/web/js/games/funhero.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funheroGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funheroGames = {
  'hero': const PlaceholderFunGame('hero', owner: 'F', webFile: 'funhero.js'),
};
