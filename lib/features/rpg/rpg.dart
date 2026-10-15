// Thế giới phiêu lưu (/rpg): làng, cửa hàng, chọn vùng. Vào màn: context.go("/rpg/<vùng>/<màn>") (RpgStageScreen). Vé: store.useTicket(); bố mẹ chơi miễn phí: parentFunProvider.
// CHỦ: agent H. Port của reference/web/js/games/rpg.js + app.js rpgTown()/rpgPlay().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (RpgTownScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class RpgTownScreen extends StatelessWidget {
  const RpgTownScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Thế giới phiêu lưu', img: 'Crossed swords');
}

/// Một màn RPG (`/rpg/<vùng>/<màn>`): trừ vé (trừ khi bố mẹ chơi), chơi, bảng kết quả.
class RpgStageScreen extends StatelessWidget {
  const RpgStageScreen({super.key, required this.zone, required this.stage});
  final int zone;
  final int stage;
  @override
  Widget build(BuildContext context) => UnderConstruction(title: 'Vùng ${zone + 1} · Màn ${stage + 1}', img: 'Crossed swords', backPath: '/rpg');
}
