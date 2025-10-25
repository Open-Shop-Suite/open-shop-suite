-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V001: System Foundation
-- =============================================

-- =============================================
-- AUDIT LOG TABLE
-- =============================================
CREATE TABLE audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    operation_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id VARCHAR(255) NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,

    INDEX idx_audit_table_record (table_name, record_id),
    INDEX idx_audit_timestamp (changed_at),
    INDEX idx_audit_user (changed_by)
) ENGINE=InnoDB;


-- =============================================
-- ORDER NUMBER GENERATION FUNCTION
-- =============================================
DELIMITER //
CREATE FUNCTION generate_order_number()
RETURNS VARCHAR(50)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE seq_val INT;
    DECLARE order_date VARCHAR(8);

    -- Get next sequence value (using auto_increment table emulation)
    INSERT INTO order_number_sequence () VALUES ();
    SET seq_val = LAST_INSERT_ID();

    -- Get current date
    SET order_date = DATE_FORMAT(NOW(), '%Y%m%d');

    -- Return formatted order number
    RETURN CONCAT('ORD-', order_date, '-', LPAD(seq_val, 6, '0'));
END //
DELIMITER ;
