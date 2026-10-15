// Đảo Tập viết: tô theo nét chữ/số (CustomPainter).
// CHỦ: agent A. Port của reference/web/js/games/trace.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (traceModule) vì router/registry trỏ tới.
// Hợp đồng: lib/core/game/game_module.dart (GameModule, GameContext) — xem lib/core/README.md.
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

/// Thay PlaceholderGame bằng GameModule thật (vd. `final GameModule traceModule = TraceGame();`).
final GameModule traceModule = const PlaceholderGame('trace', owner: 'A', webFile: 'trace.js');
