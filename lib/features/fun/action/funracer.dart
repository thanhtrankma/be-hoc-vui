// Đua xe tốc độ (Flame). Tiếng động cơ: ctx.audio.engine(0..1).
// CHỦ: agent G. Port của reference/web/js/games/funracer.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (funracerGames) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/fun_games.dart (FunGameModule, FunGameContext, FunResult) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// id game → module. Giữ nguyên các khoá (trùng FUN_GAMES); thay giá trị bằng FunGameModule thật.
final Map<String, FunGameModule> funracerGames = {
  'racer': const PlaceholderFunGame('racer', owner: 'G', webFile: 'funracer.js'),
};
