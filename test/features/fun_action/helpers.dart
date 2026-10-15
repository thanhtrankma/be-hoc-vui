// Tiện ích test cho game hành động (agent G): FunGameContext giả, SilentAudio, game chạy không cần hình.
import 'package:be_vui_hoc/core/audio/audio_service.dart';
import 'package:be_vui_hoc/core/content/content.dart';
import 'package:be_vui_hoc/core/game/fun_games.dart';
import 'package:be_vui_hoc/core/i18n/i18n.dart';
import 'package:be_vui_hoc/core/store/store.dart';

class FakeFun {
  FakeFun({String gameId = 'racer', int level = 0, Json? carry, Json? ticket, this.alive = true}) {
    store = AppStore(null);
    audio = SilentAudio(store: store);
    ctx = FunGameContext(
      gameId: gameId,
      heroImg: 'Man superhero',
      level: level,
      content: Content({}),
      data: AppData.fromJson({}),
      profile: Profile({'id': 'kid1', 'name': 'Bé'}),
      audio: audio,
      i18n: const I18n('vi'),
      store: store,
      carry: carry ?? {},
      free: false,
      ticket: ticket,
      isAlive: () => alive,
      onSaveGear: (c) => saved.add(c),
      onLevelUp: () => ups++,
      onFinish: (r) => results.add(r),
    );
  }
  late final AppStore store;
  late final SilentAudio audio;
  late final FunGameContext ctx;
  bool alive;
  int ups = 0;
  final List<Json> saved = [];
  final List<FunResult?> results = [];
}
