-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V008: Inventory System
-- =============================================

-- =============================================
-- SUPPLIERS TABLE
-- =============================================
CREATE TABLE suppliers (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    slug VARCHAR2(100) NOT NULL UNIQUE,
    description CLOB,

    -- Contact information
    contact_person VARCHAR2(100),
    email VARCHAR2(255),
    phone VARCHAR2(20),
    website_url VARCHAR2(500),

    -- Address information
    address_line1 VARCHAR2(100),
    address_line2 VARCHAR2(100),
    city VARCHAR2(50),
    state VARCHAR2(50),
    postal_code VARCHAR2(20),
    country VARCHAR2(2),

    -- Business details
    tax_id VARCHAR2(50),
    payment_terms VARCHAR2(100),
    lead_time_days NUMBER,
    minimum_order_amount NUMBER(12,2),
    currency VARCHAR2(3) DEFAULT 'USD',

    -- Status and ratings
    status VARCHAR2(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    rating NUMBER(2,1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_supplier_slug_format CHECK (REGEXP_LIKE(slug, '^[a-z0-9-]+$')),
    CONSTRAINT chk_supplier_website_url_format CHECK (website_url IS NULL OR REGEXP_LIKE(website_url, '^https?://.+')),
    CONSTRAINT chk_supplier_lead_time_positive CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
    CONSTRAINT chk_supplier_min_order_positive CHECK (minimum_order_amount IS NULL OR minimum_order_amount >= 0)
);

-- INDEXES for suppliers
-- idx_supplier_slug removed: slug column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_supplier_name ON suppliers (name);
CREATE INDEX idx_supplier_status ON suppliers (status);
CREATE INDEX idx_supplier_country ON suppliers (country);
CREATE INDEX idx_supplier_rating ON suppliers (rating DESC);

-- COMMENTS for suppliers
COMMENT ON TABLE suppliers IS 'Product suppliers and vendors';
COMMENT ON COLUMN suppliers.lead_time_days IS 'Expected delivery time in days';
COMMENT ON COLUMN suppliers.payment_terms IS 'Payment terms description (e.g., "Net 30", "COD")';

-- =============================================
-- INVENTORY LOCATIONS TABLE
-- =============================================
CREATE TABLE inventory_locations (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    code VARCHAR2(20) NOT NULL UNIQUE,
    type VARCHAR2(30) DEFAULT 'warehouse' CHECK (type IN ('warehouse', 'store', 'distribution_center', 'drop_ship')),
    description VARCHAR2(500),

    -- Address information
    address_line1 VARCHAR2(100),
    address_line2 VARCHAR2(100),
    city VARCHAR2(50),
    state VARCHAR2(50),
    postal_code VARCHAR2(20),
    country VARCHAR2(2),

    -- Location properties
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),
    capacity_sqm NUMBER(8,2),  -- Storage capacity in square meters
    temperature_controlled NUMBER(1) DEFAULT 0 CHECK (temperature_controlled IN (0,1)),

    -- Contact information
    contact_person VARCHAR2(100),
    contact_phone VARCHAR2(20),
    contact_email VARCHAR2(255),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_location_email CHECK (contact_email IS NULL OR REGEXP_LIKE(contact_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

-- INDEXES for inventory_locations
-- idx_location_code removed: code column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_location_type ON inventory_locations (type);
CREATE INDEX idx_location_active ON inventory_locations (is_active);
CREATE INDEX idx_location_country ON inventory_locations (country);

-- COMMENTS for inventory_locations
COMMENT ON TABLE inventory_locations IS 'Warehouse and storage locations for inventory management';
COMMENT ON COLUMN inventory_locations.code IS 'Unique location code for identification';
COMMENT ON COLUMN inventory_locations.capacity_sqm IS 'Total storage capacity in square meters';

-- =============================================
-- INVENTORY STOCK TABLE
-- =============================================
CREATE TABLE inventory_stock (
    variant_id RAW(16) NOT NULL,
    supplier_id RAW(16) NOT NULL,
    location_id RAW(16) NOT NULL,
    supplied_date DATE NOT NULL,

    -- Supplier batch details
    cost_price NUMBER(12,2) NOT NULL,
    supplier_sku VARCHAR2(100),
    batch_reference VARCHAR2(100),

    -- Stock quantities
    quantity_on_hand NUMBER DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved NUMBER DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_available NUMBER GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved),

    -- Inventory controls
    low_stock_threshold NUMBER DEFAULT 10 CHECK (low_stock_threshold >= 0),
    reorder_quantity NUMBER DEFAULT 50 CHECK (reorder_quantity >= 0),

    -- Status and tracking
    status VARCHAR2(20) DEFAULT 'active' CHECK (status IN ('active', 'discontinued', 'out_of_stock', 'backordered')),
    expiry_date DATE,
    last_inventory_count TIMESTAMP WITH TIME ZONE,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Primary key: variant/supplier/location/supplied_date
    CONSTRAINT pk_inventory_stock PRIMARY KEY (variant_id, supplier_id, location_id, supplied_date),

    -- Foreign keys
    CONSTRAINT fk_stock_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    CONSTRAINT fk_stock_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    CONSTRAINT fk_stock_location FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_stock_cost_positive CHECK (cost_price > 0)
);

-- INDEXES for inventory_stock
CREATE INDEX idx_stock_variant ON inventory_stock (variant_id);
CREATE INDEX idx_stock_supplier ON inventory_stock (supplier_id);
CREATE INDEX idx_stock_location ON inventory_stock (location_id);
CREATE INDEX idx_stock_supplied_date ON inventory_stock (supplied_date);
CREATE INDEX idx_stock_status ON inventory_stock (status);
CREATE INDEX idx_stock_available ON inventory_stock (quantity_available);

-- COMMENTS for inventory_stock
COMMENT ON TABLE inventory_stock IS 'Stock levels per variant/supplier/location/batch';
COMMENT ON COLUMN inventory_stock.supplied_date IS 'Date this stock batch was supplied';
COMMENT ON COLUMN inventory_stock.quantity_available IS 'Calculated as quantity_on_hand - quantity_reserved';

-- =============================================
-- INVENTORY LOG TABLE
-- =============================================
CREATE TABLE inventory_log (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,

    -- What was changed
    entity_type VARCHAR2(20) NOT NULL CHECK (entity_type IN (
        'stock_movement', 'product_update', 'variant_update',
        'supplier_update', 'location_update', 'adjustment'
    )),

    -- Entity identifiers (nullable based on entity_type)
    product_id RAW(16),
    variant_id RAW(16),
    supplier_id RAW(16),
    location_id RAW(16),

    -- Change details
    operation_type VARCHAR2(20) NOT NULL CHECK (operation_type IN (
        'insert', 'update', 'delete', 'adjustment', 'movement', 'transfer'
    )),

    -- Before/after values (JSON for flexibility)
    old_values JSON,
    new_values JSON,

    -- Quantity changes (for stock movements)
    quantity_change NUMBER,
    quantity_before NUMBER,
    quantity_after NUMBER,

    -- Metadata
    reason VARCHAR2(255),
    reference_type VARCHAR2(50), -- 'order', 'adjustment', 'restock', etc.
    reference_id VARCHAR2(255),  -- order_id, adjustment_id, etc.

    -- User attribution
    admin_user_id RAW(16), -- Who made the change
    admin_username VARCHAR2(100), -- For display purposes

    -- Audit
    ip_address VARCHAR2(45),
    user_agent CLOB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys (nullable)
    CONSTRAINT fk_log_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    CONSTRAINT fk_log_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,
    CONSTRAINT fk_log_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
    CONSTRAINT fk_log_location FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE SET NULL,
    CONSTRAINT fk_log_admin_user FOREIGN KEY (admin_user_id) REFERENCES customers(id) ON DELETE SET NULL
);

-- INDEXES for inventory_log
CREATE INDEX idx_log_entity_type ON inventory_log (entity_type);
CREATE INDEX idx_log_product ON inventory_log (product_id);
CREATE INDEX idx_log_variant ON inventory_log (variant_id);
CREATE INDEX idx_log_supplier ON inventory_log (supplier_id);
CREATE INDEX idx_log_location ON inventory_log (location_id);
CREATE INDEX idx_log_operation ON inventory_log (operation_type);
CREATE INDEX idx_log_created ON inventory_log (created_at DESC);
CREATE INDEX idx_log_reference ON inventory_log (reference_type, reference_id);
CREATE INDEX idx_log_admin_user ON inventory_log (admin_user_id);

-- COMMENTS for inventory_log
COMMENT ON TABLE inventory_log IS 'Comprehensive audit log for all inventory and product changes';
COMMENT ON COLUMN inventory_log.entity_type IS 'Type of entity that was changed';
COMMENT ON COLUMN inventory_log.old_values IS 'JSON snapshot of values before change';
COMMENT ON COLUMN inventory_log.new_values IS 'JSON snapshot of values after change';

-- =============================================
-- INVENTORY ALERTS TABLE
-- =============================================
CREATE TABLE inventory_alerts (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,

    -- Alert details
    alert_type VARCHAR2(30) NOT NULL CHECK (alert_type IN (
        'low_stock', 'overstock', 'unusual_movement', 'expired', 'damaged',
        'reorder_needed', 'supplier_delay', 'quality_issue'
    )),
    severity VARCHAR2(10) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    -- Related entities
    product_id RAW(16),
    variant_id RAW(16),
    supplier_id RAW(16),
    location_id RAW(16),

    -- Alert content
    title VARCHAR2(200) NOT NULL,
    message CLOB NOT NULL,
    suggested_action CLOB,

    -- Alert status
    status VARCHAR2(20) DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved', 'dismissed')),
    acknowledged_by RAW(16),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    resolved_by RAW(16),
    resolved_at TIMESTAMP WITH TIME ZONE,

    -- Threshold values (for context)
    current_value NUMBER,
    threshold_value NUMBER,
    unit VARCHAR2(20), -- 'units', 'percentage', 'days', etc.

    -- Auto-resolution
    auto_resolve_hours NUMBER, -- Auto-resolve after X hours
    auto_resolve_enabled NUMBER(1) DEFAULT 0 CHECK (auto_resolve_enabled IN (0,1)),

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_alert_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_location FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_acknowledged_by FOREIGN KEY (acknowledged_by) REFERENCES customers(id) ON DELETE SET NULL,
    CONSTRAINT fk_alert_resolved_by FOREIGN KEY (resolved_by) REFERENCES customers(id) ON DELETE SET NULL
);

-- INDEXES for inventory_alerts
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

-- COMMENTS for inventory_alerts
COMMENT ON TABLE inventory_alerts IS 'Automated inventory alerts and notifications';
COMMENT ON COLUMN inventory_alerts.alert_type IS 'Type of inventory issue detected';
COMMENT ON COLUMN inventory_alerts.severity IS 'Alert priority level';
