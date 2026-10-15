// Port của js/i18n.js: t() lấy chữ giao diện theo ngôn ngữ, L() chọn trường vi/en của dữ liệu.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/store.dart';
import 'strings.dart';

export 'strings.dart' show kStrings;

class I18n {
  const I18n(this.lang);

  /// 'vi' (mặc định) hoặc 'en'.
  final String lang;

  bool get isEn => lang == 'en';

  /// Chữ giao diện theo khoá, thay {biến}. Không có thì lấy bản tiếng Việt, rồi chính khoá.
  String t(String key, [Map<String, Object?>? vars]) {
    final v = kStrings[lang]?[key] ?? kStrings['vi']![key] ?? key;
    var s = v is String ? v : v.toString();
    if (vars != null) {
      s = s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${vars[m[1]] ?? ''}');
    }
    return s;
  }

  /// Chữ dạng danh sách (vd. installSteps).
  List<String> tList(String key) {
    final v = kStrings[lang]?[key] ?? kStrings['vi']![key];
    return v is List ? v.cast<String>() : const [];
  }

  /// L(obj): chọn obj[lang] ?? obj.vi. Nhận Map {vi, en}, đối tượng có `vi`/`en` (LText, Island...), hoặc String.
  String L(Object? obj) => pickLang(obj, lang);
}

/// Hàm thuần cho L(): dùng được ở nơi không có ref.
String pickLang(Object? obj, String lang) {
  if (obj == null) return '';
  if (obj is String) return obj;
  if (obj is Map) {
    final v = obj[lang] ?? obj['vi'];
    return v == null ? '' : v.toString();
  }
  if (obj is Localized) return obj.textOf(lang);
  return obj.toString();
}

/// Đối tượng dữ liệu có tên song ngữ (đảo, linh vật, cấp học...).
abstract interface class Localized {
  String textOf(String lang);
}

/// Ngôn ngữ hiện tại theo cài đặt (store.settings.lang). Đổi cài đặt → mọi widget watch tự vẽ lại.
final i18nProvider = Provider<I18n>((ref) {
  final lang = ref.watch(storeProvider.select((s) => s.settings['lang'] as String? ?? 'vi'));
  return I18n(lang == 'en' ? 'en' : 'vi');
});
