-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V002: Customer Management
-- =============================================

-- =============================================
-- CUSTOMERS TABLE
-- =============================================
CREATE TABLE customers (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMP NULL,

    -- OAuth fields
    google_id VARCHAR(100) UNIQUE,
    facebook_id VARCHAR(100) UNIQUE,
    linkedin_id VARCHAR(100) UNIQUE,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,

    -- Indexes
    INDEX idx_customer_phone (phone),
    INDEX idx_customer_name (first_name, last_name),
    INDEX idx_customer_email_verified (email_verified),
    INDEX idx_customer_created (created_at DESC),
    INDEX idx_customer_last_login (last_login_at DESC)
) ENGINE=InnoDB;

-- =============================================
-- CUSTOMER ADDRESSES TABLE
-- =============================================
CREATE TABLE customer_addresses (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    type ENUM('shipping', 'billing', 'both') NOT NULL DEFAULT 'shipping',

    -- Name fields (support both individual and full name)
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(100),
    company VARCHAR(100),

    -- Address fields
    address_line1 VARCHAR(100) NOT NULL,
    address_line2 VARCHAR(100),
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    postal_code VARCHAR(20) NOT NULL,
    country CHAR(2) NOT NULL,
    phone VARCHAR(20),

    -- Address metadata
    is_default BOOLEAN DEFAULT FALSE,
    is_validated BOOLEAN DEFAULT FALSE,

    -- Geolocation fields
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_address_customer (customer_id),
    INDEX idx_address_type (type),
    INDEX idx_address_default (customer_id, is_default, type),
    INDEX idx_address_country (country),
    INDEX idx_address_postal (postal_code),
    INDEX idx_address_validated (is_validated),

    -- Constraints
    CONSTRAINT chk_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    )
) ENGINE=InnoDB;

-- =============================================
-- CUSTOMER PREFERENCES TABLE
-- =============================================
CREATE TABLE customer_preferences (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL UNIQUE,

    -- Communication preferences
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    marketing_emails BOOLEAN DEFAULT TRUE,

    -- Localization preferences
    currency VARCHAR(3) DEFAULT 'USD',
    language VARCHAR(5) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',

    -- Display preferences
    theme VARCHAR(20) DEFAULT 'light',
    items_per_page INT DEFAULT 20,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_preference_currency (currency),
    INDEX idx_preference_language (language),

    -- Constraints
    CONSTRAINT chk_preference_language_format CHECK (language REGEXP '^[a-z]{2}(-[A-Z]{2})?$')
) ENGINE=InnoDB;
