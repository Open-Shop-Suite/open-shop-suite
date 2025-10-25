-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V001: System Foundation
-- =============================================

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS openshop;
SET search_path TO openshop;

-- Create UUID extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create pg_trgm extension for text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================
-- CUSTOM TYPES
-- =============================================

-- Operation types for audit
CREATE TYPE operation_type AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- Address types
CREATE TYPE address_type AS ENUM ('shipping', 'billing', 'both');

-- Order statuses
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled');

-- Inventory statuses
CREATE TYPE inventory_status AS ENUM ('active', 'discontinued', 'out_of_stock', 'backordered');

-- Dimension units
CREATE TYPE dimension_unit AS ENUM ('mm', 'cm', 'in', 'ft');

-- Product image types
CREATE TYPE image_type AS ENUM ('main', 'gallery', 'thumbnail', 'zoom', 'lifestyle', 'detail', 'size_chart');

-- Product status
CREATE TYPE product_status AS ENUM ('draft', 'active', 'inactive', 'archived');

-- Cart status
CREATE TYPE cart_status AS ENUM ('active', 'abandoned', 'converted', 'expired');

-- Payment status
CREATE TYPE payment_status AS ENUM ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded');

-- Shipping status
CREATE TYPE shipping_status AS ENUM ('pending', 'created', 'in_transit', 'delivered', 'exception', 'returned');

-- =============================================
-- AUDIT AND TRACKING TABLES
-- =============================================

-- General audit log table
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    operation_type operation_type NOT NULL,
    record_id VARCHAR(255) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(255),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Indexes for audit log
CREATE INDEX idx_audit_table_record ON audit_log (table_name, record_id);
CREATE INDEX idx_audit_timestamp ON audit_log (changed_at);
CREATE INDEX idx_audit_user ON audit_log (changed_by);

-- =============================================
-- SEQUENCE GENERATORS
-- =============================================

-- Order number sequence
CREATE SEQUENCE order_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

-- =============================================
-- UTILITY FUNCTIONS
-- =============================================

-- Function to generate order numbers
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
    seq_val BIGINT;
    order_date TEXT;
BEGIN
    seq_val := nextval('order_number_seq');
    order_date := to_char(CURRENT_DATE, 'YYYYMMDD');
    RETURN 'ORD-' || order_date || '-' || lpad(seq_val::text, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Function for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
