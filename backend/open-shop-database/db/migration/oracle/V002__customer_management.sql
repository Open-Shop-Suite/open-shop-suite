-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V002: Customer Management
-- =============================================

-- =============================================
-- CUSTOMERS TABLE
-- =============================================
CREATE TABLE customers (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    email VARCHAR2(255) NOT NULL UNIQUE,
    password_hash VARCHAR2(128) NOT NULL,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    phone VARCHAR2(20),
    date_of_birth DATE,
    email_verified NUMBER(1) DEFAULT 0 CHECK (email_verified IN (0,1)),
    email_verified_at TIMESTAMP WITH TIME ZONE,

    -- OAuth fields
    google_id VARCHAR2(100) UNIQUE,
    facebook_id VARCHAR2(100) UNIQUE,
    linkedin_id VARCHAR2(100) UNIQUE,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- INDEXES for customers
-- idx_customer_email removed: email column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_customer_phone ON customers (phone);
CREATE INDEX idx_customer_name ON customers (first_name, last_name);
-- OAuth indexes removed: google_id, facebook_id, linkedin_id columns have UNIQUE constraints which create indexes automatically
CREATE INDEX idx_customer_email_verified ON customers (email_verified);
CREATE INDEX idx_customer_created ON customers (created_at DESC);
CREATE INDEX idx_customer_last_login ON customers (last_login_at DESC);

-- COMMENTS for customers
COMMENT ON TABLE customers IS 'Core customer accounts and authentication data';
COMMENT ON COLUMN customers.google_id IS 'OAuth Google ID for social login integration';
COMMENT ON COLUMN customers.facebook_id IS 'OAuth Facebook ID for social login integration';
COMMENT ON COLUMN customers.linkedin_id IS 'OAuth LinkedIn ID for social login integration';

-- =============================================
-- CUSTOMER ADDRESSES TABLE
-- =============================================
CREATE TABLE customer_addresses (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id RAW(16) NOT NULL,
    type VARCHAR2(20) DEFAULT 'shipping' CHECK (type IN ('shipping', 'billing', 'both')),

    -- Name fields (support both individual and full name)
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    full_name VARCHAR2(100),
    company VARCHAR2(100),

    -- Address fields
    address_line1 VARCHAR2(100) NOT NULL,
    address_line2 VARCHAR2(100),
    city VARCHAR2(50) NOT NULL,
    state VARCHAR2(50),
    postal_code VARCHAR2(20) NOT NULL,
    country VARCHAR2(2) NOT NULL,
    phone VARCHAR2(20),

    -- Address metadata
    is_default NUMBER(1) DEFAULT 0 CHECK (is_default IN (0,1)),
    is_validated NUMBER(1) DEFAULT 0 CHECK (is_validated IN (0,1)),

    -- Geolocation fields using Oracle Spatial (optional)
    latitude NUMBER(10,8),
    longitude NUMBER(11,8),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    ),
    CONSTRAINT chk_address_coordinates CHECK (
        (latitude IS NULL AND longitude IS NULL) OR
        (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
    )
);

-- INDEXES for customer_addresses
CREATE INDEX idx_address_customer ON customer_addresses (customer_id);
CREATE INDEX idx_address_type ON customer_addresses (type);
CREATE INDEX idx_address_default ON customer_addresses (customer_id, is_default, type);
CREATE INDEX idx_address_country ON customer_addresses (country);
CREATE INDEX idx_address_postal ON customer_addresses (postal_code);
CREATE INDEX idx_address_validated ON customer_addresses (is_validated);

-- COMMENTS for customer_addresses
COMMENT ON TABLE customer_addresses IS 'Customer shipping and billing addresses with spatial support';
COMMENT ON COLUMN customer_addresses.type IS 'Address type: shipping, billing, or both';
COMMENT ON COLUMN customer_addresses.is_validated IS 'Whether address has been validated through address verification service';

-- =============================================
-- CUSTOMER PREFERENCES TABLE
-- =============================================
CREATE TABLE customer_preferences (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id RAW(16) NOT NULL UNIQUE,

    -- Communication preferences
    email_notifications NUMBER(1) DEFAULT 1 CHECK (email_notifications IN (0,1)),
    sms_notifications NUMBER(1) DEFAULT 0 CHECK (sms_notifications IN (0,1)),
    push_notifications NUMBER(1) DEFAULT 1 CHECK (push_notifications IN (0,1)),
    marketing_emails NUMBER(1) DEFAULT 1 CHECK (marketing_emails IN (0,1)),

    -- Localization preferences
    currency VARCHAR2(3) DEFAULT 'USD',
    language VARCHAR2(5) DEFAULT 'en' CHECK (REGEXP_LIKE(language, '^[a-z]{2}(-[A-Z]{2})?$')),
    timezone VARCHAR2(50) DEFAULT 'UTC',

    -- Display preferences
    theme VARCHAR2(20) DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'auto')),
    items_per_page NUMBER(3) DEFAULT 20 CHECK (items_per_page BETWEEN 10 AND 100),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_preference_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE
);

-- INDEXES for customer_preferences
-- idx_preference_customer removed: customer_id column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_preference_currency ON customer_preferences (currency);
CREATE INDEX idx_preference_language ON customer_preferences (language);

-- COMMENTS for customer_preferences
COMMENT ON TABLE customer_preferences IS 'Detailed customer preferences and settings';
COMMENT ON COLUMN customer_preferences.language IS 'Language preference in ISO 639-1 format (e.g., en, fr, es)';
COMMENT ON COLUMN customer_preferences.currency IS 'Preferred currency code in ISO 4217 format';
