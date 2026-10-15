// Đọc câu dẫn (voice.json phrases) một lần khi màn mở, như audio.sayPhrase('...') đầu mỗi màn của app.js.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';

/// Gọi một lần khi màn mở (đọc câu dẫn...).
mixin SayOnOpen<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? get openPhrase;
  @override
  void initState() {
    super.initState();
    final k = openPhrase;
    if (k != null) WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(audioProvider).sayPhrase(k));
  }
}

