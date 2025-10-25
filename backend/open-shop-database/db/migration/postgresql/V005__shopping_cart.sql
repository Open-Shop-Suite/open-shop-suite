-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V005: Shopping Cart
-- =============================================

-- =============================================
-- SHOPPING CARTS TABLE
-- =============================================
CREATE TABLE shopping_carts (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    session_id VARCHAR(128),  -- For guest carts

    -- Cart metadata
    status cart_status DEFAULT 'active',
    currency VARCHAR(3) DEFAULT 'USD',

    -- Applied discounts and coupons
    coupon_code VARCHAR(50),
    coupon_discount_amount DECIMAL(12,2) DEFAULT 0,
    coupon_discount_type VARCHAR(20) DEFAULT 'fixed',

    -- Calculated totals (updated by triggers)
    item_count INTEGER DEFAULT 0,
    subtotal DECIMAL(12,2) DEFAULT 0,
    discount_total DECIMAL(12,2) DEFAULT 0,
    tax_estimate DECIMAL(12,2) DEFAULT 0,
    shipping_estimate DECIMAL(12,2) DEFAULT 0,
    total_estimate DECIMAL(12,2) DEFAULT 0,

    -- Tax and shipping calculation data
    tax_rate DECIMAL(5,4) DEFAULT 0,
    shipping_address_id UUID,
    billing_address_id UUID,

    -- Cart lifecycle timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_cart_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_cart_amounts_non_negative CHECK (
        subtotal >= 0 AND discount_total >= 0 AND
        tax_estimate >= 0 AND shipping_estimate >= 0 AND total_estimate >= 0
    ),
    CONSTRAINT chk_cart_tax_rate_valid CHECK (tax_rate >= 0 AND tax_rate <= 1),
    CONSTRAINT chk_cart_coupon_discount CHECK (coupon_discount_amount >= 0)
);

-- Indexes for shopping carts
CREATE INDEX idx_cart_customer ON shopping_carts (customer_id);
CREATE INDEX idx_cart_session ON shopping_carts (session_id);
CREATE INDEX idx_cart_status ON shopping_carts (status);
CREATE INDEX idx_cart_last_activity ON shopping_carts (last_activity_at);
CREATE INDEX idx_cart_expires ON shopping_carts (expires_at);
CREATE INDEX idx_cart_coupon ON shopping_carts (coupon_code);

-- =============================================
-- SHOPPING CART ITEMS TABLE
-- =============================================
CREATE TABLE shopping_cart_items (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    cart_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant_id UUID NOT NULL,

    -- Item details (snapshot at time of addition)
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    -- Product snapshot data (to handle product changes)
    product_name VARCHAR(200) NOT NULL,
    product_slug VARCHAR(200) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    variant_sku VARCHAR(100) NOT NULL,

    -- Product attributes at time of addition
    color_name VARCHAR(50),
    size_name VARCHAR(50),
    material VARCHAR(100),
    primary_image_url VARCHAR(500),

    -- Item-specific discounts
    discount_amount DECIMAL(12,2) DEFAULT 0,
    discount_type VARCHAR(20) DEFAULT 'fixed',
    discount_reason VARCHAR(255),

    -- Item availability checking
    availability_checked_at TIMESTAMPTZ,
    is_available BOOLEAN DEFAULT TRUE,
    availability_message TEXT,

    -- Audit fields
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_cart_item_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_cart_item_price_non_negative CHECK (unit_price >= 0),
    CONSTRAINT chk_cart_item_discount_non_negative CHECK (discount_amount >= 0),

    -- Unique constraint to prevent duplicate items
    UNIQUE (cart_id, variant_id)
);

-- Indexes for cart items
CREATE INDEX idx_cart_item_cart ON shopping_cart_items (cart_id);
CREATE INDEX idx_cart_item_product ON shopping_cart_items (product_id);
CREATE INDEX idx_cart_item_variant ON shopping_cart_items (variant_id);
CREATE INDEX idx_cart_item_availability ON shopping_cart_items (availability_checked_at, is_available);
CREATE INDEX idx_cart_item_added ON shopping_cart_items (added_at);

-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp triggers for carts
CREATE TRIGGER cart_updated_at_trigger
    BEFORE UPDATE ON shopping_carts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER cart_item_updated_at_trigger
    BEFORE UPDATE ON shopping_cart_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
