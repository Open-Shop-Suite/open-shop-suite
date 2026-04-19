-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V003: Authentication Module
-- =============================================

-- =============================================
-- USER SESSIONS TABLE
-- =============================================
CREATE TABLE user_sessions (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    refresh_token VARCHAR2(512) NOT NULL UNIQUE,
    access_token_hash VARCHAR2(64),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR2(45),
    user_agent CLOB,
    device_type VARCHAR2(20) DEFAULT 'api' NOT NULL CHECK (device_type IN ('web', 'mobile_ios', 'mobile_android', 'desktop', 'api')),
    device_name VARCHAR2(255),
    location VARCHAR2(255),
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),

    CONSTRAINT fk_session_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE
);

-- INDEXES for user_sessions
CREATE INDEX idx_session_customer ON user_sessions (customer_id);
CREATE INDEX idx_session_expires ON user_sessions (expires_at);
CREATE INDEX idx_session_active ON user_sessions (is_active, expires_at);

-- COMMENTS for user_sessions
COMMENT ON TABLE  user_sessions IS 'Active user sessions for authentication and security tracking';
COMMENT ON COLUMN user_sessions.refresh_token IS 'Unique refresh token for session renewal';
COMMENT ON COLUMN user_sessions.device_type   IS 'Client platform inferred from User-Agent; defaults to api for headless clients';
COMMENT ON COLUMN user_sessions.device_name   IS 'Human-readable device description inferred from User-Agent (e.g. Chrome on macOS)';
COMMENT ON COLUMN user_sessions.location      IS 'Approximate location derived from IP at session creation (e.g. New York, US); null if geolocation unavailable';

-- =============================================
-- PASSWORD RESET TOKENS TABLE
-- =============================================
CREATE TABLE password_reset_tokens (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    token VARCHAR2(128) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR2(45),

    CONSTRAINT fk_reset_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE
);

-- INDEXES for password_reset_tokens
CREATE INDEX idx_reset_customer ON password_reset_tokens (customer_id);
CREATE INDEX idx_reset_expires ON password_reset_tokens (expires_at);

-- COMMENTS for password_reset_tokens
COMMENT ON TABLE password_reset_tokens IS 'Temporary tokens for password reset functionality';
COMMENT ON COLUMN password_reset_tokens.token IS 'Secure token for password reset verification';

-- =============================================
-- EMAIL VERIFICATION TOKENS TABLE
-- =============================================
CREATE TABLE email_verification_tokens (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    token VARCHAR2(128) NOT NULL UNIQUE,
    email VARCHAR2(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_verify_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE
);

-- INDEXES for email_verification_tokens
CREATE INDEX idx_verify_customer ON email_verification_tokens (customer_id);
CREATE INDEX idx_verify_email ON email_verification_tokens (email);

-- COMMENTS for email_verification_tokens
COMMENT ON TABLE email_verification_tokens IS 'Tokens for verifying customer email addresses';
COMMENT ON COLUMN email_verification_tokens.token IS 'Unique verification token sent via email';

-- =============================================
-- OAUTH STATES TABLE
-- =============================================
CREATE TABLE oauth_states (
    state      VARCHAR2(128) NOT NULL,
    provider   VARCHAR2(20)  NOT NULL CHECK (provider IN ('google', 'facebook', 'linkedin')),
    channel    VARCHAR2(20)  NOT NULL CHECK (channel IN ('web', 'mobile_ios', 'mobile_android', 'desktop')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at    TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_oauth_states PRIMARY KEY (state)
);

-- INDEXES for oauth_states
CREATE INDEX idx_oauth_state_expires  ON oauth_states (expires_at);
CREATE INDEX idx_oauth_state_provider ON oauth_states (provider);

-- COMMENTS for oauth_states
COMMENT ON TABLE  oauth_states             IS 'Short-lived CSRF state tokens for OAuth authorization flow';
COMMENT ON COLUMN oauth_states.state       IS 'Cryptographically random token used as CSRF state; single-use';
COMMENT ON COLUMN oauth_states.channel     IS 'Client platform that initiated the OAuth flow; used to resolve redirect URI server-side';
COMMENT ON COLUMN oauth_states.expires_at  IS 'State expires 10 minutes after creation';
COMMENT ON COLUMN oauth_states.used_at     IS 'Set when the callback consumes the state; prevents replay attacks';
