// Khung chơi game Khu vui chơi (funPlay() của app.js): trừ vé (bố mẹ chơi miễn phí), chơi tối đa 3 cấp/vé với game
// "leveled", lưu kho đồ, kỷ lục, bảng kết quả (Chơi tiếp tốn 1 vé / Học thêm để có vé).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_service.dart';
import '../../core/content/content.dart';
import '../../core/game/fun_games.dart';
import '../../core/game/registry.dart';
import '../../core/i18n/i18n.dart';
import '../../core/store/store.dart';
import '../../core/ui/ui.dart';

class FunPlayScreen extends ConsumerStatefulWidget {
  const FunPlayScreen({super.key, required this.gameId});
  final String gameId;
  @override
  ConsumerState<FunPlayScreen> createState() => _FunPlayScreenState();
}

class _FunPlayScreenState extends ConsumerState<FunPlayScreen> {
  bool ready = false, alive = true, free = false;
  int level = 0, run = 0, total = 0, ups = 0;
  FunResult? last;
  FunGameDef? def;
  FunGameModule? module;
  FunGameContext? ctx;

  /// Trạng thái dùng chung các cấp của vé này (opts của web) và kho đồ mang sang cấp sau (cả khi bố mẹ chơi miễn phí).
  final Json _ticket = {};
  Json? _carry;

  @override
  void initState() {
    super.initState();
    def = funGameDef(widget.gameId);
    module = funGameModuleFor(widget.gameId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final store = ref.read(storeProvider);
    final p = store.profile;
    if (def == null || module == null || !store.funOn || p == null) {
      context.go('/map');
      return;
    }
    free = ref.read(parentFunProvider);
    if (!free && !store.useTicket()) {
      ref.read(audioProvider).sayPhrase('noTicket');
      context.go('/fun');
      return;
    }
    level = store.funLevel(p, widget.gameId);
    setState(() {
      ready = true;
      _newContext();
    });
  }

  void _newContext() {
    final store = ref.read(storeProvider);
    final p = store.profile!;
    final myRun = run;
    ctx = FunGameContext(
      gameId: widget.gameId,
      heroImg: ref.read(appDataProvider).mascot(p.mascot).img,
      level: level,
      content: ref.read(contentProvider),
      data: ref.read(appDataProvider),
      profile: p,
      audio: ref.read(audioProvider),
      i18n: ref.read(i18nProvider),
      store: store,
      carry: _carry ?? store.gear(p, widget.gameId),
      free: free,
      ticket: _ticket,
      isAlive: () => alive && mounted && run == myRun,
      onSaveGear: (c) => store.saveGear(widget.gameId, c),
      onLevelUp: () => store.funLevelUp(widget.gameId),
      onFinish: (r) => _onLevelDone(r, myRun),
    );
  }

  /// Một lượt (một cấp) xong.
  void _onLevelDone(FunResult? r, int myRun) {
    if (!mounted || !alive || run != myRun) return;
    if (r == null) return _quit();
    final store = ref.read(storeProvider);
    if (!def!.leveled || r.pvp) return _result(r);
    // Kho đồ mang sang cấp sau và lưu vào hồ sơ, thắng hay thua đều giữ.
    if (r.carry != null) {
      _carry = r.carry;
      if (!free) store.saveGear(widget.gameId, r.carry);
    }
    total += r.score;
    last = r;
    if (r.win) {
      ups++;
      if (!free) store.funLevelUp(widget.gameId);
    }
    final stop = !r.win || ups >= kLevelsPerTicket || level + 1 >= kFunMax;
    if (stop) return _result(r.copyWith(score: total, win: ups > 0, lvUp: ups > 0, ups: ups));
    setState(() {
      level++;
      run++;
      _newContext();
    });
  }

  void _quit() {
    alive = false;
    ref.read(audioProvider).engine(0);
    ref.read(audioProvider).stopVoice();
    context.go('/fun');
  }

  void _result(FunResult res) {
    alive = false;
    final store = ref.read(storeProvider);
    final audio = ref.read(audioProvider);
    final i = ref.read(i18nProvider);
    final p = store.profile!;
    audio.engine(0);
    final rec = free || res.pvp ? false : store.saveBest(widget.gameId, res.score);
    audio.sfx('win');
    if (res.win || rec) confetti();
    audio.sayPhrase(rec ? 'newRecord' : res.win ? 'youWin' : 'gameOver');
    final title = res.title ??
        (res.pos != null ? (res.pos == 1 ? '🏆 ${i.t('first')}' : '🏁 ${i.t('place', {'n': res.pos})}') : res.win ? '🏆 ${i.t('youWin')}' : i.t('gameOver'));
    final canAgain = free || store.tickets(p) > 0;
    showPanel<void>(
      context: context,
      builder: (c) => Column(key: const Key('fun-result'), mainAxisSize: MainAxisSize.min, children: [
        PanelTitle(title),
        Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [
          const EmojiImage('Coin', size: 56, photo: false),
          Text('${res.score}', style: TextStyle(fontSize: baseFontSize(c) * 2.2, fontWeight: FontWeight.w800)),
        ]),
        if (res.lvUp && !free)
          Prize(img: 'Glowing star', text: '+${math.max(1, res.ups)} ${i.t('level').toLowerCase()} → ${i.t('level')} ${store.funLevel(p, widget.gameId) + 1}/$kFunMax'),
        if (rec) Prize(img: 'Trophy', text: i.t('newRecord')) else NoteText('🏆 ${asInt(p.best[widget.gameId])}'),
        PanelRow(children: [
          AppButton(icon: '🎮', label: i.t('funZone'), variant: BtnVariant.ghostPanel, onTap: () {
            Navigator.pop(c);
            context.go('/fun');
          }),
          if (canAgain)
            AppButton(
              icon: res.lvUp ? '▶' : '🔄',
              label: '${i.t(res.lvUp ? 'nextLv' : 'again')}${free ? '' : ' (🎟️ 1)'}',
              variant: BtnVariant.blue,
              onTap: () {
                Navigator.pop(c);
                // Đường dẫn khác (thêm ?r=) để dựng màn mới: trừ vé lần nữa như route() của web.
                context.go('/fun/${widget.gameId}?r=${DateTime.now().millisecondsSinceEpoch}');
              },
            )
          else
            AppButton(icon: '📚', label: i.t('learnMore'), variant: BtnVariant.green, onTap: () {
              Navigator.pop(c);
              context.go('/map');
            }),
        ]),
      ]),
    );
  }

  @override
  void dispose() {
    alive = false;
    try {
      ref.read(audioProvider).engine(0);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = ref.watch(i18nProvider);
    // Như web (PWA, thanh trạng thái 'default'): game không vẽ dưới thanh trạng thái / tai thỏ,
    // nếu không HUD ở góc trên (hạng, điểm, máu...) bị đồng hồ và Dynamic Island che.
    // Đáy cũng vậy: thanh điều hướng Android (edge-to-edge) và vạch Home của iPhone không được che nút điều khiển.
    final pad = MediaQuery.paddingOf(context);
    final top = pad.top;
    // SkyCover: nền đục che kín trời → mây phía sau ngừng chạy (hiệu năng).
    return SkyCover(child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(fit: StackFit.expand, children: [
        if (ready && ctx != null)
          Positioned(
            top: top,
            left: pad.left,
            right: pad.right,
            bottom: pad.bottom,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              removeLeft: true,
              removeRight: true,
              child: KeyedSubtree(key: ValueKey('fun-$run'), child: Builder(builder: (c) => module!.build(c, ctx!))),
            ),
          ),
        // .funquit: top: max(70px, safe-area) — nằm dưới hàng HUD của game.
        Positioned(
          top: top + 70,
          left: math.max(12, MediaQuery.paddingOf(context).left),
          child: Opacity(
            opacity: .85,
            child: IconBtn(key: const Key('fun-quit'), icon: AppIcon.close, size: 48, label: i.t('close'), onTap: _quit),
          ),
        ),
      ]),
    ));
  }
}
