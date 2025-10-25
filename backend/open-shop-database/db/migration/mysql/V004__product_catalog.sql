-- =============================================
-- Open Shop E-commerce Platform - MySQL Schema
-- V004: Product Catalog
-- =============================================

-- =============================================
-- CATEGORIES TABLE
-- =============================================
CREATE TABLE categories (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_id VARCHAR(36),

    -- SEO fields
    seo_title VARCHAR(60),
    seo_description VARCHAR(160),

    -- Display properties
    image_url VARCHAR(500),
    image_alt_text VARCHAR(255),
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,

    -- Path for hierarchical queries (materialized path)
    path VARCHAR(1000),
    level_depth INT DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,

    -- Indexes
    INDEX idx_category_parent (parent_id),
    INDEX idx_category_active (is_active),
    INDEX idx_category_featured (is_featured),
    INDEX idx_category_level (level_depth),
    INDEX idx_category_sort (sort_order),

    -- Constraints
    CONSTRAINT chk_category_slug_format CHECK (slug REGEXP '^[a-z0-9-]+$'),
    CONSTRAINT chk_category_level_positive CHECK (level_depth >= 0)
) ENGINE=InnoDB;

-- =============================================
-- BRANDS TABLE
-- =============================================
CREATE TABLE brands (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,

    -- Brand assets
    logo_url VARCHAR(500),
    logo_alt_text VARCHAR(255),
    website_url VARCHAR(500),

    -- SEO fields
    seo_title VARCHAR(60),
    seo_description VARCHAR(160),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_brand_active (is_active),
    INDEX idx_brand_sort (sort_order),

    -- Constraints
    CONSTRAINT chk_brand_slug_format CHECK (slug REGEXP '^[a-z0-9-]+$'),
    CONSTRAINT chk_brand_website_url_format CHECK (website_url IS NULL OR website_url REGEXP '^https?://.+')
) ENGINE=InnoDB;

-- =============================================
-- PRODUCTS TABLE
-- =============================================
CREATE TABLE products (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    short_description VARCHAR(500),

    -- Relations
    category_id VARCHAR(36) NOT NULL,
    brand_id VARCHAR(36) NOT NULL,

    -- SKU and barcoding
    sku VARCHAR(100),
    barcode VARCHAR(50),

    -- Physical properties
    weight_grams DECIMAL(10,3),
    length_cm DECIMAL(10,2),
    width_cm DECIMAL(10,2),
    height_cm DECIMAL(10,2),
    dimension_unit VARCHAR(5) DEFAULT 'cm',

    -- Status and visibility
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'inactive', 'archived')),
    is_featured BOOLEAN DEFAULT FALSE,

    -- SEO fields
    seo_title VARCHAR(60),
    seo_description VARCHAR(160),

    -- Calculated fields (updated by triggers)
    min_price DECIMAL(12,2),
    max_price DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',
    avg_rating DECIMAL(3,2) DEFAULT 0 CHECK (avg_rating BETWEEN 0 AND 5),
    review_count INT DEFAULT 0,
    total_stock INT DEFAULT 0,
    is_in_stock BOOLEAN DEFAULT FALSE,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (brand_id) REFERENCES brands(id),

    -- Indexes
    INDEX idx_product_name (name),
    INDEX idx_product_category (category_id),
    INDEX idx_product_brand (brand_id),
    INDEX idx_product_status (status),
    INDEX idx_product_featured (is_featured),
    INDEX idx_product_in_stock (is_in_stock),
    INDEX idx_product_price_range (min_price, max_price),
    INDEX idx_product_rating (avg_rating DESC),
    INDEX idx_product_created (created_at DESC),
    INDEX idx_product_sku (sku),
    INDEX idx_product_barcode (barcode),

    -- Constraints
    CONSTRAINT chk_product_slug_format CHECK (slug REGEXP '^[a-z0-9-]+$'),
    CONSTRAINT chk_product_weight_positive CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_product_dimensions_positive CHECK (
        (length_cm IS NULL OR length_cm >= 0) AND
        (width_cm IS NULL OR width_cm >= 0) AND
        (height_cm IS NULL OR height_cm >= 0)
    )
) ENGINE=InnoDB;

-- =============================================
-- PRODUCT VARIANTS TABLE
-- =============================================
CREATE TABLE product_variants (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    sku VARCHAR(100) NOT NULL UNIQUE,

    -- Pricing
    price DECIMAL(12,2) NOT NULL,
    compare_at_price DECIMAL(12,2),
    cost_price DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Variant properties
    color_name VARCHAR(36),
    size_type VARCHAR(50),
    material VARCHAR(100),

    -- Physical properties (can override product defaults)
    weight_grams DECIMAL(10,3),
    length_cm DECIMAL(10,2),
    width_cm DECIMAL(10,2),
    height_cm DECIMAL(10,2),

    -- Variant status
    is_active BOOLEAN DEFAULT TRUE,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_variant_product (product_id),
    INDEX idx_variant_color (color_name),
    INDEX idx_variant_size (size_type),
    INDEX idx_variant_active (is_active),
    INDEX idx_variant_price (price)
) ENGINE=InnoDB;

-- =============================================
-- PRODUCT ATTRIBUTES TABLE (EAV MODEL)
-- =============================================
CREATE TABLE product_attributes (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    product_id VARCHAR(36),
    variant_id VARCHAR(36),

    -- Attribute Information
    attribute_key VARCHAR(100) NOT NULL,
    attribute_value TEXT NOT NULL,
    attribute_type VARCHAR(20) DEFAULT 'text' CHECK (attribute_type IN ('text', 'number', 'boolean', 'date', 'url', 'email')),

    -- Attribute Properties
    is_filterable BOOLEAN DEFAULT FALSE,
    is_searchable BOOLEAN DEFAULT TRUE,
    display_order INT DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_attribute_product (product_id),
    INDEX idx_attribute_variant (variant_id),
    INDEX idx_attribute_key (attribute_key),
    INDEX idx_attribute_filterable (is_filterable, attribute_key),
    INDEX idx_attribute_searchable (is_searchable, attribute_key),
    INDEX idx_attribute_display (product_id, display_order),

    -- Constraints
    CONSTRAINT chk_attribute_has_parent CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
) ENGINE=InnoDB;

-- =============================================
-- PRODUCT IMAGES TABLE
-- =============================================
CREATE TABLE product_images (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255) NOT NULL,
    title VARCHAR(255),

    -- Image metadata
    image_type VARCHAR(20) DEFAULT 'gallery' CHECK (image_type IN ('main', 'gallery', 'thumbnail', 'zoom', 'lifestyle', 'detail', 'size_chart')),
    width_px INT,
    height_px INT,
    file_size_bytes INT,
    mime_type VARCHAR(50),

    -- Display properties
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,

    -- Indexes
    INDEX idx_image_product (product_id),
    INDEX idx_image_type (image_type),
    INDEX idx_image_primary (product_id, is_primary),
    INDEX idx_image_sort (product_id, sort_order),

    -- Constraints
    CONSTRAINT chk_image_url_format CHECK (url REGEXP '^https?://.+'),
    CONSTRAINT chk_image_dimensions_positive CHECK (
        (width_px IS NULL OR width_px > 0) AND (height_px IS NULL OR height_px > 0)
    ),
    CONSTRAINT chk_image_file_size_positive CHECK (file_size_bytes IS NULL OR file_size_bytes > 0)
) ENGINE=InnoDB;

-- =============================================
-- PRODUCT REVIEWS TABLE
-- =============================================
CREATE TABLE product_reviews (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    product_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    order_id VARCHAR(36),  -- Optional: link to purchase

    -- Review content
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    review_text TEXT,

    -- Review metadata
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,

    -- Helpful votes
    helpful_count INT DEFAULT 0 CHECK (helpful_count >= 0),
    total_votes INT DEFAULT 0 CHECK (total_votes >= 0),

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    approved_at TIMESTAMP NULL,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Unique constraint: one review per customer per product
    UNIQUE KEY uk_review_customer_product (customer_id, product_id),

    -- Indexes
    INDEX idx_review_product (product_id),
    INDEX idx_review_customer (customer_id),
    INDEX idx_review_rating (rating),
    INDEX idx_review_approved (is_approved),
    INDEX idx_review_featured (is_featured),
    INDEX idx_review_created (created_at DESC),
    INDEX idx_review_helpful (helpful_count DESC)
) ENGINE=InnoDB;

-- =============================================
-- TAGS TABLE
-- =============================================
CREATE TABLE tags (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    color VARCHAR(7), -- hex color like #FF5733
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Indexes
    INDEX idx_tag_active (is_active),
    INDEX idx_tag_sort (sort_order)
) ENGINE=InnoDB;

-- =============================================
-- PRODUCT TAGS TABLE
-- =============================================
CREATE TABLE product_tags (
    product_id VARCHAR(36) NOT NULL,
    tag_id VARCHAR(36) NOT NULL,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,

    -- Primary key
    PRIMARY KEY (product_id, tag_id),

    -- Indexes
    INDEX idx_product_tag_product (product_id),
    INDEX idx_product_tag_tag (tag_id)
) ENGINE=InnoDB;
