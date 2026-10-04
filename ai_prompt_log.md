# Nhật Ký Trao Đổi Kỹ Thuật Với AI (AI Prompt Log)
**Học viên:** Nông Quang Tiệp  
**Vai trò:** Data Architect  

---

### Phiên 1: Xử lý rủi ro kiểu số thực và sai số kế toán
* **Prompt:**  
  *"Tại sao trong các hệ thống tính toán chiết khấu tiền cọc và phạt như AutoRide, lập trình viên tuyệt đối không được dùng FLOAT hoặc DOUBLE cho các cột security_deposit, late_fee, damage_fee? Dùng DECIMAL(10, 2) mang lại lợi ích gì?"*
* **Tóm tắt phản hồi của AI:**  
  * `FLOAT` và `DOUBLE` sử dụng định dạng dấu phẩy động nhị phân IEEE 754, gây sai số làm tròn khi thực hiện các phép toán trừ liên tiếp (ví dụ: $10000000 - 2000000$ có thể bị lệch thành $7999999.999999$).
  * `DECIMAL(10, 2)` là kiểu số có độ chính xác cố định (Fixed-point), lưu trữ chính xác tuyệt đối từng con số thập phân, đảm bảo số dư kế toán luôn khớp với tài khoản ngân hàng.

---

### Phiên 2: Phân tích quan hệ 1-1 vs 1-N cho bảng Inspections
* **Prompt:**  
  *"Khi thiết kế bảng lưu Biên bản kiểm tra xe (Inspections), tại sao nên tách thành bảng riêng thay vì thêm một cột `damage_description` vào bảng `Rentals`? Bảng này nên là quan hệ 1-1 hay 1-N với `Rentals`?"*
* **Tóm tắt phản hồi của AI:**  
  * Tách bảng riêng tuân thủ nguyên tắc chuẩn hóa dữ liệu (Normalization). Bảng `Rentals` chỉ phục vụ giao dịch hợp đồng, trong khi kiểm tra xe là hành động vật lý tại hiện trường.
  * Nếu gộp vào `Rentals`, khi xe trả về không bị hư hại gì, cột `damage_description` sẽ bị dư thừa giá trị `NULL`.
  * Thiết kế quan hệ 1-N cho phép ghi nhận nhiều lần kiểm tra trong một vòng đời thuê xe (ví dụ: biên bản kiểm tra lúc giao xe ban đầu và biên bản kiểm tra lúc nhận lại xe khi hoàn tất).

---

### Phiên 3: Ràng buộc nghiệp vụ trạng thái bằng Database Trigger
* **Prompt:**  
  *"Tôi muốn đảm bảo rằng nếu hợp đồng đang ở trạng thái BOOKED (khách chưa nhận xe), hệ thống cơ sở dữ liệu phải chặn không cho tạo biên bản kiểm tra trong bảng Inspections. Khóa ngoại có làm được việc này không và cú pháp Trigger trong MySQL viết như thế nào?"*
* **Tóm tắt phản hồi của AI:**  
  * Foreign Key chỉ kiểm tra sự tồn tại của `rental_id`, không thể kiểm tra giá trị của cột `status`.
  * Bắt buộc sử dụng `BEFORE INSERT TRIGGER` trên bảng `Inspections`, kiểm tra `SELECT status FROM Rentals WHERE rental_id = NEW.rental_id`. Nếu bằng `BOOKED`, dùng lệnh `SIGNAL SQLSTATE '45000'` để hủy giao dịch và thông báo lỗi.
