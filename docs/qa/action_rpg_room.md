> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Feature-parity audit: action games, RPG, room/pet/duel/class

Method: I read every web file in scope and the matching Dart code. I also ran `numdiff.py` (in this folder), which pulls every numeric literal and quoted string out of each web game function and checks it against the Dart class. After excluding CSS, DOM class names, rgba colours, ms-to-seconds conversions and HUD pixel offsets, no gameplay constant is missing from any Dart port. I then checked logic flows by hand: shop/garage gating per ticket, AI, item effects, scoring, end banners, controls and voice lines.

Paths: web = `reference/web/js/games/*.js` (app.js = `reference/web/js/app.js`); flutter = `lib/features/...`.

| # | file | game / feature | web ref | flutter ref | status | note |
|---|------|----------------|---------|-------------|--------|------|
| 1 | funracer.js | game id `racer` (only export) | funracer.js:216 | fun/action/funracer.dart:23 | OK | |
| 2 | funracer.js | 6 cars (4 free, green 450, black 700) with vmax/acc/grip/robot/armor | :40-47 | funracer.dart:41-48 | OK | values identical |
| 3 | funracer.js | 10 box items, BOX_POOL weights, 9 SHOP_ITEMS | :48-56 | :49-56 | OK | |
| 4 | funracer.js | Garage upgrades eng/acc/grip/nitro/armor/bag, upCost/ipCost/IP_MAX | :57-64 | :57-60 | OK | |
| 5 | funracer.js | Paints (6, 30 coins), decals (4, 40 coins), BAG_MAX 3, RANK_COINS | :65-67 | :61-64 | OK | |
| 6 | funracer.js | carry normaliser `norm()` (v:1 schema) | :74-92 | RacerGear :68-130 | OK | |
| 7 | funracer.js | Garage screen (buy car, tune, upgrade, paint, decal, item stars, bag, Play) | :136-213 | RacerGarage :207-453 | PARTIAL | Car previews are static (`_CarPainter`); web bobs and sways them every frame (`carCanvas` spin). An unowned paint swatch shows only the price; web shows a Coin icon + price. Cosmetic only. |
| 8 | funracer.js | Driver head wears a racing helmet (`hat:'racing'` maps to 'Billed cap' via OLD_HATS) | :31 | drawCar :124 (`drawHead(... hero)`) | PARTIAL | Dart draws the hero's own costume hat. Fix: pass `hero.copyWith(hat: 'Billed cap')` in RacerGame (`hero` at :522) and in `_CarPainter`. |
| 9 | funracer.js | Garage shown only on the first level of a ticket (`opts.car`) | :226-228 | `ses.data['car']` :166-174 | OK | |
| 10 | funracer.js | Level goal (top3 <8, top2 <20, else 1st), length ramp, AI speed incl. gp | :218, :240-254 | :517-519, setup | OK | |
| 11 | funracer.js | Track gen (coins, 3 boxes, boost, ramp, oil, cones), scenery, tribunes | :263-278 | setup :588-622 | OK | |
| 12 | funracer.js | Controls: drag to steer, item button + 2 extra slots, nitro button | :282-301 | _hitBtn/down/move/up :625-650 | OK | |
| 13 | funracer.js | Item effects (rocket x2 at 3 stars, triple, shield, magnet, turbo, robot, zap, oil bomb, gold, fly) | :322-344 | useItem :707-772 | OK | |
| 14 | funracer.js | Armor absorb, knock, AI oil (lv>=5) / rocket (lv>=14), homing rockets, bot rockets | :345-472 | :774-1029 | OK | |
| 15 | funracer.js | Road pickups and hazards, magnet pull, landing dust | :473-497 | :1031-1114 | OK | |
| 16 | funracer.js | End: pos bonus, earn, carry build, score = coins+bonus+hits*2 | :497-503 | :1115-1124 | OK | |
| 17 | funracer.js | HUD (rank, coins, armour, progress bar, buttons, timers), countdown lights, gear show-off, end banner | :643-697 | :1355-1436 | OK | |
| 18 | funracer.js | Engine sound `engine(v)` / stop | :441, :697 | audio.engine | OK | |
| 19 | funshooter.js | game id `shooter` | :147 | funshooter.dart:19 | OK | |
| 20 | funshooter.js | 8 guns, max 5 stars; GUN_PRICE 300, starPrice 100n | :16-36 | :41-62 | OK | |
| 21 | funshooter.js | 6 workshop upgrades with tiered prices | :28-35 | kShipUps :53-60 | OK | |
| 22 | funshooter.js | 3 skills (shield 10, meteor 18, giant 26 kills); bombs max 5, drones max 2 | :38-43 | :63-64 | OK | |
| 23 | funshooter.js | carry read/pack | :47-62 | ShipGear :67-105 | OK | |
| 24 | funshooter.js | Workshop shown once per ticket | :106-158 | ShipShop + `ses.data['shop']` | OK | |
| 25 | funshooter.js | 6 enemy types, V formation, mid boss (28 s), final boss (60 s, rage phase) | :340-372, :398-421 | :714-760, :846-890 | OK | |
| 26 | funshooter.js | Per-gun fire patterns, RATE table, beam tick, thunder chain, vortex boomerang, ice slow | :278-337 | :600-712 | OK | |
| 27 | funshooter.js | Drops (gun/shield/heart/bomb/drone/magnet), maxed gun gives coins | :204-214, :466-490 | :1060-1120 | OK | |
| 28 | funshooter.js | Hurt lowers gun stars in-level, auto-recharging armour shield | :423-432, :383 | :755-765 | OK | |
| 29 | funshooter.js | Controls: drag to fly, bomb button, 3 skill buttons, tap gun bar to switch | :180-195 | :397-420 | OK | |
| 30 | funshooter.js | Win bonus 10+lv/3, wins++, banners | :233-238, :610-611 | :529-535, :1279-1280 | OK | |
| 31 | funtank.js | game id `tank` | :139 | funtank.dart:20 | OK | |
| 32 | funtank.js | 8 weapons (TK_WEAPONS), 4 skills (costs 25/35/50/60), 3 bodies, 5 upgrades, prices | :15-46 | :37-68 | OK | |
| 33 | funtank.js | Tank workshop (colour, weapon buy 120, upgrades), once per ticket | :95-136 | TankShop + `ses.data['shop']` | OK | |
| 34 | funtank.js | need/bossLv, hpMul, range/cd/speed from upgrades, allies at start | :140-158 | :345-400 | OK | |
| 35 | funtank.js | Enemy types basic/fast/heavy/turret/boss, spawn rules, boss at every 5th level | :255-280 | :530-570 | OK | |
| 36 | funtank.js | Weapon fire logic x8 (norm, multi, bounce, homing, blast, laser, flame, mine) | :310-327 | :688-745 | OK | |
| 37 | funtank.js | Skills (shield, fix, air strike with plane + bombs, ally max 2) | :188-200 | :465-495 | OK | |
| 38 | funtank.js | Drops, crates and sandbags, splash damage, killFoe energy/coins | :281-307 | :572-650 | OK | |
| 39 | funtank.js | Controls: tap to drive (turret auto-aims), weapon buttons left, skill buttons right | :202-213 | down/move | OK | |
| 40 | funtank.js | End score and coins, banners | :176-181, :559-560 | :440-447, :1257-1259 | OK | |
| 41 | funvs1.js | Mode picker "Đấu với máy" / "Hai người", remembered per ticket | :15-25 | vs_core.dart VsView :194-250 | OK | |
| 42 | funvs1.js | `versus()` result (pvp title / bot win+score) | :27-34 | vsResult :22-27 | OK | |
| 43 | funvs1.js | Multi-touch, canvas buttons, scoreBar, vsIntro, endVs, sky/clouds | :42-96 | vs_core.dart :30-130 | OK | |
| 44 | funvs1.js | `fighter` (Võ đài): walk/jump/punch/block, AI, pvp buttons | :100-223 | funvs1.dart:26-298 | OK | numdiff: no missing constants |
| 45 | funvs1.js | `hockey` (Khúc côn cầu) | :224-342 | :299-562 | OK | |
| 46 | funvs1.js | `tug` (Kéo co): tap fast, both sides in pvp | :343-416 | :563-691 | OK | |
| 47 | funvs1.js | `soccer` (Bóng đá đầu to) | :457-552 | :692-897 | OK | |
| 48 | funvs1.js | `volley` (Bóng chuyền) | :553-649 | :898-1076 | OK | |
| 49 | funvs2.js | `snowball` (Ném tuyết): drag back and release | :14-118 | funvs2.dart:28-253 | OK | |
| 50 | funvs2.js | `tron` (Mô tô ánh sáng) incl. flood-fill AI | :119-222 | :254-510 | OK | |
| 51 | funvs2.js | `sumo` | :223-313 | :511-726 | OK | |
| 52 | funvs2.js | `caro`: board size 3/6/9 with win length 3/4/5 by level, AI delay 550 ms | :330-413 | :727-932 | OK | |
| 53 | funvs2.js | `connect4` | :414-515 | :933-1208 | OK | |
| 54 | rpg.js | 10 zones (id, name, icon, boss, colour, runner) | :12-23 | rpg.dart:33-44 | OK | |
| 55 | rpg.js | 8 weapons, 6 armours, 5 charms (stats, costs) | :27-52 | :55-79 | OK | identical |
| 56 | rpg.js | 3 companions (dog free, fairy/cat after zone 3, dragon/fox after zone 6) | :53-57 | :89-93 | OK | |
| 57 | rpg.js | POTION 25, MAX_POT 5, MAX_LV 50, need(L), stats(), rec level | :58, :140-146 | :94, :186-198 | OK | |
| 58 | rpg.js | p.rpg default save schema | :136-139 | rpgOf :163-184 | OK | |
| 59 | rpg.js | Village scene (tiles, walking NPCs holding weapons) | :68-134 | RpgVillage :687-830 | OK | |
| 60 | rpg.js | Town hero card: figure **holding the equipped weapon**, pet, level/XP bar, stat chips, Shop/Companion buttons | :167-175 | :315-371 | PARTIAL | `FigureView` (figure.dart:487) has no weapon param, so the town hero has no weapon in hand. Web: `figureEl(...).weapon = WEAPONS[R.w].img`. Fix: draw it with `drawFigure(..., weaponImage:)` in a CustomPaint, as RpgVillage already does. |
| 61 | rpg.js | NPC tip bubble (random NPC + tip); NPC **holds its weapon** | :62-66, :176 | :102-107, :383-392 | PARTIAL | Tips/names are OK. The NPC portrait uses `FigureView` with no weapon (web `figureEl(npc.c).weapon = npc.wp`). |
| 62 | rpg.js | World map tiles (locked toast, recommended level, 6 dots with crown) | :151-164, :178 | _zoneTile :398-455 | OK | |
| 63 | rpg.js | Stage picker (locked, ticket check + noTicket voice, boss tile) | :182-200 | rpgStagePicker :458-525 | OK | |
| 64 | rpg.js | Shop tabs weapons/armour/charms/potions, buy/use, "Chưa đủ vàng" | :202-226 | rpgShop :528-616 | OK | |
| 65 | rpg.js | Companion picker | :228-239 | rpgPetPicker :640-685 | OK | |
| 66 | rpg.js / app.js | playStage rewards (first-clear XP/gold, boss x3, goldMul/xpMul, level ups, unlocks), free parent mode | rpg.js:243-263; app.js:994-1010 | applyStage :218-243; RpgStageScreen :838-950 | OK | |
| 67 | rpg.js | Result panel (cleared/level up/unlock/new zone/final trophy, Next/Retry with ticket, "Học để có vé") | :266-291 | _result :955-1030 | OK | |
| 68 | rpg.js | Voice: rpgTown, rpgBoss, rpgZ{r}, rpgClear, rpgLevelUp, youWin, rpgLose, noTicket | :150, :245, :269 | rpg.dart :282, :896, :962-966 | OK | |
| 69 | rpgcore.js | foeStats, taken, strike (crit), PET_RIG, BASE_IMGS, fade, hpBar/topHud/bossBar, zoneIntro, endBanner, drawHero | :27-94 | rpgcore.dart:66, :700-800 | OK | |
| 70 | rpgcore.js | Joystick (drag on left half) + **keyboard arrows/WASD** | :97-125 | rpgcore.dart:610-680, :1612 | OK | |
| 71 | rpgcore.js | Potion button (+50% HP), potion count | :127-135 | :820-835 | OK | |
| 72 | rpgcore.js | Companion AI: dog bites (atk x0.4, bark), cat heals 2.5%/s, fox fireballs (atk x0.6) | :138-158 | PetState :884-935 | OK | |
| 73 | rpgcore.js | Arena engine (melee/auto-fire, skill, telegraph rings, drops, gold/xp formula, dying anims) | :162-359 | :1100-1600 | OK | |
| 74 | rpgcore.js | RPG_SHEETS includes `kenney-fish/fish` | :12 | kRpgSheets :58-64 | OMITTED-OK | No zone uses this sheet in web. |
| 75 | rpgzones1.js | Zone 1 `forest`: goblins/boar/spider, boss Troll (Quỷ Đá) with ground slam + spawns | :48-79 | rpgzones1.dart | OK | |
| 76 | rpgzones1.js | Zone 2 `sea`: ship, auto cannon, sharks; boss Squid | :81-120 | rpgzones1.dart | OK | |
| 77 | rpgzones1.js | Zone 6 `sky`: eagle mount, comet auto-fire; boss Thundercloud | :122-156 | rpgzones1.dart | OK | |
| 78 | rpgzones1.js | Zone 9 `swamp`: darkness, light orbs, 💡 flash stuns; boss Ghost King (shield, teleports) | :158-215 | rpgzones1.dart | OK | |
| 79 | rpgzones1.js | Zone 10 `castle`: 3 allies (Bé Mây, Bé Lá, Bé Gió); boss Dragon with rage phase | :217-292 | rpgzones1.dart:624-700 | OK | Costumes match: web `dress/long` give base girl; `hat:'ears'` maps to null. |
| 80 | rpgzones2.js | shell (HP, potion, intro, end, keys) | :8-62 | rpgzones2.dart | OK | |
| 81 | rpgzones2.js | Zone 3 `mine`: maze, dig rocks, key + door, bats; boss Spider; d-pad + swipe + keys | :64-196 | rpgzones2.dart:270-560 | OK | |
| 82 | rpgzones2.js | Zone 4 `snow`: turn-based ⚔️/❄️/🛡 with timing bar 👊 (space key); boss Mammoth | :198-302 | rpgzones2.dart:560-760 | OK | |
| 83 | rpgzones2.js | Zone 5 `desert`: dig with hot/cold hints, scorpions; boss Scorpion King pops up | :304-387 | rpgzones2.dart | OK | |
| 84 | rpgzones2.js | Zone 7 `candy`: 3 towers (pop 30, ice 40, boom 60), place/upgrade, waves; boss Candy Spider | :389-482 | rpgzones2.dart:1178-1180 | OK | |
| 85 | rpgzones2.js | Zone 8 `volcano`: platformer ◀▶⬆⚔️ + keys, lava, fireballs, flag; boss T-Rex | :484-596 | rpgzones2.dart:1600-1903 | OK | |
| 86 | app.js | room(): mascot dressed, wallet, 4 slots (hat/eyes/hand/bg), buy/equip/unequip, voice buyOk/needMore, roomIntro on route | :842-866, :1603 | room.dart, wardrobe.dart | OK | |
| 87 | app.js | album(): stickers grid with count, missing silhouettes, tap sfx, badges, voice `album` | :620-636 | stickers.dart | OK | |
| 88 | app.js | classScreen(): week, TV/Toán tabs, current-week cards, first-todo highlight, thin/story notes, activity tiles with stars, prev/next folds, footer | :476-503 | lop1.dart | OK | |
| 89 | app.js | pickClassWeek(): parent gate, 35-week list with labels, "Theo lịch năm học" reset | :504-519 | lop1.dart `_pickWeek` | OK | |
| 90 | app.js | classDone rewards (3 tickets per finished lesson, next activity) | :439-456 | core/game/class_plan.dart (frame) | OK | Out of folder D; handled by core. |
| 91 | app.js | lookCard (avatar boy/girl, shirt, hat) | :935-963 | (fun hub, agent E) | OMITTED-OK | Not part of room/pet/duel/class. |
| 92 | pet.js | Adopt flow: animated species cards, name input (max 14) + name chips, petHello, initial stats | :595-683 | pet.dart:145-290 | OK | |
| 93 | pet.js | 5 stats with hourly decay (9/11/6/7/6), floor 8, energy rises while asleep, 48 h cap, level = xp/60 (max 10) | :11-36 | pet_sim.dart:20-43 | OK | |
| 94 | pet.js | onLesson (+8 happy, +5 xp) | :39-45 | pet_sim.dart:46-54 | OK | |
| 95 | pet.js | Real animal voices per species (+ cat purr loop) | :19-26, :74-82 | pet_sim.dart:57-72, :200-225 | OK | |
| 96 | pet.js | Autonomous AI `decide()` (eat/drink/sleep/beg/scratch/wander/sit/lie/sniff/look/hop) | :135-157 | pet_sim.dart | OK | |
| 97 | pet.js | Touch: tap reactions, triple tap roll, stroke = petting + hearts, tap floor = follow (cat pounce), wake sleeper | :187-261 | pet_sim.dart:420-530, :750-765 | OK | |
| 98 | pet.js | Feed (species foods, full check + petFull voice), water, bowls with 3 portions, petYum/petDrink | :548-566, :346-358 | pet_sim.dart:615-660, :895-905 | OK | |
| 99 | pet.js | Play: ball throw/flick, dog fetches, cat/rabbit/hamster bat it, petSleepy when tired | :159-188, :567-574 | pet_sim.dart | OK | |
| 100 | pet.js | Bath: tub, scrub foam progress bar, rinse button, shake dry, petScrub/petClean | :264-298, :575-581 | pet_sim.dart:540-580, :660-665; pet.dart:513-525 | OK | |
| 101 | pet.js | Sleep (bed, night overlay, Zzz, snore, wake), petNight | :360-368, :582-587 | pet_sim.dart:670-680, :905-915 | OK | |
| 102 | pet.js | Wear items unlocked by level (locked toast "Cấp N"), level-up confetti + petGrow + petNewItem after 2.6 s | :119-133, :588-599 | pet_sim.dart:255-275, :685-700; pet.dart:503-512 | OK | |
| 103 | pet.js | Stat bars (low < 35 highlight) + XP bar, title "· Cấp N" | :523-531 | pet.dart:424-452, :386 | OK | |
| 104 | pet.js | Room drawing (wall, day/night window, picture, floor, bed, bowls, tub, thought bubble of need, depth sort) | :421-478 | pet_sim.dart paint | OK | |
| 105 | pet.js | Greeting on entry (need voice petHungry/Thirsty/Dirty/Sleepy/Sad, else petLove); exit voice petWash | :589-594; app.js:1016 | pet_sim.dart:710-725; pet.dart:34 | OK | |
| 106 | pet.js | Pause on `visibilitychange` | :496-503 | Flutter ticker is muted in background; dt clamped to 0.05 | OMITTED-OK | |
| 107 | pet.js | Periodic save every 5 s, bars every 1 s, save on exit | :418-419 | pet_sim.dart:992-998, pet.dart:361 | OK | |
| 108 | petrig.js | SPECIES table (dog, cat, rabbit, hamster, panda, fox), newPose, easePose, drawPet (legs, ears, tail, muzzle, cheeks, panda, mask, wear, dirt, foam) | :7-292 | petrig.dart:56-468 | OK | numdiff: only rgba / arc-sweep forms differ |
| 109 | duel.js | 3 topics (count, letters, math), 10 rounds, PICS list | :7-30 | duel.dart:20-76 | OK | |
| 110 | duel.js | Split screen; top half rotated 180° in portrait; first correct answer on pointer-down scores; wrong answer locks that side 1.3 s; answer voice + 1.1 s | :48-90 | duel.dart:126-200, :376-400, :508 | OK | |
| 111 | duel.js | Voices duelIntro, ready, question say, duelKid/duelParent/duelTie; result overlay with Map / Rematch; quit ✕ | :34, :63, :94-104 | duel.dart:108-260 | OK | Dart also lets the player tap the 🔊 visual to repeat the letter question (extra). |

## Counts
- OK: 104
- PARTIAL: 4 (#7, #8, #60, #61)
- MISSING: 0
- OMITTED-OK: 3 (#74, #91, #106)
