// Hình theo tên (port src()/img()/photoOf() của ui.js): "Red apple" → assets/img/red-apple.webp.
// Trong màn học (PhotoScope bật) hình có ảnh chụp thật (photos.json) thì dùng ảnh chụp; lỗi tải → quay về hình hoạt hình.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content.dart';

/// "Red apple" → "red-apple" (giống slug() của web).
String slug(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

/// Đường dẫn asset hình hoạt hình (Fluent Emoji 3D).
String imgAsset(String name) => 'assets/img/${slug(name)}.webp';

/// Đường dẫn ảnh chụp thật nếu có, không thì null.
String? photoAsset(Map<String, PhotoInfo> photos, String name) => photos[name]?.assetPath;

/// Bật ảnh chụp thật cho cả cây con (màn học bọc stage trong PhotoScope(enabled: true)).
class PhotoScope extends InheritedWidget {
  const PhotoScope({super.key, required this.enabled, required super.child});
  final bool enabled;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PhotoScope>()?.enabled ?? false;
  @override
  bool updateShouldNotify(PhotoScope oldWidget) => oldWidget.enabled != enabled;
}

/// Một nhóm hình (các thẻ lựa chọn...) phải cùng kiểu: nếu có hình chưa có ảnh chụp thì cả nhóm dùng hoạt hình
/// (unifyPhotos của web). Trả về true nếu cả nhóm được dùng ảnh chụp.
bool groupUsesPhotos(Map<String, PhotoInfo> photos, Iterable<String> names) => names.every(photos.containsKey);

/// Hình emoji/ảnh theo tên. size = cạnh vuông (null = theo khung cha). photo:false giữ hình hoạt hình.
class EmojiImage extends ConsumerWidget {
  const EmojiImage(this.name, {super.key, this.size, this.width, this.height, this.photo = true, this.fit = BoxFit.contain, this.color, this.colorBlendMode, this.opacity = 1});
  final String name;
  final double? size;
  final double? width;
  final double? height;

  /// Cho phép đổi sang ảnh chụp khi PhotoScope bật.
  final bool photo;
  final BoxFit fit;

  /// Tô màu (vd. bóng đen cho trò "Ghép bóng"): color + BlendMode.srcIn.
  final Color? color;
  final BlendMode? colorBlendMode;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = width ?? size, h = height ?? size;
    String? ph;
    if (photo && PhotoScope.of(context)) {
      try {
        ph = photoAsset(ref.watch(contentBundleProvider).photos, name);
      } catch (_) {/* chưa nạp dữ liệu (test) */}
    }
    final cartoon = Image.asset(
      imgAsset(name),
      width: w,
      height: h,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      opacity: opacity == 1 ? null : AlwaysStoppedAnimation(opacity),
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
    );
    if (ph == null) return cartoon;
    return ClipRRect(
      borderRadius: BorderRadius.circular((w ?? 100) * .12),
      child: Image.asset(ph, width: w, height: h, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => cartoon),
    );
  }
}

/// Tải trước hình cho một màn (tránh thẻ trống). Lỗi bỏ qua.
Future<void> precacheEmojis(BuildContext context, Iterable<String> names, {Map<String, PhotoInfo>? photos}) async {
  final futures = <Future<void>>[];
  for (final n in names.toSet()) {
    final p = photos == null ? null : photoAsset(photos, n);
    futures.add(precacheImage(AssetImage(p ?? imgAsset(n)), context).catchError((_) {}));
  }
  await Future.wait(futures).timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
}

// ---------- Ảnh cho canvas / Flame (vẽ bằng Canvas.drawImage) ----------
final Map<String, Future<ui.Image?>> _uiImages = {};

/// Giải mã một asset ảnh thành ui.Image (có bộ nhớ đệm). Lỗi → null.
Future<ui.Image?> loadUiImage(String assetPath) => _uiImages[assetPath] ??= () async {
      try {
        final data = await rootBundle.load(assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      } catch (_) {
        _uiImages.remove(assetPath);
        return null;
      }
    }();

/// Hình emoji theo tên cho canvas (draw(ctx, name, ...) của funcore.js).
Future<ui.Image?> loadEmojiUiImage(String name) => loadUiImage(imgAsset(name));

/// Tải nhiều hình emoji một lượt; trả về map tên → ảnh (hình lỗi bỏ qua).
Future<Map<String, ui.Image>> loadEmojiUiImages(Iterable<String> names) async {
  final list = names.toSet().toList();
  final imgs = await Future.wait(list.map(loadEmojiUiImage));
  return {for (var i = 0; i < list.length; i++) if (imgs[i] != null) list[i]: imgs[i]!};
}
