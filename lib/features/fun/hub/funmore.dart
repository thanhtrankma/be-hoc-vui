// Game vui nhộn: hứng trái cây, đập quái vật, câu cá, xây tháp, phá gạch, chim bay.
// CHỦ: agent E. Port của reference/web/js/games/funmore.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funmoreGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funmoreGames = {
  'catch': const PlaceholderFunGame('catch', owner: 'E', webFile: 'funmore.js'),
  'whack': const PlaceholderFunGame('whack', owner: 'E', webFile: 'funmore.js'),
  'fishing': const PlaceholderFunGame('fishing', owner: 'E', webFile: 'funmore.js'),
  'stack': const PlaceholderFunGame('stack', owner: 'E', webFile: 'funmore.js'),
  'breakout': const PlaceholderFunGame('breakout', owner: 'E', webFile: 'funmore.js'),
  'flappy': const PlaceholderFunGame('flappy', owner: 'E', webFile: 'funmore.js'),
};
