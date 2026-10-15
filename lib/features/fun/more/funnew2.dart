// Khủng long chạy, ếch qua đường, bóng bàn, ăn đậu né ma, ghép 3.
// CHỦ: agent F. Port của reference/web/js/games/funnew2.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funnew2Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funnew2Games = {
  'runner': const PlaceholderFunGame('runner', owner: 'F', webFile: 'funnew2.js'),
  'frogger': const PlaceholderFunGame('frogger', owner: 'F', webFile: 'funnew2.js'),
  'pong': const PlaceholderFunGame('pong', owner: 'F', webFile: 'funnew2.js'),
  'pacman': const PlaceholderFunGame('pacman', owner: 'F', webFile: 'funnew2.js'),
  'match3': const PlaceholderFunGame('match3', owner: 'F', webFile: 'funnew2.js'),
};
