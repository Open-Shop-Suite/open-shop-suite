-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V003: Authentication Module
-- =============================================

-- =============================================
-- USER SESSIONS TABLE
-- =============================================
CREATE TABLE user_sessions (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    refresh_token VARCHAR(512) NOT NULL UNIQUE,
    access_token_hash VARCHAR(64),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT TRUE,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Indexes for user sessions
CREATE INDEX idx_session_customer ON user_sessions (customer_id);
CREATE INDEX idx_session_expires ON user_sessions (expires_at);
CREATE INDEX idx_session_active ON user_sessions (is_active, expires_at);

-- =============================================
-- PASSWORD RESET TOKENS TABLE
-- =============================================
CREATE TABLE password_reset_tokens (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Indexes for password reset
CREATE INDEX idx_reset_customer ON password_reset_tokens (customer_id);
CREATE INDEX idx_reset_expires ON password_reset_tokens (expires_at);

-- =============================================
-- EMAIL VERIFICATION TOKENS TABLE
-- =============================================
CREATE TABLE email_verification_tokens (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    token VARCHAR(128) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Indexes for email verification
CREATE INDEX idx_verify_customer ON email_verification_tokens (customer_id);
CREATE INDEX idx_verify_email ON email_verification_tokens (email);
