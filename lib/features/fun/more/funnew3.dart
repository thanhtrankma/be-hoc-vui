// Chạy 3 làn, cá con, bóng rổ, vượt rào, nhảy theo nhạc, golf mini (sprite Kenney).
// CHỦ: agent F. Port của reference/web/js/games/funnew3.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funnew3Games) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funnew3Games = {
  'lanes': const PlaceholderFunGame('lanes', owner: 'F', webFile: 'funnew3.js'),
  'swim': const PlaceholderFunGame('swim', owner: 'F', webFile: 'funnew3.js'),
  'hoops': const PlaceholderFunGame('hoops', owner: 'F', webFile: 'funnew3.js'),
  'hurdles': const PlaceholderFunGame('hurdles', owner: 'F', webFile: 'funnew3.js'),
  'dance': const PlaceholderFunGame('dance', owner: 'F', webFile: 'funnew3.js'),
  'golf': const PlaceholderFunGame('golf', owner: 'F', webFile: 'funnew3.js'),
};
