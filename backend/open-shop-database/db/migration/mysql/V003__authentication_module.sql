-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V003: Authentication Module
-- =============================================

-- =============================================
-- USER SESSIONS TABLE
-- =============================================
CREATE TABLE user_sessions (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    refresh_token VARCHAR(512) NOT NULL UNIQUE,
    access_token_hash VARCHAR(64),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,

    INDEX idx_session_customer (customer_id),
    INDEX idx_session_expires (expires_at),
    INDEX idx_session_active (is_active, expires_at),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- PASSWORD RESET TOKENS TABLE
-- =============================================
CREATE TABLE password_reset_tokens (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),

    INDEX idx_reset_customer (customer_id),
    INDEX idx_reset_expires (expires_at),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =============================================
-- EMAIL VERIFICATION TOKENS TABLE
-- =============================================
CREATE TABLE email_verification_tokens (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_verify_customer (customer_id),
    INDEX idx_verify_email (email),
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB;
