# Khai báo quyền riêng tư cho cửa hàng — Bé Vui Học

Cập nhật: 19/10/2026. Khớp với mã nguồn sau khi bỏ trang web cũ, bỏ Crashlytics, App Check và Remote Config; đồng bộ
chuyển sang Cloud Firestore. Chính sách đầy đủ: `assets/legal/privacy_vi.md` / `privacy_en.md` (trong app: Góc bố mẹ → 🔒 Chính sách quyền
riêng tư; trên web: https://bevuihoc-app.web.app/privacy và https://bevuihoc-app.web.app/privacy/en).

Trước khi gửi duyệt: điền email ở `beatgone2503@gmail.com` (4 file `assets/legal/*.md`), chạy `python3 hosting/build_pages.py`,
deploy `firebase deploy --only firestore:rules,hosting`, rồi mới dán URL chính sách vào hai cửa hàng.

## 0. Hành vi thật của app (căn cứ để trả lời)

| Dữ liệu / tính năng | Đi đâu | Ghi chú |
|---|---|---|
| Tên gọi của bé (≤ 20 ký tự), linh vật, tiến độ học, thời gian học, cài đặt | Chỉ trên máy (`shared_preferences`) | Không tài khoản, không email, không ngày sinh, không ảnh |
| Đồng bộ "mã gia đình" (tuỳ chọn, mặc định TẮT, bật ở Góc bố mẹ sau khoá bố mẹ) | Cloud Firestore `syncs/{sid}`, vùng asia-southeast1 | Chỉ khối dữ liệu **mã hoá đầu-cuối** AES-256-GCM (khoá suy từ mã 16 ký tự, PBKDF2 150.000 vòng, mã không bao giờ gửi đi) + số phiên bản + giờ cập nhật; sid = SHA-256 của mã. Nhà phát triển không đọc được. Xoá được ngay: "Xoá bản trên máy chủ" |
| Đọc to (speech_to_text, `onDevice: true`) | Bộ nhận giọng của hệ điều hành, **chạy trên máy** | Chỉ khi bố mẹ đồng ý + qua khoá bố mẹ; máy không có bộ nhận tại chỗ thì micro tắt. Không ghi âm, không lưu, không gửi âm thanh đi đâu |
| Sao lưu file, bằng khen, chia sẻ, link ngoài | Bảng chia sẻ / trình duyệt của máy, do bố mẹ chọn | Tất cả sau khoá bố mẹ; link chia sẻ là https://bevuihoc-app.web.app/ (không tham số theo dõi) |
| Quảng cáo, Analytics, Crashlytics, App Check, Remote Config, Firebase Installations, mua trong app, đăng nhập | **Không có** | Đã gỡ khỏi pubspec, gradle, Xcode |
| Quyền máy | Android: `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE` (Firestore tự thêm). iOS: micro + nhận dạng giọng nói (hỏi lúc dùng) | Không có `AD_ID`, vị trí, danh bạ, ảnh, thông báo |

Kiểm lại trước mỗi bản phát hành: `grep -rn "firebase_\|cloud_firestore" pubspec.yaml`, `./gradlew app:dependencies` không có `firebase-installations`, `crashlytics`, `measurement`, `ads`
(phải trống), và manifest sau gộp không có `com.google.android.gms.permission.AD_ID`.

## 1. Google Play — Data safety (An toàn dữ liệu)

**Does your app collect or share any of the required user data types?** → **No.**

Lý do: dữ liệu học và tên gọi chỉ ở trên máy. Khi bố mẹ tự bật đồng bộ, dữ liệu rời máy ở dạng **mã hoá đầu-cuối** (chỉ
máy có mã gia đình giải được, nhà phát triển không đọc được). App không có Analytics, Crashlytics, Remote Config, Firebase
Installations, mã quảng cáo hay định danh thiết bị. Nhận giọng (đọc to) chạy trên máy, âm thanh không rời máy.

Nếu muốn khai thận trọng cho phần đồng bộ: App activity → "Other user-generated content": Collected, **Optional**, App
functionality, không shared, encrypted in transit: Yes, deletion: Yes (Góc bố mẹ → "Xoá bản trên máy chủ").

## 2. Google Play — Families / Target audience and content

- **Target age group**: **5 tuổi trở xuống** và **6–8 tuổi** (app cho bé 3–6). Không chọn nhóm 13+.
- **Appeal to children**: Yes — app được thiết kế cho trẻ em → tuân thủ **Families Policy**.
- **Ads**: Không chứa quảng cáo. **In-app purchases**: không. **Account / login**: không.
- **SDK**: chỉ Firebase core + Cloud Firestore (dùng cho đồng bộ mã hoá đầu-cuối) — không phải SDK quảng cáo/đo lường;
  không thu AAID / Android ID / Firebase installation ID; không truyền định danh nào của trẻ.
- **Parental gate**: Góc bố mẹ, bật micro, chia sẻ, liên kết ngoài, Giới thiệu/Ghi công/Chính sách (kể cả ở màn Bắt đầu) đều
  qua phép nhân 2 chữ số × 1 chữ số (12–49 × 3–9).
- **Content rating (IARC)**: giáo dục; có mini-game bắn súng / xe tăng / đánh quái kiểu hoạt hình — trả lời trung thực mục
  "violence" (bạo lực hoạt hình nhẹ, không máu); không nội dung người dùng tạo chia sẻ công khai, không chat, không vị trí.
- **Permissions**: `RECORD_AUDIO` — giải thích: "Bé đọc to trong bài Đọc, chỉ khi bố mẹ đồng ý qua khoá bố mẹ".
- **Privacy policy URL**: https://bevuihoc-app.web.app/privacy

## 3. Apple App Store — App Privacy (nhãn dinh dưỡng) + Kids Category

**Do you or your third-party partners collect data from this app?** → **No** → nhãn **"Data Not Collected"**.

Lý do: như mục 1 — dữ liệu ở trên máy; bản đồng bộ (tuỳ chọn) là dữ liệu mã hoá đầu-cuối mà nhà phát triển và Google không
đọc được; nhận giọng bằng Apple Speech framework ở chế độ trên máy (on-device); không Crashlytics/Analytics/định danh thiết bị.
(Khai thận trọng nếu muốn: User Content → Other User Content, App Functionality, Not linked, No tracking.)

**Tracking (ATT)**: Không theo dõi → không cần App Tracking Transparency; không có IDFA.

**Kids Category** (App Store Review Guidelines 1.3, 5.1.4):
- Age band: **5 & Under** (hoặc 6–8 nếu muốn nhắm Lớp 1; chỉ chọn một).
- Không quảng cáo, không analytics bên thứ ba, không mua trong app.
- Link ra ngoài, chia sẻ, xin quyền micro: **sau parental gate** (phép nhân 2×1 chữ số). Trang Giới thiệu / Ghi công / Chính sách
  ở màn Bắt đầu cũng sau gate.
- Không gửi thông tin cá nhân hay thông tin thiết bị tới bên thứ ba. Ghi chú cho reviewer: "No analytics, no advertising,
  no device identifiers. Optional family sync stores only an end-to-end encrypted blob in Cloud Firestore."
- **Privacy Policy URL**: https://bevuihoc-app.web.app/privacy . **Support URL**: https://bevuihoc-app.web.app/ (email beatgone2503@gmail.com).
- **Privacy manifest**: các SDK Firebase (core, Firestore) và plugin Flutter (shared_preferences…) tự kèm `PrivacyInfo.xcprivacy`; app không dùng
  API "required reason" nào khác. Kiểm bằng Xcode → Product → Archive → Generate Privacy Report trước khi nộp.
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` (Info.plist) đã ghi rõ: chỉ khi bố mẹ đồng ý, nhận giọng
  ngay trên máy, app không lưu hay gửi âm thanh.

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
