> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Feature parity: web js/app.js (+ index.html, ui.js) vs Flutter lib/

Status: OK = faithful · PARTIAL = differs (see note) · MISSING = not implemented · OMITTED-OK = intentionally dropped (native/store policy)

| area | feature | web ref (app.js:line) | flutter ref (file:line) | status | note |
|---|---|---|---|---|---|
| boot | Load content/app/photos/voice JSON before use; Start screen drawn immediately | 1620-1633 | lib/main.dart:15-33 | OK | Flutter loads everything before runApp, so the "⏳ Đang tải…" button state (app.js:241-246) is not needed |
| boot | Clear hash/search on load → always open at Start | 1625 | lib/app_router.dart:60 (initialLocation '/') | OK | |
| boot | Service worker register / update-reload / warm cache | 1640-1654 | — | OMITTED-OK | PWA only; assets are bundled |
| boot | index.html rescue script (BVH_FAIL/BVH_FIX, 20s timeout, "↻ Tải lại") | index.html:30-80 | — | OMITTED-OK | PWA cache-repair only |
| boot | Sky background with clouds | index.html:27 | lib/app.dart:68 (SkyBackground) | OK | |
| boot | document.lang = lang() | 1621, 755 | — | OMITTED-OK | No DOM; I18n provider drives text |
| boot | iconize() emoji → SVG icon buttons | ui.js:146-155 | core/ui (IconBtn/AppIcon) | OK | Native icon set used everywhere |
| boot | sync.init re-render of kids/map/parent/lop1 on remote data | 1636-1639 | lib/app.dart:30; core/store/store.dart:26 (ChangeNotifier) | OK | Every screen watching storeProvider rebuilds; play screens keep state via keyed subtree |
| router | route() guard: not started → Start | 1585 | lib/app_router.dart:46 | OK | |
| router | needKid guard (except '', kids, new, parent, report) → /kids or /new | 1587-1588 | lib/app_router.dart:40,47-48 | OK | |
| router | overLimit guard → /rest (except rest) | 1589 | lib/app_router.dart:49 | OK | |
| router | kids with no profiles → /new; rest when not over limit → /map; rpg when fun off → /map | 1591,1606,1607 | lib/app_router.dart:50-52 | OK | |
| router | unknown route → Start | 1608 | lib/app_router.dart:108 | OK | errorBuilder renders StartScreen without changing the URL |
| router | route() stops voice on EVERY navigation (audio.stopVoice) | 1582 | only play_screen.dart:137,166 / review.dart:189,282 | PARTIAL | No global stopVoice on route change. E.g. map → buddies/parent/album while "pickIsland" or an intro is talking keeps talking. Fix: add a router listener (routerDelegate.addListener / GoRouter observer) that calls ref.read(audioProvider).stopVoice() when the location changes (before the new screen's SayOnOpen fires) |
| router | route() removes all overlays + buddy on navigation | 1581 | showPanel on root navigator (core/ui/overlay.dart:21-38) | OK | Pageless dialog routes are dropped when go_router replaces pages |
| router | route(true) re-runs guards for "Chơi lại"/"Ôn tiếp" (over-limit check) | 600, 1433 | play_screen.dart:149-157; review.dart:343-350 | PARTIAL | Flutter "Chơi lại" (play) and "Ôn tiếp" (review) rebuild in place without re-running the router guard, so a child past the daily limit can keep replaying forever (timer skips 'play'). Fix: in onAgain / again==true, check `store.overLimit()` and `context.go('/rest')` instead of rebuilding (also re-check levelUnlocked like web play() does) |
| router | Resume route after reload: sessionStorage 'bvh.route' saved for map/island/fun/pet/album/room/buddies/rpg/lop1 (not fun/<id>, rpg/<r>/<s>); Start → resumeRoute() when 1 profile | 125-131, 254, 1586 | start_screen.dart:28-29 (always '/map') | MISSING | No equivalent. Native app killed in background (iPad memory) restarts at Start → /map. Fix: in a router listener save `routeName` path to `store.setKv('bvh.route', path)` when first segment ∈ RESUME list and not (fun\|rpg with sub-path), else ''. In StartScreen._start, when exactly 1 profile, `context.go(resume ?? '/map')`. Consider expiring it (web sessionStorage dies with the tab) e.g. store timestamp and ignore if > a few hours |
| usage | 15s usage timer: only when started, foreground, profile, name ∉ ['', kids, new, parent, report, rest]; addUsage(15); overLimit && name≠'play' → /rest | 1613-1618 | lib/app.dart:28,33-41,44-49 | OK | |
| start | Parade (Man superhero, Robot, T-rex, Princess), logo "Bé Vui Học", tagline, ▶ Bắt đầu | 257-261 | home/start_screen.dart:58-104 | OK | |
| start | Tap: audio.unlock, music, started=true, sfx win; 0 profiles → 'welcome' + /new; 1 → map; else /kids | 239-256 | home/start_screen.dart:17-33 | PARTIAL | Logic matches except resumeRoute (see router row). store.persist() is web-only (OMITTED-OK) |
| start | iOS mute hint "🔇 Không nghe tiếng? Gạt nút im lặng…" | 263 | — | OMITTED-OK | Old-iOS Safari only. Verify on device that SoLoud uses a playback audio-session category so the silent switch does not mute voice |
| start | Links Giới thiệu · Ghi công | 264-265 | home/start_screen.dart:35-39,106-113 | OK | Behind parent gate (kids-category policy) — intentional |
| telemetry | hello() new_profile ping, active() daily ping, noteSource/refKind/firstTouch/devKind, shareEvent(), cafeSeen() | 133-211, 1169-1175 | — (features/sync/firebase_setup.dart:2 "KHÔNG Analytics") | OMITTED-OK | Kids-category app: no analytics. Only implicit justification (firebase_setup comment) — no comment explicitly mentions hello/active pings |
| kids | Title "whoPlays" + phrase, ParentButton, kid cards (mascot, name, ⭐), "+ Thêm bé" | 269-281 | home/kids_screen.dart:18-100 | OK | |
| kids/map | installBanner (iOS, not standalone, sessionStorage noinstall; "?" overlay with steps; ✕) | 1042-1058 | — | OMITTED-OK | PWA-only; documented for the install card in parents.dart:4-5 |
| newKid | Step 1: name input (max 20, placeholder, autofocus 300ms, Enter → next), Next disabled until name; back to /kids only if profiles exist | 284-303 | home/new_kid_screen.dart:26-32,77-124 | OK | Back from step 2 keeps the typed name (web re-creates step 1 empty) — harmless |
| newKid | "🔑 Đã có mã gia đình" (only 0 profiles + sync supported) → join → /kids or toast notfound/bad/offline | 294-301 | home/new_kid_screen.dart:58-72,125-133 | OK | |
| newKid | Step 2: phrase pickMascot, free mascots (no stars), say mascotVi/En, "Let's go" → addProfile, sfx win, confetti, /map | 305-328 | home/new_kid_screen.dart:43-56,139-163 | OK | hello()/active() telemetry omitted (see telemetry) |
| map | Reset island intro memory; phrase pickIsland | 337-338 | map/map_screen.dart:26,31 | OK | |
| map | Hello button (dressed avatar, "Chào {name}", sub) → /buddies | 341-343 | map/map_screen.dart:56-78 | OK | |
| map | Tier pill → chooseTier; star pill; album (Trophy) → /album; switch kid → /kids; ParentButton | 344-349 | map/map_screen.dart:82-100 | OK | |
| map | Auto-open chooseTier when no tier | 378 | map/map_screen.dart:33-36 | OK | Flutter tests `tier == null`; web `!p.tier` also triggers on 0 (only matters for imported data) |
| map | dailyBar: 🎯 title, 3 task islands (done ✔, → /island), streak 🔥, "🔁 Ôn bài N" when dueCount ≥ 2 | 109-122 | map/map_screen.dart:293-366 | OK | Tasks created post-frame (store write outside build) |
| map | Fun bar (only settings.fun): Joystick, tickets, Racing car/Rocket/Robot → /fun | 353-355 | map/map_screen.dart:427-440 | OK | |
| map | Pet bar: pet img/name or Paw prints/petRoom, petCare/petAdopt → /pet | 356-358 | map/map_screen.dart:441-449 | OK | |
| map | Islands grid; tier 3 → lop1 first; special islands (room ⭐wallet, lop1 "Tuần N", duel 👨‍👩‍👦); soon (pop + 'soon'); progress done/total in current tier; 'full' when all done | 360-375 | map/map_screen.dart:110-165,172-282 | OK | |
| tier | chooseTier overlay: phrase pickTier, 3 tier cards (on = current), pop sfx, updateProfile tier, clear viewTier, tierHint | 49-62 | tiers/tier_picker.dart:13-52 | OK | Panel not barrier-dismissible (like web). Android system back can still pop it — acceptable |
| island | Guard (missing/soon/route → map); intro phrase only when island changed | 386-391 | map/island_screen.dart:28-39 | OK | |
| island | Tier tabs when >1 tier (viewTier), progress bar "levelsDone", level cards (img or number, 🔒, next highlight, ★★★); locked → wrong + 'locked' | 392-414 | map/island_screen.dart:53-157,196-257 | OK | |
| levels | levelsOf / tierFor / tierLevels / unlocked (lockOrder) | 13-47 | core/content/levels.dart:33-109; learn_tracking.dart:163 | OK | |
| lop1 | classWeek (parent week + weeks since, else from kntt.start; clamp 1..35) | 421-428 | core/game/class_plan.dart:42-54 | OK | |
| lop1 | classItems tv (bài) + tv2 (tuần) / toan | 430-435 | core/game/class_plan.dart:75-86 | OK | |
| lop1 | classScreen: topbar "Học cùng lớp" + "Tuần N" pill, TV/Toán tabs, "Tuần N trên lớp", current items (fallback to latest earlier item unless wk 18), firstTodo highlight, review/continue note, folds (prev reversed / next), footer text, parent-gated "other week" | 476-502 | features/room/lop1.dart:25-35,62-193 | OK | |
| lop1 | classCard: title/sub/✔, thin note, stories note, activity buttons (level img, actName, ★) → /play/…/lop1 | 457-475 | features/room/lop1.dart:195-259; class_plan.dart:124-130 | OK | |
| lop1 | pickClassWeek overlay: 35 weeks with labels (week 18 "Ôn tập cuối học kì 1"), select → p.cls {wk, at=monday}, "Theo lịch năm học" keeps done, Cancel | 504-518 | features/room/lop1.dart:262-325; class_plan.dart:57-67 | OK | |
| lop1 | classDone: next activity in same item; first completion → +3 tickets (fun on) once, reward text | 439-456 | core/game/class_plan.dart:92-121 | OK | |
| play | Guard: valid island/level, unlocked → else /map | 521-527 | play/play_screen.dart:46-72 | OK | |
| play | Topbar back → home (/lop1 or /island), progress segments, star pill; buddy (dressed, no bg) with cheer/sad anims; hideBuddy | 529-553 | play/play_screen.dart:173-249 | OK | |
| play | Photo mode on during level (setPhotoMode(true)) | 534 | play/play_screen.dart:197 (PhotoScope) | OK | |
| play | ensureLearn; g.record → recordQ(itemKeys, confNs) ; gate | 538-547 | play/play_screen.dart:75-78,116,119; learn_tracking.dart:126-160 | OK | |
| finish | recordRound (sticker), dailyProgress, tickets ticketsPer(+2 daily), unlocked mascots, newBadges, milestones, dueCount, sfx win + confetti + 'roundDone' | 563-577 | play/finish_round.dart:35-54 | OK | |
| finish | Pet happiness +8 (cap 100), xp +5 | 570-571 | play/finish_round.dart:39-45 | PARTIAL | Web uses `(p.pet.happy \|\| 50) + 8` → a pet at happy 0 becomes 58. Flutter `asInt(pet['happy'], 50)` only defaults on null → 0 becomes 8. Fix: `final h = asInt(pet['happy']); pet['happy'] = ((h == 0 ? 50 : h) + 8).clamp(0, 100);` |
| finish | Next path: next level in viewed tier, or lop1 next activity; home path | 579-585 | play/finish_round.dart:56-67 | OK | |
| finish | Result panel: "great", 3 stars lit 380ms each + 'star', prizes (sticker, new buddy, daily ✔ +5 ⭐, pet happy, tickets, lop1 reward "+3 vé", badges, milestone buttons → certificate), "🔁 Ôn nhanh N chỗ hay nhầm" when due ≥ 3, buttons Map/🎒 Bài học, Again, Next | 586-611 | play/finish_round.dart:77-179 | OK | |
| finish | After stars: wait 1600; milestones → celebrate; else phrase dailyDone > badge > newMascot > newSticker | 610-617 | play/finish_round.dart:82-98 | OK | |
| finish | "Chơi lại" re-runs route | 600 | play/play_screen.dart:149-157 | PARTIAL | See router row: no overLimit / unlocked re-check |
| milestones | MS_STEPS, masteredCount, milestoneIds (w/e/m/l10/lall/i:<isl>:<tier>), msInfo texts, ensureLearn pre-mark, checkMilestones | 1135-1175, 1099-1107 | core/game/learn_tracking.dart:14,165-241 | OK | |
| milestones | celebrate(): confetti 140, win, phrase, trophy + pic, lines, "Tiếp ➜" / "🏅 Bằng khen" | 1178-1192 | play/finish_round.dart:182-214 | OK | |
| badges | 14 BADGES with tests (allDone by current tier, explorer = level 0 of every game island) | 88-106 | core/game/learn_tracking.dart:55-70,252-274 | OK | |
| album | Phrase album, count pill have/total, sticker grid (missing silhouette, pop/tap sfx), badges grid | 620-635 | features/room/stickers.dart:37-129 | OK | |
| buddies | All mascots, locked by stars (wrong + needStars), pick → updateProfile, pop, say mascot; star pill | 638-656 | home/buddies_screen.dart:13-51; new_kid_screen.dart:167-244 | OK | |
| gate | a,b ∈ 3..9, keypad 1-9 ⌫ 0 OK, max 3 digits, wrong → reset + toast ✖, Cancel | 659-682 | core/ui/parent_gate.dart:15-93 | OK | |
| gate | parentBtn: gear + "Bố mẹ" label, gate → /parent | 684-690 | core/ui/parent_gate.dart:96-124 | OK | |
| parent | Back → /map if profile else /kids; title | 752 | parents/parents.dart:81-92 | OK | |
| parent | Settings: language, music (re-applies music), sound, limit 0/15/20/30/45, lockOrder, funZone, ticketsPer 1/2 | 742-761 | parents/settings.dart:11-68 | OK | |
| parent | Give tickets: per kid "Name (🎟️ n) +3", keeps active kid, toast | 762-766 | parents/settings.dart:18-23,69-83 | OK | |
| parent | Kids card: mascot, name, "⭐ · levelsDone a/total · rounds · today min", weekBars | 768-775 | parents/parents.dart:108-139 | OK | |
| parent | weekBars: 7 days minutes, max(10,…) scale, day number | 730-739 | parents/parents.dart:181-218 | OK | |
| parent | Kid actions: 📊 report, 🌱 tier (chooseTier), rename (prompt, trim, 20 chars), remove (confirm) ; "+ Thêm bé" | 776-787 | parents/parents.dart:140-175 | OK | |
| parent | Backup: download JSON `be-vui-hoc-<today>.json`; restore file → importData, toast restored/badFile | 744-748, 789-800 | parents/parents.dart:36-59,221-266 | OK | Native save dialog / share sheet instead of <a download> |
| parent | syncCard: create / join (prompt) / masked code + 👁 show / last sync time + last error / sync now / leave (confirm) / wipe server (confirm); toasts | 694-720 | parents/sync_card.dart:30-130 | OK | Additionally hidden when RemoteFlags.syncEnabled is false (extra kill switch) |
| parent | Feedback card: Zalo link, Giới thiệu link, "🎤 Hỏi lại về micro" (clears bvh.micOK + toast) | 802-812 | parents/parents.dart (FeedbackCard) | OMITTED-OK | 18/10/2026: Zalo link (developer channel) removed; note now points parents to the App Store / Google Play listing; Crashlytics removed so the note says the app sends no error reports; Giới thiệu opens the in-app About page (info_pages.dart) |
| parent | shareCard: native share sheet "📤 Chia sẻ Zalo, Facebook, Messenger…" (desktop: Facebook sharer link) + "📋 Chép link" with APP_PITCH + link | 1258-1275 | parents/parents.dart:295-316; certificate.dart:19-22 | OK | Pitch says "ứng dụng" instead of "web"; shareEvent telemetry dropped; no FB sharer (mobile-only app) — 18/10/2026: link is https://bevuihoc-app.web.app/ without ?src= tags |
| parent | Cafe/donation card: bank QR, save QR (saveQR), copy account number (copyText) | 214-234, 814-823 | — (parents/parents.dart:4) | OMITTED-OK | Documented: store policy forbids non-IAP payments in kids apps |
| parent | Credits: photo count note, expandable list (name — by — licence — link to Wikimedia source c.src), sfx CREDITS.txt link | 824-831 | parents/parents.dart:319-372 | PARTIAL | Per-photo source link (c.src, the Wikimedia file page) is not shown/linked — each row only says "Wikimedia Commons". For CC-BY/BY-SA attribution, add the source URL: make the "Wikimedia Commons" part tappable → `io.openUrl(e.value.src)` (PhotoInfo needs a `src` field if absent) or print the URL. SFX credits shown inline (fine) — 18/10/2026: "Ghi công (web)" link replaced by the in-app Credits page (info_pages.dart) |
| parent | Install card (why/steps) + version | 832-837 | parents/parents.dart:101 (version card only) | OMITTED-OK | Install steps PWA-only (documented parents.dart:5); version shown as kAppVersion '1.0.0' (matches pubspec 1.0.0+1 but hard-coded — consider package_info) |
| parent | (extra) Privacy policy card → in-app policy (assets/legal/privacy_*.md) + web version link | — | parents/parents.dart (PrivacyCard), info_pages.dart | OK | Added 18/10/2026 for store review |
| parent | (extra) Remote notice card | — | parents/parents.dart:77,93 | OK | Flutter-only addition |
| room | Wallet pill, dressed big preview, slot tabs (hat/eyes/hand/bg), wardrobe: owned → equip/unequip (pop), buy → win + confetti(30) + buyOk, else wrong + needMore; tag ✔/wear/⭐price; phrase roomIntro on route | 842-863, 1603 | features/room/room.dart:24-73; wardrobe.dart:16-35,87-124 | OK | Item names localized (web always shows w.vi) |
| fun | funZone: funIntro once per session, topbar tickets, funHow note, lookCard, parent-free row (gate → on / exit), groups: Hot (RPG card + hot games), action/vs/casual/brain | 868-897 | features/fun/hub/fun.dart:24-201 | OK | |
| fun | funCard: no ticket (and not parent) → wrong + noTicket phrase + toast; else /fun/<id>; sub "Cấp x/60 · 🏆 best" | 890-896 | features/fun/hub/fun.dart:56-69,81-89 | OK | All web games have levels:true, so always showing level is equivalent |
| fun | RPG card "Thế giới phiêu lưu · Nhập vai · Cấp n" → /rpg | 873-875 | features/fun/hub/fun.dart:91-104 | OK | |
| fun | fillGrids: last card spans the rest of the last row (wide layout) | 965-978 | features/fun/hub/fun.dart:205-239 | OK | |
| fun | lookCard: boy/girl seg, shirt swatches, hats (✖ none), preview figure (cheer), default base from mascot costume; saves p.look + setPlayer | 935-962 | features/fun/hub/fun.dart:290-370 | OK | |
| fun | applyLook before fun/rpg screens | 981-985 | features/fun/hub/fun.dart:50-54; rpg.dart:892 | OK | |
| funPlay | Guard: unknown game or fun off → /map; not free and no ticket → noTicket phrase + /fun | 899-906 | play/fun_play_screen.dart:40-59 | OK | |
| funPlay | Close ✕ → /fun | 910 | play/fun_play_screen.dart:107-112,201-208 | OK | |
| funPlay | leveled loop (max 3 levels/ticket, stop on loss or max level), pvp passthrough, levelUp/saveGear disabled when free | fun.js:144-160; app.js:912-914 | play/fun_play_screen.dart:85-105; core/game/fun_games.dart:122-131 | PARTIAL | In free (parent) mode web still passes the returned `carry` to the next level within the same ticket (`opts.carry = r.carry`, only persistence is skipped). Flutter only saves gear when !free and rebuilds context with `store.gear(p,id)`, so in parent-free mode gear won between levels is lost. Fix: keep a local `Json? carry` in _FunPlayScreenState, set it from r.carry, and use `carry ?? store.gear(...)` in _newContext |
| funPlay | Result: saveBest (not free/pvp), win sfx + confetti on win/record, phrase newRecord/youWin/gameOver, title (res.title / pos / win), coin score, "+n cấp → Cấp x/60" (not free), record or best note, buttons 🎮 Fun zone + Again/Next (🎟️ 1) or 📚 learn more | 917-931 | play/fun_play_screen.dart:114-163 | OK | |
| rpg | rpgTown / rpgPlay: fun off → /map; canPlay (unless free); ticket (unless free) else noTicket + /rpg; result panel with next stage | 988-1010 | features/rpg/rpg.dart:263+, 872-890 | OK | |
| pet | petRoom; onExit says 'petWash' then /map | 1013-1017 | features/room/pet.dart:33-36,51 | PARTIAL | The adoption screen's back button (no pet yet) goes to /map WITHOUT 'petWash' (pet.dart:51). Web passes the same onExit to adopt() (pet.js:51,628), so it says petWash there too. Fix: `_Adopt(onExit: exit, …)` |
| duel | duelScreen: kid img/name, onExit → /map | 1020-1025 | features/room/duel.dart:79+, 265, 293 | OK | |
| rest | Phrase rest, Sleeping face, restTitle/restText, milk, "⏱️ moreTime" → gate → addBonus(10) → /map | 1028-1039 | home/rest_screen.dart:16-53 | OK | |
| review | revIndex reverse lookup from voice templates, itemOf, skillOfSet, itemKeys, confNs, recordQ conf pairs | 1063-1128 | core/game/learn_tracking.dart:84-160 | OK | |
| review | wordQ (tone confusions first, variants, same onset/rime others, toneFocus) | 1319-1329 | learn/language/review.dart:55-72 | OK | |
| review | reviewQ for letters / tone / vnwords / twoWords / sentences / ruleWords / facts (near()) / en_* | 1330-1371 | learn/language/review.dart:34-167 | OK | |
| review | REVIEWABLE + dueCount | 1372-1373 | core/game/learn_tracking.dart:244-249 | OK | |
| review | reviewPlay keys (x / all / due, max 8), up to 3 rounds until ≥ min(5, keys*3), shuffle → 8 | 1376-1404 | learn/language/review.dart:194-224 | OK | |
| review | No items → reviewNone + "Không có gì cần ôn!" + map | 1397-1403 | learn/language/review.dart:219-222,286-303 | OK | |
| review | record: key of question, tone adds vnwords:<id>, ns null for tone | 1408-1414 | learn/language/review.dart:263-276 | OK | Uses progress index → question key (quiz calls progress before record) |
| review | Done: recordReview, +1 ticket (fun on), milestones, left count, win + confetti + reviewDone, "🔁 Ôn xong!" stars, ticket prize, left note, Map / "🔁 Ôn tiếp", celebrate after 1400ms | 1416-1437 | learn/language/review.dart:305-354,441-476 | PARTIAL | (1) "Ôn tiếp" rebuilds without overLimit check (see router row). (2) Celebrate after 1400ms is gated on the screen being mounted, not the result panel: if the child taps "Ôn tiếp" within 1.4s the milestone overlay pops over the new quiz (web checks `ov.isConnected`). Fix: pass a panel-mounted callback like finish_round.dart:82-86 |
| review | Topbar back → /map, progress, "🔁 Ôn bài" pill, buddy, photo mode | 1381-1389 | learn/language/review.dart:356-409 | OK | |
| report | days (7, 'Nay', WD), week sums, summary sentence, hero (tier · ⭐ · 🔥), goal, tiles today / 7 days | 1512-1539 | parents/report.dart:58-77,287-366 | OK | |
| report | 7-day chart (minutes bar, lessons below), note | 1540-1546 | parents/report.dart:~373-420 | OK | |
| report | skillRows (letters, spell + tone weak list, read, math f10/f20/f100, english total, other islands % + s/q) | 1441-1479 | parents/report.dart:79-178 | OK | |
| report | weakList (merge pairs, n ≥ 2, top 6, + due items 10), chips → /review/x/<key> (setActive), "▶ Luyện lại cho …" → /review/all, notes | 1480-1504, 1557-1568 | parents/report.dart:180-225, ~434-481 | OK | |
| report | nextGoal | 1505-1510 | parents/report.dart:227-244 | OK | |
| report | Milestones list sorted by date desc → certificate(parent=true); empty note | 1524, 1569-1573 | parents/report.dart:247-258, ~487-520 | OK | |
| report | Unknown kid → /parent | 1514 | parents/report.dart:281-286 | OK | |
| cert | certificate overlay: phrase cert, card (medal, BẰNG KHEN, to-line, name, dressed kid + pic, text, date, stars, seal), "Hiện tên bé trên ảnh" checkbox, Close, "📤 Khoe với người thân" (gate unless parent) | 1278-1306 | parents/certificate.dart:167-260 | OK | Preview hides the name when unchecked (web preview always shows it; only the image changes) and the "Bé Vui Học" seal is not drawn on the preview — cosmetic |
| cert | certImage 1080×1350 PNG (same coordinates/texts/fonts) | 1213-1245 | parents/certificate.dart:80-142 | OK | |
| cert | shareImage: share sheet with file + text; desktop download + clipboard | 1247-1257 | parents/certificate.dart:145-163 | OK | Falls back to text-only share if PNG fails (web toasts) — fine |
| mic | Mic consent (bvh.micOK) asked once with gate; parent reset button | read.js:173-193; app.js:808-811 | learn/language/read.dart:669-781; parents/parents.dart:282-288 | OK | |
| photo | setPhotoMode / photoOf / unifyPhotos / watchStage (wait for images, 4s → cartoon) | ui.js:17-90 | core/ui/emoji_image.dart:22-75 | OK | Assets are local so no network wait; error → cartoon fallback; groupUsesPhotos replaces unifyPhotos |
| keyboard | Only keydown in app.js: Enter on name input → step 2 | 289 | home/new_kid_screen.dart:107-109 | OK | Game key handlers (funhunt, rpg) are outside this file's scope |
| ui | toast (2.4s), overlay panel, confetti(n) | ui.js:97-121 | core/ui/overlay.dart:21-200 | OK | |
