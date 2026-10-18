# Bé Vui Học — Kiểm tra đủ tính năng so với bản web (QA parity)

> **Cập nhật 18/10/2026:** mã web `reference/web/` đã được gỡ khỏi repo. Các test đối chiếu vẫn giữ nguyên ý nghĩa nhưng đọc
> dữ liệu đã trích sẵn từ mã web (`test/parity/fixtures/web_sources.json`, `web_store_trace.json`) thay vì đọc mã web. Các số
> dòng `*.js` trong `docs/qa/` là của bản web cũ. App không còn liên kết tới trang web cũ; đồng bộ chuyển sang Cloud Firestore;
> 4 khoá chữ "Cài lên màn hình chính" (install*, chỉ dành cho web) đã bỏ khỏi `kStrings`.

Ngày kiểm tra: 15/10/2026. Nguồn gốc so sánh: mã web `reference/web/` lúc đó (index.html, css/app.css, js/app.js, store.js, audio.js,
i18n.js, ui.js, sync.js và 42 file `js/games/*.js` — tổng 48 module, 16.935 dòng JS) và dữ liệu `assets/data/`.
Bản app: `lib/` (Flutter).

**Trả lời ngắn: app CÓ ĐỦ mọi tính năng của web.** Không còn mục ❌ nào. Còn 5 mục ⚠️ khác biệt nhỏ về hiệu ứng/bố cục
(không ảnh hưởng nội dung học, cách chấm sao hay dữ liệu) và 36 mục ➖ cố ý bỏ hoặc làm khác cho phù hợp app gốc / chính sách
app trẻ em. Mục 7 liệt kê những việc cần chủ app quyết định.

Ký hiệu: ✅ đã có, giống web · ⚠️ có nhưng khác một phần · ❌ thiếu · ➖ cố ý bỏ / làm khác (có lý do).

---

## 1. Bảng tổng hợp

Mỗi dòng là một tính năng hoặc hành vi cụ thể, so cả logic, ngưỡng, chữ hiển thị và câu đọc (không chỉ so tên).
Bảng chi tiết từng dòng (tiếng Anh, kèm số dòng web ↔ Flutter) ở thư mục `docs/qa/`.

| Khu vực | Bảng chi tiết | Trước khi sửa ✅ / ⚠️ / ❌ / ➖ | Sau khi sửa ✅ / ⚠️ / ❌ / ➖ |
|---|---|---|---|
| Màn hình, điều hướng, góc bố mẹ, ôn tập, báo cáo (app.js, ui.js, index.html) | `qa/app_screens.md` | 97 / 9 / 1 / 8 | 107 / 0 / 0 / 8 |
| Lưu trữ, đồng bộ, âm thanh (store.js, sync.js, audio.js) | `qa/core_store_audio.md` | 85 / 7 / 1 / 2 | 91 / 1 / 0 / 3 |
| 15 đảo học — 16 file game học | `qa/learn_games.md` | 119 / 5 / 0 / 3 | 120 / 2 / 0 / 5 |
| Khu vui chơi: danh sách, khung chơi, 35 game (trừ săn quái / siêu nhân) | `qa/fun_games.md` | 319 / 13 / 0 / 8 | 331 / 1 / 0 / 8 |
| Săn quái vật + Siêu nhân (funhunt, funhero) | `qa/fun_hunt_hero.md` | 92 / 4 / 0 / 9 | 96 / 0 / 0 / 9 |
| Game hành động, đối kháng, RPG, phòng, thú cưng, thi tài, lớp 1 | `qa/action_rpg_room.md` | 104 / 4 / 0 / 3 | 107 / 1 / 0 / 3 |
| Phát hiện thêm khi viết test đối chiếu (mục 3) | — | 0 / 5 / 0 / 0 | 5 / 0 / 0 / 0 |
| **Tổng (898 mục)** | | **816 / 47 / 2 / 33** | **857 / 5 / 0 / 36** |

Ghi chú về cách đếm:
- Một vài lỗi xuất hiện ở hai bảng (vd. "kho đồ mất giữa các cấp khi bố mẹ chơi miễn phí" có ở bảng màn hình, Khu vui chơi
  và săn quái/siêu nhân) — đếm theo dòng của từng bảng.
- Học: dòng "bấm lại thẻ sai" bị đánh dấu ⚠️ lúc kiểm tra, nhưng CSS web có `.choice.wrong { pointer-events: none }` nên web
  cũng không tính lần bấm lại → thực ra ✅ (không sửa). Đồng bộ: kết quả `'error'` đổi tên `'offline'` và giữ cờ "chưa gửi"
  khi lỗi là cải tiến có chủ đích → chuyển sang ➖.

---

## 2. Cách kiểm tra

1. **Đọc mã từng phần (6 nhóm, song song)**: đọc hết từng file JS của web, liệt kê từng nhánh/chế độ/hằng số/câu đọc, tìm
   chỗ tương ứng trong Dart (file:dòng) và so logic. Kết quả: các bảng ở `docs/qa/`.
2. **Trích xuất máy móc** bằng script (node/python) ngay trên mã web: route, đảo, kiểu bài, danh sách game, khoá câu đọc,
   khoá chữ giao diện, tên hiệu ứng, tên hình (mục 3).
3. **Test đối chiếu tự động** `test/parity/` (chạy trong `flutter test`) — trước đọc thẳng mã web trong `reference/web/`; từ
   18/10/2026 đọc dữ liệu đã trích từ mã web (`test/parity/fixtures/web_sources.json`) nên nếu app lệch khỏi bản web thì test hỏng:

| File | Kiểm tra |
|---|---|
| `test/parity/web_sources_test.dart` | 48 game của `FUN_GAMES` (fun.js) = `kFunGames` (cùng thứ tự, kind, hình, tên vi/en, màu, hot, leveled) và đều có module; mọi câu `sayPhrase/phrase/tpl` web gọi có trong voice.json + có file mp3 + app cũng dùng; 21 hiệu ứng `sfx()` = các `case` của audio.js; tiếng thật thú cưng có file; mọi khoá `i18n.js` (vi + en) có trong `kStrings` với **cùng nội dung**; mọi tên hình trong content.json / `img('…')` của web / `EmojiImage('…')` của app đều có file; 17 màn của `route()` có trong router; danh sách màn được nhớ để mở lại = `RESUME` của web |
| `test/parity/levels_render_test.dart` | Số bài từng đảo = dữ liệu web (647 bài); **từng bài một** của 15 đảo mở được game thật (không phải "Đang xây dựng") và chạy 1,2 giây không lỗi |
| `test/parity/store_parity_test.dart` | Bản ghi **store.js thật của web** chạy trong Node (đồng hồ + Math.random cố định; ghi sẵn trong `fixtures/web_store_trace.json`, công cụ sinh đã gỡ cùng mã web) qua 186 thao tác (lượt chơi, giờ chơi, ví sao, thử thách ngày + chuỗi ngày, huy hiệu, vé, kỷ lục, cấp game, kho đồ, trả lời + nhầm lẫn + ôn tập ngắt quãng qua nhiều ngày, mốc, gộp dữ liệu máy khác, xoá bé, sao lưu/khôi phục); phát lại trên `AppStore` và so **kết quả + toàn bộ JSON lưu** sau từng bước |
| `test/parity/resume_route_test.dart` | Nhớ màn để mở lại (resumeRoute) và dừng câu đọc khi đổi màn |

---

## 3. Kết quả trích xuất máy móc

| Hạng mục | Web | App | Kết quả |
|---|---|---|---|
| Màn hình (`route()` app.js) | 17 màn: kids, new, map, island, play, lop1, album, buddies, parent, report, review, duel, room, pet, fun, rpg, rest (+ màn Bắt đầu) | `lib/app_router.dart` | ✅ đủ, cùng các chặn (chưa bấm Bắt đầu, chưa có bé, hết giờ chơi, tắt Khu vui chơi) |
| Đảo | 18 (15 đảo học + Phòng, Thi tài, Học cùng lớp) | `app.json` dùng chung | ✅ |
| Bài học | 647 bài: chữ cái 32, ghép vần 247, tập viết 28, đọc 105, đếm 19, toán 48, cuộc sống 10, tiếng Anh 34, trí nhớ 14, tư duy 25, lập trình 20, trò chơi 10, âm nhạc 7, tô vẽ 7, khám phá 41 | | ✅ từng bài dựng được (test) |
| Kiểu bài (`kind`) | chữ cái: mặc định/initial/upper · tiếng Anh: findEn/findEnA/findEnThe/showMe · ghép vần: tone, onset, rime, build, listen, readword, sentence, rule, readsent, cloze · đọc: story, dictation, aloud · toán: add, sub, cmp, tens, mix, clock, shape, blocks, next, cmp100, add100, sub100, missing, word, chain, add2d, sub2d, position, maxmin, seqnum, cmpexpr · cuộc sống: shop, length, weight, week, clips, height, ruler, calendar · tư duy: shadow, pattern, odd, maze, sudoku, jigsaw, seq, spot · lập trình: garden, trace, debug, loop · âm nhạc: free, song, simon · tô vẽ: draw, color · trò chơi: balloon (letters/numbers/tones/english), race (add/sub/mix) · đếm, trí nhớ, khám phá, tập viết: một kiểu (có biến thể) | `lib/features/learn/**` | ✅ mọi kiểu có nhánh xử lý riêng |
| Game Khu vui chơi | 48 (+ RPG 10 vùng × 6 màn) | `kFunGames`, `registry.dart` | ✅ |
| Câu đọc cố định (phrases) | 185 | voice.json dùng chung | ✅ mọi câu web gọi đều có file và app dùng. 14 câu không file JS nào gọi (codeJumpQ, codeRelQ, dictC/T/V, duelPick, tensHint, traceGood…) — web cũng không dùng |
| Mẫu câu (templates) | 77 | | ✅ (findEn, findEnA, petLearned, showMe: web cũng không gọi bằng tên) |
| Câu ghép động | `ms_<mốc>`, `rpgZ<vùng>`, `codeRep<n>`, praise1–6, retry1–3 | `learn_tracking.dart:211`, `rpg.dart:895`, `code.dart:401`, `audio_service.dart` | ✅ |
| Chữ giao diện (i18n.js) | 148 khoá × 2 ngôn ngữ | `lib/core/i18n/strings.dart` | ✅ cùng nội dung; khác có chủ đích: `backupNote` ("xoá ứng dụng" thay "xoá dữ liệu trình duyệt"); không dùng `install*`, `gotIt` (➖ hướng dẫn cài PWA) |
| Hiệu ứng tổng hợp | 21 (`tap, flip, count, correct, wrong, star, win, pop, laser, boom, coin, jump, hit, power, bark, meow, squeak, eat, splash, snore, shoot`) | `synth.dart` — cùng tần số/thời lượng/âm lượng | ✅ (splash ⚠️ xem mục 6) |
| Tiếng thật (`clip`) | 11 tiếng thú cưng | `assets/sfx/*.mp3` | ✅ |
| Hình | 2.672 `img` + 301 `imgs` + bìa truyện, bài vị trí, nhóm phân loại; `img('…')` trong JS | `assets/img`, `assets/photo` | ✅ không thiếu file nào |
| Dữ liệu lưu (`bvh.v1`) | store.js | `store.dart` | ✅ 186/186 bước giống hệt (sau khi sửa lỗi sort, mục 4) |

---

## 4. Đã sửa trong đợt này

| # | Vấn đề (trước) | Sửa | File |
|---|---|---|---|
| 1 | ❌ **Không mở lại đúng màn** sau khi máy tắt app ở nền (web: sessionStorage `bvh.route` + `resumeRoute()`) | Ghi màn hiện tại (chỉ các màn RESUME, không nhớ màn đang chơi `/fun/<id>`, `/rpg/<r>/<s>`), kèm giờ, hết hạn sau 2 giờ; bấm Bắt đầu (1 bé) thì về màn đó | `lib/app_router.dart` (`saveResumeRoute`, `resumeRoute`), `lib/app.dart` (`_onRoute`), `lib/features/home/start_screen.dart` |
| 2 | ❌ **iOS: gạt nút im lặng là mất hết tiếng** (web đặt `navigator.audioSession.type = 'playback'`; flutter_soloud không tự đặt) | Đặt `AVAudioSession` loại `.playback` lúc mở app | `ios/Runner/AppDelegate.swift` (cần thử trên iPhone thật) |
| 3 | ⚠️ Đổi màn không dừng câu đang đọc (web `route()` gọi `stopVoice()`) | Dừng câu của màn cũ mỗi lần đổi màn; giữ câu vừa nói kèm lệnh chuyển (vd. 'welcome' rồi sang tạo bé) | `lib/app.dart`, `lib/core/audio/audio_service.dart` (`stopVoiceOnRoute`) |
| 4 | ⚠️ "Chơi lại" / "Ôn tiếp" không kiểm tra hết giờ chơi → bé chơi lại mãi quá giới hạn | Hết giờ thì sang màn Nghỉ mắt (như `route(true)`) | `lib/features/play/play_screen.dart`, `lib/features/learn/language/review.dart` |
| 5 | ⚠️ Ăn mừng mốc của bài ôn hiện đè lên câu hỏi mới nếu bé bấm "Ôn tiếp" nhanh | Chỉ ăn mừng khi bảng kết quả còn mở | `review.dart` |
| 6 | ⚠️ Thưởng thú cưng sau bài: cắt số lẻ, vui = 0 thành 8 (web: 58) | Công thức đúng web `min(100, (happy‖50)+8)`, giữ số lẻ | `lib/features/play/finish_round.dart` |
| 7 | ⚠️ Nhận nuôi thú cưng: nút quay lại không nói câu 'petWash' | Dùng chung `exit()` | `lib/features/room/pet.dart` |
| 8 | ⚠️ Ghi công ảnh: không có link tới trang tệp Wikimedia của từng ảnh (yêu cầu của giấy phép CC BY/BY-SA) | Chữ "Wikimedia Commons" bấm được, mở `src` (đã qua khoá bố mẹ) | `lib/features/parents/parents.dart` |
| 9 | ⚠️ **Sắp xếp không ổn định** (Dart `List.sort`) → khi >80 cặp nhầm lẫn bằng điểm, xoá khác cặp so với web; thứ tự mục ôn bằng điểm khác web. Tìm ra nhờ test đối chiếu store | Sắp xếp ổn định (giữ thứ tự chèn như JS) | `lib/core/store/store.dart` (`recordAnswer`, `dueItems`) |
| 10 | ⚠️ **Khu vui chơi: trạng thái theo vé** — web dùng chung một `opts` cho các cấp của một vé (kho chưởng siêu nhân, kho vũ khí săn quái, xưởng xe tăng, gara đua xe, chọn đấu máy/2 người). App đoán bằng giờ (8 giây) / biến toàn cục → sai khi bé bấm "Cấp tiếp (🎟️ 1)" ngay sau một vé 3 cấp | Thêm `FunGameContext.ticket` (map dùng chung các cấp của MỘT vé); siêu nhân, săn quái, đua xe, phi thuyền, xe tăng, 10 game đối kháng dùng nó | `lib/core/game/fun_games.dart`, `lib/features/play/fun_play_screen.dart`, `lib/features/fun/more/funhero.dart`, `lib/features/fun/hub/funhunt.dart`, `lib/features/fun/action/act_core.dart` (+ test) |
| 11 | ⚠️ Bố mẹ chơi miễn phí: kho đồ (súng, skill…) của cấp trước mất ở cấp sau | Khung giữ `carry` của cấp trước cho cả chế độ miễn phí (chỉ không lưu vào hồ sơ) | `fun_play_screen.dart` |
| 12 | ⚠️ Game Khu vui chơi (ná, hứng trái cây, đập quái, câu cá, xây tháp, phá gạch, chim bay, săn quái) **chơi lại từ đầu/đứng hình khi xoay máy** (game tạo lại trong `build()`) | Khung giữ game đầu tiên; săn quái tạo game một lần | `lib/features/fun/hub/funcore.dart`, `funhunt.dart` |
| 13 | ⚠️ Đồng hồ cấp chạy trước khi hình nạp xong (web `await loadAll` rồi mới chạy) | Chờ hình (tối đa 2 giây) rồi mới chạy | `funcore.dart` |
| 14 | ⚠️ Chạm bị hệ thống huỷ (vuốt hệ thống, lòng bàn tay) bị coi là thả tay → ná tự bắn, bóng tự phóng | Huỷ chạm không làm gì (web không xử lý) | `funcore.dart` (`pointerCancel`) |
| 15 | ⚠️ Xây tháp: khối đang đung đưa + vạch dẫn biến mất khi hết lượt | Vẽ như web | `lib/features/fun/hub/funmore.dart` |
| 16 | ⚠️ Nối dây màu: thêm tiếng 'win' web không có | Bỏ | `lib/features/fun/hub/funlogic.dart` |
| 17 | ⚠️ Bảng số thần tốc: bấm lại số đã tìm không tính sai (web tính sai); thời gian đếm theo nhịp Timer (đọc thiếu → điểm cao hơn) | Như web; đo bằng `Stopwatch` | `funlogic.dart` |
| 18 | ⚠️ Dẫn nước: độ lệch sang phải khi sinh đường ống khác web | Tung 60% ở mỗi lần so sánh như web | `funlogic.dart` |
| 19 | ⚠️ Săn quái: ngọc giá trị 3 khi đã quá 140 ngọc không đổi màu xanh; đọc kho đồ lạ ("3.7", true) khác web | Như web (`+v` của JS) | `funhunt.dart` |
| 20 | ⚠️ Đua xe: tay đua đội mũ trang phục của bé (web: mũ lưỡi trai tay đua); giá màu sơn thiếu hình đồng xu | Như web | `lib/features/fun/action/funracer.dart` |
| 21 | ⚠️ RPG: anh hùng ở làng và NPC không cầm vũ khí | `FigureView(weapon:)` | `lib/features/learn/creative/figure.dart`, `lib/features/rpg/rpg.dart` |
| 22 | ⚠️ Âm thanh vào nền: chỉ dừng nhạc, cắt câu đang đọc; động cơ xe, tiếng mèo rừ rừ vẫn kêu (web dừng tất cả rồi phát tiếp) | Dừng cả thiết bị âm thanh, phát tiếp đúng chỗ khi quay lại | `lib/core/audio/soloud_audio.dart` |
| 23 | ⚠️ Đàn to gấp đôi web (thiếu bus hiệu ứng .5) | gain .5 | `soloud_audio.dart`, `synth.dart` |
| 24 | ⚠️ Tiếng động cơ xe rè (thiếu lọc thông thấp 400+900·ga Hz; sóng vuông nhỏ hơn) | Bộ lọc biquad + cùng âm lượng như web | `soloud_audio.dart` |
| 25 | ⚠️ Nhạc nền lặp một giai điệu ~22 giây mãi (web đổi giai điệu mỗi 64 nhịp), có thể vỡ tiếng khi nốt chồng | 3 giai điệu nối nhau (~65 giây), trộn gain .8 (bù ở âm lượng nhạc) | `synth.dart`, `soloud_audio.dart` |
| 26 | ⚠️ Thử thách hôm nay: thiếu nhãn "Chơi 1 bài …" (`title` của web) | Nhãn trợ năng | `lib/features/map/map_screen.dart` |
| 27 | ⚠️ Nối dây màu: hiệu ứng khi xong đơn giản hơn web | Chấm đầu/cuối nảy 1,4×, cả đường nảy 1,1× lần lượt 30 ms/ô, cả bảng nảy 1,12× thành sóng chéo (40 ms) | `funlogic.dart` |

Test mới: `test/parity/*` (mục 2). Test cũ cập nhật theo API mới: `test/features/fun_more/{harness,funhero_test}.dart`,
`test/features/fun_action/{helpers,widget_test}.dart`.

---

## 5. Danh sách kiểm tra theo khu vực

Chi tiết từng dòng (kèm số dòng hai bên) xem `docs/qa/*.md`. Dưới đây là danh sách đầy đủ theo tính năng.

### 5.1 Khởi động, điều hướng, giờ chơi (`lib/app.dart`, `lib/app_router.dart`, `lib/main.dart`)
- ✅ Nạp dữ liệu (content, app, photos, voice, audio) trước khi chạy; nền trời mây chung.
- ✅ Chặn: chưa bấm Bắt đầu → màn Bắt đầu; cần bé mà chưa có → /kids hoặc /new; hết giờ → /rest; tắt Khu vui chơi → không vào RPG; đường dẫn lạ → Bắt đầu.
- ✅ Đếm giờ chơi 15 giây/lần (chỉ khi app mở, có bé, không ở kids/new/parent/report/rest); hết giờ thì sang Nghỉ (trừ khi đang làm bài).
- ✅ (đã sửa) Dừng câu đọc khi đổi màn; nhớ màn để mở lại; "Chơi lại"/"Ôn tiếp" kiểm tra giờ chơi.
- ✅ Đồng bộ có dữ liệu mới → các màn tự vẽ lại (ChangeNotifier).
- ✅ Nút Back Android = nút Quay lại/✕ của màn, đóng bảng đang mở trước.
- ➖ Service worker, cứu hộ index.html, tải lại khi có bản mới, `document.lang` (chỉ có ở PWA).

### 5.2 Màn Bắt đầu, chọn bé, tạo bé, bạn đồng hành (`lib/features/home/`)
- ✅ Đoàn linh vật nhảy, logo, khẩu hiệu, nút Bắt đầu; lần chạm đầu mở âm thanh + nhạc; 0 bé → 'welcome' + tạo bé; 1 bé → bản đồ (hoặc màn đã nhớ); nhiều bé → chọn bé.
- ✅ Liên kết Giới thiệu / Ghi công (qua khoá bố mẹ — chính sách app trẻ em).
- ✅ Chọn bé (thẻ linh vật, tên, sao), thêm bé; tạo bé 2 bước (tên → linh vật), chọn cấp học lần đầu.
- ✅ Bạn đồng hành: mở khoá theo sao, "Cần n sao".
- ➖ Gợi ý "gạt nút im lặng" (Safari iOS cũ) — thay bằng audio session `.playback` (mục 4 #2).
- ➖ Đo lường (hello/active/shareEvent/cafeSeen, nguồn giới thiệu, loại máy) — app trẻ em không dùng analytics.

### 5.3 Bản đồ, cấp học, danh sách bài (`lib/features/map/`, `lib/features/tiers/`, `lib/core/content/levels.dart`)
- ✅ 3 cấp (Mầm 3–4 tuổi, Chồi 5 tuổi, Lớp 1 6 tuổi), bài tier 0 thuộc mọi cấp, chọn cấp gần nhất khi đảo không có cấp đó, đổi cấp xem tạm từng đảo.
- ✅ Khoá bài theo thứ tự (cài đặt bố mẹ): bài sau mở khi bài trước có sao.
- ✅ Thẻ đảo: hình, tên, x/y bài, sao; đảo đặc biệt (Phòng, Thi tài, Học cùng lớp) đi thẳng tới màn riêng.
- ✅ Thử thách hôm nay: 3 đảo chọn theo ngày + id bé (cùng thuật toán băm với web), dấu ✔, chuỗi ngày 🔥, nút "🔁 Ôn bài n" khi ≥2 mục cần ôn.
- ✅ Thanh Khu vui chơi + Thú cưng, vé, ví sao, huy hiệu.
- ➖ Banner "Cài lên màn hình chính" (PWA).

### 5.4 Màn chơi + kết thúc bài (`lib/features/play/play_screen.dart`, `finish_round.dart`)
- ✅ Thanh trên (quay lại, tiến độ, sao), linh vật cổ vũ/buồn, ẩn linh vật ở bài vẽ, ảnh thật trong bài (photo mode), chọn ảnh thật/hoạt hình đồng bộ trong một nhóm.
- ✅ Kết thúc: sao (giữ cao nhất, cộng dồn), hình dán mới, thử thách ngày (+5 sao, +2 vé), vé mỗi bài, bạn đồng hành mới, huy hiệu mới, mốc tiến bộ + ăn mừng + bằng khen, thú cưng vui hơn (đã sửa công thức), Học cùng lớp (+3 vé, bài tiếp), câu khen theo thứ tự ưu tiên như web, nút Chơi lại / Bài tiếp / Bản đồ.

### 5.5 15 đảo học (`lib/features/learn/**`) — chi tiết `qa/learn_games.md`
- ✅ Chữ cái, tiếng Anh (pick): tìm chữ/âm đầu/chữ hoa; tìm từ tiếng Anh 4 mẫu câu; combo, bay chữ, thẻ thưởng chạm để qua.
- ✅ Ghép vần (spell): 10 kiểu, luật "đánh vần nhanh", bay chữ, bài lớp 1 có danh sách từ riêng. ➖ thẻ vần: app bỏ thẻ trùng và bù đủ số thẻ (web có thể hiện ít thẻ hơn hoặc trùng) — xem mục 7.
- ✅ Tập viết (trace): 39 nét chữ/số, sai số TOL 15 / LOOK 14 / STEP 2, điểm bắt đầu 1,7×. ⚠️ bảng viết hiện ngay khi đang đọc lời giới thiệu (web hiện sau).
- ✅ Đọc (read): truyện có tô chữ theo giọng, chính tả 3 bước (âm đầu/vần/dấu), đọc to có nhận giọng (hỏi bố mẹ đồng ý + khoá phép tính trước khi bật micro) hoặc bố mẹ chấm. ➖ app không kiểm tra trước "máy có nhận giọng không" (muốn kiểm tra phải xin quyền micro TRƯỚC khi bố mẹ đồng ý); máy không hỗ trợ thì báo `micNA` khi bấm 🎤.
- ✅ Đếm, Toán (21 kiểu), Cuộc sống (8 kiểu), Trí nhớ, Tư duy (8 kiểu), Lập trình (vườn/dò mã/sửa lỗi/vòng lặp, BFS giống web), Âm nhạc (đàn tự do, bài hát, Simon), Tô vẽ (vẽ tự do, tô màu ≥50% vùng), Khám phá (41 bộ phân loại), Trò chơi (bóng bay 4 chế độ, đua xe 3 phép tính).
- ⚠️ Cuộc sống / "dài nhất – ngắn nhất": app xếp 3 bút dựng đứng cạnh nhau (web xếp nằm ngang một cột) — chỉ khác bố cục.
- ➖ Lưu tranh: web tải PNG; app lưu vào bộ nhớ app + thông báo.

### 5.6 Ôn tập ngắt quãng & báo cáo (`review.dart`, `lib/features/parents/report.dart`, `lib/core/game/learn_tracking.dart`)
- ✅ Ghi từng câu (đúng ngay/sai/thời gian), cặp nhầm lẫn (tối đa 80), khoảng ôn 0/1/3/7/14/30 ngày, mục cần ôn, "Luyện riêng mục này", "Luyện lại cho bé".
- ✅ Báo cáo bố mẹ: tỉ lệ đúng theo kỹ năng, nhóm phép tính, chỗ hay nhầm, mục tiêu tiếp theo, biểu đồ tuần, danh sách mốc + bằng khen.
- ✅ Mốc tiến bộ (đọc đúng 10/25/50/100 tiếng, chữ cái, phép tính, tiếng Anh, học xong đảo) + câu đọc `ms_*`; bằng khen PNG 1080×1350, chia sẻ.

### 5.7 Phòng của bé, hình dán, thú cưng, thi tài, Học cùng lớp (`lib/features/room/`)
- ✅ Tủ đồ (mua bằng ví sao, đeo/bỏ, nền phòng), album hình dán + huy hiệu.
- ✅ Thú cưng: nhận nuôi (6 loài), đặt tên, chỉ số giảm theo giờ, tiếng thật, tự đi lại, chạm/vuốt/đi theo/lăn, cho ăn, uống, chơi bóng, tắm + xả nước, ngủ, đồ đẹp mở theo cấp, mọi câu đọc. (Đã sửa câu 'petWash' khi thoát lúc nhận nuôi.)
- ✅ Bố con thi tài: 3 chủ đề × 10 lượt, màn chia đôi xoay ngược, khoá 1,3 giây khi sai, kết quả + đấu lại.
- ✅ Học cùng lớp: tuần học theo ngày khai giảng, chọn tuần, thẻ bài (đã xong/tiếp theo), bài thưởng.

### 5.8 Khu vui chơi (`lib/features/fun/**`, `lib/features/play/fun_play_screen.dart`) — chi tiết `qa/fun_games.md`, `qa/fun_hunt_hero.md`
- ✅ Danh sách: 🔥 Game hay nhất (thẻ RPG đầu tiên) → Hành động → Đối kháng → Vui nhộn → Trí tuệ, ẩn nhóm trống, ô cuối lấp hàng; "Cấp x/60 · 🏆 kỷ lục"; hết vé → tiếng + thông báo; bố mẹ chơi miễn phí qua khoá phép tính; thẻ "Nhân vật của bé" (trai/gái, màu áo, mũ).
- ✅ Khung chơi: trừ vé, tối đa 3 cấp/vé, lên cấp, kho đồ, kỷ lục (không tính khi bố mẹ chơi / 2 người), bảng kết quả (Về Khu vui chơi / Cấp tiếp hoặc Chơi lại (🎟️ 1) / Học thêm để có vé). (Đã sửa: trạng thái theo vé, kho đồ khi chơi miễn phí.)
- ✅ 48 game, đủ chế độ con: đua xe (gara, nâng cấp, sơn, decal, hộp đồ), săn quái (12 skill, 4 nâng cấp, 10 loại quái, 3 trùm, phím mũi tên/WASD), phi thuyền (súng, skill, cửa hàng), siêu nhân (7 chưởng, kho chưởng, tên lửa, khiên), xe tăng (xưởng, vũ khí), ná, hứng trái cây, đập quái, câu cá, xây tháp, phá gạch, chim bay, bắn bia, khủng long chạy, ăn đậu né ma, rắn, nhảy mây, ếch qua đường, bóng bàn, xếp gạch, ghép 3, 10 game đối kháng (đấu máy / 2 người trên một máy, cảm ứng nhiều ngón), lập trình robot, nối dây màu, dẫn nước, bảng số, chạy 3 làn, bóng rổ, vượt rào, cứu hoả, cá con, nhảy theo nhạc, nông trại, bóng bay số, pizza, golf, tìm đồ vật, bẻ ghi tàu, xếp hàng lên xe.
- ✅ (đã sửa) Nối dây màu: hiệu ứng nảy khi xong (chấm 1,4×, chạy dọc đường 1,1×, sóng chéo cả bảng 1,12×).
- ⚠️ Thẻ game: chưa có hiệu ứng "mọc lên lần lượt" và hình nảy khi bấm (chỉ thu nhỏ khi bấm).
- ⚠️ Gara đua xe: hình xe đứng yên (web nhún, lắc nhẹ).

### 5.9 Thế giới phiêu lưu RPG (`lib/features/rpg/`) — chi tiết `qa/action_rpg_room.md`
- ✅ Làng (NPC đi lại, lời khuyên), thẻ anh hùng (đã sửa: cầm vũ khí), cửa hàng (vũ khí, giáp, bùa), đồng đội (thú), 10 vùng × 6 màn (Rừng Xanh, Biển Ngọc, Hang Mỏ, Xứ Tuyết, Sa Mạc, Thành Mây, Rừng Kẹo, Núi Lửa, Đầm Lầy Ma, Lâu Đài Rồng) với trùm và cơ chế riêng, vé, thưởng + lên cấp, câu đọc rpgZ*/rpgBoss.

### 5.10 Góc bố mẹ, cài đặt, sao lưu, đồng bộ (`lib/features/parents/`, `lib/features/sync/`)
- ✅ Khoá bố mẹ (phép tính), các bé (đổi tên, xoá, báo cáo), biểu đồ tuần, cài đặt: ngôn ngữ, nhạc nền, giọng đọc & hiệu ứng, giới hạn mỗi ngày, cho thêm 10 phút, Khu vui chơi bật/tắt, vé mỗi bài, tặng vé, khoá theo thứ tự.
- ✅ Sao lưu / khôi phục (cùng định dạng file web `{app:'be-vui-hoc', version:1, data}`), ghi công ảnh (đã sửa: link từng ảnh) và tiếng thú cưng, phiên bản.
- ✅ Đồng bộ mã gia đình: cùng API, PBKDF2 150000 vòng + AES-GCM-256 (đối chiếu byte với web), gộp dữ liệu (bản sửa sau thắng, sao/lượt/giờ/cấp/hình dán lấy lớn hơn, xoá bé theo `gone`), chờ 20 giây, thử lại khi 409.
- ➖ Thẻ "Mời cà phê" chuyển khoản ngân hàng + QR, sao chép số tài khoản (chính sách store: không thanh toán ngoài trong app trẻ em).
- ➖ Thẻ hướng dẫn cài PWA.

### 5.11 Âm thanh (`lib/core/audio/`)
- ✅ Giọng đọc mp3 theo audio.json, cắt câu cũ khi đọc câu mới, đọc chuỗi, nhạc nhỏ lại khi đang đọc, khen/nhắc ngẫu nhiên không lặp, 21 hiệu ứng, tiếng thật, đàn 8 phím, động cơ xe, nhạc nền hộp nhạc ngũ cung; tắt giọng đọc & hiệu ứng thì im.
- ✅ (đã sửa) audio session iOS, vào nền/ra lại, âm lượng đàn, bộ lọc động cơ, nhạc nền đổi giai điệu.
- ⚠️ Tiếng 'splash' (nước bắn) tổng hợp sẵn một mẫu (web ngẫu nhiên cao độ mỗi lần).

---

## 6. Còn lại (⚠️ — khác nhỏ, chưa sửa)

| Mục | Khác biệt | Vì sao chưa sửa |
|---|---|---|
| Thẻ game Khu vui chơi | Không có "mọc lên lần lượt" và hình nảy khi bấm | Chỉ là hiệu ứng; `fun.dart` FunGameCard |
| Gara đua xe | Xe trong gara đứng yên | Chỉ là hiệu ứng; `funracer.dart` `_CarPainter` |
| Tập viết | Bảng viết hiện trong lúc đọc lời giới thiệu (bé viết sớm được) | Không đổi cách chấm; nhiều khả năng tốt hơn cho bé |
| Cuộc sống — so dài/ngắn | Bút dựng đứng 3 cột (web: nằm ngang 1 cột) | Bố cục cho thẻ vuông trên điện thoại; logic giống hệt |
| Tiếng 'splash' | Cùng một mẫu mỗi lần | Rất nhỏ; nằm trong file âm thanh đang được tối ưu hiệu năng song song |

---

## 7. Cần chủ app quyết định

1. **Thẻ vần (đảo Ghép vần, kiểu `rime`)**: web đôi khi hiện ít thẻ hơn hoặc hai thẻ trùng nhau (khi bé mới biết 1–2 dấu); app bỏ trùng và luôn đủ thẻ. Đề xuất giữ cách của app. Nếu muốn giống web tuyệt đối: `spell.dart` `_rimeChoices`.
2. **Mở lại màn cũ sau khi app bị tắt**: app nhớ màn trong 2 giờ (`kResumeFor` trong `app_router.dart`). Web chỉ nhớ trong cùng tab trình duyệt. Có thể đổi thời gian.
3. **Audio session iOS**: đặt `.playback` (giống web) — mở app sẽ dừng nhạc của app khác đang phát. Nếu muốn phát chung với nhạc khác: thêm `options: [.mixWithOthers]` trong `ios/Runner/AppDelegate.swift`. **Cần thử trên iPhone thật**: gạt nút im lặng vẫn nghe giọng đọc; sau khi dùng micro (đọc to) tiếng vẫn bình thường.
4. **Không làm (giữ ➖)**: chuyển khoản/QR "mời cà phê", đo lường lượt dùng, hướng dẫn cài PWA — đề xuất giữ bỏ vì chính sách Kids/Families của App Store & Google Play.
5. Các mục ⚠️ ở mục 6 (hiệu ứng) — làm thêm nếu muốn giống web 100% về cảm giác.

---

## 8. Kết quả test

- `flutter analyze`: sạch (No issues found).
- `flutter test`: **391 test đều qua** (gồm 25 test đối chiếu mới ở `test/parity/`: 647 bài học, 48 game, 185 câu đọc + 77 mẫu câu,
  148 khoá chữ × 2 ngôn ngữ, 21 hiệu ứng, ~3.000 tên hình, 186 bước store đối chiếu với store.js thật, nhớ màn, dừng câu đọc).
- iOS Simulator (iPhone 17 Pro): build debug thành công với `AppDelegate.swift` mới; mở app → màn Bắt đầu → chọn bé chạy bình thường.
  Chưa thử nút im lặng (simulator không có) — cần iPhone thật (mục 7.3).
