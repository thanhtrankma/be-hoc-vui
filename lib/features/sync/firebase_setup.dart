// Firebase cho bản app: chỉ Cloud Firestore (bản đồng bộ đã mã hoá đầu-cuối, xem sync.dart).
// KHÔNG Analytics, KHÔNG Crashlytics, KHÔNG App Check, KHÔNG Remote Config, KHÔNG quảng cáo (app thuộc nhóm
// Kids/Families của App Store & Google Play) — app không gửi mã cài đặt hay định danh thiết bị nào.
// Cấu hình: lib/firebase_options.dart (project bevuihoc-app, id com.iping.bevuihoc). An toàn: chạy test, nền tảng chưa
// cấu hình hoặc khởi động lỗi thì initFirebase() chỉ ghi log rồi bỏ qua, app vẫn chạy bình thường (không chặn khi mất mạng).
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:be_vui_hoc/firebase_options.dart';

/// Cờ tính năng cố định trong app (trước đây lấy từ Remote Config; đã gỡ để không gửi mã cài đặt Firebase).
const Map<String, Object> kRemoteDefaults = {
  'sync_enabled': true,
  'fun_zone_enabled': true,
  'review_enabled': true,
  'parent_notice_vi': '',
  'parent_notice_en': '',
  'min_build': 0,
};

/// Trạng thái Firebase sau initFirebase().
class FirebaseState {
  FirebaseState._();
  static bool ready = false;
  static String? skippedReason;
}

/// Cờ tính năng: giá trị cố định ở kRemoteDefaults (giữ API cũ cho các màn đang dùng).
class RemoteFlags {
  RemoteFlags._();

  static bool getBool(String key) {
    final v = kRemoteDefaults[key];
    return v is bool ? v : false;
  }

  static String getString(String key) {
    final v = kRemoteDefaults[key];
    return v is String ? v : '';
  }

  static int getInt(String key) {
    final v = kRemoteDefaults[key];
    return v is int ? v : 0;
  }

  static bool get syncEnabled => getBool('sync_enabled');
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
