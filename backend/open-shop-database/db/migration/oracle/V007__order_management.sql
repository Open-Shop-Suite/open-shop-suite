-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V007: Order Management
-- =============================================

-- =============================================
-- ORDERS TABLE
-- =============================================
CREATE TABLE orders (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    order_number VARCHAR2(50) NOT NULL UNIQUE,
    customer_id RAW(16) NOT NULL,

    -- Order status and workflow
    status VARCHAR2(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),

    -- Order financial information
    subtotal NUMBER(12,2) NOT NULL,
    discount_total NUMBER(12,2) DEFAULT 0,
    tax_total NUMBER(12,2) DEFAULT 0,
    shipping_cost NUMBER(12,2) DEFAULT 0,
    total_amount NUMBER(12,2) NOT NULL,
    currency VARCHAR2(3) DEFAULT 'USD',

    -- Applied discounts
    coupon_code VARCHAR2(50),
    coupon_discount_amount NUMBER(12,2) DEFAULT 0,
    coupon_discount_type VARCHAR2(20) DEFAULT 'fixed',

    -- Customer notes and special instructions
    customer_notes CLOB,
    special_instructions CLOB,

    -- Order fulfillment information
    requires_shipping NUMBER(1) DEFAULT 1 CHECK (requires_shipping IN (0,1)),
    weight_total NUMBER(8,3),  -- total weight in grams

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    shipped_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,

    -- Foreign keys
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customers(id),

    -- Constraints
    CONSTRAINT chk_order_weight_non_negative CHECK (weight_total IS NULL OR weight_total >= 0)
);

-- INDEXES for orders
CREATE INDEX idx_order_customer ON orders (customer_id);
CREATE INDEX idx_order_status ON orders (status);
-- idx_order_number removed: order_number column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_order_created ON orders (created_at DESC);
CREATE INDEX idx_order_total ON orders (total_amount DESC);
CREATE INDEX idx_order_coupon ON orders (coupon_code);

-- COMMENTS for orders
COMMENT ON TABLE orders IS 'Core order information with status tracking and financial totals';
COMMENT ON COLUMN orders.order_number IS 'Unique human-readable order identifier';
COMMENT ON COLUMN orders.weight_total IS 'Total weight of all items in grams';

-- =============================================
-- ORDER ITEMS TABLE
-- =============================================
CREATE TABLE order_items (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    order_id RAW(16) NOT NULL,
    product_id RAW(16) NOT NULL,
    variant_id RAW(16) NOT NULL,

    -- Item details (snapshot at time of order)
    quantity NUMBER NOT NULL CHECK (quantity > 0),
    unit_price NUMBER(12,2) NOT NULL,
    line_total NUMBER GENERATED ALWAYS AS (quantity * unit_price),

    -- Product snapshot data (immutable after order creation)
    product_name VARCHAR2(200) NOT NULL,
    product_slug VARCHAR2(200) NOT NULL,
    variant_name VARCHAR2(100) NOT NULL,
    variant_sku VARCHAR2(100) NOT NULL,

    -- Product attributes at time of order
    color_name VARCHAR2(50),
    size_name VARCHAR2(50),
    material VARCHAR2(100),
    weight_grams NUMBER(8,3),  -- individual item weight in grams

    -- Cost information (for admin analytics)
    cost_price NUMBER(12,2),
    profit_margin NUMBER GENERATED ALWAYS AS ((quantity * unit_price) - (NVL(cost_price, 0) * quantity)),

    -- Item fulfillment
    fulfillment_status VARCHAR2(20) DEFAULT 'pending',
    shipped_quantity NUMBER DEFAULT 0 CHECK (shipped_quantity >= 0),

    -- Foreign keys
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_order_item_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_order_item_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id),

    -- Constraints
    CONSTRAINT chk_order_item_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_order_item_shipped_quantity CHECK (shipped_quantity <= quantity)
);

-- INDEXES for order_items
CREATE INDEX idx_order_item_order ON order_items (order_id);
CREATE INDEX idx_order_item_product ON order_items (product_id);
CREATE INDEX idx_order_item_variant ON order_items (variant_id);
CREATE INDEX idx_order_item_fulfillment ON order_items (fulfillment_status);

-- COMMENTS for order_items
COMMENT ON TABLE order_items IS 'Order line items with product snapshots and fulfillment tracking';
COMMENT ON COLUMN order_items.line_total IS 'Calculated as quantity * unit_price';
COMMENT ON COLUMN order_items.profit_margin IS 'Calculated profit margin per line item';

-- =============================================
-- ORDER ADDRESSES TABLE
-- =============================================
CREATE TABLE order_addresses (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    order_id RAW(16) NOT NULL,
    address_type VARCHAR2(20) NOT NULL CHECK (address_type IN ('shipping', 'billing')),

    -- Address details (snapshot at time of order)
    first_name VARCHAR2(50),
    last_name VARCHAR2(50),
    full_name VARCHAR2(100),
    company VARCHAR2(100),
    address_line1 VARCHAR2(100) NOT NULL,
    address_line2 VARCHAR2(100),
    city VARCHAR2(50) NOT NULL,
    state VARCHAR2(50),
    postal_code VARCHAR2(20) NOT NULL,
    country VARCHAR2(2) NOT NULL,
    phone VARCHAR2(20),

    -- Address validation
    is_validated NUMBER(1) DEFAULT 0 CHECK (is_validated IN (0,1)),
    validation_score NUMBER(3,2) CHECK (validation_score IS NULL OR (validation_score >= 0 AND validation_score <= 1)),

    -- Foreign keys
    CONSTRAINT fk_order_address_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_order_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    )
);

-- INDEXES for order_addresses
CREATE INDEX idx_order_address_order ON order_addresses (order_id);
CREATE INDEX idx_order_address_type ON order_addresses (address_type);
CREATE INDEX idx_order_address_country ON order_addresses (country);
CREATE INDEX idx_order_address_postal ON order_addresses (postal_code);

-- COMMENTS for order_addresses
COMMENT ON TABLE order_addresses IS 'Immutable shipping and billing address snapshots';
COMMENT ON COLUMN order_addresses.validation_score IS 'Address validation confidence score (0-1)';

-- =============================================
-- ORDER PAYMENTS TABLE
-- =============================================
CREATE TABLE order_payments (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    order_id RAW(16) NOT NULL,

    -- Payment provider and method
    payment_provider VARCHAR2(50) NOT NULL,
    payment_method VARCHAR2(50) NOT NULL,

    -- Payment amounts
    amount NUMBER(12,2) NOT NULL,
    currency VARCHAR2(3) NOT NULL,

    -- Payment status
    status VARCHAR2(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded')),

    -- Provider-specific information
    provider_payment_id VARCHAR2(255),
    provider_charge_id VARCHAR2(255),
    provider_transaction_id VARCHAR2(255),
    provider_metadata JSON,

    -- Payment processing timestamps
    authorized_at TIMESTAMP WITH TIME ZONE,
    captured_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    refunded_at TIMESTAMP WITH TIME ZONE,

    -- Failure information
    failure_code VARCHAR2(100),
    failure_message CLOB,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- INDEXES for order_payments
CREATE INDEX idx_payment_order ON order_payments (order_id);
CREATE INDEX idx_payment_provider ON order_payments (payment_provider);
CREATE INDEX idx_payment_status ON order_payments (status);
CREATE INDEX idx_payment_provider_payment_id ON order_payments (provider_payment_id);
CREATE INDEX idx_payment_created ON order_payments (created_at DESC);

-- COMMENTS for order_payments
COMMENT ON TABLE order_payments IS 'Payment processing information and provider integration';
COMMENT ON COLUMN order_payments.provider_metadata IS 'JSON metadata from payment provider';

-- =============================================
-- ORDER SHIPMENTS TABLE
-- =============================================
CREATE TABLE order_shipments (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    order_id RAW(16) NOT NULL,

    -- Shipping carrier and service
    carrier VARCHAR2(100) NOT NULL,
    service_level VARCHAR2(100) NOT NULL,

    -- Tracking information
    tracking_number VARCHAR2(255),
    tracking_url VARCHAR2(500),

    -- Shipment status
    status VARCHAR2(20) DEFAULT 'pending' CHECK (status IN ('pending', 'created', 'in_transit', 'delivered', 'exception', 'returned')),

    -- Shipment details
    weight_grams NUMBER(8,3),
    dimensions_length NUMBER(8,2),
    dimensions_width NUMBER(8,2),
    dimensions_height NUMBER(8,2),
    dimension_unit VARCHAR2(5) DEFAULT 'cm' CHECK (dimension_unit IN ('cm', 'in')),

    -- Shipping cost breakdown
    shipping_cost NUMBER(12,2),
    insurance_cost NUMBER(12,2) DEFAULT 0,
    handling_fee NUMBER(12,2) DEFAULT 0,

    -- Provider-specific information
    provider_shipment_id VARCHAR2(255),
    provider_metadata JSON,

    -- Estimated and actual delivery
    estimated_delivery_date DATE,
    actual_delivery_date DATE,

    -- Delivery information
    delivered_to VARCHAR2(255),
    delivery_location VARCHAR2(255),
    delivery_signature_required NUMBER(1) DEFAULT 0 CHECK (delivery_signature_required IN (0,1)),
    delivery_signature_obtained NUMBER(1) DEFAULT 0 CHECK (delivery_signature_obtained IN (0,1)),

    -- Shipment lifecycle timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    shipped_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,

    -- Foreign keys
    CONSTRAINT fk_shipping_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_shipping_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_shipping_dimensions_positive CHECK (
        (dimensions_length IS NULL OR dimensions_length > 0) AND
        (dimensions_width IS NULL OR dimensions_width > 0) AND
        (dimensions_height IS NULL OR dimensions_height > 0)
    )
);

-- INDEXES for order_shipments
CREATE INDEX idx_shipping_order ON order_shipments (order_id);
CREATE INDEX idx_shipping_carrier ON order_shipments (carrier);
CREATE INDEX idx_shipping_status ON order_shipments (status);
CREATE INDEX idx_shipping_tracking ON order_shipments (tracking_number);
CREATE INDEX idx_shipping_created ON order_shipments (created_at DESC);
CREATE INDEX idx_shipping_estimated_delivery ON order_shipments (estimated_delivery_date);

-- COMMENTS for order_shipments
COMMENT ON TABLE order_shipments IS 'Shipping carrier integration and tracking information';
COMMENT ON COLUMN order_shipments.provider_metadata IS 'JSON metadata from shipping provider';

-- =============================================
-- COUPONS TABLE
-- =============================================
CREATE TABLE coupons (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    code VARCHAR2(50) NOT NULL UNIQUE,
    name VARCHAR2(100) NOT NULL,
    description CLOB,

    -- Discount configuration
    discount_type VARCHAR2(20) NOT NULL CHECK (discount_type IN ('fixed', 'percentage', 'free_shipping')),
    discount_value NUMBER(12,2) NOT NULL,

    -- Usage limits
    usage_limit NUMBER,  -- NULL = unlimited
    usage_limit_per_customer NUMBER DEFAULT 1,
    usage_count NUMBER DEFAULT 0,

    -- Conditions
    minimum_order_amount NUMBER(12,2),
    maximum_discount_amount NUMBER(12,2),

    -- Validity period
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Status
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_coupon_discount_value_positive CHECK (discount_value > 0),
    CONSTRAINT chk_coupon_usage_limits_positive CHECK (
        (usage_limit IS NULL OR usage_limit > 0) AND
        usage_limit_per_customer > 0 AND
        usage_count >= 0
    )
);

-- INDEXES for coupons
CREATE INDEX idx_coupon_active ON coupons (is_active);
CREATE INDEX idx_coupon_expires ON coupons (expires_at);
CREATE INDEX idx_coupon_starts ON coupons (starts_at);
CREATE INDEX idx_coupon_type ON coupons (discount_type);

-- COMMENTS for coupons
COMMENT ON TABLE coupons IS 'Discount coupons and promotional codes';
COMMENT ON COLUMN coupons.discount_type IS 'Type: fixed amount, percentage, or free shipping';

-- =============================================
-- COUPON USAGE TABLE
-- =============================================
CREATE TABLE coupon_usage (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    coupon_id RAW(16) NOT NULL,
    customer_id RAW(16) NOT NULL,
    order_id RAW(16) NOT NULL,

    -- Usage details
    discount_amount NUMBER(12,2) NOT NULL,
    order_amount NUMBER(12,2) NOT NULL,

    -- Audit fields
    used_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_coupon_usage_coupon FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_coupon_usage_amounts CHECK (discount_amount >= 0 AND order_amount >= 0)
);

-- INDEXES for coupon_usage
CREATE INDEX idx_coupon_usage_coupon ON coupon_usage (coupon_id);
CREATE INDEX idx_coupon_usage_customer ON coupon_usage (customer_id);
CREATE INDEX idx_coupon_usage_order ON coupon_usage (order_id);
CREATE INDEX idx_coupon_usage_used_at ON coupon_usage (used_at DESC);

-- COMMENTS for coupon_usage
COMMENT ON TABLE coupon_usage IS 'Tracking of coupon usage by customers';
COMMENT ON COLUMN coupon_usage.discount_amount IS 'Actual discount amount applied';
