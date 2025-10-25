-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V005: Shopping Cart
-- =============================================

-- =============================================
-- SHOPPING CARTS TABLE
-- =============================================
CREATE TABLE shopping_carts (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id RAW(16) NOT NULL,
    session_id VARCHAR2(128),  -- For guest carts

    -- Cart metadata
    status VARCHAR2(20) DEFAULT 'active' CHECK (status IN ('active', 'abandoned', 'converted', 'expired')),
    currency VARCHAR2(3) DEFAULT 'USD',

    -- Applied discounts and coupons
    coupon_code VARCHAR2(50),
    coupon_discount_amount NUMBER(12,2) DEFAULT 0,
    coupon_discount_type VARCHAR2(20) DEFAULT 'fixed' CHECK (coupon_discount_type IN ('fixed', 'percentage')),

    -- Calculated totals (updated by triggers)
    item_count NUMBER DEFAULT 0,
    subtotal NUMBER(12,2) DEFAULT 0,
    discount_total NUMBER(12,2) DEFAULT 0,
    tax_estimate NUMBER(12,2) DEFAULT 0,
    shipping_estimate NUMBER(12,2) DEFAULT 0,
    total_estimate NUMBER(12,2) DEFAULT 0,

    -- Tax and shipping calculation data
    tax_rate NUMBER(5,4) DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 1),
    shipping_address_id RAW(16),
    billing_address_id RAW(16),

    -- Cart lifecycle timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Foreign keys
    CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_shipping_address FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL,
    CONSTRAINT fk_cart_billing_address FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL
);

-- INDEXES for shopping_carts
CREATE INDEX idx_cart_customer ON shopping_carts (customer_id);
CREATE INDEX idx_cart_session ON shopping_carts (session_id);
CREATE INDEX idx_cart_status ON shopping_carts (status);
CREATE INDEX idx_cart_last_activity ON shopping_carts (last_activity_at);
CREATE INDEX idx_cart_expires ON shopping_carts (expires_at);
CREATE INDEX idx_cart_coupon ON shopping_carts (coupon_code);

-- COMMENTS for shopping_carts
COMMENT ON TABLE shopping_carts IS 'Customer shopping carts with calculated totals and lifecycle tracking';
COMMENT ON COLUMN shopping_carts.session_id IS 'Session ID for guest carts before customer login';
COMMENT ON COLUMN shopping_carts.total_estimate IS 'Estimated total including tax and shipping';

-- =============================================
-- SHOPPING CART ITEMS TABLE
-- =============================================
CREATE TABLE shopping_cart_items (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    cart_id RAW(16) NOT NULL,
    product_id RAW(16) NOT NULL,
    variant_id RAW(16) NOT NULL,

    -- Item details (snapshot at time of addition)
    quantity NUMBER NOT NULL CHECK (quantity > 0),
    unit_price NUMBER(12,2) NOT NULL,
    line_total NUMBER GENERATED ALWAYS AS (quantity * unit_price),

    -- Product snapshot data (to handle product changes)
    product_name VARCHAR2(200) NOT NULL,
    product_slug VARCHAR2(200) NOT NULL,
    variant_name VARCHAR2(100) NOT NULL,
    variant_sku VARCHAR2(100) NOT NULL,

    -- Product attributes at time of addition
    color_name VARCHAR2(50),
    size_name VARCHAR2(50),
    material VARCHAR2(100),
    primary_image_url VARCHAR2(500),

    -- Item-specific discounts
    discount_amount NUMBER(12,2) DEFAULT 0,
    discount_type VARCHAR2(20) DEFAULT 'fixed',
    discount_reason VARCHAR2(255),

    -- Item availability checking
    availability_checked_at TIMESTAMP WITH TIME ZONE,
    is_available NUMBER(1) DEFAULT 1 CHECK (is_available IN (0,1)),
    availability_message CLOB,

    -- Audit fields
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_cart_item_cart FOREIGN KEY (cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_item_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_item_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Unique constraint to prevent duplicate items
    CONSTRAINT uk_cart_item_variant UNIQUE (cart_id, variant_id)
);

-- INDEXES for shopping_cart_items
CREATE INDEX idx_cart_item_cart ON shopping_cart_items (cart_id);
CREATE INDEX idx_cart_item_product ON shopping_cart_items (product_id);
CREATE INDEX idx_cart_item_variant ON shopping_cart_items (variant_id);
CREATE INDEX idx_cart_item_availability ON shopping_cart_items (availability_checked_at, is_available);
CREATE INDEX idx_cart_item_added ON shopping_cart_items (added_at);

-- COMMENTS for shopping_cart_items
COMMENT ON TABLE shopping_cart_items IS 'Items in shopping carts with product snapshots and availability tracking';
COMMENT ON COLUMN shopping_cart_items.line_total IS 'Calculated as quantity * unit_price';
COMMENT ON COLUMN shopping_cart_items.is_available IS 'Whether item is still available for purchase';
