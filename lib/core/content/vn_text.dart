// Tiện ích chữ tiếng Việt dùng chung (port placeTone trong games/spell.js; arcade, read, ôn tập cũng dùng).
// Dart không có String.normalize('NFC'): bảng ghép nguyên âm + dấu thanh → ký tự dựng sẵn.

const Map<String, String> kToneMark = {'ngang': '', 'huyền': '̀', 'sắc': '́', 'hỏi': '̉', 'ngã': '̃', 'nặng': '̣'};
const List<String> kTones = ['ngang', 'huyền', 'sắc', 'hỏi', 'ngã', 'nặng'];
const String _vow = 'aăâeêioôơuưy';
const String _mod = 'ăâêôơư';

/// Đặt dấu thanh đúng chỗ trên vần (v: vần không dấu, vd "an", "ua", "ương").
/// Một nguyên âm thì đặt trên nó; có nguyên âm mang dấu phụ (ă â ê ô ơ ư) thì đặt trên nguyên âm đó (ươ, iê, uô: chữ sau);
/// hai nguyên âm thường (ai, ao, ua…) thì đặt trên chữ đầu; vần có âm đệm o/u (oa, oe, uy, uâ…) không đặt trên âm đệm.
String placeTone(String v, String tone) {
  if (tone == 'ngang' || !kToneMark.containsKey(tone)) return v;
  final chars = v.split('');
  final idx = <int>[for (var i = 0; i < chars.length; i++) if (_vow.contains(chars[i])) i];
  if (idx.isEmpty) return v;
  if (idx.length > 1 && RegExp(r'^(o[aăe]|u[yâê])').hasMatch(v)) idx.removeAt(0);
  var k = idx.first;
  if (idx.length > 1) {
    final mods = idx.where((i) => _mod.contains(chars[i])).toList();
    if (mods.isNotEmpty) k = mods.last;
  }
  return nfc(v.substring(0, k + 1) + kToneMark[tone]! + v.substring(k + 1));
}

/// Ghép nguyên âm + dấu thanh tổ hợp thành ký tự dựng sẵn (đủ cho tiếng Việt).
String nfc(String s) {
  if (!s.contains(RegExp('[̣̀́̃̉]'))) return s;
  final out = StringBuffer();
  final cs = s.split('');
  for (var i = 0; i < cs.length; i++) {
    if (i + 1 < cs.length) {
      final pair = _compose['${cs[i]}${cs[i + 1]}'];
      if (pair != null) {
        out.write(pair);
        i++;
        continue;
      }
    }
    out.write(cs[i]);
  }
  return out.toString();
}

const Map<String, String> _compose = {
  'à': 'à', 'á': 'á', 'ả': 'ả', 'ã': 'ã', 'ạ': 'ạ', 'ằ': 'ằ', 'ắ': 'ắ', 'ẳ': 'ẳ', 'ẵ': 'ẵ', 'ặ': 'ặ', 'ầ': 'ầ', 'ấ': 'ấ', 'ẩ': 'ẩ', 'ẫ': 'ẫ', 'ậ': 'ậ', 'è': 'è', 'é': 'é', 'ẻ': 'ẻ', 'ẽ': 'ẽ', 'ẹ': 'ẹ', 'ề': 'ề', 'ế': 'ế', 'ể': 'ể', 'ễ': 'ễ', 'ệ': 'ệ', 'ì': 'ì', 'í': 'í', 'ỉ': 'ỉ', 'ĩ': 'ĩ', 'ị': 'ị', 'ò': 'ò', 'ó': 'ó', 'ỏ': 'ỏ', 'õ': 'õ', 'ọ': 'ọ', 'ồ': 'ồ', 'ố': 'ố', 'ổ': 'ổ', 'ỗ': 'ỗ', 'ộ': 'ộ', 'ờ': 'ờ', 'ớ': 'ớ', 'ở': 'ở', 'ỡ': 'ỡ', 'ợ': 'ợ', 'ù': 'ù', 'ú': 'ú', 'ủ': 'ủ', 'ũ': 'ũ', 'ụ': 'ụ', 'ừ': 'ừ', 'ứ': 'ứ', 'ử': 'ử', 'ữ': 'ữ', 'ự': 'ự', 'ỳ': 'ỳ', 'ý': 'ý', 'ỷ': 'ỷ', 'ỹ': 'ỹ', 'ỵ': 'ỵ', 'À': 'À', 'Á': 'Á', 'Ả': 'Ả', 'Ã': 'Ã', 'Ạ': 'Ạ', 'Ằ': 'Ằ', 'Ắ': 'Ắ', 'Ẳ': 'Ẳ', 'Ẵ': 'Ẵ', 'Ặ': 'Ặ', 'Ầ': 'Ầ', 'Ấ': 'Ấ', 'Ẩ': 'Ẩ', 'Ẫ': 'Ẫ', 'Ậ': 'Ậ', 'È': 'È', 'É': 'É', 'Ẻ': 'Ẻ', 'Ẽ': 'Ẽ', 'Ẹ': 'Ẹ', 'Ề': 'Ề', 'Ế': 'Ế', 'Ể': 'Ể', 'Ễ': 'Ễ', 'Ệ': 'Ệ', 'Ì': 'Ì', 'Í': 'Í', 'Ỉ': 'Ỉ', 'Ĩ': 'Ĩ', 'Ị': 'Ị', 'Ò': 'Ò', 'Ó': 'Ó', 'Ỏ': 'Ỏ', 'Õ': 'Õ', 'Ọ': 'Ọ', 'Ồ': 'Ồ', 'Ố': 'Ố', 'Ổ': 'Ổ', 'Ỗ': 'Ỗ', 'Ộ': 'Ộ', 'Ờ': 'Ờ', 'Ớ': 'Ớ', 'Ở': 'Ở', 'Ỡ': 'Ỡ', 'Ợ': 'Ợ', 'Ù': 'Ù', 'Ú': 'Ú', 'Ủ': 'Ủ', 'Ũ': 'Ũ', 'Ụ': 'Ụ', 'Ừ': 'Ừ', 'Ứ': 'Ứ', 'Ử': 'Ử', 'Ữ': 'Ữ', 'Ự': 'Ự', 'Ỳ': 'Ỳ', 'Ý': 'Ý', 'Ỷ': 'Ỷ', 'Ỹ': 'Ỹ', 'Ỵ': 'Ỵ'
,
};
