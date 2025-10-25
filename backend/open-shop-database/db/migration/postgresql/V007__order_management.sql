-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V007: Order Management
-- =============================================

-- =============================================
-- ORDERS TABLE
-- =============================================
CREATE TABLE orders (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id UUID NOT NULL,

    -- Order status and workflow
    status order_status DEFAULT 'pending',

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
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMPTZ NULL,
    shipped_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    cancelled_at TIMESTAMPTZ NULL,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,

    -- Constraints
    CONSTRAINT chk_order_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_order_amounts_non_negative CHECK (
        subtotal >= 0 AND discount_total >= 0 AND
        tax_total >= 0 AND shipping_cost >= 0 AND total_amount >= 0
    ),
    CONSTRAINT chk_order_coupon_discount CHECK (coupon_discount_amount >= 0),
    CONSTRAINT chk_order_weight_non_negative CHECK (weight_total IS NULL OR weight_total >= 0)
);

-- Indexes for orders
CREATE INDEX idx_order_customer ON orders (customer_id);
CREATE INDEX idx_order_status ON orders (status);
CREATE INDEX idx_order_created ON orders (created_at DESC);
CREATE INDEX idx_order_total ON orders (total_amount DESC);
CREATE INDEX idx_order_coupon ON orders (coupon_code);

-- =============================================
-- ORDER ITEMS TABLE
-- =============================================
CREATE TABLE order_items (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant_id UUID NOT NULL,

    -- Item details (snapshot at time of order)
    quantity INTEGER NOT NULL,
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
    profit_margin DECIMAL(12,2),

    -- Item fulfillment
    fulfillment_status VARCHAR(20) DEFAULT 'pending',
    shipped_quantity INTEGER DEFAULT 0,

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE RESTRICT,

    -- Constraints
    CONSTRAINT chk_order_item_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_order_item_price_non_negative CHECK (unit_price >= 0),
    CONSTRAINT chk_order_item_cost_non_negative CHECK (cost_price IS NULL OR cost_price >= 0),
    CONSTRAINT chk_order_item_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_order_item_shipped_quantity CHECK (shipped_quantity >= 0 AND shipped_quantity <= quantity)
);

-- Indexes for order items
CREATE INDEX idx_order_item_order ON order_items (order_id);
CREATE INDEX idx_order_item_product ON order_items (product_id);
CREATE INDEX idx_order_item_variant ON order_items (variant_id);
CREATE INDEX idx_order_item_fulfillment ON order_items (fulfillment_status);

-- =============================================
-- ORDER ADDRESSES TABLE (immutable snapshot)
-- =============================================
CREATE TABLE order_addresses (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID NOT NULL,
    address_type address_type NOT NULL,

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
    validation_score DECIMAL(3,2),  -- 0.0 to 1.0 confidence score

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_order_address_name_provided CHECK (
        (first_name IS NOT NULL AND last_name IS NOT NULL) OR full_name IS NOT NULL
    ),
    CONSTRAINT chk_order_address_country_format CHECK (country ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_order_address_phone_format CHECK (phone IS NULL OR phone ~ '^\+?[1-9][0-9]{1,14}$'),
    CONSTRAINT chk_order_address_validation_score CHECK (validation_score IS NULL OR (validation_score >= 0 AND validation_score <= 1))
);

-- Indexes for order addresses
CREATE INDEX idx_order_address_order ON order_addresses (order_id);
CREATE INDEX idx_order_address_type ON order_addresses (address_type);
CREATE INDEX idx_order_address_country ON order_addresses (country);
CREATE INDEX idx_order_address_postal ON order_addresses (postal_code);

-- =============================================
-- ORDER PAYMENTS TABLE
-- =============================================
CREATE TABLE order_payments (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID NOT NULL,

    -- Payment provider and method
    payment_provider VARCHAR(50) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,

    -- Payment amounts
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) NOT NULL,

    -- Payment status
    status payment_status DEFAULT 'pending',

    -- Provider-specific information
    provider_payment_id VARCHAR(255),
    provider_charge_id VARCHAR(255),
    provider_transaction_id VARCHAR(255),
    provider_metadata JSONB,

    -- Payment processing timestamps
    authorized_at TIMESTAMPTZ NULL,
    captured_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,
    refunded_at TIMESTAMPTZ NULL,

    -- Failure information
    failure_code VARCHAR(100),
    failure_message TEXT,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_payment_amount_positive CHECK (amount > 0),
    CONSTRAINT chk_payment_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

-- Indexes for payments
CREATE INDEX idx_payment_order ON order_payments (order_id);
CREATE INDEX idx_payment_provider ON order_payments (payment_provider);
CREATE INDEX idx_payment_status ON order_payments (status);
CREATE INDEX idx_payment_provider_payment_id ON order_payments (provider_payment_id);
CREATE INDEX idx_payment_created ON order_payments (created_at DESC);

-- =============================================
-- ORDER SHIPMENTS TABLE
-- =============================================
CREATE TABLE order_shipments (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    order_id UUID NOT NULL,

    -- Shipping carrier and service
    carrier VARCHAR(100) NOT NULL,
    service_level VARCHAR(100) NOT NULL,

    -- Tracking information
    tracking_number VARCHAR(255),
    tracking_url VARCHAR(500),

    -- Shipment status
    status shipping_status DEFAULT 'pending',

    -- Shipment details
    weight_grams DECIMAL(8,3),  -- total shipment weight in grams
    dimensions_length DECIMAL(8,2),
    dimensions_width DECIMAL(8,2),
    dimensions_height DECIMAL(8,2),
    dimension_unit dimension_unit DEFAULT 'cm',

    -- Shipping cost breakdown
    shipping_cost DECIMAL(12,2),
    insurance_cost DECIMAL(12,2) DEFAULT 0,
    handling_fee DECIMAL(12,2) DEFAULT 0,

    -- Provider-specific information
    provider_shipment_id VARCHAR(255),
    provider_metadata JSONB,

    -- Estimated and actual delivery
    estimated_delivery_date DATE,
    actual_delivery_date DATE,

    -- Delivery information
    delivered_to VARCHAR(255),
    delivery_location VARCHAR(255),
    delivery_signature_required BOOLEAN DEFAULT FALSE,
    delivery_signature_obtained BOOLEAN DEFAULT FALSE,

    -- Shipment lifecycle timestamps
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    shipped_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,

    -- Foreign keys
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_shipment_weight_non_negative CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_shipment_dimensions_positive CHECK (
        (dimensions_length IS NULL OR dimensions_length > 0) AND
        (dimensions_width IS NULL OR dimensions_width > 0) AND
        (dimensions_height IS NULL OR dimensions_height > 0)
    ),
    CONSTRAINT chk_shipment_costs_non_negative CHECK (
        (shipping_cost IS NULL OR shipping_cost >= 0) AND
        insurance_cost >= 0 AND handling_fee >= 0
    )
);

-- Indexes for shipments
CREATE INDEX idx_shipping_order ON order_shipments (order_id);
CREATE INDEX idx_shipping_carrier ON order_shipments (carrier);
CREATE INDEX idx_shipping_status ON order_shipments (status);
CREATE INDEX idx_shipping_tracking ON order_shipments (tracking_number);
CREATE INDEX idx_shipping_created ON order_shipments (created_at DESC);
CREATE INDEX idx_shipping_estimated_delivery ON order_shipments (estimated_delivery_date);

-- =============================================
-- COUPONS TABLE
-- =============================================
CREATE TABLE coupons (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Discount configuration
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('fixed', 'percentage')),
    discount_value DECIMAL(12,2) NOT NULL,

    -- Usage limits
    usage_limit INTEGER,  -- NULL means unlimited
    usage_limit_per_customer INTEGER DEFAULT 1,
    usage_count INTEGER DEFAULT 0,

    -- Date restrictions
    starts_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,

    -- Application rules
    minimum_order_amount DECIMAL(12,2),
    maximum_discount_amount DECIMAL(12,2),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_coupon_discount_positive CHECK (discount_value > 0),
    CONSTRAINT chk_coupon_usage_limits_positive CHECK (
        (usage_limit IS NULL OR usage_limit > 0) AND
        usage_limit_per_customer > 0 AND
        usage_count >= 0
    )
);

-- Indexes for coupons
CREATE INDEX idx_coupon_active ON coupons (is_active);
CREATE INDEX idx_coupon_expires ON coupons (expires_at);
CREATE INDEX idx_coupon_starts ON coupons (starts_at);
CREATE INDEX idx_coupon_type ON coupons (discount_type);

-- =============================================
-- COUPON USAGE TABLE
-- =============================================
CREATE TABLE coupon_usage (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    coupon_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    order_id UUID NOT NULL,

    -- Usage details
    discount_amount DECIMAL(12,2) NOT NULL,
    order_amount DECIMAL(12,2) NOT NULL,

    -- Audit fields
    used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_coupon_usage_amounts CHECK (discount_amount >= 0 AND order_amount >= 0)
);

-- Indexes for coupon usage
CREATE INDEX idx_coupon_usage_coupon ON coupon_usage (coupon_id);
CREATE INDEX idx_coupon_usage_customer ON coupon_usage (customer_id);
CREATE INDEX idx_coupon_usage_order ON coupon_usage (order_id);
CREATE INDEX idx_coupon_usage_used_at ON coupon_usage (used_at DESC);

-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp triggers for orders
CREATE TRIGGER order_updated_at_trigger
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER payment_updated_at_trigger
    BEFORE UPDATE ON order_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER shipment_updated_at_trigger
    BEFORE UPDATE ON order_shipments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER coupon_updated_at_trigger
    BEFORE UPDATE ON coupons
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Order number generation trigger
CREATE OR REPLACE FUNCTION generate_order_number_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := generate_order_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_number_trigger
    BEFORE INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_order_number_trigger();
