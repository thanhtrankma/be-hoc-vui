> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Learn-island games — web vs Flutter parity audit

Scope: reference/web/js/games/{pick,quiz,sheets,spell,trace,read,count,math,life,memory,explore,music,logic,code,art,figure}.js
vs lib/features/learn/{language,math,creative}/*.dart + lib/core/game/registry.dart.
Level data: assets/data/app.json islands × assets/data/content.json (key resolved like app.js levelsOf():
letters→letterLevels, english→englishLevels, else LEVEL_KEY[game]). (Script tạm lúc kiểm tra; kiểm tra tự động tương đương: test/parity/levels_render_test.dart.)

## 1. Registry
| island | game | levels key | n | Dart module | status |
|---|---|---|---|---|---|
| letters | pick | letterLevels | 32 | pickModule (registry.dart:42) → letterQuestions | OK |
| english | pick | englishLevels | 34 | pickModule → englishQuestions (islandId=='english') | OK |
| spell | spell | spellLevels | 247 | spellModule | OK |
| trace | trace | traceLevels | 28 | traceModule | OK |
| read | read | readLevels | 105 | readModule | OK |
| count | count | countLevels | 19 | countModule | OK |
| math | math | mathLevels | 48 | mathModule | OK |
| life | life | lifeLevels | 10 | lifeModule | OK |
| memory | memory | memoryLevels | 14 | memoryModule | OK |
| logic | logic | logicLevels | 25 | logicModule | OK |
| code | code | codeLevels | 20 | codeModule | OK |
| music | music | musicLevels | 7 | musicModule | OK |
| art | art | artLevels | 7 | artModule | OK |
| explore | explore | exploreLevels | 41 | exploreModule | OK |
| arcade | arcade | arcadeLevels | 10 | arcadeModule (agent E, fun/hub) | out of scope (kinds balloon/race listed below for completeness) |

## 2. Level-signature table (distinct discriminator + sorted key set per island)
| island | kind/mode | key set | level indices | Dart dispatch |
|---|---|---|---|---|
| letters | (none) | extra,name,targets,tier | 0-8 | pick.dart:82 default (findLetter) |
| letters | initial | choices,kind,name,targets,tier | 9,10,11,15 | pick.dart:65 |
| letters | upper | choices,kind,name,targets,tier | 12,13,14,16 | pick.dart:82 (upper=true) |
| letters | (none, lop1) | choices,extra,hide,kid,kntt,name,targets,tier | 17-31 | pick.dart:82 default |
| english | (none) | img,name,set,tier,tpl (tpl∈findEn,findEnA,findEnThe,showMe; 34 en_* sets, all items have id) | 0-33 | pick.dart:104 |
| spell | tone | choices,kind,name,tier,tones (+pool / +hide,kid,know,kntt,words) | 0-2,7,51,55,57,61,69,91 | spell.dart:473 |
| spell | onset | choices,kind,name,tier (+pool / +hide,kid,know,kntt,words) | 3,8,49,59,… | spell.dart:474 |
| spell | rime | choices,kind,name,tier (+pool / +hide,kid,know,kntt,tones,words) | 4,9,101,104,… | spell.dart:475 |
| spell | build | choices,kind,name,tier (+pool / +pool,rimes / +lop1 words) | 5,10,12,22…40(even),44,54,… | spell.dart:476 |
| spell | listen | choices,kind,name,tier (+pool / +pool,rimes / +lop1 words) | 6,11,13,23…41(odd),50,… | spell.dart:477 |
| spell | readword | choices,kind,name,tier (+hard) | 14,16,45 | spell.dart:478 |
| spell | sentence | kind,max,name,tier | 15,17,48 | spell.dart:479 |
| spell | rule | grp,kind,name,tier (grp ck/g/qu) | 18,19,42,43 | spell.dart:480 |
| spell | readsent | choices,kind,name,tier | 20,47 | spell.dart:481 |
| spell | cloze | choices,kind,name,tier | 21,46 | spell.dart:482 |
| trace | (none) | chars,name,tier (+hide,kid,kntt) | 0-27 (39 distinct chars, all in kGlyphs) | trace.dart TraceView |
| read | story | img,kind,name,story,tier | 0,1,3,4,6,7,9-14,17-41 | read.dart:33 default → StoryView |
| read | dictation | img,kind,name,tier,tones (+pool / +pool,rimes / +hide,kid,know,kntt,words) | 2,5,15,16,42-104 | read.dart:31 |
| read | aloud | img,kind,name,tier | 8 | read.dart:32 |
| count | (none) | choices,max,min,name,tier (+tens / +round,tens) | 0-18 | count.dart countQuestions |
| math | add | kind,max,name,pics,tier (+min) | 0,2,9,29,34,36,38,41,45 | math.dart:47 |
| math | sub | kind,max,name,pics,tier (+min) | 1,3,10,30,35,37,39,42,46 | math.dart:48 |
| math | cmp | kind,max,name,tier | 4,33 | math.dart:50 |
| math | tens | kind,name,tier | 5 | math.dart:51 |
| math | mix | kind,max,name,(pics),tier (+min) | 6,11,31,40,43 | math.dart:49 |
| math | clock | kind,name,tier | 7 | math.dart:52 |
| math | shape | kind,name,tier | 8 | math.dart:53 |
| math | blocks/next/cmp100/add100/sub100 | kind,name,tier | 12/13/14/15/16 | math.dart:42-46 |
| math | missing | kind,max,name,tier | 17,18,32,44 | math.dart:37 |
| math | word | kind,max,name,tier | 19,20,47 | math.dart:38 |
| math | chain/add2d/sub2d/position/seqnum/cmpexpr | kind,name,tier | 21/22/23/24/27/28 | math.dart:33-41 |
| math | maxmin | kind,max,name,tier | 25,26 | math.dart:34 |
| life | shop | img,kind,name,tier,types | 0,4,9 | life.dart:25 |
| life | length / height / clips / ruler | img,kind,name,tier | 1 / 6 / 5 / 7 | life.dart:29 → _LifeQuiz (63-67) |
| life | weight / week / calendar | img,kind,name,tier | 2 / 3 / 8 | life.dart:26-28 |
| memory | (none) | cols,name,pairs,tier (+theme) | 0-4 / 5-13 | memory.dart:52 |
| logic | shadow / odd / pattern | choices… / patterns | 0,6,22 / 2,19 / 1,5,17,23 | logic.dart:27→_LogicQuiz (56-84) |
| logic | maze | kind,name,size,tier | 3,7,9,24 | logic.dart:28 |
| logic | sudoku | blanks,kind,name,tier | 4,8 | logic.dart:29 |
| logic | jigsaw | kind,name,page,pieces,tier (+rows) | 10,13,16,18,20 | logic.dart:30 |
| logic | seq | kind,name,sets,tier | 11,14 | logic.dart:31 |
| logic | spot | diffs,kind,name,page,tier | 12,15,21 | logic.dart:32 |
| code | garden | cmds,img,k,kind,max,min,n,name,rocks,spare,tier (+detour / +say / +jump,say) | 0,1,2,5,6,7,17 | code.dart:239 genGarden |
| code | trace | cmds,img,kind,max,min,n,name,tier (+loops:true) | 3,8,15 | code.dart _runTrace / genTrace |
| code | debug | cmds,img,k,kind,max,min,n,name,rocks,spare,tier / cmds,…,loops | 4,9,18 / 16 | genDebug |
| code | loop | cmds,img,kind,loops,n,name,rocks,spare,tier (+hint) | 10-14,19 | genLoop |
| music | free / song / simon | img,kind,name,tier / +song / +goal | 0 / 1,3,4,6 / 2,5 | music.dart:22-31 |
| art | draw / color | img,kind,name,tier / +page | 0 / 1-6 | art.dart:27-28 |
| explore | (none) | img,name,set,tier (41 sets, all exist in sortSets) | 0-40 | explore.dart |
| arcade | balloon(letters/numbers/tones/english), race(add/sub/mix) | img,kind,mode,name,tier (+max) | 0-9 | agent E — not audited |

Data integrity checks (all pass): every story/sortSet/sequence/song id referenced by levels exists; memItems has ≥11 items per theme (max pairs 10); ruleWords grps {ck,g,qu} cover rule levels; story question shapes ∈ {img,color,text}; all vnwords/twoWords/sentences/en_* items have `id`.

## 3. Feature checklist
| island/game | feature/kind | web ref | flutter ref | status | note |
|---|---|---|---|---|---|
| letters/pick | default find-letter | pick.js:42-46 | pick.dart:82-94 | OK | |
| letters/pick | kind initial (picture → first letter, letterWord2 reward) | pick.js:26-33 | pick.dart:65-79 | OK | |
| letters/pick | kind upper (uppercase label, labelCls upper) | pick.js:35-41 | pick.dart:82-94 | OK | |
| letters/pick | choices n = lv.choices ‖ (li<2?3:4); targets 'all'; pool=targets+extra | pick.js:21-24 | pick.dart:58-62 | OK | |
| letters/pick | wordFor: random letterWords, fallback letters+letterWord tpl | pick.js:10-15 | pick.dart:37-48 | OK | |
| letters/pick | lop1 fields kid/kntt/hide | data only | — | OMITTED-OK | consumed by class plan / level list, not by game |
| english/pick | set+tpl prompt, label=prompt text, 3 distractors, wordEn reward | pick.js:55-67 | pick.dart:104-121 | OK | |
| english/pick | face img / color swatch / digit | pick.js:49-53 | pick.dart:98-102,123-132 | OK | Dart adds `en` text fallback when no digit (harmless) |
| quiz | ROUND 8, sequence() no adjacent repeat | quiz.js:16-25 | quiz.dart:29, utils.dart:49 | OK | |
| quiz | starsFor 0→3, ≤2→2, else 1 | quiz.js:14 | quiz.dart:32 | OK | |
| quiz | intro phrase → wait 350 → speak unless already tapped | quiz.js:98-104 | quiz.dart:414-420 | OK | |
| quiz | prompt button 🔊 re-speak, saying pulse | quiz.js:42-49 | quiz.dart:423-436,669+ | OK | |
| quiz | right answer: record(q,picks,ms), correct sfx, cheer, stopVoice, streak, combo≥3 (power at 3/5/8/10, 1.4 s) | quiz.js:58-64,7-12 | quiz.dart:476-487,543-551 | OK | |
| quiz | onRight hook, pickReward({missed,streak}), reward card tap-to-skip, min 1100 / no-node 400|650 | quiz.js:65-79 | quiz.dart:488-506,553-557 | OK | |
| quiz | timed reward anim (clipDuration of first line) | quiz.js:74 | quiz.dart:494-499 | OK | |
| quiz | wrong answer: mistakes++, picks.push, wrong sfx, sad, await retry(), re-speak | quiz.js:81-90 | quiz.dart:527-540 | PARTIAL | Dart ignores taps on a card already marked wrong (`wrong.contains(c.id)` guard, quiz.dart:474). Web lets the kid tap the same wrong card again → another mistake, another retry voice. Affects star scoring (web harsher). Decide: keep (kinder) or drop the guard to match web |
| quiz | preload say/reward/preload lines | quiz.js:33 | quiz.dart:398 | OK | |
| sheets | loadSheet/frameAt/drawFrame/drawAnim | sheets.js | core/ui/sprite_sheet.dart (re-exported by language/sheets.dart) | OK | core-owned; not deep-diffed |
| spell | kind tone (pool∩tones, extra tones fill, cols n>4?3:n) | spell.js:93-106 | spell.dart:233-252 | OK | |
| spell | kind onset (TWINS ban, know.c restricts, fewer choices if few known) | spell.js:108-134 | spell.dart:254-294 | OK | |
| spell | kind rime (rimeChoices sameV/sameT, near rimes, know.v/t) | spell.js:116-143 | spell.dart:264-307 | PARTIAL | Dart dedups (Set) and tops up from sameT to max(n,3); web may show fewer cards (e.g. know.t has 1–2 tones so sameV short) or a duplicate. Minor behavioral difference (card count) |
| spell | kind build (2 steps: onset then rime, step 2 says vnSay, always fastSpell) | spell.js:146-162 | spell.dart:310-331 | OK | |
| spell | kind listen (spell voice, 🔤 label, picture distractors w/ confuse groups, wordPraise) | spell.js:166-184 | spell.dart:335-371 | OK | |
| spell | kind readword (+hard shared-syllable distractors) | spell.js:187-199 | spell.dart:374-392 | OK | |
| spell | kind sentence (max≥5 → 4 long sentences else 5 short, word-by-word) | spell.js:202-215 | spell.dart:401-418 | OK | |
| spell | kind rule (ruleWords by grp, 2 choices) | spell.js:218-224 | spell.dart:421-432 | OK | |
| spell | kind readsent | spell.js:227-234 | spell.dart:435-446 | OK | |
| spell | kind cloze (blank ≠ first word, lowercase pool) | spell.js:237-251 | spell.dart:449-469 | OK | |
| spell | intro per kind (KINDS table) | spell.js:253 | spell.dart:28-39 | OK | |
| spell | runQuiz opts combo + minReward 800 | spell.js:262 | spell.dart:55 | OK | |
| spell | fly chip into first blank, merge pop | spell.js:72-91,261 | quiz.dart:438-471 (options.fly) | OK | |
| spell | reward policy fastSpell (missed / odd streak / build) else wordPraise; spell card lit by BEATS | spell.js:42-69 | spell.dart:103-229 | OK | |
| spell | lop1 `words`/`know` pools | spell.js:33-34 | spell.dart:75-93 | OK | |
| trace | 39 glyphs, compile arcs ≤90°, E ellipse | trace.js:13-83 | trace.dart:33-428 | OK | glyph keys identical; all data chars covered |
| trace | TOL 15, LOOK 14, STEP 2, start within 1.7·TOL, stroke done at samples-3 | trace.js:87,127-146 | trace.dart:431,586-620 | OK | |
| trace | wrong start → pop sfx + dot hint blink | trace.js:147 | trace.dart:617-618,686 | OK | |
| trace | stroke complete → star sfx; stroke number label when >1 | trace.js:122,138 | trace.dart:597,663 | OK | |
| trace | voice writeLetter/writeNum; done voice letterWord/num; reward card + 1200 ms | trace.js:160-177 | trace.dart:474-510 | OK | |
| trace | traceIntro before first char | trace.js:164 | trace.dart:496-498 | PARTIAL | cosmetic: web shows nothing until intro ends; Dart already shows the board (kid can trace during intro). No scoring impact |
| trace | hideBuddy, stars always 3 | trace.js:163,180 | trace.dart:490,510 | OK | |
| read | dispatch dictation / aloud / default story | read.js:250-256 | read.dart:28-36 | OK | |
| read/story | per-line read with word highlight timing (weights len+2(+4 punct), ×0.96) | read.js:26-45 | read.dart:188-223 | OK | |
| read/story | tap word → storyWord voice | read.js:19 | read.dart:339 | OK | |
| read/story | title read on page 0, "again" re-read, "next" enabled after first read, flip sfx | read.js:54-75 | read.dart:169-244,310-311 | OK | |
| read/story | comprehension quiz (img / color / text, praise, storyQ intro, progress offset) | read.js:78-87 | read.dart:246-281 | OK | |
| read/dictation | 6 words, dictIntro, c→v→t keys, know filter, 11 rime distractors (+rimes if pool) | read.js:96-136 | read.dart:381-457 | OK | |
| read/dictation | check: bad slots 900 ms, wrong parts reset (wrong v also clears t), re-say word; tap slot to clear | read.js:137-162 | read.dart:459-511 | OK | |
| read/dictation | stars starsFor(max(0,mistakes-1)) | read.js:167 | read.dart:475 | OK | |
| read/aloud | intro aloudIntro vs aloudParent; parent ✔ / 🔊 / skip; stars 3 | read.js:196-246 | read.dart:711-751,868-871 | OK | |
| read/aloud | mic consent overlay once + parent gate + bvh.micOK | read.js:173-192 | read.dart:759-783 | OK | text adapted to Android/iOS |
| read/aloud | speech recognition vi-VN, alternates, normalized word match, wrong → status+wrong sfx+aloudTry, error → micNA | read.js:226-241 | read.dart:785-829,624-664 | OK | speech_to_text plugin |
| read/aloud | no-recognizer device handling | read.js:198-206 | read.dart:697,726 | PARTIAL | Web: no SpeechRecognition → useMic false → intro 'aloudParent', no mic button, status t('micNA'). Dart: useMic = pref!='0' only → plays 'aloudIntro', shows mic; micNA only after a tap when init() fails, and mic stays visible. Fix: probe `rec.init()` (or SpeechToText.hasPermission/isAvailable) before intro; if unavailable treat as !useMic with status micNA |
| count | range min..max (round → multiples of 10), 6 picks no adjacent repeat | count.js:53-61 | count.dart:31-40 | OK | |
| count | things filter !big when max>10 | count.js:62 | count.dart:41-42 | OK | |
| count | distractors (±1/±2, tens ±1/±10, round ±10/±20), bound rule | count.js:68-70 | count.dart:52-56 | OK | |
| count | tap-to-count board (number tags, count sfx, say number/n100) | count.js:12-28 | count.dart:92-170 | OK | |
| count | tens board: bar=+10, singles blocked until all bars (wrong sfx + hint), total badge | count.js:31-51 | count.dart:173-284 | OK | |
| count | reward countAnswer(≤10) / n100 | count.js:75-76 | count.dart:63-68 | OK | |
| math | add/sub (facts filter max/min, pics groups, crossed-out for sub, near(c,4,0,max(10,max))) | math.js:33-53 | math.dart:84-120 | OK | |
| math | mix (4 add + 4 sub, no pics) | math.js:55-59 | math.dart:122-125 | OK | |
| math | cmp (2 equal + 6 unequal, cmpQ, cmpA) | math.js:61-80 | math.dart:127-160 | OK | |
| math | tens (ten-frames 11-20) | math.js:86-95 | math.dart:162-174 | OK | |
| math | clock (hour hand, 3 choices "n giờ") | math.js:97-118 | math.dart:176-191 | OK | label localized via mt('hour') |
| math | shape (random fill/rotation, all shapes as choices) | math.js:120-141 | math.dart:193-215 | OK | |
| math | blocks / next / cmp100 / add100 / sub100 | math.js:144-208 | math.dart:220-307 | OK | near100 identical (common.dart:68) |
| math | missing / word / chain / add2d / sub2d | math.js:211-262 | math.dart:310-388 | OK | |
| math | position / maxmin / seqnum / cmpexpr | math.js:265-321 | math.dart:391-454 | OK | |
| math | intro mathIntro (add/sub), wordIntro (word) | math.js:334 | math.dart:70-72 | OK | unknown kind falls back to add≤5 (web would throw) |
| life | shop: 5 rounds, types items ×1-5, order voice, shelf 4, basket add/remove, deliver check (exact counts, no extras), shopThanks / shopWrong, starsFor | life.js:13-61 | life.dart:347-540 | OK | |
| life | length (6 q, longest/shortest pencils, lifeIntro) | life.js:74-86 | life.dart:70-92 | PARTIAL | layout only: web `cols:1` horizontal pencils stacked in one column; Dart cols:3 with pencils rotated vertical side-by-side. Logic/scoring same |
| life | height (towers, tallest/lowest) | life.js:92-104 | life.dart:94-111 | OK | |
| life | weight (scale tilts, wrong = mistake but round still ends after weightA + 600 ms) | life.js:116-149 | life.dart:551-615 | OK | Dart adds busy guard (web allowed double tap) |
| life | clips (pencil + n clips, n±1) | life.js:156-167 | life.dart:113-133 | OK | |
| life | ruler (pencil on 12-cm ruler, 3 options in cm) | life.js:180-192 | life.dart:135-157 | OK | |
| life | week (tomorrow/yesterday alternating, dayName on tap, wrong shake no retry voice, 1300 ms) | life.js:195-220 | life.dart:718-800 | OK | |
| life | calendar (current month, Monday-first, 5 targets, findDate, dateIs + isDay, weekday header highlight) | life.js:223-262 | life.dart:826-977 | OK | |
| life | hideBuddy for shop & calendar | life.js:269,276 | life.dart:370,848 | OK | |
| memory | pool theme→memItems else words; pairs; voice wordEn/wordVi by lang | memory.js:9-14 | memory.dart:46-57 | OK | |
| memory | flip, match after 450 ms, mismatch close after 1000 ms, finish after 900 ms | memory.js:23-49 | memory.dart:63-94 | OK | |
| memory | stars misses≤pairs 3, ≤2·pairs 2, else 1 | memory.js:42 | memory.dart:27 | OK | |
| explore | 4 A + 4 B items, exploreIntro then say both basket names | explore.js:11-28 | explore.dart:53-70 | OK | |
| explore | drag to basket or tap basket; tap card (no move) re-says name | explore.js:37-81 | explore.dart:127-160 | OK | |
| explore | wrong → mistake, shake, retry voice; right → fly into bin 350 ms | explore.js:39-55 | explore.dart:92-115 | OK | |
| explore | closing fact card (exploreFact) 1500 ms; starsFor | explore.js:86-93 | explore.dart:80-89 | OK | basket label uses L(d) (vi fallback; data has no en) |
| music | free: 8 taps enable Done, stars 3 | music.js:25-33 | music.dart:207-245 | OK | |
| music | song: next key lit, wrong key nope, listen demo 420 ms, stars ≤3/≤8 | music.js:35-75 | music.dart:280-335,45 | OK | |
| music | simon: pads 0/2/4/7, flash 380+140, replay after 700 on miss, simonMore at len 3, goal, starsFor | music.js:78-122 | music.dart:342-440 | OK | |
| music | hideBuddy all kinds | music.js:128 | music.dart:181-196,368 | OK | |
| logic | shadow (silhouette, photo:false) | logic.js:11-22 | logic.dart:57-62,108-119 | OK | |
| logic | pattern (patterns, shown 2..3 cycles, 3 choices) | logic.js:24-43 | logic.dart:63-77,120-130 | OK | |
| logic | odd | logic.js:45-55 | logic.dart:79-83,131-139 | OK | |
| logic | maze DFS, drag/tap adjacent cells, backtrack trail, pop on blocked tap, star goal, buddy sprite, stars 3 | logic.js:58-136 | logic.dart:198-300 | OK | |
| logic | sudoku 4×4 animals, blanks, auto-select first empty, starsFor | logic.js:139-190 | logic.dart:367-530 | OK | |
| logic | jigsaw (page ghost, cols×rows, drag or tap-select-tap-slot, mistakes, starsFor(m-1)) | logic.js:193-247 | logic.dart:532-713 | OK | |
| logic | seq (tap to next slot, tap back to tray, check, seqWrong, wrong cards return) | logic.js:250-296 | logic.dart:715-835 | OK | |
| logic | spot (diffs on regions ≥2, small → hidden 50%, else recolor; rings; bg taps free; starsFor(m-2)) | logic.js:299-343 | logic.dart:910-1000 | OK | |
| logic | voice prompts mazeQ/sudokuQ/jigsawQ/spotQ; hideBuddy jigsaw/spot | logic.js:349-353 | logic.dart:224,400,556-558,955-957 | OK | |
| code | engine simulate/shortest(BFS)/genGarden/genLoop/genDebug/genTrace/walkEmpty/LOOPS/mirror | code.js:36-224 | code_engine.dart:39-382 | OK | line-by-line equivalent; detour null-guard added |
| code | board (rocks, logs, sprouts→flowers, robot BOT shirt, heading arrow for relative cmds) | code.js:227-282 | code.dart:123-232 | OK | |
| code | play animation (bump 550, move/turn 440, jump 560, water coin / splash pop) | code.js:285-304 | code.dart:180-230 | OK | |
| code | editor: edit (remove card, REP block target, ×rep chip 2..6 + codeRepN, kill block, cap meter + codeFull), fix (select & replace, no REP), view | code.js:308-375 | code.dart:362-471,600-800 | OK | |
| code | puzzles: 3 per level, first-say lv.say‖codeLoopQ/codeDebugQ/codeGardenQ, hint REP block, codeBump/codeMissed, debug hint after 2 fails (2.4 s), stars fails≤1/≤4 | code.js:378-427 | code.dart:236-310 | OK | |
| code | trace: 5 q, tap cell guess, play, codeTraceWrong + show true end, stars 0/≤2 | code.js:430-466 | code.dart:313-357 | OK | |
| art | color page: 6 pages (region counts 16/15/16/16/12/13 match), tap fill, palette 15, Done requires ≥50% regions (colorMore), artIntro/artDone, stars 3 | art.js:10-130 | art.dart:100-178,410-497 | OK | |
| art | free draw: palette + rainbow (hue+6) + eraser (×2.5), sizes 6/12/24, 12 stamps (70+size·2), undo 15, clear, Done after 3 strokes | art.js:181-247 | art.dart:499-700 | OK | |
| art | save: web downloads PNG (1200×900 page / canvas) | art.js:162-178 | art.dart:265-317 | OMITTED-OK | platform adaptation: PNG saved to app documents + 'bvh.art' list + toast |
| art | pageSvg/PRESET exported for logic jigsaw/spot | art.js:39-65 | art.dart PagePainter/pageRegions/kPreset | OK | |
| figure | COSTUMES / costumeOf / LOOK_* / setPlayer / lookOf / heroOf / BOT / DAD / FRIENDS | figure.js:25-65 | figure.dart:24-115 | OK | |
| figure | hat mapping OLD_HATS/HATS, bases, pet sheet/tint | figure.js:67-71 | figure.dart:117-128 | OK | |
| figure | baseOf legacy flags c.robot / c.long / c.dress | figure.js:124 | figure.dart:204 | OMITTED-OK | Costume has no such fields; no data/callers use them |
| figure | shade-based recolor variant | figure.js:93-122 | figure.dart:169-192 | OK | |
| figure | frameFor poses (17 + default) / drawFigure (shadow, bob, lift, noHead clip, hat, weapon) / drawHead / petBuddy | figure.js:139-243 | figure.dart:236-446 | OK | Dart adds placeholder drawing when sheets not loaded |
| figure | figureEl / petEl DOM canvases | figure.js:245-279 | figure.dart FigureView/FigureController/PetView 449-660 | OK | |

## 4. Totals (feature checklist §3 only)
OK 105 · PARTIAL 5 · MISSING 0 · OMITTED-OK 3. Every (island, kind) in the data has a matching Dart dispatch branch (§2).
