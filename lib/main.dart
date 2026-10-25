// Bé Vui Học — khởi động: nạp dữ liệu, mở bộ nhớ máy, khởi động âm thanh, rồi vẽ app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/audio/audio_service.dart';
import 'core/audio/soloud_audio.dart';
import 'core/content/content.dart';
import 'core/store/store.dart';
import 'features/sync/firebase_setup.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Chỉ đặt màu biểu tượng thanh trạng thái (nền trời sáng → biểu tượng tối). Không đặt statusBarColor trên Android 15+:
  // máy tự vẽ tràn viền (edge-to-edge) với thanh trong suốt, còn Window.setStatusBarColor đã lỗi thời từ API 35.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark));
  if (defaultTargetPlatform == TargetPlatform.android) unawaited(_legacyStatusBar());
  // Firebase khởi động song song với việc nạp dữ liệu (không bắt màn đầu chờ).
  final results = await Future.wait([SharedPreferences.getInstance(), loadContentBundle(), initFirebase(options: DefaultFirebaseOptions.currentPlatform)]);
  final prefs = results[0] as SharedPreferences;
  final bundle = results[1] as ContentBundle;
  final store = AppStore(prefs);
  final audio = SoloudAudio(voice: bundle.voice, store: store);
  // Âm thanh khởi động song song; lỗi thì im lặng (không chặn màn đầu).
  audio.init();
  runApp(ProviderScope(
    overrides: [
      contentBundleProvider.overrideWithValue(bundle),
      storeProvider.overrideWith((ref) => store),
      audioProvider.overrideWithValue(audio),
    ],
    child: const BeVuiHocApp(),
  ));
}

/// Android 14 trở xuống: FlutterActivity phủ thanh trạng thái một lớp tối mờ; đặt trong suốt để giữ nền trời như trước.
/// Android 15+ (API 35) đã tràn viền sẵn nên không gọi API lỗi thời. Hỏi API level qua kênh bvh/system (MainActivity.kt).
Future<void> _legacyStatusBar() async {
  try {
    final sdk = await const MethodChannel('bvh/system').invokeMethod<int>('sdkInt');
    if (sdk != null && sdk < 35) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
    }
  } catch (_) {/* không có kênh: giữ mặc định */}
}
