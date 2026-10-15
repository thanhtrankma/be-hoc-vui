// Đối kháng 1: võ đài, khúc côn cầu, kéo co, bóng đá đầu to, bóng chuyền (đấu máy hoặc bố/mẹ).
// CHỦ: agent G. Port của reference/web/js/games/funvs1.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funvs1Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funvs1Games = {
  'fighter': const PlaceholderFunGame('fighter', owner: 'G', webFile: 'funvs1.js'),
  'hockey': const PlaceholderFunGame('hockey', owner: 'G', webFile: 'funvs1.js'),
  'tug': const PlaceholderFunGame('tug', owner: 'G', webFile: 'funvs1.js'),
  'soccer': const PlaceholderFunGame('soccer', owner: 'G', webFile: 'funvs1.js'),
  'volley': const PlaceholderFunGame('volley', owner: 'G', webFile: 'funvs1.js'),
};
