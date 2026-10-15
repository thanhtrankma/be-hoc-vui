// Báo cáo của con (/report/<id>): 7 ngày, kỹ năng, chỗ hay nhầm, mốc tiến bộ & bằng khen. Dữ liệu: store.learn(p), LearnTracker.
// CHỦ: agent I. Port của reference/web/js/app.js report().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (ReportScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.kidId});
  final String kidId;
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Báo cáo của con', img: 'Abacus');
}
