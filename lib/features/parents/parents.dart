// Góc bố mẹ (/parent): cài đặt, các bé, sao lưu/khôi phục (store.exportData/importData), đồng bộ, góp ý, ghi công. Đã qua khoá bố mẹ trước khi vào.
// CHỦ: agent I. Port của reference/web/js/app.js parent().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (ParentsScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class ParentsScreen extends StatelessWidget {
  const ParentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Góc bố mẹ', img: 'Gear');
}
