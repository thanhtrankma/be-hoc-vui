// ignore_for_file: prefer_initializing_formals
// Khu vui chơi: danh sách game (FUN_GAMES của games/fun.js) + hợp đồng FunGameModule giữa khung chơi và từng game.
//
// Web: app.js funPlay() trừ vé, gọi gm.run(box, opts) với opts = {hero, alive, level, content, levelUp, carry, saveGear};
// game "leveled" chơi tối đa 3 cấp mỗi vé (thắng cấp nào lên cấp đó), thua thì dừng; xong hiện bảng điểm/kỷ lục.
// Ở đây FunPlayScreen (lib/features/play/fun_play_screen.dart) làm phần khung đó; game chỉ chơi MỘT cấp rồi gọi ctx.finish(result).
// Game không "leveled" (sling, coding, flow, pipes, schulte) tự chơi nhiều cấp, tự gọi ctx.levelUp() và trả lvUp/ups.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../audio/audio_service.dart';
import '../content/content.dart';
import '../i18n/i18n.dart';
import '../store/store.dart';

/// Số cấp chơi liên tiếp mỗi vé (LEVELS_PER_TICKET).
const int kLevelsPerTicket = 3;

class FunGameDef implements Localized {
  const FunGameDef({required this.id, required this.kind, required this.img, required this.vi, required this.en, required this.color, this.hot = false, this.leveled = true});
  final String id;

  /// action | vs | casual | brain
  final String kind;
  final String img;
  final String vi;
  final String en;
  final int color;

  /// Nằm trong nhóm "🔥 Game hay nhất".
  final bool hot;

  /// Khung tự chạy tối đa 3 cấp/vé (leveled() của web). false = game tự lo nhiều cấp.
  final bool leveled;
  Color get colorValue => Color(color);
  @override
  String textOf(String lang) => lang == 'en' ? en : vi;
}

/// Kết quả MỘT lượt chơi game.
class FunResult {
  const FunResult({this.score = 0, this.win = false, this.pvp = false, this.title, this.pos, this.carry, this.lvUp = false, this.ups = 0});

  /// Điểm (xu) của lượt.
  final int score;

  /// Đạt mục tiêu cấp (leveled: lên cấp).
  final bool win;

  /// Hai người chơi (bố/mẹ đấu con): không lên cấp, không ghi kỷ lục.
  final bool pvp;

  /// Tiêu đề riêng cho bảng kết quả (vd. '🏆 Về nhất!').
  final String? title;

  /// Thứ hạng (đua xe): 1 = về nhất.
  final int? pos;

  /// Kho đồ mang sang cấp sau/lượt sau (lưu vào hồ sơ p.gear[id]).
  final Json? carry;

  /// Chỉ game không leveled: đã lên cấp / số cấp đã lên.
  final bool lvUp;
  final int ups;

  FunResult copyWith({int? score, bool? win, bool? lvUp, int? ups}) =>
      FunResult(score: score ?? this.score, win: win ?? this.win, pvp: pvp, title: title, pos: pos, carry: carry, lvUp: lvUp ?? this.lvUp, ups: ups ?? this.ups);
}

/// Mọi thứ một game Khu vui chơi cần (opts của web).
class FunGameContext {
  FunGameContext({
    required this.gameId,
    required this.heroImg,
    required this.level,
    required this.content,
    required this.data,
    required this.profile,
    required this.audio,
    required this.i18n,
    required this.store,
    required this.carry,
    required this.free,
    required bool Function() isAlive,
    required void Function(Json carry) onSaveGear,
    required VoidCallback onLevelUp,
    required void Function(FunResult? r) onFinish,
  })  : _isAlive = isAlive,
        _onSaveGear = onSaveGear,
        _onLevelUp = onLevelUp,
        _onFinish = onFinish;

  final String gameId;

  /// Hình linh vật của bé (opts.hero), vd. 'Man superhero'. Nhân vật vẽ: xem figure.dart (agent C).
  final String heroImg;

  /// Cấp hiện tại 0..59 (opts.level).
  final int level;
  final Content content;
  final AppData data;
  final Profile profile;
  final AudioService audio;
  final I18n i18n;
  final AppStore store;

  /// Kho đồ đã lưu của game này (opts.carry), {} nếu chưa có.
  Json carry;

  /// Bố mẹ chơi miễn phí: không đổi cấp/kỷ lục của bé.
  final bool free;

  final bool Function() _isAlive;
  final void Function(Json) _onSaveGear;
  final VoidCallback _onLevelUp;
  final void Function(FunResult?) _onFinish;
  bool _done = false;

  /// false khi bé đã thoát: dừng game loop.
  bool get alive => _isAlive();

  /// Lưu kho đồ ngay (opts.saveGear).
  void saveGear(Json c) {
    carry = c;
    if (!free) _onSaveGear(c);
  }

  /// Lên một cấp (chỉ game không leveled tự gọi; game leveled để khung lo).
  void levelUp() {
    if (!free) _onLevelUp();
  }

  /// Xong lượt (null = thoát giữa chừng, không tính).
  void finish(FunResult? r) {
    if (_done) return;
    _done = true;
    _onFinish(r);
  }
}

/// Một game Khu vui chơi. build() trả về widget toàn màn (khung chỉ thêm nút ✕ góc trên).
abstract class FunGameModule {
  const FunGameModule();
  String get id;
  Widget build(BuildContext context, FunGameContext ctx);
}

/// Bố mẹ (qua khoá phép tính) được chơi không cần vé; không đổi cấp và kỷ lục của bé. (parentFun của app.js)
final parentFunProvider = StateProvider<bool>((ref) => false);

/// Danh sách game theo thứ tự web.
const List<FunGameDef> kFunGames = [
  FunGameDef(id: 'racer', kind: 'action', img: 'Racing car', vi: 'Đua xe tốc độ', en: 'Speed racer', color: 0xFFFF6B6B, hot: true),
  FunGameDef(id: 'hunt', kind: 'action', img: 'Crossed swords', vi: 'Săn quái vật', en: 'Monster hunt', color: 0xFF7048E8, hot: true),
  FunGameDef(id: 'shooter', kind: 'action', img: 'Rocket', vi: 'Phi thuyền diệt quái', en: 'Space blaster', color: 0xFF5F3DC4, hot: true),
  FunGameDef(id: 'hero', kind: 'action', img: 'Man superhero', vi: 'Siêu nhân diệt quái vật', en: 'Super hero', color: 0xFF1C7ED6, hot: true),
  FunGameDef(id: 'sling', kind: 'action', img: 'Bullseye', vi: 'Ná thần kỳ', en: 'Slingshot', color: 0xFFE8590C, leveled: false),
  FunGameDef(id: 'catch', kind: 'casual', img: 'Basket', vi: 'Hứng trái cây', en: 'Fruit catch', color: 0xFF2F9E44),
  FunGameDef(id: 'whack', kind: 'casual', img: 'Hammer', vi: 'Đập quái vật', en: 'Whack a monster', color: 0xFFE8590C),
  FunGameDef(id: 'fishing', kind: 'casual', img: 'Tropical fish', vi: 'Câu cá', en: 'Fishing', color: 0xFF1C7ED6),
  FunGameDef(id: 'stack', kind: 'casual', img: 'Building construction', vi: 'Xây tháp', en: 'Tower stack', color: 0xFFF08C00),
  FunGameDef(id: 'breakout', kind: 'casual', img: 'Brick', vi: 'Phá gạch', en: 'Brick breaker', color: 0xFF495057),
  FunGameDef(id: 'flappy', kind: 'casual', img: 'Baby chick', vi: 'Chim bay', en: 'Flappy chick', color: 0xFFFAB005),
  FunGameDef(id: 'gallery', kind: 'action', img: 'Water pistol', vi: 'Bắn bia', en: 'Target shooting', color: 0xFFC92A2A),
  FunGameDef(id: 'tank', kind: 'action', img: 'Military helmet', vi: 'Xe tăng dũng cảm', en: 'Brave tank', color: 0xFF2B8A3E, hot: true),
  FunGameDef(id: 'runner', kind: 'action', img: 'T-Rex', vi: 'Khủng long chạy', en: 'Dino run', color: 0xFF5C940D),
  FunGameDef(id: 'pacman', kind: 'action', img: 'Ghost', vi: 'Ăn đậu né ma', en: 'Dot muncher', color: 0xFF364FC7),
  FunGameDef(id: 'snake', kind: 'casual', img: 'Snake', vi: 'Rắn săn mồi', en: 'Snake', color: 0xFF2F9E44),
  FunGameDef(id: 'jumper', kind: 'casual', img: 'Cloud', vi: 'Nhảy lên mây', en: 'Cloud jump', color: 0xFF4DABF7),
  FunGameDef(id: 'frogger', kind: 'casual', img: 'Frog', vi: 'Ếch qua đường', en: 'Frog crossing', color: 0xFF37B24D),
  FunGameDef(id: 'pong', kind: 'casual', img: 'Ping pong', vi: 'Bóng bàn', en: 'Ping pong', color: 0xFFE8590C),
  FunGameDef(id: 'blocks', kind: 'brain', img: 'Puzzle piece', vi: 'Xếp gạch', en: 'Block drop', color: 0xFF7048E8),
  FunGameDef(id: 'match3', kind: 'brain', img: 'Gem stone', vi: 'Ghép 3 hình', en: 'Match three', color: 0xFFD6336C),
  FunGameDef(id: 'fighter', kind: 'vs', img: 'Boxing glove', vi: 'Võ đài', en: 'Fighter', color: 0xFFE03131),
  FunGameDef(id: 'hockey', kind: 'vs', img: 'Ice hockey', vi: 'Khúc côn cầu', en: 'Air hockey', color: 0xFF1C7ED6),
  FunGameDef(id: 'tug', kind: 'vs', img: 'Flexed biceps', vi: 'Kéo co', en: 'Tug of war', color: 0xFFA0522D),
  FunGameDef(id: 'soccer', kind: 'vs', img: 'Soccer ball', vi: 'Bóng đá đầu to', en: 'Head soccer', color: 0xFF2F9E44),
  FunGameDef(id: 'volley', kind: 'vs', img: 'Volleyball', vi: 'Bóng chuyền bãi biển', en: 'Beach volley', color: 0xFFF08C00),
  FunGameDef(id: 'snowball', kind: 'vs', img: 'Snowman', vi: 'Ném tuyết', en: 'Snowball fight', color: 0xFF74C0FC),
  FunGameDef(id: 'tron', kind: 'vs', img: 'Motorcycle', vi: 'Mô tô ánh sáng', en: 'Light bikes', color: 0xFF3B5BDB),
  FunGameDef(id: 'sumo', kind: 'vs', img: 'Person wrestling', vi: 'Đấu sumo', en: 'Sumo', color: 0xFFD6336C),
  FunGameDef(id: 'caro', kind: 'vs', img: 'Cross mark', vi: 'Cờ caro', en: 'Tic-tac-toe', color: 0xFF495057),
  FunGameDef(id: 'connect4', kind: 'vs', img: 'Red circle', vi: 'Nối bốn', en: 'Connect four', color: 0xFFC92A2A),
  FunGameDef(id: 'coding', kind: 'brain', img: 'Robot', vi: 'Lập trình robot', en: 'Code the robot', color: 0xFF0CA678, leveled: false),
  FunGameDef(id: 'flow', kind: 'brain', img: 'Rainbow', vi: 'Nối dây màu', en: 'Connect colors', color: 0xFFD6336C, leveled: false),
  FunGameDef(id: 'pipes', kind: 'brain', img: 'Droplet', vi: 'Dẫn nước', en: 'Water pipes', color: 0xFF1971C2, leveled: false),
  FunGameDef(id: 'schulte', kind: 'brain', img: 'Input numbers', vi: 'Bảng số thần tốc', en: 'Number rush', color: 0xFFF08C00, leveled: false),
  FunGameDef(id: 'lanes', kind: 'action', img: 'Person running', vi: 'Chạy 3 làn', en: 'Lane runner', color: 0xFFF76707),
  FunGameDef(id: 'hoops', kind: 'action', img: 'Basketball', vi: 'Ném bóng rổ', en: 'Basketball', color: 0xFFE8590C),
  FunGameDef(id: 'hurdles', kind: 'action', img: 'Sports medal', vi: 'Chạy vượt rào', en: 'Hurdle race', color: 0xFFD9480F),
  FunGameDef(id: 'firefight', kind: 'action', img: 'Fire engine', vi: 'Lính cứu hoả nhí', en: 'Firefighter', color: 0xFFE03131),
  FunGameDef(id: 'swim', kind: 'casual', img: 'Blowfish', vi: 'Cá con đại dương', en: 'Ocean swim', color: 0xFF1971C2),
  FunGameDef(id: 'dance', kind: 'casual', img: 'Woman dancing', vi: 'Nhảy theo nhạc', en: 'Dance beat', color: 0xFF9C36B5),
  FunGameDef(id: 'farm', kind: 'casual', img: 'Seedling', vi: 'Nông trại vui vẻ', en: 'Happy farm', color: 0xFF5C940D),
  FunGameDef(id: 'balloons', kind: 'casual', img: 'Balloon', vi: 'Bong bóng số', en: 'Number balloons', color: 0xFFF03E3E),
  FunGameDef(id: 'pizza', kind: 'brain', img: 'Pizza', vi: 'Tiệm pizza', en: 'Pizza shop', color: 0xFFE67700),
  FunGameDef(id: 'golf', kind: 'brain', img: 'Flag in hole', vi: 'Golf mini', en: 'Mini golf', color: 0xFF2B8A3E),
  FunGameDef(id: 'hidden', kind: 'brain', img: 'Magnifying glass tilted left', vi: 'Tìm đồ vật', en: 'Hidden objects', color: 0xFF5F3DC4),
  FunGameDef(id: 'trains', kind: 'brain', img: 'Locomotive', vi: 'Bẻ ghi tàu hoả', en: 'Train switch', color: 0xFF364FC7),
  FunGameDef(id: 'truckload', kind: 'brain', img: 'Delivery truck', vi: 'Xếp hàng lên xe', en: 'Load the truck', color: 0xFFA0522D),
];

FunGameDef? funGameDef(String id) {
  for (final g in kFunGames) {
    if (g.id == id) return g;
  }
  return null;
}

/// Cảnh theo cấp (THEMES của funcore.js): cứ 10 cấp đổi cảnh.
class FunTheme {
  const FunTheme({required this.vi, required this.sky, required this.ground, required this.edge, required this.sun, required this.deco});
  final String vi;
  final List<int> sky;
  final int ground;
  final int edge;
  final String sun;
  final List<String> deco;
}

const List<FunTheme> kFunThemes = [
  FunTheme(vi: 'Đồng cỏ', sky: [0xFF74C0FC, 0xFFE7F5FF], ground: 0xFF8CE99A, edge: 0xFF69DB7C, sun: 'Sun with face', deco: ['Deciduous tree', 'Evergreen tree', 'Sunflower', 'House']),
  FunTheme(vi: 'Sa mạc', sky: [0xFFFFA94D, 0xFFFFF3BF], ground: 0xFFFFD8A8, edge: 0xFFFAB005, sun: 'Sun with face', deco: ['Cactus', 'Palm tree', 'Camel', 'Rock']),
  FunTheme(vi: 'Xứ tuyết', sky: [0xFFA5D8FF, 0xFFF8F9FA], ground: 0xFFF1F3F5, edge: 0xFFCED4DA, sun: 'Snowflake', deco: ['Snowman', 'Evergreen tree', 'Christmas tree', 'Snow-capped mountain']),
  FunTheme(vi: 'Thành phố đêm', sky: [0xFF1C2A5A, 0xFF5C7CFA], ground: 0xFF868E96, edge: 0xFF495057, sun: 'Crescent moon', deco: ['Office building', 'House', 'Cityscape', 'Evergreen tree']),
  FunTheme(vi: 'Rừng kẹo', sky: [0xFFF783AC, 0xFFFFF0F6], ground: 0xFFFCC2D7, edge: 0xFFF06595, sun: 'Rainbow', deco: ['Lollipop', 'Candy', 'Doughnut', 'Mushroom']),
  FunTheme(vi: 'Núi lửa', sky: [0xFFC92A2A, 0xFFFFC078], ground: 0xFF8D5524, edge: 0xFFE8590C, sun: 'Volcano', deco: ['Volcano', 'Rock', 'Fire', 'Mountain']),
];

FunTheme funTheme(int lv) => kFunThemes[(lv ~/ 10) % kFunThemes.length];
List<String> funThemeImgs(int lv) => [funTheme(lv).sun, ...funTheme(lv).deco];

/// Chữ kết thúc cấp (endText của funcore.js).
String funEndText(bool win, int lv) => win ? (lv + 1 >= kFunMax ? '🏆 CẤP CAO NHẤT!' : '⭐ LÊN CẤP ${lv + 2}!') : 'CHƯA QUA CẤP';
