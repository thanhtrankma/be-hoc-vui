# Khai báo quyền riêng tư cho cửa hàng — Bé Vui Học

Cập nhật: 18/10/2026. Khớp với mã nguồn sau khi bỏ trang web cũ, bỏ Crashlytics + App Check, đồng bộ chuyển sang Cloud
Firestore. Chính sách đầy đủ: `assets/legal/privacy_vi.md` / `privacy_en.md` (trong app: Góc bố mẹ → 🔒 Chính sách quyền
riêng tư; trên web: https://bevuihoc-app.web.app/privacy và https://bevuihoc-app.web.app/privacy/en).

Trước khi gửi duyệt: điền email ở `[EMAIL LIÊN HỆ]` (4 file `assets/legal/*.md`), chạy `python3 hosting/build_pages.py`,
deploy `firebase deploy --only firestore:rules,hosting`, rồi mới dán URL chính sách vào hai cửa hàng.

## 0. Hành vi thật của app (căn cứ để trả lời)

| Dữ liệu / tính năng | Đi đâu | Ghi chú |
|---|---|---|
| Tên gọi của bé (≤ 20 ký tự), linh vật, tiến độ học, thời gian học, cài đặt | Chỉ trên máy (`shared_preferences`) | Không tài khoản, không email, không ngày sinh, không ảnh |
| Đồng bộ "mã gia đình" (tuỳ chọn, mặc định TẮT, bật ở Góc bố mẹ sau khoá bố mẹ) | Cloud Firestore `syncs/{sid}`, vùng asia-southeast1 | Chỉ khối dữ liệu **mã hoá đầu-cuối** AES-256-GCM (khoá suy từ mã 16 ký tự, PBKDF2 150.000 vòng, mã không bao giờ gửi đi) + số phiên bản + giờ cập nhật; sid = SHA-256 của mã. Nhà phát triển không đọc được. Xoá được ngay: "Xoá bản trên máy chủ" |
| Firebase Remote Config | Google (Firebase) | Mỗi lần mở app (tối đa 6 giờ/lần) tải cấu hình chung. Thư viện Firebase Installations tạo **Firebase installation ID** (FID, ngẫu nhiên theo lần cài) + token; gửi kèm phiên bản app/OS/SDK, ngôn ngữ/vùng; Google thấy IP. Không dùng để phân tích/quảng cáo. **Không thể tắt** nếu giữ Remote Config |
| Đọc to (speech_to_text, `onDevice: true`) | Bộ nhận giọng của hệ điều hành, **chạy trên máy** | Chỉ khi bố mẹ đồng ý + qua khoá bố mẹ; máy không có bộ nhận tại chỗ thì micro tắt. Không ghi âm, không lưu, không gửi âm thanh đi đâu |
| Sao lưu file, bằng khen, chia sẻ, link ngoài | Bảng chia sẻ / trình duyệt của máy, do bố mẹ chọn | Tất cả sau khoá bố mẹ; link chia sẻ là https://bevuihoc-app.web.app/ (không tham số theo dõi) |
| Quảng cáo, Analytics, Crashlytics, App Check, mua trong app, đăng nhập | **Không có** | Đã gỡ khỏi pubspec, gradle, Xcode |
| Quyền máy | Android: `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE` (Firestore tự thêm). iOS: micro + nhận dạng giọng nói (hỏi lúc dùng) | Không có `AD_ID`, vị trí, danh bạ, ảnh, thông báo |

Kiểm lại trước mỗi bản phát hành: `grep -rn "firebase_\|cloud_firestore" pubspec.yaml`, `unzip -l app-release.apk | grep -i -E "crashlytics|appcheck|measurement|ads"`
(phải trống), và manifest sau gộp không có `com.google.android.gms.permission.AD_ID`.

## 1. Google Play — Data safety (An toàn dữ liệu)

**Does your app collect or share any of the required user data types?** → **Yes** (vì Firebase installation ID).

Nếu sau này gỡ Remote Config (xem mục 4) thì có thể trả lời **No** (đồng bộ là dữ liệu mã hoá đầu-cuối, xem dưới).

**Is all of the user data collected by your app encrypted in transit?** → **Yes** (TLS tới Firebase).

**Do you provide a way for users to request that their data is deleted?** → **Yes** — trong app: Góc bố mẹ → Xoá bé /
"Xoá bản trên máy chủ"; gỡ app xoá dữ liệu trên máy và FID. (App không có tài khoản nên không cần trang yêu cầu xoá tài khoản;
nếu Console vẫn hỏi URL, dùng https://bevuihoc-app.web.app/privacy — mục 8 hướng dẫn xoá.)

Kiểu dữ liệu cần khai:

| Nhóm Play | Kiểu | Collected | Shared | Ephemeral | Bắt buộc? | Mục đích |
|---|---|---|---|---|---|---|
| Device or other IDs | Firebase installation ID | **Yes** | No (Google xử lý thay nhà phát triển = service provider, không tính "shared") | No | Required | App functionality |

Không khai (lý do):
- **App activity / App info and performance / Personal info**: tiến độ, tên gọi chỉ ở trên máy. Khi bật đồng bộ, dữ liệu rời máy
  ở dạng **mã hoá đầu-cuối** (chỉ máy có mã gia đình giải được) — theo hướng dẫn Data safety, dữ liệu mã hoá đầu-cuối mà
  nhà phát triển không đọc được không tính là "collected". (Nếu muốn khai thận trọng hơn: App activity → "Other user-generated
  content", Collected, Optional, App functionality, không shared.)
- **Audio → Voice or sound recordings**: không thu — nhận giọng chạy trên máy (on-device), âm thanh không rời khỏi máy
  theo chính sách của Google. (Khai thận trọng: Collected, **Ephemeral = Yes**, Optional, App functionality.)
- **Crash logs / Diagnostics / Analytics**: không có (đã gỡ Crashlytics).
- **Location, Contacts, Photos, Financial, Messages, Web browsing**: không có.

**Security practices:** encrypted in transit: Yes; deletion request: Yes. Không chọn "Independent security review".

## 2. Google Play — Families / Target audience and content

- **Target age group**: **5 tuổi trở xuống** và **6–8 tuổi** (app cho bé 3–6). Không chọn nhóm 13+.
- **Appeal to children**: Yes — app được thiết kế cho trẻ em → tuân thủ **Families Policy**.
- **Ads**: Không chứa quảng cáo. **In-app purchases**: không. **Account / login**: không.
- **SDK**: chỉ Firebase (core, Remote Config, Cloud Firestore) — không phải SDK quảng cáo; không thu AAID / Android ID;
  không truyền thông tin định danh của trẻ (FID là ID ngẫu nhiên theo lần cài, không gắn người). Ghi rõ điều này nếu Play hỏi về
  "identifiers from children" — nếu reviewer coi FID là định danh thiết bị, phương án là gỡ Remote Config (mục 4).
- **Parental gate**: Góc bố mẹ, bật micro, chia sẻ, liên kết ngoài, Giới thiệu/Ghi công/Chính sách (kể cả ở màn Bắt đầu) đều
  qua phép nhân 2 chữ số × 1 chữ số (12–49 × 3–9).
- **Content rating (IARC)**: giáo dục; có mini-game bắn súng / xe tăng / đánh quái kiểu hoạt hình — trả lời trung thực mục
  "violence" (bạo lực hoạt hình nhẹ, không máu); không nội dung người dùng tạo chia sẻ công khai, không chat, không vị trí.
- **Permissions**: `RECORD_AUDIO` — giải thích: "Bé đọc to trong bài Đọc, chỉ khi bố mẹ đồng ý qua khoá bố mẹ".
- **Privacy policy URL**: https://bevuihoc-app.web.app/privacy

## 3. Apple App Store — App Privacy (nhãn dinh dưỡng) + Kids Category

**Do you or your third-party partners collect data from this app?** → **Yes** (Firebase installation ID của Remote Config).

| Loại Apple | Kiểu | Mục đích | Linked to user? | Used for tracking? |
|---|---|---|---|---|
| Identifiers | **Device ID** (Firebase installation ID) | App Functionality | **No** | **No** |

Không khai (lý do):
- **User Content / Usage Data / Contact Info / Health / Location…**: không thu. Bản đồng bộ là dữ liệu mã hoá đầu-cuối; theo định
  nghĩa của Apple, dữ liệu mà nhà phát triển và đối tác không truy cập được (không đọc được) không tính là "collect".
  (Khai thận trọng nếu muốn: User Content → Other User Content, App Functionality, Not linked, No tracking.)
- **Audio Data**: không thu; nhận giọng bằng Apple Speech framework ở chế độ trên máy (on-device), âm thanh không rời khỏi máy.
- **Diagnostics (Crash Data, Performance Data)**: không có (đã gỡ Crashlytics).

**Tracking (ATT)**: Không theo dõi → không cần App Tracking Transparency; không có IDFA.

**Kids Category** (App Store Review Guidelines 1.3, 5.1.4):
- Age band: **5 & Under** (hoặc 6–8 nếu muốn nhắm Lớp 1; chỉ chọn một).
- Không quảng cáo, không analytics bên thứ ba, không mua trong app.
- Link ra ngoài, chia sẻ, xin quyền micro: **sau parental gate** (phép nhân 2×1 chữ số). Trang Giới thiệu / Ghi công / Chính sách
  ở màn Bắt đầu cũng sau gate.
- Lưu ý rủi ro: Apple yêu cầu app Kids không gửi "personally identifiable information or device information" tới bên thứ ba.
  Remote Config gửi FID + thông tin phiên bản tới Google. Ghi chú cho reviewer: "Firebase Remote Config is used only to fetch
  static feature flags; no analytics, no advertising, no user identification. Optional family sync stores only an
  end-to-end encrypted blob." Nếu bị từ chối vì lý do này → gỡ Remote Config (mục 4).
- **Privacy Policy URL**: https://bevuihoc-app.web.app/privacy . **Support URL**: https://bevuihoc-app.web.app/ (cần email liên hệ).
- **Privacy manifest**: các SDK Firebase và plugin Flutter (shared_preferences…) tự kèm `PrivacyInfo.xcprivacy`; app không dùng
  API "required reason" nào khác. Kiểm bằng Xcode → Product → Archive → Generate Privacy Report trước khi nộp.
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` (Info.plist) đã ghi rõ: chỉ khi bố mẹ đồng ý, nhận giọng
  ngay trên máy, app không lưu hay gửi âm thanh.

## 4. Remote Config và Firebase Installations — cân nhắc

`firebase_remote_config` luôn kéo theo **Firebase Installations** (FID + token, gửi lên `firebaseinstallations.googleapis.com`)
— đó là lý do duy nhất phải khai "Device or other IDs" / "Device ID". App hiện chỉ dùng Remote Config cho: `sync_enabled`,
`fun_zone_enabled`, `review_enabled`, `parent_notice_vi/en`, `min_build` (mặc định có sẵn trong app, `kRemoteDefaults`).

- Giữ Remote Config: khai như mục 1 và 3 (đã soạn sẵn ở trên).
- Gỡ Remote Config (khuyến nghị nếu muốn nhãn "Data Not Collected" và giảm rủi ro duyệt Kids): xoá gói, để `RemoteFlags` trả
  `kRemoteDefaults`; khi đó Firestore là thư viện Firebase duy nhất gửi dữ liệu (chỉ khi bật đồng bộ, chỉ bản mã hoá) và có thể
  trả lời "No data collected" ở cả hai cửa hàng.
