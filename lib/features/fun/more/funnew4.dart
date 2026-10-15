// Tiệm pizza, nông trại, lính cứu hoả, tìm đồ vật.
// CHỦ: agent F. Port của reference/web/js/games/funnew4.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funnew4Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funnew4Games = {
  'pizza': const PlaceholderFunGame('pizza', owner: 'F', webFile: 'funnew4.js'),
  'farm': const PlaceholderFunGame('farm', owner: 'F', webFile: 'funnew4.js'),
  'firefight': const PlaceholderFunGame('firefight', owner: 'F', webFile: 'funnew4.js'),
  'hidden': const PlaceholderFunGame('hidden', owner: 'F', webFile: 'funnew4.js'),
};
