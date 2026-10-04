# Báo Cáo Phân Tích Đối Chiếu: Nghiệp Vụ Trả Xe & Toàn Vẹn CSDL
**Dự án:** Hệ thống Cho thuê xe Tự lái AutoRide  
**Vai trò:** Data Architect  

### 1. Bảng chẩn đoán khoảng trống dữ liệu (Data Gaps Analysis)

| Điểm chạm Activity Diagram | Thiết kế Legacy Database | Hậu quả vận hành thực tế |
| :--- | :--- | :--- |
| **Quản lý vòng đời hợp đồng:** `BOOKED` $\rightarrow$ `ACTIVE` $\rightarrow$ `COMPLETED` / `CANCELLED` | Cột `status VARCHAR(50) DEFAULT 'BOOKED'` không ràng buộc. | Dữ liệu trạng thái nhập tự do, dễ sai chính tả, không kiểm soát được tiến trình hợp đồng. |
| **Nhánh rẽ tính phạt:** Tính phí trả trễ (`late_fee`) và phí sửa chữa hư hại (`damage_fee`) | Hoàn toàn vắng mặt các cột tài chính trong bảng `Rentals`. | Ứng dụng không có trường lưu vết khấu trừ, nhân viên buộc phải hoàn 100% cọc hoặc ghi chép sổ tay gây thất thoát doanh thu. |
| **Biên bản kiểm tra xe (Inspection):** Ghi nhận chi tiết vị trí trầy xước, vỡ linh kiện | Hoàn toàn không có bảng `Inspections`. | Không lưu trữ được bằng chứng kiểm định xe, người kiểm tra và thời điểm bàn giao xe. |

---

### 2. Tầm quan trọng bắt buộc của cột `damage_fee` đối với tính toàn vẹn hệ thống
Trong quy trình hoàn tất trả xe của AutoRide, dòng tiền hoàn trả được xác định theo công thức nghiệp vụ:  
$$\text{Tiền hoàn trả (Refund)} = \text{Tiền cọc} - \text{Phí phạt trễ} - \text{Phí sửa chữa}$$

Cột `damage_fee` (kiểu `DECIMAL(10, 2)`) bắt buộc phải tồn tại trong bảng `Rentals` vì 3 lý do cốt lõi:
1. **Toàn vẹn dòng tiền (Financial Integrity):** Nếu thiếu trường lưu trữ này, hệ thống không thể thực hiện phép tính tự động để khấu trừ tiền đền bù vào tiền cọc (`security_deposit`). Điều này dẫn tới việc hoàn trả dư tiền cho khách hàng, gây tổn thất tài chính trực tiếp cho startup.
2. **Minh bạch sổ sách đối soát (Audit Trail):** Giúp kế toán cuối tháng phân định rạch ròi giữa doanh thu dịch vụ cho thuê thông thường và khoản bồi hoàn phục vụ sửa chữa tài sản doanh nghiệp.
3. **Đồng bộ hóa nghiệp vụ:** Đảm bảo kết quả thẩm định xe ngoài thực tế (tại bảng `Inspections`) được chuyển đổi trực tiếp thành số liệu tài chính ràng buộc trên hợp đồng `Rentals` trước khi chuyển sang trạng thái `COMPLETED`.
