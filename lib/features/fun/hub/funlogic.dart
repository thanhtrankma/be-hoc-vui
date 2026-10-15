// Game trí tuệ: lập trình robot, nối dây màu, dẫn nước, bảng số thần tốc.
// CHỦ: agent E. Port của reference/web/js/games/funlogic.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funlogicGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funlogicGames = {
  'coding': const PlaceholderFunGame('coding', owner: 'E', webFile: 'funlogic.js'),
  'flow': const PlaceholderFunGame('flow', owner: 'E', webFile: 'funlogic.js'),
  'pipes': const PlaceholderFunGame('pipes', owner: 'E', webFile: 'funlogic.js'),
  'schulte': const PlaceholderFunGame('schulte', owner: 'E', webFile: 'funlogic.js'),
};
