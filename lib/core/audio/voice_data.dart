// Dữ liệu giọng đọc (port phần thuần dữ liệu của js/audio.js): voice.json (câu cố định + mẫu câu) và audio.json
// (bảng "lang|text" → tên file mp3 trong assets/audio/). Không phụ thuộc engine âm thanh nên test được.

/// Một câu đọc: [lang, text] như web. File mp3 tra theo khoá "lang|text".
class VoiceLine {
  const VoiceLine(this.lang, this.text);

  /// Từ mảng JSON ['vi', 'Giỏi quá!'].
  static VoiceLine? fromList(Object? v) => v is List && v.length >= 2 ? VoiceLine(v[0].toString(), v[1].toString()) : null;

  final String lang;
  final String text;
  String get key => '$lang|$text';
  List<String> toList() => [lang, text];

  @override
  bool operator ==(Object other) => other is VoiceLine && other.lang == lang && other.text == text;
  @override
  int get hashCode => Object.hash(lang, text);
  @override
  String toString() => 'VoiceLine($lang, $text)';
}

class VoiceTemplate {
  VoiceTemplate({required this.lang, required this.text, this.fx = const {}, this.forSets = const [], this.json = const {}});
  factory VoiceTemplate.fromJson(Map<String, dynamic> j) => VoiceTemplate(
        lang: (j['lang'] ?? 'vi').toString(),
        text: (j['text'] ?? '').toString(),
        fx: (j['fx'] is Map) ? (j['fx'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
        forSets: (j['for'] is List) ? (j['for'] as List).map((e) => e.toString()).toList() : const [],
        json: j,
      );
  final String lang;
  final String text;

  /// Biến đổi một trường trước khi ghép (phải khớp FX trong tools/build.py của web).
  final Map<String, String> fx;

  /// Các bộ dữ liệu content.json mà mẫu này đọc (dùng cho tra ngược mục học).
  final List<String> forSets;
  final Map<String, dynamic> json;
}

/// Biến đổi trường (giống FX trong audio.js).
final Map<String, String Function(String)> voiceFx = {
  'spellFast': (s) {
    final p = s.trim().replaceAll(RegExp(r'\.+$'), '').split('. ');
    if (p.length == 5) return '${p[0]} ${p[1]} ${p[2]}, ${p[3]} ${p[4]}!';
    if (p.length == 3) return '${p[0]} ${p[1]}, ${p[2]}!';
    return '${p.join(', ')}!';
  },
  'spellComma': (s) => '${s.trim().replaceAll(RegExp(r'\.+$'), '').split('. ').join(', ')}.',
};

class VoiceData {
  VoiceData({required this.phrases, required this.templates, required this.index});

  factory VoiceData.fromJson(Map<String, dynamic> voice, Map<String, dynamic> audioIndex) {
    final ph = <String, Map<String, String>>{};
    (voice['phrases'] as Map? ?? {}).forEach((k, v) {
      if (v is Map) ph[k.toString()] = v.map((a, b) => MapEntry(a.toString(), b.toString()));
    });
    final tp = <String, VoiceTemplate>{};
    (voice['templates'] as Map? ?? {}).forEach((k, v) {
      if (v is Map) tp[k.toString()] = VoiceTemplate.fromJson(v.cast<String, dynamic>());
    });
    return VoiceData(phrases: ph, templates: tp, index: audioIndex.map((k, v) => MapEntry(k, v.toString())));
  }

  static final empty = VoiceData(phrases: const {}, templates: const {}, index: const {});

  /// key → {vi, en}
  final Map<String, Map<String, String>> phrases;
  final Map<String, VoiceTemplate> templates;

  /// "lang|text" → "abcd1234.mp3"
  final Map<String, String> index;

  /// Câu cố định theo khoá (welcome, praise1...) ở ngôn ngữ lg.
  VoiceLine phrase(String key, String lg) => VoiceLine(lg, phrases[key]?[lg] ?? '');

  /// Ghép mẫu câu với một mục dữ liệu (Map). Không có mẫu → null.
  VoiceLine? tpl(String key, Map<String, dynamic> obj) {
    final t = templates[key];
    if (t == null) return null;
    final text = t.text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final k = m[1]!;
      final v = obj[k];
      if (v == null) return '';
      final f = t.fx[k];
      final fn = f == null ? null : voiceFx[f];
      return fn != null ? fn(v.toString()) : _jsString(v);
    });
    return VoiceLine(t.lang, text);
  }

  /// File mp3 của câu (null nếu thiếu: web chỉ cảnh báo, không lỗi).
  String? fileOf(VoiceLine? line) => line == null ? null : index[line.key];
  String? assetOf(VoiceLine? line) {
    final f = fileOf(line);
    return f == null ? null : 'assets/audio/$f';
  }
}

/// Số trong JS in ra không có ".0" (vd. 3 chứ không phải 3.0).
String _jsString(Object v) {
  if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
  return v.toString();
}
