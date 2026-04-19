-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V008: Inventory System
-- =============================================

-- =============================================
-- SUPPLIERS TABLE
-- =============================================
CREATE TABLE suppliers (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,

    -- Contact information
    contact_person VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    website_url VARCHAR(500),

    -- Address information
    address_line1 VARCHAR(100),
    address_line2 VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(2),

    -- Business details
    tax_id VARCHAR(50),
    payment_terms VARCHAR(100),
    lead_time_days INTEGER,
    minimum_order_amount DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Status and ratings
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    rating DECIMAL(2,1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_supplier_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT chk_supplier_website_url_format CHECK (website_url IS NULL OR website_url ~ '^https?://.+'),
    CONSTRAINT chk_supplier_lead_time_positive CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
    CONSTRAINT chk_supplier_min_order_positive CHECK (minimum_order_amount IS NULL OR minimum_order_amount >= 0)
);

-- Indexes for suppliers
CREATE INDEX idx_supplier_name ON suppliers (name);
CREATE INDEX idx_supplier_status ON suppliers (status);
CREATE INDEX idx_supplier_country ON suppliers (country);
CREATE INDEX idx_supplier_rating ON suppliers (rating DESC);

-- =============================================
-- INVENTORY LOCATIONS TABLE
-- =============================================
CREATE TABLE inventory_locations (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,  -- Short code like "WH-NYC", "STORE-001"
    type VARCHAR(20) NOT NULL CHECK (type IN ('warehouse', 'store', 'distribution_center', 'dropship')),
    description TEXT,

    -- Address information
    address_line1 VARCHAR(100),
    address_line2 VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(2),

    -- Contact information
    contact_person VARCHAR(100),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),

    -- Location properties
    is_active BOOLEAN DEFAULT TRUE,
    capacity_sqm INTEGER,  -- Storage capacity in square meters
    temperature_controlled BOOLEAN DEFAULT FALSE,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_location_code_format CHECK (code ~ '^[A-Z0-9_-]+$'),
    CONSTRAINT chk_location_capacity_positive CHECK (capacity_sqm IS NULL OR capacity_sqm > 0)
);

-- Indexes for inventory locations
CREATE INDEX idx_location_type ON inventory_locations (type);
CREATE INDEX idx_location_active ON inventory_locations (is_active);
CREATE INDEX idx_location_country ON inventory_locations (country);

-- =============================================
-- INVENTORY STOCK TABLE
-- =============================================
CREATE TABLE inventory_stock (
    variant_id UUID NOT NULL,
    supplier_id UUID NOT NULL,
    location_id UUID NOT NULL,
    supplied_date DATE NOT NULL,

    -- Supplier batch details
    cost_price DECIMAL(12,2) NOT NULL,
    supplier_sku VARCHAR(100),
    batch_reference VARCHAR(100),

    -- Stock quantities
    quantity_on_hand INTEGER DEFAULT 0,
    quantity_reserved INTEGER DEFAULT 0,
    quantity_available INTEGER GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,

    -- Inventory controls
    low_stock_threshold INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,

    -- Status and tracking
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'discontinued', 'out_of_stock', 'backordered')),
    expiry_date DATE,
    last_inventory_count TIMESTAMPTZ,
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Primary key: variant/supplier/location/supplied_date
    PRIMARY KEY (variant_id, supplier_id, location_id, supplied_date),

    -- Foreign keys
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_stock_quantities_non_negative CHECK (
        quantity_on_hand >= 0 AND quantity_reserved >= 0
    ),
    CONSTRAINT chk_stock_thresholds CHECK (low_stock_threshold >= 0),
    CONSTRAINT chk_stock_reorder_quantity CHECK (reorder_quantity >= 0),
    CONSTRAINT chk_stock_cost_positive CHECK (cost_price > 0)
);

-- Indexes for inventory stock
CREATE INDEX idx_stock_variant ON inventory_stock (variant_id);
CREATE INDEX idx_stock_supplier ON inventory_stock (supplier_id);
CREATE INDEX idx_stock_location ON inventory_stock (location_id);
CREATE INDEX idx_stock_supplied_date ON inventory_stock (supplied_date);
CREATE INDEX idx_stock_status ON inventory_stock (status);
CREATE INDEX idx_stock_available ON inventory_stock (quantity_available);

-- =============================================
-- INVENTORY LOG TABLE
-- =============================================
CREATE TABLE inventory_log (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,

    -- What was changed
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN (
        'stock_movement', 'product_update', 'variant_update',
        'supplier_update', 'location_update', 'adjustment'
    )),

    -- Entity identifiers (nullable based on entity_type)
    product_id UUID,
    variant_id UUID,
    supplier_id UUID,
    location_id UUID,

    -- Change details
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN (
        'insert', 'update', 'delete', 'adjustment', 'movement', 'transfer'
    )),

    -- Before/after values (JSON for flexibility)
    old_values JSONB,
    new_values JSONB,

    -- Quantity changes (for stock movements)
    quantity_change INTEGER,
    quantity_before INTEGER,
    quantity_after INTEGER,

    -- Metadata
    reason VARCHAR(255),
    reference_type VARCHAR(50), -- 'order', 'adjustment', 'restock', etc.
    reference_id VARCHAR(255),  -- order_id, adjustment_id, etc.

    -- User attribution
    admin_user_id UUID, -- Who made the change
    admin_username VARCHAR(100), -- For display purposes

    -- Audit
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys (nullable)
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE SET NULL,
    FOREIGN KEY (admin_user_id) REFERENCES customers(id) ON DELETE SET NULL
);

-- Indexes for inventory log
CREATE INDEX idx_log_entity_type ON inventory_log (entity_type);
CREATE INDEX idx_log_product ON inventory_log (product_id);
CREATE INDEX idx_log_variant ON inventory_log (variant_id);
CREATE INDEX idx_log_supplier ON inventory_log (supplier_id);
CREATE INDEX idx_log_location ON inventory_log (location_id);
CREATE INDEX idx_log_operation ON inventory_log (operation_type);
CREATE INDEX idx_log_created ON inventory_log (created_at DESC);
CREATE INDEX idx_log_reference ON inventory_log (reference_type, reference_id);
CREATE INDEX idx_log_admin_user ON inventory_log (admin_user_id);

-- =============================================
-- INVENTORY ALERTS TABLE
-- =============================================
CREATE TABLE inventory_alerts (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,

    -- Alert details
    alert_type VARCHAR(30) NOT NULL CHECK (alert_type IN (
        'low_stock', 'overstock', 'unusual_movement', 'expired', 'damaged',
        'reorder_needed', 'supplier_delay', 'quality_issue'
    )),
    severity VARCHAR(10) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    -- Related entities
    product_id UUID,
    variant_id UUID,
    supplier_id UUID,
    location_id UUID,

    -- Alert content
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    suggested_action TEXT,

    -- Alert status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved', 'dismissed')),
    acknowledged_by UUID,
    acknowledged_at TIMESTAMPTZ,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,

    -- Threshold values (for context)
    current_value INTEGER,
    threshold_value INTEGER,
    unit VARCHAR(20), -- 'units', 'percentage', 'days', etc.

    -- Auto-resolution
    auto_resolve_hours INTEGER, -- Auto-resolve after X hours
    auto_resolve_enabled BOOLEAN DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,
    FOREIGN KEY (acknowledged_by) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by) REFERENCES customers(id) ON DELETE SET NULL
);

-- Indexes for inventory alerts
CREATE INDEX idx_alert_type ON inventory_alerts (alert_type);
CREATE INDEX idx_alert_severity ON inventory_alerts (severity);
CREATE INDEX idx_alert_status ON inventory_alerts (status);
CREATE INDEX idx_alert_product ON inventory_alerts (product_id);
CREATE INDEX idx_alert_variant ON inventory_alerts (variant_id);
CREATE INDEX idx_alert_supplier ON inventory_alerts (supplier_id);
CREATE INDEX idx_alert_location ON inventory_alerts (location_id);
CREATE INDEX idx_alert_created ON inventory_alerts (created_at DESC);
CREATE INDEX idx_alert_acknowledged ON inventory_alerts (acknowledged_at);
CREATE INDEX idx_alert_resolved ON inventory_alerts (resolved_at);

-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp triggers for inventory system
CREATE TRIGGER supplier_updated_at_trigger
    BEFORE UPDATE ON suppliers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER location_updated_at_trigger
    BEFORE UPDATE ON inventory_locations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER stock_updated_at_trigger
    BEFORE UPDATE ON inventory_stock
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER alert_updated_at_trigger
    BEFORE UPDATE ON inventory_alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
