# 🌍 World Time

# Giới thiệu

Ứng dụng Flutter hiển thị múi giờ và chuyển đổi thời gian giữa các thành phố trên thế giới.

## 🚀 Tính năng chính
- Hiển thị danh sách các thành phố với giờ địa phương tương ứng
- Chọn khoảng thời gian và xem quy đổi sang các thành phố khác
- Đặt thành phố mặc định (home) để làm chuẩn
- Tạo sự kiện Google Calendar từ khoảng thời gian đã chọn
- Giao diện tối ưu cho màn hình ngang (landscape)

## 📸 Giao diện minh họa
<img width="2400" height="1080" alt="image" src="https://github.com/user-attachments/assets/9f05d1ba-d528-4e1f-afeb-f7a7464f9729" />
<img width="2400" height="1080" alt="image" src="https://github.com/user-attachments/assets/c154a0c9-7fbc-4ce3-8f7b-2a71b9dc350d" />

## 🛠️ Công nghệ sử dụng
- Flutter SDK (ngôn ngữ Dart)
- Android Studio / VS Code
- Git & GitHub để quản lý phiên bản
- Các package: get, timezone, intl, flutter_launcher_icons

## 📦 Cài đặt & chạy thử
Yêu cầu:
- Flutter SDK
- Android Studio hoặc VS Code

Các bước:
```bash
git clone https://github.com/705105001-LQKA/world_time.git
cd world_time
flutter pub get
flutter run
```

## 📁 Cấu trúc thư mục
- `lib/` – mã nguồn chính của ứng dụng  
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` – cấu hình build cho từng nền tảng  
- `test/` – các bài test đơn vị  
- `.gitignore` – danh sách file/directory không đưa lên GitHub  
- `pubspec.yaml` – khai báo dependencies và metadata dự án  

## 📦 Phụ thuộc chính
- `get` – quản lý trạng thái  
- `timezone` – xử lý múi giờ chính xác  
- `intl` – định dạng thời gian  
- `flutter_launcher_icons` – tuỳ chỉnh icon ứng dụng  

📅 Lưu ý về Google Calendar API
Ứng dụng này không sử dụng Firebase, nên sẽ không có file google-services.json (Android) hoặc GoogleService-Info.plist (iOS) trong repo.
Thay vào đó, ứng dụng dùng trực tiếp Google Sign-In SDK để lấy accessToken và gọi Google Calendar API.
🔧 Để sử dụng chức năng Google Calendar:
1. Vào Google Cloud Console.
2. Tạo một OAuth Client ID cho ứng dụng Flutter của bạn:
- Android: khai báo package name và SHA-1 key.
- iOS: khai báo bundle ID.
3. Bật Google Calendar API trong project.
4. Khi chạy app, người dùng đăng nhập bằng Google → ứng dụng sẽ tự động lấy accessToken.
5. Token này được dùng để tạo sự kiện trên Calendar qua API.

## 📄 Giấy phép
Dự án này sử dụng [MIT License](LICENSE). Bạn có thể sử dụng, sửa đổi và chia sẻ mã nguồn tự do.

🤝 Đóng góp
Mọi ý tưởng, bug report hoặc pull request đều được hoan nghênh.
Nếu bạn muốn đóng góp vào dự án, hãy làm theo các bước sau:
1. Fork repo
Nhấn nút Fork trên GitHub để tạo một bản sao repo này vào tài khoản của bạn.
2. Clone repo đã fork về máy
```bash
git clone https://github.com/your-username/world_time.git
cd world_time
```
3. Tạo nhánh mới cho tính năng hoặc sửa lỗi
```bash
git checkout -b feature/your-feature-name
```
4. Commit và push thay đổi lên repo fork
```
git commit -m "Add your feature"
git push origin feature/your-feature-name
```
5. Tạo Pull Request (PR)
Vào GitHub, mở repo gốc, nhấn New Pull Request để gửi thay đổi của bạn.
Mô tả rõ ràng tính năng hoặc lỗi bạn đã sửa để người duyệt dễ hiểu.
📌 Lưu ý
- Hãy đảm bảo code của bạn tuân thủ style guide của Flutter/Dart.
- Viết commit message rõ ràng, ngắn gọn.
- Nếu thêm tính năng mới, hãy cập nhật README hoặc viết test kèm theo.
---

## 📬 Liên hệ
- GitHub: [705105001-LQKA](https://github.com/705105001-LQKA)  
- Email: *lequykhangan@gmail.com*
