import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Như audio.js (navigator.audioSession.type = 'playback'): gạt nút im lặng của iPhone/iPad vẫn nghe giọng đọc,
    // hiệu ứng và nhạc (flutter_soloud không tự đặt audio session). Chỉ đặt loại; phiên tự kích hoạt khi phát tiếng.
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Bài Đọc to chỉ nhận giọng ngay trên máy (read.dart): hỏi máy có nhận tiếng Việt tại chỗ không.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BvhSpeech") else { return }
    FlutterMethodChannel(name: "bvh/speech", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
      guard call.method == "onDeviceAvailable" else { return result(FlutterMethodNotImplemented) }
      result(SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))?.supportsOnDeviceRecognition ?? false)
    }
  }
}
