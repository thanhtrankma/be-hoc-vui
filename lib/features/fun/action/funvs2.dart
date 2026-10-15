// Đối kháng 2: ném tuyết, mô tô ánh sáng, sumo, cờ caro, nối bốn.
// CHỦ: agent G. Port của reference/web/js/games/funvs2.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funvs2Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funvs2Games = {
  'snowball': const PlaceholderFunGame('snowball', owner: 'G', webFile: 'funvs2.js'),
  'tron': const PlaceholderFunGame('tron', owner: 'G', webFile: 'funvs2.js'),
  'sumo': const PlaceholderFunGame('sumo', owner: 'G', webFile: 'funvs2.js'),
  'caro': const PlaceholderFunGame('caro', owner: 'G', webFile: 'funvs2.js'),
  'connect4': const PlaceholderFunGame('connect4', owner: 'G', webFile: 'funvs2.js'),
};
