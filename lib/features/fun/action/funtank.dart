// Xe tăng dũng cảm (Flame).
// CHỦ: agent G. Port của reference/web/js/games/funtank.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funtankGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funtankGames = {
  'tank': const PlaceholderFunGame('tank', owner: 'G', webFile: 'funtank.js'),
};
