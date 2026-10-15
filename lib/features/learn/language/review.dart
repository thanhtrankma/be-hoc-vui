// Ôn tập (/review, /review/all, /review/x/<mục>): dựng câu hỏi cho mục tới ngày ôn (store.dueItems), chạy bằng QuizView. Xong: store.recordReview(stars), +1 vé nếu bật Khu vui chơi.
// CHỦ: agent A. Port của reference/web/js/app.js reviewPlay()/reviewQ().
// Chỉ sửa file trong thư mục của mình; giữ nguyên tên công khai (ReviewScreen) vì router/registry trỏ tới.
import 'package:flutter/widgets.dart';

import 'package:be_vui_hoc/core/game/placeholder.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, this.mode, this.item});
  /// null = mục tới ngày ôn; 'all' = bố mẹ bấm Luyện lại; 'x' = luyện một mục (item).
  final String? mode;
  final String? item;
  @override
  Widget build(BuildContext context) => const UnderConstruction(title: 'Ôn bài', img: 'Counterclockwise arrows button');
}
