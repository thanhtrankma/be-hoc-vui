# Hiệu năng — Bé Vui Học (đo, tối ưu, kết quả)

Cập nhật 15/10/2026. Phạm vi: độ mượt (jank), khởi động, bộ nhớ, dung lượng app. Mọi thay đổi giữ nguyên hình và hành vi;
`flutter analyze` sạch và toàn bộ `flutter test` (391 test) đều qua.

## 1. Cách đo

Đo bằng hai cách bổ sung cho nhau.

### 1.1 Trên thiết bị: `integration_test/perf_test.dart`

Chạy trên emulator Android arm64 (AVD "S23", 1080×2340, 480 dpi, `-gpu host` = GPU Apple M1 qua lớp dịch GLES,
Impeller OpenGLES), bản **profile**:

```
flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d emulator-5554
# chỉ vài kịch bản: --dart-define=PERF_ONLY=game_snake,map_scroll ; kết quả: build/perf_<PERF_TAG>.json
```

- **Khung app:** test dựng app giống `main()` (SharedPreferences thật, `loadContentBundle`, `SoloudAudio` thật, chỉ bỏ
  Firebase). Có một bé với 9999 vé và một thú cưng; frame policy là `benchmarkLive`, nên khung hình chạy theo vsync thật.
- **Kịch bản (23):**
  - màn đầu đứng yên, Bắt đầu → bản đồ, cuộn bản đồ, mở đảo + cuộn danh sách bài
  - chơi bài trắc nghiệm (chạm đáp án, bảng thưởng + pháo giấy), tập tô chữ (vẽ ngón tay), vẽ tự do, tô màu
  - phòng thú cưng, cuộn Khu vui chơi
  - 7 game canvas: snake, runner, pacman, match3, breakout, hero, hunt
  - 4 game Flame: racer, shooter, tank, fighter (đối kháng)
  - RPG làng + màn 1
- **Mỗi kịch bản:**
  - Ghi `FrameTiming` gồm build (luồng UI) và raster (luồng GPU), rồi tính trung bình, p90, p99, khung xấu nhất.
  - **Jank %** là tỉ lệ khung có build hoặc raster vượt 16,7 ms.
  - Sau kịch bản ghi thêm RSS (`ProcessInfo.currentRss`) và dung lượng `imageCache`.
- **Âm thanh:** thời gian nạp và giải mã 30 file mp3 giọng đọc ngẫu nhiên bằng `SoLoud.loadAsset`, chính là cách
  `SoloudAudio` nạp khi cần.

**Lưu ý độ tin cậy:**
- Emulator không phải máy thật.
- Raster trên emulator gồm cả thời gian chờ swap/vsync của lớp dịch GLES, nên luôn khoảng ≥16 ms.
- Máy Mac đo đang chạy song song iOS Simulator của agent khác (load average 12–17), nên số tuyệt đối dao động mạnh giữa
  các lượt: giọng đọc nạp 15 ms ở lượt yên tĩnh nhưng 70–107 ms ở lượt bận.

Vì vậy mình đo **xen kẽ A/B**:
- **A** là bản sao mã gốc, được khôi phục đúng các chỗ đã sửa.
- **B** là mã đã tối ưu.
- Chạy theo thứ tự A1 → B1 → A2 → B2 trên cùng emulator rồi lấy **trung bình 2 lượt mỗi bên**.
- Chỉ nên đọc **tỉ lệ tương đối**.

### 1.2 Trên máy tính, không phụ thuộc tốc độ máy: `benchmark/repaint_bench_test.dart`

```
flutter test benchmark/repaint_bench_test.dart
```

Bench dựng app, đứng yên hoặc cuộn/vẽ 60–120 khung, rồi đếm cho mỗi khung:
- **paints/frame**: số RenderObject phải vẽ lại (`debugOnProfilePaint`).
- **pics/frame** và **KB/frame**: số display list (`PictureLayer`) bị ghi lại và số byte lệnh vẽ của chúng.

Đây là việc của luồng UI khi vẽ, cũng là lượng lệnh luồng raster nhận thêm. Kết quả xác định (deterministic) nên so
trước/sau chính xác. Bench nằm ngoài `test/`, không chạy trong `flutter test` mặc định.

Ngoài ra còn dùng:
- `adb shell am start -W` (6 lần cold start / bản release arm64)
- `dumpsys meminfo` lấy mẫu 3 giây/lần trong suốt các lượt A/B
- log thời gian tạm trong `main()` (chỉ ở bản sao, không để lại trong mã)
- dump stack luồng main Android (`kill -3`) lúc khởi động
- phân tích nội dung AAB (`unzip -l`)

## 2. Nút thắt tìm được

| # | Vấn đề | Ảnh hưởng |
|---|---|---|
| 1 | **Hoạt ảnh lặp vô hạn (Bob/Hop/Pulse/mây/tia sáng) dựng lại widget mỗi khung.** Phần lớn nằm trong `LayoutBuilder` (thẻ đảo, `TopBar`…). Một widget con bị bẩn trong `LayoutBuilder` buộc chính `LayoutBuilder` layout lại, kéo lên tận `Scaffold`; mà `RenderObject.layout()` luôn `markNeedsPaint()`. | Bản đồ đảo **đứng yên** vẫn layout + vẽ lại **662 RenderObject / 24 display list (32 KB) mỗi khung**, 60 lần/giây, suốt thời gian mở. |
| 2 | Không có `RepaintBoundary` nào quanh phần chuyển động: thú cưng, bảng vẽ, nét tô chữ, canvas game, làng RPG, pháo giấy, danh sách cuộn. | Mỗi khung game/thú cưng vẽ lại cả màn (thanh chỉ số, nút, HUD). Cuộn Khu vui chơi ghi lại toàn bộ ~50 thẻ game mỗi khung (440 paints/khung). |
| 3 | Mây trời (3 hoạt ảnh) nằm **ngoài** Navigator nên `TickerMode` không dừng được: chạy 60 hình/giây cả khi game toàn màn hình che kín. | Tốn CPU/GPU/pin cho thứ không nhìn thấy; app không bao giờ "đứng yên". |
| 4 | Game Flame (đua xe, bắn súng, xe tăng, đối kháng) và màn RPG **vẫn vẽ 60 hình/giây sau khi xong**, phía sau bảng kết quả (vốn có nền mờ `BackdropFilter`). | Bảng kết quả bị blur lại mỗi khung. |
| 5 | Nền lát ô RPG (rừng, hầm ngục, làng) và nền đất xe tăng phát lại hàng trăm `drawImageRect` mỗi khung (Picture vẫn phải phát lại từng lệnh). | Raster màn RPG cao nhất trong các game (p90 59 ms trên emulator). |
| 6 | Bảng vẽ tự do phát lại **mọi nét** mỗi lần di tay, nên càng vẽ càng chậm. Nét tô chữ chạy `computeMetrics`/`extractPath` cho từng chấm của đường gạch mỗi lần vẽ. | Chậm dần theo số nét; tô chữ tốn CPU khi đứng yên. |
| 7 | Bộ vẽ canvas kiểu web (`canvas2d.dart`, ~25 game) có các chi phí lặp lại: tạo `Path` native mới cho mỗi hạt/chấm, tạo `Paint` mới cho mỗi ảnh, chạy RegExp phân tích font mỗi lần vẽ chữ. Bộ đệm chữ dùng màu sau khi nhân `globalAlpha` làm khoá, nên chữ "+1" mờ dần phải layout lại mỗi khung; khi đầy thì **xoá sạch**, cả chữ HUD cũng phải layout lại cùng lúc (giật). Bộ đệm chữ của `act_core` (game Flame) và `rpgcore` cũng xoá sạch như vậy. | Giật nhịp khi chữ bay nhiều (hero, snake). |
| 8 | Tổng hợp ~22 hiệu ứng + 8 nốt đàn (`renderTones`, gọi `pow()` hai lần mỗi mẫu) chạy **trên isolate UI** lúc mở app, ngay khi màn Bắt đầu đang chạy hoạt ảnh. | 0,5–1,5 s CPU của luồng UI trong những giây đầu. |
| 9 | `PlayScreen` `ref.watch(storeProvider)`: mỗi lần lưu (15 giây/lần đếm giờ chơi, mỗi câu trả lời) dựng lại cả màn chơi và game. | Rebuild thừa. |
| 10 | `assets/icon/` (icon/splash gốc, 4,4 MB) bị đóng gói vào app dù app không dùng lúc chạy. | +4,4 MB dung lượng. |

Những chỗ đã kiểm tra và thấy **không** cần sửa:
- `content.json` đã giải mã ở isolate khác.
- Nhạc nền đã tổng hợp bằng `compute`.
- Giọng đọc có LRU 48 câu, nạp khi cần (15 ms/câu lúc máy rảnh).
- Game canvas không `setState` mỗi khung (đã dùng `CustomPaint(repaint:)`).
- Ảnh canvas giải mã một lần (cache Future).
- Không có MaskFilter blur trong vòng lặp.
- Impeller dùng shader biên dịch sẵn nên không có jank biên dịch shader.

## 3. Đã thay đổi gì (và vì sao)

Các thay đổi đều nhỏ, khoanh vùng, và không đổi hình (cùng lệnh vẽ, cùng điểm ảnh).

**Lõi giao diện (ảnh hưởng mọi màn)**
- `lib/core/ui/motion.dart`:
  - `LoopAnim` bọc `RepaintBoundary` hai lớp: ngoài phần động và quanh `child` tĩnh, nên child chỉ bị dời/xoay chứ không
    ghi lại.
  - Thêm **`LoopAnim.transform`**: một `RenderTransform` nghe thẳng `AnimationController` và chỉ `markNeedsPaint`, không
    dựng lại widget nên **không kéo `LayoutBuilder` layout lại**. Nó hoạt động như `FadeTransition` nhưng cho ma trận.
    `Bob` và `Hop` đã chuyển sang cách này. Ma trận gộp `translate·rotate/scale` quanh tâm bằng đúng
    `Transform.translate(Transform.rotate/scale(child))` cũ.
- `lib/core/ui/sky_background.dart`:
  - Mây có `RepaintBoundary` riêng và dùng `LoopAnim.transform`.
  - Thêm **`SkyCover`**: màn nào che kín nền trời thì mây dừng hẳn (`TickerMode`). Trạng thái cập nhật sau khung hình để
    không báo giữa lúc dựng cây.
- `lib/features/play/fun_play_screen.dart` và `lib/features/rpg/rpg.dart` (`RpgStageScreen`): bọc `SkyCover`. Cả hai
  `Scaffold` đều có nền đục, nên mây vốn đã bị che.
- `lib/core/ui/widgets.dart`: `AppScreen(scroll: true)` có `RepaintBoundary` trong `SingleChildScrollView`, nên khi cuộn
  chỉ dời lớp nội dung đã vẽ.
- `lib/core/ui/overlay.dart`: pháo giấy dùng `CustomPaint(repaint: controller)` trong `RepaintBoundary` (không còn
  `AnimatedBuilder` dựng lại), một `Paint`/`RRect` dùng chung thay vì tạo mới cho mỗi mảnh mỗi khung.
- `lib/features/learn/language/fx.dart` (`Pulse`), `lib/features/home/start_screen.dart` (nút Bắt đầu phập phồng),
  `lib/features/learn/language/quiz.dart` (tia sáng bảng thưởng): chuyển sang `LoopAnim.transform`. Tia sáng vẽ một lần
  rồi chỉ xoay lớp.

**Màn học / phòng**
- `lib/features/learn/creative/art.dart`:
  - Bảng vẽ ghi các nét đã xong thành một `Picture` (đệm theo danh sách nét, vô hiệu khi hoàn tác/xoá) và chỉ vẽ lại nét
    đang vẽ; thêm `RepaintBoundary`.
- `lib/features/learn/language/trace.dart`: nét gạch của chữ và dòng kẻ ô li tính một lần (cache theo `Path`); thêm
  `RepaintBoundary` quanh bảng tô.
- `lib/features/room/pet.dart`: `RepaintBoundary` quanh canvas phòng thú cưng và các thú cưng nhỏ ở màn nhận nuôi.
- `lib/features/play/play_screen.dart`: chỉ `watch` `(activeId, stars)` thay vì cả store.

**Game**
- `lib/features/fun/more/kit/funkit.dart` và `lib/features/fun/hub/funcore.dart`: `RepaintBoundary` quanh canvas game,
  áp dụng cho mọi game canvas.
- `lib/features/fun/more/kit/canvas2d.dart`:
  - Dùng lại một `Path` (`reset()`) và một `Paint` ảnh.
  - Nhớ font gần nhất, `RegExp` để `static`.
  - Bộ đệm chữ thành LRU (bỏ 1/4 mục cũ thay vì xoá hết).
  - Độ mờ chữ làm tròn 1/64. Mắt không phân biệt được, nhưng đây là thay đổi duy nhất **không** trùng từng điểm ảnh:
    chênh tối đa 1/128 độ mờ.
- `lib/features/fun/action/act_core.dart`:
  - Bộ đệm chữ `Txt` thành LRU (dispose mục bị bỏ).
  - Game xong thì `pauseEngine()`: khung cuối vẫn hiện, không vẽ lại phía sau bảng kết quả.
- `lib/features/rpg/rpgcore.dart`: tương tự, gồm `pauseEngine()` khi xong màn và bộ đệm chữ LRU.
- `lib/core/ui/sprite_sheet.dart`:
  - Thêm `flattenPicture()`: chụp một `Picture` tĩnh nhiều lệnh thành **một ảnh ở đúng độ phân giải màn hình**
    (`toImageSync`), trả về Picture chỉ còn 1 lệnh vẽ.
  - Áp dụng cho nền lát ô RPG (`rpgzones1.dart` `TileBg`, `rpg.dart` làng, thêm `RepaintBoundary` cho làng) và nền đất xe
    tăng (`funtank.dart`, vẽ một lần thay vì ~50 `drawImageRect`/khung).

**Âm thanh / khởi động**
- `lib/core/audio/synth.dart` + `soloud_audio.dart`: tổng hợp toàn bộ WAV hiệu ứng/nốt đàn bằng
  `compute(renderSynthBank)` ở isolate khác. Nhạc nền vốn đã làm vậy. Âm thanh tạo ra giống hệt từng mẫu.

**Dung lượng**
- `pubspec.yaml`: bỏ `assets/icon/` khỏi asset của app. Đã kiểm tra không có tham chiếu nào trong `lib/`, `test/`,
  `android/`, `ios/`. `flutter_launcher_icons` và `flutter_native_splash` vẫn đọc file từ ổ đĩa như cũ.
- Thêm `integration_test` + `flutter_driver` (SDK) vào `dev_dependencies`.

## 4. Kết quả trước / sau

### 4.1 Trên máy tính: vẽ lại mỗi khung (xác định, `benchmark/repaint_bench_test.dart`)

| Kịch bản | paints/khung trước → sau | display list ghi lại/khung | KB lệnh vẽ/khung |
|---|---|---|---|
| Màn Bắt đầu đứng yên | 72 → **16** | 3 → **0** | 3,2 → **0** |
| Bản đồ đảo đứng yên | 662 → **46** | 24 → **0** | 31,9 → **0** |
| Bản đồ đảo khi kéo | 662 → **47** | 24 → **0** | 31,9 → **0** |
| Danh sách bài (đảo) đứng yên | 110 → 85 | 5 → 4 | 2,3 → 1,9 |
| Cuộn Khu vui chơi | 440 → **8** | 9,9 → **1** | 7,5 → **0,4** |
| Phòng thú cưng | 172 → **8** | 3 → 1 | 9,9 → 4,7 |
| Tập tô chữ (chờ tô) | 101 → **8** | 4 → **0** | 2,4 → **0** |
| Bảng vẽ (đã 120 nét, đang vẽ) | 82 → **7** | 4 → 1 | 5,5 → 4,3 |

### 4.2 Trên emulator: FrameTiming (ms), trung bình 2 lượt A và 2 lượt B xen kẽ

Mỗi ô ghi trước → sau. **Jank %** = % khung có build hoặc raster > 16,7 ms. Raster trên emulator luôn khoảng ≥16 ms vì
gồm cả thời gian chờ swap (xem 1.1), nên jank % ở đây cao hơn nhiều so với máy thật. Hãy đọc mức giảm, đừng đọc số tuyệt
đối.

| Kịch bản | build TB | build p90 | build p99 | raster TB | raster p90 | raster p99 | jank % |
|---|---|---|---|---|---|---|---|
| Màn đầu đứng yên | 4,5 → 4,0 | 9,5 → 8,3 | 16 → 32¹ | 67 → **32** | 92 → **51** | 133 → 101 | 100 → 83 |
| Bắt đầu → bản đồ | 17,3 → **6,7** | 30,6 → **9,5** | 82 → **35** | 54 → **31** | 87 → **40** | 262 → 154 | 93 → 93 |
| Cuộn bản đồ | 12,9 → **5,9** | 22,1 → **8,7** | 80 → **30** | 35 → 29 | 49 → 40 | 176 → **80** | 93 → 91 |
| Mở đảo + cuộn bài | 5,2 → 4,5 | 8,8 → 8,4 | 27 → 18 | 28 → 26 | 36 → 38 | 107 → 68 | 92 → 83 |
| Trắc nghiệm + pháo giấy | 4,2 → 3,0 | 8,5 → 6,5 | 28 → **17** | 33 → 22 | 52 → **33** | 159 → **70** | 87 → 71 |
| Tô chữ | 3,8 → 3,3 | 7,7 → 6,7 | 19 → 15 | 27 → 25 | 39 → 35 | 75 → 61 | 90 → 82 |
| Vẽ tự do | 3,2 → 2,5 | 6,4 → 5,4 | 19 → 12 | 25 → 24 | 36 → 33 | 64 → 51 | 82 → 85 |
| Tô màu | 3,2 → 2,9 | 6,6 → 6,6 | 16 → 19 | 23 → 23 | 33 → 32 | 60 → 63 | 74 → 68 |
| Phòng thú cưng | 5,9 → 4,2 | 9,5 → 8,0 | 31 → **18** | 30 → 25 | 42 → 34 | 89 → **54** | 97 → 91 |
| Cuộn Khu vui chơi | 4,5 → **2,9** | 7,8 → 6,4 | 20 → 15 | 23 → 26 | 35 → 37 | 60 → 87 | 72 → 78 |
| Snake | 10,3 → 7,8 | 18,2 → 13,7 | 77 → **44** | 26 → 21 | 35 → 31 | 73 → 59 | 90 → **65** |
| Runner | 5,3 → 4,1 | 9,9 → 7,1 | 32 → 29 | 26 → 22 | 38 → 31 | 75 → 64 | 76 → 64 |
| Pacman | 5,3 → 4,4 | 9,4 → 8,5 | 26 → 26 | 28 → 24 | 39 → 33 | 79 → 60 | 92 → 77 |
| Match3 | 4,6 → 3,4 | 8,4 → 6,9 | 25 → **15** | 24 → 21 | 36 → 30 | 83 → **46** | 76 → 66 |
| Phá gạch | 4,8 → 3,1 | 7,5 → 6,3 | 26 → 16 | 38 → **21** | 43 → 31 | 173 → **52** | 94 → **64** |
| Siêu nhân (hero) | 15,3 → **4,9** | 29,0 → **8,7** | 59 → **24** | 85 → **24** | 146 → **33** | 353 → **70** | 89 → 73 |
| Săn quái (hunt) | 3,1 → **1,1** | 6,3 → **2,4** | 17 → 11 | 29 → 23 | 45 → 32 | 128 → **55** | 84 → 80 |
| Đua xe (Flame) | 6,5 → 5,2 | 12,2 → 9,3 | 28 → 28 | 29 → 24 | 42 → 34 | 80 → 58 | 94 → 76 |
| Bắn súng (Flame) | 4,4 → **1,8** | 9,7 → **4,9** | 29 → **10** | 32 → 28 | 49 → 37 | 87 → 60 | 96 → 95 |
| Xe tăng (Flame) | 3,8 → **2,0** | 8,1 → 5,2 | 17 → 14 | 38 → 27 | 57 → **38** | 110 → **68** | 99 → 89 |
| Võ đài (Flame, đối kháng) | 4,5 → 3,5 | 8,9 → 7,3 | 24 → 18 | 21 → 23 | 30 → 33 | 67 → 63 | 65 → 72 |
| RPG làng | 5,7 → **3,4** | 9,8 → **6,1** | 27 → 20 | 28 → 25 | 37 → 33 | 105 → 94 | 92 → 80 |
| RPG màn 1 (rừng) | 5,7 → 3,9 | 10,9 → 7,5 | 34 → **18** | 40 → **21** | 59 → **30** | 140 → **52** | 100 → **63** |

¹ p99 build của màn đầu là 2–3 khung lẻ trong khoảng 3 giây, thường là lúc audio nạp xong; con số này dao động mạnh giữa
các lượt.

Tóm lại:
- Thời gian build trung bình (luồng UI) giảm ở **cả 23/23 kịch bản**: trung bình −33 % (tổng −39 %); bản đồ −55 %,
  shooter −60 %, hunt −65 %, hero −68 %.
- p99 build giảm mạnh nhất ở bản đồ (82 → 35 ms), snake (77 → 44) và hero (59 → 24).
- Raster p90 giảm ở 20/23 kịch bản; RPG màn 1 từ 59 xuống 30 ms nhờ nền lát ô được chụp thành ảnh.
- Hai kịch bản tăng nhẹ (cuộn Khu vui chơi raster, võ đài) nằm trong biên độ dao động của máy đo, vì máy đang bị chia
  CPU/GPU với simulator.

### 4.3 Khởi động

| Chỉ số | Trước | Sau | Ghi chú |
|---|---|---|---|
| Cold start `am start -W` (release arm64, trung vị 5 lần, bỏ lần đầu sau cài) | 3 713 ms | 3 627 ms | Không đổi đáng kể (xem phân tích dưới) |
| Tổng hợp âm thanh trên isolate UI lúc mở app | 0,5–1,5 s CPU trên luồng UI | **0** (chuyển sang isolate khác) | `audio_init_ms` (tổng thời gian tới khi âm thanh sẵn sàng) vẫn khoảng 0,5–2,5 s vì bao gồm cả `loadMem` |
| Thời gian từ `main()` tới khung đầu (perf test, không Firebase) | 193–1 119 ms | 964–1 383 ms | Dao động theo tải máy; không có thay đổi mã ở đoạn này |

Phân tích khởi động (log thời gian tạm trong `main()` + stack của luồng main Android):

| Giai đoạn | Thời gian |
|---|---|
| `SharedPreferences` | 8–70 ms |
| Firebase (`initFirebase`) | **~70 ms** |
| `loadContentBundle` | 1,4–2,5 s, nhưng gần như toàn bộ là **chờ** |
| `jsonDecode` ở isolate | 110–200 ms |
| Tạo model | ~10 ms |

- Thời gian chờ của `loadContentBundle` là do lời gọi asset đầu tiên (`flutter/assets`, xử lý trên luồng platform)
  phải đợi luồng main Android đang kẹt trong `FlutterJNI.nativeSurfaceCreated`, tức engine đang tạo GL context/surface
  cho Impeller. Logcat ghi "Skipped 85 frames".
- Đây là chi phí engine + lớp GLES giả lập của emulator, không phải mã Dart của app. Trên máy thật dùng Vulkan, thời gian
  này khác hẳn, **phải đo lại trên máy thật** (xem mục 6).

### 4.4 Bộ nhớ

Lấy mẫu `dumpsys meminfo` 3 giây/lần trong suốt mỗi lượt (đủ 23 kịch bản):

| | Lượt A1 | Lượt A2 | Lượt B1 | Lượt B2 |
|---|---|---|---|---|
| PSS đỉnh | 250 MB | 249 MB | 246 MB | 248 MB |
| RSS đỉnh | 389 MB | 387 MB | 384 MB | 386 MB |

- RSS cuối mỗi kịch bản (Dart `ProcessInfo.currentRss`): 320 MB ở màn đầu, 340–360 MB ở màn học, 370–385 MB sau khi
  chơi các game. Bản B thấp hơn 2–10 MB ở hầu hết kịch bản.
- `imageCache` lớn nhất khoảng 32 MB, sau khi qua Khu vui chơi và các game.
- Kết luận: bộ nhớ không phải vấn đề trên máy 4 GB+, và các thay đổi không làm tăng bộ nhớ:
  - Ảnh nền RPG chụp sẵn khoảng 10 MB nhưng thay cho Picture cũ.
  - Mây dừng sau game.
- Sprite sheet và ảnh canvas giải mã đầy đủ và giữ suốt phiên (cache toàn cục, không giải phóng). Với máy 2 GB RAM, xem
  khuyến nghị.

### 4.5 Âm thanh

- Giọng đọc mp3 (24 kHz mono 64 kbps, trung vị 10 KB) được `flutter_soloud` nạp theo yêu cầu và giải mã toàn bộ thành PCM.
  Có LRU 48 câu.
- Thời gian nạp một câu:
  - máy rảnh: TB 15,5 ms, p90 24 ms, tối đa 34 ms
  - máy bận: TB 70–107 ms
- Độ trễ này nằm trong khoảng hợp lý cho trẻ bấm rồi nghe đọc. Màn học đã `preload()` các câu sắp đọc.
- Hiệu ứng bấm (sfx) được tổng hợp sẵn trong RAM nên độ trễ chỉ là bộ đệm SoLoud 1024 mẫu.

### 4.6 Dung lượng

| | Trước | Sau |
|---|---|---|
| APK release arm64 | 146,8 MB | **142,7 MB** (−4,1 MB, bỏ `assets/icon/`) |
| AAB (mọi ABI + ký hiệu debug) | 184,9 MB | khoảng 180,5 MB |

Thành phần AAB (chưa nén):

| Phần | Dung lượng |
|---|---|
| Giọng đọc `assets/audio` | 95,7 MB (8 632 file, 108 MB trên đĩa; không có file nào thừa: `audio.json` tham chiếu đúng 8 632/8 632) |
| Thư viện native, mỗi ABI | 25–29 MB |
| Ký hiệu debug | 97 MB, nằm trong `BUNDLE-METADATA`, Google Play **không** tải về máy người dùng |
| Ảnh chụp | 5,9 MB |
| Emoji | 3,4 MB |
| Sprite | 3,2 MB |
| Font | 2,1 MB |
| Dữ liệu | 1,6 MB |

- Dung lượng người dùng thật sự tải về (một ABI) ước khoảng 140 MB.
- Tag ID3 trong mp3 tổng chỉ 0,39 MB nên không đáng xử lý.
- **Chưa** nén lại âm thanh, vì việc đó làm giảm chất lượng (xem khuyến nghị).

## 5. Kiểm tra

- `flutter analyze`: No issues found.
- `flutter test`: **391/391 passed**. Bộ test có 391 test lúc kiểm tra cuối, đã gồm test do agent QA thêm song song.
- `flutter drive --profile` trên emulator: kịch bản đo chạy đủ cả 4 lượt A/B.

## 6. Việc nên làm tiếp (theo thứ tự ưu tiên)

1. **Đo trên máy Android thật cấu hình thấp**, ví dụ Galaxy A0x/A1x 2–3 GB RAM, Mali/PowerVR, cùng một iPhone cũ
   (iPhone 8/XR). Chạy `flutter drive --profile` với kịch bản trên và `am start -W`.
   - Emulator không phản ánh đúng raster và khởi động: phần chờ ~1,5 s lúc tạo surface Impeller GLES là đặc thù emulator.
   - Nếu máy thật vẫn chậm khởi động, xem xét hiện khung đầu sớm hơn (cho `loadContentBundle` chạy song song sau `runApp`,
     hiện splash Flutter) và kiểm tra Impeller Vulkan với `--enable-impeller` hoặc tắt trên dòng máy lỗi.
2. **Dung lượng giọng đọc (95–108 MB)**:
   - (a) Mã hoá lại giọng nói ở 32–40 kbps mono (Opus/Vorbis tốt hơn mp3 ở bitrate thấp, SoLoud đọc được ogg/opus) sẽ
     giảm khoảng 40–55 MB nhưng **có giảm chất lượng**, cần nghe thử với trẻ.
   - (b) Hoặc tách tiếng Anh hay các bộ ít dùng thành gói tải sau: Play Asset Delivery fast-follow/on-demand, iOS On-Demand
     Resources, hoặc Firebase Storage như PLAN.md mục 5.
3. **Giới hạn bộ nhớ ảnh canvas**: `_uiImages` (`emoji_image.dart`) và `_sheets` (`sprite_sheet.dart`) giữ ảnh đã giải
   mã mãi mãi. Sprite sheet cỡ 1500×600 tốn khoảng 3,6 MB mỗi sheet, khoảng 115 MB nếu mở hết game. Nên làm LRU theo byte
   (~48 MB) hoặc `release()` khi rời game. Máy 2 GB có thể bị hệ thống giết app khi chuyển nhiều game.
4. **Panel kết quả có `BackdropFilter` blur toàn màn**: khi panel mở, mọi hoạt ảnh phía dưới (Bob, thú cưng, `Hop` trong
   panel) buộc blur lại mỗi khung. Có thể tạm dừng route phía dưới bằng `TickerMode` khi panel mở. Cách này đổi hình rất
   nhẹ, vì hoạt ảnh sau lớp mờ sẽ đứng yên.
5. **Còn rebuild theo khung ở vài chỗ**:
   - `island_screen.dart` `LevelCard` nhấp nháy bài kế tiếp: dựng lại cả thẻ, 85 paints/khung.
   - `hub/arcade.dart` trò bong bóng và đua: `setState` mỗi khung.
   - `hub/funlogic.dart` Schulte: `setState` 10 lần/giây.
   - `pet_sim.dart` vẽ lại 3 gradient + nền phòng mỗi khung (có thể ghi Picture theo kích thước/ngày-đêm), và
     `setState` cả màn mỗi giây để cập nhật thanh chỉ số.
   - Các `LoopAnim` còn lại dùng `builder`: `rest_screen`, `code.dart`, `music.dart`. Có thể chuyển sang
     `LoopAnim.transform` nếu chúng nằm trong `LayoutBuilder`.
6. **Lưu dữ liệu**:
   - `AppStore.save()` `jsonEncode` toàn bộ store trên isolate UI và ghi SharedPreferences ở mỗi lần lưu; phòng thú cưng
     lưu 5 giây/lần.
   - Gom các lần lưu bằng debounce 1–2 giây, và luôn flush khi app vào nền.
   - Hiện chi phí còn nhỏ vì store chỉ vài chục KB, nhưng sẽ tăng theo lịch sử học.
7. **`canvas2d.dart` đường gạch đứt** (`setLineDash`: viền đấu trường snake, đường ray tàu) vẫn tính `computeMetrics`
   mỗi khung. Có thể cache theo hình dạng path.
8. **`EmojiImage`** giải mã ảnh 256² (ảnh chụp 512²) để hiện ở 26–54 dp. Có thể dùng
   `ResizeImage.resizeIfNeeded(bucket ≥ px vật lý)` để giảm 2–4 lần RAM ảnh. Mình chưa làm vì tổng `imageCache` hiện chỉ
   khoảng 32 MB và cần kiểm tra kỹ các chỗ phóng to (thưởng, `Hop`).

## 7. Tệp liên quan

- Đo trên thiết bị: `integration_test/perf_test.dart`, `test_driver/perf_driver.dart` (kết quả `build/perf_<tag>.json`).
- Đo trên máy tính: `benchmark/repaint_bench_test.dart`.
