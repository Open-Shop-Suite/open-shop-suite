-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V005: Shopping Cart
-- =============================================

-- =============================================
-- SHOPPING CARTS TABLE
-- =============================================
CREATE TABLE shopping_carts (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(128),  -- For guest carts

    -- Cart metadata
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'abandoned', 'converted', 'expired')),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Applied discounts and coupons
    coupon_code VARCHAR(50),
    coupon_discount_amount DECIMAL(12,2) DEFAULT 0,
    coupon_discount_type VARCHAR(20) DEFAULT 'fixed' CHECK (coupon_discount_type IN ('fixed', 'percentage')),

    -- Calculated totals (updated by triggers)
    item_count INT DEFAULT 0,
    subtotal DECIMAL(12,2) DEFAULT 0,
    discount_total DECIMAL(12,2) DEFAULT 0,
    tax_estimate DECIMAL(12,2) DEFAULT 0,
    shipping_estimate DECIMAL(12,2) DEFAULT 0,
    total_estimate DECIMAL(12,2) DEFAULT 0,

    -- Tax and shipping calculation data
    tax_rate DECIMAL(5,4) DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 1),
    shipping_address_id VARCHAR(36),
    billing_address_id VARCHAR(36),

    -- Cart lifecycle timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(id) ON DELETE SET NULL,

    -- Indexes
    INDEX idx_cart_customer (customer_id),
    INDEX idx_cart_session (session_id),
    INDEX idx_cart_status (status),
    INDEX idx_cart_last_activity (last_activity_at),
    INDEX idx_cart_expires (expires_at),
    INDEX idx_cart_coupon (coupon_code)
) ENGINE=InnoDB;

-- =============================================
-- SHOPPING CART ITEMS TABLE
-- =============================================
CREATE TABLE shopping_cart_items (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    cart_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36) NOT NULL,

    -- Item details (snapshot at time of addition)
    quantity INT NOT NULL CHECK (quantity > 0),
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
    availability_checked_at TIMESTAMP,
    is_available BOOLEAN DEFAULT TRUE,
    availability_message TEXT,

    -- Audit fields
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (cart_id) REFERENCES shopping_carts(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Unique constraint to prevent duplicate items
    UNIQUE KEY uk_cart_item_variant (cart_id, variant_id),

    -- Indexes
    INDEX idx_cart_item_cart (cart_id),
    INDEX idx_cart_item_product (product_id),
    INDEX idx_cart_item_variant (variant_id),
    INDEX idx_cart_item_availability (availability_checked_at, is_available),
    INDEX idx_cart_item_added (added_at)
) ENGINE=InnoDB;
