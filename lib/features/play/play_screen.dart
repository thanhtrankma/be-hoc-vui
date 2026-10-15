// Màn chơi (play() của app.js): thanh trên (quay lại, tiến độ, sao), vùng stage chứa GameModule, linh vật góc dưới.
// Xong bài (ctx.finish) → finishRound(): ghi sao, hình dán, vé, thử thách ngày, huy hiệu, mốc tiến bộ, bảng kết quả.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/content/levels.dart';
import '../../core/game/game_module.dart';
import '../../core/game/learn_tracking.dart';
import '../../core/game/registry.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';
import 'finish_round.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.islandId, required this.levelIndex, this.from});
  final String islandId;
  final int levelIndex;

  /// 'lop1' khi mở từ Học cùng lớp.
  final String? from;

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> with SingleTickerProviderStateMixin {
  bool aborted = false;
  bool valid = false;
  int gen = 0; // tăng khi "Chơi lại" để dựng game mới
  int progI = 0, progN = 0;
  bool buddyVisible = true;
  late final AnimationController buddyAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  String buddyMode = '';
  GameContext? ctx;
  GameModule? module;
  Island? island;

  String get homePath => widget.from == 'lop1' ? '/lop1' : '/island/${widget.islandId}';

  @override
  void initState() {
    super.initState();
    final data = ref.read(appDataProvider);
    final content = ref.read(contentProvider);
    final store = ref.read(storeProvider);
    final p = store.profile;
    final isl = data.island(widget.islandId);
    final total = isl == null ? 0 : levelsOf(isl, content).length;
    final li = widget.levelIndex;
    valid =
        p != null &&
        isl != null &&
        !isl.soon &&
        isl.route == null &&
        li >= 0 &&
        li < total &&
        levelUnlocked(lockOrder: store.lockOrder, isl: isl, content: content, i: li, starsOf: (k) => store.levelStars(p, isl.id, k));
    island = isl;
    module = gameModuleFor(isl?.game);
    if (!valid || module == null) {
      valid = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/map');
      });
      return;
    }
    _newContext();
    // Hồ sơ cũ chưa có p.learn: tạo (có ghi máy) sau khung hình đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = ref.read(storeProvider).profile;
      if (p != null) ref.read(learnTrackerProvider).ensureLearn(p);
    });
  }

  void _newContext() {
    final store = ref.read(storeProvider);
    final p = store.profile!;
    final isl = island!;
    final content = ref.read(contentProvider);
    final data = ref.read(appDataProvider);
    final tracker = ref.read(learnTrackerProvider);
    final lvData = levelData(isl, content, widget.levelIndex);
    final myGen = gen;
    ctx = GameContext(
      island: isl,
      levelIndex: widget.levelIndex,
      level: lvData,
      content: content,
      data: data,
      profile: p,
      tier: tracker.tierForIsland(isl, p),
      audio: ref.read(audioProvider),
      i18n: ref.read(i18nProvider),
      store: store,
      buddyImg: data.mascot(p.mascot).img,
      from: widget.from,
      isAborted: () => aborted || !mounted || gen != myGen,
      onProgress: (i, n) {
        if (mounted && gen == myGen) {
          setState(() {
            progI = i;
            progN = n;
          });
        }
      },
      onBuddy: _animBuddy,
      onBuddyVisible: (v) {
        if (mounted) setState(() => buddyVisible = v);
      },
      onRecord: (q) => tracker.recordForLevel(isl, lvData, q),
      onFinish: (r) => _finish(r, myGen),
      onExit: _back,
      onGate: (c) => parentGate(c, ref),
    );
  }

  void _animBuddy(String mode) {
    if (!mounted) return;
    setState(() => buddyMode = mode);
    buddyAnim.forward(from: 0);
  }

  void _back() {
    ref.read(audioProvider).sfx('tap');
    _leave();
    context.go(homePath);
  }

  void _leave() {
    aborted = true;
    ref.read(audioProvider).stopVoice();
  }

  Future<void> _finish(GameResult r, int myGen) async {
    if (!mounted || aborted || gen != myGen) return;
    await finishRound(
      context,
      ref,
      island: island!,
      li: widget.levelIndex,
      stars: r.stars,
      from: widget.from,
      onAgain: () {
        if (!mounted) return;
        // route(true) của web chạy lại các chặn: hết giờ chơi hôm nay → màn nghỉ.
        if (ref.read(storeProvider).overLimit()) return context.go('/rest');
        setState(() {
          gen++;
          progI = progN = 0;
          buddyVisible = true;
          _newContext();
        });
      },
    );
  }

  @override
  void dispose() {
    aborted = true;
    buddyAnim.dispose();
    try {
      ref.read(audioProvider).stopVoice();
    } catch (_) {
      /* ref đã huỷ */
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!valid || ctx == null) return const AppScreen(child: SizedBox());
    // Chỉ dựng lại khi số sao (hoặc bé) đổi — không dựng lại cả màn chơi mỗi lần lưu dữ liệu (15 giây/lần, mỗi câu...).
    ref.watch(storeProvider.select((s) => (s.activeId, s.profile?.stars)));
    final p = ref.read(storeProvider).profile;
    if (p == null) return const SizedBox();
    final i = ref.watch(i18nProvider);
    final size = MediaQuery.sizeOf(context);
    final buddySize = (size.width * .10).clamp(70.0, 120.0);
    final hideBuddy = size.height <= 640 && size.width > size.height;
    // Back của Android: IconBtn 'play-back' tự nhận (PopScope trong IconBtn) → _back.
    return Stack(
      children: [
        AppScreen(
          child: Column(
            children: [
              TopBar(
                leading: IconBtn(key: const Key('play-back'), icon: AppIcon.back, label: 'Back', onTap: _back),
                titleWidget: Center(
                  child: ProgressSegments(index: progI, total: progN),
                ),
                trailing: Pill(children: [const EmojiImage('Glowing star', size: 34, photo: false), Text('${p.stars}')]),
                bottomGap: 10,
              ),
              Expanded(
                child: PhotoScope(
                  enabled: true,
                  child: KeyedSubtree(
                    key: ValueKey('game-$gen'),
                    child: Builder(builder: (context) => module!.build(context, ctx!)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (buddyVisible && !hideBuddy)
          Positioned(
            left: math.max(8, MediaQuery.paddingOf(context).left),
            bottom: math.max(8, MediaQuery.paddingOf(context).bottom),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: buddyAnim,
                builder: (context, child) {
                  final t = buddyAnim.value;
                  if (buddyMode == 'cheer') {
                    // cheer: 30% -40px xoay -10°, 60% -20px xoay 8°
                    final y = t < .3
                        ? -40 * t / .3
                        : t < .6
                        ? -40 + 20 * (t - .3) / .3
                        : -20 * (1 - (t - .6) / .4);
                    final r = t < .3
                        ? -10 * t / .3
                        : t < .6
                        ? -10 + 18 * (t - .3) / .3
                        : 8 * (1 - (t - .6) / .4);
                    return Transform.translate(
                      offset: Offset(0, y),
                      child: Transform.rotate(angle: r * math.pi / 180, child: child),
                    );
                  }
                  if (buddyMode == 'sad') {
                    final r = 12 * math.sin(t * 2 * math.pi) * (t < 1 ? 1 : 0);
                    return Transform.rotate(angle: -r * math.pi / 180, child: child);
                  }
                  return child!;
                },
                child: Semantics(
                  label: i.t('buddies'),
                  child: Dressed(profile: p, size: buddySize, showBg: false),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Thanh tiến độ liền mạch của màn chơi (.game .topbar .progress): xong = xanh, đang làm = vàng.
class ProgressSegments extends StatelessWidget {
  const ProgressSegments({super.key, required this.index, required this.total});
  final int index;
  final int total;
  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox(height: 26);
    return ConstrainedBox(
      key: const Key('progress'),
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(999)),
        child: Row(
          spacing: 4,
          children: [
            for (var k = 0; k < total; k++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(k == 0 ? 99 : 4), right: Radius.circular(k == total - 1 ? 99 : 4)),
                    color: k < index || k == index ? null : const Color(0xFFE6EDF6),
                    gradient: k < index
                        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6EE79A), AppColors.good])
                        : k == index
                        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE08A), AppColors.sun])
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
