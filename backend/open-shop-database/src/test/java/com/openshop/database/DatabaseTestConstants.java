package com.openshop.database;

import java.util.Map;
import java.util.HashMap;
import java.util.Arrays;
import java.util.List;

/**
 * Shared constants for database schema tests.
 * This ensures consistency across Oracle, MySQL, and other database tests.
 */
public final class DatabaseTestConstants {

    /**
     * Expected table names that should exist in the database schema.
     * This list is shared across all database implementations (Oracle, MySQL, etc.)
     * to ensure schema consistency.
     */
    public static final String[] EXPECTED_TABLES = {
            // Customer Management
            "CUSTOMERS",
            "CUSTOMER_PREFERENCES",
            "CUSTOMER_ADDRESSES",
            "USER_SESSIONS",

            // Product Catalog
            "CATEGORIES",
            "BRANDS",
            "SUPPLIERS",
            "PRODUCTS",
            "PRODUCT_VARIANTS",
            "PRODUCT_ATTRIBUTES",
            "PRODUCT_IMAGES",
            "PRODUCT_REVIEWS",
            "PRODUCT_TAGS",
            "TAGS",

            // Inventory Management
            "INVENTORY_LOCATIONS",
            "INVENTORY_STOCK",
            "INVENTORY_LOG",
            "INVENTORY_ALERTS",

            // Order Management
            "ORDERS",
            "ORDER_ITEMS",
            "ORDER_ADDRESSES",
            "ORDER_PAYMENTS",
            "ORDER_SHIPMENTS",

            // Shopping & Wishlist
            "SHOPPING_CARTS",
            "SHOPPING_CART_ITEMS",
            "WISHLISTS",
            "WISHLIST_ITEMS",

            // Promotions
            "COUPONS",
            "COUPON_USAGE",

            // Audit & Security
            "AUDIT_LOG",
            "EMAIL_VERIFICATION_TOKENS",
            "PASSWORD_RESET_TOKENS"
    };

    /**
     * Expected indexes for each table.
     * Maps table name to list of index names that must exist.
     * Index names are in uppercase for consistency.
     * Only includes explicit CREATE INDEX statements from DDL scripts (excludes system-generated constraint indexes)
     */
    public static final Map<String, List<String>> EXPECTED_TABLE_INDEXES = new HashMap<>() {{
        // System Foundation
        put("AUDIT_LOG", Arrays.asList(
                "IDX_AUDIT_TABLE_RECORD", "IDX_AUDIT_TIMESTAMP", "IDX_AUDIT_USER"
        ));

        // Customer Management
        put("CUSTOMERS", Arrays.asList(
                "IDX_CUSTOMER_PHONE", "IDX_CUSTOMER_NAME",
                "IDX_CUSTOMER_EMAIL_VERIFIED", "IDX_CUSTOMER_CREATED", "IDX_CUSTOMER_LAST_LOGIN"
        ));

        put("CUSTOMER_ADDRESSES", Arrays.asList(
                "IDX_ADDRESS_CUSTOMER", "IDX_ADDRESS_TYPE", "IDX_ADDRESS_DEFAULT", "IDX_ADDRESS_COUNTRY", "IDX_ADDRESS_POSTAL", "IDX_ADDRESS_VALIDATED"
        ));

        put("CUSTOMER_PREFERENCES", Arrays.asList(
                "IDX_PREFERENCE_CURRENCY", "IDX_PREFERENCE_LANGUAGE"
        ));

        // Authentication Module
        put("USER_SESSIONS", Arrays.asList(
                "IDX_SESSION_CUSTOMER", "IDX_SESSION_EXPIRES", "IDX_SESSION_ACTIVE"
        ));

        put("PASSWORD_RESET_TOKENS", Arrays.asList(
                "IDX_RESET_CUSTOMER", "IDX_RESET_EXPIRES"
        ));

        put("EMAIL_VERIFICATION_TOKENS", Arrays.asList(
                "IDX_VERIFY_CUSTOMER", "IDX_VERIFY_EMAIL"
        ));

        // Product Catalog
        put("CATEGORIES", Arrays.asList(
                "IDX_CATEGORY_PARENT", "IDX_CATEGORY_ACTIVE", "IDX_CATEGORY_FEATURED",
                "IDX_CATEGORY_LEVEL", "IDX_CATEGORY_SORT"
        ));

        put("BRANDS", Arrays.asList(
                "IDX_BRAND_ACTIVE", "IDX_BRAND_SORT"
        ));

        put("PRODUCTS", Arrays.asList(
                "IDX_PRODUCT_NAME", "IDX_PRODUCT_CATEGORY", "IDX_PRODUCT_BRAND", "IDX_PRODUCT_STATUS",
                "IDX_PRODUCT_FEATURED", "IDX_PRODUCT_IN_STOCK", "IDX_PRODUCT_PRICE_RANGE", "IDX_PRODUCT_RATING",
                "IDX_PRODUCT_CREATED", "IDX_PRODUCT_SKU", "IDX_PRODUCT_BARCODE"
        ));

        put("PRODUCT_VARIANTS", Arrays.asList(
                "IDX_VARIANT_PRODUCT", "IDX_VARIANT_COLOR", "IDX_VARIANT_SIZE",
                "IDX_VARIANT_ACTIVE", "IDX_VARIANT_PRICE"
        ));

        put("PRODUCT_ATTRIBUTES", Arrays.asList(
                "IDX_ATTRIBUTE_PRODUCT", "IDX_ATTRIBUTE_VARIANT", "IDX_ATTRIBUTE_KEY",
                "IDX_ATTRIBUTE_FILTERABLE", "IDX_ATTRIBUTE_SEARCHABLE", "IDX_ATTRIBUTE_DISPLAY"
        ));

        put("PRODUCT_IMAGES", Arrays.asList(
                "IDX_IMAGE_PRODUCT", "IDX_IMAGE_TYPE", "IDX_IMAGE_PRIMARY", "IDX_IMAGE_SORT"
        ));

        put("PRODUCT_REVIEWS", Arrays.asList(
                "IDX_REVIEW_PRODUCT", "IDX_REVIEW_CUSTOMER", "IDX_REVIEW_RATING",
                "IDX_REVIEW_APPROVED", "IDX_REVIEW_FEATURED", "IDX_REVIEW_CREATED", "IDX_REVIEW_HELPFUL"
        ));

        put("TAGS", Arrays.asList(
                "IDX_TAG_ACTIVE", "IDX_TAG_SORT"
        ));

        put("PRODUCT_TAGS", Arrays.asList(
                "IDX_PRODUCT_TAG_PRODUCT", "IDX_PRODUCT_TAG_TAG"
        ));

        // Shopping Cart
        put("SHOPPING_CARTS", Arrays.asList(
                "IDX_CART_CUSTOMER", "IDX_CART_SESSION", "IDX_CART_STATUS",
                "IDX_CART_LAST_ACTIVITY", "IDX_CART_EXPIRES", "IDX_CART_COUPON"
        ));

        put("SHOPPING_CART_ITEMS", Arrays.asList(
                "IDX_CART_ITEM_CART", "IDX_CART_ITEM_PRODUCT", "IDX_CART_ITEM_VARIANT",
                "IDX_CART_ITEM_AVAILABILITY", "IDX_CART_ITEM_ADDED"
        ));

        // Wishlist
        put("WISHLISTS", Arrays.asList(
                "IDX_WISHLIST_CUSTOMER", "IDX_WISHLIST_DEFAULT", "IDX_WISHLIST_PUBLIC"
        ));

        put("WISHLIST_ITEMS", Arrays.asList(
                "IDX_WISHLIST_ITEM_WISHLIST", "IDX_WISHLIST_ITEM_PRODUCT",
                "IDX_WISHLIST_ITEM_VARIANT", "IDX_WISHLIST_ITEM_PRIORITY", "IDX_WISHLIST_ITEM_ADDED"
        ));

        // Order Management
        put("ORDERS", Arrays.asList(
                "IDX_ORDER_CUSTOMER", "IDX_ORDER_STATUS", "IDX_ORDER_CREATED",
                "IDX_ORDER_TOTAL", "IDX_ORDER_COUPON"
        ));

        put("ORDER_ITEMS", Arrays.asList(
                "IDX_ORDER_ITEM_ORDER", "IDX_ORDER_ITEM_PRODUCT", "IDX_ORDER_ITEM_VARIANT", "IDX_ORDER_ITEM_FULFILLMENT"
        ));

        put("ORDER_ADDRESSES", Arrays.asList(
                "IDX_ORDER_ADDRESS_ORDER", "IDX_ORDER_ADDRESS_TYPE", "IDX_ORDER_ADDRESS_COUNTRY", "IDX_ORDER_ADDRESS_POSTAL"
        ));

        put("ORDER_PAYMENTS", Arrays.asList(
                "IDX_PAYMENT_ORDER", "IDX_PAYMENT_PROVIDER", "IDX_PAYMENT_STATUS",
                "IDX_PAYMENT_PROVIDER_PAYMENT_ID", "IDX_PAYMENT_CREATED"
        ));

        put("ORDER_SHIPMENTS", Arrays.asList(
                "IDX_SHIPPING_ORDER", "IDX_SHIPPING_CARRIER", "IDX_SHIPPING_STATUS",
                "IDX_SHIPPING_TRACKING", "IDX_SHIPPING_CREATED", "IDX_SHIPPING_ESTIMATED_DELIVERY"
        ));

        put("COUPONS", Arrays.asList(
                "IDX_COUPON_ACTIVE", "IDX_COUPON_EXPIRES", "IDX_COUPON_STARTS", "IDX_COUPON_TYPE"
        ));

        put("COUPON_USAGE", Arrays.asList(
                "IDX_COUPON_USAGE_COUPON", "IDX_COUPON_USAGE_CUSTOMER",
                "IDX_COUPON_USAGE_ORDER", "IDX_COUPON_USAGE_USED_AT"
        ));

        // Inventory Management
        put("SUPPLIERS", Arrays.asList(
                "IDX_SUPPLIER_NAME", "IDX_SUPPLIER_STATUS", "IDX_SUPPLIER_COUNTRY",
                "IDX_SUPPLIER_RATING"
        ));

        put("INVENTORY_LOCATIONS", Arrays.asList(
                "IDX_LOCATION_TYPE", "IDX_LOCATION_ACTIVE", "IDX_LOCATION_COUNTRY"
        ));

        put("INVENTORY_STOCK", Arrays.asList(
                "IDX_STOCK_VARIANT", "IDX_STOCK_SUPPLIER", "IDX_STOCK_LOCATION",
                "IDX_STOCK_SUPPLIED_DATE", "IDX_STOCK_STATUS", "IDX_STOCK_AVAILABLE"
        ));

        put("INVENTORY_LOG", Arrays.asList(
                "IDX_LOG_ENTITY_TYPE", "IDX_LOG_PRODUCT", "IDX_LOG_VARIANT", "IDX_LOG_SUPPLIER",
                "IDX_LOG_LOCATION", "IDX_LOG_OPERATION", "IDX_LOG_CREATED", "IDX_LOG_REFERENCE", "IDX_LOG_ADMIN_USER"
        ));

        put("INVENTORY_ALERTS", Arrays.asList(
                "IDX_ALERT_TYPE", "IDX_ALERT_SEVERITY", "IDX_ALERT_STATUS", "IDX_ALERT_PRODUCT",
                "IDX_ALERT_VARIANT", "IDX_ALERT_SUPPLIER", "IDX_ALERT_LOCATION", "IDX_ALERT_CREATED",
                "IDX_ALERT_ACKNOWLEDGED", "IDX_ALERT_RESOLVED"
        ));
    }};

    /**
     * Expected columns for each table.
     * Maps table name to list of column names that must exist.
     * Column names are in uppercase for consistency.
     */
    public static final Map<String, List<String>> EXPECTED_TABLE_COLUMNS = new HashMap<>() {{
        // Customer Management
        put("CUSTOMERS", Arrays.asList(
                "ID", "EMAIL", "PASSWORD_HASH", "FIRST_NAME", "LAST_NAME", "PHONE",
                "DATE_OF_BIRTH", "EMAIL_VERIFIED", "EMAIL_VERIFIED_AT",
                "GOOGLE_ID", "FACEBOOK_ID", "LINKEDIN_ID",
                "CREATED_AT", "UPDATED_AT", "LAST_LOGIN_AT"
        ));

        put("CUSTOMER_PREFERENCES", Arrays.asList(
                "ID", "CUSTOMER_ID",
                "EMAIL_NOTIFICATIONS", "SMS_NOTIFICATIONS", "PUSH_NOTIFICATIONS", "MARKETING_EMAILS",
                "CURRENCY", "LANGUAGE", "TIMEZONE",
                "THEME", "ITEMS_PER_PAGE",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("CUSTOMER_ADDRESSES", Arrays.asList(
                "ID", "CUSTOMER_ID", "TYPE",
                "FIRST_NAME", "LAST_NAME", "FULL_NAME", "COMPANY",
                "ADDRESS_LINE1", "ADDRESS_LINE2", "CITY", "STATE", "POSTAL_CODE", "COUNTRY", "PHONE",
                "IS_DEFAULT", "IS_VALIDATED",
                "LONGITUDE", "LATITUDE",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("USER_SESSIONS", Arrays.asList(
                "ID", "CUSTOMER_ID", "REFRESH_TOKEN", "ACCESS_TOKEN_HASH",
                "EXPIRES_AT", "CREATED_AT", "LAST_ACCESSED_AT",
                "IP_ADDRESS", "USER_AGENT", "IS_ACTIVE"
        ));

        // Product Catalog
        put("CATEGORIES", Arrays.asList(
                "ID", "NAME", "SLUG", "DESCRIPTION", "PARENT_ID",
                "SEO_TITLE", "SEO_DESCRIPTION",
                "IMAGE_URL", "IMAGE_ALT_TEXT", "SORT_ORDER", "IS_ACTIVE", "IS_FEATURED",
                "PATH", "LEVEL_DEPTH",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("BRANDS", Arrays.asList(
                "ID", "NAME", "SLUG", "DESCRIPTION",
                "LOGO_URL", "LOGO_ALT_TEXT", "WEBSITE_URL",
                "SEO_TITLE", "SEO_DESCRIPTION",
                "IS_ACTIVE", "SORT_ORDER",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("SUPPLIERS", Arrays.asList(
                "ID", "NAME", "SLUG", "DESCRIPTION",
                "CONTACT_PERSON", "EMAIL", "PHONE", "WEBSITE_URL",
                "ADDRESS_LINE1", "ADDRESS_LINE2", "CITY", "STATE", "POSTAL_CODE", "COUNTRY",
                "TAX_ID", "PAYMENT_TERMS", "LEAD_TIME_DAYS", "MINIMUM_ORDER_AMOUNT", "CURRENCY",
                "STATUS", "RATING",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("PRODUCTS", Arrays.asList(
                "ID", "NAME", "SLUG", "DESCRIPTION", "SHORT_DESCRIPTION",
                "CATEGORY_ID", "BRAND_ID",
                "SKU", "BARCODE",
                "WEIGHT_GRAMS", "LENGTH_CM", "WIDTH_CM", "HEIGHT_CM", "DIMENSION_UNIT",
                "STATUS", "IS_FEATURED",
                "SEO_TITLE", "SEO_DESCRIPTION",
                "MIN_PRICE", "MAX_PRICE", "CURRENCY", "AVG_RATING", "REVIEW_COUNT", "TOTAL_STOCK", "IS_IN_STOCK",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("PRODUCT_VARIANTS", Arrays.asList(
                "ID", "PRODUCT_ID", "NAME", "SKU",
                "PRICE", "COMPARE_AT_PRICE", "COST_PRICE", "CURRENCY",
                "COLOR_NAME", "SIZE_TYPE", "MATERIAL",
                "WEIGHT_GRAMS", "LENGTH_CM", "WIDTH_CM", "HEIGHT_CM",
                "IS_ACTIVE",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("PRODUCT_ATTRIBUTES", Arrays.asList(
                "ID", "PRODUCT_ID", "VARIANT_ID",
                "ATTRIBUTE_KEY", "ATTRIBUTE_VALUE", "ATTRIBUTE_TYPE",
                "IS_FILTERABLE", "IS_SEARCHABLE", "DISPLAY_ORDER",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("PRODUCT_IMAGES", Arrays.asList(
                "ID", "PRODUCT_ID", "URL", "ALT_TEXT", "TITLE",
                "IMAGE_TYPE", "WIDTH_PX", "HEIGHT_PX", "FILE_SIZE_BYTES", "MIME_TYPE",
                "IS_PRIMARY", "SORT_ORDER",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("PRODUCT_REVIEWS", Arrays.asList(
                "ID", "PRODUCT_ID", "CUSTOMER_ID", "ORDER_ID",
                "RATING", "TITLE", "REVIEW_TEXT",
                "IS_VERIFIED_PURCHASE", "IS_APPROVED", "IS_FEATURED",
                "HELPFUL_COUNT", "TOTAL_VOTES",
                "CREATED_AT", "UPDATED_AT", "APPROVED_AT"
        ));

        put("PRODUCT_TAGS", Arrays.asList(
                "PRODUCT_ID", "TAG_ID"
        ));

        put("TAGS", Arrays.asList(
                "ID", "NAME", "SLUG", "DESCRIPTION", "COLOR", "SORT_ORDER", "IS_ACTIVE", "CREATED_AT"
        ));

        // Inventory Management
        put("INVENTORY_LOCATIONS", Arrays.asList(
                "ID", "NAME", "CODE", "TYPE", "DESCRIPTION",
                "ADDRESS_LINE1", "ADDRESS_LINE2", "CITY", "STATE", "POSTAL_CODE", "COUNTRY",
                "IS_ACTIVE", "CAPACITY_SQM", "TEMPERATURE_CONTROLLED",
                "CONTACT_PERSON", "CONTACT_PHONE", "CONTACT_EMAIL",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("INVENTORY_STOCK", Arrays.asList(
                "VARIANT_ID", "SUPPLIER_ID", "LOCATION_ID", "SUPPLIED_DATE",
                "COST_PRICE", "SUPPLIER_SKU", "BATCH_REFERENCE",
                "QUANTITY_ON_HAND", "QUANTITY_RESERVED", "QUANTITY_AVAILABLE",
                "LOW_STOCK_THRESHOLD", "REORDER_QUANTITY",
                "STATUS", "EXPIRY_DATE", "LAST_INVENTORY_COUNT", "LAST_UPDATED"
        ));

        put("INVENTORY_LOG", Arrays.asList(
                "ID",
                "ENTITY_TYPE", "OPERATION_TYPE",
                "PRODUCT_ID", "VARIANT_ID", "SUPPLIER_ID", "LOCATION_ID",
                "OLD_VALUES", "NEW_VALUES",
                "QUANTITY_CHANGE", "QUANTITY_BEFORE", "QUANTITY_AFTER",
                "REASON", "REFERENCE_TYPE", "REFERENCE_ID",
                "ADMIN_USER_ID", "ADMIN_USERNAME",
                "IP_ADDRESS", "USER_AGENT",
                "CREATED_AT"
        ));

        put("INVENTORY_ALERTS", Arrays.asList(
                "ID",
                "ALERT_TYPE", "SEVERITY",
                "PRODUCT_ID", "VARIANT_ID", "SUPPLIER_ID", "LOCATION_ID",
                "TITLE", "MESSAGE", "SUGGESTED_ACTION",
                "STATUS", "ACKNOWLEDGED_BY", "ACKNOWLEDGED_AT", "RESOLVED_BY", "RESOLVED_AT",
                "CURRENT_VALUE", "THRESHOLD_VALUE", "UNIT",
                "AUTO_RESOLVE_HOURS", "AUTO_RESOLVE_ENABLED",
                "CREATED_AT", "UPDATED_AT"
        ));

        // Order Management
        put("ORDERS", Arrays.asList(
                "ID", "ORDER_NUMBER", "CUSTOMER_ID",
                "STATUS",
                "SUBTOTAL", "DISCOUNT_TOTAL", "TAX_TOTAL", "SHIPPING_COST", "TOTAL_AMOUNT", "CURRENCY",
                "COUPON_CODE", "COUPON_DISCOUNT_AMOUNT", "COUPON_DISCOUNT_TYPE",
                "CUSTOMER_NOTES", "SPECIAL_INSTRUCTIONS",
                "REQUIRES_SHIPPING", "WEIGHT_TOTAL",
                "CREATED_AT", "UPDATED_AT", "CONFIRMED_AT", "SHIPPED_AT", "DELIVERED_AT", "CANCELLED_AT"
        ));

        put("ORDER_ITEMS", Arrays.asList(
                "ID", "ORDER_ID", "PRODUCT_ID", "VARIANT_ID",
                "QUANTITY", "UNIT_PRICE", "LINE_TOTAL",
                "PRODUCT_NAME", "PRODUCT_SLUG", "VARIANT_NAME", "VARIANT_SKU",
                "COLOR_NAME", "SIZE_NAME", "MATERIAL", "WEIGHT_GRAMS",
                "COST_PRICE", "PROFIT_MARGIN",
                "FULFILLMENT_STATUS", "SHIPPED_QUANTITY"
        ));

        put("ORDER_ADDRESSES", Arrays.asList(
                "ID", "ORDER_ID", "ADDRESS_TYPE",
                "FIRST_NAME", "LAST_NAME", "FULL_NAME", "COMPANY",
                "ADDRESS_LINE1", "ADDRESS_LINE2", "CITY", "STATE", "POSTAL_CODE", "COUNTRY", "PHONE",
                "IS_VALIDATED", "VALIDATION_SCORE"
        ));

        put("ORDER_PAYMENTS", Arrays.asList(
                "ID", "ORDER_ID",
                "PAYMENT_PROVIDER", "PAYMENT_METHOD",
                "AMOUNT", "CURRENCY",
                "STATUS",
                "PROVIDER_PAYMENT_ID", "PROVIDER_CHARGE_ID", "PROVIDER_TRANSACTION_ID", "PROVIDER_METADATA",
                "AUTHORIZED_AT", "CAPTURED_AT", "FAILED_AT", "REFUNDED_AT",
                "FAILURE_CODE", "FAILURE_MESSAGE",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("ORDER_SHIPMENTS", Arrays.asList(
                "ID", "ORDER_ID",
                "CARRIER", "SERVICE_LEVEL",
                "TRACKING_NUMBER", "TRACKING_URL",
                "STATUS",
                "WEIGHT_GRAMS", "DIMENSIONS_LENGTH", "DIMENSIONS_WIDTH", "DIMENSIONS_HEIGHT", "DIMENSION_UNIT",
                "SHIPPING_COST", "INSURANCE_COST", "HANDLING_FEE",
                "PROVIDER_SHIPMENT_ID", "PROVIDER_METADATA",
                "ESTIMATED_DELIVERY_DATE", "ACTUAL_DELIVERY_DATE",
                "DELIVERED_TO", "DELIVERY_LOCATION", "DELIVERY_SIGNATURE_REQUIRED", "DELIVERY_SIGNATURE_OBTAINED",
                "CREATED_AT", "UPDATED_AT", "SHIPPED_AT", "DELIVERED_AT"
        ));

        // Shopping & Wishlist
        put("SHOPPING_CARTS", Arrays.asList(
                "ID", "CUSTOMER_ID", "SESSION_ID",
                "STATUS", "CURRENCY",
                "COUPON_CODE", "COUPON_DISCOUNT_AMOUNT", "COUPON_DISCOUNT_TYPE",
                "ITEM_COUNT", "SUBTOTAL", "DISCOUNT_TOTAL", "TAX_ESTIMATE", "SHIPPING_ESTIMATE", "TOTAL_ESTIMATE",
                "TAX_RATE", "SHIPPING_ADDRESS_ID", "BILLING_ADDRESS_ID",
                "CREATED_AT", "UPDATED_AT", "LAST_ACTIVITY_AT", "EXPIRES_AT"
        ));

        put("SHOPPING_CART_ITEMS", Arrays.asList(
                "ID", "CART_ID", "PRODUCT_ID", "VARIANT_ID",
                "QUANTITY", "UNIT_PRICE", "LINE_TOTAL",
                "PRODUCT_NAME", "PRODUCT_SLUG", "VARIANT_NAME", "VARIANT_SKU",
                "COLOR_NAME", "SIZE_NAME", "MATERIAL", "PRIMARY_IMAGE_URL",
                "DISCOUNT_AMOUNT", "DISCOUNT_TYPE", "DISCOUNT_REASON",
                "AVAILABILITY_CHECKED_AT", "IS_AVAILABLE", "AVAILABILITY_MESSAGE",
                "ADDED_AT", "UPDATED_AT"
        ));

        put("WISHLISTS", Arrays.asList(
                "ID", "CUSTOMER_ID", "NAME", "DESCRIPTION",
                "IS_PUBLIC", "IS_DEFAULT",
                "SHARE_TOKEN",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("WISHLIST_ITEMS", Arrays.asList(
                "ID", "WISHLIST_ID", "PRODUCT_ID", "VARIANT_ID",
                "QUANTITY", "PRIORITY",
                "PRODUCT_NAME", "PRODUCT_SLUG", "VARIANT_NAME", "VARIANT_SKU", "SAVED_PRICE",
                "NOTES",
                "ADDED_AT", "UPDATED_AT"
        ));

        // Promotions
        put("COUPONS", Arrays.asList(
                "ID", "CODE", "NAME", "DESCRIPTION",
                "DISCOUNT_TYPE", "DISCOUNT_VALUE",
                "USAGE_LIMIT", "USAGE_LIMIT_PER_CUSTOMER", "USAGE_COUNT",
                "MINIMUM_ORDER_AMOUNT", "MAXIMUM_DISCOUNT_AMOUNT",
                "STARTS_AT", "EXPIRES_AT",
                "IS_ACTIVE",
                "CREATED_AT", "UPDATED_AT"
        ));

        put("COUPON_USAGE", Arrays.asList(
                "ID", "COUPON_ID", "CUSTOMER_ID", "ORDER_ID",
                "DISCOUNT_AMOUNT", "ORDER_AMOUNT",
                "USED_AT"
        ));

        // Audit & Security
        put("AUDIT_LOG", Arrays.asList(
                "ID", "TABLE_NAME", "OPERATION_TYPE", "RECORD_ID",
                "OLD_VALUES", "NEW_VALUES",
                "CHANGED_BY", "CHANGED_AT",
                "IP_ADDRESS", "USER_AGENT"
        ));

        put("EMAIL_VERIFICATION_TOKENS", Arrays.asList(
                "ID", "CUSTOMER_ID", "TOKEN", "EMAIL",
                "EXPIRES_AT", "VERIFIED_AT", "CREATED_AT"
        ));

        put("PASSWORD_RESET_TOKENS", Arrays.asList(
                "ID", "CUSTOMER_ID", "TOKEN",
                "EXPIRES_AT", "USED_AT", "CREATED_AT",
                "IP_ADDRESS"
        ));
    }};
}
