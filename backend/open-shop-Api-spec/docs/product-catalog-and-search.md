# Product Search Workflow Documentation

This document outlines the complete product search and discovery workflow for the Open Shop e-commerce platform, including search, filtering, categorization, and product details retrieval.

## Overview

The product search system provides comprehensive discovery capabilities:
- Text-based product search with relevance scoring
- Category-based browsing and navigation
- Advanced filtering by price, attributes, ratings, and availability
- Sorting by relevance, price, popularity, and ratings
- Product detail views with variants and reviews
- Related product recommendations

## 1. Product Search

### Basic Text Search

**Endpoint:** `GET /products/search`

**Flow:**
1. Customer enters search query
2. System performs full-text search across product data
3. Results are ranked by relevance
4. Pagination and filtering options are applied

**Request Example:**
```http
GET /products/search?q=wireless%20headphones&page=1&limit=20
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "products": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "name": "Premium Wireless Bluetooth Headphones",
      "brand": "AudioTech",
      "slug": "premium-wireless-bluetooth-headphones",
      "description": "High-quality wireless headphones with noise cancellation",
      "shortDescription": "Premium wireless headphones with active noise cancellation and 30-hour battery life.",
      "price": {
        "min": 199.99,
        "max": 249.99,
        "currency": "USD"
      },
      "images": [
        {
          "url": "https://images.openshop.com/products/headphones-main.jpg",
          "alt": "Premium Wireless Headphones - Main View",
          "isPrimary": true
        }
      ],
      "avgRating": 4.5,
      "reviewCount": 128,
      "isInStock": true,
      "tags": ["wireless", "bluetooth", "noise-cancelling"],
      "createdAt": "2024-01-15T09:00:00Z"
    },
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j2",
      "name": "Budget Wireless Earbuds",
      "brand": "SoundMax",
      "slug": "budget-wireless-earbuds",
      "description": "Affordable wireless earbuds with good sound quality",
      "shortDescription": "Compact wireless earbuds with 6-hour battery and charging case.",
      "price": {
        "min": 49.99,
        "max": 49.99,
        "currency": "USD"
      },
      "images": [
        {
          "url": "https://images.openshop.com/products/earbuds-main.jpg",
          "alt": "Budget Wireless Earbuds - Main View",
          "isPrimary": true
        }
      ],
      "avgRating": 4.2,
      "reviewCount": 89,
      "isInStock": true,
      "tags": ["wireless", "bluetooth", "earbuds", "budget"],
      "createdAt": "2024-01-10T14:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 45,
    "totalPages": 3,
    "hasNextPage": true,
    "hasPreviousPage": false
  },
  "searchInfo": {
    "query": "wireless headphones",
    "searchTime": 23,
    "totalResults": 45,
    "suggestions": ["bluetooth headphones", "noise cancelling headphones", "gaming headphones"]
  }
}
```

### Advanced Search with Filters

**Request Example:**
```http
GET /products/search?q=headphones&category=electronics&priceMin=50&priceMax=300&brand=AudioTech,SoundMax&rating=4&inStock=true&sort=price_asc&page=1&limit=12
```

**Query Parameters:**
- `q` - Search query text
- `category` - Category slug or ID
- `priceMin`, `priceMax` - Price range filter
- `brand` - Brand filter (comma-separated)
- `rating` - Minimum rating filter (1-5)
- `inStock` - Show only in-stock items
- `sort` - Sorting option (relevance, price_asc, price_desc, rating, newest, popularity)
- `page`, `limit` - Pagination

**Response Example:**
```json
{
  "products": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "name": "Wireless Bluetooth Headphones",
      "description": "High-quality wireless headphones with noise cancellation",
      "price": 129.99,
      "currency": "USD",
      "category": {
        "id": "65f1a2b3c4d5e6f7g8h9i0a1",
        "name": "Electronics",
        "slug": "electronics"
      },
      "images": [
        {
          "url": "https://images.openshop.com/products/headphones-main.jpg",
          "alt": "Wireless headphones main view",
          "isPrimary": true
        }
      ],
      "inStock": true,
      "rating": 4.5,
      "reviewCount": 128
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 2,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false
  },
  "searchInfo": {
    "query": "headphones",
    "appliedFilters": {
      "category": "electronics",
      "priceRange": {"min": 50, "max": 300},
      "brands": ["AudioTech", "SoundMax"],
      "minRating": 4,
      "inStock": true
    },
    "availableFilters": {
      "brands": [
        {"name": "AudioTech", "count": 12},
        {"name": "SoundMax", "count": 8},
        {"name": "BassPro", "count": 5}
      ],
      "priceRanges": [
        {"range": "0-50", "count": 8},
        {"range": "50-100", "count": 15},
        {"range": "100-200", "count": 18},
        {"range": "200+", "count": 4}
      ],
      "ratings": [
        {"rating": 5, "count": 12},
        {"rating": 4, "count": 25},
        {"rating": 3, "count": 8}
      ]
    }
  }
}
```

## 2. Category-Based Browsing

### Get All Categories

**Endpoint:** `GET /categories`

**Request Example:**
```http
GET /categories?includeProducts=true
```

**Response Example:**
```json
{
  "categories": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0k1",
      "name": "Electronics",
      "slug": "electronics",
      "description": "Electronic devices and accessories",
      "image": "https://images.openshop.com/categories/electronics.jpg",
      "parentId": null,
      "level": 0,
      "productCount": 245,
      "isActive": true,
      "children": [
        {
          "id": "65f1a2b3c4d5e6f7g8h9i0k2",
          "name": "Audio & Headphones",
          "slug": "audio-headphones",
          "productCount": 67,
          "children": [
            {
              "id": "65f1a2b3c4d5e6f7g8h9i0k3",
              "name": "Wireless Headphones",
              "slug": "wireless-headphones",
              "productCount": 23
            }
          ]
        }
      ]
    }
  ]
}
```

### Browse Products by Category

**Endpoint:** `GET /products`

**Request Example:**
```http
GET /products?category=wireless-headphones&sort=popularity&page=1&limit=20
```

**Response Example:**
```json
{
  "products": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "name": "Wireless Bluetooth Headphones",
      "description": "High-quality wireless headphones with noise cancellation",
      "price": 129.99,
      "currency": "USD",
      "category": {
        "id": "65f1a2b3c4d5e6f7g8h9i0a1",
        "name": "Electronics",
        "slug": "electronics"
      },
      "images": [
        {
          "url": "https://images.openshop.com/products/headphones-main.jpg",
          "alt": "Wireless headphones main view",
          "isPrimary": true
        }
      ],
      "inStock": true,
      "rating": 4.5,
      "reviewCount": 128
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 2,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false
  },
  "category": {
    "id": "65f1a2b3c4d5e6f7g8h9i0k3",
    "name": "Wireless Headphones",
    "slug": "wireless-headphones",
    "breadcrumbs": [
      {"name": "Electronics", "slug": "electronics"},
      {"name": "Audio & Headphones", "slug": "audio-headphones"},
      {"name": "Wireless Headphones", "slug": "wireless-headphones"}
    ]
  },
  "availableFilters": {
    "categories": [
      {"id": "electronics", "name": "Electronics", "count": 45},
      {"id": "accessories", "name": "Accessories", "count": 23}
    ],
    "priceRanges": [
      {"min": 0, "max": 50, "count": 12},
      {"min": 50, "max": 200, "count": 34}
    ],
    "brands": [
      {"name": "AudioTech", "count": 15},
      {"name": "SoundMax", "count": 8}
    ]
  }
}
```

## 3. Product Details

### Get Single Product

**Endpoint:** `GET /products/{id}`

**Request Example:**
```http
GET /products/65f1a2b3c4d5e6f7g8h9i0j1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "product": {
    "id": "65f1a2b3c4d5e6f7g8h9i0j1",
    "name": "Premium Wireless Bluetooth Headphones",
    "brand": "AudioTech",
    "slug": "premium-wireless-bluetooth-headphones",
    "description": "Experience premium audio quality with our flagship wireless headphones featuring active noise cancellation, premium materials, and industry-leading battery life.",
    "shortDescription": "Premium wireless headphones with active noise cancellation and 30-hour battery life.",
    "specifications": {
      "Driver Size": "40mm",
      "Frequency Response": "20Hz - 20kHz",
      "Battery Life": "30 hours",
      "Charging Time": "2 hours",
      "Weight": "250g",
      "Connectivity": "Bluetooth 5.0",
      "Noise Cancellation": "Active",
      "Warranty": "2 years"
    },
    "features": [
      "Active Noise Cancellation",
      "30-hour battery life",
      "Premium leather ear cushions",
      "Touch controls",
      "Voice assistant compatibility",
      "Foldable design"
    ],
    "images": [
      {
        "url": "https://images.openshop.com/products/headphones-main.jpg",
        "alt": "Premium Wireless Headphones - Main View",
        "isPrimary": true
      },
      {
        "url": "https://images.openshop.com/products/headphones-side.jpg",
        "alt": "Premium Wireless Headphones - Side View",
        "isPrimary": false
      }
    ],
    "variants": [
      {
        "id": "var_001",
        "sku": "ATP-WH-001-BLK",
        "colorway": {
          "name": "Midnight Black",
          "hex": "#000000",
          "family": "black",
          "code": "BLK"
        },
        "size": "Standard",
        "price": 199.99,
        "compareAtPrice": 249.99,
        "isInStock": true,
        "inventory": 15,
        "images": [
          "https://images.openshop.com/products/headphones-black-1.jpg",
          "https://images.openshop.com/products/headphones-black-2.jpg"
        ]
      },
      {
        "id": "var_002",
        "sku": "ATP-WH-001-WHT",
        "colorway": {
          "name": "Pearl White",
          "hex": "#FFFFFF",
          "family": "white",
          "code": "WHT"
        },
        "size": "Standard",
        "price": 209.99,
        "compareAtPrice": 249.99,
        "isInStock": true,
        "inventory": 8,
        "images": [
          "https://images.openshop.com/products/headphones-white-1.jpg"
        ]
      }
    ],
    "price": {
      "min": 199.99,
      "max": 209.99,
      "currency": "USD"
    },
    "dimensions": {
      "length": 18.5,
      "width": 15.2,
      "height": 8.3,
      "weight": 250,
      "unit": "cm"
    },
    "category": {
      "id": "65f1a2b3c4d5e6f7g8h9i0k3",
      "name": "Wireless Headphones",
      "slug": "wireless-headphones"
    },
    "tags": ["wireless", "bluetooth", "noise-cancelling", "premium"],
    "avgRating": 4.5,
    "reviewCount": 128,
    "reviewSummary": {
      "5": 75,
      "4": 35,
      "3": 12,
      "2": 4,
      "1": 2
    },
    "seoTitle": "Premium Wireless Bluetooth Headphones - AudioTech",
    "seoDescription": "Shop premium wireless Bluetooth headphones with noise cancellation. Free shipping and 2-year warranty.",
    "isInStock": true,
    "isActive": true,
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-20T14:30:00Z"
  },
  "relatedProducts": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j3",
      "name": "Wireless Charging Pad",
      "price": {"min": 29.99, "max": 29.99, "currency": "USD"},
      "images": [{"url": "https://images.openshop.com/products/charging-pad-main.jpg", "isPrimary": true}],
      "avgRating": 4.3
    }
  ]
}
```

## 4. Product Reviews

### Get Product Reviews

**Endpoint:** `GET /products/{id}/reviews`

**Request Example:**
```http
GET /products/65f1a2b3c4d5e6f7g8h9i0j1/reviews?page=1&limit=10&sort=newest
```

**Response Example:**
```json
{
  "reviews": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0r1",
      "customerId": "507f1f77bcf86cd799439011",
      "customerName": "John D.",
      "rating": 5,
      "title": "Excellent sound quality!",
      "comment": "These headphones exceeded my expectations. The noise cancellation is amazing and the battery life is as advertised. Highly recommend!",
      "pros": ["Great sound quality", "Long battery life", "Comfortable fit"],
      "cons": ["Slightly heavy"],
      "verified": true,
      "helpful": 23,
      "images": [
        "https://images.openshop.com/reviews/review-img-1.jpg"
      ],
      "createdAt": "2024-01-20T14:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "totalItems": 128,
    "totalPages": 13,
    "hasNextPage": true
  },
  "reviewSummary": {
    "avgRating": 4.5,
    "totalReviews": 128,
    "ratingDistribution": {
      "5": 75,
      "4": 35,
      "3": 12,
      "2": 4,
      "1": 2
    }
  }
}
```

## 5. Search Suggestions & Autocomplete

### Get Search Suggestions

**Endpoint:** `GET /products/search/suggestions`

**Request Example:**
```http
GET /products/search/suggestions?q=wire
```

**Response Example:**
```json
{
  "suggestions": [
    {
      "type": "query",
      "text": "wireless headphones",
      "count": 45
    },
    {
      "type": "query",
      "text": "wired headphones",
      "count": 23
    },
    {
      "type": "product",
      "text": "Premium Wireless Bluetooth Headphones",
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "price": 199.99,
      "image": "https://images.openshop.com/products/headphones-thumb.jpg"
    },
    {
      "type": "category",
      "text": "Wireless Headphones",
      "slug": "wireless-headphones",
      "count": 23
    },
    {
      "type": "brand",
      "text": "Wireless Pro",
      "count": 12
    }
  ]
}
```

## 6. Wishlist Integration

### Add Product to Wishlist

**Endpoint:** `POST /wishlist/items`

**Request Example:**
```http
POST /wishlist/items
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
  "variantId": "var_001"
}
```

**Response Example:**
```json
{
  "message": "Product added to wishlist successfully",
  "wishlistItem": {
    "id": "wish_123",
    "product": {
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "name": "Premium Wireless Bluetooth Headphones",
      "price": {"min": 199.99, "max": 209.99, "currency": "USD"},
      "images": [{"url": "...", "isPrimary": true}]
    },
    "variant": {
      "id": "var_001",
      "colorway": {"name": "Midnight Black", "hex": "#000000"},
      "price": 199.99
    },
    "addedAt": "2024-01-22T10:30:00Z"
  }
}
```

## Complete Product Discovery Flow

### Customer Search Journey

1. **Browse Categories** → `GET /categories`
2. **Search Products** → `GET /products/search?q=headphones`
3. **Apply Filters** → `GET /products/search?q=headphones&priceMax=200&brand=AudioTech`
4. **View Product Details** → `GET /products/{id}`
5. **Read Reviews** → `GET /products/{id}/reviews`
6. **Add to Wishlist** → `POST /wishlist/items` (optional)
7. **Add to Cart** → `POST /cart/items`

### Search Performance Optimization

**Request with Performance Headers:**
```http
GET /products/search?q=wireless%20headphones
X-Cache-Control: max-age=300
X-Search-Timeout: 5000
```

**Response with Performance Metrics:**
```json
{
  "products": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0j1",
      "name": "Wireless Bluetooth Headphones",
      "description": "High-quality wireless headphones with noise cancellation",
      "price": 129.99,
      "currency": "USD",
      "category": {
        "id": "65f1a2b3c4d5e6f7g8h9i0a1",
        "name": "Electronics",
        "slug": "electronics"
      },
      "images": [
        {
          "url": "https://images.openshop.com/products/headphones-main.jpg",
          "alt": "Wireless headphones main view",
          "isPrimary": true
        }
      ],
      "inStock": true,
      "rating": 4.5,
      "reviewCount": 128
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 2,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false
  },
  "searchInfo": {
    "searchTime": 23,
    "cached": false,
    "indexVersion": "v2.1.0"
  }
}
```

### Error Handling

**400 Bad Request:**
```json
{
  "error": "INVALID_SEARCH_QUERY",
  "message": "Search query must be at least 2 characters long",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**404 Not Found:**
```json
{
  "error": "PRODUCT_NOT_FOUND",
  "message": "Product with ID 65f1a2b3c4d5e6f7g8h9i0j1 not found",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**429 Too Many Requests:**
```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many search requests. Please try again in 60 seconds.",
  "retryAfter": 60,
  "timestamp": "2024-01-22T10:30:00Z"
}
```

## Search Best Practices

1. **Implement Autocomplete:** Use the suggestions endpoint for real-time search suggestions
2. **Cache Results:** Cache popular search queries and category browsing
3. **Progressive Loading:** Load basic product info first, then details on demand
4. **Filter State Management:** Maintain filter state in URL for bookmarking/sharing
5. **Error Boundaries:** Handle network failures gracefully with offline support
6. **Analytics Tracking:** Track search queries, clicks, and conversion rates