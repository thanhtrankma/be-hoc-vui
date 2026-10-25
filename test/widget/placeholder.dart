// Chỉ dùng trong test: game giả có nút "Xong bài" / "Thắng (thử)" và màn "Đang xây dựng" (chuyển khỏi lib/ để không nằm trong
// bản phát hành — App Store 2.1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/game/game_module.dart';
import 'package:be_vui_hoc/core/ui/ui.dart';

/// Màn "Đang xây dựng" có nút quay lại (về bản đồ nếu không có trang trước).
class UnderConstruction extends ConsumerWidget {
  const UnderConstruction({super.key, required this.title, this.img = 'Building construction', this.note, this.backPath = '/map', this.actions = const []});
  final String title;
  final String img;
  final String? note;
  final String backPath;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [
          TopBar(
            leading: IconBtn(
              icon: AppIcon.back,
              label: 'Back',
              onTap: () {
                ref.read(audioProvider).sfx('tap');
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(backPath);
                }
              },
            ),
            title: title,
          ),
          Expanded(child: UnderConstructionBody(img: img, note: note, actions: actions)),
        ]),
      ),
    );
  }
}

class UnderConstructionBody extends StatelessWidget {
  const UnderConstructionBody({super.key, this.img = 'Building construction', this.note, this.actions = const []});
  final String img;
  final String? note;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 14, children: [
          Bob(child: EmojiImage(img, size: 140, photo: false)),
          const Text('Đang xây dựng', key: Key('under-construction'), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink2)),
          if (note != null) NoteText(note!),
          ...actions,
        ]),
      ),
    );
  }
}

/// GameModule giữ chỗ: hiện "Đang xây dựng" + nút thử "Xong bài" để kiểm tra khung thưởng.
class PlaceholderGame extends GameModule {
  const PlaceholderGame(this.id, {required this.owner, required this.webFile});
  @override
  final String id;

  /// Agent phụ trách (A..I) và file web gốc — để dễ tìm.
  final String owner;
  final String webFile;

  @override
  Widget build(BuildContext context, GameContext ctx) {
    return UnderConstructionBody(
      img: ctx.island.img,
      note: 'Trò chơi "$id" (games/$webFile) — agent $owner',
      actions: [
        AppButton(key: const Key('placeholder-finish'), label: 'Xong bài', icon: '⭐', variant: BtnVariant.green, onTap: () => ctx.finish(3)),
      ],
    );
  }
}

/// FunGameModule giữ chỗ.
class PlaceholderFunGame extends FunGameModule {
  const PlaceholderFunGame(this.id, {required this.owner, required this.webFile});
  @override
  final String id;
  final String owner;
  final String webFile;

  @override
  Widget build(BuildContext context, FunGameContext ctx) {
    final def = funGameDef(id);
    return UnderConstructionBody(
      img: def?.img ?? 'Joystick',
      note: '${def?.vi ?? id} (games/$webFile) — agent $owner',
      actions: [
        AppButton(label: 'Thắng (thử)', icon: '🏆', variant: BtnVariant.green, onTap: () => ctx.finish(const FunResult(score: 10, win: true))),
      ],
    );
  }
}
