# Rà soát chính sách Google Play — Bé Vui Học (Android)

Ngày rà soát: 25/10/2026. Gói `com.iping.bevuihoc`, bản 1.0.0 (versionCode 1). Nhắm **Families** — Target audience **chỉ 6–8 tuổi** (quyết định của chủ app 25/10/2026: giữ mọi game Khu vui chơi).
Data safety: **khai thận trọng** (mục 5.2). Các việc Dart D1–D4 đã làm ngày 25/10/2026 (mục 3).
Căn cứ: mã nguồn hiện tại, manifest sau gộp của bản release
(`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`), `aapt dump` trên
`build/app/outputs/flutter-apk/app-release.apk`, AAB `build/app/outputs/bundle/release/app-release.aab`, cây phụ thuộc
`./gradlew app:dependencies --configuration releaseRuntimeClasspath`, và chạy thử bản release trên emulator S23
(Android API 37, arm64, **trang bộ nhớ 16 KB**).

Ký hiệu: 🔴 sẽ bị từ chối / không tải lên được · 🟡 có thể bị hỏi, cảnh báo hoặc nên sửa · 🟢 ổn.

## 1. Bảng rủi ro

| # | Mức | Chính sách / yêu cầu | Bằng chứng | Trạng thái |
|---|---|---|---|---|
| 1 | 🔴 | App signing — Play từ chối bản ký bằng khoá debug | Chưa có `android/key.properties` + keystore; AAB hiện tại ký `CN=Android Debug` (`keytool -printcert -jarfile app-release.aab`). Cấu hình `android/app/build.gradle.kts:44-63` tự lùi về khoá debug | **Chủ app phải tạo upload key** (mục 4). Đã thêm cảnh báo lúc build khi thiếu key (`build.gradle.kts:58-61`) |
| 2 | 🟢 | Families — SDK quảng cáo (chỉ được dùng Families Self-Certified Ads SDK) | Không có SDK quảng cáo/đo lường: cây phụ thuộc release chỉ có `firebase-common`, `firebase-firestore`, `firebase-components`, `*-interop`, `play-services-base/basement/tasks`, `grpc-*`, `protobuf-javalite`, `guava`; **không** có `play-services-ads*`, `firebase-analytics`, `measurement`, `firebase-installations`, `crashlytics`, `datatransport` | Ổn |
| 3 | 🟢 | Families — không dùng AAID (`AD_ID`) | `aapt dump permissions app-release.apk`: chỉ `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE`, `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (quyền nội bộ của androidx). Không có `AD_ID` | Đã thêm `tools:node="remove"` cho `AD_ID` để chặn hẳn nếu sau này có thư viện kéo vào (`AndroidManifest.xml:7`) |
| 4 | 🟢 | Families — vị trí, Android ID, định danh thiết bị | Không có quyền vị trí; `grep` mã Dart/Kotlin không có `ANDROID_ID`, `Settings.Secure`, AAID, FID. Remote Config/Installations đã gỡ | Ổn |
| 5 | 🟢 | Families / User Data — dữ liệu gửi đi khi **đồng bộ TẮT** | `SyncService.init` chỉ gọi mạng khi `code != null` (`lib/features/sync/sync.dart:211-240`); Firestore chỉ được tạo khi đồng bộ (`firestore_sync_backend.dart:24-35`). Chạy bản release trên emulator: tạo hồ sơ, vào bản đồ, mở đảo, mở Đọc to → `/proc/net/{tcp,tcp6,udp,udp6}` không có socket nào của uid app; `dumpsys netstats --poll` không có byte nào trong phiên 25/10 (chỉ có số liệu cũ ngày 15/10 của bản còn Remote Config) | Ổn |
| 6 | 🟢 | User Data — đọc to chỉ nhận giọng **trên máy** | Dart hỏi kênh `bvh/speech` trước (`read.dart:631-641`); `MainActivity.kt:15-20` trả `SDK>=31 && SpeechRecognizer.isOnDeviceRecognitionAvailable`. Plugin `speech_to_text 7.5.0` (`SpeechToTextPlugin.kt:623-637`) với `onDevice: true` dùng **cùng điều kiện** → luôn tạo `createOnDeviceSpeechRecognizer`, không có đường lùi sang bản mạng trong trường hợp này. Android < 12 hoặc không có bộ nhận tại chỗ → micro tắt, bố mẹ chấm. Không ghi âm/lưu file | Ổn (xem 🟡 #12 về gói ngôn ngữ) |
| 7 | 🟢 | Quyền `RECORD_AUDIO` — xin lúc dùng, có giải thích, app chạy khi bị từ chối | Thử trên emulator: bấm 🎤 → bảng "Bật micro?" giải thích rõ (giọng nhận ngay trên máy, không ghi âm) → "Bố mẹ đồng ý" → khoá bố mẹ (15 × 9) → hộp quyền hệ thống. Chọn "Don't allow" → app báo "Máy này chưa nghe được giọng. Bố mẹ nghe bé đọc rồi chấm giúp nhé", vẫn chơi tiếp được | Ổn |
| 8 | 🟢 | Quyền nhạy cảm (`QUERY_ALL_PACKAGES`, SMS, Call log, ảnh/video, thông báo, `BLUETOOTH_CONNECT`) | Không có trong manifest gộp. `<queries>` chỉ có `RecognitionService`, `PROCESS_TEXT` (engine Flutter), `GET_CONTENT` (file_picker) | Đã thêm `tools:node="remove"` cho `BLUETOOTH_CONNECT` (plugin speech xin kèm nếu có khai báo) |
| 9 | 🟢 | Parental gate trước link ngoài / chia sẻ / quyền | `parentGate` 2 chữ số × 1 chữ số, đáp số 36–441 (`lib/core/ui/parent_gate.dart:14-24`). Có gate: Góc bố mẹ (`ParentButton`), Giới thiệu/Ghi công ở màn Bắt đầu (`start_screen.dart:36-40`), chia sẻ bằng khen phía bé (`certificate.dart:210`), micro (`read.dart` `_consent()`, gọi `g.gate`), chơi miễn phí (`fun.dart:192`), chọn tuần Lớp 1. Mọi `launchUrl`/`share` chỉ nằm trong `parents.dart`, `info_pages.dart`, `certificate.dart` (sau gate) | Ổn |
| 10 | 🟡→🟢 | Parental gate — nhập **mã gia đình** ở màn tạo bé | `new_kid_screen.dart:58-64`: nút "🔑 Đã có mã gia đình" mở ô nhập và gọi `sync.join()` (đọc Firestore) **không qua gate**. Chỉ gửi băm của mã, không có dữ liệu cá nhân, nhưng là tính năng của bố mẹ + kết nối mạng do trẻ kích hoạt | **Đã sửa (D1)**: `_join()` gọi `parentGate` trước khi hỏi mã; chữ song ngữ (test `test/widget/new_kid_join_test.dart`) |
| 11 | 🟡→🟢 | Quyền micro bị xin lại không qua gate | `read.dart:771`: khi `bvh.micOK == '1'` thì bỏ qua gate; nếu bố mẹ đã từ chối quyền hệ thống, lần bấm 🎤 sau `rec.init()` lại bật hộp quyền → **bé tự bấm "Allow"** được | **Đã sửa (D2)**: `rec.init()` thất bại/bị từ chối → đặt `bvh.micOK = '0'`, lần bấm 🎤 sau phải qua lại bảng "Bật micro?" + khoá bố mẹ rồi mới hỏi quyền hệ thống (test `read_test.dart` "quyền micro bị từ chối"). Thêm `options: [SpeechToText.androidNoBluetooth]` (D3) |
| 12 | 🟡 | Mô tả "nhận giọng trên máy" khi máy chưa có gói tiếng Việt | Bộ nhận tại chỗ có nhưng thiếu gói `vi-VN` → lỗi `language_unavailable` → `micNA` (không gửi mạng). Đúng chính sách, chỉ là trải nghiệm | Không cần sửa; có thể ghi rõ trong mô tả |
| 13 | 🟢 | Backup — dữ liệu trẻ lên Google Drive | Trước: `allowBackup` mặc định `true` → Auto Backup đẩy `shared_preferences` (tên bé, tiến độ, **mã gia đình**) lên Drive, trái với câu "không gửi đi đâu" trong chính sách | **Đã sửa**: `android:allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules` loại trừ mọi thứ khỏi cloud-backup, chỉ cho chuyển máy trực tiếp (`res/xml/data_extraction_rules.xml`) |
| 14 | 🟢 | Cleartext traffic | Mặc định tắt (target 36); đã ghi rõ `android:usesCleartextTraffic="false"`. Mọi URL là https | Ổn |
| 15 | 🟢 | `debuggable` | `aapt dump xmltree` bản release: không có `android:debuggable` | Ổn |
| 16 | 🟢 | Component exported | Chỉ `MainActivity` (LAUNCHER) và `ProfileInstallReceiver` (chặn bằng quyền `DUMP`, chuẩn androidx). Provider/receiver của share_plus, Firebase đều `exported=false` | Ổn |
| 17 | 🟢 | Target API level (yêu cầu 2026: API 36 cho app mới/cập nhật) | `targetSdkVersion=36`, `compileSdk=36` (Flutter 3.47.7 mặc định, `FlutterExtension.kt:23,34`) | Ổn |
| 18 | 🟢 | minSdk | 24 (Android 7.0). Đọc to cần API 31+, máy cũ tự chuyển bố mẹ chấm | Ổn |
| 19 | 🟢 | 64-bit | `native-code: arm64-v8a armeabi-v7a x86_64` | Ổn |
| 20 | 🟢 | Trang bộ nhớ 16 KB (bắt buộc với target 35+ từ 11/2025) | `llvm-readelf -l`: mọi `.so` (libflutter, libapp, libflutter_soloud_plugin, libopus/ogg/vorbis/FLAC, libdartjni, libdatastore_shared_counter) có LOAD align 0x4000 hoặc 0x10000; `zipalign -c -P 16 -v 4 app-release.apk` → "Verification successful", `extractNativeLibs=false`. Chạy thật trên emulator `PAGE_SIZE=16384`: khởi động OK | Ổn |
| 21 | 🟢 | Edge-to-edge (Android 15+) | App vẽ dưới thanh trạng thái, nội dung trong SafeArea (ảnh chụp emulator) | Ổn |
| 22 | 🟡→🟢 | Edge-to-edge — API đã lỗi thời | `lib/main.dart:17` đặt `statusBarColor: Colors.transparent` → engine gọi `Window.setStatusBarColor` (deprecated từ API 35). Play Console có thể hiện khuyến nghị "uses deprecated APIs for edge-to-edge" (không chặn duyệt) | **Đã sửa (D4)**: `main.dart` không đặt `statusBarColor` nữa (chỉ `statusBarIconBrightness`); riêng Android ≤ 14 (API < 35, hỏi qua kênh `bvh/system` trong `MainActivity.kt`) vẫn đặt trong suốt để giữ nguyên giao diện. Lưu ý: chính engine Flutter (`FlutterActivity`) vẫn chứa lời gọi `setStatusBarColor`, nên Play Console có thể vẫn hiện khuyến nghị này — không chặn duyệt |
| 23 | 🟢 | Predictive back (Android 16, target 36 bật mặc định) | Emulator API 37: mở đảo "Chữ cái" → phím Back → về bản đồ (không thoát app). PopScope ở `widgets.dart:208` | Ổn |
| 24 | 🟢 | Kích thước AAB (base ≤ 200 MB nén khi tải) | AAB 139,3 MB gồm 3 ABI + 37,5 MB debug symbols + 1,7 MB mapping (metadata, không tải về máy). Phần base cho một máy ≈ assets 58,2 + lib 11,6 + res 3,0 + dex 1,1 ≈ **74 MB** nén (bundletool không có sẵn, ước tính từ `unzip -lv`) | Ổn |
| 25 | 🟢 | R8 / obfuscation | Release bật R8 (mặc định Flutter); mapping + native symbols tự nằm trong `BUNDLE-METADATA` → Play tự nhận. Bản release khởi động, chạy đảo học, Đọc to bình thường | Ổn. Nên thử đồng bộ thật một lần trên bản release (Firestore + R8) trước khi phát hành |
| 26 | 🟢 | Máy không có Google Play services | Firebase core khởi động không cần GMS; lỗi được bắt (`firebase_setup.dart:66-73`), đồng bộ báo "offline". Không có màn bắt cài GMS | Ổn (chưa thử trên máy không GMS) |
| 27 | 🟢 | versionCode / versionName | `1` / `1.0.0` từ `pubspec.yaml: version: 1.0.0+1`. Mỗi lần tải lên phải tăng `+N` | Ổn |
| 28 | 🟡 | Nội dung cho trẻ — mini-game hành động | `fun_games.dart:159-188`: Săn quái vật, Phi thuyền diệt quái, Siêu nhân diệt quái vật, Đập quái vật, Bắn bia (súng nước), Xe tăng dũng cảm, Võ đài (đấm, thanh máu, KO — `funvs1.dart:126-238`), Đấu sumo, Ném tuyết. Hình hoạt hình Kenney/Fluent (xe tăng nhìn từ trên, phi thuyền, thiên thạch), không máu, không vũ khí thật. Phù hợp Families nhưng **phải khai thật** trong IARC → nhiều khả năng PEGI 7 / ESRB E (Mild Fantasy Violence). Không cản duyệt; giảm khả năng **Teacher Approved** | **Chủ app giữ các game** → Target audience chỉ **6–8** (mục 5.1), khai đúng IARC (mục 5.5) |
| 29 | 🟢 | Sở hữu trí tuệ / mạo danh | Ảnh Wikimedia: `assets/data/photos.json` có `by`, `lic`, `src` cho 230 ảnh (5 ảnh CC BY/BY-SA thiếu tác giả đã điền 25/10/2026; giấy phép có link, ghi chú "đã thu nhỏ/cắt"), hiện ở Ghi công với link từng trang ảnh (`info_pages.dart:267-272`, sau gate). Fluent Emoji (MIT), Kenney/OpenGameArt (CC0), Baloo 2 (OFL) ghi ở `assets/legal/about_*.md`. Tên game nội bộ `pacman`/`tron` nhưng tên hiển thị là "Ăn đậu né ma"/"Mô tô ánh sáng" | Ổn. Không dùng chữ "Pac-Man", "Tron", logo Zalo/Facebook trong ảnh cửa hàng |
| 30 | 🟢 | Misleading claims | About/chính sách nói "không quảng cáo, không mua trong app, không tài khoản, chạy offline" — đúng với mã | Ổn. Không ghi "Teacher Approved"/"COPPA certified" trong mô tả |
| 31 | 🟢 | Xoá tài khoản (Account deletion) | Không có tài khoản → khai "No" ở câu tạo tài khoản; không cần URL xoá tài khoản | Ổn |
| 32 | 🟢 | Xoá bản đồng bộ | Góc bố mẹ → Dùng trên nhiều máy → "Xoá bản trên máy chủ" (`sync.dart:198-206`, `backend.delete`) | Ổn |
| 33 | 🟢 | Chính sách quyền riêng tư (trong app + Play Console) + email | https://bevuihoc-app.web.app/privacy trả 200 (bản deploy cũ "19/10/2026"; bản mới "Ngày hiệu lực: 25/10/2026" đã build trong `hosting/public/`, chờ deploy), có email `beatgone2503@gmail.com`; bản EN `/privacy/en` 200. Trong app: Góc bố mẹ → Chính sách (`parents.dart:328`) | Ổn |
| 34 | 🟢 (đã quyết) | Data safety khi có Firestore | Bản đồng bộ là khối mã hoá đầu-cuối, nhà phát triển không đọc được → thuộc ngoại lệ mã hoá đầu-cuối của Data safety; IP chỉ Google xử lý (Firestore không bật Data Access audit log). Hợp lý nhưng reviewer có thể hỏi vì app có `INTERNET` + Firestore | **Đã chọn khai thận trọng** (mục 5.2): App activity → Other user-generated content, Collected, Optional, App functionality. Chính sách (hiệu lực 25/10/2026) có đoạn "Khai báo trên cửa hàng" khớp và nói về địa chỉ IP |
| 35 | 🟢 | Trẻ nhập tên | Tên gọi ≤ 20 ký tự lưu trên máy, không gửi đi (trừ trong khối mã hoá khi bố mẹ bật đồng bộ) | Ổn |

## 2. Đã sửa (chỉ trong `android/`)

1. `android/app/src/main/AndroidManifest.xml`
   - Thêm `xmlns:tools`; `<uses-permission ... AD_ID tools:node="remove"/>` và `BLUETOOTH_CONNECT tools:node="remove"`.
   - `<application>`: `android:allowBackup="false"`, `android:fullBackupContent="false"`,
     `android:dataExtractionRules="@xml/data_extraction_rules"`, `android:usesCleartextTraffic="false"`,
     `tools:replace="android:allowBackup"`.
2. Mới: `android/app/src/main/res/xml/data_extraction_rules.xml` — Android 12+: loại mọi miền khỏi `cloud-backup`; `device-transfer`
   chỉ mang `sharedpref` (chuyển máy trực tiếp, không qua máy chủ).
3. `android/app/build.gradle.kts` — khi thiếu `key.properties`, in cảnh báo "bản release đang ký bằng KHOÁ DEBUG — KHÔNG tải lên Google
   Play" (vẫn build được để chạy thử).

Kiểm lại sau khi sửa: `flutter build appbundle --release` ✓ (139,3 MB), `flutter build apk --release` ✓ (145,3 MB), `flutter analyze`
không lỗi, `flutter test` 408 test đều qua, cài APK release lên emulator API 37 / 16 KB chạy được.

Hệ quả cần biết: đổi máy qua Google backup sẽ **không** mang tiến độ của bé theo (trừ chuyển máy trực tiếp). Bố mẹ dùng Sao lưu (file)
hoặc Dùng trên nhiều máy. Khớp với chính sách: "dữ liệu không gửi đi đâu, trừ khi bố mẹ bật đồng bộ".

## 3. Sửa Dart — **đã làm (25/10/2026)**

- **D1** ✅ `lib/features/home/new_kid_screen.dart` `_join()`: `parentGate` trước khi hỏi mã gia đình; bảng hỏi mã, nút và toast song ngữ.
- **D2** ✅ `lib/features/learn/language/read.dart` `_mic()`: `rec.init()` trả `false` (không có bộ nhận tại chỗ / bị từ chối quyền) →
  `g.store.setKv(kMicKey, '0')`; lần bấm 🎤 sau phải qua bảng đồng ý + `g.gate()` rồi mới gọi lại `rec.init()` (hộp quyền hệ thống).
  Bố mẹ có thể bật lại bằng "🎤 Hỏi lại về micro" trong Góc bố mẹ.
- **D3** ✅ `read.dart` `_stt.initialize(options: [SpeechToText.androidNoBluetooth])` (hằng có trong speech_to_text 7.5.0).
- **D4** ✅ `lib/main.dart`: bỏ `statusBarColor` (Android 15+); Android ≤ 14 vẫn đặt trong suốt để giữ giao diện.
- **D5** — không làm (không chọn): chủ app giữ "Võ đài", "Đấu sumo" và các game hành động; thay vào đó Target audience chỉ 6–8.
- Thêm: menu chọn chữ không còn mục "process text" (Dịch… của app khác) / Share — `lib/core/ui/text_menu.dart`.

## 4. Việc chủ app phải làm (không sửa được bằng mã)

1. Tạo upload key: `keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`,
   tạo `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias=upload`, `storeFile=upload-keystore.jks`), sao lưu cả hai ở
   nơi an toàn. Bật **Play App Signing** khi tạo app. Kiểm: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
   không còn `CN=Android Debug`.
2. Trước bản chính thức: thử đồng bộ thật (tạo mã → máy khác nhập mã → xoá bản trên máy chủ) trên **bản release** (R8).
3. Ảnh cửa hàng/mô tả: không có logo/nhân vật thương hiệu khác, không ghi "Teacher Approved", không hứa "an toàn tuyệt đối".
4. Đăng ký tài khoản nhà phát triển cá nhân mới (sau 11/2023): phải chạy **closed testing ≥ 12 người thử trong 14 ngày** trước khi
   xin Production.

## 5. Câu trả lời Play Console

### 5.1 App content → Target audience and content
- **Target age groups**: ☑ **6–8** — chỉ nhóm này. ☐ 5 and under (không chọn: app có mini-game hành động hoạt hình), ☐ 9–12, ☐ 13+.
- **Appeal to children**: app nhắm trẻ em → tự động thuộc **Families Policy**. Câu "Could your store listing unintentionally appeal to
  children?" không hỏi vì đã chọn nhóm trẻ.
- **Store presence**: ảnh/biểu tượng hướng trẻ em — đúng với nhóm tuổi.
- Đồng ý tuân thủ Families Policy Requirements; email liên hệ `beatgone2503@gmail.com`.
- **Teacher Approved**: không cần đăng ký; Google tự xét. Không đảm bảo (xem #28).

### 5.2 Data safety — **ĐÃ CHỌN: khai thận trọng**
- **Does your app collect or share any of the required user data types?** → **Yes**.
- **Is all of the user data collected by your app encrypted in transit?** → **Yes**.
- **Account creation**: "My app does not allow users to create an account" → không cần URL xoá tài khoản.
- **Do you provide a way for users to request that their data is deleted?** → **Yes** (Góc bố mẹ → Dùng trên nhiều máy → Xoá bản
  trên máy chủ; hoặc email `beatgone2503@gmail.com`).
- **Data types**: chỉ **App activity → Other user-generated content**: ☑ Collected, ☐ Shared; processed ephemerally: **No**;
  **Users can choose whether this data is collected** (Optional — chỉ khi bố mẹ bật đồng bộ); Purpose: **App functionality**.
- Không khai: Audio (xử lý trên máy), Device or other IDs, Personal info, Location, App info and performance, các loại khác.
- Lý do (nội bộ): bản đồng bộ là khối **mã hoá đầu-cuối** (AES-256-GCM, khoá suy từ mã 16 ký tự chỉ có trên máy gia đình) — không
  ai ngoài các máy của gia đình đọc được; vẫn khai để thận trọng vì dữ liệu được lưu lâu dài trên Firestore. Bảng đầy đủ:
  `docs/STORE_PRIVACY.md` mục 1. Phương án "No data collected" **không chọn**.

### 5.3 Ads
- **Does your app contain ads?** → **No, my app does not contain ads.**

### 5.4 App access
- Chọn **"All or some functionality in my app is restricted"** và thêm một mục hướng dẫn (không cần tên đăng nhập/mật khẩu — tick
  "No username or password required" / để trống phần đăng nhập):

  > No account or login. Parent-only areas (⚙ Bố mẹ / Parents button on the home map, sharing, external links, the microphone in
  > "Bé đọc to") are behind a parental gate: answer the multiplication shown on screen (a 2-digit number × a 1-digit number, e.g.
  > 15 × 9 = 135) with the keypad and tap OK. A new random question appears each time, and after a wrong answer. Entering a family
> code on the "create child" screen is behind the gate too. To reach the microphone: Start → enter any
  > name → pick a mascot → "Bắt đầu thôi!" → choose "Lớp 1" → "Đọc truyện" → "Bé đọc to" → tap 🎤 → "Bố mẹ đồng ý" → gate.
  > Multi-device sync (optional) is in Parents → "Dùng trên nhiều máy".

  (Nếu muốn đơn giản hơn có thể chọn "All functionality is available without special access" vì gate không cần thông tin đăng nhập;
  khuyên dùng phương án có hướng dẫn để reviewer không kẹt ở gate.)

### 5.5 Content rating (IARC)
- Email liên hệ: `beatgone2503@gmail.com`. **Category**: *Game* (app có ~48 mini-game, gồm game hành động — chọn "Game" để mô tả
  trung thực; nếu chọn "Reference, News, or Educational" vẫn phải khai các nội dung bạo lực hoạt hình).
- **Violence**: **Yes**.
  - Bạo lực có thực tế/đồ hoạ không? **No** — hoạt hình, nhân vật kỳ ảo (quái vật dễ thương, phi thuyền, xe tăng đồ chơi nhìn từ trên
    xuống), không máu, không thi thể, không vũ khí thật.
  - Bạo lực với nhân vật giống người? Có đấu võ hoạt hình (đấm, đỡ, thanh máu, KO) và ném tuyết/sumo giữa nhân vật hoạt hình; trả lời
    là bạo lực **hoạt hình/kỳ ảo, mức nhẹ, bối cảnh trẻ em**. Blood/gore: **No**. Bạo lực tình dục: **No**.
- **Fear/horror**: **No** (quái vật/ma kiểu dễ thương, không doạ).
- **Sexuality / nudity**: **No**. **Language** (chửi thề, phân biệt): **No**. **Controlled substances** (rượu, thuốc lá, ma tuý): **No**.
- **Gambling / simulated gambling**: **No** (vé chơi và sao do học mà có, không mua bằng tiền, không quay thưởng trả tiền).
- **Crude humor**: **No**.
- **Users can interact / communicate**: **No** (không chat, không nội dung người dùng công khai; "Hai người" là chung một màn hình).
- **Shares user's location**: **No**. **Digital purchases**: **No**. **Unrestricted internet / web browser**: **No** (chỉ mở vài trang
  cố định ở trình duyệt ngoài, sau gate).
- **Is the app a web browser or search engine?** No. **Miscellaneous / NFTs / blockchain**: No.
- Kết quả dự kiến: ESRB **E** (có thể kèm "Mild Fantasy Violence"), PEGI **3 hoặc 7**, USK 6, ClassInd L/10, IARC 7+. Mức này
  chấp nhận được cho Families; nếu ra mức cao hơn 7 thì xem lại câu trả lời.

### 5.6 Các khai báo khác trong App content
- **Privacy policy**: https://bevuihoc-app.web.app/privacy
- **Government app**: No. **Financial features**: None. **Health**: không phải app sức khoẻ. **News app**: No.
- **COVID-19 / Actor**: không áp dụng. **Advertising ID**: "No" (app không dùng Advertising ID; manifest đã gỡ `AD_ID`).
- **Permissions declaration**: không có quyền hạn chế nên không có form riêng; mô tả `RECORD_AUDIO` trong phần mô tả/ghi chú:
  "Microphone is only used in the optional 'Read aloud' activity after a parent agrees and passes the parental gate. Speech is
  recognized on the device; audio is never recorded, stored or sent."
- **Store listing**: Category **Education** (hoặc Educational trong Family). Email hỗ trợ `beatgone2503@gmail.com`, website
  https://bevuihoc-app.web.app/

## 6. Kiểm lại trước mỗi bản phát hành

```
flutter build appbundle --release
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk   # chỉ INTERNET, RECORD_AUDIO, ACCESS_NETWORK_STATE
cd android && ./gradlew app:dependencies --configuration releaseRuntimeClasspath | grep -iE "ads|analytics|measurement|installations|crashlytics"   # phải trống
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab   # không phải CN=Android Debug
zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-release.apk          # Verification successful
```
