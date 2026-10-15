// Firebase cho bản app: Crashlytics (báo lỗi), Remote Config (cờ tính năng), App Check (chống gọi giả API).
// KHÔNG Analytics, KHÔNG quảng cáo (app thuộc nhóm Kids/Families của App Store & Google Play).
// Cấu hình: lib/firebase_options.dart (project bevuihoc-app, id com.iping.bevuihoc). An toàn: chạy test, nền tảng chưa
// cấu hình hoặc khởi động lỗi thì initFirebase() chỉ ghi log rồi bỏ qua, app vẫn chạy bình thường (không chặn khi mất mạng).
// CHỦ: agent I.
//
// Nối vào main.dart (coordinator):
//   import 'features/sync/firebase_setup.dart';
//   ... sau WidgetsFlutterBinding.ensureInitialized():
//   await initFirebase();      // mặc định dùng DefaultFirebaseOptions.currentPlatform
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'package:be_vui_hoc/firebase_options.dart';

/// Giá trị mặc định của Remote Config (dùng luôn khi chưa có Firebase / mất mạng).
const Map<String, Object> kRemoteDefaults = {
  // Bật/tắt đồng bộ mã gia đình từ xa (vd. khi máy chủ bảo trì).
  'sync_enabled': true,
  // Địa chỉ API đồng bộ (đổi máy chủ không cần ra bản mới).
  'sync_api': 'https://datpilot.com/api/bvh/sync/',
  // Khu vui chơi / RPG có hiện không (bố mẹ vẫn tắt được trong Góc bố mẹ).
  'fun_zone_enabled': true,
  // Ôn tập thông minh.
  'review_enabled': true,
  // Thông báo ngắn cho bố mẹ trong Góc bố mẹ (rỗng = không hiện).
  'parent_notice_vi': '',
  'parent_notice_en': '',
  // Phiên bản tối thiểu (build number); thấp hơn thì Góc bố mẹ nhắc cập nhật. 0 = không nhắc.
  'min_build': 0,
};

/// Trạng thái Firebase sau initFirebase().
class FirebaseState {
  FirebaseState._();
  static bool ready = false;
  static String? skippedReason;
}

/// Cờ tính năng: đọc Remote Config nếu Firebase đã sẵn sàng, không thì giá trị mặc định.
class RemoteFlags {
  RemoteFlags._();

  static FirebaseRemoteConfig? get _rc => FirebaseState.ready ? FirebaseRemoteConfig.instance : null;

  static bool getBool(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getBool(key);
    } catch (_) {/* bỏ qua */}
    final v = kRemoteDefaults[key];
    return v is bool ? v : false;
  }

  static String getString(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getString(key);
    } catch (_) {/* bỏ qua */}
    final v = kRemoteDefaults[key];
    return v is String ? v : '';
  }

  static int getInt(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getInt(key);
    } catch (_) {/* bỏ qua */}
    final v = kRemoteDefaults[key];
    return v is int ? v : 0;
  }

  static bool get syncEnabled => getBool('sync_enabled');
  static String get syncApi => getString('sync_api');
  static bool get funZoneEnabled => getBool('fun_zone_enabled');
  static bool get reviewEnabled => getBool('review_enabled');
  static String parentNotice(String lang) => getString(lang == 'en' ? 'parent_notice_en' : 'parent_notice_vi');
  static int get minBuild => getInt('min_build');
}

/// Khởi động Firebase. Trả về true nếu chạy được, false nếu bỏ qua (chưa cấu hình, chạy test, nền tảng không hỗ trợ).
/// Không bao giờ ném lỗi ra ngoài.
Future<bool> initFirebase({FirebaseOptions? options}) async {
  if (FirebaseState.ready) return true;
  // Chạy trong `flutter test`: không có plugin gốc.
  if (!kIsWeb && _isTest()) {
    return _skip('test environment');
  }
  if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    return _skip('unsupported platform $defaultTargetPlatform');
  }
  try {
    // DefaultFirebaseOptions ném UnsupportedError với nền tảng chưa cấu hình → bỏ qua.
    final opts = options ?? DefaultFirebaseOptions.currentPlatform;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: opts);
  } catch (e) {
    return _skip('Firebase init failed ($e)');
  }
  FirebaseState.ready = true;

  // ----- Crashlytics: bắt lỗi Flutter và lỗi bất đồng bộ. Tắt thu thập khi debug. -----
  try {
    final c = FirebaseCrashlytics.instance;
    await c.setCrashlyticsCollectionEnabled(!kDebugMode);
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      c.recordFlutterFatalError(details);
      prevFlutter?.call(details);
    };
    final prevPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      c.recordError(error, stack, fatal: true);
      return prevPlatform?.call(error, stack) ?? true;
    };
  } catch (e) {
    debugPrint('[firebase] crashlytics: $e');
  }

  // ----- App Check: Play Integrity / App Attest (DeviceCheck dự phòng); debug provider khi debug. -----
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    debugPrint('[firebase] app check: $e');
  }

  // ----- Remote Config: mặc định trước, tải bản mới ở nền (không chặn khởi động). -----
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults(kRemoteDefaults);
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 6),
    ));
    unawaited(rc.fetchAndActivate().then((_) {}, onError: (Object e) => debugPrint('[firebase] remote config fetch: $e')));
  } catch (e) {
    debugPrint('[firebase] remote config: $e');
  }
  return true;
}

bool _skip(String why) {
  FirebaseState.skippedReason = why;
  debugPrint('[firebase] skipped: $why');
  return false;
}

/// flutter_tester đặt biến môi trường FLUTTER_TEST=true.
bool _isTest() {
  try {
    return Platform.environment['FLUTTER_TEST'] == 'true';
  } catch (_) {
    return false;
  }
}
