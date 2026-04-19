-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V006: Wishlist
-- =============================================

-- =============================================
-- WISHLISTS TABLE
-- =============================================
CREATE TABLE wishlists (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    customer_id UUID NOT NULL,
    name VARCHAR(100) DEFAULT 'My Wishlist',
    description TEXT,

    -- Privacy settings
    is_public BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,

    -- Sharing
    share_token VARCHAR(128) UNIQUE,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- Indexes for wishlists
CREATE INDEX idx_wishlist_customer ON wishlists (customer_id);
CREATE INDEX idx_wishlist_default ON wishlists (customer_id, is_default);
CREATE INDEX idx_wishlist_public ON wishlists (is_public);

-- =============================================
-- WISHLIST ITEMS TABLE
-- =============================================
CREATE TABLE wishlist_items (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    wishlist_id UUID NOT NULL,
    product_id UUID NOT NULL,
    variant_id UUID,

    -- Item details
    quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
    priority SMALLINT DEFAULT 3 CHECK (priority BETWEEN 1 AND 5), -- 1=highest, 5=lowest

    -- Snapshot data
    product_name VARCHAR(200) NOT NULL,
    product_slug VARCHAR(200) NOT NULL,
    variant_name VARCHAR(100),
    variant_sku VARCHAR(100),
    saved_price DECIMAL(12,2),

    -- Personal notes
    notes TEXT,

    -- Audit fields
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (wishlist_id) REFERENCES wishlists(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,

    -- Unique constraint
    UNIQUE (wishlist_id, product_id, variant_id)
);

-- Indexes for wishlist_items
CREATE INDEX idx_wishlist_item_wishlist ON wishlist_items (wishlist_id);
CREATE INDEX idx_wishlist_item_product ON wishlist_items (product_id);
CREATE INDEX idx_wishlist_item_variant ON wishlist_items (variant_id);
CREATE INDEX idx_wishlist_item_priority ON wishlist_items (wishlist_id, priority);
CREATE INDEX idx_wishlist_item_added ON wishlist_items (added_at DESC);

-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp triggers for wishlists
CREATE TRIGGER wishlist_updated_at_trigger
    BEFORE UPDATE ON wishlists
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER wishlist_item_updated_at_trigger
    BEFORE UPDATE ON wishlist_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
