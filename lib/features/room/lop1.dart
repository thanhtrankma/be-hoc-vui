// Học cùng lớp (/lop1): lộ trình theo tuần học (content.kntt). Mở hoạt động: context.go("/play/<đảo>/<bài>/lop1") — khung màn chơi đã xử lý "bài tiếp"/thưởng vé theo bài sách (classDone).
// CHỦ: agent D. Port của reference/web/js/app.js classScreen()/pickClassWeek().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (Lop1Screen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class Lop1Screen extends StatelessWidget {
  const Lop1Screen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Học cùng lớp', img: 'School');
}
