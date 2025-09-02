# Admin Inventory Management Workflow Documentation

This document outlines the comprehensive inventory management workflows for administrators of the Open Shop e-commerce platform, covering stock monitoring, adjustments, analytics, and operational processes.

## Overview

The admin inventory management system provides tools for:
- Real-time stock level monitoring
- Inventory adjustments and bulk updates
- Low stock alerts and notifications  
- Stock movement tracking and audit trails
- Supplier management and analytics
- Automated inventory alerts

## 1. Inventory Dashboard

### List All Inventory Items

**Endpoint:** `GET /admin/inventory`

**Request Example:**
```http
GET /admin/inventory?page=1&limit=20&lowStock=true&sort=stockQuantity:asc
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "inventory": [
    {
      "id": "507f1f77bcf86cd799439013",
      "name": "Premium Wireless Headphones",
      "sku": "AWH-001",
      "brand": "AudioTech",
      "category": {
        "id": "cat_electronics_001",
        "name": "Electronics"
      },
      "variants": [
        {
          "id": "var_001",
          "sku": "AWH-001-BLK",
          "colorway": {
            "name": "Midnight Black",
            "hex": "#000000"
          },
          "price": 299.99,
          "compareAtPrice": 349.99,
          "costOfGoods": 150.00,
          "inventory": {
            "stockQuantity": 5,
            "committedQuantity": 3,
            "availableQuantity": 2,
            "minimumThreshold": 10,
            "maximumThreshold": 100,
            "reorderPoint": 15,
            "reorderQuantity": 50
          },
          "supplier": {
            "id": "sup_001",
            "name": "AudioTech Manufacturing",
            "leadTimeDays": 14
          },
          "locations": [
            {
              "warehouse": "WH-001",
              "quantity": 5,
              "reserved": 3
            }
          ],
          "lastStockUpdate": "2024-01-22T10:30:00Z"
        }
      ],
      "totalStock": 5,
      "totalAvailable": 2,
      "isLowStock": true,
      "status": "active"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 145,
    "totalPages": 8,
    "hasNextPage": true,
    "hasPreviousPage": false
  },
  "summary": {
    "totalProducts": 245,
    "lowStockCount": 23,
    "outOfStockCount": 8,
    "totalValue": 1247890.50
  }
}
```

### Filter Inventory

**Common Filtering Options:**
- `lowStock=true` - Products below minimum threshold
- `outOfStock=true` - Products with zero stock
- `categoryId=cat_electronics_001` - Filter by category
- `supplierId=sup_001` - Filter by supplier
- `status=inactive` - Filter by product status

## 2. Individual Product Inventory

### Get Product Inventory Details

**Endpoint:** `GET /admin/inventory/{id}`

**Request Example:**
```http
GET /admin/inventory/507f1f77bcf86cd799439013
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "product": {
    "id": "507f1f77bcf86cd799439013",
    "name": "Premium Wireless Headphones",
    "sku": "AWH-001",
    "brand": "AudioTech",
    "category": {
      "id": "cat_electronics_001",
      "name": "Electronics",
      "slug": "electronics"
    },
    "variants": [
      {
        "id": "var_001",
        "sku": "AWH-001-BLK",
        "colorway": {
          "name": "Midnight Black",
          "hex": "#000000"
        },
        "inventory": {
          "stockQuantity": 5,
          "committedQuantity": 3,
          "availableQuantity": 2,
          "minimumThreshold": 10,
          "maximumThreshold": 100,
          "reorderPoint": 15,
          "reorderQuantity": 50,
          "averageDailySales": 2.5,
          "daysOfStock": 2,
          "turnoverRate": 12.5
        },
        "financials": {
          "costOfGoods": 150.00,
          "sellingPrice": 299.99,
          "margin": 49.92,
          "totalValue": 750.00
        },
        "supplier": {
          "id": "sup_001",
          "name": "AudioTech Manufacturing",
          "contactEmail": "orders@audiotech.com",
          "leadTimeDays": 14,
          "minimumOrderQuantity": 25
        },
        "locations": [
          {
            "warehouse": "WH-001",
            "name": "Main Warehouse",
            "quantity": 3,
            "reserved": 2,
            "available": 1
          },
          {
            "warehouse": "WH-002", 
            "name": "Regional Warehouse",
            "quantity": 2,
            "reserved": 1,
            "available": 1
          }
        ]
      }
    ],
    "alerts": [
      {
        "type": "low_stock",
        "severity": "high",
        "message": "Stock level (5) is below minimum threshold (10)",
        "createdAt": "2024-01-22T08:00:00Z"
      }
    ],
    "recentMovements": [
      {
        "id": "mov_001",
        "type": "sale",
        "quantity": -2,
        "reason": "Order fulfillment",
        "orderId": "ORD-2024-000123",
        "timestamp": "2024-01-22T10:30:00Z",
        "performedBy": "system"
      }
    ]
  }
}
```

## 3. Stock Adjustments

### Manual Stock Adjustment

**Endpoint:** `POST /admin/inventory/{id}/adjust`

**Request Example:**
```http
POST /admin/inventory/507f1f77bcf86cd799439013/adjust
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "variantId": "var_001",
  "adjustmentType": "restock",
  "quantity": 50,
  "reason": "New shipment received from supplier",
  "referenceNumber": "PO-2024-001",
  "costPerUnit": 150.00,
  "notes": "Shipment arrived ahead of schedule",
  "warehouse": "WH-001"
}
```

**Response Example:**
```json
{
  "message": "Inventory adjusted successfully",
  "adjustment": {
    "id": "adj_001",
    "productId": "507f1f77bcf86cd799439013",
    "variantId": "var_001",
    "adjustmentType": "restock",
    "quantity": 50,
    "previousStock": 5,
    "newStock": 55,
    "reason": "New shipment received from supplier",
    "referenceNumber": "PO-2024-001",
    "costPerUnit": 150.00,
    "totalCost": 7500.00,
    "performedBy": "admin_001",
    "timestamp": "2024-01-22T14:30:00Z"
  },
  "updatedInventory": {
    "stockQuantity": 55,
    "availableQuantity": 52,
    "totalValue": 8250.00
  },
  "alerts": {
    "lowStockResolved": true,
    "newAlerts": []
  }
}
```

### Bulk Inventory Updates

**Endpoint:** `POST /admin/inventory/bulk-update`

**Request Example:**
```http
POST /admin/inventory/bulk-update
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "updates": [
    {
      "productId": "507f1f77bcf86cd799439013",
      "variantId": "var_001",
      "adjustmentType": "adjustment",
      "quantity": 10,
      "reason": "Physical count correction"
    },
    {
      "productId": "507f1f77bcf86cd799439014", 
      "variantId": "var_002",
      "adjustmentType": "damage",
      "quantity": -3,
      "reason": "Damaged in transit"
    }
  ],
  "notes": "Monthly inventory reconciliation",
  "referenceNumber": "INV-2024-001"
}
```

**Response Example:**
```json
{
  "message": "Bulk inventory update completed",
  "summary": {
    "totalUpdates": 2,
    "successful": 2,
    "failed": 0,
    "totalValueChange": 1050.00
  },
  "results": [
    {
      "productId": "507f1f77bcf86cd799439013",
      "status": "success",
      "previousStock": 55,
      "newStock": 65
    },
    {
      "productId": "507f1f77bcf86cd799439014",
      "status": "success", 
      "previousStock": 23,
      "newStock": 20
    }
  ],
  "timestamp": "2024-01-22T15:00:00Z"
}
```

## 4. Low Stock Management

### Get Low Stock Items

**Endpoint:** `GET /admin/inventory/low-stock`

**Request Example:**
```http
GET /admin/inventory/low-stock?severity=critical&sort=daysOfStock:asc
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "products": [
    {
      "id": "507f1f77bcf86cd799439013",
      "name": "Premium Wireless Headphones",
      "sku": "AWH-001-BLK",
      "currentStock": 2,
      "minimumThreshold": 10,
      "reorderPoint": 15,
      "recommendedReorder": 50,
      "daysOfStock": 0.8,
      "averageDailySales": 2.5,
      "severity": "critical",
      "supplier": {
        "name": "AudioTech Manufacturing",
        "leadTimeDays": 14
      },
      "estimatedStockoutDate": "2024-01-23T18:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 23,
    "totalPages": 2,
    "hasNextPage": true,
    "hasPreviousPage": false
  },
  "summary": {
    "criticalCount": 8,
    "lowCount": 15,
    "totalAffectedValue": 45670.00,
    "estimatedReorderCost": 125000.00
  }
}
```

### Generate Purchase Orders

**Create Suggested Purchase Orders:**
```http
POST /admin/inventory/generate-purchase-orders
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "supplierId": "sup_001",
  "includeProducts": [
    "507f1f77bcf86cd799439013",
    "507f1f77bcf86cd799439014"
  ],
  "urgencyLevel": "standard"
}
```

## 5. Stock Movement Tracking

### Get Stock History

**Endpoint:** `GET /admin/inventory/{id}/history`

**Request Example:**
```http
GET /admin/inventory/507f1f77bcf86cd799439013/history?page=1&limit=50&fromDate=2024-01-01
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "productId": "507f1f77bcf86cd799439013",
  "movements": [
    {
      "id": "mov_001",
      "type": "sale",
      "quantity": -2,
      "runningBalance": 5,
      "reason": "Order fulfillment",
      "orderId": "ORD-2024-000123",
      "customerId": "507f1f77bcf86cd799439011",
      "unitCost": 150.00,
      "totalValue": -300.00,
      "warehouse": "WH-001",
      "performedBy": "system",
      "timestamp": "2024-01-22T10:30:00Z"
    },
    {
      "id": "mov_002",
      "type": "adjustment",
      "quantity": 7,
      "runningBalance": 7,
      "reason": "Physical count correction",
      "referenceNumber": "ADJ-2024-001",
      "unitCost": 150.00,
      "totalValue": 1050.00,
      "warehouse": "WH-001",
      "performedBy": "admin_001",
      "timestamp": "2024-01-21T15:00:00Z"
    },
    {
      "id": "mov_003",
      "type": "restock",
      "quantity": 100,
      "runningBalance": 100,
      "reason": "Initial stock",
      "referenceNumber": "PO-2024-001", 
      "unitCost": 150.00,
      "totalValue": 15000.00,
      "warehouse": "WH-001",
      "performedBy": "admin_001",
      "timestamp": "2024-01-15T09:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "totalItems": 25,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false
  },
  "summary": {
    "totalMovements": 25,
    "totalInbound": 107,
    "totalOutbound": -102,
    "netMovement": 5,
    "valueChange": 750.00
  }
}
```

## 6. Inventory Alerts and Notifications

### Get Active Alerts

**Endpoint:** `GET /admin/inventory/alerts`

**Request Example:**
```http
GET /admin/inventory/alerts?status=active&severity=high
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "alerts": [
    {
      "id": "alert_001",
      "productId": "507f1f77bcf86cd799439013",
      "productName": "Premium Wireless Headphones",
      "sku": "AWH-001-BLK",
      "alertType": "low_stock",
      "severity": "critical",
      "message": "Stock level (2) is critically low - immediate reorder required",
      "currentStock": 2,
      "minimumThreshold": 10,
      "recommendedAction": "Reorder 50 units immediately",
      "estimatedStockoutDate": "2024-01-23T18:00:00Z",
      "supplier": {
        "id": "sup_001",
        "name": "AudioTech Manufacturing",
        "leadTimeDays": 14
      },
      "createdAt": "2024-01-22T08:00:00Z",
      "acknowledged": false,
      "status": "active"
    },
    {
      "id": "alert_002",
      "productId": "507f1f77bcf86cd799439015",
      "productName": "Smart Phone Case",
      "sku": "SPC-001-RED",
      "alertType": "overstock",
      "severity": "medium",
      "message": "Stock level (450) exceeds maximum threshold (200)",
      "currentStock": 450,
      "maximumThreshold": 200,
      "recommendedAction": "Consider promotional pricing or bundle deals",
      "daysOfStock": 180,
      "createdAt": "2024-01-21T12:00:00Z",
      "acknowledged": false,
      "status": "active"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 12,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false
  },
  "summary": {
    "totalAlerts": 12,
    "criticalCount": 3,
    "highCount": 5,
    "mediumCount": 4
  }
}
```

### Acknowledge Alerts

**Mark Alert as Acknowledged:**
```http
PUT /admin/inventory/alerts/alert_001
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "acknowledged": true,
  "notes": "Purchase order PO-2024-002 created for 50 units",
  "actionTaken": "reorder_initiated"
}
```

## 7. Inventory Analytics

### Get Inventory Performance

**Endpoint:** `GET /admin/inventory/analytics`

**Request Example:**
```http
GET /admin/inventory/analytics?period=30days&metrics=turnover,profitability&categoryId=cat_electronics_001
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "period": {
    "start": "2024-01-01T00:00:00Z",
    "end": "2024-01-31T23:59:59Z"
  },
  "summary": {
    "totalProducts": 245,
    "totalValue": 1247890.50,
    "averageTurnover": 8.5,
    "fastMoving": 23,
    "slowMoving": 45,
    "deadStock": 8
  },
  "topPerformers": [
    {
      "productId": "507f1f77bcf86cd799439013",
      "name": "Premium Wireless Headphones",
      "sku": "AWH-001",
      "unitsSold": 125,
      "revenue": 37487.50,
      "profit": 18743.75,
      "turnoverRate": 15.6,
      "profitMargin": 49.92
    }
  ],
  "underPerformers": [
    {
      "productId": "507f1f77bcf86cd799439020",
      "name": "Basic Wired Earphones",
      "sku": "BWE-001",
      "unitsSold": 3,
      "revenue": 59.97,
      "profit": 11.97,
      "turnoverRate": 0.3,
      "daysInStock": 180
    }
  ],
  "categoryBreakdown": [
    {
      "categoryId": "cat_electronics_001",
      "categoryName": "Electronics",
      "totalValue": 567890.25,
      "turnoverRate": 12.3,
      "profitMargin": 42.5
    }
  ]
}
```

## 8. Automated Workflows

### Reorder Point System

**Automatic Purchase Order Generation:**
```json
{
  "triggers": [
    {
      "condition": "stock_below_reorder_point",
      "action": "create_purchase_order",
      "parameters": {
        "quantity": "reorder_quantity",
        "urgent": true
      }
    }
  ]
}
```

### Stock Alerts Configuration

**Set Alert Thresholds:**
```http
PUT /admin/inventory/507f1f77bcf86cd799439013/thresholds
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "variantId": "var_001",
  "minimumThreshold": 15,
  "maximumThreshold": 200,
  "reorderPoint": 25,
  "reorderQuantity": 75,
  "alertSettings": {
    "lowStockAlert": true,
    "overstockAlert": true,
    "emailNotifications": true,
    "urgentThreshold": 5
  }
}
```

## 9. Common Administrative Tasks

### Daily Inventory Checklist

1. **Review Low Stock Alerts**: Check critical and high-priority alerts
2. **Process Adjustments**: Handle damaged goods, returns, and corrections  
3. **Update Thresholds**: Adjust reorder points based on sales velocity
4. **Review Analytics**: Monitor turnover rates and identify trends
5. **Supplier Communication**: Follow up on pending purchase orders

### Weekly Inventory Tasks

1. **Physical Count Verification**: Spot-check high-value items
2. **Dead Stock Review**: Identify slow-moving inventory
3. **Supplier Performance**: Evaluate delivery times and quality
4. **Pricing Analysis**: Review margins and competitive positioning

### Monthly Inventory Operations

1. **Full Category Review**: Analyze performance by product category
2. **Forecasting Updates**: Adjust demand predictions
3. **Supplier Negotiations**: Review contracts and pricing
4. **System Optimization**: Update automation rules and thresholds

## Best Practices

1. **Real-time Monitoring**: Check inventory dashboard multiple times daily
2. **Proactive Reordering**: Don't wait for stockouts before reordering
3. **Accurate Record Keeping**: Document all adjustments with clear reasons
4. **Regular Audits**: Perform periodic physical counts
5. **Data-Driven Decisions**: Use analytics to optimize stock levels