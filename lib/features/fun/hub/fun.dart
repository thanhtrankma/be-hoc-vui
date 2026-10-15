// Khu vui chơi (/fun): danh sách game theo nhóm, thẻ "Nhân vật của bé" (p.look), nút bố mẹ chơi miễn phí; game Ná thần kỳ.
// CHỦ: agent E. Port của reference/web/js/games/fun.js + app.js funZone()/lookCard().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (FunHubScreen, funGames) vì router/registry trỏ tới.
// Danh sách game + hợp đồng: lib/core/game/fun_games.dart (kFunGames, parentFunProvider). Mở game: context.go('/fun/<id>')
// (khung FunPlayScreen của Foundation lo trừ vé, chơi 3 cấp/vé, bảng kết quả, kỷ lục).
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/placeholder.dart';

class FunHubScreen extends StatelessWidget {
  const FunHubScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Khu vui chơi', img: 'Joystick');
}

/// Game của file fun.js (Ná thần kỳ — không "leveled": tự chơi nhiều cấp, tự gọi ctx.levelUp()).
final Map<String, FunGameModule> funGames = {
  'sling': const PlaceholderFunGame('sling', owner: 'E', webFile: 'fun.js'),
};
