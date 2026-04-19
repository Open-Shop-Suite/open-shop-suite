-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V002: Customer Management
-- =============================================

-- =============================================
-- CUSTOMERS TABLE
-- =============================================
CREATE TABLE customers (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,

    -- OAuth fields
    google_id VARCHAR(100) UNIQUE,
    facebook_id VARCHAR(100) UNIQUE,
    linkedin_id VARCHAR(100) UNIQUE,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT chk_customer_email_format CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_customer_phone_format CHECK (phone IS NULL OR phone ~ '^\+?[1-9][0-9]{1,14}$')
);

-- Indexes for customers
CREATE INDEX idx_customer_phone ON customers (phone);
CREATE INDEX idx_customer_name ON customers (first_name, last_name);
CREATE INDEX idx_customer_email_verified ON customers (email_verified);
CREATE INDEX idx_customer_created ON customers (created_at DESC);
CREATE INDEX idx_customer_last_login ON customers (last_login_at DESC);



-- =============================================
-- CUSTOMER ADDRESSES TABLE
-- =============================================
CREATE TABLE customer_addresses (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    type address_type NOT NULL DEFAULT 'shipping',

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

    -- Geolocation fields (optional)
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    ),
    CONSTRAINT chk_address_country_format CHECK (country ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_address_phone_format CHECK (phone IS NULL OR phone ~ '^\+?[1-9][0-9]{1,14}$'),
    CONSTRAINT chk_address_coordinates CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
    )
);

-- Indexes for customer addresses
CREATE INDEX idx_address_customer ON customer_addresses (customer_id);
CREATE INDEX idx_address_type ON customer_addresses (type);
CREATE INDEX idx_address_default ON customer_addresses (customer_id, is_default, type);
CREATE INDEX idx_address_country ON customer_addresses (country);
CREATE INDEX idx_address_postal ON customer_addresses (postal_code);
CREATE INDEX idx_address_validated ON customer_addresses (is_validated);

-- =============================================
-- CUSTOMER PREFERENCES TABLE
-- =============================================
CREATE TABLE customer_preferences (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL UNIQUE,

    -- Communication preferences
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    marketing_emails BOOLEAN DEFAULT TRUE,

    -- Localization preferences
    currency CHAR(3) DEFAULT 'USD',
    language VARCHAR(5) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',

    -- Display preferences
    theme VARCHAR(20) DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'auto')),
    items_per_page INTEGER DEFAULT 20 CHECK (items_per_page BETWEEN 10 AND 100),

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_preference_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_preference_language_format CHECK (language ~ '^[a-z]{2}(-[A-Z]{2})?$')
);

-- Indexes for customer preferences
CREATE INDEX idx_preference_currency ON customer_preferences (currency);
CREATE INDEX idx_preference_language ON customer_preferences (language);

-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp trigger for customers
CREATE TRIGGER customer_updated_at_trigger
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Update timestamp trigger for addresses
CREATE TRIGGER address_updated_at_trigger
    BEFORE UPDATE ON customer_addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Update timestamp trigger for preferences
CREATE TRIGGER preference_updated_at_trigger
    BEFORE UPDATE ON customer_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
