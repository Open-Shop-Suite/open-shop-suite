-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V006: Wishlist
-- =============================================

-- =============================================
-- WISHLISTS TABLE
-- =============================================
CREATE TABLE wishlists (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    customer_id RAW(16) NOT NULL,
    name VARCHAR2(100) DEFAULT 'My Wishlist',
    description CLOB,

    -- Privacy settings
    is_public NUMBER(1) DEFAULT 0 CHECK (is_public IN (0,1)),
    is_default NUMBER(1) DEFAULT 0 CHECK (is_default IN (0,1)),

    -- Sharing
    share_token VARCHAR2(128) UNIQUE,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_wishlist_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
);

-- INDEXES for wishlists
CREATE INDEX idx_wishlist_customer ON wishlists (customer_id);
CREATE INDEX idx_wishlist_default ON wishlists (customer_id, is_default);
CREATE INDEX idx_wishlist_public ON wishlists (is_public);

-- COMMENTS for wishlists
COMMENT ON TABLE wishlists IS 'Customer wishlists for saving desired products';
COMMENT ON COLUMN wishlists.share_token IS 'Token for sharing public wishlists';
COMMENT ON COLUMN wishlists.is_default IS 'Whether this is the customer default wishlist';

-- =============================================
-- WISHLIST ITEMS TABLE
-- =============================================
CREATE TABLE wishlist_items (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    wishlist_id RAW(16) NOT NULL,
    product_id RAW(16) NOT NULL,
    variant_id RAW(16),

    -- Item details
    quantity NUMBER DEFAULT 1 CHECK (quantity > 0),
    priority NUMBER(1) DEFAULT 3 CHECK (priority BETWEEN 1 AND 5), -- 1=highest, 5=lowest

    -- Snapshot data
    product_name VARCHAR2(200) NOT NULL,
    product_slug VARCHAR2(200) NOT NULL,
    variant_name VARCHAR2(100),
    variant_sku VARCHAR2(100),
    saved_price NUMBER(12,2),

    -- Personal notes
    notes CLOB,

    -- Audit fields
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_wishlist_item_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlists(id) ON DELETE CASCADE,
    CONSTRAINT fk_wishlist_item_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_wishlist_item_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,

    -- Unique constraint
    CONSTRAINT uk_wishlist_product_variant UNIQUE (wishlist_id, product_id, variant_id)
);

-- INDEXES for wishlist_items
CREATE INDEX idx_wishlist_item_wishlist ON wishlist_items (wishlist_id);
CREATE INDEX idx_wishlist_item_product ON wishlist_items (product_id);
CREATE INDEX idx_wishlist_item_variant ON wishlist_items (variant_id);
CREATE INDEX idx_wishlist_item_priority ON wishlist_items (wishlist_id, priority);
CREATE INDEX idx_wishlist_item_added ON wishlist_items (added_at DESC);

-- COMMENTS for wishlist_items
COMMENT ON TABLE wishlist_items IS 'Individual items saved in customer wishlists';
COMMENT ON COLUMN wishlist_items.priority IS 'Item priority: 1=highest, 5=lowest';
COMMENT ON COLUMN wishlist_items.variant_id IS 'Specific variant or NULL for general product';
