# Bé Vui Học — Kế hoạch chuyển web sang app Flutter

Nguồn: https://datpilot.com/kids/ (PWA, JS thuần). Bản tải về nằm ở `reference/web/` (mã JS/CSS/HTML),
tài nguyên (giọng đọc, hình, dữ liệu) đã chuyển vào `assets/`.

## 1. Hiện trạng web

| Thành phần | Quy mô |
|---|---|
| Mã JS | 48 module, ~1,1 MB (app.js 100K, store/audio/sync/i18n/ui, 42 file trong `games/`) |
| Dữ liệu | `content.json` 1 MB (~100 bộ dữ liệu: chữ cái, vần, toán, tiếng Anh, truyện…), `app.json` (đảo, linh vật, sticker, tủ đồ, thú cưng) |
| Giọng đọc | 8.632 mp3 tạo sẵn (108 MB), tra qua `audio.json` + `voice.json` |
| Hình | ~1.000 webp (emoji 3D, ảnh thật, sprite Kenney) |
| Tính năng | 3 cấp học (Mầm/Chồi/Lớp 1), 15 đảo học, Phòng của bé (tủ đồ, thú cưng), Bố con thi tài, Học cùng lớp, Khu vui chơi (đua xe, bắn súng, xe tăng, RPG…), Góc bố mẹ, song ngữ Việt/Anh, đồng bộ nhiều máy bằng "mã gia đình" mã hoá đầu-cuối |

## 2. Công nghệ chọn

| Mảng | Lựa chọn | Lý do |
|---|---|---|
| Framework | Flutter 3.47 / Dart 3 | iOS + Android từ một mã nguồn |
| State | `flutter_riverpod` | Đơn giản, dễ test |
| Điều hướng | `go_router` | Tương ứng các route `#/...` của web |
| Lưu trữ | `shared_preferences` (JSON giống `store.js`) | Giữ nguyên định dạng dữ liệu → đồng bộ được với web |
| Âm thanh | `flutter_soloud` | Độ trễ thấp cho hiệu ứng, phát mp3 giọng đọc, tạo sóng âm thay Web Audio |
| Game hành động | `flame` | Đua xe, bắn súng, xe tăng, RPG cần game loop |
| Vẽ / tập viết / tô màu | `CustomPainter` | Không cần thư viện ngoài |
| Font | Baloo 2 (TTF, OFL) | Giống web |
| Đồng bộ | Giữ API `datpilot.com/api/bvh/sync` + mã hoá PBKDF2/AES-GCM (`cryptography`) | Dùng chung mã gia đình giữa web và app |
| Firebase | Crashlytics, Remote Config, App Check, Storage (gói nội dung sau này) | **Không** dùng Analytics/quảng cáo: app thuộc nhóm Kids/Families của App Store & Google Play |
| CI/Test | `flutter analyze`, `flutter test` (unit + widget), chạy thử trên iOS Simulator | |

## 3. Kiến trúc thư mục

```
lib/
  main.dart, app.dart          # khởi động, router, theme
  core/                        # nền tảng dùng chung (do agent Foundation làm)
    content/   models + loader cho content.json / app.json
    audio/     AudioService (giọng đọc, sfx, nhạc nền)
    store/     hồ sơ bé, sao, tiến độ, sticker, cài đặt (port store.js)
    i18n/      t(), L() song ngữ
    ui/        theme, nút, confetti, toast, overlay, hình emoji, khung màn chơi
    game/      GameModule interface + registry
  features/
    home/ map/ tiers/          # màn đầu, bản đồ đảo, chọn cấp
    learn/                     # các đảo học (mỗi game một thư mục con)
    room/ pet/ duel/ lop1/     # phòng của bé, thú cưng, bố con thi tài, học cùng lớp
    fun/ rpg/                  # khu vui chơi + RPG (Flame)
    parents/ sync/             # góc bố mẹ, đồng bộ
assets/ audio img photo sprites sfx fonts data icon
reference/web/                 # mã web gốc để đối chiếu
```

## 4. Các giai đoạn & phân công agent

**Giai đoạn 0 — Chuẩn bị (xong)**: tải web, tạo project, bộ icon + splash.

**Giai đoạn 1 — Foundation (1 agent, chạy trước)**: toàn bộ `lib/core`, màn đầu, chọn hồ sơ/cấp, bản đồ đảo,
danh sách bài, khung màn chơi + chấm sao, registry chứa sẵn chỗ cho mọi game, khai báo đủ dependency.
Các agent sau chỉ thêm file trong thư mục riêng → không đụng nhau.

**Giai đoạn 2 — Song song (9 agent)**:

| Agent | Phạm vi (file web) |
|---|---|
| A. Ngôn ngữ | pick, quiz, sheets, spell, trace, read |
| B. Toán & khám phá | count, math, life, memory, explore, music |
| C. Tư duy & sáng tạo | logic, code, art, figure |
| D. Phòng của bé | pet, petrig, phòng/tủ đồ/sticker, duel (bố con thi tài), lop1 |
| E. Khu vui chơi 1 | fun, funcore, funfx, funlogic, funmore, funhunt, arcade, motionb |
| F. Khu vui chơi 2 | funnew1–5, funhero |
| G. Game hành động | funracer, funshooter, funtank, funvs1, funvs2 (Flame) |
| H. RPG | rpg, rpgcore, rpgzones1, rpgzones2 (Flame) |
| I. Bố mẹ & nền tảng | Góc bố mẹ (cổng phụ huynh), sync mã gia đình, cài đặt, Firebase |

**Giai đoạn 3 — Tích hợp & kiểm thử**: analyze/test toàn bộ, chạy trên iOS Simulator + Android emulator,
so sánh từng đảo với web, sửa lỗi, tối ưu dung lượng (ảnh/âm thanh).

**Giai đoạn 4 — Phát hành**: Firebase project, ký app, TestFlight / Google Play Internal testing,
chính sách quyền riêng tư cho trẻ em, ảnh chụp cửa hàng.

## 5. Rủi ro

- Dung lượng: giọng đọc 108 MB → app ~130 MB (dưới giới hạn 200 MB của cả hai store). Sau có thể tách gói tải sau qua Firebase Storage.
- Hiệu ứng âm thanh/nhạc web tạo bằng Web Audio → tái tạo bằng SoLoud waveform hoặc render sẵn thành file.
- Chính sách trẻ em: không quảng cáo, không thu thập dữ liệu cá nhân, mọi liên kết ngoài/mua hàng phải qua cổng phụ huynh.
