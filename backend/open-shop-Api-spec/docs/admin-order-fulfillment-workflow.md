# Admin Order Fulfillment Workflow Documentation

This document outlines the complete order management workflow for administrators of the Open Shop e-commerce platform, covering order fulfillment operations, status management, and customer service processes.

## Overview

The admin order management system provides comprehensive tools for:
- Order processing and fulfillment
- Status tracking and updates
- Customer communication
- Inventory coordination
- Shipping integration

## Order Status Lifecycle

Orders progress through the following status states:
- **pending** → Order created, payment pending
- **confirmed** → Payment confirmed, ready for processing
- **processing** → Order being prepared for shipment
- **shipped** → Order dispatched with tracking information
- **delivered** → Order successfully delivered to customer
- **cancelled** → Order cancelled (can occur at any stage)

## 1. Order Management Dashboard

### List All Orders

**Endpoint:** `GET /admin/orders`

**Request Example:**
```http
GET /admin/orders?status=pending&page=1&limit=20&sort=createdAt:desc
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "orders": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0m1",
      "orderNumber": "ORD-2024-000123",
      "customer": {
        "id": "507f1f77bcf86cd799439011",
        "email": "john.doe@example.com",
        "firstName": "John",
        "lastName": "Doe"
      },
      "status": "pending",
      "totalAmount": 317.76,
      "currency": "USD",
      "itemCount": 2,
      "createdAt": "2024-01-22T10:30:00Z",
      "paymentStatus": "requires_payment"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "totalItems": 156,
    "totalPages": 8,
    "hasNextPage": true,
    "hasPreviousPage": false
  },
  "summary": {
    "totalOrders": 1250,
    "totalRevenue": 187450.50,
    "pendingCount": 23,
    "processingCount": 45,
    "shippedCount": 67
  }
}
```

### Filter Orders

**Common Filtering Options:**
- `status=pending` - New orders requiring attention
- `status=processing` - Orders being fulfilled
- `status=shipped` - Orders in transit
- `fromDate=2024-01-01&toDate=2024-01-31` - Date range filtering
- `customerId=507f1f77bcf86cd799439011` - Customer-specific orders
- `search=john.doe@example.com` - Text search across customer details

## 2. Order Detail Management

### Get Order Details

**Endpoint:** `GET /admin/orders/{id}`

**Request Example:**
```http
GET /admin/orders/65f1a2b3c4d5e6f7g8h9i0m1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "orderNumber": "ORD-2024-000123",
    "status": "pending",
    "customer": {
      "id": "507f1f77bcf86cd799439011",
      "email": "john.doe@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "phone": "+1234567890",
      "orderCount": 5,
      "totalSpent": 1247.89
    },
    "items": [
      {
        "id": "item_001",
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "productName": "Wireless Bluetooth Headphones",
        "productSku": "WBH-001-BK",
        "productImage": "https://images.openshop.com/products/headphones-main.jpg",
        "quantity": 2,
        "unitPrice": 129.99,
        "totalPrice": 259.98,
        "stockAvailable": 43
      }
    ],
    "summary": {
      "subtotal": 284.97,
      "taxAmount": 22.80,
      "shippingAmount": 9.99,
      "discountAmount": 15.00,
      "totalAmount": 302.76,
      "currency": "USD"
    },
    "shippingAddress": {
      "fullName": "John Doe",
      "addressLine1": "123 Main Street",
      "addressLine2": "Apt 4B",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "US",
      "phone": "+1234567890"
    },
    "paymentInfo": {
      "provider": "stripe",
      "method": "card",
      "status": "requires_payment",
      "amount": 302.76,
      "currency": "USD",
      "lastFour": "4242"
    },
    "timeline": [
      {
        "status": "pending",
        "timestamp": "2024-01-22T10:30:00Z",
        "description": "Order created",
        "actor": "customer"
      }
    ],
    "createdAt": "2024-01-22T10:30:00Z",
    "updatedAt": "2024-01-22T10:30:00Z"
  }
}
```

## 3. Order Processing Workflow

### Step 1: Review New Orders

**Daily Process:**
1. Filter orders by `status=pending`
2. Review payment status
3. Check inventory availability
4. Verify shipping address

### Step 2: Confirm and Process Orders

**Update Order Status to Process:**

**Endpoint:** `PUT /admin/orders/{id}`

**Request Example:**
```http
PUT /admin/orders/65f1a2b3c4d5e6f7g8h9i0m1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "status": "processing",
  "adminNotes": "Order verified and ready for fulfillment",
  "expectedShipDate": "2024-01-23T00:00:00Z"
}
```

**Response Example:**
```json
{
  "message": "Order status updated successfully",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "status": "processing",
    "expectedShipDate": "2024-01-23T00:00:00Z",
    "updatedAt": "2024-01-22T14:30:00Z"
  },
  "notifications": {
    "customerNotified": true,
    "emailSent": true
  }
}
```

### Step 3: Fulfill and Ship Orders

**Update to Shipped Status:**

**Request Example:**
```http
PUT /admin/orders/65f1a2b3c4d5e6f7g8h9i0m1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "status": "shipped",
  "shippingInfo": {
    "carrier": "FedEx",
    "service": "Ground",
    "trackingNumber": "1234567890123456",
    "shippedAt": "2024-01-23T16:00:00Z",
    "estimatedDelivery": "2024-01-25T18:00:00Z"
  },
  "adminNotes": "Shipped via FedEx Ground"
}
```

**Response Example:**
```json
{
  "message": "Order marked as shipped successfully",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "status": "shipped",
    "shippingInfo": {
      "carrier": "FedEx",
      "service": "Ground",
      "trackingNumber": "1234567890123456",
      "trackingUrl": "https://www.fedex.com/apps/fedextrack/?tracknumbers=1234567890123456",
      "shippedAt": "2024-01-23T16:00:00Z",
      "estimatedDelivery": "2024-01-25T18:00:00Z"
    },
    "updatedAt": "2024-01-23T16:00:00Z"
  },
  "notifications": {
    "customerNotified": true,
    "trackingEmailSent": true
  }
}
```

## 4. Order Cancellation Workflow

### Customer-Requested Cancellation

**Endpoint:** `POST /orders/{id}/cancel`

**Admin Approval Process:**

**Request Example:**
```http
PUT /admin/orders/65f1a2b3c4d5e6f7g8h9i0m1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "status": "cancelled",
  "cancellationReason": "Customer request - address change needed",
  "refundInfo": {
    "amount": 302.76,
    "method": "original_payment",
    "processRefund": true
  },
  "restockInventory": true,
  "adminNotes": "Cancelled per customer request on phone"
}
```

**Response Example:**
```json
{
  "message": "Order cancelled successfully",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "status": "cancelled",
    "cancellationReason": "Customer request - address change needed",
    "cancelledAt": "2024-01-22T15:45:00Z"
  },
  "refund": {
    "id": "ref_12345",
    "amount": 302.76,
    "status": "processing",
    "estimatedCompletion": "2024-01-24T15:45:00Z"
  },
  "inventory": {
    "restocked": true,
    "itemsAffected": 2
  }
}
```

## 5. Order Analytics and Reporting

### Get Order Statistics

**Endpoint:** `GET /admin/orders/stats`

**Request Example:**
```http
GET /admin/orders/stats?period=30days&groupBy=status
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
    "totalOrders": 1250,
    "totalRevenue": 187450.50,
    "averageOrderValue": 149.96,
    "completedOrders": 1180,
    "cancelledOrders": 45,
    "cancellationRate": 3.6
  },
  "statusBreakdown": {
    "pending": 23,
    "processing": 45,
    "shipped": 67,
    "delivered": 1070,
    "cancelled": 45
  },
  "dailyTrends": [
    {
      "date": "2024-01-01",
      "orders": 42,
      "revenue": 6247.89
    }
  ]
}
```

## 6. Common Administrative Tasks

### Bulk Status Updates

**Process Multiple Orders:**
```http
PUT /admin/orders/bulk-update
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "orderIds": [
    "65f1a2b3c4d5e6f7g8h9i0m1",
    "65f1a2b3c4d5e6f7g8h9i0m2"
  ],
  "updates": {
    "status": "processing",
    "expectedShipDate": "2024-01-23T00:00:00Z"
  }
}
```

### Export Orders

**Generate Reports:**
```http
GET /admin/orders/export?format=csv&fromDate=2024-01-01&toDate=2024-01-31
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## 7. Integration Workflows

### Shipping Carrier Integration

**Webhook for Delivery Confirmation:**
```json
{
  "eventType": "package.delivered",
  "trackingNumber": "1234567890123456",
  "orderId": "65f1a2b3c4d5e6f7g8h9i0m1",
  "deliveredAt": "2024-01-25T14:30:00Z",
  "signedBy": "John Doe"
}
```

### Inventory System Integration

**Automatic Stock Updates:**
- Order confirmed → Reserve inventory
- Order shipped → Deduct from available stock  
- Order cancelled → Release reserved inventory

## Best Practices

1. **Daily Order Review**: Check pending orders every morning
2. **Status Updates**: Update order status promptly to maintain customer trust
3. **Communication**: Use admin notes for internal tracking
4. **Inventory Monitoring**: Verify stock before confirming orders
5. **Exception Handling**: Document unusual situations for future reference

## Error Handling

**Common Order Management Errors:**

**Insufficient Stock:**
```json
{
  "error": "INSUFFICIENT_STOCK",
  "message": "Cannot process order - product out of stock",
  "details": {
    "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
    "requested": 5,
    "available": 2
  }
}
```

**Invalid Status Transition:**
```json
{
  "error": "INVALID_STATUS_TRANSITION",
  "message": "Cannot change status from 'delivered' to 'processing'",
  "allowedTransitions": ["delivered"]
}
```