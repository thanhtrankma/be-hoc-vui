// Rắn săn mồi, bắn bia, xếp gạch, nhảy lên mây (tank nằm ở funtank.dart của agent G).
// CHỦ: agent F. Port của reference/web/js/games/funnew1.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funnew1Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funnew1Games = {
  'snake': const PlaceholderFunGame('snake', owner: 'F', webFile: 'funnew1.js'),
  'gallery': const PlaceholderFunGame('gallery', owner: 'F', webFile: 'funnew1.js'),
  'blocks': const PlaceholderFunGame('blocks', owner: 'F', webFile: 'funnew1.js'),
  'jumper': const PlaceholderFunGame('jumper', owner: 'F', webFile: 'funnew1.js'),
};
