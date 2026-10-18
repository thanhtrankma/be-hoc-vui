> **Bảng kiểm chi tiết (tiếng Anh) — trạng thái lúc kiểm tra, TRƯỚC khi sửa.** Các dòng PARTIAL/MISSING đã sửa được liệt kê ở `docs/QA_FEATURES.md` mục 4. Số dòng Flutter có thể lệch vài dòng sau khi sửa.

# Feature parity audit: store.js / sync.js / audio.js -> Flutter core

Web root: web js/. Dart: lib/. Statuses: OK, PARTIAL, MISSING, OMITTED-OK.
Mechanical sfx/clip scan: kiểm tra tự động tương đương ở test/parity/web_sources_test.dart (results summarized in section E).

## A. Store: state, keys, settings, profiles

| area | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|
| store | localStorage key `bvh.v1`, state shape {profiles, active, settings, gone, smt} | store.js:3,7-13 | store.dart:16,45-62 | OK | same shape and same corrupt-data fallback |
| store | DEFAULTS {lang:'vi', music:true, sound:true, limit:20, fun:true, ticketsPer:1, lockOrder:false} | store.js:4 | store.dart:19-21 | OK | identical |
| store | save(): stamps `mt` on the active profile, rawSave, onSave hook | store.js:18-26 | store.dart:64-77 | OK | also notifyListeners |
| store | persist() (navigator.storage.persist) | store.js:28-30 | - | OMITTED-OK | browser-only; SharedPreferences is persistent anyway |
| store | settings()/setSetting(k,v) sets smt=now | store.js:32-33 | store.dart:102-107 | OK | typed getters added (store.dart:109-115) |
| store | profiles()/profile()/setActive (rawSave, no mt) | store.js:35-37 | store.dart:118-139 | OK | |
| store | addProfile id = base36(now)+4 random base36 chars; fields stars 0, rounds 0, stickers[], levels{}, usage{}, bonus{}, created | store.js:39-46 | store.dart:141-151 | OK | Dart random part is nextInt(2^20) in base36, padded to 4 chars (smaller space than web's ~36^4, still fine) |
| store | updateProfile: assign fields + mt=now, save | store.js:48-51 | store.dart:153-159 | OK | |
| store | removeProfile: drops it, gone[id]=now, active falls back to first | store.js:53-58 | store.dart:161-166 | OK | |
| store | other localStorage keys: bvh.sync, bvh.micOK, bvh.src, bvh.ref, bvh.act, bvh.cafe; sessionStorage bvh.route, bvh.noinstall, bvh.reloaded | sync.js:7; read.js:173; app.js:128-206,1044-1054,1586-1649 | store.dart:83-99 getKv/setKv | OK | getKv/setKv cover bvh.sync and bvh.micOK. src/ref/act/cafe/route/noinstall/reloaded are web-only (analytics/PWA/reload) and out of this scope |
| profile | Profile fields (id,name,mascot,stars,rounds,spent,tier,stickers,owned,badges,levels,usage,bonus,outfit,best,funLevel,gear,pet,look,streak) | store.js (various) | profile.dart:11-68 | OK | Note: the `_map`/`_strList` getters write an empty {} or [] into JSON when a key is missing (e.g. reading `p.best` adds `best:{}`). The format stays compatible, but two devices' JSON may differ by empty keys, so mergeRemote sees a change and saves (harmless) |
| stars | levelStars key `"island:i"` | store.js:60 | store.dart:168 | OK | |
| stars | recordRound: levels max, stars+=, rounds+=1, logDay(1,stars), random new sticker from pool | store.js:63-75 | store.dart:172-185 | OK | Dart has a null-profile guard |
| usage | dayKey YYYY-MM-DD local; today() | store.js:78-79 | store.dart:188-189 | OK | |
| usage | addUsage(sec): usage[today]+=, keep last 60 days | store.js:81-89 | store.dart:191-201 | OK | |
| usage | overLimit: limit 0 = unlimited; usage[d] >= (limit+bonus[d])*60 | store.js:92-98 | store.dart:204-210 | OK | |
| usage | addBonus(min): bonus = {today: old+min} (drops older days) | store.js:100-107 | store.dart:212-218 | OK | |
| usage | 15 s ticker: only when started, visible, kid active, route not in ['', kids,new,parent,report,rest]; overLimit and not play -> /rest | app.js:1613-1618 | app.dart:33-41; app_router.dart:49-51 | OK | |
| backup | exportData {app:'be-vui-hoc', version:1, exported ISO, data:S} | store.js:109-111 | store.dart:220-221 | OK | Dart ISO string can carry microseconds (".123456Z"); import ignores the field |
| backup | importData: check app tag + profiles[]; S=data, gone={}, smt=now; rawSave + onSave (no mt stamp) | store.js:113-121 | store.dart:224-239 | OK | throws FormatException instead of Error; `active` uses `??` instead of `||` (only differs for an empty-string active) |
| wallet | wallet = stars - spent | store.js:124 | store.dart:242 | OK | |
| wallet | buy(item): price check, spent+=, owned+=id, equip(slot,id) | store.js:125-132 | store.dart:243-250 | OK | |
| wallet | equip(slot,id): falsy id deletes slot | store.js:133-138 | store.dart:252-259 | OK | Dart deletes only for null (web also for ''); callers pass null |
| daily | seeded(str) FNV-1a + murmur-style mixer | store.js:141-145 | store.dart:556-568 | OK | 32-bit imul emulated with &0xFFFFFFFF; same sequence |
| daily | daily(ids): new per day, seeded(today+p.id), 3 tasks picked by splice | store.js:146-158 | store.dart:268-283 (+peekDaily 263-266) | OK | |
| daily | dailyProgress: marks task; when all done claimed=true, streak (yesterday -> +1, today -> same, else 1), +5 stars | store.js:160-173 | store.dart:286-307 | OK | |
| daily | reward on round end: tickets ticketsPer + (dailyDone ? 2 : 0), prize line "+5 ⭐", phrase 'dailyDone' | app.js:568-616 | finish_round.dart:37,46-47,89-102 | OK | |
| badges | newBadges(earned) stores fresh ids | store.js:176-182 | store.dart:310-320 | OK | |
| badges | BADGES thresholds: first r>=1, r10, r50, s100, s300, streak3, streak7, abc/writer/math/reader allDone, stickers>=15, explorer (all game islands level 0), fashion owned>=3 | app.js:88-103 | learn_tracking.dart:55-70,252-274 | OK | same ids, images, text and tests |
| tickets | tickets(p) = p.tickets ?? 2 (no daily refill exists in web) | store.js:185 | store.dart:323 | OK | web has no daily refill; the only sources are the default 2, per-lesson ticketsPer, daily +2, review +1, lop1 lesson +3, parent "give" +3 |
| tickets | addTickets / useTicket (false at 0) | store.js:186-198 | store.dart:324-337 | OK | |
| tickets | review +1, lop1 lesson done +3, parent give +3 | app.js:1420, 449, 764 | review.dart:314; class_plan.dart:114; settings.dart:18-22 | OK | |
| records | saveBest(game,score) -> isNew; always saves | store.js:199-206 | store.dart:340-347 | OK | |
| fun | FUN_MAX 60; funLevel = min(59, funLevel[id]); funLevelUp | store.js:209-215 | store.dart:24,349-355 | OK | |
| gear | gear(p,id) / saveGear(id,data) (null data ignored) | store.js:219-225 | store.dart:358-364 | OK | |
| learn | dayNum = local-day number | store.js:234 | store.dart:369-372 | OK | getTimezoneOffset sign handled correctly |
| learn | GAPS [0,1,3,7,14,30] (not 1/3/7): next = now + GAPS[min(streak,5)]; wrong -> streak 0, due now | store.js:235,263-264 | store.dart:374,415-423 | OK | |
| learn | mastered = streak>=1 && ok>wrong; first mastery sets it[4]=1, days[4]++ | store.js:236,265 | store.dart:375,424-428 | OK | |
| learn | learn(p) ensures items/conf/skills/days/ms/msAt | store.js:237-241 | store.dart:377-384 | OK | |
| learn | logDay [rounds,stars,ok,wrong,newMastered], keep 60 days | store.js:242-249 | store.dart:386-396 | OK | |
| learn | recordAnswer: skills [ok,wrong,ms<=60000], conf counts capped at 80 (drops lowest) | store.js:252-272 | store.dart:400-442 | OK | Dart List.sort is not stable, so among equal counts a different key may be dropped than in JS. Negligible |
| learn | dueItems: wrong>0 && streak<5 && (all ? streak<2 \|\| due<=now : due<=now); sort due asc then (wrong-ok) desc | store.js:274-278 | store.dart:445-459 | OK | same stability caveat |
| learn | recordReview(stars): stars+=, logDay(1,stars) | store.js:280-285 | store.dart:462-468 | OK | |
| learn | addMilestones: append fresh, msAt=today | store.js:286-292 | store.dart:470-484 | OK | |
| learn | itemKeys/confNs/recordQ, REV_SETS, FACT_SETS, skillOfSet | app.js:1064-1065,1110-1130,1100 | learn_tracking.dart:12-13,122-160 | OK | |
| milestones | MS_STEPS w[10,25,50,100] e[10,25,50,100] m[20,50,100], l10, lall, i:<island>:<tier> | app.js:1134-1158 | learn_tracking.dart:14,177-198 | OK | |
| milestones | msInfo text/img/phrase; ensureLearn (since + pre-mark); checkMilestones | app.js:1100-1106,1159-1175 | learn_tracking.dart:200-241 | OK | |
| review | REVIEWABLE + dueCount; result-panel button at due>=3, map at >=2 | app.js:1372-1373,121,590 | learn_tracking.dart:244-249; finish_round.dart:108; map_screen.dart:311 | OK | |
| pet | finishRound pet: happy = min(100, (happy\|\|50)+8), xp = (xp\|\|0)+5 | app.js:570-571 | finish_round.dart:39-45 | PARTIAL | Dart uses asInt(), which truncates fractions. pet_sim stores fractional happy/xp (+1.5, +0.4 per stroke), so they get truncated. happy==0 gives 8 instead of web's 58 (web treats 0 as falsy -> 50) |
| lop1 | classDone: next act, +3 tickets once per lesson | app.js:438-455 | class_plan.dart:92-120 | OK | |
| round end | finishRound order: recordRound, dailyProgress, pet, tickets, unlocked mascots, badges, milestones, due, sfx win, confetti, 'roundDone', stars 380 ms each + 'star', 1600 ms, then celebrate / dailyDone / badge / newMascot / newSticker | app.js:564-616 | finish_round.dart:35-98,160-168 | OK | |

## B. Sync merge (store side)

| area | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|
| merge | snapshot {profiles, settings, gone, smt} | store.js:295 | store.dart:487 | OK | |
| merge | maxMerge: numeric values take the max | store.js:296 | store.dart:489-498 | OK | |
| merge | gone = per-id max of both sides | store.js:302-304 | store.dart:505-507 | OK | |
| merge | skip remote profile if gone[id] >= rp.mt | store.js:306 | store.dart:511 | OK | explicit containsKey matches JS `undefined >= x` being false |
| merge | new remote profile -> push | store.js:308 | store.dart:513-517 | OK | |
| merge | identical JSON -> skip | store.js:309 | store.dart:519 | OK | |
| merge | win = larger mt (ties go to local); {...win, levels/funLevel/usage maxMerge, stars/rounds/spent max, stickers union (win first), mt max}; keys missing from merged are deleted in place | store.js:310-317 | store.dart:520-536 | OK | pet/learn/best/tickets/gear/badges/daily come from the winner in both |
| merge | drop local profiles that are gone; fix active | store.js:319-322 | store.dart:538-541 | OK | |
| merge | settings: remote wins if R.smt > S.smt (DEFAULTS fill) | store.js:323 | store.dart:542-546 | OK | |
| merge | rawSave only (no mt stamp, no onSave) | store.js:324 | store.dart:547-550 | OK | plus notifyListeners (replaces the web onMerged re-route) |
| migration | old profiles without learn/gear/funLevel/best handled lazily | store.js:219,237; app.js:1100 | profile.dart:54-68; store.dart:377 | OK | no versioned migrations exist in web |

## C. sync.js

| area | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|
| sync | endpoint `/api/bvh/sync/<sid>`; GET (no-store) / PUT {base, blob} / DELETE; 404 / 409 semantics | sync.js:6,53-81,117 | sync.dart `_round`, sync_backend.dart, firestore_sync_backend.dart | CHANGED | 18/10/2026: backend is Cloud Firestore `syncs/{sid}` {v, blob, at}; GET → doc or null (notfound), PUT → Firestore transaction (v != base → conflict with remote blob, else write v+1), DELETE → delete doc; same semantics, offline persistence disabled; 20 s timeout kept |
| sync | state key `bvh.sync` {code, v, at, err, dirty} | sync.js:7,11-12 | sync.dart:26,69-83 | OK | |
| sync | family code: ALPHA 31 chars (no I L O 0 1), 16 random bytes, byte%31, pretty XXXX-XXXX-XXXX-XXXX; normalize | sync.js:8,20-25 | sync_crypto.dart:15,21-30 | OK | |
| crypto | sid = hex SHA-256('bvh-sync-id\|'+norm) | sync.js:31 | sync_crypto.dart:48 | OK | |
| crypto | PBKDF2-SHA256, salt 'bvh-sync-key-v1', 150000 iterations, AES-GCM 256 | sync.js:32-34 | sync_crypto.dart:16-18,49-51 | OK | runs in an isolate |
| crypto | blob = base64(iv12 + ct + tag); open | sync.js:37-46 | sync_crypto.dart:68-85 | OK | |
| sync | round(): pull, merge if v differs, early 'ok' when clean; push up to 3 tries with 409 merge; else 'conflict' | sync.js:49-82 | sync.dart:117-152 | OK | |
| sync | syncNow: single-flight, sets at/err, err 'offline' when offline | sync.js:84-97 | sync.dart:154-184 | PARTIAL (intentional) | Result 'error' is renamed 'offline' (the UI maps both to the same toast). Dart keeps the dirty flag after a failed push (improvement). Network-error detection: ClientException/Timeout -> 'offline' |
| sync | create / join (len 16 else 'bad'; reset on failure) / leave(wipe) | sync.js:100-120 | sync.dart:187-223 | OK | |
| sync | auto: on open, 20 s debounce after save, on hide if dirty, on 'online' | sync.js:123-134 | sync.dart:228-257; app.dart:30 | OK | 'online' replaced by app resume (always pulls) |
| sync | onMerged re-route when on kids/map/parent/lop1 | app.js:1636-1639 | app.dart:30 (init() without onMerged) | OMITTED-OK | store notifies listeners, so watching screens rebuild |
| sync UI | card text, masked code '••••-••••-••••-'+last4, 👁 show, last-sync time, error (mất mạng/máy chủ), buttons, confirm texts, toasts (✔ Đã đồng bộ / Không tìm thấy mã này / Mã gồm 16 chữ và số / Chưa kết nối được, thử lại sau) | app.js:694-722 | sync_card.dart:14-129 | OK | extra RemoteFlags.syncEnabled gate |
| sync UI | new-kid screen "🔑 Đã có mã gia đình" join | app.js:294-300 | new_kid_screen.dart:58-73 | OK | |

## D. audio.js

| area | feature | web ref | flutter ref | status | note |
|---|---|---|---|---|---|
| audio | init: load audio.json + voice.json | audio.js:11-14 | voice_data.dart:58-68 (content bundle) | OK | |
| audio | unlock(): iOS audioSession.type='playback' (plays with the silent switch on) + resume ctx | audio.js:16-32 | soloud_audio.dart:64-68 | MISSING (iOS session) | flutter_soloud 5.2.1 leaves the AVAudioSession to the app (`sessionCategory = ma_ios_session_category_none`, soloud_miniaudio.cpp:916). ios/Runner has no AVAudioSession setup, so the default SoloAmbient category applies and the hardware silent switch mutes all sound. Fix: set `.playback` (e.g. `try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])` in AppDelegate, or the audio_session package) |
| audio | visibility: ctx.suspend/resume (pauses everything, voice continues after resume) | audio.js:34-37 | soloud_audio.dart:251-266; app.dart:44-49 | PARTIAL | Dart pauses only music and *stops* the current voice line. The engine loop and looping clips (pet purr, loop:true) keep playing in the background and are not paused; sfx are dropped while suspended. Fix: pause/resume _eng handles and track looping clip handles (or `SoLoud.setPauseAll`) |
| voice | phrase(key, lg) -> [lg, text\|\|''] | audio.js:53 | voice_data.dart:80; audio_service.dart:82 | OK | |
| voice | tpl(key,obj) with FX spellFast / spellComma; null -> '' | audio.js:55-67 | voice_data.dart:45-53,83-95 | OK | |
| voice | preload(items) | audio.js:69-72 | soloud_audio.dart:96-103 | OK | LRU cache of 48 (web unbounded) |
| voice | stopVoice: seq++, stop current | audio.js:74-77 | audio_service.dart:85-88; soloud_audio.dart:131-141 | OK | Dart also un-ducks on stop (web leaves music ducked after an interrupted line; an improvement) |
| voice | say(): no-op if sound off; stopVoice first; missing mp3 -> console.warn only (no TTS fallback); duck during line | audio.js:80-95 | audio_service.dart:91-101; soloud_audio.dart:113-129 | OK | Web has no speechSynthesis fallback and no voice-rate setting, so nothing to port. Dart plays even before unlock() (no browser gesture rule) |
| voice | clipDuration | audio.js:98-103 | soloud_audio.dart:105-111 | OK | |
| voice | sayPhrase, sayAll (stops if interrupted; single item accepted) | audio.js:105-115 | audio_service.dart:103-113 | OK | Dart takes only an Iterable (single item -> wrap in a list) |
| voice | praiseItem (6 variants, no immediate repeat), praise (random of praise1-6), retry (random of retry1-3) | audio.js:117-125 | audio_service.dart:116-123 | OK | |
| sfx | tone(): exponential attack 12 ms to vol, exponential decay to 1e-4 at dur, optional exponential frequency glide; sfx bus gain .5 | audio.js:128-138,25 | synth.dart:38-70,44 (gain .5) | OK | |
| sfx | 21 recipes: tap, flip, count, correct, wrong, star, win, pop, laser, boom, coin, jump, hit, power, bark, meow, squeak, eat, splash, snore, shoot | audio.js:143-165 | synth.dart:102-129 | OK | frequencies, times, types and volumes match line by line |
| sfx | splash: 6 random-pitched blips, re-randomized on each call | audio.js:162 | synth.dart:125 | PARTIAL | pre-rendered once with Random(7), so the same pattern every time. Minor. Fix: render 3-4 variants and pick at random |
| clip | clip(name,{rate,vol,loop}) from sfx/<name>.mp3 via sfx bus (.5); returns stop fn (fade τ .05, stop +.2) or false; failures cached | audio.js:169-183 | soloud_audio.dart:154-170 | OK | returns null instead of false |
| note | NOTES C4-C5 [261.6..523.3]; note(i,dur=.9) = 3 partials (f .55, 2f .18 for .45dur, 4.01f tri .08 .12 s); i>7 = Hz | audio.js:186-193 | synth.dart:132-134; soloud_audio.dart:172-191 | PARTIAL | web routes note() through sfxBus (gain .5, tone() default bus). Dart renders notes with gain 1 (soloud_audio.dart:47,187: `renderTones(noteRecipe(...))` with no `gain: .5`), so the piano is 2x (+6 dB) louder relative to sfx/voice. Fix: pass `gain: .5` in both places |
| engine | engine(level): saw (55+110L) + square (27+55L) into lowpass (400+900L Hz) into gain .05+.05L into sfx bus; 0 = fade out and stop after 300 ms | audio.js:196-213 | soloud_audio.dart:194-209,270-312 | PARTIAL | no lowpass filter (raw saw/square, much harsher); square level is v*.6 instead of an equal share. Fix: add a SoLoud biquad low-pass filter (cutoff 400+900L) on the engine sources, or pre-render a filtered loop; drop the .6 factor |
| music | background music: pentatonic music-box melody (32 notes, random walk ±2, rests at n%8==7 or 18%), chords every 4 beats, beat .34 s, bus .07 (ducked .025), new melody every 64 steps | audio.js:216-259 | synth.dart:137-169; soloud_audio.dart:211-249 | PARTIAL | Dart renders one 64-step loop (~21.8 s) and repeats it forever; web makes a new melody every 64 steps. Overlapping notes in renderTones can sum above 1.0 and are hard-clipped in toWav. Fix: render 3-4 loops with different seeds and alternate them (or regenerate in an isolate each cycle) |
| music | music() applies setting; starts only after unlock | audio.js:250-259 | soloud_audio.dart:224-237; start_screen.dart:20-21; settings.dart:14 | OK | also listens to store changes |
| music | duck on voice (setTargetAtTime τ .15) | audio.js:243-248 | soloud_audio.dart:212-222 | OK | 300 ms fade |

## E. Mechanical sfx/clip scan (sfx_scan.py)

- Every sfx name used anywhere in web js/**/*.js (audio.sfx('x'), imported sfx('x'), rpgcore re-export) exists in synth.dart sfxRecipes: bark, boom, coin, correct, count, eat, flip, hit, jump, laser, pop, power, shoot, snore, splash, squeak, star, tap, win, wrong. The scan's "plasma"/"vortex" hits are false positives: they are string comparisons inside `sfx(me.gun === 'plasma' || me.gun === 'vortex' ? 'shoot' : 'laser')` (funshooter.js:365).
- Dynamic sfx: pet.js:105,652 `sfx(kind.sound)` -> app.json pets[].sound in {bark, meow, squeak}; all present ('meow' is used only this way).
- clip() names: pet.js VOICE map (pet.js:19-25): dog-bark1/2/3, dog-whine, cat-meow1/2/3, cat-purr, rabbit-1/2/3. All 11 exist in assets/sfx/*.mp3, and pubspec lists assets/sfx/. The Dart pet_sim.dart:66-71 map is identical. Other `clip()` matches (funvs2, figure, rpgzones2, funmore, funvs1) are canvas ctx.clip(), not audio.
- Dart sfx names used in lib/ are all in kSfxNames.
