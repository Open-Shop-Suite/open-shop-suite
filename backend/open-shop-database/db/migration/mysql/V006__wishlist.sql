-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V006: Wishlist
-- =============================================

-- =============================================
-- WISHLISTS TABLE
-- =============================================
CREATE TABLE wishlists (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    name VARCHAR(100) DEFAULT 'My Wishlist',
    description TEXT,

    -- Privacy settings
    is_public BOOLEAN DEFAULT FALSE,
    is_default BOOLEAN DEFAULT FALSE,

    -- Sharing
    share_token VARCHAR(128) UNIQUE,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_wishlist_customer (customer_id),
    INDEX idx_wishlist_default (customer_id, is_default),
    INDEX idx_wishlist_public (is_public)
) ENGINE=InnoDB;

-- =============================================
-- WISHLIST ITEMS TABLE
-- =============================================
CREATE TABLE wishlist_items (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    wishlist_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36),

    -- Item details
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    priority INT DEFAULT 3 CHECK (priority BETWEEN 1 AND 5), -- 1=highest, 5=lowest

    -- Snapshot data
    product_name VARCHAR(200) NOT NULL,
    product_slug VARCHAR(200) NOT NULL,
    variant_name VARCHAR(100),
    variant_sku VARCHAR(100),
    saved_price DECIMAL(12,2),

    -- Personal notes
    notes TEXT,

    -- Audit fields
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (wishlist_id) REFERENCES wishlists(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL,

    -- Unique constraint
    UNIQUE KEY uk_wishlist_product_variant (wishlist_id, product_id, variant_id),

    -- Indexes
    INDEX idx_wishlist_item_wishlist (wishlist_id),
    INDEX idx_wishlist_item_product (product_id),
    INDEX idx_wishlist_item_variant (variant_id),
    INDEX idx_wishlist_item_priority (wishlist_id, priority),
    INDEX idx_wishlist_item_added (added_at DESC)
) ENGINE=InnoDB;
