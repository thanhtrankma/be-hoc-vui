// Bé Vui Học — khởi động: nạp dữ liệu, mở bộ nhớ máy, khởi động âm thanh, rồi vẽ app.
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
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
