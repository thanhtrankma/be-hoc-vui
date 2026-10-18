> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Parity audit: hunt + hero (web web js/games → Flutter lib/)

Web: `W:funhunt.js`, `W:funhero.js`, `W:fun.js` (leveled loop), `W:app.js`, `W:funcore.js`, `W:figure.js`.
Flutter: `D:funhunt.dart` = lib/features/fun/hub/funhunt.dart, `D:funhero.dart` = lib/features/fun/more/funhero.dart, `D:funkit.dart` = lib/features/fun/more/kit/funkit.dart, `D:hubcore` = lib/features/fun/hub/funcore.dart, `D:play` = lib/features/play/fun_play_screen.dart, `D:games` = lib/core/game/fun_games.dart.

Summary: hunt OK 44 / PARTIAL 2 / MISSING 0 / OMITTED-OK 5; hero OK 48 / PARTIAL 2 / MISSING 0 / OMITTED-OK 4. (The free-mode carry PARTIAL is a single frame issue that shows up in both games.)

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funhunt | hunt | SKILLS table (12 skills: img, colour, atk flag) | W:funhunt.js:12-25 | D:funhunt.dart:30-43 | OK | Identical keys, imgs, colours, atk set (8 weapons). Adds EN names. |
| funhunt | hunt | SK_MAX=5, CAP=45 | W:26 | D:44-48 | OK | |
| funhunt | hunt | PERM (hp/speed/power/gem), PERM_MAX=5, price=80+40n | W:28-34 | D:51-60 | OK | |
| funhunt | hunt | readCarry: defensive parse, gun≥1, off filtered to owned skills, coins clamp 1e7 | W:52-62 | D:74-89 | OK | Tiny parse nuance: numeric strings like "3.7" give 3 on web and 0 in Dart (`int.tryParse`). Real carries always hold ints, so no practical effect. |
| funhunt | hunt | mergeCarry (owned skills/perm never drop below saved) | W:65-70 | D:92-101 | OK | |
| funhunt | hunt | Armory: buy perm (cost, MAX, wrong sfx, pop anim, save on buy), coin counter | W:104-135 | D:177-341 | OK | Flutter widget instead of DOM. Same 4-col grid / 2-col ≤640px. |
| funhunt | hunt | Armory: toggle owned skills, keep ≥1 attack weapon on | W:121-127 | D:211-225 | OK | |
| funhunt | hunt | Armory only before 1st level of ticket (opts._huntShop) | W:144-146, W:fun.js:143-160 | D:109-158 | OK | Emulated with module-level `_skipShop`/`_chain` that mirrors the frame stop rule (`kLevelsPerTicket`, `level+1<kFunMax`). Equivalent. |
| funhunt | hunt | Level ramp: DUR 55→75, hpK, spK, CAPN 32→60, spawnBase 1.05→.3, power factor | W:155-159 | D:441-448, 502 | OK | Same formulas. |
| funhunt | hunt | maxHp=5+perm.hp+heart, speed, need() xp curve, perm.gem head-start xp | W:162-170 | D:480-509 | OK | |
| funhunt | hunt | Touch: floating joystick at touch point, follows finger, JR=min(70,S*.11) | W:176-188, 309-312 | D:523-546, 777-787 | OK | |
| funhunt | hunt | Keyboard arrows + WASD, normalised diagonal | W:189-191, 314-316 | D:790-799; D:hubcore keys/Focus autofocus | OK | |
| funhunt | hunt | Skill card generation (weighted, owned×2, atk×1.3, force ≥1 atk, fill coins/heal, CAP → coins/heal only) | W:194-212 | D:549-574 | OK | |
| funhunt | hunt | choose(): +5 coins / full heal / skill+1 (unoff; heart +2hp; pet sync; armor reset) then save | W:213-226 | D:577-605 | OK | |
| funhunt | hunt | Card tap guards (t≥.45, lift after finger up, single pick, .35s close) | W:227-230, 296-302 | D:607-613, 747-763 | OK | |
| funhunt | hunt | 10 foe kinds, spawnFoe (cap, off-screen ring, elite ×10hp ×1.7 size ×.8 speed, hp grows with t) | W:38-49, 234-242 | D:355-366, 618-631 | OK | |
| funhunt | hunt | Waves every DUR/4: ring of n=ramp(8,16) + elite; "ĐỢT n!" msg | W:325-332 | D:816-828 | OK | |
| funhunt | hunt | Trickle spawn (rate, group size, slower under boss) | W:333-341 | D:829-839 | OK | |
| funhunt | hunt | Foe behaviours: hop, zig, re-place in front when far, fslime shoots (lv≥12), contact dmg (elite lv≥40 → 2) | W:346-358 | D:844-888 | OK | |
| funhunt | hunt | Foe separation (no overlap) | W:360-366 | D:890-902 | OK | |
| funhunt | hunt | Boss by lv/10: Vua slime / Rồng / Quỷ khổng lồ | W:50, 139 | D:367, 427 | OK | |
| funhunt | hunt | Boss: hp ramp(40,1200)×power, chase, ring bullets, summons, aimed dash lv≥15, rage ×.75, contact dmg (lv≥30 → 2), frost slows | W:272-276, 369-385 | D:701-708, 905-961 | OK | |
| funhunt | hunt | Boss death: explosions, 10 flying coins, kill all foes, gems fly, end after 1.6s | W:386-397 | D:962-986 | OK | |
| funhunt | hunt | Gun (alternates boss/nearest, n=[1,1,2,2,3], cd .62-.06l, dmg, pierce at l5) | W:401-413 | D:993-1009 | OK | |
| funhunt | hunt | Fireball (cd 2.4-.25l, 2 shots at l≥4, AoE on impact) | W:414-423, 485-491 | D:1010-1023, 1106-1125 | OK | |
| funhunt | hunt | Boomerang (out-and-back arc, per-foe hit cooldown .3) | W:424-434, 473-479 | D:1024-1037, 1085-1098 | OK | |
| funhunt | hunt | Lightning (random visible targets [1,2,2,3,4]) | W:435-448 | D:1038-1053 | OK | |
| funhunt | hunt | Meteor (delayed AoE, 50% boss bias) | W:449-459, 494-497 | D:1054-1064, 1129-1140 | OK | |
| funhunt | hunt | Orbiting knives (l knives, .35 hit cooldown) | W:462-469 | D:1067-1080 | OK | |
| funhunt | hunt | Frost ring (radius, slow, dps) | W:345, 355, 375 | D:843, 876-879, 929-932 | OK | |
| funhunt | hunt | Pet dogs (1 or 2 at l≥4, chase nearest, bite cd, teleport back) | W:171, 500-510 | D:513-518, 1146-1175 | OK | |
| funhunt | hunt | Armor shield regen (13-2l s), hurtMe (shield pop, inv 1.3+.1l), death | W:278-283, 322 | D:710-729, 806-813 | OK | |
| funhunt | hunt | Enemy bullets | W:513-517 | D:1178-1191 | OK | |
| funhunt | hunt | Drops: gems (blue/green lv≥30/red elite, cap 140 merge), coins 4%, hearts 1.2%, elite drops; magnet radius; pickup → xp/pickQ, coins++ | W:249-262, 519-535 | D:644-672, 1193-1234 | OK | |
| funhunt | hunt | Gem recolour when merged gem hits v=3 | W:257 | D:659-664 | OMITTED-OK | The web checks `gems[last]`, not the merged gem, so the recolour is an accidental cosmetic quirk. Dart colours a gem green only when it spawns with v=3. Gameplay is the same. |
| funhunt | hunt | finish(): win bonus 5+lv/5 coins, +50 score, score+=earned; lose at 0 hp | W:284-292 | D:731-743 | OK | |
| funhunt | hunt | End timing (win 2s / lose 2.2s), turbo loop | W:704-709 | D:1272-1281 | OK | |
| funhunt | hunt | Carry save points: every buy/toggle/card pick (saveGear merged), FunResult.carry at end | W:143, 225, 289 | D:145, 520, 604, 741 | OK | |
| funhunt | hunt | Carry passed between levels of one ticket in parent-free mode | W:fun.js:152 (`opts.carry = r.carry`), W:app.js:914 | D:play:75 (`carry: store.gear(...)` each level), D:play:91, D:games:123-126 | PARTIAL | Frame issue. In free mode Dart never writes the store, and `_newContext()` rereads `store.gear`. Skills, coins and buys from level k are lost for level k+1 of the same ticket. The web keeps them in `opts.carry`. |
| funhunt | hunt | Camera follow, screen shake, dust/booms/float text | W:580-584, 151 | D:436-439, 1343-1349 | OK | |
| funhunt | hunt | Ground grid (grass dots + hashed deco), frost ring visuals | W:586-604 | D:1351-1392 | OK | The dashed frost ring is drawn as arc segments, rotating like `lineDashOffset`. |
| funhunt | hunt | Sprites: plat/enemies, creatures/flyers (fly, dragon), plat/tiles (gems, fireball), fxa/fx; figure with water pistol; Ogre image | W:142, 557-579, 613 | D:434, 1289-1341, 1415 | OK | All frames exist in assets/sprites (checked). Dart adds circle fallbacks if a sheet is missing. |
| funhunt | hunt | HUD: coins, timer (hidden in boss), boss bar, hearts (2nd row narrow), shield icon, xp bar (gold at CAP), owned skill icons + stars (dim off), joystick, msg | W:637-667 | D:1466-1501 | OK | |
| funhunt | hunt | Card overlay drawing (wide 3-col / narrow stacked, stars lv+1, MỚI! badge, select scale) | W:668-702 | D:1503-1553 | OK | Bilingual. |
| funhunt | hunt | Level banner (t<2.8) + end banner | W:714-716 | D:1559-1565 | OK | |
| funhunt | hunt | 2-player | n/a | n/a | OMITTED-OK | The web has no 2P mode. |
| funhunt | hunt | Records/best score, level-up per win, max 3 levels/ticket | W:fun.js:143-160, W:app.js:916 | D:play:86-100 | OK | Handled by the frame. |
| funhunt | hunt | Tilt | n/a | n/a | OMITTED-OK | Not used in the web. |
| funhunt | hunt | Test hooks (window.__hunt, _bot===2 radius, _pickDelay, _shop) | W:298-302, 536, 540-553 | D:122-127, 489-494, 1237-1269 | OMITTED-OK | Test-only. Dart's bot always uses the .2 avoidance radius. |
| funhunt | hunt | Pause on tab hidden (visibilitychange) | W:funcore.js:113-123 | D:hubcore FunCanvas (no lifecycle observer) | OMITTED-OK | Flutter stops frames in the background and dt is clamped to .05, so the effect is the same. |
| funhunt | hunt | Game instance stability across widget rebuilds | W:138-148 (one closure per level) | D:170-173 (`HuntGame(...)` built inside `build()`), D:hubcore:392 (`g => widget.game`, no didUpdateWidget) | PARTIAL | Flutter-only bug. When FunPlayScreen rebuilds (it depends on `MediaQuery.paddingOf` and `i18nProvider`, D:play:176-180, e.g. on rotation or a safe-area change), HuntRun.build passes a NEW uninitialised HuntGame to FunCanvas. `_tick` then returns at `!g.inited` (load() only ran in initState). The level freezes and its state is lost. |
| funhero | hero | POWERS (7: basic, fire, triple, ice, thunder, tornado, quake) | W:funhero.js:11-20 | D:funhero.dart:28-38 | OK | |
| funhero | hero | UPS (hp/armor/rate/super/dash/jump3/pound; max; cost fns) | W:22-30 | D:48-56 | OK | |
| funhero | hero | UNLOCK 200, lvCost 100+60(n-1), ROCKET 60, STOCK_MAX 3 | W:31 | D:57-58 | OK | |
| funhero | hero | norm(carry): own (basic≥1), power fallback, up clamps, fly/shield/charge | W:35-44 | D:61-114 | OK | Reproduces JS `+v` semantics. |
| funhero | hero | Armory UI: pick power, unlock (auto-select)/level up, upgrades, rocket stock; save each buy; MAX | W:59-89 | D:143-358, 457 | OK | Flutter overlay via `g.overlay`; the game loop doesn't run while it is open. |
| funhero | hero | Armory only before 1st level of ticket (opts.heroArmory) | W:98-99, W:fun.js:146-160 | D:123-141, 456, 756 | PARTIAL | Heuristic: armory is skipped if the last run was a WIN at `lv-1` that ended <8s ago. Wrong case: a ticket ends after a win (3rd win, or the top level) and the kid starts a new ticket within 8s (fast "play again"). The armory is skipped on that new ticket's first level, but the web shows it. |
| funhero | hero | Super charge carried between levels (rounded .01) | W:95-97 | D:86-95, 452-454 | OK | |
| funhero | hero | Gear power gp & foe/boss hp scaling hpM | W:115-116, 191 | D:481-482, 685 | OK | |
| funhero | hero | maxLives=5+up.hp, cdM, maxJ (jump3), sup | W:117 | D:483 | OK | |
| funhero | hero | Touch: left half jump (hold = fly up), right half shoot; super/dash/swap/rocket/shield button hit-tests and radii | W:119-122, 165-177 | D:489-492, 668-683 | OK | |
| funhero | hero | Keyboard | none in web | none | OMITTED-OK | The web has no keys for hero. |
| funhero | hero | Jump physics (double/triple, .85 second), ground pound (vy 2400, ring, 3 dmg in S*.5) | W:125-130, 218-229 | D:496-513, 778-804 | OK | |
| funhero | hero | Dash (.35s, cd 1.2, invulnerable, kills on contact, return to HX) | W:131, 231-232, 313 | D:515-521, 806-812, 1002-1005 | OK | |
| funhero | hero | Swap power cycles owned | W:132 | D:523-530 | OK | |
| funhero | hero | Basic blast (n=[1,2,2,3,3], size, dmg table, cd .28) | W:144 | D:588-593 | OK | |
| funhero | hero | Fire (pierce 2+L, cd .38, breaks rocks) | W:145, 295 | D:594-597, 958-961 | OK | |
| funhero | hero | Triple (n=[3,3,5,5,7], spread) | W:146 | D:598-603 | OK | |
| funhero | hero | Ice (freeze 1.5+.5L, splash at L≥4) | W:147, 296 | D:604-607, 966-973 | OK | |
| funhero | hero | Thunder (nearest n foes, boss fallback, bolt cap 12) | W:148-157 | D:608-628 | OK | |
| funhero | hero | Tornado (sweep, pull, boss dps) | W:158, 280, 285 | D:629-632, 924-937 | OK | |
| funhero | hero | Quake (ground sweep, one boss hit ×1.5) | W:159, 286 | D:633-639, 938-943 | OK | |
| funhero | hero | Super beam (charge 1, duration 1.6+.4sup, width, boss dps 7+3sup) | W:162, 237-242 | D:643-650, 826-846 | OK | |
| funhero | hero | Use rocket stock (8s flight) / shield stock (10s) | W:163-164 | D:652-666 | OK | |
| funhero | hero | Drop table (coin + 9% power, 3% rocket, 2.5% shield, 2% heart, 2% magnet) | W:179-187 | D:532-546 | OK | |
| funhero | hero | kill(): pts, charge +.12(1+.15sup), drop | W:190 | D:549-559 | OK | |
| funhero | hero | Foe types: Alien/Ghost(float)/Bat(sine, 3pt)/Goblin(+hp, 4pt)/Spider(drop, 3pt); early pool t<20; speed ramp | W:192-200, 304-311 | D:686-698, 989-999 | OK | |
| funhero | hero | Spawn schedule (58% foe, 20% rock/saw, 22% coin arc; until t<55) | W:243-251 | D:848-863 | OK | |
| funhero | hero | Scroll speed (230+1.5t)×ramp(1,1.35); 0 during boss | W:208-209 | D:762-763 | OK | |
| funhero | hero | Boss: Ogre(bslime)/Dragon by (lv/10)%2, spawns at t≥55 with no foes, hp ramp(40,115)×(1+gp) | W:93, 252 | D:450, 864-869 | OK | |
| funhero | hero | Boss attacks: lobbed fireballs (rage 2), stomp ground waves (jump over), rage timers | W:254-261 | D:871-893 | OK | |
| funhero | hero | Boss death: +40 score, +20 coins, save, win | W:262 | D:894-907 | OK | |
| funhero | hero | hurt(): dash/inv immune → shield → armor (GIÁP!) → lives; lose at 0 | W:264-270 | D:700-724 | OK | |
| funhero | hero | Shot collisions (pierce sets, rock handling, boss hit) | W:271-301 | D:909-984 | OK | |
| funhero | hero | Foe contact (non-rock removed on hit) | W:302-316 | D:985-1012 | OK | |
| funhero | hero | Coins + magnet | W:317-322 | D:1013-1032 | OK | |
| funhero | hero | Item pickups (power unlock/level-up/+15 coins at max; rocket/shield active or +stock; magnet; heart) | W:323-340 | D:1033-1083 | OK | |
| funhero | hero | Hazards: fireballs, ground waves (only when low) | W:341-342 | D:1084-1111 | OK | |
| funhero | hero | End: wait 2s, G.power=me.power, return carry=out() (win and lose) | W:207 | D:750-760 | OK | |
| funhero | hero | Carry save points (armory buys, power pickups, extra stock, boss death; final carry) | W:96, 334, 336-337, 262 | D:454, 1057, 1062, 1071, 906, 757 | OK | |
| funhero | hero | Carry passed between levels of one ticket in parent-free mode | W:96 (`opts.carry = c`), W:fun.js:152 | D:play:75, D:games:123-126 | PARTIAL | Same frame issue as hunt. In free mode, coins, unlocked powers and stock from level k are lost on level k+1. |
| funhero | hero | HUD: coins/score, timer 55-t, boss bar, hearts up to 8 (2nd row narrow) | W:480-482 | D:1405-1410 | OK | |
| funhero | hero | HUD power pill + stars, armor shields, rocket fuel bar | W:483-489 | D:1411-1431 | OK | |
| funhero | hero | Owned-power strip at level start (t<3.6) | W:491-500 | D:1433-1453 | OK | |
| funhero | hero | On-screen buttons drawing (jump/🚀, 💥, dash, swap w/ stars+🔄, rocket ×n, shield ×n, super charge ring + sup stars) | W:456-478 | D:1334-1403 | OK | |
| funhero | hero | Background: sky (purple in boss), sun, clouds, backHills, parallax city, groundTiles | W:350-366 | D:1125-1150 | OK | |
| funhero | hero | Sprites: LOOK map, saw/rock, fireball, dragon/bslime/fslime boss | W:105, 372-397 | D:467, 1161-1224 | OK | Frames exist. |
| funhero | hero | Hero figure: squash on land, tilt by vy/dash, poses punch/jump/run, rocket, pound fist, shield ring | W:438-451 | D:1302-1328 | OK | |
| funhero | hero | Superhero cape (`cos.cape='#e03131'`) | W:443 | D:1309 (comment) | OMITTED-OK | Web figure.js never draws `cape` (only a comment at W:figure.js:61), so there is no visual difference. |
| funhero | hero | Screen shake, dust (emit/puff/debris/sparks), booms (incl. smoke), float text, stars | W:106, many | D:468, many; D:funkit.dart:256-330, 381 | OK | |
| funhero | hero | Level banner hint + end banner (HẾT LƯỢT!, live score) | W:501-502 | D:1454-1459 | OK | Bilingual. |
| funhero | hero | 2-player | n/a | n/a | OMITTED-OK | None in the web. |
| funhero | hero | Records / level-up / 3 levels per ticket | W:fun.js:143-160 | D:play:86-100 | OK | Handled by the frame. |
| funhero | hero | botPlay auto-player | none | D:727-735, 761 | OMITTED-OK | Dart-only test helper (g.bot). |
| funhero | hero | Pause on background / during overlay | W:funcore.js:113-123 | D:funkit.dart:782-784, 805-813 | OK | |

## Fixes for PARTIAL items

1. **Free-mode carry between levels (hunt + hero; frame).** In `lib/features/play/fun_play_screen.dart`, add `Json? _carry;`.
   - In `_onLevelDone`, set `if (r.carry != null) _carry = r.carry;` whether or not `free` is set.
   - In `_newContext()`, use `carry: _carry ?? ctx?.carry ?? store.gear(p, widget.gameId)`. Simplest version: keep the previous ctx's `carry`, which `saveGear` already updates in memory, then let `r.carry` override it.
   - This matches web `opts.carry = r.carry` (fun.js:152) and hero's `opts.carry = c` (funhero.js:96).
2. **Hunt game freezes on rebuild.** In `lib/features/fun/hub/funhunt.dart`, make the game a field of `_HuntRunState`: `late final HuntGame game = HuntGame(widget.ctx, carry: C, saved: saved, bot: widget.bot, turbo: widget.turbo);`, and use `FunCanvas(game: game, onEnd: _end)` in `build`.
   - Optionally harden `FunCanvas` in `lib/features/fun/hub/funcore.dart`: keep the first game in the state (`late final FunCanvasGame g = widget.game;`) instead of `get g => widget.game`. This protects every hub game that builds its game inside `build()`.
3. **Hero armory-once-per-ticket heuristic.** Replace `_LastRun`/8s (`funhero.dart:123-141, 756`) with the same deterministic chain logic hunt uses (`funhunt.dart:109-158`).
   - Keep a module-level `int _heroChain` and `bool _heroSkip`. At the win end (line 756), do `_heroChain++; _heroSkip = _heroChain < kLevelsPerTicket && lv + 1 < kFunMax; if (!_heroSkip) _heroChain = 0;`. On a loss, reset both.
   - In `hero()`, use `final skip = _heroSkip; _heroSkip = false; if (!skip) { _heroChain = 0; await g.overlay(...); }`.
   - Cleaner long-term option: add `int ticketStep` (0-based level index within the ticket) to `FunGameContext`, set by FunPlayScreen from `ups`, and show the armory/shop when `ticketStep == 0`. Hunt could drop its statics too.
