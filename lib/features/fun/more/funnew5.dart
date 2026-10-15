// Bẻ ghi tàu hoả, xếp hàng lên xe, bong bóng số.
// CHỦ: agent F. Port của reference/web/js/games/funnew5.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funnew5Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funnew5Games = {
  'trains': const PlaceholderFunGame('trains', owner: 'F', webFile: 'funnew5.js'),
  'truckload': const PlaceholderFunGame('truckload', owner: 'F', webFile: 'funnew5.js'),
  'balloons': const PlaceholderFunGame('balloons', owner: 'F', webFile: 'funnew5.js'),
};
