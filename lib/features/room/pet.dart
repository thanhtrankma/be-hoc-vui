// Phòng thú cưng (/pet): nhận nuôi, cho ăn, tắm, chơi, ngủ. Khi bé học xong một bài, khung màn chơi đã cộng p.pet.happy/xp (như web).
// CHỦ: agent D. Port của reference/web/js/games/pet.js.
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (PetScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Thú cưng', img: 'Paw prints');
}
