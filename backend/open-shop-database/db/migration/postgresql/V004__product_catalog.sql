-- =============================================
-- Open Shop E-commerce Platform - PostgreSQL Schema
-- V004: Product Catalog
-- =============================================

-- =============================================
-- CATEGORIES TABLE
-- =============================================
CREATE TABLE categories (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_id UUID,

    -- SEO fields
    seo_title VARCHAR(60),
    seo_description VARCHAR(160),

    -- Display properties
    image_url VARCHAR(500),
    image_alt_text VARCHAR(255),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,

    -- Path for hierarchical queries (materialized path)
    path VARCHAR(1000),
    level_depth INTEGER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,

    -- Constraints
    CONSTRAINT chk_category_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT chk_category_level_positive CHECK (level_depth >= 0),
    CONSTRAINT chk_category_no_self_parent CHECK (id != parent_id)
);

-- Indexes for categories
CREATE INDEX idx_category_parent ON categories (parent_id);
CREATE INDEX idx_category_active ON categories (is_active);
CREATE INDEX idx_category_featured ON categories (is_featured);
CREATE INDEX idx_category_level ON categories (level_depth);
CREATE INDEX idx_category_sort ON categories (sort_order);

-- =============================================
-- BRANDS TABLE
-- =============================================
CREATE TABLE brands (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
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
    sort_order INTEGER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_brand_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT chk_brand_website_url_format CHECK (website_url IS NULL OR website_url ~ '^https?://.+')
);

-- Indexes for brands
CREATE INDEX idx_brand_active ON brands (is_active);
CREATE INDEX idx_brand_sort ON brands (sort_order);

-- =============================================
-- PRODUCTS TABLE
-- =============================================
CREATE TABLE products (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    short_description VARCHAR(500),

    -- Relations
    category_id UUID NOT NULL,
    brand_id UUID NOT NULL,

    -- SKU and barcoding
    sku VARCHAR(100),
    barcode VARCHAR(50),

    -- Physical properties
    weight_grams DECIMAL(10,3),
    length_cm DECIMAL(10,2),
    width_cm DECIMAL(10,2),
    height_cm DECIMAL(10,2),
    dimension_unit dimension_unit DEFAULT 'cm',

    -- Status and visibility
    status product_status DEFAULT 'draft',
    is_featured BOOLEAN DEFAULT FALSE,

    -- SEO fields
    seo_title VARCHAR(60),
    seo_description VARCHAR(160),

    -- Calculated fields (updated by triggers)
    min_price DECIMAL(12,2),
    max_price DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',
    avg_rating DECIMAL(3,2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    total_stock INTEGER DEFAULT 0,
    is_in_stock BOOLEAN DEFAULT FALSE,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
    FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE RESTRICT,

    -- Constraints
    CONSTRAINT chk_product_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT chk_product_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_product_weight_positive CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_product_dimensions_positive CHECK (
        (length_cm IS NULL OR length_cm >= 0) AND
        (width_cm IS NULL OR width_cm >= 0) AND
        (height_cm IS NULL OR height_cm >= 0)
    ),
    CONSTRAINT chk_product_price_range CHECK (min_price IS NULL OR max_price IS NULL OR min_price <= max_price),
    CONSTRAINT chk_product_rating_range CHECK (avg_rating BETWEEN 0 AND 5)
);

-- Indexes for products
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

-- Full text search index removed for consistency with other databases

-- =============================================
-- PRODUCT VARIANTS TABLE
-- =============================================
CREATE TABLE product_variants (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    product_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    sku VARCHAR(100) NOT NULL UNIQUE,

    -- Pricing
    price DECIMAL(12,2) NOT NULL,
    compare_at_price DECIMAL(12,2),
    cost_price DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Variant properties
    color_name VARCHAR(50),
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
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_variant_price_positive CHECK (price >= 0),
    CONSTRAINT chk_variant_compare_price_positive CHECK (compare_at_price IS NULL OR compare_at_price >= 0),
    CONSTRAINT chk_variant_cost_price_positive CHECK (cost_price IS NULL OR cost_price >= 0),
    CONSTRAINT chk_variant_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_variant_weight_positive CHECK (weight_grams IS NULL OR weight_grams >= 0),
    CONSTRAINT chk_variant_dimensions_positive CHECK (
        (length_cm IS NULL OR length_cm >= 0) AND
        (width_cm IS NULL OR width_cm >= 0) AND
        (height_cm IS NULL OR height_cm >= 0)
    )
);

-- Indexes for product variants
CREATE INDEX idx_variant_product ON product_variants (product_id);
CREATE INDEX idx_variant_color ON product_variants (color_name);
CREATE INDEX idx_variant_size ON product_variants (size_type);
CREATE INDEX idx_variant_active ON product_variants (is_active);
CREATE INDEX idx_variant_price ON product_variants (price);

-- =============================================
-- PRODUCT ATTRIBUTES TABLE (EAV MODEL)
-- =============================================
CREATE TABLE product_attributes (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    product_id UUID,
    variant_id UUID,

    -- Attribute Information
    attribute_key VARCHAR(100) NOT NULL,
    attribute_value TEXT NOT NULL,
    attribute_type VARCHAR(20) DEFAULT 'text' CHECK (attribute_type IN ('text', 'number', 'boolean', 'date', 'url', 'email')),

    -- Attribute Properties
    is_filterable BOOLEAN DEFAULT FALSE,
    is_searchable BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_attribute_has_parent CHECK (
        (product_id IS NOT NULL AND variant_id IS NULL) OR
        (product_id IS NULL AND variant_id IS NOT NULL)
    )
);

-- Indexes for product_attributes
CREATE INDEX idx_attribute_product ON product_attributes (product_id);
CREATE INDEX idx_attribute_variant ON product_attributes (variant_id);
CREATE INDEX idx_attribute_key ON product_attributes (attribute_key);
CREATE INDEX idx_attribute_filterable ON product_attributes (is_filterable, attribute_key);
CREATE INDEX idx_attribute_searchable ON product_attributes (is_searchable, attribute_key);
CREATE INDEX idx_attribute_display ON product_attributes (product_id, display_order);

-- =============================================
-- PRODUCT IMAGES TABLE
-- =============================================
CREATE TABLE product_images (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    product_id UUID NOT NULL,
    url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255) NOT NULL,
    title VARCHAR(255),

    -- Image metadata
    image_type VARCHAR(20) DEFAULT 'gallery' CHECK (image_type IN ('main', 'gallery', 'thumbnail', 'zoom', 'lifestyle', 'detail', 'size_chart')),
    width_px INTEGER,
    height_px INTEGER,
    file_size_bytes INTEGER,
    mime_type VARCHAR(50),

    -- Display properties
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,

    -- Constraints
    CONSTRAINT chk_image_url_format CHECK (url ~ '^https?://.+'),
    CONSTRAINT chk_image_dimensions_positive CHECK (
        (width_px IS NULL OR width_px > 0) AND (height_px IS NULL OR height_px > 0)
    ),
    CONSTRAINT chk_image_file_size_positive CHECK (file_size_bytes IS NULL OR file_size_bytes > 0)
);

-- Indexes for product_images
CREATE INDEX idx_image_product ON product_images (product_id);
CREATE INDEX idx_image_type ON product_images (image_type);
CREATE INDEX idx_image_primary ON product_images (product_id, is_primary);
CREATE INDEX idx_image_sort ON product_images (product_id, sort_order);

-- =============================================
-- PRODUCT REVIEWS TABLE
-- =============================================
CREATE TABLE product_reviews (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    product_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    order_id UUID,  -- Optional: link to purchase

    -- Review content
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    review_text TEXT,

    -- Review metadata
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,

    -- Helpful votes
    helpful_count INTEGER DEFAULT 0 CHECK (helpful_count >= 0),
    total_votes INTEGER DEFAULT 0 CHECK (total_votes >= 0),

    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP NULL,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,

    -- Unique constraint: one review per customer per product
    UNIQUE (customer_id, product_id)
);

-- Indexes for product_reviews
CREATE INDEX idx_review_product ON product_reviews (product_id);
CREATE INDEX idx_review_customer ON product_reviews (customer_id);
CREATE INDEX idx_review_rating ON product_reviews (rating);
CREATE INDEX idx_review_approved ON product_reviews (is_approved);
CREATE INDEX idx_review_featured ON product_reviews (is_featured);
CREATE INDEX idx_review_created ON product_reviews (created_at DESC);
CREATE INDEX idx_review_helpful ON product_reviews (helpful_count DESC);

-- =============================================
-- TAGS TABLE
-- =============================================
CREATE TABLE tags (
    id UUID NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    color VARCHAR(7), -- hex color like #FF5733
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for tags
CREATE INDEX idx_tag_active ON tags (is_active);
CREATE INDEX idx_tag_sort ON tags (sort_order);

-- =============================================
-- PRODUCT TAGS TABLE
-- =============================================
CREATE TABLE product_tags (
    product_id UUID NOT NULL,
    tag_id UUID NOT NULL,

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,

    -- Primary key
    PRIMARY KEY (product_id, tag_id)
);

-- Indexes for product_tags
CREATE INDEX idx_product_tag_product ON product_tags (product_id);
CREATE INDEX idx_product_tag_tag ON product_tags (tag_id);



-- =============================================
-- TRIGGERS
-- =============================================

-- Update timestamp triggers for product catalog
CREATE TRIGGER category_updated_at_trigger
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER brand_updated_at_trigger
    BEFORE UPDATE ON brands
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER product_updated_at_trigger
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER product_image_updated_at_trigger
    BEFORE UPDATE ON product_images
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER product_variant_updated_at_trigger
    BEFORE UPDATE ON product_variants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

