// Bảng tra: id game (island.game của app.json) → GameModule, và id game Khu vui chơi → FunGameModule.
// File của Foundation — agent khác KHÔNG sửa. Mỗi agent chỉ thay giá trị biến trong file của mình
// (vd. `final GameModule pickModule = ...` trong lib/features/learn/language/pick.dart).
import 'package:be_vui_hoc/features/fun/action/funracer.dart';
import 'package:be_vui_hoc/features/fun/action/funshooter.dart';
import 'package:be_vui_hoc/features/fun/action/funtank.dart';
import 'package:be_vui_hoc/features/fun/action/funvs1.dart';
import 'package:be_vui_hoc/features/fun/action/funvs2.dart';
import 'package:be_vui_hoc/features/fun/hub/arcade.dart';
import 'package:be_vui_hoc/features/fun/hub/fun.dart';
import 'package:be_vui_hoc/features/fun/hub/funhunt.dart';
import 'package:be_vui_hoc/features/fun/hub/funlogic.dart';
import 'package:be_vui_hoc/features/fun/hub/funmore.dart';
import 'package:be_vui_hoc/features/fun/more/funhero.dart';
import 'package:be_vui_hoc/features/fun/more/funnew1.dart';
import 'package:be_vui_hoc/features/fun/more/funnew2.dart';
import 'package:be_vui_hoc/features/fun/more/funnew3.dart';
import 'package:be_vui_hoc/features/fun/more/funnew4.dart';
import 'package:be_vui_hoc/features/fun/more/funnew5.dart';
import 'package:be_vui_hoc/features/learn/creative/art.dart';
import 'package:be_vui_hoc/features/learn/creative/code.dart';
import 'package:be_vui_hoc/features/learn/creative/logic.dart';
import 'package:be_vui_hoc/features/learn/language/pick.dart';
import 'package:be_vui_hoc/features/learn/language/read.dart';
import 'package:be_vui_hoc/features/learn/language/spell.dart';
import 'package:be_vui_hoc/features/learn/language/trace.dart';
import 'package:be_vui_hoc/features/learn/math/count.dart';
import 'package:be_vui_hoc/features/learn/math/explore.dart';
import 'package:be_vui_hoc/features/learn/math/life.dart';
import 'package:be_vui_hoc/features/learn/math/math.dart';
import 'package:be_vui_hoc/features/learn/math/memory.dart';
import 'package:be_vui_hoc/features/learn/math/music.dart';

import 'fun_games.dart';
import 'game_module.dart';

/// Trò chơi của các đảo học. Chủ: A (pick, spell, trace, read), B (count, math, life, memory, explore, music),
/// C (logic, code, art), E (arcade).
Map<String, GameModule> get gameModules => {
      'pick': pickModule,
      'spell': spellModule,
      'trace': traceModule,
      'read': readModule,
      'count': countModule,
      'math': mathModule,
      'life': lifeModule,
      'memory': memoryModule,
      'explore': exploreModule,
      'music': musicModule,
      'logic': logicModule,
      'code': codeModule,
      'art': artModule,
      'arcade': arcadeModule,
    };

GameModule? gameModuleFor(String? gameId) => gameId == null ? null : gameModules[gameId];

/// Game Khu vui chơi theo id (khớp kFunGames). Chủ: E (fun/hub), F (fun/more), G (fun/action).
Map<String, FunGameModule> get funGameModules => {
      ...funGames,
      ...funlogicGames,
      ...funmoreGames,
      ...funhuntGames,
      ...funnew1Games,
      ...funnew2Games,
      ...funnew3Games,
      ...funnew4Games,
      ...funnew5Games,
      ...funheroGames,
      ...funracerGames,
      ...funshooterGames,
      ...funtankGames,
      ...funvs1Games,
      ...funvs2Games,
    };

FunGameModule? funGameModuleFor(String id) => funGameModules[id];
