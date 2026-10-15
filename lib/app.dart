// Khung app: theme, router, nền trời chung, đếm giờ chơi (giới hạn mỗi ngày), tạm dừng âm thanh khi app vào nền.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';
import 'core/audio/audio_service.dart';
import 'core/store/store.dart';
import 'core/ui/ui.dart';
import 'features/sync/sync.dart';

class BeVuiHocApp extends ConsumerStatefulWidget {
  const BeVuiHocApp({super.key});
  @override
  ConsumerState<BeVuiHocApp> createState() => _BeVuiHocAppState();
}

class _BeVuiHocAppState extends ConsumerState<BeVuiHocApp> with WidgetsBindingObserver {
  Timer? _usage;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Đếm thời gian chơi (chỉ khi app đang mở và có bé đang chơi), 15 giây một lần như web.
    _usage = Timer.periodic(const Duration(seconds: 15), (_) => _tickUsage());
    // Đồng bộ mã gia đình (chỉ chạy khi bố mẹ đã bật trong Góc bố mẹ).
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(syncServiceProvider).init());
    final router = ref.read(routerProvider);
    _router = router;
    router.routerDelegate.addListener(_onRoute);
  }

  GoRouter? _router;
  String _lastPath = '';

  /// Mỗi lần đổi màn (route() của web): dừng giọng đọc của màn cũ, nhớ màn để mở lại (resumeRoute).
  void _onRoute() {
    final uri = ref.read(routerProvider).routerDelegate.currentConfiguration.uri;
    if (uri.path == _lastPath) return;
    _lastPath = uri.path;
    ref.read(audioProvider).stopVoiceOnRoute();
    if (ref.read(startedProvider)) saveResumeRoute(ref.read(storeProvider), uri.path);
  }

  void _tickUsage() {
    if (!_foreground || !ref.read(startedProvider)) return;
    final store = ref.read(storeProvider);
    final router = ref.read(routerProvider);
    final name = routeName(router.routerDelegate.currentConfiguration.uri.path);
    if (store.profile == null || const ['', 'kids', 'new', 'parent', 'report', 'rest'].contains(name)) return;
    store.addUsage(15);
    if (store.overLimit() && name != 'play') router.go('/rest');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = ref.read(audioProvider);
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) audio.suspend();
    if (state == AppLifecycleState.resumed) audio.resume();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _usage?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Bé Vui Học',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        // Nền trời chung cho mọi màn; cỡ chữ gốc theo bề ngang như web.
        return SkyBackground(
          child: DefaultTextStyle(
            style: TextStyle(fontFamily: kFontFamily, fontSize: baseFontSize(context), height: 1.35, color: AppColors.ink),
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
