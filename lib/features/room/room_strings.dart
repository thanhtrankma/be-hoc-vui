// Chữ giao diện riêng của Học cùng lớp (web viết thẳng tiếng Việt trong app.js classScreen()/pickClassWeek()).
// Core i18n (lib/core/i18n/strings.dart) chưa có các khoá này nên để tạm ở đây, tra theo ngôn ngữ của I18n.
// TODO(core): chuyển các khoá cls* vào kStrings rồi dùng i18n.t().
import 'package:be_vui_hoc/core/i18n/i18n.dart';

const Map<String, Map<String, String>> _kClsStrings = {
  'vi': {
    'clsTitle': 'Học cùng lớp',
    'clsWeek': 'Tuần {n}',
    'clsWeekNow': 'Tuần {n} trên lớp',
    'clsTv': 'Tiếng Việt',
    'clsToan': 'Toán',
    'clsLesson': 'Bài {n}',
    'clsThin': 'Bài này đang soạn thêm từ cho bé luyện.',
    'clsStories': 'Truyện cùng chủ đề do Bé Vui Học viết.',
    'clsReview': 'Tuần này lớp ôn tập. Bé luyện lại các bài cũ ở dưới nhé.',
    'clsContinue': 'Tuần này lớp học tiếp bài cũ. Bé xem các bài đã qua ở dưới nhé.',
    'clsPrev': 'Bài đã qua: ôn lại',
    'clsNext': 'Bài sắp tới',
    'clsFoot':
        'Thứ tự bài theo sách Tiếng Việt 1 và Toán 1 bộ Kết nối tri thức với cuộc sống. Từ ngữ, câu, truyện do Bé Vui Học soạn. Phần luyện âm, vần của mỗi bài chỉ dùng âm, vần, dấu bé đã học tới bài đó.',
    'clsOtherWeek': '👨‍👩‍👦 Lớp của con đang học tuần khác?',
    'clsPickTitle': 'Lớp đang học tuần nào?',
    'clsPickNote': 'Chọn tuần có bài cô đang dạy. Mỗi tuần sau app tự chuyển sang bài kế tiếp.',
    'clsReviewHk1': 'Ôn tập cuối học kì 1',
    'clsSchedule': 'Theo lịch năm học',
  },
  'en': {
    'clsTitle': 'My class',
    'clsWeek': 'Week {n}',
    'clsWeekNow': 'Week {n} at school',
    'clsTv': 'Vietnamese',
    'clsToan': 'Math',
    'clsLesson': 'Lesson {n}',
    'clsThin': 'More practice words for this lesson are coming.',
    'clsStories': 'Stories on the same topic written by Bé Vui Học.',
    'clsReview': 'The class is reviewing this week. Practice the earlier lessons below.',
    'clsContinue': 'The class continues the previous lesson this week. See the earlier lessons below.',
    'clsPrev': 'Earlier lessons: review',
    'clsNext': 'Coming up',
    'clsFoot':
        'Lesson order follows the Grade 1 Vietnamese and Math textbooks (Kết nối tri thức với cuộc sống). Words, sentences and stories are written by Bé Vui Học. Each lesson only practises sounds, rimes and tones learned up to that lesson.',
    'clsOtherWeek': '👨‍👩‍👦 Is the class on a different week?',
    'clsPickTitle': 'Which week is the class on?',
    'clsPickNote': 'Pick the week the teacher is teaching. The app moves on to the next lesson every week.',
    'clsReviewHk1': 'End of term 1 review',
    'clsSchedule': 'Follow the school calendar',
  },
};

/// Tra chữ Học cùng lớp theo ngôn ngữ hiện tại; khoá không có thì dùng i18n.t().
String clsT(I18n i18n, String key, [Map<String, Object?>? vars]) {
  var s = _kClsStrings[i18n.lang]?[key] ?? _kClsStrings['vi']![key];
  if (s == null) return i18n.t(key, vars);
  if (vars != null) s = s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${vars[m[1]] ?? ''}');
  return s;
}
