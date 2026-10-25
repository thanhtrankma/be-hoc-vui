# Bé Vui Học — Rà soát trước khi gửi duyệt App Store (Kids Category)

Ngày rà soát: 25/10/2026. Bản: `1.0.0+1`, bundle `com.iping.bevuihoc`, Flutter 3.47.7, Xcode 26.6 (SDK iOS 26), iOS tối thiểu 15.0,
iPhone + iPad. Căn cứ: App Store Review Guidelines bản hiện hành, App Store Connect Help (age rating mới 4+/9+/13+/16+/18+,
Made for Kids), Firebase "App Store data collection". Đi kèm: `docs/STORE_PRIVACY.md` (khai báo cửa hàng), `assets/legal/*`.

Ký hiệu: 🔴 sẽ bị từ chối nếu không sửa · 🟡 có thể bị hỏi / từ chối tuỳ reviewer · 🟢 ổn.
"Đã sửa" = sửa trong `ios/` ở lượt này. "Dart" = sửa mã trong `lib/` (mục 3) — **tất cả D1–D8 đã làm ngày 25/10/2026**.

**Quyết định của chủ app (25/10/2026):** giữ mọi game Khu vui chơi (bắn quái, xe tăng, võ đài, săn quái, siêu nhân, bắn bia, RPG) →
age rating **9+**, Kids Category age band **6–8** (mục 4.1); App Privacy khai **thận trọng**: User Content → Other User Content (mục 4.3).

## 1. Bảng rủi ro

| # | Mức | Guideline | Vấn đề | Bằng chứng | Trạng thái |
|---|---|---|---|---|---|
| 1 | 🔴→🟢 | 5.1.1, 2.3 | Chuỗi xin quyền chỉ có tiếng Việt, không có bản Anh; app không khai báo hỗ trợ tiếng Việt (chỉ `en`) nên trang App Store ghi "English" dù app chủ yếu tiếng Việt; chuỗi nhận dạng giọng nói không nói rõ chạy trên máy | `ios/Runner/Info.plist:5-8` (cũ), `project.pbxproj` `knownRegions = (en, Base)` | **Đã sửa**: thêm `vi.lproj/InfoPlist.strings`, `en.lproj/InfoPlist.strings` (tên app, micro, nhận dạng giọng nói), `CFBundleLocalizations = [vi, en]` (`Info.plist:13`), `knownRegions += vi`; chuỗi mới nói rõ "chỉ khi bố mẹ đồng ý, nhận dạng ngay trên máy, không ghi âm/không gửi đi" |
| 2 | 🟡→🟢 | Export compliance | Thiếu `ITSAppUsesNonExemptEncryption` → mỗi bản build bị hỏi tay trong App Store Connect / TestFlight | `Info.plist` (cũ) | **Đã sửa**: `ITSAppUsesNonExemptEncryption = NO` (`Info.plist:9`). Lý do ở mục 4.4 |
| 3 | 🟡→🟢 | 5.1.1, 5.1.4, 1.3 | Firebase (Firestore + Installations) mặc định gửi "Firebase user agent"/heartbeat (manifest của SDK khai `OtherDiagnosticData`, mục đích *Analytics*) — trong app Kids có thể bị coi là analytics bên thứ ba | `build/ios/SourcePackages/checkouts/firebase-ios-sdk/Firestore/Source/Resources/PrivacyInfo.xcprivacy`, `FirebaseCore/Sources/FIRApp.m:854-860` (`heartbeatLogger log` chỉ khi `isDataCollectionDefaultEnabled`) | **Đã sửa**: `FirebaseDataCollectionDefaultEnabled = NO` (`Info.plist:11`). Firestore vẫn chạy bình thường; heartbeat không được ghi nên header `x-firebase-client` không mang dữ liệu chẩn đoán. Theo tài liệu Firebase, Firestore/Installations chỉ thu user agent "if data collection is enabled" |
| 4 | 🟡→🟢 | 5.1.2 (privacy manifest) | Target app không có `PrivacyInfo.xcprivacy` riêng | `ios/Runner/` (cũ) | **Đã sửa**: `ios/Runner/PrivacyInfo.xcprivacy` (Tracking = NO, không miền theo dõi, không thu dữ liệu; UserDefaults `CA92.1`, File timestamp `C617.1`), đã thêm vào Copy Bundle Resources. Flutter engine (FileTimestamp `0A2A.1/C617.1`, SystemBootTime `35F9.1`), FirebaseCore/Firestore/Installations, GoogleUtilities, gRPC, abseil, leveldb, nanopb, Promises, shared_preferences, url_launcher, share_plus, file_picker, flutter_soloud **đều tự kèm manifest** (đã thấy trong `build/ios/iphonesimulator/Runner.app/*.bundle`). `speech_to_text` không kèm manifest nhưng không dùng API "required reason" |
| 5 | 🟢 | 1.3, 5.1.4 | Không quảng cáo, không Analytics/Crashlytics/App Check/Remote Config/Messaging; không IDFA, không ATT | `pubspec.yaml:36-41`; binary đã build không có ký hiệu `GoogleAppMeasurement`/`APM*`/`GDTCOR*` (chỉ có lớp cấu hình rỗng `FIRAnalyticsConfiguration` của FirebaseCore). `GoogleService-Info.plist`: `IS_ANALYTICS_ENABLED=false`, `IS_ADS_ENABLED=false` | Ổn. Lưu ý: `Package.resolved` có liệt kê `googleappmeasurement`, `google-ads-on-device-conversion` — chỉ là gói SPM được *resolve* theo `firebase-ios-sdk`, **không được link** |
| 6 | 🟢 | 5.1.4 | FirebaseInstallations được link (firebase_core SPM) | `ios/Flutter/ephemeral/Packages/.packages/firebase_core-4.15.0/Package.swift:32,49` | Ổn: không plugin nào gọi FIS (Firestore iOS không dùng FID), data collection đã tắt. Kiểm lại bằng Xcode → Archive → *Generate Privacy Report*: báo cáo có thể vẫn liệt kê "Other Diagnostic Data" do manifest tĩnh của SDK; hành vi thật không thu — giữ nhãn ở mục 4.3 |
| 7 | 🟢 | 5.1.4 | Lưu lượng mạng khi đồng bộ TẮT | `lib/main.dart:19` gọi `Firebase.initializeApp` (không tạo kết nối); Firestore chỉ được chạm trong `lib/features/sync/firestore_sync_backend.dart:24-28`; `lib/features/sync/sync.dart:136` trả `'off'` khi chưa có mã | Ổn: khi chưa bật đồng bộ app không gửi gì. Cần đo lại trên máy thật bằng Charles/Proxyman nếu muốn chứng minh cho reviewer |
| 8 | 🟢 | 1.3 (parental gate) | Mọi link ra ngoài / chia sẻ / chọn file đều sau khoá bố mẹ | `url_launcher`: chỉ `lib/features/parents/parents.dart:60` (`ParentsIo.openUrl`), gọi từ `info_pages.dart:183` (Chính sách → web), `:272` (trang ảnh Wikimedia), `:314` (Ghi công → web). Các trang này chỉ mở từ Góc bố mẹ (`/parent`, vào qua `ParentButton` `lib/core/ui/parent_gate.dart:113-117`; `kids_screen.dart:34`, `map_screen.dart:99`) hoặc từ màn Bắt đầu sau `parentGate` (`start_screen.dart:36-40`). `share_plus`: `parents.dart:45,62` (Góc bố mẹ), `certificate.dart:154,157` — nút "Khoe" hỏi khoá nếu mở từ màn kết quả (`certificate.dart:214`). `file_picker`: `parents.dart:42,55` (Góc bố mẹ). Không có `mailto:`/`tel:`/`sms:`. Không có URL scheme / Associated Domains → không deep link vào `/parent` | Ổn |
| 9 | 🟢 | 1.3 | Độ khó khoá bố mẹ | `parent_gate.dart:15` 12–49 × 3–9, nhập bằng bàn phím số tự vẽ, sai thì xoá (`:44-46`) | Ổn (phép nhân 2×1 chữ số, kết quả tới 3 chữ số — đúng tinh thần "adult-level task"). **Đã làm D6**: sai thì hỏi phép tính mới, luôn khác phép vừa hỏi (`parent_gate.dart` `_newQuestion`, test `test/core/parent_gate_test.dart`) |
| 10 | 🟢 | 5.1.1 (iv) | Xin quyền đúng lúc dùng, app chạy được khi từ chối | `lib/features/learn/language/read.dart:770-791` (bảng "Bật micro?" → bố mẹ đồng ý → `g.gate`) rồi mới `rec.init()` (`:807`) → hệ thống hỏi micro + nhận dạng giọng nói. Từ chối/không hỗ trợ → `micNA`, bố mẹ bấm "Đúng rồi". Chỉ nhận trên máy: `read.dart:638` (kênh `bvh/speech`, `AppDelegate.swift:22-26` `supportsOnDeviceRecognition`), `:665` `onDevice: true` | Ổn, khớp chính sách mục 4 |
| 11 | 🟡→🟢 | 2.3.10 | Nhắc nền tảng khác trong app iOS: "…trên App Store **hoặc Google Play**…, ví dụ iPad, **Android**" | `lib/features/parents/parents.dart:275` | **Đã sửa (D1)**: `feedbackNote()` trong `parents.dart` — bản iOS chỉ nhắc App Store (+ email), bản Android chỉ nhắc Google Play. Chính sách giữ cách viết trung tính khi mô tả cả hai nền tảng ("Apple trên iPhone/iPad, Google trên Android", "App Store và Google Play (Families)") |
| 12 | 🟡→🟢 | 1.3, 5.1.4 | Menu chọn chữ của iOS trên ô nhập ở màn của bé có "Tra cứu" / "Tìm trên web" / "Chia sẻ…" → mở Safari/bảng chia sẻ **không qua khoá** | `TextField` ở `lib/features/home/new_kid_screen.dart:101` (tên bé), `lib/features/room/pet.dart:254` (tên thú cưng), `lib/core/ui/parent_gate.dart:141` (`promptPanel`) — Flutter mặc định thêm Look Up/Search Web/Share trên iOS | **Đã sửa (D2)**: `lib/core/ui/text_menu.dart` `safeContextMenuBuilder` (chỉ Cắt/Chép/Dán/Chọn tất cả, luôn vẽ menu Flutter — không dùng `SystemContextMenu`), dùng cho mọi `TextField`/`SelectableText` (tên bé, tên thú cưng, `promptPanel` gồm đổi tên bé + nhập mã gia đình, mã đồng bộ, Ghi công). Test `test/core/text_menu_test.dart` quét `lib/` |
| 13 | 🟢 (đã quyết) | 1.3 / 2.3.6 | Nội dung: nhiều mini-game "bạo lực hoạt hình" + vũ khí: Phi thuyền diệt quái (8 loại súng, bom), Xe tăng dũng cảm (đạn, **gọi không kích**, icon mũ lính), Siêu nhân diệt quái vật, Săn quái vật (kiếm), Võ đài (đấm, số sát thương), Bắn bia (súng nước), Đập quái vật, RPG (vũ khí, "hết máu", hoạt ảnh nhân vật chết) | `lib/core/game/fun_games.dart:159-206`, `lib/features/fun/action/funtank.dart:4-5,1267`, `funshooter.dart:4-5`, `funvs1.dart:4-6`, `lib/features/rpg/rpgcore.dart:285,801` | **Chủ app quyết định giữ** các game. Không máu me, không người thật, phong cách hoạt hình → khai trung thực "Cartoon or fantasy violence: Infrequent/Mild" + "Guns or other weapons: Infrequent" = **9+**, age band **6–8** (mục 4.1) |
| 14 | 🟡→🟢 | 1.3 | Màn tạo bé có nút "🔑 Đã có mã gia đình" → tải dữ liệu từ Firestore **không qua khoá** | `lib/features/home/new_kid_screen.dart:58-72,125-133` | **Đã sửa (D3)**: `_join()` gọi `parentGate` trước khi hỏi mã (test `test/widget/new_kid_join_test.dart`) |
| 15 | 🟡→🟢 | 2.3, 4.0 | Phần lớn Góc bố mẹ, bảng micro/mã gia đình, chữ khoe bằng khen chỉ có tiếng Việt dù đã chọn English (reviewer đọc tiếng Anh) | `parents.dart:273-306` (Góp ý, Giới thiệu cho bạn bè), `new_kid_screen.dart:60,70,132`, `certificate.dart:145,198,207` | **Đã sửa (D4)**: bản tiếng Anh cho Góp ý / Giới thiệu cho bạn bè / toast / Báo cáo của con / Sao lưu lỗi (`parents.dart`), nút + bảng nhập mã + thông báo (`new_kid_screen.dart`), chữ khoe + nút + toast bằng khen (`certificate.dart`, `kAppPitchEn`). Còn tiếng Việt: thẻ "Dùng trên nhiều máy" (`sync_card.dart`) và chữ vẽ trên ảnh bằng khen — ghi trong mục 4.5 |
| 16 | 🟡→🟢 | 5.2.1 | 5 ảnh CC BY / CC BY-SA thiếu tên tác giả (`by` rỗng → dòng ghi công trống tên) — giấy phép BY bắt buộc ghi tác giả | `assets/data/photos.json`: Fire engine (BY-SA 3.0), Gloves (BY 4.0), Handbag (BY-SA 4.0), Potato (BY-SA 2.0), Shower (BY-SA 3.0); hiển thị `info_pages.dart:265` | **Đã sửa (D5)** theo Commons API (wikitext trang tệp): Fire engine → Nick Precision (English Wikipedia), Gloves → Auckland War Memorial Museum, Handbag → Monica Ho, MoMu – Fashion Museum Antwerp, Potato → Robin Corps (Flickr), Shower → DO'Neil (English Wikipedia); thêm 2 ảnh CC0 của The Metropolitan Museum of Art. Ghi công trong app + trang web: giấy phép có link creativecommons.org, ghi chú "ảnh đã thu nhỏ/cắt và đổi sang WebP". Không phải bỏ ảnh nào |
| 17 | 🟢 | 5.2 | Tài sản bên thứ ba | Fluent Emoji (MIT), Kenney (CC0), OpenGameArt pzUH/Bevouliin (CC0), Baloo 2 (OFL), tiếng thú Wikimedia (PD/CC0/CC BY-SA 3.0 có ghi tác giả) — `assets/sprites/CREDITS.txt`, `assets/sfx/CREDITS.txt`, `info_pages.dart:283-294`. "Man superhero", "Princess" là emoji chung của Microsoft, không phải nhân vật có thương hiệu; không thấy Disney/Marvel/Nintendo… | Ổn |
| 18 | 🟢 | 2.1 | Màn "Đang xây dựng", nút "Xong bài", "Thắng (thử)" | `lib/core/game/placeholder.dart:59,84,105` | Không tới được trong bản phát hành: chỉ test dùng (`test/widget/app_flow_test.dart:24-26`); `registry.dart:64,85` chỉ trả `debug*Overrides` khi test gán; không đảo nào `soon: true` trong `app.json`; route lạ → `StartScreen` (`app_router.dart:133`). **Đã làm (D7)**: chuyển sang `test/widget/placeholder.dart` (chỉ test dùng), không còn trong binary |
| 19 | 🟢 | 3.1, 3.2.2 | Thanh toán | Thẻ "Mời cà phê"/QR đã bỏ (`parents.dart:4`); không IAP, không link quyên góp; "xu"/"sao" chỉ là phần thưởng trong game | Ổn |
| 20 | 🟢 | 4.2 | Chức năng tối thiểu | 15 đảo học, ~48 mini-game, RPG, phòng của bé, báo cáo bố mẹ; nội dung offline đầy đủ | Ổn |
| 21 | 🟢 | 4.0 / iPad | Hướng màn & đa nhiệm | `Info.plist:69-80`: iPad đủ 4 hướng, không `UIRequiresFullScreen` → hỗ trợ Split View/Stage Manager (test quét tràn 320dp, ngang); iPhone dọc + 2 ngang; `UILaunchStoryboardName` có; UIScene lifecycle (`SceneDelegate.swift`, yêu cầu từ sau iOS 26) có | Ổn. Nên thử Stage Manager cửa sổ nhỏ trên iPad thật |
| 22 | 🟢 | 2.5.1, 2.5.2 | API công khai, không tải mã | Kênh native duy nhất `bvh/speech` dùng `SFSpeechRecognizer.supportsOnDeviceRecognition` (public). Không tải mã/JS; cờ tính năng là hằng số (`firebase_setup.dart:14-21`) | Ổn |
| 23 | 🟢 | 4.5 | Dịch vụ Apple | Không dùng Game Center/Push/Sign in with Apple; không đăng nhập nên **không cần** Sign in with Apple (4.8) | Ổn |
| 24 | 🟢 | 1.5 | Thông tin nhà phát triển | Support URL https://bevuihoc-app.web.app/ (200, có email `beatgone2503@gmail.com`), Privacy URL https://bevuihoc-app.web.app/privacy (200); trong app: Góc bố mẹ → Chính sách / Giới thiệu (`about_*.md` có email) | Ổn |
| 25 | 🟢 | 5.1.1 (v) | Xoá dữ liệu | Xoá bé `parents.dart:165`; "Xoá bản trên máy chủ" `sync_card.dart:91`; gỡ app xoá dữ liệu máy. Không có tài khoản nên không cần "xoá tài khoản" | Ổn |
| 26 | 🟢 | Kỹ thuật | Icon, version, ATS, background | Icon 1024 không alpha, đủ cỡ iPhone/iPad (`AppIcon.appiconset/Contents.json`); `CFBundleDisplayName` "Bé Vui Học"; `CFBundleName` đổi từ `be_vui_hoc` → "Bé Vui Học" (**đã sửa**); version/build lấy từ `pubspec.yaml` `1.0.0+1`; không `NSAppTransportSecurity` ngoại lệ (chỉ HTTPS); không `UIBackgroundModes`; deployment target 15.0; Xcode 26.6 / SDK iOS 26 (đáp ứng yêu cầu SDK 2026) | Ổn. Lưu ý mỗi lần nộp lại phải tăng build `+N` |
| 27 | 🟢 | Âm thanh | Nút gạt im lặng | `AppDelegate.swift:14` đặt `.playback` → gạt im lặng vẫn nghe giọng đọc. Hợp lý cho app học bằng giọng nói; sẽ dừng nhạc app khác | Ổn. Cần thử iPhone thật: sau khi dùng micro (speech_to_text đổi sang `playAndRecord`) tiếng có còn ra loa ngoài và còn bỏ qua nút im lặng không |
| 28 | 🟢 | Dung lượng | | Tài sản 82 MB (giọng đọc 60 MB Opus); dự kiến IPA ~110–130 MB, dưới giới hạn tải qua mạng di động | Ổn |
| 29 | 🟢 | iPad share | `share_plus` trên iPad không truyền `sharePositionOrigin` (`parents.dart:62`) | share_plus 13.3.1 tự đặt popover giữa màn (`FPPSharePlusPlugin.m:435-442`) → không crash | Ổn (có thể truyền origin cho đẹp) |
| 30 | 🟡→🟢 | 5.1.1 | Chính sách nói "If parents do not turn sync on, the app sends no data to any server" — đúng; nhưng khi bật đồng bộ Google vẫn thấy địa chỉ IP kết nối (nhật ký kỹ thuật) | `assets/legal/privacy_en.md` mục 2–3 | **Đã sửa (D8)**: chính sách mục 2 (vi/en, hiệu lực 25/10/2026) nêu Google thấy/xử lý IP khi đồng bộ kết nối, chúng tôi không lưu/dùng; thêm đoạn "Khai báo trên cửa hàng" khớp nhãn thận trọng |

Không có mục 🔴 nào còn mở. Hai quyết định đã chốt (25/10/2026): độ tuổi/nhãn bạo lực → **9+, age band 6–8** (4.1); App Privacy → **khai thận trọng** (4.3).

## 2. Đã sửa trong `ios/` (lượt này)

| File | Thay đổi |
|---|---|
| `ios/Runner/Info.plist` | Thêm `ITSAppUsesNonExemptEncryption = NO`, `FirebaseDataCollectionDefaultEnabled = NO`, `CFBundleLocalizations = [vi, en]`; `CFBundleName` = "Bé Vui Học"; viết lại `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` (chỉ khi bố mẹ đồng ý, nhận dạng trên máy, không ghi âm, không gửi đi) |
| `ios/Runner/vi.lproj/InfoPlist.strings` (mới) | Tên app + 2 chuỗi quyền, tiếng Việt |
| `ios/Runner/en.lproj/InfoPlist.strings` (mới) | Tên app + 2 chuỗi quyền, tiếng Anh |
| `ios/Runner/PrivacyInfo.xcprivacy` (mới) | Manifest của app: không tracking, không thu dữ liệu, UserDefaults `CA92.1`, File timestamp `C617.1` |
| `ios/Runner.xcodeproj/project.pbxproj` | Thêm 2 file trên vào nhóm Runner + Copy Bundle Resources (nhóm biến thể `InfoPlist.strings` vi/en), `knownRegions += vi` |

Kiểm: `flutter build ios --simulator --debug` → ✓ (65 s); bundle có `en.lproj/`, `vi.lproj/`, `PrivacyInfo.xcprivacy`, các key mới trong `Info.plist`.
`flutter analyze` → No issues found. Không sửa `lib/`, không commit.

## 3. Việc sửa mã Dart — **đã làm hết (25/10/2026)**

- **D1 (2.3.10)** ✅ `parents.dart` `feedbackNote()`: iOS chỉ "App Store", Android chỉ "Google Play"; có email `beatgone2503@gmail.com`
  (chữ, không phải link `mailto:`). Test: `test/features/parents/parents_test.dart` "góp ý theo nền tảng".
- **D2 (1.3)** ✅ `lib/core/ui/text_menu.dart` `safeContextMenuBuilder` cho mọi `TextField`/`SelectableText` (kể cả Ghi công, mã đồng bộ):
  chỉ Cắt/Chép/Dán/Chọn tất cả; bỏ Look Up / Search Web / Share / Live Text (iOS) và mục "process text" như Dịch (Android).
  Luôn vẽ `AdaptiveTextSelectionToolbar` của Flutter, không dùng `SystemContextMenu`. Test: `test/core/text_menu_test.dart`.
- **D3 (1.3)** ✅ `new_kid_screen.dart` `_join()`: `parentGate` trước khi hỏi mã gia đình.
- **D4 (2.3/4.0)** ✅ Song ngữ `parents.dart` (Góp ý, Chia sẻ, Chép link, toast, Báo cáo của con), `new_kid_screen.dart`, `certificate.dart`.
- **D5 (5.2.1)** ✅ `assets/data/photos.json` đủ tác giả; Ghi công có link giấy phép + ghi chú "đã thu nhỏ/cắt". Trang web đã build lại.
- **D6 (1.3)** ✅ Khoá bố mẹ: sai thì đổi phép tính mới (khác phép vừa hỏi).
- **D7 (2.1)** ✅ `placeholder.dart` chuyển sang `test/widget/`.
- **D8 (5.1.1)** ✅ Chính sách mục 2 nói về địa chỉ IP khi đồng bộ.
- Thêm: `ios/Runner/PrivacyInfo.xcprivacy` khai `NSPrivacyCollectedDataTypeOtherUserContent` (không liên kết, không tracking,
  App Functionality) để Privacy Report khớp nhãn 4.3.

## 4. Câu trả lời App Store Connect

### 4.1 Age rating (bảng câu hỏi mới 2025) + Kids age band — **ĐÃ CHỌN: giữ game hành động → 9+, age band 6–8**

Theo định nghĩa của Apple: 4+ = không có nội dung phản cảm; **9+ gồm "Infrequent cartoon or fantasy violence" và "Infrequent guns or other weapons"**.
Chỉ app 4+ hoặc 9+ mới được chọn "Made for Kids"; chọn rồi **không đổi lại được** sau khi được duyệt.

| Câu hỏi | Trả lời |
|---|---|
| In-app controls: Parental controls | **Yes** (Góc bố mẹ: giới hạn thời gian, khoá) · Age assurance: No |
| Capabilities: Unrestricted web access | No · User-generated content: No · Messaging/chat: No · Advertising: No |
| Mature/suggestive, Sexual content/nudity, Profanity/crude humor, Horror/fear, Alcohol/tobacco/drugs, Gambling, Simulated gambling, Contests, Loot boxes, Medical/wellness | None / No |
| **Cartoon or fantasy violence** | **Infrequent** (mức nhẹ: quái vật/phi thuyền/xe tăng hoạt hình, võ đài hoạt hình, không máu) |
| Realistic violence | None · Prolonged graphic/sadistic violence: None |
| **Guns or other weapons** | **Infrequent** (súng laser/súng nước, pháo xe tăng, kiếm hoạt hình) |
| Made for Kids | **Yes** → Age band **6–8** |
| Kết quả | **9+** |

Không chọn: phương án "đổi tông/ẩn game để lấy 4+ / 5 & Under" (chủ app giữ các game). Không được khai None cho bạo lực/vũ khí
để lấy 4+ (vi phạm 2.3.6, dễ bị từ chối khi reviewer chơi thử Khu vui chơi).

### 4.2 Category

Primary: **Education**; tích **Kids** → age band như 4.1. Secondary (tuỳ): Games → Educational.

### 4.3 App Privacy (nhãn dinh dưỡng) — **ĐÃ CHỌN: khai thận trọng**

- Tracking: **No** (không ATT, không IDFA).
- **Data Collected: Yes** → chỉ một loại: **User Content → Other User Content** — Purpose: *App Functionality*; Linked to user: **No**;
  Used for tracking: **No**. Nhãn hiển thị: "Data Not Linked to You: User Content". Chỉ xảy ra khi bố mẹ bật đồng bộ tuỳ chọn
  (mặc định tắt); dữ liệu là khối mã hoá đầu-cuối. Bảng trả lời từng câu: `docs/STORE_PRIVACY.md` mục 3.
- Không khai: Diagnostics (đã tắt Firebase data collection), Identifiers (không FID/IDFA), Audio Data (nhận giọng trên máy, không gửi),
  Usage Data, Contact Info, Location. Địa chỉ IP: Google xử lý khi kết nối, chúng tôi không lưu/dùng — nêu trong chính sách (D8).
- `ios/Runner/PrivacyInfo.xcprivacy` khai cùng loại dữ liệu (khớp nhãn).
- Privacy Policy URL: `https://bevuihoc-app.web.app/privacy` · Support URL: `https://bevuihoc-app.web.app/` · Marketing URL: (để trống hoặc như Support).
- Không chọn: "Data Not Collected".

### 4.4 Export compliance

`Info.plist` đã có `ITSAppUsesNonExemptEncryption = NO` → App Store Connect/TestFlight không hỏi lại mỗi build, không cần tải tài liệu.
Căn cứ: app dùng (1) HTTPS/TLS qua Firestore/gRPC — được miễn; (2) AES-256-GCM + PBKDF2 + SHA-256 (thuật toán chuẩn, `package:cryptography`)
chỉ để bảo vệ bản sao dữ liệu học của chính người dùng khi đồng bộ. Chức năng chính của app là giáo dục, không phải bảo mật thông tin /
truyền thông / máy tính; phần mã hoá hỗ trợ chức năng đó → thuộc **Note 4 của Category 5 Part 2 (EAR)**, không phải nộp báo cáo năm (self-classification) hay CCATS.
Nếu App Store Connect vẫn hỏi (ví dụ khi tạo app): *Does your app use encryption?* **Yes** → *Does your app qualify for any of the
exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations?* **Yes** (Note 4: mã hoá chỉ hỗ trợ chức năng
chính không phải bảo mật). Không dùng thuật toán tự chế. Nếu chủ app không chắc về Note 4 thì lựa chọn thay thế là trả lời theo diện
mass-market 5D992.c (phải nộp self-classification report hằng năm cho BIS) — khi đó đổi key thành `YES` và làm theo hướng dẫn của App Store Connect.

### 4.5 App Review Information — ghi chú cho reviewer (dán nguyên văn)

```
Bé Vui Học is a free learning app for children aged 6–8 (Vietnamese phonics, reading, maths, English, music, drawing, logic),
designed for the Kids Category (age band 6–8). The Game zone has a few mild cartoon action mini-games (space shooter,
toy tank, cartoon boxing, monster hunt) - declared as Infrequent cartoon/fantasy violence and Infrequent weapons (9+). No account or login, no ads, no in-app purchases, no analytics, no tracking, no device identifiers.

LANGUAGE: the app opens in Vietnamese. To switch to English: tap "Bắt đầu" (Start) → create a child (type any name, e.g. "Test",
then pick a mascot) → on the island map tap the "⚙ Bố mẹ" (Parents) button → pass the parental gate → Settings → Language → English.
A few parent-area texts (the family sync card) and the drawn certificate image are Vietnamese only.

PARENTAL GATE: every grown-up area — Parents area, About/Credits/Privacy pages (also on the Start screen), external links,
the share sheet, backup files, family sync and the microphone — is behind a gate asking for a multiplication such as "23 × 4 = ?".
Type the product on the on-screen keypad and tap OK (a wrong answer shows a new question). Entering a family code on the
"create child" screen is also behind the gate. Text-selection menus have no Look Up / Search Web / Share.

MICROPHONE / SPEECH: only used in Reading → "Read aloud" ("Đọc to"). A parent first confirms "Parents agree" and passes the gate;
only then does iOS ask for Microphone and Speech Recognition. Recognition is forced on-device (requiresOnDeviceRecognition);
if the device has no on-device Vietnamese recognizer, the microphone stays off and the parent taps "Correct" instead.
No audio is recorded, stored or sent.

FAMILY SYNC (optional, OFF by default): Parents area → "Dùng trên nhiều máy" (Use on several devices). It stores only an
end-to-end encrypted blob (AES-256-GCM, key derived on device from a random family code that is never sent) in Google Cloud
Firestore; the developer cannot read it. "Xoá bản trên máy chủ" deletes it immediately. With sync off, the app makes no network
requests. Firebase data collection (heartbeat/user agent) is disabled; no Firebase Analytics, Crashlytics or Installations are used.
App Privacy declares this optional sync blob as "Other User Content" (App Functionality, not linked, no tracking).

All content works offline. Privacy policy: https://bevuihoc-app.web.app/privacy
```

Sign-in required: **No** (không cần tài khoản demo). Contact: email `beatgone2503@gmail.com`.

### 4.6 Metadata (2.3)

- Tên: "Bé Vui Học" (≤ 30 ký tự); phụ đề gợi ý: "Học mà chơi cho bé 6–8 tuổi".
- Ngôn ngữ chính trong App Store Connect: **Vietnamese**; thêm bản English cho mô tả.
- Ảnh chụp: chụp từ app thật (iPhone 6.9" và iPad 13"), không chèn logo Google Play/Android, không chụp màn khoá bố mẹ đã mở sẵn đáp án.
- Mô tả không hứa "không thu thập dữ liệu nào" (đã chọn nhãn thận trọng ở 4.3); ghi "không quảng cáo, không mua trong app, không tài khoản".
- Age band 6–8 / 9+: mô tả và ảnh chụp không nhắm bé dưới 6 tuổi (app, chính sách, trang web đều ghi "6–8 tuổi").

## 5. Kiểm trước khi nộp (máy thật)

1. Xcode → Product → Archive → *Generate Privacy Report*: kiểm có `Runner` manifest; nếu còn "Other Diagnostic Data" từ Firestore/FIS thì do manifest tĩnh — hành vi đã tắt.
2. Proxyman/Charles trên iPhone: mở app, chơi vài bài khi đồng bộ tắt → không có request nào tới `firestore.googleapis.com`/`firebaseinstallations.googleapis.com`.
3. Gạt nút im lặng: vẫn nghe giọng đọc; sau bài Đọc to (micro) tiếng vẫn ra loa ngoài.
4. iPad: Split View / Stage Manager cửa sổ nhỏ, xoay 4 hướng, bảng chia sẻ mở được.
5. Đặt iPhone sang tiếng Anh: hộp thoại xin quyền hiện bản tiếng Anh; tiếng Việt: hiện bản tiếng Việt.
6. Tăng build number cho mỗi lần tải lên (`version: 1.0.0+2`, …).
