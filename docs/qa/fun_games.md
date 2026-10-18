> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Fun zone parity audit

Note: hunt/hero agent had not finished at hand-off; its table (if written) is part_hunt_hero.md.

<!-- part_hub.md -->
## Id list / registry (mechanical, script: fun_ids.py)

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| fun.js | (all 48) | FUN_GAMES ids + order | fun.js:162-211 | core/game/fun_games.dart:162-211 (kFunGames) | OK | 48 vs 48, same order, no id only on one side |
| fun.js | (all 48) | kind / img / vi / en / color / hot | fun.js:162-211 | fun_games.dart kFunGames | OK | field-by-field diff: 0 mismatches (hot = racer,hunt,shooter,hero,tank) |
| fun.js | (all 48) | leveled() wrapper vs custom run | fun.js:143-160 | FunGameDef.leveled | OK | non-leveled exactly sling, coding, flow, pipes, schulte in both |
| fun.js | (all 48) | `levels: true` (show "Cấp x/60" on card) | fun.js:162-211, app.js:895 | fun.dart:84 | OK | all games true in web; Dart always shows level |
| registry | (all 48) | id → module | fun.js imports 1-16 | core/game/registry.dart:69-86 + each *Games map | OK | every id resolves: sling→fun.dart:377; catch,whack,fishing,stack,breakout,flappy→funmore.dart:17; coding,flow,pipes,schulte→funlogic.dart:15; hunt→funhunt.dart:20; snake,gallery,blocks,jumper→funnew1.dart:14; runner,frogger,pong,pacman,match3→funnew2.dart:14; lanes,swim,hoops,hurdles,dance,golf→funnew3.dart:15; pizza,farm,firefight,hidden→funnew4.dart:13; trains,truckload,balloons→funnew5.dart:13; hero→funhero.dart:19; racer/shooter/tank/fighter..connect4→fun/action (other auditor). Module id strings == map keys. No extra ids. |

## Hub screen (app.js funZone / lookCard / fillGrids) → lib/features/fun/hub/fun.dart

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| app.js | hub | intro voice 'funIntro' once per session | app.js:872 | fun.dart:38-46 | OK | |
| app.js | hub | applyLook (setPlayer from mascot + p.look) on entry | app.js:870,975-979 | fun.dart:50-54 | OK | |
| app.js | hub | top bar: back→/map, title funZone, ticket pill (Admission tickets + count) | app.js:881 | fun.dart:117-129 | OK | |
| app.js | hub | 'funHow' note | app.js:882 | fun.dart:130 | OK | |
| app.js | hub | sections: Hot (rpg card + hot games), then action, vs, casual, brain (non-hot), empty groups hidden | app.js:877-879,887 | fun.dart:106-110,135-141 | OK | |
| app.js | hub | hot styling (gold inset ring on every card of first grid incl. rpg) | app.js:887, css:1480 | fun.dart:84,101,269 | OK | Dart top padding 22 vs web 26px — cosmetic |
| app.js | hub | RPG card: 'Thế giới phiêu lưu', 'Nhập vai · Cấp n', gradient #7048e8→#c2255c, → /rpg | app.js:874-876, css:1533 | fun.dart:90-104 | OK | Dart adds EN text |
| app.js | hub | game card: img, name, "Cấp x/60 · 🏆 best" | app.js:890-897 | fun.dart:78-86, 216-272 | OK | |
| app.js | hub | card tap: no ticket & not parentFun → sfx wrong + voice noTicket + toast; else tap + go /fun/id | app.js:891-894 | fun.dart:56-69 | OK | |
| app.js | hub | parent free mode button (math gate) / "on" strip with exit | app.js:884-886 | fun.dart:162-212 | OK | state in parentFunProvider (session-wide like web module var); Dart adds tap sfx |
| app.js | hub | look card: boy/girl seg, shirt swatches, hats (✖ = none), default base from mascot costume, save p.look + setPlayer | app.js:927-955 | fun.dart:275-370 | OK | |
| app.js | hub | fillGrids (last card spans remainder, wide layout) + auto-fill minmax(min(220px,42vw)) | app.js:958-971, css:1377 | fun.dart:215-248 | OK | |
| app.js | hub | card pop-in stagger animation / img hop on press | css:1212-1220,1380 | fun.dart FunGameCard | PARTIAL | cosmetic: no rise-stagger entry animation nor img hop on press (Chunky pressScale only) |

## Play frame (app.js funPlay + fun.js leveled) → lib/features/play/fun_play_screen.dart

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| app.js | frame | unknown id / fun setting off → /map | app.js:904 | fun_play_screen.dart:43-47 | OK | |
| app.js | frame | ticket use unless parentFun; none → voice noTicket, /fun | app.js:905-906 | :48-53 | OK | |
| app.js | frame | opts: hero, alive, level, content, levelUp (no-op if free), carry, saveGear (no-op if free) | app.js:913-915 | :59-79, fun_games.dart:120-129 | OK | |
| fun.js | frame | leveled loop: ≤3 levels/ticket, stop on loss or level 59, sum score, win=ups>0, lvUp, ups, pvp returns immediately | fun.js:143-160 | :82-102 | OK | equivalent stop condition |
| fun.js | frame | carry handed to next level of the same ticket (`opts.carry = r.carry` even when free) | fun.js:152 | :97, :71 | PARTIAL | Dart rebuilds context with `store.gear(p,id)`; in parent-free mode saveGear is skipped so level 2/3 lose carry from level 1. Fix: keep `Json? _carry` in state, set from r.carry, pass `carry: _carry ?? store.gear(...)` |
| fun.js | frame | opts object shared between levels of one ticket (heroArmory, tankShopDone, opts.vs, opts.car) | fun.js:157, funhero.js:99, funtank.js:144, funvs1.js:18, funracer.js:231 | fun_play_screen.dart:58-79 (new FunGameContext per level, no per-ticket bag); funhero.dart:123-140 | PARTIAL | FunGameContext has no per-ticket shared state. hero works around with a timing heuristic (skip armory if a win at level-1 finished <8 s ago) — wrong when the kid taps '▶ Cấp tiếp (🎟️ 1)' within 8 s of a 3-level ticket win (new ticket, web shows armory again). Fix (core): add `final Json ticket` (shared map, created in _start, reused in _newContext) to FunGameContext; hero uses ctx.ticket['heroArmory']. Action games (tank/vs/racer) need the same — other auditor |
| app.js | frame | result: saveBest unless free/pvp, sfx win, confetti if win/rec, voice newRecord/youWin/gameOver | app.js:917-920 | :111-122 | OK | |
| app.js | frame | result title: res.title / pos 1 '🏆 first' / '🏁 place n' / youWin / gameOver | app.js:922 | :123-124 | OK | |
| app.js | frame | coin score, "+n cấp → Cấp x/60" (not free), new record prize or best note | app.js:923-925 | :129-136 | OK | |
| app.js | frame | buttons: funZone; again/nextLv (🎟️ 1 unless free) if tickets or free, else learnMore→/map | app.js:926-931 | :137-161 | OK | |
| app.js | frame | ✕ quit button | app.js:910 | :190-199 | OK | |
| app.js | frame | game resolves null without user quit → stays (web) | app.js:916 | :85 _quit → /fun | OK | harmless difference |

## Shared helpers

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funcore.js | helpers | THEMES, theme(), themeImgs, MAX_LV=60, ramp, endText | funcore.js:122-169 | fun_games.dart:220-243, more/kit/funkit.dart:36,577, hub/funcore.dart:300 | OK | |
| funcore.js | helpers | loadAll before loop (assets ready before level timer starts) | funcore.js:14, fun.js:22 | hub/funcore.dart:337-345 (load "chạy nền; game không đợi") | PARTIAL | hub FunCanvas (sling + funmore games) starts ticking immediately; banner/timers run while images still loading (first-launch). funkit (more/*) awaits run() which loads. Fix: in hub _FunCanvasState only start ticker after `g.load()` completes |
| funcore.js | helpers | loop pauses on visibilitychange | funcore.js:104-118 | hub/funcore.dart:383-410 (none); funkit.dart:780 (explicit) | OK | Flutter stops frame callbacks while app paused; dt clamped .05 |
| funcore.js | helpers | fx(): burst/text/star; hud(); banner(); levelBanner(); goalPill() | funcore.js:44-100,140-166 | hub/funcore.dart:200-300; funkit.dart:546-575 | OK | |
| funfx.js | helpers | sheet/spr/anim/sprW/sprBox/aspect/shaker/dust/booms/stripX/tile/stripPart/PLAT_*/groundTiles/backHills/coin | funfx.js | hub/funfx.dart:32-300 | OK | easing fns live in motionb.dart/funkit |
| motionb.js | helpers | camera shake/stop/scale, fxb (burst/dust/sparks/ring/num/text/slash), shadow, drawMob, sheetsB, spr/sprA, tilePattern, prerender | motionb.js:1-158 | hub/motionb.dart:19-347 | OK | faithful port; `pixel` option of drawMob not ported (only used by rpg). NOTE: file is imported by nobody (funvs/rpg have own copies per README rule) — dead code. Web motionb has no camera/device-motion input; nothing to omit |

## Sling (fun.js) → fun.dart

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| fun.js | sling | run: up to 3 levels per ticket, levelUp per win, ups/lvUp result, last-level banner '🎯 TRÚNG HẾT!' | fun.js:128-139 | fun.dart:392-424 | OK | |
| fun.js | sling | geometry: ground .86H, anchor (.17W, ground-.24S), maxPull .2S, R .035S, G 1.9S, POWER 8.2 | fun.js:24-26 | fun.dart:470-478 | OK | |
| fun.js | sling | level ramp: nT=min(7,3+lv/6), moving lv≥3, mvSp ramp 1.2→2.6, mvAmp .05→.1, balls nT+max(1,3-lv/20) | fun.js:28,37 | fun.dart:452-462 | OK | |
| fun.js | sling | walls lv≥1, lv≥15, flying wall lv≥35 | fun.js:34-36 | fun.dart:483-485 | OK | |
| fun.js | sling | drag only near anchor (<.2S), tiny pull resets, release fires, sfx shoot | fun.js:40-58 | fun.dart:496-528 | OK | |
| fun.js | sling | physics 4 substeps, target hit +10 (boom, burst, star, +10 text), wall bounce, ground bounce, reset rules | fun.js:70-85 | fun.dart:543-590 | OK | |
| fun.js | sling | end: all hit → score+balls*3 win; out of balls → lose; 2s banner | fun.js:59-63,68 | fun.dart:530-541 | OK | |
| fun.js | sling | aim dots count max(6,34-.9lv) | fun.js:107-112 | fun.dart:636-646 | OK | |
| fun.js | sling | banners CẤP n / theme · Bắn trúng n mục tiêu; end banners | fun.js:120-121 | fun.dart:660-667 | OK | EN added |

## Arcade island (arcade.js) → hub/arcade.dart

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| arcade.js | arcade | route by level kind race/balloon, hideBuddy | arcade.js:184-188 | arcade.dart:22-28 | OK | |
| arcade.js | arcade/balloon | modes letters/numbers(0-20)/tones/english (en_animals+en_fruits images) | arcade.js:24-41 | arcade.dart:44-62 | OK | |
| arcade.js | arcade/balloon | GOAL 8, 'balloonQ' intro, prompt replay btn, target ≥1 per 4 spawns (38%), spawn every 1.15/speed, speed 1+.09*hits, size clamp(w/7,86,130), vy 55-85*speed, sway | arcade.js:18,43-101 | arcade.dart:96-180 | OK | |
| arcade.js | arcade/balloon | wrong tap: mistakes++, wrong sfx, sad, shake; stars=starsFor(max(0,mistakes-1)) | arcade.js:76-80,93 | arcade.dart:182-212 | OK | |
| arcade.js | arcade/race | raceQ add/sub/mix, facts filter, 3 choices ±1/±2 in 0..10 | arcade.js:105-112 | arcade.dart:347-364 | OK | |
| arcade.js | arcade/race | 10 steps, bot 1/(max>5?5.6:4.6) steps/s, wrong→stall .9s, boost anim, raceIntro/raceWin/raceLose, stars win?(mistakes≤2?3:2):1 | arcade.js:114-181 | arcade.dart:366-470 | OK | |
| arcade.js | arcade/race | Kenney car sprites car_red_1 / car_blue_3 + driver = buddy, fallback emoji | arcade.js:10-17,116-118 | arcade.dart:540-610 | OK | |
| fun.js | sling | release only on pointerup (no pointercancel handler) | fun.js:50-58 | hub/funcore.dart:454 (onPointerCancel → pointerUp) | PARTIAL | a cancelled touch (system gesture, palm) fires the ball and spends one. Same root cause as breakout. Fix: route onPointerCancel to a separate no-op `pointerCancel` hook (or clear `drag` without firing) |

<!-- part_funmore_funlogic.md -->
# Parity audit: funmore + funlogic (web → Flutter)

Web: `web js/games/funmore.js` (M), `funlogic.js` (L), `funcore.js` (C), `fun.js` (F).
Dart: `lib/features/fun/hub/funmore.dart` (m), `funlogic.dart` (l), `funcore.dart` (c), `lib/core/game/fun_games.dart` (g).

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funmore | (all) | Registration / leveled flag | F:169-174 `leveled(...)` | m:17-24, g (default leveled=true) | OK | ids catch/whack/fishing/stack/breakout/flappy; one level → result → frame ctx.finish (c:414-424) |
| funmore | (all) | Wait for assets before loop starts | M:21,99,180,286,367,493 `await Promise.all([sheets, loadAll])` then `loop()` | c:331-337 load() "chạy nền; game không đợi", c:394-412 ticks update once `inited` (size known) | PARTIAL | Flutter starts t/TIME and the t<2.6 intro banner while sprites/sheets still load; web's clock starts after load. Fix: in `_FunCanvasState` set `_loaded=true` in `g.load().then(...)` and `if (!_loaded) return;` before `g.update(dt)` (keep a timeout fallback, e.g. start anyway after 3 s) |
| funmore | (all) | End delay 2 s then resolve | M:36 etc `endT > 2 ? end` | m:50-54 endStep | OK | |
| funmore | (all) | dt clamp .05, pause when hidden | C:111-128 | c:398-401, Ticker | OK | Ticker stops when app not rendering |
| funmore | (all) | HUD helpers hearts/timer/goalPill/levelBanner/banner/endText | M:9-15, C:77-169 | m:26-39, c:254-304 | OK | bilingual |
| funmore | catch | Goal `need=round(15+lv*.95)`, TIME 50 | M:20,29 | m:73-74 | OK | |
| funmore | catch | Basket width ramp(.22,.17), approach 12, tilt | M:26,37-38 | m:91,107-108 | OK | |
| funmore | catch | Spawn interval, bomb prob `.16+ramp(0,.1)+t/400`, star >.96, speed ramp(1,1.6) | M:43-46 | m:116-119 | OK | |
| funmore | catch | Catch hitbox, bomb −1 life/shake/boom, star ×2 for 8 s, combo≥5 ×2, combo reset on missed fruit | M:51-56 | m:126-153 | OK | |
| funmore | catch | Win/lose: t≥50 → win=score≥need; lives 0 → lose | M:54,59 | m:140,156-159 | OK | sfx win/pop identical |
| funmore | catch | Controls: pointer down/drag (mouse only when pressed) | M:30-32 | m:95-100, c:451-452 | OK | hover passes down=false |
| funmore | catch | HUD: score, 3 hearts, timer, goal pill, "Chuỗi n 🔥", intro banner, "TRÚNG BOM RỒI!" | M:87-90 | m:200-206 | OK | |
| funmore | whack | Goal `round(15+lv*.8)`, TIME 45, grid 4x3/3x3, cw | M:98,106-110 | m:231-253 | OK | |
| funmore | whack | Spawn interval `max(.3,.9-t/70)*ramp(1,.75)`, friend prob ramp(.2,.32), Ogre 12%, life `max(.5,1.5-t/60)*ramp(1,.62)` | M:128-130 | m:305-312 | OK | |
| funmore | whack | Tap: hitbox up>.4; friend −2 (min 0) 'wrong'; Ogre +3 else +1; hitT .25 | M:111-119 | m:257-288 | OK | |
| funmore | whack | End at t≥45 win=score≥need | M:138 | m:329-332 | OK | |
| funmore | whack | Hammer swing, Collision fx, sprites | M:150-167 | m:346-381 | OK | emoji fallbacks added |
| funmore | fishing | Goal `round(12+lv*.6)`, TIME 55, sea=.3H | M:179,185,192 | m:406-407,427 | OK | |
| funmore | fishing | Fish pool by depth, jelly prob ramp(.14,.3), gem 5% (+10), shoe 5% (0), size/speed/depth formulas | M:197-203 | m:448-461 | OK | |
| funmore | fishing | Tap → boat moves (approach 4) → hook down 420/s → catch/jelly sting → up 220/340 → score | M:193-235 | m:441-546 | OK | |
| funmore | fishing | End only when t≥55 and hook idle | M:236 | m:544-547 | OK | |
| funmore | fishing | Hero sitting on boat (drawFigure heroOf) | M:272 | m:622 | OK | |
| funmore | stack | Goal `min(40,8+floor(lv*.55))`, lives 2, block speed `min(ramp(520,680), ramp(210,330)+len*14)` | M:285,294-295 | m:650-654,681 | OK | |
| funmore | stack | Tap: miss (<8px overlap) → −life, "Thử lại!"; perfect (<6px) +2, every 3rd perfect widens +20; trimmed piece falls; +1 per floor | M:297-316 | m:686-732 | OK | |
| funmore | stack | Win: floors≥need → score+20; lose on lives 0 (win=floors≥need) | M:304,326 | m:699,757-760 | OK | |
| funmore | stack | Camera, sky darkens with height, HUD 🏢 n/need, hearts, banners | M:322-359 | m:745-822 | PARTIAL | cosmetic only: Dart hides the swinging block + dashed guide once `end!=null` (m:801); web keeps drawing it under the banner (M:349). Fix: drop `&& end == null` |
| funmore | breakout | screens = lv<10?1:2; 8 patterns; pattern pick; rows `3+min(5,floor(lv/8))(+2 stripe)`; hard rows lv/12, hp 3 at lv≥30 row0 | M:366,376-393 | m:853-905 | OK | |
| funmore | breakout | Paddle width ramp(.26,.19), launch on pointer-up, speed `S*.75*ramp(1,1.45)` | M:372,396-399 | m:884,912-928 | PARTIAL | minor: Dart also launches on pointer *cancel* (c:454 routes onPointerCancel→pointerUp); web has no pointercancel handler. Fix: give FunCanvasGame a separate `pointerCancel` (default no-op) or ignore cancel in Breakout |
| funmore | breakout | Physics: 3 substeps, walls, top at 70, paddle angle `off*.8`, speed ×1.01, brick bounce/hp, fire passes through | M:411-434 | m:962-1016 | OK | |
| funmore | breakout | Power-ups 15%: multi(x2 weight)/big 12 s ×1.6/fire 8 s/heart (max 3) | M:427,436-446 | m:1004,1027-1054 | OK | |
| funmore | breakout | Lives 3, lose → "HẾT BÓNG!"; clear screen +10, next screen or win | M:435,447-450,485 | m:1017-1067,1121 | OK | |
| funmore | breakout | HUD "Cấp n · Màn a/b", launch hint, intro banner until launched | M:481-484 | m:1115-1120 | OK | |
| funmore | flappy | need `10+floor(lv/2)`, wobble lv≥15, gap formula, flap −1.15S, gravity 3S | M:492,500-501,508 | m:1138-1153,1178-1187,1213 | OK | |
| funmore | flappy | Speed `S*.38*ramp(1,1.45)+passed*2`, spawn `1.7*ramp(1,.85)`, moving gaps prob ramp(.2,.6) amp ≤.12S, coin per gap +2 | M:509-517,527 | m:1216-1226,1250-1264 | OK | |
| funmore | flappy | Pass +1, hurt (inv 1.5 s), ground bounce hurts, ceiling clamp, 3 lives | M:519-533 | m:1227-1273,1189-1198 | OK | Dart breaks pipe loop after death (harmless) |
| funmore | flappy | Win passed≥need → score+10; lose "HẾT LƯỢT!"; idle hover before first tap | M:507,530,571 | m:1207-1212,1274-1277,1330 | OK | |
| funmore | (all) | Keyboard/tilt/2-player/records | none in web | none | OK | records/level-up by frame (F:144-160 ↔ FunPlayScreen) |
| funlogic | (all) | Registration non-leveled; intro voice keys codingQ/flowQ/pipesQ/schulteQ; puzzles 3/3/3/2 | L:354-357 | l:15-20, g:184-187 leveled:false | OK | |
| funlogic | (all) | sessions(): lv=min(MAX-1, level+i); progress dots; "Cấp n"; per puzzle score+=r, sfx power, levelUp(), "⭐ Lên cấp n+2!/Cấp cao nhất!" 1300 ms; return {win,score,lvUp:true,ups:n} | L:26-47 | l:54-145 | OK | title from FunGameDef (same text, localized) |
| funlogic | (all) | Abort when !alive → null | L:31,36 | l:69,77 (frame ✕ calls finish(null)) | OK | |
| funlogic | coding | codingLevel: n by lv, len `min(24, lv<9?4+lv:13+floor((lv-9)/4))`, spare 3/2/1, rocks 30%, coins 2/3, max=len+spare | L:50-69 | l:181-217 | OK | |
| funlogic | coding | Generator retries 200 (web returns undefined → crash if all fail) | L:52 | l:184 (400) + fallback l:211 | OMITTED-OK | robustness improvement |
| funlogic | coding | Arrow pad (cap max, blocked while busy), slot tap removes, ↺ clear, ▶ Run | L:87-104 | l:250-257,382-435 | OK | |
| funlogic | coding | Run: reset to start + coins, 250 ms, step 420 ms, bump → 'wrong' 600 ms stop, coin pickup, goal → score `max(3,12-tries*2)+got*2`, else 'wrong' 400 ms reset | L:106-134 | l:267-313 | OK | |
| funlogic | coding | Robot = blue BOT figure (not hero), face/run/cheer | L:84,97,131 | l:374 | OK | |
| funlogic | flow | flowLevel: n by lv, backbite n²·30, k colors (3 for n=4), segment cut ≥3 | L:142-166 | l:481-512 | OK | |
| funlogic | flow | Drag rules: start on dot clears that color, resume from own cell truncates, backtrack, cross-cut other color, block other dots, lock done colors | L:202-224 | l:561-619 | OK | |
| funlogic | flow | Score `10 + (all cells filled ? 5 : 0)` after 500 ms | L:222 | l:608-614 | OK | |
| funlogic | flow | Sounds: tap, count per cell, star per completed color; NO win sfx on solve | L:205,219,220,222 | l:569,598,602,611 | PARTIAL | Dart adds `sfx('win')` on solve (l:611) followed by sessions 'power'; web plays none. Fix: remove `widget.ctx.audio.sfx('win');` at l:611 |
| funlogic | flow | Completion fx: dots bounce 1.4 + staggered path bounce 1.1 (30 ms/cell); solved board diagonal wave bounce 1.12 | L:220,222 | l:603-605 (uniform 1.08 pulse), l:649 glow | PARTIAL | cosmetic: no dot 1.4 bounce, no stagger, no solved wave. Fix: give `_Bounce` k/delay per cell (dot k 1.4, path k 1.1 delay k*30, solved wave k 1.12 delay ((i%n)+(i~/n))*40) |
| funlogic | pipes | pipeLevel: n by lv, random walk ≤200 steps, len ≥ n+1, filler shapes, random rotation, reject pre-solved | L:233-262 | l:741-797 | PARTIAL | low: right-bias differs. Web uses random *per comparison* `(q[0]-p[0])*(rand<.6?1:0)` (L:244); Dart draws one random per step and sorts fully (l:759-760). Fix: `opts.sort((p, q) => (q[0] - p[0]) * (rng.nextDouble() < .6 ? 1 : 0));` (sort algorithms differ, so distribution only approximates) |
| funlogic | pipes | Tap rotates 90° cw, moves++, water BFS from left row sy to right row ey; solve → wet cells bounce by column 70 ms, Seedling→Sunflower, 'win', score `max(4,15-floor(moves/4))` after 900 ms | L:264-323 | l:800-875,909-932 | OK | sunflower pop has no n*70 delay (cosmetic) |
| funlogic | schulte | n by lv (3/4/5/6), countdown mode `lv≥8 && lv%3==2`, shuffled numbers, colors | L:328-336 | l:986-989 | OK | |
| funlogic | schulte | Voice: read target via calNums 'numBig' else nums100 'n100' | L:338-339,349 | l:1015-1023,1003,1050 | OK | Dart length-check vs JS truthiness: same for non-empty data |
| funlogic | schulte | Wrong tap → mistakes++, 'wrong', shake; tapping an already-found cell counts as a mistake on web | L:344, css app.css:787 (hit cell still clickable) | l:1026 `if (done \|\| hit.contains(v)) return;` | PARTIAL | Dart ignores taps on found cells (no mistake/shake). Fix: change guard to `if (done) return;` |
| funlogic | schulte | Timer 0.1 s display; score `max(5, round(N*2 - sec - mistakes*2))` after 600 ms | L:331,340,347 | l:1004-1006,1043-1046 | PARTIAL | Dart counts Timer.periodic ticks (`tenths`) rather than wall time; ticks can be dropped/delayed so sec under-reports → slightly higher score. Fix: use a `Stopwatch` started in initState; display/score from `sw.elapsedMilliseconds/1000` (keep periodic timer only for repaint) |

<!-- part_funnew45.md -->
# Feature-parity audit: funnew4 / funnew5 (web → Flutter)

Web: `web js/games/funnew4.js` (W4), `funnew5.js` (W5), helpers in `funcore.js`, `funnew3.js`, `fun.js`.
Dart: `lib/features/fun/more/funnew4.dart` (D4), `funnew5.dart` (D5), helpers in `kit/funkit.dart` (K).

None of these 7 games has a 2-player mode, keyboard controls or voice prompts (`say`) on the web, so the port has nothing to match there. Records, score totals and the 3-levels-per-ticket loop belong to the frame: web `leveled()` (fun.js:144-161), Flutter FunPlayScreen via `ctx.finish(FunResult)` (K:826). All 7 ids are registered as leveled in `kFunGames` (fun_games.dart:191-200) and `registry.dart:75-76`.

## Shared helpers

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| kit | * | ramp(lv,a,b) linear over MAX_LV=60 | funcore.js:145 | K:36 | OK | identical formula, kFunMax=60 |
| kit | * | theme(lv) = THEMES[lv/10 % n] | funcore.js:142 | fun_games.dart:230, K:74 | OK | |
| kit | * | taps(): tap if move ≤28px else swipe; onDown/onMove/onUp | funnew3.js:24-36 | K:696-718 | OK | same order (onUp then tap/swipe) and same cancel handling |
| kit | * | kidOf(hero) | funnew3.js:14 | K:583 | OK | same regex |
| kit | * | hud/time ⏱ ceil, hearts(3), goalPill, pill, banner, levelBanner "CẤP n", endText | funcore.js:77-169, funnew3.js:17-22 | K:483-580, 594-610 | OK | adds EN strings through `tr`, plus auto-fit text in banner (polish only) |
| kit | * | loop: dt clamp .05, pause when hidden, resolve on end → FunResult | funcore.js:111-131 | K:796-828 | OK | lifecycle pause stands in for visibilitychange |
| kit | * | sfx names used (pop, correct, wrong, win, flip, splash, coin, star, squeak, eat, tap, hit) | audio.js | audio_service.dart:24-25 | OK | all present |
| kit | * | sprite sheets/anims (play/items flagR..Y, fence, window, door_open, bush; critters mouse/worm/snail/bee/ladyfly; people walk/cheer/think/idle/work/hold) | sheets.js | assets/sprites/play/*.json | OK | checked in the JSON |

## funnew4

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funnew4 | pizza | need = min(8, 3+lv/10); toppings nT = min(8, 4+lv/12) | W4:19-20 | D4:65-66 | OK | |
| funnew4 | pizza | maxN=round(ramp 3→6), kinds 1/2/3 at lv<6/<25, patience ramp 40→18 s | W4:33-34 | D4:90-91 | OK | |
| funnew4 | pizza | customer order (random distinct kinds, n=1..maxN), state machine in→wait→happy/out | W4:36-41,66-76 | D4:97-101,163-195 | OK | |
| funnew4 | pizza | controls: tap tray adds topping (max 18), tap Serve, tap topping on pizza removes it; ignored before t<2 | W4:43-59 | D4:105-149 | OK | |
| funnew4 | pizza | serve check: exact counts and no extra kinds; win served≥need score served*10+lives*5; wrong −1 life; timeout −1 life; lose score served*10 | W4:48-53,70 | D4:112-134,173-179 | OK | |
| funnew4 | pizza | lives 3 (hearts), HUD score=served, goalPill y=16 | W4:35,117-118 | D4:92,290-292 | OK | |
| funnew4 | pizza | order bubble: lv<12 and n≤4 draws each item (dim when placed), else "× n"; patience bar colors | W4:89-101 | D4:218-251 | OK | |
| funnew4 | pizza | layout (2-row tray on narrow screens, Serve button placement W<640) | W4:29-32 | D4:74-89 | OK | |
| funnew4 | pizza | banners: "Làm bánh cho N khách" / hint / "TIỆM ĐÓNG CỬA!" / "x/N khách"; "Chưa đúng số!" | W4:52,119-120 | D4:131,294-299 | OK | EN added |
| funnew4 | pizza | sounds pop/flip/correct/wrong/win | W4:46,51-52,58,70 | D4:109,120,128,145,175 | OK | |
| funnew4 | pizza | bot autoplay | W4:71-74 | D4:180-188 | OK | test only |
| funnew4 | pizza | cust.sad flag | W4:70 | D4:177 | OK | never read on either side |
| funnew4 | farm | need=round(ramp 6→18), crop=CROPS[lv/3 % 7], grid cols 3/4 (lv<10), rows 2/3 (lv<20) | W4:129-135 | D4:327-335 | OK | |
| funnew4 | farm | grow ramp 4.5→6.5 s; wilt after ramp 14→8 s only from lv≥20; timer round(ramp 80→95) | W4:140,144 | D4:342,348 | OK | |
| funnew4 | farm | plot cycle 0 plant→1 water→2 grow→3 ripe→harvest (got++), 4 wilted→clear; kid walks there (speed S*.9) then works .45 s | W4:145-151,168-173 | D4:351-380,418-437 | OK | |
| funnew4 | farm | tap critter shoos it (S*.08 radius, squeak); tap plot (not while growing) → goTo | W4:152-157 | D4:382-394 | OK | |
| funnew4 | farm | pests from lv≥6: interval rand(5,8)*ramp(1.3→.55), speed S*ramp(.1→.2), eat after 1.6 s resets the plot to 0 | W4:174-189 | D4:438-475 | OK | |
| funnew4 | farm | win got≥need score got*5+round(time); time out lose score got*5 | W4:148,196 | D4:367-369,487-491 | OK | |
| funnew4 | farm | HUD score/time + goalPill; banner "Thu hoạch N bắp ngô/nông sản", "HẾT GIỜ!" | W4:220-223 | D4:537-549 | OK | EN added |
| funnew4 | farm | sounds pop/splash/coin/star/flip/squeak/eat/win/wrong | W4 | D4 | OK | |
| funnew4 | farm | bot | W4:190-195 | D4:476-486 | OK | |
| funnew4 | firefight | need=round(ramp 6→22); cols=min(5, 3+lv/20+(W>700)), rows 2/3 (lv<12) | W4:231,237 | D4:576,584 | OK | |
| funnew4 | firefight | growR ramp .1→.22, dryR .75→.55, maxBurn 9→5 s; max simultaneous fires min(n-1, 1+lv/12); spawn rand(1.6,3)*ramp(1.3→.6); first spawn at 1 s; new fire .3 | W4:242,244,258-263 | D4:591,595,623-633 | OK | |
| funnew4 | firefight | tap burning window → truck target; tap road → move truck (clamped 60..W-60) | W4:245-250 | D4:598-608 | OK | |
| funnew4 | firefight | spraying only when truck is within 4px; the target window does not grow while sprayed; burn>maxBurn → black for 4 s, −1 life | W4:265-278 | D4:641-683 | OK | |
| funnew4 | firefight | win out≥need score out*8+lives*5; lose score out*8; lives 3 | W4:273,277 | D4:660-680 | OK | |
| funnew4 | firefight | "!" warning at 60% burn, thanks cheer anim 1.8 s, water drops arc | W4:294-305 | D4:714-743 | OK | |
| funnew4 | firefight | banners "Dập N đám lửa" / "LỬA LỚN QUÁ!" / "x/N đám lửa" | W4:312-313 | D4:752-756 | OK | |
| funnew4 | firefight | bot (target the longest-burning fire) | W4:264 | D4:634-640 | OK | |
| funnew4 | hidden | nItems=round(ramp 14→46), nFind=min(6, 3+lv/15), random pool from 65 FIND names | W4:319-327 | D4:763-787 | OK | same list |
| funnew4 | hidden | size sqrt(area/n)*ramp(.72→.5); placement 40 tries, minD ramp(.95→.6); rotation ±.6 when lv≥10 else ±.15 | W4:333-345 | D4:793-813 | OK | |
| funnew4 | hidden | target items drawn first (can be covered); bushes from lv≥20, count round(ramp 3→8) | W4:347-348 | D4:815-816 | OK | stable partition equals web stable sort |
| funnew4 | hidden | tap topmost unfound item: target → found; anything else (non-target or empty) → −3 s with "-3 giây" | W4:350-356 | D4:820-839 | OK | |
| funnew4 | hidden | hint: targets wiggle after 14 s idle | W4:364 | D4:856-858 | OK | |
| funnew4 | hidden | timer round(ramp 75→60); win score gotN*10+round(time); time out score gotN*10 | W4:349,354,366 | D4:817,831,864-868 | OK | |
| funnew4 | hidden | tray with ✔, kid think/cheer, banners "Tìm N món đồ…" / "HẾT GIỜ!" / "x/N món" | W4:376-389 | D4:887-913 | OK | |
| funnew4 | hidden | `miss` counter | W4:349,355 | — | OMITTED-OK | written on web but never read, so it has no effect |
| funnew4 | hidden | bot | W4:365 | D4:859-863 | OK | |

## funnew5

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funnew5 | trains | need=round(ramp 6→20); stations nSt 2/3/4 (lv<10, <30) | W5:12-13 | D5:47-48 | OK | |
| funnew5 | trains | junction tree shapes per nSt (x .42 / .32+.58 / .3+.58×2), fixY, seg path (flat-diagonal-flat) | W5:21-32 | D5:54-88 | OK | |
| funnew5 | trains | colors: shuffle 4 flag colors, take nSt; train color random 0..nSt-1 | W5:33,38 | D5:90,97 | OK | |
| funnew5 | trains | speed S*ramp(.2→.36), spawn every ramp(5.5→2.4)*rand(.9,1.15), first at 1.2 s | W5:34,36,61 | D5:91,94,173-176 | OK | |
| funnew5 | trains | tap within S*.09 of a junction toggles it (flip sfx) | W5:39-43 | D5:98-107 | OK | |
| funnew5 | trains | arrive: right station done++ (score done*8+lives*5 on win), wrong "Sai ga!" −1 life, lose score done*8; lives 3 | W5:44-54 | D5:108-133 | OK | |
| funnew5 | trains | movement along path with leftover distance carried over; fade out over 1.2 s | W5:62-72 | D5:177-200 | OK | |
| funnew5 | trains | rails, stations (house + flag), junction arrow, locomotive and flag | W5:85-113 | D5:135-270 | OK | |
| funnew5 | trains | banners "Đưa N tàu về đúng ga" / "TÀU ĐI LẠC RỒI!" / "x/N tàu" | W5:120-121 | D5:279-284 | OK | |
| funnew5 | trains | bot | W5:73-77 | D5:201-209 | OK | |
| funnew5 | truckload | cols=min(7, 3+lv/12), rows 2/3/4 (lv<8, <30), maxSz 2/3/4 (lv<5, <25), needTrucks 2/3 (lv<10) | W5:150-151 | D5:343-344 | OK | |
| funnew5 | truckload | partition: random connected pieces that always tile the grid | W5:130-147 | D5:305-332 | OK | |
| funnew5 | truckload | timer round(ramp(75→100)*needTrucks/2); runs only while playing (not during the truck arriving/leaving animation) | W5:161,201-207 | D5:358,473-491 | OK | |
| funnew5 | truckload | drag from tray (onDown/onMove/onUp), snap with round(), fits check, wrong sfx; input blocked while leaving/arriving | W5:184-193 | D5:420-447 | OK | |
| funnew5 | truckload | full grid → trucks++, leave anim 1.3 s, then new load (arrive) or win score trucks*20+round(time); time out score trucks*20 | W5:179-182,202-209 | D5:392-406,477-501 | OK | |
| funnew5 | truckload | drop preview (green/red), tray layout wraps rows, kid anim | W5:163-171,229-238 | D5:360-376,553-570 | OK | |
| funnew5 | truckload | banners "Xếp kín N xe tải" / "HẾT GIỜ!" / "x/N xe" | W5:242-243 | D5:575-579 | OK | |
| funnew5 | truckload | bot (place pieces at home) | W5:208 | D5:492-496 | OK | |
| funnew5 | balloons | number content: modes lv<15 count 1,2,3…; <30 by 2 (2,4,6…); <45 by 5 (5,10,…); ≥45 count down from 20 | W5:252 | D5:604-605 | OK | |
| funnew5 | balloons | sequence length: lv<15 → 5+lv/3 (capped at 10), else 10; seq formula | W5:253-254 | D5:606-607 | OK | countdown 20→11 on both |
| funnew5 | balloons | pool(): the needed number always present; else 70% a later seq number, otherwise want±{1,-1,3}*max(1,abs(d)) | W5:264-268 | D5:618-625 | OK | |
| funnew5 | balloons | size S*ramp(.15→.11), rise speed S*ramp(.1→.2)*rand(.85,1.2), max on screen round(ramp 4→7), spawn rand(.6,1.1), first 3 start at H*.75/.55/.35 | W5:259,263,269,286-288 | D5:611,617,627,672-675 | OK | H0.pop() = removeLast() |
| funnew5 | balloons | tap a bug (S*.06) → −1 life "Ối!"; right balloon pops (idx++); wrong → −1 life, shake, "Tìm số N" | W5:270-279 | D5:628-658 | OK | |
| funnew5 | balloons | needed balloon escapes off the top (lv≥5, no other copy on screen) → −1 life "Bóng bay mất rồi!" | W5:294-298 | D5:687-698 | OK | |
| funnew5 | balloons | bugs (bee/ladyfly) from lv≥8, chance dt*ramp(.15→.45), max 3 | W5:300-301 | D5:701-709 | OK | |
| funnew5 | balloons | win idx≥len score idx*5+lives*5; lose score idx*5; lives 3 | W5:272-278,297 | D5:635-656,695 | OK | |
| funnew5 | balloons | HUD score=idx, hearts, pill "🎈 Tìm số N", sequence strip ?/numbers, banner by mode ("Đếm lùi từ 20", "Đếm cách d: a, b, c...", "Chạm bóng theo thứ tự 1 → n"), "HẾT TIM RỒI!" | W5:321-327 | D5:751-781 | OK | EN added |
| funnew5 | balloons | bot | W5:302 (dispatches PointerEvent) | D5:710-714 (calls onTap directly) | OK | same handler and guards; test only |
| funnew5 | balloons | balloon alpha during pop | W5:311 (a can go slightly below 0) | D5:733 (clamped max 0) | OK | only guards against a negative alpha |

<!-- part_funnew3.md -->
# Feature-parity audit: funnew3 (lanes, swim, hoops, hurdles, dance, golf)

Web: `web js/games/funnew3.js` (W:line). Flutter: `lib/features/fun/more/funnew3.dart` (D:line), kit `lib/features/fun/more/kit/funkit.dart` (K:line).
Method: line-by-line comparison of formulas, constants, branches, HUD strings, sfx names and sprite frame names. I also checked that every sprite frame and anim used exists in `assets/sprites/play/*.json`, and that every sfx name exists in `audio_service.dart`.

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funkit.dart | (helpers) | sheets(names) -> map, 'play/' prefix | W:9-12 | K:127-130 playSheets | OK | Same mapping. A sheet that fails to load becomes null and is skipped (web would throw), which is harmless. |
| funkit.dart | (helpers) | kidOf regex (Woman/Princess/Unicorn/fairy/Cat face/Rabbit face -> kidgirl; 'Robot' -> robot; else kidboy) | W:14 | K:583-584; hero = ctx.heroImg (K:665) | OK | ctx.heroImg = `mascot(p.mascot).img` (fun_play_screen.dart:67), the same as the web `opts.hero` (app.js:912). |
| funkit.dart | (helpers) | taps(): onDown/onMove/onUp, swipe if hypot>28 else tap, cancel resets | W:24-36 | K:696-720 | OK | Flutter Listener captures the pointer implicitly, which stands in for setPointerCapture. |
| funkit.dart | (helpers) | pill(W,text,y=10,w=190) | W:19-22 | K:601-609 | OK | Same geometry and font size. The font family comes from the global kFontFamily. |
| funkit.dart | (helpers) | hearts(n,max=3) at W-40-i*36, alpha .22 | W:17 | K:594-598 | OK | |
| funkit.dart | (helpers) | shadow(), skyFill() | W:16,38 | K:586-592,612-617 | OK | |
| funkit.dart | (helpers) | ramp/MAX_LV=60, theme/themeImgs, hud, goalPill, levelBanner, endText | funcore.js:77-175 | K:36,74-75,483-579 | OK | banner() also fits text to the width (the web version does not). levelBanner/endText add English through Tr. Both are improvements. |
| funkit.dart | (helpers) | loop: dt cap .05, pause when hidden, resolve result | funcore.js:111-129 | K:803-828 | OK | Lifecycle pause stands in for visibilitychange. Result -> ctx.finish(FunResult(score, win, pos)). |
| funkit.dart | (helpers) | canvasIn: W/H = max(320, box) | funcore.js:20-32 | K:857 | OK | |
| funkit.dart | (helpers) | sheets.js frameAt (fps default 10, loop flag) / drawFrame (anchor, ox/oy, size) | sheets.js:29-53 | sprite_sheet.dart:82-88; K:133-153 | OK | |
| funnew3.dart | lanes | goal need = round(ramp(250,1100)) m | W:43 | D:52 | OK | |
| funnew3.dart | lanes | lane geometry LY/LS/ph, me.x=.24W, G=ph*9, JV | W:48-50 | D:57-61 | OK | |
| funnew3.dart | lanes | controls: tap lane = change lane one step / tap own lane = jump; swipe vertical = lane, horizontal = jump; locked t<2 or end | W:54-60 | D:68-109 | OK | |
| funnew3.dart | lanes | speed v = S*ramp(.62,1.0)*(1+min(.2,dist/4000)); dist += v*dt/(S*.1) | W:66-67 | D:119-120 | OK | |
| funnew3.dart | lanes | spawn interval rand(.9,1.4)*ramp(1.35,.72); hard obstacles lv>=6 p=ramp(.35,.6), 2 lanes at lv>=30 p=.4 (+.55s); bee lv>=15 p=.4 else crate | W:72-78 | D:133-141 | OK | Lane shuffle uses Fisher-Yates instead of the web's biased sort(random). Behaviour is otherwise equivalent (OMITTED-OK nuance). |
| funnew3.dart | lanes | soft ground critter p=ramp(.55,.9); pool slime,snail(+ladybug lv>=8,+mouse lv>=16); 50% in player's lane when no hard | W:79-80 | D:142-145 | OK | |
| funnew3.dart | lanes | coin rows: 55% chance, 5 coins in free lane; arc z=ph*.35 lv>=10 | W:81 | D:146-151 | OK | |
| funnew3.dart | lanes | obstacle speeds (snail .9, mouse 1.15), collision (hard always; soft only if z<ph*.2), inv 1.5s, hurt .5 | W:84-91 | D:154-172 | OK | |
| funnew3.dart | lanes | lives 3; lose score round(dist/10)+coins; win score round(need/10)+coins*2+lives*5 | W:89,103 | D:168,209 | OK | |
| funnew3.dart | lanes | kid anims cheer/hurt/jump/fall/run, blink while invulnerable, lane lerp *14 | W:133-139 | D:253-259 | OK | |
| funnew3.dart | lanes | HUD: coin score, hearts, pill "🏃 m/need m" (y 62 if W<640), banners "Chạy N mét"/"VẤP NGÃ RỒI!" | W:142-145 | D:262-270 | OK | Adds English. |
| funnew3.dart | lanes | sfx jump/flip/hit/coin/win/wrong | W:55-103 | D:79-210 | OK | |
| funnew3.dart | lanes | scenery: theme sky/sun/deco parallax .25, lane bands, dashes | W:107-120 | D:215-233 | OK | |
| funnew3.dart | lanes | bot autoplay | W:98-102 | D:194-207 | OK | Test only. |
| funnew3.dart | swim | goal need = round(ramp(10,26)) gems; 4 gems on field, respawn on pickup | W:152,161-162,197 | D:311,323-326,398-413 | OK | |
| funnew3.dart | swim | control: hold+drag target, accel *5, slow near target, drag decay .2^dt; bounds y>=fs/2+60; speed SP=S*ramp(.75,.95) | W:171-192 | D:338-395 | OK | |
| funnew3.dart | swim | foes: fishP count min(4,1+lv/12); eel lv>=8 (vx ramp .3-.55, wait); puffer lv>=15 (size pulse 1.35); big red lv>=25 (chase 3s / retreat 3s, k ramp .3-.45) | W:163-167,199-210 | D:327-333,414-447 | OK | |
| funnew3.dart | swim | collision radii (eel box), lives 3, inv 2s, big fish reset cd=3 on hit | W:211-215 | D:448-467 | OK | |
| funnew3.dart | swim | score win got*5+lives*5; lose got*5 | W:197,214 | D:409,461 | OK | |
| funnew3.dart | swim | anims: fishY anim speed by velocity, flip by facing, tilt by vy; blink | W:235-236 | D:519-523 | OK | |
| funnew3.dart | swim | scenery: gradient, light rays, friends, sand, swaying weeds, rocks, bubbles | W:219-228 | D:471-503 | OK | |
| funnew3.dart | swim | HUD: score, hearts, goalPill y16, banners "Nhặt N viên ngọc"/"HẾT LƯỢT BƠI!" | W:238-241 | D:525-532 | OK | Adds English. |
| funnew3.dart | swim | kid sprite | n/a | n/a | OMITTED-OK | The web uses the fish 'fishY', not kidOf. Flutter matches. |
| funnew3.dart | hoops | need = min(12, 3+floor(lv/7)); timer round(ramp(70,55)) s | W:248,257 | D:551,561 | OK | |
| funnew3.dart | hoops | rim radius ramp(.085,.062); hoop moves Y lv>=8 ramp(.05,.14), X lv>=28 ramp(.03,.12), speed ramp(.8,1.6) | W:254-261 | D:557-576 | OK | |
| funnew3.dart | hoops | control: drag from anywhere, swipe up (dy<=0, len>=25) -> v = d*4.2 capped S*3.2 | W:264-275 | D:588-619 | OK | |
| funnew3.dart | hoops | physics: G=S*2.4, 3 substeps, rim bounce 1.6, backboard bounce .55, floor bounce .5/.7, score when crossing rim downward within rr-br*.4, ball reset 3.2s/1.5s/offscreen | W:287-306 | D:641-693 | OK | |
| funnew3.dart | hoops | aim dots count round(max(5,26-lv*.35)) | W:332-340 | D:752-770 | OK | |
| funnew3.dart | hoops | win score*10+round(time); timeout score*10 'HẾT GIỜ!' | W:300,307 | D:677,694-698 | OK | |
| funnew3.dart | hoops | kid anims cheer/throw/hold/idle (kidOf) | W:330-331 | D:750-751 | OK | |
| funnew3.dart | hoops | shots counter | W:257,263 | — | OMITTED-OK | The web increments `shots` but never reads it. |
| funnew3.dart | hoops | HUD: score, timer, goalPill, banners | W:346-349 | D:782-788 | OK | |
| funnew3.dart | hoops | sfx shoot/pop/coin/win/wrong, net sway | W:263-307,323-327 | D:585-697,730-747 | OK | |
| funnew3.dart | hurdles | race length L=round(ramp(50,130)), gap max(7,ramp(12,8))*rand(.85,1.15), hurdles from 10 to L-4 | W:363-365 | D:813-818 | OK | |
| funnew3.dart | hurdles | place needed: <15 top3, <35 top2, else 1st | W:364 | D:814 | OK | |
| funnew3.dart | hurdles | racers: kid (kidOf) + 3 of [kidgirl,kidboy,robot,woman,man] minus kid; lanes [3,0,1,2]; AI skill ramp(.86,1.02)*rand(.96,1.04), miss ramp(.3,.06) | W:358,368-369 | D:808,823-826 | OK | |
| funnew3.dart | hurdles | speed base 6.2, trip -> .3, boost +25% (jump within 1.6 of hurdle, "Tuyệt!"), player factor ramp(1.02,1) | W:372-373,382 | D:832-843,868 | OK | |
| funnew3.dart | hurdles | jump vz 9.5 G 34; trip when |h-x|<.35 & z<.45 -> trip .8, v*=.4 | W:385-391 | D:873-904 | OK | |
| funnew3.dart | hurdles | controls: tap or swipe = jump (t>=2.5) | W:374 | D:845-849 | OK | |
| funnew3.dart | hurdles | finish: place<=placeNeed win; score max(0,50-place*10)+round(ramp(10,40)); pos returned | W:392 | D:905-914 | OK | pos goes into FunResult.pos (K:826). |
| funnew3.dart | hurdles | post-finish runout 2.5s | W:378 | D:855-861 | OK | |
| funnew3.dart | hurdles | anims cheer(1st)/idle/hurt/jump/fall/run, anim rate by speed, yellow marker arrow | W:414-416 | D:961-979 | OK | |
| funnew3.dart | hurdles | HUD: meters, progress bar with mini racers + flag, pill "🏁 Hạng X · cần ...", banners | W:421-430 | D:984-1004 | OK | Adds English. |
| funnew3.dart | hurdles | scenery: parallax deco, track lanes, meter marks, chequered finish | W:398-410 | D:919-956 | OK | |
| funnew3.dart | dance | 3 songs (identical note arrays), song = lv%3 | W:436-440,448 | D:1010-1014,1030 | OK | |
| funnew3.dart | dance | columns nc = lv<20 ? 3 : 4; beat ramp(.62,.34); hit window ramp(.24,.13); fall time ramp(2.2,1.3); note at 2.6+i*beat | W:442,448,451 | D:1024,1030,1033 | OK | |
| funnew3.dart | dance | double notes lv>=40 every 6th from i=4 (pitch+2, col+1) | W:452 | D:1034-1038 | OK | The web `dbl:true` flag is never read. |
| funnew3.dart | dance | allowed misses round(ramp(10,4)); lose if miss>allowed (score hits*5); win when all resolved (hits*5+best*2) | W:453,473-475 | D:1039,1091-1106 | OK | |
| funnew3.dart | dance | press: nearest note in column within window; "Tuyệt!" if <40% window; empty press resets combo | W:457-466 | D:1047-1067 | OK | |
| funnew3.dart | dance | music: note(pitch,.5) per hit (NOTES table, 8 pitches) | W:462 | D:1058; soloud_audio.dart:173 | OK | Pitch indexes 0..7 stay in range. |
| funnew3.dart | dance | control: pointer-down column (multi-touch for doubles) | W:467 | D:1069-1073 | OK | |
| funnew3.dart | dance | poses: 8 POSES cycling on hits, hurt on miss, idle bob on beat, cheer on win; crew robot at combo>=5, other kid at combo>=10 | W:443,456,485-490 | D:1025,1046,1133-1142 | OK | All pose frames exist in kid/robot sheets. |
| funnew3.dart | dance | HUD: hits, heart row min(allowed,12), combo pill >=3, banners "Chạm đúng N nốt nhạc"/"LỠ NHỊP RỒI!" | W:505-509 | D:1161-1171 | OK | |
| funnew3.dart | dance | stage: gradient, 3 swinging spotlights, pads flash | W:480-503 | D:1111-1159 | OK | |
| funnew3.dart | golf | arena A (top 112/70, margin 16), portrait vs landscape start/hole placement | W:521-525 | D:1205-1211 | OK | |
| funnew3.dart | golf | walls nW=min(4,floor(lv/12)+(lv>=2)), length ramp(.45,.62), alternating gap | W:527-533 | D:1213-1228 | OK | |
| funnew3.dart | golf | sand lv>=20 count min(3,1+(lv-20)/15), friction 2.2 vs 1.05 | W:534,567-568 | D:1229-1231,1326-1329 | OK | |
| funnew3.dart | golf | moving bugs lv>=10 count min(3,1+(lv-10)/16), speed ramp(.12,.3), bounce 2x, squeak | W:535,575 | D:1232-1235,1354-1366 | OK | Flutter adds a `dd>0` guard against divide-by-zero NaN (safe). |
| funnew3.dart | golf | par=1+nW; allowed=par+round(ramp(5,3)) | W:536 | D:1236 | OK | |
| funnew3.dart | golf | control: slingshot pull from anywhere (min 14px, maxPull S*.26, POW 7.5), only when ball stopped | W:538-555 | D:1241-1286 | OK | |
| funnew3.dart | golf | physics: 4 substeps, stop <18, border bounce .8, wall bounce 1.8, sink dh<hr*.8 & sp<S*1.6, hole suction | W:564-579 | D:1322-1381 | OK | |
| funnew3.dart | golf | win after sink .7s score max(5,(allowed-strokes+1)*10); lose when strokes>=allowed & stopped (score 0) | W:562,580 | D:1301-1308,1382-1385 | OK | |
| funnew3.dart | golf | kid anims hold/throw/hurt/cheer, flagR anim, aim dots len round(max(3,12-lv*.15)) | W:595-606 | D:1418-1446 | OK | |
| funnew3.dart | golf | HUD: strokes, pill "⛳ Gậy s/allowed", banners | W:609-612 | D:1459-1465 | OK | Adds English. |
| funnew3.dart | all 6 | 2-player / pvp mode | none | none | OMITTED-OK | The web has no pvp for these games. |
| funnew3.dart | all 6 | keyboard / tilt controls | none (no keydown/deviceorientation in funnew3.js) | none | OMITTED-OK | Pointer only on both sides. |
| funnew3.dart | all 6 | power-ups | none (hurdles near-jump boost only) | D:838-841 | OK | |
| funnew3.dart | all 6 | records / level loop (one level -> finish) | fun.js:200-209 leveled() | fun_games.dart:188-197 (leveled=true default), registry.dart:74 | OK | Records and 3 levels per ticket are handled by FunPlayScreen. |

<!-- part_funnew12.md -->
# Audit: funnew1.js / funnew2.js vs funnew1.dart / funnew2.dart

Web files: `web js/games/funnew1.js` (W1) and `web js/games/funnew2.js` (W2). Dart files: `lib/features/fun/more/funnew1.dart` (D1), `lib/features/fun/more/funnew2.dart` (D2) and `lib/features/fun/more/kit/funkit.dart` (K).
Tank is out of scope (it is re-exported from funtank at W1:287).

**How this was checked:** each formula was compared line by line. None of these 9 games has keyboard input, tilt, a 2-player mode or a records mode in the web version. Records and the 3-levels-per-ticket loop are handled by the frame, through `leveled` at web fun.js:144 and FunPlayScreen in Dart. All 9 games are registered in `lib/core/game/registry.dart:72-73` and `kFunGames` (`fun_games.dart:164-173`) with leveled=true.

| file | game id | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|---|
| funnew1 | (helper) | dirInput: swipe ≥24px gives the swipe direction; a tap gives the direction from the character to the tap; dominant axis | W1:11-22 | K:722-737 | OK | Same 24px threshold and axis rule. Like the web version, it does not handle pointercancel. |
| funnew1 | snake | Goal need=round(ramp(lv,25,110)) | W1:29 | D1:64 | OK | |
| funnew1 | snake | Field WW=2.2·max, WH=1.8·max; 160 starting foods, refilled to 140; 12% big fruit (v=4) or dots (v=1) | W1:34-38,103 | D1:69-80,246-248 | OK | |
| funnew1 | snake | Speed SP=S·ramp(.3,.38), TURN 4.2, bot speed ×ramp(.75,1), boost ×1.7, radius grows R0·(1+min(.8,len/160)) | W1:35,56-65 | D1:70-71,149-164 | OK | |
| funnew1 | snake | Controls: drag to steer (mouse only while a button is held); double-tap within <300ms gives a 1.6s boost plus the 'power' sound | W1:50-52 | D1:109-121 | OK | Dart measures the double-tap on game time (g.clock) instead of performance.now(). The behaviour is the same. |
| funnew1 | snake | Bots: count round(ramp(2,8)); length rand(10,10+.6lv); spawn ≥.8S from the player; respawn 2.5s after death | W1:46-48,121 | D1:91-104,285-290 | OK | setTimeout became g.after, which runs on game time. |
| funnew1 | snake | Bot AI: thinks every .3-.8s; at lv≥15, chases a point ahead of the player with probability ramp(0,.35) when within S; otherwise heads for the nearest food ±.3; turns back at the wall margin of 80 | W1:79-90 | D1:202-225 | OK | |
| funnew1 | snake | Eating: len+=v, score+=v (player only), gulp .25, sounds coin/count, '+v' text | W1:92-102 | D1:227-245 | OK | |
| funnew1 | snake | Collision: a head touching another body (segment i>1, r·.7+o.r·.8) costs the player 1 life (3 lives); player respawns at len·.6 (min 14) with 2s invulnerability; a bot that hits dies, turns into food v=2, and shows 'GIỎI QUÁ!' when it hit the player | W1:105-120,66-70 | D1:250-284,166-178 | OK | |
| funnew1 | snake | Wall: clamp and reverse; at lv≥20 hitting the wall costs a life (when not invulnerable), otherwise plays 'pop' | W1:123-126 | D1:292-308 | OK | |
| funnew1 | snake | End: win when score≥need, scoring score+lives·5; lose scores score; 2s end delay | W1:74,114,128 | D1:186-189,271,311-314 | OK | |
| funnew1 | snake | HUD: score, 3 hearts, goalPill y=16, level banner and end banner text | W1:182-186 | D1:472-481 | OK | Dart adds English versions of the text through tr. |
| funnew1 | snake | Visuals: camera lerp ×5, hex dot pattern, dashed red border, tube body, eyes, tongue, gulp, blink while invulnerable, shake | W1:127,131-180 | D1:309-310,317-470 | OK | |
| funnew1 | gallery | need=round(14+.9lv), TIME=40s | W1:193 | D1:500-501 | OK | |
| funnew1 | gallery | Spawn: interval rand(.45,.9)·ramp(1.1,.6); 3 lanes with alternating direction; speed ramp(120,300)·rand(.8,1.3) | W1:205,226-233 | D1:522,582-589 | OK | |
| funnew1 | gallery | Target mix: friend if r<ramp(.12,.25), 'Alarm clock' if r>.97, otherwise a bad target; Bullseye size ramp(.14,.1)·S, others .13S; vertical wobble at lv≥15 with 50% chance | W1:230-232,237 | D1:586-588,599 | OK | |
| funnew1 | gallery | Shooting: tap; hit radius .55·s; 12 bullet holes; crosshair pulse; shake 2.5 | W1:206-212 | D1:523-539,563 | OK | |
| funnew1 | gallery | Scoring: hitting a friend costs 3 (minimum 0) and resets the combo ('Ối! Bạn mà!'); the clock adds 5s; Bullseye 3, Bat 2, others 1, +1 when combo≥5 | W1:213-217 | D1:541-560 | OK | |
| funnew1 | gallery | End: when t-2 ≥ TIME+bonusT, win if score≥need; sounds win/pop | W1:240 | D1:607-610 | OK | |
| funnew1 | gallery | HUD: score, countdown, goalPill, level banner and end banner | W1:278-281 | D1:671-677 | OK | |
| funnew1 | gallery | `booms(fxs,16)` (B) is created and updated but never drawn | W1:197,221 | — | OMITTED-OK | This is dead code on the web. Leaving it out changes nothing visible. |
| funnew1 | blocks | need=min(30,3+floor(.4lv)); 10×18 board; cell size and button layout | W1:293,299-300,319-320 | D1:710,719-721,788-789 | OK | |
| funnew1 | blocks | Piece pool: lv<6 uses I,O,T,L, otherwise all 7; junk rows at lv≥15: min(6,floor((lv-10)/8)), 80% filled with one gap | W1:302-305 | D1:723-731 | OK | |
| funnew1 | blocks | Fall step ramp(.75,.22)s; soft-drop step .03 | W1:354 | D1:888 | OK | |
| funnew1 | blocks | Controls: 4 buttons (← ⟳ → ⬇); on the board, a tap within 1.5 cells of the piece rotates, otherwise moves left/right; rotation tries kicks [0,-1,1,-2,2] | W1:316-328 | D1:760-813 | OK | The web version has no keyboard controls either. |
| funnew1 | blocks | Lock and clear: line scores [0,1,3,6,10]; texts 'N HÀNG!' and '+1 hàng'; flash and debris effects; sounds win/coin/pop | W1:329-346 | D1:814-868 | OK | |
| funnew1 | blocks | Win when lines≥need, scoring score+10; lose when spawn is blocked or a piece locks above the top ('ĐẦY RỒI!') | W1:312,333,344,388 | D1:752-755,832-835,862-866,1000 | OK | |
| funnew1 | blocks | Visuals: ghost piece, smooth fall, next-piece preview, lock pulse, button press | W1:358-389 | D1:899-1001 | OK | |
| funnew1 | jumper | need=round(ramp(60,400)) m; height=(H·.7−y)/(S·.1) | W1:395,417 | D1:1032,1069 | OK | |
| funnew1 | jumper | Physics: G=2.6S, JUMP=−1.55S; platform gap S·ramp(.16,.27)·rand(.8,1.1); width S·ramp(.28,.18) | W1:398,403-405,413,443 | D1:1039,1048-1050,1061-1064,1177-1180 | OK | |
| funnew1 | jumper | Platform kinds: 'move' at lv≥8 with p<ramp(.1,.35) (speed 60-140, bounces at the edges); 'break' at lv≥20 with p>1−ramp(0,.18) (breaks into 2 falling pieces) | W1:406-407,433,437 | D1:1051-1052,1115-1121,1135-1140 | OK | |
| funnew1 | jumper | Pickups: coin 30%; rocket 1.5% (2.5s at vy=JUMP·1.4) | W1:408,410,427,438 | D1:1053,1055,1102-1105,1141-1155 | OK | |
| funnew1 | jumper | Foes at lv≥12 with p=ramp(.03,.12) (Bat/Ghost): stomp when falling, otherwise lose; immune while on the rocket | W1:409,439 | D1:1054,1156-1173 | OK | |
| funnew1 | jumper | Controls: drag/tap sets target x, lerp ×8 | W1:414-416,423 | D1:1065-1068,1088 | OK | |
| funnew1 | jumper | End: falling below the camera loses (best+coinN); best≥need wins (best+coinN·2) | W1:439,446-447 | D1:1168,1185-1192 | OK | Dart adds `end==null` guards. On the web, a loss set earlier in the same frame can be overwritten by a later check, e.g. a foe hit followed by best≥need becomes a win. This only matters within a single frame. |
| funnew1 | jumper | HUD: coin count, '⬆ best/need m' pill, banners ('RƠI MẤT RỒI!'); sky darkens when progress k>.6; parallax clouds; squash and stretch | W1:450-486 | D1:1195-1276 | OK | |
| funnew2 | runner | need=round(ramp(150,900)); speed S·ramp(.55,1.05)·(1+min(.3,dist/3000)); distance unit S·.1 | W2:16,32-33 | D2:52,100,111-112 | OK | |
| funnew2 | runner | Tap to jump; double jump (heights .3S then .22S); G=4.2S | W2:20,26,34-35 | D2:60,73-86,113-124 | OK | |
| funnew2 | runner | Spawn: interval rand(.9,1.6)·ramp(1.25,.7); flyers (Bird/Bat) at lv≥6 with p=ramp(.1,.35); double obstacle at lv≥25 with 30%; 4-coin arc with 50% | W2:38-44 | D2:131-147 | OK | |
| funnew2 | runner | Hitbox (o.s+w)·.32/.35; 3 lives; 1.4s invulnerability with blinking | W2:45-53,75 | D2:148-169,224 | OK | |
| funnew2 | runner | Coin +1, shown as '+1' | W2:54 | D2:170-184 | OK | |
| funnew2 | runner | End: lose scores round(dist/10)+coinN; win scores round(need/10)+coinN·2+lives·5 | W2:51,56 | D2:167,192-195 | OK | |
| funnew2 | runner | HUD: coins, hearts, '🏃 dist/need m', banners ('VẤP NGÃ RỒI!'); hills, deco, ground parallax; dino animation speed t·(1+lv/120) | W2:59-91 | D2:198-255 | OK | |
| funnew2 | frogger | need=min(8,2+floor(lv/10)) | W2:97 | D2:276 | OK | |
| funnew2 | frogger | Rows: roadN=min(5,2+floor(lv/12)); riverN=0 if lv<5, else min(4,1+floor((lv−5)/14)); cell size and centring | W2:105-108 | D2:285-290 | OK | |
| funnew2 | frogger | Lanes: alternating direction; speed cs·ramp(1.3,3.2)·rand(.8,1.25); cars n=round(ramp(2,4)); 3 logs of length round(ramp(3,2)); wrap span W+4cs | W2:109-116,142 | D2:291-305,389-395 | OK | |
| funnew2 | frogger | Controls: dirInput hop, clamped to the board, facing direction, 'jump' sound | W2:124-128 | D2:327-334,351 | OK | |
| funnew2 | frogger | Goal row: crossed++, burst, 'n/need' text, reset to row 0; win scores crossed·10+lives·5 | W2:129-133 | D2:335-348 | OK | |
| funnew2 | frogger | Death: car overlap <.8cs; river with no log under the frog, or riding a log off screen; 3 lives; lose scores crossed·10; the frog is carried by the log | W2:119-123,143-148 | D2:310-325,397-408 | OK | Dart has an extra `if(end!=null) return` at D2:396. The behaviour is the same. |
| funnew2 | frogger | HUD and visuals: crossings, hearts, goalPill, banners; river ripples (JS-style mod kept via _jsMod); smooth hop | W2:139,151-192 | D2:26,375-376,411-497 | OK | |
| funnew2 | pong | need is 3 below lv 20, otherwise 5; paddle width S·ramp(.3,.2); serve vy S·ramp(.55,.95) with vx rand(±.5)S; .8s serve pause | W2:198,203-207 | D2:508,518-531 | OK | |
| funnew2 | pong | Controls: drag/tap x, approach 16, clamped | W2:208-210,218 | D2:532-535,555 | OK | |
| funnew2 | pong | AI: speed S·ramp(.45,1.15); error ramp(.35,.08) as a sin(1.3t) offset; tracks the ball only when it moves toward the AI, otherwise returns to centre | W2:211,220-221 | D2:536,557-558 | OK | |
| funnew2 | pong | Physics: 3 substeps; wall bounce; paddle angle off·.75; speed ×1.05 capped at 1.9S; rally shake once rally>4 | W2:223-235 | D2:563-596 | OK | |
| funnew2 | pong | Scoring: missing the ball gives the opponent a point; first to need wins; win scores mine·5+10, lose mine·5; 'GHI ĐIỂM!' | W2:236-237 | D2:597-618 | OK | |
| funnew2 | pong | HUD and visuals: 'mine : his', banners ('MÁY THẮNG RỒI!'), Robot and hero heads, ball trail, squash and spin | W2:240-267 | D2:621-700 | OK | |
| funnew2 | pong | 2-player mode | — | — | OK | The web pong has no 2-player mode either. Versus games live in funvs1.js. |
| funnew2 | pacman | Maze: DFS carve plus cols·rows/6 extra openings at odd cells | W2:272-284 | D2:705-737 | OK | |
| funnew2 | pacman | Size cols=round(ramp(11,19))\|1; rows=round(cols·min(1.2,(H−top)/W))\|1; wall colour cycles every 10 levels | W2:290-292 | D2:752-754 | OK | |
| funnew2 | pacman | Dots on every open cell except (1,1); stars at 3 corners | W2:294-297 | D2:756-773 | OK | |
| funnew2 | pacman | Ghosts nG=min(5,1+floor(lv/10)), spawn bottom-right | W2:300-301 | D2:776-781 | OK | |
| funnew2 | pacman | Speeds: player ramp(4.2,6), ghosts ramp(2.4,5.4), ×.6 while scared | W2:304,324 | D2:786,859 | OK | |
| funnew2 | pacman | Controls: dirInput with a buffered next direction | W2:303,319 | D2:785,844 | OK | |
| funnew2 | pacman | Ghost AI: no reversing; with p=ramp(.45,.8) sorts by Manhattan distance (flees when scared), otherwise random | W2:325-330 | D2:860-879 | OK | |
| funnew2 | pacman | Star: 6s scared, 'MA SỢ RỒI!'; eating a ghost sends it back to the corner | W2:322,333 | D2:851-857,882-890 | OK | |
| funnew2 | pacman | Caught: lives−−, player reset to (1,1); lose scores eaten; win (all dots) scores eaten+lives·10 | W2:334,337 | D2:891-906 | OK | |
| funnew2 | pacman | HUD and visuals: eaten count, hearts, goalPill (total−left)/total, banners ('MA BẮT MẤT RỒI!'), ghost rings, wobble, scared flicker | W2:340-370 | D2:909-979 | OK | The head always faces right. This copies a web bug (`'l'[0] < 0` is always false). See D2:963. |
| funnew2 | match3 | need=round(ramp(20,90)); moves=round(ramp(22,18)); kinds=round(ramp(4,7)) of 7 fruits; 7×7 board | W2:376-381 | D2:998-1004 | OK | |
| funnew2 | match3 | Opening board has no ready-made matches; pieces drop in from above | W2:383,391 | D2:1007,1033-1037 | OK | |
| funnew2 | match3 | Controls: swipe from the press cell toward the dominant axis, or tap one cell then an adjacent one; input blocked while busy or ended | W2:393,428-439 | D2:1043-1046,1145-1168 | OK | |
| funnew2 | match3 | Move: invalid swap reverts with 'wrong'; valid swap costs a move and resets combo | W2:402-406 | D2:1109-1124 | OK | |
| funnew2 | match3 | Cascade: pts=matchSize·combo; shake; 'xN +pts' text; delays of 160, 220 and 260ms; gravity refill | W2:407-423 | D2:1064-1107 | OK | setTimeout became g.after, which runs on game time. |
| funnew2 | match3 | End: win when score≥need (score+moves·2); lose when moves≤0; 2s delay | W2:424-425,450 | D2:1066-1072,1194-1197 | OK | |
| funnew2 | match3 | HUD: score, 'Còn N lượt' pill (position depends on width), goalPill, banners ('HẾT LƯỢT RỒI!'); fall bounce, swap slide, pops | W2:441-478 | D2:1170-1262 | OK | |
| both | all | Sound names (power, count, coin, boom, hit, pop, win, wrong, shoot, tap, jump) | W1/W2 throughout | audio_service.dart:24-25 | OK | All exist in the Dart sound list. |
| both | all | ramp, endText, hud, levelBanner, goalPill, banner, approach | funcore.js:77-175, funfx.js:34 | K:36,47,483-596 | OK | Dart's banner auto-fits long text, which the web banner does not. This is a harmless improvement. |
| both | all | Bot autoplay (g.bot), only in Dart | — | D1:193,603,1080; D2:102,382,554,843,1198 | OMITTED-OK | Extra code for tests only. It does nothing in normal play. |
| both | all | English UI text through tr() | — | throughout | OK | An addition in Dart. The Vietnamese text matches the web version. |
