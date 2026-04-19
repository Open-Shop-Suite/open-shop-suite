-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V008: Inventory System
-- =============================================

-- =============================================
-- SUPPLIERS TABLE
-- =============================================
CREATE TABLE suppliers (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
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
    lead_time_days INT,
    minimum_order_amount DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Status and ratings
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    rating DECIMAL(2,1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_supplier_name (name),
    INDEX idx_supplier_status (status),
    INDEX idx_supplier_country (country),
    INDEX idx_supplier_rating (rating DESC),

    -- Constraints
    CONSTRAINT chk_supplier_slug_format CHECK (slug REGEXP '^[a-z0-9-]+$'),
    CONSTRAINT chk_supplier_website_url_format CHECK (website_url IS NULL OR website_url REGEXP '^https?://.+'),
    CONSTRAINT chk_supplier_lead_time_positive CHECK (lead_time_days IS NULL OR lead_time_days >= 0),
    CONSTRAINT chk_supplier_min_order_positive CHECK (minimum_order_amount IS NULL OR minimum_order_amount >= 0)
) ENGINE=InnoDB;

-- =============================================
-- INVENTORY LOCATIONS TABLE
-- =============================================
CREATE TABLE inventory_locations (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    type VARCHAR(30) DEFAULT 'warehouse' CHECK (type IN ('warehouse', 'store', 'distribution_center', 'drop_ship')),
    description TEXT,

    -- Address information
    address_line1 VARCHAR(100),
    address_line2 VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country CHAR(2),

    -- Location properties
    is_active BOOLEAN DEFAULT TRUE,
    capacity_sqm DECIMAL(8,2),  -- Storage capacity in square meters
    temperature_controlled BOOLEAN DEFAULT FALSE,

    -- Contact information
    contact_person VARCHAR(100),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_location_type (type),
    INDEX idx_location_active (is_active),
    INDEX idx_location_country (country),

    -- Constraints
    CONSTRAINT chk_location_email CHECK (contact_email IS NULL OR contact_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
) ENGINE=InnoDB;

-- =============================================
-- INVENTORY STOCK TABLE
-- =============================================
CREATE TABLE inventory_stock (
    variant_id VARCHAR(36) NOT NULL,
    supplier_id VARCHAR(36) NOT NULL,
    location_id VARCHAR(36) NOT NULL,
    supplied_date DATE NOT NULL,

    -- Supplier batch details
    cost_price DECIMAL(12,2) NOT NULL,
    supplier_sku VARCHAR(100),
    batch_reference VARCHAR(100),

    -- Stock quantities
    quantity_on_hand INT DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INT DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_available INT GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,

    -- Inventory controls
    low_stock_threshold INT DEFAULT 10 CHECK (low_stock_threshold >= 0),
    reorder_quantity INT DEFAULT 50 CHECK (reorder_quantity >= 0),

    -- Status and tracking
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'discontinued', 'out_of_stock', 'backordered')),
    expiry_date DATE,
    last_inventory_count TIMESTAMP NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Primary key: variant/supplier/location/supplied_date
    PRIMARY KEY (variant_id, supplier_id, location_id, supplied_date),

    -- Indexes
    INDEX idx_stock_variant (variant_id),
    INDEX idx_stock_supplier (supplier_id),
    INDEX idx_stock_location (location_id),
    INDEX idx_stock_supplied_date (supplied_date),
    INDEX idx_stock_status (status),
    INDEX idx_stock_available (quantity_available),

    -- Foreign keys
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_stock_cost_positive CHECK (cost_price > 0)
) ENGINE=InnoDB;

-- =============================================
-- INVENTORY LOG TABLE
-- =============================================
CREATE TABLE inventory_log (
    id VARCHAR(36) NOT NULL PRIMARY KEY,

    -- What was changed
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN (
        'stock_movement', 'product_update', 'variant_update',
        'supplier_update', 'location_update', 'adjustment'
    )),

    -- Entity identifiers (nullable based on entity_type)
    product_id VARCHAR(36),
    variant_id VARCHAR(36),
    supplier_id VARCHAR(36),
    location_id VARCHAR(36),

    -- Change details
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN (
        'insert', 'update', 'delete', 'adjustment', 'movement', 'transfer'
    )),

    -- Before/after values (JSON for flexibility)
    old_values JSON,
    new_values JSON,

    -- Quantity changes (for stock movements)
    quantity_change INT,
    quantity_before INT,
    quantity_after INT,

    -- Metadata
    reason VARCHAR(255),
    reference_type VARCHAR(50), -- 'order', 'adjustment', 'restock', etc.
    reference_id VARCHAR(255),  -- order_id, adjustment_id, etc.

    -- User attribution
    admin_user_id VARCHAR(36), -- Who made the change
    admin_username VARCHAR(100), -- For display purposes

    -- Audit
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_log_entity_type (entity_type),
    INDEX idx_log_product (product_id),
    INDEX idx_log_variant (variant_id),
    INDEX idx_log_supplier (supplier_id),
    INDEX idx_log_location (location_id),
    INDEX idx_log_operation (operation_type),
    INDEX idx_log_created (created_at DESC),
    INDEX idx_log_reference (reference_type, reference_id),
    INDEX idx_log_admin_user (admin_user_id),

    -- Foreign keys (nullable)
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE SET NULL,
    FOREIGN KEY (admin_user_id) REFERENCES customers(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- =============================================
-- INVENTORY ALERTS TABLE
-- =============================================
CREATE TABLE inventory_alerts (
    id VARCHAR(36) NOT NULL PRIMARY KEY,

    -- Alert details
    alert_type VARCHAR(30) NOT NULL CHECK (alert_type IN (
        'low_stock', 'overstock', 'unusual_movement', 'expired', 'damaged',
        'reorder_needed', 'supplier_delay', 'quality_issue'
    )),
    severity VARCHAR(10) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),

    -- Related entities
    product_id VARCHAR(36),
    variant_id VARCHAR(36),
    supplier_id VARCHAR(36),
    location_id VARCHAR(36),

    -- Alert content
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    suggested_action TEXT,

    -- Alert status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'resolved', 'dismissed')),
    acknowledged_by VARCHAR(36),
    acknowledged_at TIMESTAMP NULL,
    resolved_by VARCHAR(36),
    resolved_at TIMESTAMP NULL,

    -- Threshold values (for context)
    current_value INT,
    threshold_value INT,
    unit VARCHAR(20), -- 'units', 'percentage', 'days', etc.

    -- Auto-resolution
    auto_resolve_hours INT, -- Auto-resolve after X hours
    auto_resolve_enabled BOOLEAN DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_alert_type (alert_type),
    INDEX idx_alert_severity (severity),
    INDEX idx_alert_status (status),
    INDEX idx_alert_product (product_id),
    INDEX idx_alert_variant (variant_id),
    INDEX idx_alert_supplier (supplier_id),
    INDEX idx_alert_location (location_id),
    INDEX idx_alert_created (created_at DESC),
    INDEX idx_alert_acknowledged (acknowledged_at),
    INDEX idx_alert_resolved (resolved_at),

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE CASCADE,
    FOREIGN KEY (acknowledged_by) REFERENCES customers(id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by) REFERENCES customers(id) ON DELETE SET NULL
) ENGINE=InnoDB;
