package com.iping.bevuihoc

import android.os.Build
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Bài Đọc to chỉ nhận giọng ngay trên máy (read.dart). Thiếu bộ nhận tại chỗ thì speech_to_text dùng bản qua mạng,
        // nên Dart hỏi ở đây trước và tắt micro nếu không có.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bvh/speech").setMethodCallHandler { call, result ->
            when (call.method) {
                "onDeviceAvailable" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                )
                else -> result.notImplemented()
            }
        }
    }
}
