# Khai báo quyền riêng tư cho cửa hàng — Bé Vui Học

Cập nhật: 25/10/2026 (chốt độ tuổi 6–8 và cách khai thận trọng). Trước đó: 19/10/2026. Khớp với mã nguồn sau khi bỏ trang web cũ, bỏ Crashlytics, App Check và Remote Config; đồng bộ
chuyển sang Cloud Firestore. Chính sách đầy đủ: `assets/legal/privacy_vi.md` / `privacy_en.md` (trong app: Góc bố mẹ → 🔒 Chính sách quyền
riêng tư; trên web: https://bevuihoc-app.web.app/privacy và https://bevuihoc-app.web.app/privacy/en).

Trước khi gửi duyệt: chạy `python3 hosting/build_pages.py` (đã chạy 25/10/2026 — chính sách hiệu lực 25/10/2026),
deploy `firebase deploy --only firestore:rules,hosting`, rồi mới dán URL chính sách vào hai cửa hàng.

## 0. Hành vi thật của app (căn cứ để trả lời)

| Dữ liệu / tính năng | Đi đâu | Ghi chú |
|---|---|---|
| Tên gọi của bé (≤ 20 ký tự), linh vật, tiến độ học, thời gian học, cài đặt | Chỉ trên máy (`shared_preferences`) | Không tài khoản, không email, không ngày sinh, không ảnh |
| Đồng bộ "mã gia đình" (tuỳ chọn, mặc định TẮT, bật ở Góc bố mẹ hoặc nhập mã ở màn tạo bé — đều sau khoá bố mẹ) | Cloud Firestore `syncs/{sid}`, vùng asia-southeast1 | Chỉ khối dữ liệu **mã hoá đầu-cuối** AES-256-GCM (khoá suy từ mã 16 ký tự, PBKDF2 150.000 vòng, mã không bao giờ gửi đi) + số phiên bản + giờ cập nhật; sid = SHA-256 của mã. Nhà phát triển không đọc được. Xoá được ngay: "Xoá bản trên máy chủ" |
| Đọc to (speech_to_text, `onDevice: true`) | Bộ nhận giọng của hệ điều hành, **chạy trên máy** | Chỉ khi bố mẹ đồng ý + qua khoá bố mẹ; máy không có bộ nhận tại chỗ thì micro tắt. Không ghi âm, không lưu, không gửi âm thanh đi đâu |
| Sao lưu file, bằng khen, chia sẻ, link ngoài | Bảng chia sẻ / trình duyệt của máy, do bố mẹ chọn | Tất cả sau khoá bố mẹ; link chia sẻ là https://bevuihoc-app.web.app/ (không tham số theo dõi) |
| Quảng cáo, Analytics, Crashlytics, App Check, Remote Config, Firebase Installations, mua trong app, đăng nhập | **Không có** | Đã gỡ khỏi pubspec, gradle, Xcode |
| Quyền máy | Android: `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE` (Firestore tự thêm). iOS: micro + nhận dạng giọng nói (hỏi lúc dùng) | Không có `AD_ID`, vị trí, danh bạ, ảnh, thông báo |

Kiểm lại trước mỗi bản phát hành: `grep -rn "firebase_\|cloud_firestore" pubspec.yaml`, `./gradlew app:dependencies` không có `firebase-installations`, `crashlytics`, `measurement`, `ads`
(phải trống), và manifest sau gộp không có `com.google.android.gms.permission.AD_ID`.

## 1. Google Play — Data safety (An toàn dữ liệu) — **ĐÃ CHỌN: khai thận trọng**

Quyết định của chủ app (25/10/2026): khai **có thu** một loại dữ liệu cho phần đồng bộ tuỳ chọn (bản mã hoá đầu-cuối lưu trên
Firestore), không dựa vào ngoại lệ mã hoá đầu-cuối. Phương án "No data collected" **không chọn**.

| Câu hỏi trong Play Console | Trả lời |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (TLS tới Firestore; nội dung còn mã hoá đầu-cuối AES-256-GCM) |
| Which of the following methods of account creation does your app support? | **My app does not allow users to create an account** |
| Do you provide a way for users to request that their data is deleted? | **Yes** — Góc bố mẹ → "Dùng trên nhiều máy" → "Xoá bản trên máy chủ" (xoá ngay); hoặc email beatgone2503@gmail.com |
| Data types — chọn **duy nhất**: App activity → **Other user-generated content** | ☑ Collected · ☐ Shared |
| ↳ Is this data processed ephemerally? | **No** (lưu đến khi bố mẹ xoá) |
| ↳ Is this data required for your app, or can users choose whether it's collected? | **Users can choose whether this data is collected** (Optional — chỉ khi bố mẹ bật đồng bộ, mặc định tắt) |
| ↳ Why is this user data collected? | ☑ **App functionality** (đồng bộ tiến độ giữa các máy của gia đình). Không chọn Analytics, Developer communications, Advertising or marketing, Fraud prevention, Personalization, Account management |
| Mọi loại khác (Location, Personal info, Financial info, Health and fitness, Messages, Photos and videos, **Audio files / Voice or sound recordings**, Files and docs, Calendar, Contacts, App info and performance, **Device or other IDs**, Web browsing, App activity khác) | **Không chọn** |

Ghi chú nội bộ: tên gọi/tiến độ chỉ ở trên máy; Android backup lên Drive đã tắt; khi đồng bộ, khối dữ liệu đã mã hoá
đầu-cuối (gồm tên gọi, tiến độ) lên Firestore — nhà phát triển và Google không đọc được, nên khai một loại "Other
user-generated content". Google thấy địa chỉ IP khi kết nối (không lưu/dùng, đã ghi trong chính sách mục 2). Nhận giọng (đọc to)
chạy trên máy, âm thanh không rời máy → không khai Audio. Không có định danh thiết bị (không AAID/FID/Android ID).

## 2. Google Play — Families / Target audience and content

- **Target age group**: **chỉ 6–8 tuổi** (☑ Ages 6–8; ☐ 5 and under; ☐ 9–12; ☐ 13+). Lý do: app có mini-game hành động hoạt
  hình (bắn quái, xe tăng, võ đài, săn quái, siêu nhân, bắn bia, RPG) — chủ app giữ các game này nên **không** nhắm nhóm 5 tuổi trở xuống.
- **Appeal to children**: Yes — app được thiết kế cho trẻ em → tuân thủ **Families Policy**.
- **Ads**: Không chứa quảng cáo. **In-app purchases**: không. **Account / login**: không.
- **SDK**: chỉ Firebase core + Cloud Firestore (dùng cho đồng bộ mã hoá đầu-cuối) — không phải SDK quảng cáo/đo lường;
  không thu AAID / Android ID / Firebase installation ID; không truyền định danh nào của trẻ.
- **Parental gate**: Góc bố mẹ, bật micro (và mỗi lần hỏi lại quyền micro), chia sẻ, liên kết ngoài, nhập mã gia đình ở màn tạo bé,
  Giới thiệu/Ghi công/Chính sách (kể cả ở màn Bắt đầu) đều qua phép nhân 2 chữ số × 1 chữ số (12–49 × 3–9); sai thì đổi phép mới.
- **Content rating (IARC)**: có mini-game bắn súng / xe tăng / đánh quái kiểu hoạt hình — trả lời **Violence: Yes** (bạo lực
  hoạt hình/kỳ ảo, nhẹ, không máu); không nội dung người dùng tạo chia sẻ công khai, không chat, không vị trí. Chi tiết:
  `docs/REVIEW_GOOGLE.md` mục 5.5.
- **Permissions**: `RECORD_AUDIO` — giải thích: "Bé đọc to trong bài Đọc, chỉ khi bố mẹ đồng ý qua khoá bố mẹ".
- **Privacy policy URL**: https://bevuihoc-app.web.app/privacy

## 3. Apple App Store — App Privacy (nhãn dinh dưỡng) + Kids Category — **ĐÃ CHỌN: khai thận trọng**

| Câu hỏi trong App Store Connect → App Privacy | Trả lời |
|---|---|
| Do you or your third-party partners collect data from this app? | **Yes, we collect data from this app** |
| Data types — chọn **duy nhất**: User Content → **Other User Content** | ☑ |
| ↳ How is Other User Content used? | ☑ **App Functionality** (đồng bộ tiến độ giữa các máy của gia đình). Không chọn Third-Party Advertising, Developer's Advertising or Marketing, Analytics, Product Personalization, Other Purposes |
| ↳ Is Other User Content linked to the user's identity? | **No** (không tài khoản; ngăn lưu trữ là băm của mã ngẫu nhiên; nội dung mã hoá đầu-cuối) |
| ↳ Do you or your third-party partners use Other User Content for tracking purposes? | **No** |
| Mọi loại khác (Contact Info, Health & Fitness, Financial Info, Location, Sensitive Info, Contacts, Emails or Text Messages, Photos or Videos, **Audio Data**, Gameplay Content, Customer Support, Browsing/Search History, **Identifiers**, Purchases, Usage Data, **Diagnostics**, Other Data) | **Không chọn** |
| Nhãn hiển thị | **Data Not Linked to You: User Content** |

Ghi chú: chỉ thu khi bố mẹ bật đồng bộ tuỳ chọn (mặc định tắt); khối dữ liệu mã hoá đầu-cuối, nhà phát triển và Google không đọc
được. Không khai Diagnostics (Firebase data collection tắt), Identifiers (không FID/IDFA), Audio Data (nhận giọng trên máy, không
gửi). Địa chỉ IP do Google xử lý khi kết nối — không lưu/dùng, đã nêu trong chính sách (D8). `ios/Runner/PrivacyInfo.xcprivacy`
khai cùng loại `NSPrivacyCollectedDataTypeOtherUserContent` (không liên kết, không tracking, App Functionality) để Privacy Report
khớp nhãn. Phương án "Data Not Collected" **không chọn**.

**Tracking (ATT)**: Không theo dõi → không cần App Tracking Transparency; không có IDFA.

**Age rating** (bảng câu hỏi mới): Cartoon or Fantasy Violence **Infrequent/Mild**, Guns or Other Weapons **Infrequent** (súng laser/
súng nước, pháo xe tăng, kiếm hoạt hình), mọi mục khác None/No → **9+**. Chi tiết: `docs/REVIEW_APPLE.md` mục 4.1.

**Kids Category** (App Store Review Guidelines 1.3, 5.1.4):
- Age band: **6–8** (đã chọn; "5 & Under" không chọn vì giữ các game hành động). Lưu ý: chọn Made for Kids rồi không bỏ được sau khi duyệt.
- Không quảng cáo, không analytics bên thứ ba, không mua trong app.
- Link ra ngoài, chia sẻ, xin quyền micro, nhập mã gia đình: **sau parental gate** (phép nhân 2×1 chữ số). Trang Giới thiệu /
  Ghi công / Chính sách ở màn Bắt đầu cũng sau gate. Menu chọn chữ không có Look Up / Search Web / Share.
- Không gửi thông tin cá nhân hay thông tin thiết bị tới bên thứ ba. Ghi chú cho reviewer: "No analytics, no advertising,
  no device identifiers. Optional family sync stores only an end-to-end encrypted blob in Cloud Firestore (declared as
  Other User Content, App Functionality, not linked, no tracking)."
- **Privacy Policy URL**: https://bevuihoc-app.web.app/privacy . **Support URL**: https://bevuihoc-app.web.app/ (email beatgone2503@gmail.com).
- **Privacy manifest**: các SDK Firebase (core, Firestore) và plugin Flutter (shared_preferences…) tự kèm `PrivacyInfo.xcprivacy`; app
  có manifest riêng (`ios/Runner/PrivacyInfo.xcprivacy`). Kiểm bằng Xcode → Product → Archive → Generate Privacy Report trước khi nộp.
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` (Info.plist + `vi.lproj`/`en.lproj`) đã ghi rõ: chỉ khi bố mẹ
  đồng ý, nhận giọng ngay trên máy, app không lưu hay gửi âm thanh.

## 4. Remote Config đã gỡ (19/10/2026)

Trước đây app dùng Firebase Remote Config, kéo theo Firebase Installations (gửi mã cài đặt FID lên Google) — buộc phải khai
"Device ID". Đã gỡ gói `firebase_remote_config`; các cờ tính năng (`sync_enabled`, `fun_zone_enabled`, `review_enabled`,
`parent_notice_*`, `min_build`) giờ là giá trị cố định trong app (`kRemoteDefaults`, `lib/features/sync/firebase_setup.dart`).
Muốn đổi thì phát hành bản mới. **Đừng thêm lại** Remote Config, Analytics, Crashlytics, Messaging hay In-App Messaging nếu
không cập nhật chính sách và khai báo store.

Lưu ý iOS: plugin `firebase_core` (FlutterFire, Swift Package) luôn liên kết sẵn thư viện `FirebaseInstallations`, nhưng
không plugin nào của app gọi tới nó (Firestore không dùng FID), nên không có mã cài đặt nào được tạo hay gửi đi. Khi Archive,
mở Xcode → Generate Privacy Report để xem tổng hợp privacy manifest; nếu báo cáo liệt kê "Device ID" do manifest của thư viện
này, nội dung khai báo ở mục 3 vẫn đúng với hành vi thật (dữ liệu không được thu).
