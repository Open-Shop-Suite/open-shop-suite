# Domain Dependencies and Relationship Mapping
## Open Shop E-commerce Database Schema

### Overview

This document provides a comprehensive mapping of business domain relationships and dependencies within the Open Shop e-commerce database schema. The schema is organized into 8 separate migrations that create business domains with carefully orchestrated table creation order to satisfy foreign key dependencies.

### Migration Architecture

The Open Shop schema is split into 8 focused migrations, each handling a specific business domain:

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ System Foundation   │    │Customer Management │    │Authentication Module│
│ V001: Core utilities│    │V002: User accounts │    │V003: Auth tokens    │
│ • Audit Log         │    │• Customers         │    │• User Sessions      │
│ • Order Sequences   │    │• Addresses         │    │• Password Reset     │
│ • Utility Functions │    │• Preferences       │    │• Email Verification │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
                                                       │
┌─────────────────────┐    ┌─────────────────────┐    │
│  Product Catalog    │    │ Shopping Cart       │    │
│ V004: Product data  │    │ V005: Cart system   │    │
│ • Categories        │    │ • Shopping Carts    │    │
│ • Brands            │    │ • Cart Items        │    │
│ • Products          │    │                      │    │
│ • Variants          │    │                      │    │
│ • Attributes        │    │                      │    │
│ • Images            │    │                      │    │
│ • Reviews           │    │                      │    │
│ • Tags              │    │                      │    │
└─────────────────────┘    └─────────────────────┘    │
                              │                       │
┌─────────────────────┐        │                       │
│     Wishlist        │        │                       │
│  V006: Wishlist mgmt│        │                       │
│ • Wishlists         │        │                       │
│ • Wishlist Items    │        │                       │
└─────────────────────┘        │                       │
                              │                       │
┌─────────────────────┐        │                       │
│ Order Management    │◄───────┘                       │
│ V007: Order system  │◄───────────────────────────────┘
│ • Orders            │
│ • Order Items       │
│ • Payments          │
│ • Shipments         │
│ • Coupons           │
│ • Reviews           │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│ Inventory System    │
│ V008: Stock mgmt    │
│ • Suppliers         │
│ • Locations         │
│ • Stock Tracking    │
│ • Audit Logs        │
│ • Alerts            │
└─────────────────────┘
```

### Migration Execution Order and Dependencies

The migrations are executed in a specific order to satisfy foreign key dependencies across domains:

#### **V001__system_foundation** (No Dependencies)
- `audit_log` - General audit log for all operations
- `order_number_sequence` - Order number generation helper
- `generate_order_number()` - Utility function for order numbers

#### **V002__customer_management** (No Dependencies)
- `customers` - Core customer accounts
- `customer_addresses` - Shipping/billing addresses
- `customer_preferences` - User settings and preferences

#### **V003__authentication_module** (Depends on V002)
- `user_sessions` - Authentication sessions *(→ customers)*
- `password_reset_tokens` - Password recovery *(→ customers)*
- `email_verification_tokens` - Email verification *(→ customers)*

#### **V004__product_catalog** (Self-contained domain)
- `categories` - Product categories (hierarchical)
- `brands` - Product brands and manufacturers
- `products` - Core product catalog *(→ categories, brands)*
- `product_variants` - Product variants *(→ products)*
- `product_attributes` - EAV attributes *(→ products)*
- `product_images` - Product media *(→ products)*
- `product_reviews` - Customer reviews *(→ products)*
- `tags` - Product tags for organization
- `product_tags` - Product-tag relationships *(→ products, tags)*

#### **V005__shopping_cart** (Depends on V002, V004)
- `shopping_carts` - Shopping cart sessions *(→ customers)*
- `shopping_cart_items` - Cart contents *(→ carts, products, variants)*

#### **V006__wishlist** (Depends on V002, V004)
- `wishlists` - Customer wishlists *(→ customers)*
- `wishlist_items` - Wishlist contents *(→ wishlists, products, variants)*

#### **V007__order_management** (Depends on V002, V004)
- `orders` - Order headers *(→ customers)*
- `order_items` - Order line items *(→ orders, products, variants)*
- `order_addresses` - Order addresses *(→ orders)*
- `order_payments` - Payment processing *(→ orders)*
- `order_shipments` - Shipping tracking *(→ orders)*
- `coupons` - Discount codes
- `coupon_usage` - Coupon usage tracking *(→ coupons, customers, orders)*

#### **V008__inventory_system** (Depends on V004)
- `suppliers` - Product suppliers/vendors
- `inventory_locations` - Warehouse locations
- `inventory_stock` - Stock levels *(→ variants, suppliers, locations)*
- `inventory_log` - Inventory audit trail *(→ products, variants)*
- `inventory_alerts` - Automated alerts *(→ products, variants, suppliers)*

### Detailed Relationship Mappings

#### System Foundation Domain

**user_sessions**
- **Purpose**: Manages user authentication sessions
- **Primary Dependencies**: 
  - `customers(id)` → Session owner
- **Relationships**:
  - One customer can have multiple active sessions
  - Sessions expire automatically based on timestamp
- **Business Rules**:
  - Refresh tokens must be unique
  - Sessions automatically expire after inactivity

**password_reset_tokens**
- **Purpose**: Secure password reset workflow
- **Primary Dependencies**: 
  - `customers(id)` → Token owner
- **Relationships**:
  - One-to-many: Customer → Reset tokens
  - Tokens are single-use and time-limited
- **Business Rules**:
  - Tokens expire after configured time limit
  - Only unused tokens are valid for password reset

**email_verification_tokens**
- **Purpose**: Email address verification system
- **Primary Dependencies**: 
  - `customers(id)` → Token owner
- **Relationships**:
  - One-to-many: Customer → Verification tokens
  - Multiple tokens may exist for email changes
- **Business Rules**:
  - Tokens expire after configured time limit
  - Successful verification updates customer.email_verified

#### Customer Management Domain

**customers**
- **Purpose**: Core customer account management
- **Dependencies**: None (foundational entity)
- **Key Relationships**:
  - One-to-many: Customer → Addresses
  - One-to-one: Customer → Preferences
  - One-to-many: Customer → Sessions
  - One-to-many: Customer → Orders
  - One-to-many: Customer → Wishlists
- **OAuth Integration**:
  - Google, Facebook, LinkedIn identity mapping
  - Unique constraints on OAuth provider IDs

**customer_addresses**
- **Purpose**: Shipping and billing address management
- **Primary Dependencies**: 
  - `customers(id)` → Address owner
- **Relationships**:
  - Many-to-one: Addresses → Customer
  - Referenced by orders for shipping/billing snapshots
- **Business Rules**:
  - Address types: 'shipping', 'billing', 'both'
  - One default address per type per customer
  - Soft delete for address history preservation

**customer_preferences**
- **Purpose**: Individual customer preference management
- **Primary Dependencies**: 
  - `customers(id)` → Preference owner (unique)
- **Relationships**:
  - One-to-one: Customer → Preferences
- **Design**: Individual columns for better queryability vs JSON approach

#### Product Catalog Domain

**suppliers**
- **Purpose**: Vendor and supplier management
- **Dependencies**: None (foundational entity)
- **Key Relationships**:
  - One-to-many: Supplier → Categories
  - One-to-many: Supplier → Products
- **Business Attributes**:
  - Lead times, minimum order amounts
  - Contact information and business terms
  - Status management (active, inactive, suspended)

**categories**
- **Purpose**: Hierarchical product categorization
- **Primary Dependencies**: 
  - `suppliers(id)` → Category supplier relationship
- **Relationships**:
  - Hierarchical: Categories can have parent categories
  - One-to-many: Category → Products
- **Business Rules**:
  - URL-friendly slugs for SEO
  - Hierarchical path support for navigation

**products**
- **Purpose**: Core product information
- **Primary Dependencies**: 
  - `categories(id)` → Product categorization
  - `suppliers(id)` → Product supplier
- **Key Relationships**:
  - One-to-many: Product → Variants
  - One-to-many: Product → Images  
  - One-to-many: Product → Attributes (EAV)
  - Referenced by: Cart items, Order items, Reviews
- **Calculated Fields**:
  - Price ranges calculated from variants
  - Individual dimension fields for shipping

**product_variants**
- **Purpose**: SKU-level product variants with pricing and inventory
- **Primary Dependencies**: 
  - `products(id)` → Parent product
- **Relationships**:
  - Many-to-one: Variants → Product
  - Referenced by: Cart items, Order items, Wishlist items
- **Business Rules**:
  - Independent pricing and inventory per variant
  - Color, size, and other variant attributes
  - Low stock threshold management

**product_attributes (EAV Model)**
- **Purpose**: Flexible, queryable product attributes
- **Primary Dependencies**: 
  - `products(id)` → Product with attributes
- **Relationships**:
  - Many-to-many: Products ↔ Attributes via EAV
- **Design Benefits**:
  - More queryable than JSON approach
  - Supports complex product filtering
  - Maintains referential integrity

**product_images**
- **Purpose**: Product media asset management
- **Primary Dependencies**: 
  - `products(id)` → Product with images
- **Relationships**:
  - Many-to-one: Images → Product
  - Optional variant-specific images
- **Business Rules**:
  - Multiple image types (primary, gallery, thumbnail)
  - Display order management
  - Alt text for accessibility

#### Shopping Experience Domain

**shopping_carts**
- **Purpose**: Shopping cart session management
- **Primary Dependencies**: 
  - `customers(id)` → Cart owner (optional for guests)
  - `customer_addresses(id)` → Shipping/billing addresses
- **Relationships**:
  - One-to-many: Cart → Cart items
  - May reference customer addresses for calculations
- **Business Rules**:
  - Guest carts supported via session_id
  - Real-time total calculations
  - Coupon code integration

**shopping_cart_items**
- **Purpose**: Individual cart line items
- **Primary Dependencies**: 
  - `shopping_carts(id)` → Parent cart
  - `products(id)` → Referenced product
  - `product_variants(id)` → Specific variant
- **Relationships**:
  - Many-to-one: Items → Cart
  - Product snapshot preservation for price consistency
- **Business Rules**:
  - Quantity validation (positive numbers)
  - Price snapshot at time of addition
  - Calculated line totals

**wishlists**
- **Purpose**: Customer wishlist management
- **Primary Dependencies**: 
  - `customers(id)` → Wishlist owner
- **Relationships**:
  - Many-to-one: Wishlists → Customer
  - One-to-many: Wishlist → Wishlist items
- **Business Rules**:
  - Multiple wishlists per customer
  - Public/private sharing via share tokens
  - One default wishlist per customer

**wishlist_items**
- **Purpose**: Items saved in customer wishlists
- **Primary Dependencies**: 
  - `wishlists(id)` → Parent wishlist
  - `products(id)` → Saved product
  - `product_variants(id)` → Specific variant (optional)
- **Relationships**:
  - Many-to-one: Items → Wishlist
  - Product and variant references
- **Business Rules**:
  - Priority levels for items
  - Notes for personal reminders
  - Unique constraint per wishlist/product/variant combination

#### Order Management Domain

**orders**
- **Purpose**: Core order lifecycle management
- **Primary Dependencies**: 
  - `customers(id)` → Order customer
  - `customer_addresses(id)` → Shipping/billing addresses (optional)
- **Relationships**:
  - One-to-many: Order → Order items
  - One-to-many: Order → Order addresses
  - One-to-many: Order → Order payments
  - One-to-many: Order → Order shipments
  - One-to-one: Order → Review (optional)
- **Business Rules**:
  - Function-based order number generation
  - Status tracking with timestamps
  - Weight and dimension calculations

**order_items**
- **Purpose**: Order line item details
- **Primary Dependencies**: 
  - `orders(id)` → Parent order
  - `products(id)` → Ordered product
  - `product_variants(id)` → Specific variant
- **Relationships**:
  - Many-to-one: Items → Order
  - Product snapshot preservation
- **Business Rules**:
  - Price and details snapshot at order time
  - Individual item status tracking
  - Calculated line totals

**coupons**
- **Purpose**: Discount and promotional code management
- **Dependencies**: None (independent system)
- **Relationships**:
  - Referenced by: Shopping carts, Orders
  - One-to-many: Coupon → Usage records
- **Business Rules**:
  - Usage limits and expiration dates
  - Multiple discount types (fixed, percentage, free shipping)
  - Minimum order amount requirements

**coupon_usage**
- **Purpose**: Coupon usage tracking and analytics
- **Primary Dependencies**: 
  - `coupons(id)` → Used coupon
  - `customers(id)` → Customer who used coupon
  - `orders(id)` → Order where coupon was applied
- **Relationships**:
  - Many-to-one: Usage → Coupon, Customer, Order
- **Business Rules**:
  - Prevents duplicate usage when limits apply
  - Tracks actual discount amounts applied
  - Audit trail for coupon effectiveness

**product_reviews**
- **Purpose**: Customer product feedback and ratings
- **Primary Dependencies**: 
  - `products(id)` → Reviewed product
  - `customers(id)` → Review author
  - `orders(id)` → Purchase verification (optional)
- **Relationships**:
  - Many-to-one: Reviews → Product, Customer
  - Optional: Review → Order (verified purchase)
- **Business Rules**:
  - One review per customer per product
  - Rating scale 1-5 stars
  - Moderation status tracking

### Cross-Domain Integration Points

#### Authentication Flow
```
customers → user_sessions → password_reset_tokens/email_verification_tokens
```

#### Product Discovery
```
suppliers → categories → products → product_variants → product_attributes/product_images
```

#### Shopping Experience
```
customers → shopping_carts → shopping_cart_items → products/product_variants
customers → wishlists → wishlist_items → products/product_variants
```

#### Order Processing
```
customers + shopping_carts → orders → order_items → products/product_variants
orders → order_addresses/order_payments/order_shipments
orders + products → product_reviews
```

#### Coupon System Integration
```
coupons ↔ shopping_carts (applied discounts)
coupons + customers + orders → coupon_usage (tracking)
```

### Data Integrity Considerations

#### Referential Integrity
- All foreign key relationships enforced at database level
- Cascade deletes for dependent data (cart items, wishlist items)
- Restrict deletes for critical business data (customer orders)
- Set null for optional relationships

#### Business Rule Enforcement
- CHECK constraints for enumerated values
- Positive number constraints for quantities and prices
- Email format validation
- Unique constraints for business keys

#### Concurrency and Consistency
- Optimistic locking through updated_at timestamps
- Transaction boundaries for order processing
- Inventory management through product variants

### Performance Optimization Strategies

#### Indexing Strategy
- Primary and foreign key indexes for join performance
- Composite indexes for common query patterns
- Search indexes for product discovery
- Partial indexes for filtered queries

#### Query Optimization
- Materialized calculated fields (price ranges, totals)
- Denormalized data where appropriate (product snapshots in orders)
- View definitions for complex joins (customer_overview)

#### Scalability Considerations
- Partition-ready design for time-series data
- Horizontal scaling support through consistent sharding keys
- Read replica optimization patterns

### Conclusion

The Open Shop database schema provides a well-architected foundation for e-commerce operations with clear domain boundaries and carefully managed dependencies. The modular migration approach with 8 focused files ensures consistent deployment while the domain-driven design facilitates maintenance and future enhancements.

**Migration Structure Benefits:**
- **Focused Development**: Each migration handles a specific business domain
- **Incremental Deployment**: Migrations can be developed and deployed independently
- **Easier Testing**: Domain-specific testing and validation
- **Better Version Control**: Smaller, focused changes are easier to review
- **Rollback Safety**: Issues affect only specific domains, not entire schema

**Key Architectural Strengths:**
- **Normalized Data Model**: Proper separation of concerns with referential integrity
- **EAV Product Attributes**: Flexible, queryable product attributes system
- **Comprehensive Inventory**: Multi-supplier, multi-location stock management
- **Complete Audit Trail**: System-wide change tracking and compliance
- **Scalable Design**: Supports high-volume e-commerce operations

The schema successfully balances flexibility, performance, and maintainability for modern e-commerce platforms.
