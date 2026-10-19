# Chính sách quyền riêng tư — Bé Vui Học

Ngày hiệu lực: 19/10/2026

Bé Vui Học là ứng dụng học mà chơi cho bé 3–6 tuổi. Chính sách này giải thích ứng dụng xử lý những dữ liệu nào, ở đâu và bố mẹ xoá chúng ra sao. Tóm tắt: **không tài khoản, không email, không quảng cáo, không phân tích hành vi, không mua trong ứng dụng, không theo dõi, không bán hay chia sẻ dữ liệu**. Tiến độ học nằm trên máy của gia đình.

## 1. Dữ liệu lưu trên máy

- Hồ sơ của bé: **chỉ một tên gọi** do bố mẹ hoặc bé tự nhập (tối đa 20 ký tự, nên dùng tên ở nhà, không cần họ tên thật) và linh vật bé chọn. Không có ngày sinh, ảnh, email, số điện thoại hay địa chỉ.
- Tiến độ học: sao, bài đã học, câu trả lời đúng/sai và lỗi hay nhầm (để gợi ý ôn tập), số phút học mỗi ngày, vé chơi, đồ vật và thú cưng trong game.
- Cài đặt: ngôn ngữ, âm thanh, nhạc nền, giới hạn thời gian, các lựa chọn khác trong Góc bố mẹ.

Những dữ liệu này lưu trong bộ nhớ riêng của ứng dụng trên máy (shared_preferences) và **không được gửi đi đâu**, trừ khi bố mẹ tự bật "Dùng trên nhiều máy" (mục 2).

## 2. Đồng bộ nhiều máy bằng mã gia đình (tuỳ chọn, mặc định tắt)

Bố mẹ có thể bật đồng bộ trong Góc bố mẹ (sau khoá bố mẹ) hoặc nhập mã gia đình khi tạo hồ sơ trên máy mới.

- Ứng dụng tạo ngay trên máy một **mã gia đình** 16 ký tự ngẫu nhiên. Không cần email, mật khẩu hay tài khoản.
- Từ mã này, máy tính ra một khoá mã hoá (PBKDF2-SHA-256) và một tên ngăn lưu trữ (giá trị băm SHA-256 của mã). Mã gia đình **không bao giờ được gửi đi**.
- Dữ liệu ở mục 1 được **mã hoá đầu-cuối trên máy** (AES-256-GCM) rồi mới gửi lên **Google Cloud Firestore** (dịch vụ Firebase của Google, máy chủ đặt tại Singapore, vùng asia-southeast1). Trên máy chủ chỉ có: tên ngăn (giá trị băm), số phiên bản, khối dữ liệu đã mã hoá và thời điểm cập nhật cuối.
- Không ai đọc được khối dữ liệu này nếu không có mã gia đình — kể cả nhà phát triển và Google. Chúng tôi không có mã của gia đình bạn và không thể liên kết ngăn lưu trữ với một người cụ thể.
- Bản trên máy chủ được giữ đến khi bố mẹ xoá. Bấm **"Xoá bản trên máy chủ"** trong Góc bố mẹ để xoá ngay. Quên mã thì không ai khôi phục được dữ liệu trên máy chủ.

## 3. Không có công cụ phân tích hay định danh thiết bị

Ứng dụng chỉ dùng thư viện Firebase của Google cho việc đồng bộ ở mục 2. Ứng dụng **không dùng** Google Analytics, Crashlytics, Remote Config, App Check hay bất kỳ công cụ báo lỗi, đo lường, quảng cáo nào, và **không tạo hay gửi mã cài đặt, mã quảng cáo hay định danh thiết bị**. Nếu bố mẹ không bật đồng bộ, ứng dụng không gửi dữ liệu nào lên máy chủ.

## 4. Đọc to và micro

- Trò "Bé đọc to" chỉ bật micro sau khi **bố mẹ đồng ý và trả lời đúng khoá bố mẹ**. Bố mẹ có thể chọn "Không bật" và tự chấm, hoặc bấm "Hỏi lại về micro" trong Góc bố mẹ.
- Khi bật, tiếng bé đọc được **bộ nhận dạng giọng nói có sẵn của hệ điều hành xử lý ngay trên máy** (Apple trên iPhone/iPad, Google trên Android) để chuyển thành chữ. Ứng dụng yêu cầu chế độ nhận giọng **trên máy**: nếu máy không có bộ nhận giọng tiếng Việt chạy tại chỗ, micro không được bật và bố mẹ tự chấm — tiếng bé không bị gửi qua mạng.
- Bé Vui Học **không ghi âm, không lưu và không gửi** âm thanh đi đâu; chỉ dùng chữ nhận được ngay lúc đó để khen bé.
- Quyền micro (và quyền nhận dạng giọng nói trên iOS) chỉ được hỏi vào lúc này; bố mẹ có thể tắt bất cứ lúc nào trong Cài đặt của máy.

## 5. Sao lưu, chia sẻ và liên kết ngoài

- **Sao lưu tiến độ** tạo một file trên máy; bố mẹ tự chọn nơi lưu hoặc gửi file. Ứng dụng không tải file này lên đâu.
- **Bằng khen** là ảnh vẽ ngay trên máy. Chia sẻ bằng khen, giới thiệu ứng dụng hay mở trang web (ví dụ chính sách này, trang tác giả ảnh trên Wikimedia Commons) đều **phải qua khoá bố mẹ** và dùng bảng chia sẻ / trình duyệt của máy.

## 6. Những gì chúng tôi không làm

- Không quảng cáo, không mua trong ứng dụng, không đăng nhập mạng xã hội.
- Không thu thập vị trí, danh bạ, ảnh, mã quảng cáo hay định danh thiết bị để theo dõi.
- Không phân tích hành vi, không theo dõi qua ứng dụng/trang web khác.
- Không bán, cho thuê hay chia sẻ dữ liệu với bên thứ ba. Bên duy nhất xử lý dữ liệu cho chúng tôi là Google (Firebase) như mô tả ở mục 2; nhận dạng giọng nói (mục 4) chạy ngay trên máy, do hệ điều hành cung cấp.

## 7. Trẻ em

Ứng dụng dành cho trẻ em và được thiết kế theo yêu cầu của COPPA (Hoa Kỳ), GDPR (EU) và chính sách dành cho trẻ em của App Store và Google Play (Families). Chúng tôi không yêu cầu và không cố ý thu thập thông tin cá nhân của trẻ. Tên gọi của bé chỉ nằm trên máy; nếu bố mẹ bật đồng bộ thì chỉ nằm trong khối dữ liệu đã mã hoá mà chúng tôi không đọc được. Mọi phần dành cho người lớn (Góc bố mẹ, micro, chia sẻ, liên kết ngoài) đều có khoá bố mẹ.

## 8. Bố mẹ xem và xoá dữ liệu

- Xem tiến độ: Góc bố mẹ → Báo cáo của con.
- Xoá một bé: Góc bố mẹ → Các bé → Xoá.
- Xoá bản đồng bộ: Góc bố mẹ → Dùng trên nhiều máy → Xoá bản trên máy chủ.
- Xoá tất cả trên máy: gỡ ứng dụng (xoá toàn bộ dữ liệu học trên máy).

## 9. Bảo mật

Kết nối tới Firebase dùng mã hoá TLS. Bản đồng bộ được mã hoá đầu-cuối bằng khoá chỉ có trên các máy biết mã gia đình. Luật truy cập của máy chủ chỉ cho đọc/ghi đúng một ngăn khi biết tên ngăn, không cho liệt kê các ngăn.

## 10. Thay đổi chính sách

Khi chính sách thay đổi, chúng tôi cập nhật trang này và ngày hiệu lực ở đầu trang; thay đổi quan trọng sẽ được ghi trong ghi chú phiên bản của ứng dụng.

## 11. Liên hệ

Nhà phát triển Bé Vui Học — email: beatgone2503@gmail.com

Bản trên web: https://bevuihoc-app.web.app/privacy
