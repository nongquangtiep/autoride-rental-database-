-- ========================================================
-- HỆ THỐNG AUTORIDE - SỬA LỖI & TỐI ƯU HÓA CƠ SỞ DỮ LIỆU
-- File: autoride_db.sql
-- ========================================================

DROP DATABASE IF EXISTS autoride_db;
CREATE DATABASE autoride_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE autoride_db;

-- --------------------------------------------------------
-- 1. BẢNG CARS (Danh mục xe)
-- --------------------------------------------------------
CREATE TABLE Cars (
    car_id INT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    license_plate VARCHAR(20) UNIQUE NOT NULL
) ENGINE=InnoDB;

-- --------------------------------------------------------
-- 2. BẢNG RENTALS (Hợp đồng thuê xe)
-- Khắc phục Lỗi 1 & Lỗi 2:
-- - status dùng ENUM thay vì VARCHAR tự do.
-- - Thêm security_deposit, late_fee, damage_fee với DECIMAL(10, 2).
-- --------------------------------------------------------
CREATE TABLE Rentals (
    rental_id INT AUTO_INCREMENT PRIMARY KEY,
    car_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    rent_date DATETIME NOT NULL,
    return_date DATETIME NULL,
    status ENUM('BOOKED', 'ACTIVE', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'BOOKED',
    security_deposit DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (security_deposit >= 0),
    late_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (late_fee >= 0),
    damage_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (damage_fee >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (car_id) REFERENCES Cars(car_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- --------------------------------------------------------
-- 3. BẢNG INSPECTIONS (Khắc phục Lỗi 3: Biên bản kiểm tra xe)
-- --------------------------------------------------------
CREATE TABLE Inspections (
    inspection_id INT AUTO_INCREMENT PRIMARY KEY,
    rental_id INT NOT NULL,
    inspection_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    damage_description TEXT NULL,
    inspector_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (rental_id) REFERENCES Rentals(rental_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- --------------------------------------------------------
-- 4. DATABASE TRIGGER BẢO VỆ TOÀN VẸN
-- Chặn ghi nhận biên bản kiểm tra khi hợp đồng đang ở BOOKED (chưa nhận xe)
-- --------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_before_insert_inspection
BEFORE INSERT ON Inspections
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;

    SELECT status INTO v_status 
    FROM Rentals 
    WHERE rental_id = NEW.rental_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi nghiệp vụ: Hợp đồng thuê xe không tồn tại.';
    ELSEIF v_status = 'BOOKED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi nghiệp vụ: Xe chưa được bàn giao (trạng thái BOOKED), không thể lập biên bản kiểm tra trả xe.';
    END IF;
END;
//

DELIMITER ;

-- ========================================================
-- 5. CHÈP LIỆU THỰC TẾ & MÔ PHỎNG LUỒNG NGHIỆP VỤ (DML)
-- ========================================================

-- Khởi tạo danh mục xe
INSERT INTO Cars (model_name, license_plate) VALUES 
('VinFast VF8', '30K-888.88'),
('Toyota Camry', '29A-999.99');

-- Kịch bản:
-- Bước 1: Khách hàng "Nguyen Van A" thuê xe VF8, cọc 10.000.000 VNĐ, trạng thái ACTIVE
INSERT INTO Rentals (car_id, customer_name, rent_date, status, security_deposit)
VALUES (1, 'Nguyen Van A', '2026-10-01 08:00:00', 'ACTIVE', 10000000.00);

SET @current_rental_id = LAST_INSERT_ID();

-- Bước 2: Khách trả xe, nhân viên kiểm tra phát hiện vỡ đèn pha trái
INSERT INTO Inspections (rental_id, inspection_date, damage_description, inspector_name)
VALUES (@current_rental_id, '2026-10-03 17:30:00', 'Vỡ đèn pha trái', 'Nhan vien Nguyen Van Kiem');

-- Bước 3: Cập nhật hợp đồng hoàn tất: Ghi nhận trả trễ (late_fee = 0), hư hỏng (damage_fee = 2.000.000 VNĐ)
UPDATE Rentals 
SET return_date = '2026-10-03 17:30:00',
    status = 'COMPLETED',
    late_fee = 0.00,
    damage_fee = 2000000.00
WHERE rental_id = @current_rental_id;

-- ========================================================
-- 6. TRUY VẤN TÍNH TOÁN TIỀN HOÀN TRẢ CHO KHÁCH & ĐỐI SOÁT
-- ========================================================

-- Truy vấn chi tiết hợp đồng, biên bản kiểm tra và số tiền thực tế hoàn lại
SELECT 
    r.rental_id,
    r.customer_name,
    c.model_name,
    c.license_plate,
    r.rent_date,
    r.return_date,
    r.status,
    i.damage_description,
    r.security_deposit,
    r.late_fee,
    r.damage_fee,
    -- Công thức tính tiền hoàn trả chính xác cho khách
    (r.security_deposit - r.late_fee - r.damage_fee) AS refund_amount
FROM Rentals r
JOIN Cars c ON r.car_id = c.car_id
LEFT JOIN Inspections i ON r.rental_id = i.rental_id
WHERE r.rental_id = @current_rental_id;