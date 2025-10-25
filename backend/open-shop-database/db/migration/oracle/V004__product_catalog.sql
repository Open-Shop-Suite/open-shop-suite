-- =============================================
-- Open Shop E-commerce Platform - Oracle Schema
-- V004: Product Catalog
-- =============================================

-- =============================================
-- CATEGORIES TABLE
-- =============================================
CREATE TABLE categories (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    slug VARCHAR2(100) NOT NULL UNIQUE,
    description CLOB,
    parent_id RAW(16),

    -- SEO fields
    seo_title VARCHAR2(60),
    seo_description VARCHAR2(160),

    -- Display properties
    image_url VARCHAR2(500),
    image_alt_text VARCHAR2(255),
    sort_order NUMBER DEFAULT 0,
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),
    is_featured NUMBER(1) DEFAULT 0 CHECK (is_featured IN (0,1)),

    -- Path for hierarchical queries (materialized path)
    path VARCHAR2(1000),
    level_depth NUMBER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_category_slug_format CHECK (REGEXP_LIKE(slug, '^[a-z0-9-]+$')),
    CONSTRAINT chk_category_level_positive CHECK (level_depth >= 0),
    CONSTRAINT chk_category_no_self_parent CHECK (id != parent_id)
);

-- INDEXES for categories
-- idx_category_slug removed: slug column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_category_parent ON categories (parent_id);
CREATE INDEX idx_category_active ON categories (is_active);
CREATE INDEX idx_category_featured ON categories (is_featured);
CREATE INDEX idx_category_level ON categories (level_depth);
CREATE INDEX idx_category_sort ON categories (sort_order);

-- COMMENTS for categories
COMMENT ON TABLE categories IS 'Product categories with hierarchical structure';
COMMENT ON COLUMN categories.path IS 'Materialized path for efficient hierarchical queries';
COMMENT ON COLUMN categories.level_depth IS 'Depth level in category hierarchy starting from 0';

-- =============================================
-- BRANDS TABLE
-- =============================================
CREATE TABLE brands (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(100) NOT NULL UNIQUE,
    slug VARCHAR2(100) NOT NULL UNIQUE,
    description CLOB,

    -- Brand assets
    logo_url VARCHAR2(500),
    logo_alt_text VARCHAR2(255),
    website_url VARCHAR2(500),

    -- SEO fields
    seo_title VARCHAR2(60),
    seo_description VARCHAR2(160),

    -- Status
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),
    sort_order NUMBER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_brand_slug_format CHECK (REGEXP_LIKE(slug, '^[a-z0-9-]+$')),
    CONSTRAINT chk_brand_website_url_format CHECK (website_url IS NULL OR REGEXP_LIKE(website_url, '^https?://.+'))
);

-- INDEXES for brands
-- idx_brand_slug removed: slug column has UNIQUE constraint which creates index automatically
-- idx_brand_name removed: name column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_brand_active ON brands (is_active);
CREATE INDEX idx_brand_sort ON brands (sort_order);

-- COMMENTS for brands
COMMENT ON TABLE brands IS 'Product brands and manufacturers';
COMMENT ON COLUMN brands.website_url IS 'Official brand website URL';

-- =============================================
-- PRODUCTS TABLE
-- =============================================
CREATE TABLE products (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    slug VARCHAR2(200) NOT NULL UNIQUE,
    description CLOB,
    short_description VARCHAR2(500),

    -- Relations
    category_id RAW(16) NOT NULL,
    brand_id RAW(16) NOT NULL,

    -- SKU and barcoding
    sku VARCHAR2(100),
    barcode VARCHAR2(50),

    -- Physical properties
    weight_grams NUMBER(10,3),
    length_cm NUMBER(10,2),
    width_cm NUMBER(10,2),
    height_cm NUMBER(10,2),
    dimension_unit VARCHAR2(5) DEFAULT 'cm',

    -- Status and visibility
    status VARCHAR2(20) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'inactive', 'archived')),
    is_featured NUMBER(1) DEFAULT 0 CHECK (is_featured IN (0,1)),

    -- SEO fields
    seo_title VARCHAR2(60),
    seo_description VARCHAR2(160),

    -- Calculated fields (updated by triggers)
    min_price NUMBER(12,2),
    max_price NUMBER(12,2),
    currency VARCHAR2(3) DEFAULT 'USD',
    avg_rating NUMBER(3,2) DEFAULT 0 CHECK (avg_rating BETWEEN 0 AND 5),
    review_count NUMBER DEFAULT 0,
    total_stock NUMBER DEFAULT 0,
    is_in_stock NUMBER(1) DEFAULT 0 CHECK (is_in_stock IN (0,1)),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES categories(id),
    CONSTRAINT fk_product_brand FOREIGN KEY (brand_id) REFERENCES brands(id),

    -- Constraints
    CONSTRAINT chk_product_slug_format CHECK (REGEXP_LIKE(slug, '^[a-z0-9-]+$')),
    CONSTRAINT chk_product_weight_positive CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_product_dimensions_positive CHECK (
        (length_cm IS NULL OR length_cm >= 0) AND
        (width_cm IS NULL OR width_cm >= 0) AND
        (height_cm IS NULL OR height_cm >= 0)
    ),
    CONSTRAINT chk_product_price_range CHECK (min_price IS NULL OR max_price IS NULL OR min_price <= max_price)
);

-- INDEXES for products
-- idx_product_slug removed: slug column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_product_name ON products (name);
CREATE INDEX idx_product_category ON products (category_id);
CREATE INDEX idx_product_brand ON products (brand_id);
CREATE INDEX idx_product_status ON products (status);
CREATE INDEX idx_product_featured ON products (is_featured);
CREATE INDEX idx_product_in_stock ON products (is_in_stock);
CREATE INDEX idx_product_price_range ON products (min_price, max_price);
CREATE INDEX idx_product_rating ON products (avg_rating DESC);
CREATE INDEX idx_product_created ON products (created_at DESC);
CREATE INDEX idx_product_sku ON products (sku);
CREATE INDEX idx_product_barcode ON products (barcode);

-- COMMENTS for products
COMMENT ON TABLE products IS 'Core product catalog with calculated fields and JSON attributes';
COMMENT ON COLUMN products.min_price IS 'Minimum price across all active variants (calculated by trigger)';
COMMENT ON COLUMN products.max_price IS 'Maximum price across all active variants (calculated by trigger)';

-- =============================================
-- PRODUCT VARIANTS TABLE
-- =============================================
CREATE TABLE product_variants (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    product_id RAW(16) NOT NULL,
    name VARCHAR2(100) NOT NULL,
    sku VARCHAR2(100) NOT NULL UNIQUE,

    -- Pricing
    price NUMBER(12,2) NOT NULL,
    compare_at_price NUMBER(12,2),
    cost_price NUMBER(12,2),
    currency VARCHAR2(3) DEFAULT 'USD',

    -- Variant properties
    color_name RAW(16),
    size_type VARCHAR2(50),
    material VARCHAR2(100),

    -- Physical properties (can override product defaults)
    weight_grams NUMBER(10,3),
    length_cm NUMBER(10,2),
    width_cm NUMBER(10,2),
    height_cm NUMBER(10,2),

    -- Variant status
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_variant_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- INDEXES for product_variants
CREATE INDEX idx_variant_product ON product_variants (product_id);
-- idx_variant_sku removed: sku column has UNIQUE constraint which creates index automatically
CREATE INDEX idx_variant_color ON product_variants (color_name);
CREATE INDEX idx_variant_size ON product_variants (size_type);
CREATE INDEX idx_variant_active ON product_variants (is_active);
CREATE INDEX idx_variant_price ON product_variants (price);

-- COMMENTS for product_variants
COMMENT ON TABLE product_variants IS 'Product variants with pricing and properties';

-- =============================================
-- PRODUCT ATTRIBUTES TABLE (EAV MODEL)
-- =============================================
CREATE TABLE product_attributes (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    product_id RAW(16),
    variant_id RAW(16),

    -- Attribute Information
    attribute_key VARCHAR2(100) NOT NULL,
    attribute_value CLOB NOT NULL,
    attribute_type VARCHAR2(20) DEFAULT 'text' CHECK (attribute_type IN ('text', 'number', 'boolean', 'date', 'url', 'email')),

    -- Attribute Properties
    is_filterable NUMBER(1) DEFAULT 0 CHECK (is_filterable IN (0,1)),
    is_searchable NUMBER(1) DEFAULT 1 CHECK (is_searchable IN (0,1)),
    display_order NUMBER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_attribute_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_variant FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_attribute_has_parent CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

-- INDEXES for product_attributes
CREATE INDEX idx_attribute_product ON product_attributes (product_id);
CREATE INDEX idx_attribute_variant ON product_attributes (variant_id);
CREATE INDEX idx_attribute_key ON product_attributes (attribute_key);
CREATE INDEX idx_attribute_filterable ON product_attributes (is_filterable, attribute_key);
CREATE INDEX idx_attribute_searchable ON product_attributes (is_searchable, attribute_key);
CREATE INDEX idx_attribute_display ON product_attributes (product_id, display_order);

-- COMMENTS for product_attributes
COMMENT ON TABLE product_attributes IS 'EAV model for flexible product and variant attributes';
COMMENT ON COLUMN product_attributes.attribute_key IS 'Attribute name (e.g., "Material", "Care Instructions")';
COMMENT ON COLUMN product_attributes.attribute_value IS 'Attribute value (e.g., "Cotton", "Machine Wash")';
COMMENT ON COLUMN product_attributes.attribute_type IS 'Data type for validation and display formatting';

-- =============================================
-- PRODUCT IMAGES TABLE
-- =============================================
CREATE TABLE product_images (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    product_id RAW(16) NOT NULL,
    url VARCHAR2(500) NOT NULL,
    alt_text VARCHAR2(255) NOT NULL,
    title VARCHAR2(255),

    -- Image metadata
    image_type VARCHAR2(20) DEFAULT 'gallery' CHECK (image_type IN ('main', 'gallery', 'thumbnail', 'zoom', 'lifestyle', 'detail', 'size_chart')),
    width_px NUMBER,
    height_px NUMBER,
    file_size_bytes NUMBER,  -- in bytes
    mime_type VARCHAR2(50),

    -- Display properties
    is_primary NUMBER(1) DEFAULT 0 CHECK (is_primary IN (0,1)),
    sort_order NUMBER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_image_product FOREIGN KEY (product_id)
        REFERENCES products(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_image_url_format CHECK (REGEXP_LIKE(url, '^https?://.+')),
    CONSTRAINT chk_image_dimensions_positive CHECK (
        (width_px IS NULL OR width_px > 0) AND (height_px IS NULL OR height_px > 0)
    ),
    CONSTRAINT chk_image_file_size_positive CHECK (file_size_bytes IS NULL OR file_size_bytes > 0)
);

-- INDEXES for product images
CREATE INDEX idx_image_product ON product_images (product_id);
CREATE INDEX idx_image_type ON product_images (image_type);
CREATE INDEX idx_image_primary ON product_images (product_id, is_primary);
CREATE INDEX idx_image_sort ON product_images (product_id, sort_order);

-- COMMENTS for product images
COMMENT ON TABLE product_images IS 'Product images and media assets';
COMMENT ON COLUMN product_images.image_type IS 'Type of image: main, gallery, thumbnail, zoom, lifestyle, detail, size_chart';

-- =============================================
-- PRODUCT REVIEWS TABLE
-- =============================================
CREATE TABLE product_reviews (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    product_id RAW(16) NOT NULL,
    customer_id RAW(16) NOT NULL,
    order_id RAW(16),  -- Optional: link to purchase

    -- Review content
    rating NUMBER(1) NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR2(255),
    review_text CLOB,

    -- Review metadata
    is_verified_purchase NUMBER(1) DEFAULT 0 CHECK (is_verified_purchase IN (0,1)),
    is_approved NUMBER(1) DEFAULT 0 CHECK (is_approved IN (0,1)),
    is_featured NUMBER(1) DEFAULT 0 CHECK (is_featured IN (0,1)),

    -- Helpful votes
    helpful_count NUMBER DEFAULT 0 CHECK (helpful_count >= 0),
    total_votes NUMBER DEFAULT 0 CHECK (total_votes >= 0),

    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP WITH TIME ZONE,

    -- Foreign keys
    CONSTRAINT fk_review_product FOREIGN KEY (product_id)
        REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_review_customer FOREIGN KEY (customer_id)
        REFERENCES customers(id) ON DELETE CASCADE,

    -- Unique constraint: one review per customer per product
    CONSTRAINT uk_review_customer_product UNIQUE (customer_id, product_id)
);

-- INDEXES for product reviews
CREATE INDEX idx_review_product ON product_reviews (product_id);
CREATE INDEX idx_review_customer ON product_reviews (customer_id);
CREATE INDEX idx_review_rating ON product_reviews (rating);
CREATE INDEX idx_review_approved ON product_reviews (is_approved);
CREATE INDEX idx_review_featured ON product_reviews (is_featured);
CREATE INDEX idx_review_created ON product_reviews (created_at DESC);
CREATE INDEX idx_review_helpful ON product_reviews (helpful_count DESC);

-- COMMENTS for product reviews
COMMENT ON TABLE product_reviews IS 'Customer product reviews and ratings';
COMMENT ON COLUMN product_reviews.is_verified_purchase IS 'Whether review is from verified purchase';

-- =============================================
-- TAGS TABLE
-- =============================================
CREATE TABLE tags (
    id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    name VARCHAR2(50) NOT NULL UNIQUE,
    slug VARCHAR2(50) NOT NULL UNIQUE,
    description VARCHAR2(255),
    color VARCHAR2(7), -- hex color like #FF5733
    sort_order NUMBER DEFAULT 0,
    is_active NUMBER(1) DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- INDEXES for tags
CREATE INDEX idx_tag_active ON tags (is_active);
CREATE INDEX idx_tag_sort ON tags (sort_order);

-- COMMENTS for tags
COMMENT ON TABLE tags IS 'Product tags with metadata for display and SEO';
COMMENT ON COLUMN tags.slug IS 'URL-friendly version of tag name for SEO';
COMMENT ON COLUMN tags.color IS 'Hex color code for visual tag display';

-- =============================================
-- PRODUCT TAGS TABLE
-- =============================================
CREATE TABLE product_tags (
    product_id RAW(16) NOT NULL,
    tag_id RAW(16) NOT NULL,

    -- Foreign keys
    CONSTRAINT fk_product_tag_product FOREIGN KEY (product_id)
        REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT fk_product_tag_tag FOREIGN KEY (tag_id)
        REFERENCES tags(id) ON DELETE CASCADE,

    -- Primary key
    CONSTRAINT pk_product_tag PRIMARY KEY (product_id, tag_id)
);

-- INDEXES for product tags
CREATE INDEX idx_product_tag_product ON product_tags (product_id);
CREATE INDEX idx_product_tag_tag ON product_tags (tag_id);

-- COMMENTS for product tags
COMMENT ON TABLE product_tags IS 'Junction table linking products to tags';
