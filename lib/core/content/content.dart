// Nạp dữ liệu (content.json, app.json, photos.json, voice.json, audio.json) một lần lúc mở app.
// content.json giữ dạng Map/List như web: game đọc thẳng content['countLevels'], content.list('vnwords')...
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/voice_data.dart';
import 'models.dart';

export 'models.dart';

/// content.json: ~100 bộ dữ liệu (chữ cái, vần, phép tính, tiếng Anh, truyện...). Truy cập như object JS.
class Content {
  Content(this.raw);
  final Json raw;

  Object? operator [](String key) => raw[key];
  bool has(String key) => raw.containsKey(key);

  /// Một bộ dạng danh sách đối tượng (vd. 'vnwords', 'countLevels'). Không có → [].
  List<Json> list(String key) => asMapList(raw[key]);

  /// Một bộ dạng danh sách chuỗi (vd. 'consonants', 'rimes').
  List<String> strings(String key) => asStrList(raw[key]);

  /// Một bộ dạng Map (vd. 'categories', 'kntt').
  Json map(String key) => asMap(raw[key]);

  /// Danh sách bài của một khoá (vd. 'letterLevels'), dữ liệu thô từng bài.
  Json? level(String levelsKey, int i) {
    final l = list(levelsKey);
    return i >= 0 && i < l.length ? l[i] : null;
  }
}

/// Mọi dữ liệu tĩnh của app, nạp sẵn trong main() trước runApp.
class ContentBundle {
  ContentBundle({required this.content, required this.data, required this.photos, required this.voice});
  final Content content;
  final AppData data;

  /// Tên hình → ảnh chụp thật (chỉ dùng trong màn học, xem PhotoMode).
  final Map<String, PhotoInfo> photos;
  final VoiceData voice;
}

/// Nạp từ asset bundle (rootBundle khi chạy app; test dùng được luôn rootBundle).
Future<ContentBundle> loadContentBundle([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final texts = await Future.wait([
    b.loadString('assets/data/content.json'),
    b.loadString('assets/data/app.json'),
    b.loadString('assets/data/photos.json'),
    b.loadString('assets/data/voice.json'),
    b.loadString('assets/data/audio.json'),
  ]);
  // content.json ~1 MB: giải mã ở isolate khác cho màn đầu không giật.
  final decoded = await compute(_decodeAll, texts);
  final photos = <String, PhotoInfo>{};
  asMap(decoded[2]).forEach((k, v) {
    if (v is Map) photos[k] = PhotoInfo.fromJson(v.cast<String, dynamic>());
  });
  return ContentBundle(
    content: Content(asMap(decoded[0])),
    data: AppData.fromJson(asMap(decoded[1])),
    photos: photos,
    voice: VoiceData.fromJson(asMap(decoded[3]), asMap(decoded[4])),
  );
}

List<Object?> _decodeAll(List<String> texts) => texts.map((t) => jsonDecode(t)).toList();

/// Gói dữ liệu đã nạp. main() override bằng giá trị thật: ProviderScope(overrides: [contentBundleProvider.overrideWithValue(b)]).
final contentBundleProvider = Provider<ContentBundle>((ref) => throw UnimplementedError('contentBundleProvider chưa được nạp (override trong main)'));
final contentProvider = Provider<Content>((ref) => ref.watch(contentBundleProvider).content);
final appDataProvider = Provider<AppData>((ref) => ref.watch(contentBundleProvider).data);
