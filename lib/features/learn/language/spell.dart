// Đảo Ghép vần: dấu thanh, âm đầu, vần, ghép tiếng, nghe đánh vần. placeTone() đã có sẵn ở core/content/vn_text.dart.
// CHỦ: agent A. Port của reference/web/js/games/spell.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (spellModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule spellModule = SpellGame();`).
final GameModule spellModule = const PlaceholderGame('spell', owner: 'A', webFile: 'spell.js');
