// Album hình dán + huy hiệu (/album). Huy hiệu: kBadges + LearnTracker.badgeEarned (core/game/learn_tracking.dart).
// CHỦ: agent D. Port của reference/web/js/app.js album().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (StickersScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Bộ sưu tập hình dán', img: 'Trophy');
}
