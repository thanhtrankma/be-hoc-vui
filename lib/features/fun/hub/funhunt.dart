// Săn quái vật (có kho skill/súng lưu qua ctx.carry/saveGear).
// CHỦ: agent E. Port của reference/web/js/games/funhunt.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funhuntGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funhuntGames = {
  'hunt': const PlaceholderFunGame('hunt', owner: 'E', webFile: 'funhunt.js'),
};
