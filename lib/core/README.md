# lib/core — contracts for feature agents

Foundation layer of the Flutter port of Bé Vui Học (`reference/web/` is the source of truth for behavior).
Read this before porting a web module.

## 0. Folder ownership (hard rule)

| Agent | Folder | Public names you must keep (router/registry point at them) |
|---|---|---|
| A | `lib/features/learn/language/` | `pickModule`, `spellModule`, `traceModule`, `readModule`, `ReviewScreen({mode, item})`; quiz API in `quiz.dart`; `sheets.dart` re-exports core sprite sheets |
| B | `lib/features/learn/math/` | `countModule`, `mathModule`, `lifeModule`, `memoryModule`, `exploreModule`, `musicModule` |
| C | `lib/features/learn/creative/` | `logicModule`, `codeModule`, `artModule`; figure API in `figure.dart` |
| D | `lib/features/room/` | `RoomScreen`, `PetScreen`, `StickersScreen` (/album), `DuelScreen`, `Lop1Screen` |
| E | `lib/features/fun/hub/` | `FunHubScreen`, `funGames` (sling), `funlogicGames`, `funmoreGames`, `funhuntGames`, `arcadeModule` |
| F | `lib/features/fun/more/` | `funnew1Games` … `funnew5Games`, `funheroGames` |
| G | `lib/features/fun/action/` | `funracerGames`, `funshooterGames`, `funtankGames`, `funvs1Games`, `funvs2Games` |
| H | `lib/features/rpg/` | `RpgTownScreen`, `RpgStageScreen({zone, stage})` |
| I | `lib/features/parents/`, `lib/features/sync/` | `ParentsScreen`, `ReportScreen({kidId})`, `SyncService` API + `syncServiceProvider` |

**Only edit files inside your folder.** Never edit `pubspec.yaml`, `lib/core/**`, `lib/app*.dart`,
`lib/main.dart`, `lib/features/{home,map,tiers,play}` or another agent's folder. Need a core change or a new
package? Write it in your final report. You may add new files in your folder.

Cross-agent imports: only use the **declared stub APIs** that already exist now — `learn/language/quiz.dart`
(A), `learn/creative/figure.dart` (C), `sync/sync.dart` (I). Their owners keep those signatures stable.
Do NOT import other agents' helper files (funcore, funfx, motionb, funvs1, rpgcore, petrig...) — write your own
copy inside your folder. Shared helpers live in core (below).

Everything is exported from a few entry points:
```dart
import 'package:be_vui_hoc/core/ui/ui.dart';            // theme, widgets, images, overlay, motion, utils, sprites
import 'package:be_vui_hoc/core/game/game_module.dart';  // GameModule, GameContext, QuizRecord, GameResult
import 'package:be_vui_hoc/core/game/fun_games.dart';    // FunGameModule, FunGameContext, FunResult, kFunGames, themes
```

## 1. Island games: `GameModule` + `GameContext`

Web: `mod.run(g, islandId, content, li)` → `{stars}`. Flutter:

```dart
final GameModule countModule = CountGame();

class CountGame extends GameModule {
  @override String get id => 'count';
  @override Widget build(BuildContext context, GameContext ctx) => CountView(ctx: ctx);
}
```

`PlayScreen` (route `/play/<island>/<li>[/lop1]`) draws the top bar (back, progress bar, star pill) and the
mascot buddy, and calls `module.build()` for the stage area (wrapped in `PhotoScope(enabled: true)`).
"Chơi lại" rebuilds your widget with a new key and a fresh `GameContext`.

`GameContext` (lib/core/game/game_module.dart):

| member | meaning (web equivalent) |
|---|---|
| `island` / `islandId` | `Island` from app.json (`id`, `game`, `img`, `color`, vi/en). `letters` and `english` both use game `pick` |
| `levelIndex`, `level` | `li` and raw level JSON `content[levelsKey][li]` (e.g. `{"kind":"add","max":5,...}`) |
| `content`, `data` | `Content` (content.json) and `AppData` (app.json) |
| `profile`, `store`, `tier` | current kid, `AppStore`, tier being viewed (0/1/2/3) |
| `audio`, `i18n` | `AudioService`, `I18n` |
| `buddyImg`, `from` | mascot image name; `'lop1'` when launched from Học cùng lớp |
| `aborted` | `g.aborted()` — true after the kid leaves; check after every `await` and stop loops |
| `progress(i, n)` | `g.progress(i, n)`; call `progress(n, n)` at the end |
| `cheer()`, `sad()` | buddy animations (`g.cheer/g.sad`) |
| `hideBuddy()`, `showBuddy()` | hide mascot (drawing games) |
| `record(QuizRecord(...))` | `g.record(q, picks, ms)`: `answer`, `say`, `reward`, `picks` (wrong taps), `ms` |
| `gate(context)` | parent math gate → `Future<bool>` |
| **`finish(stars)`** | **award stars (1..3) and end the level** (`run()` resolving `{stars}`) |
| `exit()` | leave without result |

Rewards (stars, stickers, tickets, daily challenge, badges, milestones, pet happiness, lop1 next/bonus,
result panel with Again/Next) are done by the frame — games only call `ctx.finish(stars)`.
Quiz scoring: `starsFor(mistakes)` → 0 errors = 3, ≤2 = 2, else 1.

Quiz-based games: use `QuizView(ctx:, questions: [QuizQuestion(...)], options: QuizOptions(intro: 'countIntro'), onDone: ctx.finish)`
from `features/learn/language/quiz.dart` (A owns and polishes it; the API is stable).

## 2. Fun-zone games: `FunGameModule` + `FunGameContext`

Route `/fun/<id>` → `FunPlayScreen` (Foundation) takes a ticket (unless `parentFunProvider` is true), builds
your module full-screen with a ✕ button, and handles the "leveled" loop: for `FunGameDef.leveled == true`
your widget plays **one level** then calls `ctx.finish(FunResult(score:, win:, carry:))`; the frame levels up
(`store.funLevelUp`), rebuilds with `ctx.level + 1`, max 3 levels per ticket, then shows score/record/next.
Non-leveled games (sling, coding, flow, pipes, schulte) run several levels themselves, call `ctx.levelUp()`
and return `FunResult(lvUp:, ups:)`. `FunResult(pvp: true)` = 2-player (no level/record).
`ctx.finish(null)` = quit. `ctx.alive` false → stop the game loop. `ctx.carry`/`ctx.saveGear(json)` = per-game
inventory (`p.gear[id]`). `ctx.heroImg` = kid's mascot image; character costumes via `figure.dart` `heroOf()`.
Game list/metadata: `kFunGames` (ids, kind, hot, colors). Level themes: `funTheme(lv)`, `funEndText`, `kFunMax` (60).
Flame is available (`flame` package) — embed a `GameWidget` in your `build()`.

RPG (H) handles its own ticket: `store.useTicket()`, free when `ref.read(parentFunProvider)`.

## 3. Content

```dart
final content = ref.watch(contentProvider);   // or ctx.content
content.list('vnwords')        // List<Map<String,dynamic>>
content.strings('rimes')       // List<String>
content.map('categories')      // Map
content.level('countLevels', li)
final data = ref.watch(appDataProvider);      // islands, mascots, stickers, wardrobe, pets, petItems, images
```
Helpers: `levelsOf(island, content)`, `levelData`, `kTiers`/`tierOf`, `tierFor`, `tierLevels`, `levelUnlocked`
(`core/content/levels.dart`); `placeTone(rime, tone)`, `nfc()` (`core/content/vn_text.dart`); JSON readers
`asInt/asStr/asMapList/parseColor` (`core/content/models.dart`). `L()`-style localization of data:
`i18n.L(mapOrIslandOrLText)`.

## 4. Audio (`ctx.audio` / `ref.read(audioProvider)`)

```dart
await audio.say(audio.tpl('findLetter', letterJson));   // template from voice.json
await audio.sayPhrase('praise1');                         // fixed phrase
await audio.sayAll([line1, line2]);                      // sequence; stops if interrupted
audio.stopVoice();  audio.praise();  audio.retry();  audio.praiseItem();
audio.sfx('correct'|'wrong'|'tap'|'win'|'star'|'pop'|'flip'|'count'|'coin'|'boom'|'laser'|'jump'|'hit'|'power'|...);
final stop = await audio.clip('dog-bark1', rate: 1, vol: 1, loop: false);  // assets/sfx/*.mp3
audio.note(0..7);  audio.engine(0..1);  audio.preload([...]);  await audio.clipDuration(line);
```
`VoiceLine(lang, text)` = web `[lang, text]`; voice file (.ogg Opus) lookup via audio.json. `say()` interrupts the current line
(same semantics as web). Sound setting off → silent. Tests use `SilentAudio` (logs calls, completes immediately).

## 5. Store (`ref.watch(storeProvider)` / `ctx.store`) — same JSON as web localStorage `bvh.v1`

`profile` (extension type over the raw JSON map: `p.stars`, `p.levels`, `p.pet`, `p.json['anything']`),
`profiles`, `settings` (`lang, music, sound, limit, fun, ticketsPer, lockOrder`), `setSetting`, `addProfile`,
`updateProfile`, `removeProfile`, `levelStars`, `recordRound`, `wallet/buy/equip`, `daily/dailyProgress`,
`newBadges`, `tickets/addTickets/useTicket`, `saveBest`, `funLevel/funLevelUp`, `gear/saveGear`, `learn`,
`recordAnswer`, `dueItems`, `recordReview`, `addMilestones`, `exportData/importData`, `snapshot/mergeRemote`,
`onSave` (sync hook), `getKv/setKv` (other localStorage keys like `bvh.micOK`, `bvh.sync`).
Writing custom fields: mutate `p.json[...]` then `store.save()`. **Never call `save()` (or anything that saves)
during `build()`** — do it in callbacks or `addPostFrameCallback`.
Learning analytics/milestones/badges: `learnTrackerProvider` (`core/game/learn_tracking.dart`).
Học cùng lớp data: `classPlanProvider` (`core/game/class_plan.dart`).

## 6. Images

`EmojiImage('Red apple', size: 80)` → `assets/img/red-apple.webp` (`slug()` like ui.js). Inside a level
(PhotoScope on) names with a real photo in photos.json use the photo; pass `photo: false` to force cartoon;
`groupUsesPhotos(photos, names)` = web `unifyPhotos` rule for a group of choices.
Canvas/Flame: `await loadEmojiUiImages(names)`, `loadUiImage('assets/...')`, `drawImageCentered(...)`.
Sprite sheets: `loadSheet('play/kidboy')`, `frameAt`, `drawFrame`, `drawAnim` (`core/ui/sprite_sheet.dart`).

## 7. UI kit (`core/ui/ui.dart`)

`AppColors`, `AppTheme`, `baseFontSize(context)` (1em), `vwClamp`; `AppScreen` (page frame over the sky
background), `TopBar`, `ScreenTitle`, `IconBtn(icon: AppIcon.back|close|gear|kids)`, `AppButton(variant: primary|blue|green|ghost|ghostPanel, big:)`,
`Chunky` (any pressable card with solid shadow), `Pill`, `CardBox`, `Seg`, `ProgressDots`, `StarRow`, `ToneMark`,
`Dressed` (mascot with outfit), `showPanel` + `Panel/PanelTitle/PanelRow/NoteText/Prize/BigStars`,
`toast()`, `confetti()`, `confirmPanel()`, `promptPanel()`, `parentGate()`, `ParentButton`,
`Bob`/`Hop`/`LoopAnim`/`RiseIn` (respect `Motion.enabled`; tests set it false), `SayOnOpen` mixin,
`shuffle/sample/pick/sequence/wait/rand/ramp/approach/ease*`. Navigation: `context.go('/map')` (go_router).

## 8. Testing

`flutter analyze` clean, `flutter test` green. For widget tests override `contentBundleProvider`
(`await loadContentBundle(rootBundle)`), `storeProvider` (`AppStore(prefs)` with `SharedPreferences.setMockInitialValues`)
and `audioProvider` (`SilentAudio`), and set `Motion.enabled = false`. See `test/widget/app_flow_test.dart`.
