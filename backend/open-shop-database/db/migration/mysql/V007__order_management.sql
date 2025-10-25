-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V007: Order Management
-- =============================================

-- =============================================
-- ORDERS TABLE
-- =============================================
CREATE TABLE orders (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id VARCHAR(36) NOT NULL,

    -- Order status and workflow
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),

    -- Order financial information
    subtotal DECIMAL(12,2) NOT NULL,
    discount_total DECIMAL(12,2) DEFAULT 0,
    tax_total DECIMAL(12,2) DEFAULT 0,
    shipping_cost DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',

    -- Applied discounts
    coupon_code VARCHAR(50),
    coupon_discount_amount DECIMAL(12,2) DEFAULT 0,
    coupon_discount_type VARCHAR(20) DEFAULT 'fixed',

    -- Customer notes and special instructions
    customer_notes TEXT,
    special_instructions TEXT,

    -- Order fulfillment information
    requires_shipping BOOLEAN DEFAULT TRUE,
    weight_total DECIMAL(8,3),  -- total weight in grams

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP NULL,
    shipped_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    cancelled_at TIMESTAMP NULL,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id),

    -- Indexes
    INDEX idx_order_customer (customer_id),
    INDEX idx_order_status (status),
    INDEX idx_order_created (created_at DESC),
    INDEX idx_order_total (total_amount DESC),
    INDEX idx_order_coupon (coupon_code),

    -- Constraints
    CONSTRAINT chk_order_weight_non_negative CHECK (weight_total IS NULL OR weight_total >= 0)
) ENGINE=InnoDB;

-- =============================================
-- ORDER ITEMS TABLE
-- =============================================
CREATE TABLE order_items (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36) NOT NULL,

    -- Item details (snapshot at time of order)
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL,
    line_total DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    -- Product snapshot data (immutable after order creation)
    product_name VARCHAR(200) NOT NULL,
    product_slug VARCHAR(200) NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    variant_sku VARCHAR(100) NOT NULL,

    -- Product attributes at time of order
    color_name VARCHAR(50),
    size_name VARCHAR(50),
    material VARCHAR(100),
    weight_grams DECIMAL(8,3),  -- individual item weight in grams

    -- Cost information (for admin analytics)
    cost_price DECIMAL(12,2),
    profit_margin DECIMAL(12,2) GENERATED ALWAYS AS ((quantity * unit_price) - (COALESCE(cost_price, 0) * quantity)) STORED,

    -- Item fulfillment
    fulfillment_status VARCHAR(20) DEFAULT 'pending',
    shipped_quantity INT DEFAULT 0 CHECK (shipped_quantity >= 0),

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (variant_id) REFERENCES product_variants(id),

    -- Indexes
    INDEX idx_order_item_order (order_id),
    INDEX idx_order_item_product (product_id),
    INDEX idx_order_item_variant (variant_id),
    INDEX idx_order_item_fulfillment (fulfillment_status),

    -- Constraints
    CONSTRAINT chk_order_item_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_order_item_shipped_quantity CHECK (shipped_quantity <= quantity)
) ENGINE=InnoDB;

-- =============================================
-- ORDER ADDRESSES TABLE
-- =============================================
CREATE TABLE order_addresses (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('shipping', 'billing')),

    -- Address details (snapshot at time of order)
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(100),
    company VARCHAR(100),
    address_line1 VARCHAR(100) NOT NULL,
    address_line2 VARCHAR(100),
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    postal_code VARCHAR(20) NOT NULL,
    country CHAR(2) NOT NULL,
    phone VARCHAR(20),

    -- Address validation
    is_validated BOOLEAN DEFAULT FALSE,
    validation_score DECIMAL(3,2) CHECK (validation_score IS NULL OR (validation_score >= 0 AND validation_score <= 1)),

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_order_address_order (order_id),
    INDEX idx_order_address_type (address_type),
    INDEX idx_order_address_country (country),
    INDEX idx_order_address_postal (postal_code),

    -- Constraints
    CONSTRAINT chk_order_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    )
) ENGINE=InnoDB;

-- =============================================
-- ORDER PAYMENTS TABLE
-- =============================================
CREATE TABLE order_payments (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,

    -- Payment provider and method
    payment_provider VARCHAR(50) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,

    -- Payment amounts
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,

    -- Payment status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded')),

    -- Provider-specific information
    provider_payment_id VARCHAR(255),
    provider_charge_id VARCHAR(255),
    provider_transaction_id VARCHAR(255),
    provider_metadata JSON,

    -- Payment processing timestamps
    authorized_at TIMESTAMP NULL,
    captured_at TIMESTAMP NULL,
    failed_at TIMESTAMP NULL,
    refunded_at TIMESTAMP NULL,

    -- Failure information
    failure_code VARCHAR(100),
    failure_message TEXT,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_payment_order (order_id),
    INDEX idx_payment_provider (payment_provider),
    INDEX idx_payment_status (status),
    INDEX idx_payment_provider_payment_id (provider_payment_id),
    INDEX idx_payment_created (created_at DESC)
) ENGINE=InnoDB;

-- =============================================
-- ORDER SHIPMENTS TABLE
-- =============================================
CREATE TABLE order_shipments (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,

    -- Shipping carrier and service
    carrier VARCHAR(100) NOT NULL,
    service_level VARCHAR(100) NOT NULL,

    -- Tracking information
    tracking_number VARCHAR(255),
    tracking_url VARCHAR(500),

    -- Shipment status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'created', 'in_transit', 'delivered', 'exception', 'returned')),

    -- Shipment details
    weight_grams DECIMAL(8,3),
    dimensions_length DECIMAL(8,2),
    dimensions_width DECIMAL(8,2),
    dimensions_height DECIMAL(8,2),
    dimension_unit VARCHAR(5) DEFAULT 'cm' CHECK (dimension_unit IN ('cm', 'in')),

    -- Shipping cost breakdown
    shipping_cost DECIMAL(12,2),
    insurance_cost DECIMAL(12,2) DEFAULT 0,
    handling_fee DECIMAL(12,2) DEFAULT 0,

    -- Provider-specific information
    provider_shipment_id VARCHAR(255),
    provider_metadata JSON,

    -- Estimated and actual delivery
    estimated_delivery_date DATE,
    actual_delivery_date DATE,

    -- Delivery information
    delivered_to VARCHAR(255),
    delivery_location VARCHAR(255),
    delivery_signature_required BOOLEAN DEFAULT FALSE,
    delivery_signature_obtained BOOLEAN DEFAULT FALSE,

    -- Shipment lifecycle timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    shipped_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,

    -- Foreign keys
    CONSTRAINT fk_shipping_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_shipping_order (order_id),
    INDEX idx_shipping_carrier (carrier),
    INDEX idx_shipping_status (status),
    INDEX idx_shipping_tracking (tracking_number),
    INDEX idx_shipping_created (created_at DESC),
    INDEX idx_shipping_estimated_delivery (estimated_delivery_date),

    -- Constraints
    CONSTRAINT chk_shipping_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_shipping_dimensions_positive CHECK (
        (dimensions_length IS NULL OR dimensions_length > 0) AND
        (dimensions_width IS NULL OR dimensions_width > 0) AND
        (dimensions_height IS NULL OR dimensions_height > 0)
    )
) ENGINE=InnoDB;

-- =============================================
-- COUPONS TABLE
-- =============================================
CREATE TABLE coupons (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Discount configuration
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('fixed', 'percentage', 'free_shipping')),
    discount_value DECIMAL(12,2) NOT NULL,

    -- Usage limits
    usage_limit INT,  -- NULL = unlimited
    usage_limit_per_customer INT DEFAULT 1,
    usage_count INT DEFAULT 0,

    -- Conditions
    minimum_order_amount DECIMAL(12,2),
    maximum_discount_amount DECIMAL(12,2),

    -- Validity period
    starts_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_coupon_active (is_active),
    INDEX idx_coupon_expires (expires_at),
    INDEX idx_coupon_starts (starts_at),
    INDEX idx_coupon_type (discount_type),

    -- Constraints
    CONSTRAINT chk_coupon_discount_value_positive CHECK (discount_value > 0),
    CONSTRAINT chk_coupon_usage_limits_positive CHECK (
        (usage_limit IS NULL OR usage_limit > 0) AND
        usage_limit_per_customer > 0 AND
        usage_count >= 0
    )
) ENGINE=InnoDB;

-- =============================================
-- COUPON USAGE TABLE
-- =============================================
CREATE TABLE coupon_usage (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    coupon_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    order_id VARCHAR(36),

    -- Usage details
    discount_amount DECIMAL(12,2) NOT NULL,
    order_amount DECIMAL(12,2) NOT NULL,

    -- Audit fields
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,

    -- Indexes
    INDEX idx_coupon_usage_coupon (coupon_id),
    INDEX idx_coupon_usage_customer (customer_id),
    INDEX idx_coupon_usage_order (order_id),
    INDEX idx_coupon_usage_used_at (used_at DESC),

    -- Constraints
    CONSTRAINT chk_coupon_usage_amounts CHECK (discount_amount >= 0 AND order_amount >= 0)
) ENGINE=InnoDB;
