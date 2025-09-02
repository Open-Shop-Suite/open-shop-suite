# Complete Order Placement Workflow Documentation

This document outlines the complete order placement workflow for the Open Shop e-commerce platform, from cart management through payment processing and order confirmation.

## Overview

The order placement system handles the full e-commerce checkout flow:
- Shopping cart management with real-time updates
- Address management for shipping and billing
- Payment method selection and processing
- Order creation with payment intent generation
- Payment confirmation and order completion
- Order tracking and status management

## 1. Shopping Cart Management

### Add Items to Cart

**Endpoint:** `POST /cart/items`

**Flow:**
1. Customer selects product variant
2. Item is added to cart with quantity
3. Cart totals are recalculated
4. Inventory is reserved temporarily

**Request Example:**
```http
POST /cart/items
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
  "variantId": "var_001",
  "quantity": 2
}
```

**Response Example:**
```json
{
  "message": "Item added to cart successfully",
  "cartItem": {
    "id": "cart_item_123",
    "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
    "productName": "Premium Wireless Bluetooth Headphones",
    "productSlug": "premium-wireless-bluetooth-headphones",
    "productImage": "https://images.openshop.com/products/headphones-main.jpg",
    "variantId": "var_001",
    "variant": {
      "sku": "ATP-WH-001-BLK",
      "colorway": {
        "name": "Midnight Black",
        "hex": "#000000"
      },
      "size": "Standard"
    },
    "quantity": 2,
    "unitPrice": 199.99,
    "totalPrice": 399.98,
    "addedAt": "2024-01-22T10:30:00Z"
  },
  "cartSummary": {
    "itemCount": 3,
    "subtotal": 659.97,
    "tax": 52.80,
    "shipping": 9.99,
    "total": 722.76,
    "currency": "USD"
  }
}
```

### Get Cart Contents

**Endpoint:** `GET /cart`

**Request Example:**
```http
GET /cart
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "cart": {
    "id": "cart_507f1f77bcf86cd799439011",
    "customerId": "507f1f77bcf86cd799439011",
    "items": [
      {
        "id": "cart_item_123",
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "productName": "Premium Wireless Bluetooth Headphones",
        "productImage": "https://images.openshop.com/products/headphones-main.jpg",
        "variantId": "var_001",
        "variant": {
          "sku": "ATP-WH-001-BLK",
          "colorway": {"name": "Midnight Black", "hex": "#000000"},
          "size": "Standard"
        },
        "quantity": 2,
        "unitPrice": 199.99,
        "totalPrice": 399.98,
        "isInStock": true,
        "maxQuantity": 15
      },
      {
        "id": "cart_item_124",
        "productId": "65f1a2b3c4d5e6f7g8h9i0j2",
        "productName": "Smartphone Case",
        "productImage": "https://images.openshop.com/products/case-main.jpg",
        "variantId": "var_003",
        "variant": {
          "sku": "SC-001-BLU",
          "colorway": {"name": "Ocean Blue", "hex": "#0066CC"},
          "size": "iPhone 14"
        },
        "quantity": 1,
        "unitPrice": 24.99,
        "totalPrice": 24.99,
        "isInStock": true,
        "maxQuantity": 50
      }
    ],
    "summary": {
      "itemCount": 3,
      "subtotal": 424.97,
      "tax": 33.98,
      "shipping": 9.99,
      "discount": 0.00,
      "total": 468.94,
      "currency": "USD"
    },
    "expiresAt": "2024-01-22T12:30:00Z",
    "createdAt": "2024-01-22T10:00:00Z",
    "updatedAt": "2024-01-22T10:30:00Z"
  }
}
```

### Update Cart Item

**Endpoint:** `PUT /cart/items/{itemId}`

**Request Example:**
```http
PUT /cart/items/cart_item_123
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "quantity": 1
}
```

**Response Example:**
```json
{
  "message": "Cart item updated successfully",
  "cartItem": {
    "id": "cart_item_123",
    "quantity": 1,
    "unitPrice": 199.99,
    "totalPrice": 199.99,
    "updatedAt": "2024-01-22T10:35:00Z"
  },
  "cartSummary": {
    "itemCount": 2,
    "subtotal": 224.98,
    "tax": 18.00,
    "shipping": 9.99,
    "total": 252.97,
    "currency": "USD"
  }
}
```

## 2. Address Management

> **Note**: Address management is handled through the customer profile (`/profile`) or passed directly during order creation. Standalone address endpoints are not implemented in the current API specification.

### Address Information Structure

**Address fields for order creation:**

**Address Structure:**
```json
{
  "fullName": "John Doe",
  "addressLine1": "123 Main Street",
  "addressLine2": "Apt 4B",
  "city": "New York", 
  "state": "NY",
  "postalCode": "10001",
  "country": "US",
  "phone": "+1234567890"
}
```

This address structure is used in:
- Order creation requests (`shippingAddress` and `billingAddress` fields)
- Customer profile management via `GET /profile` and `PUT /profile` endpoints
- Stored addresses are returned in the customer profile's `addresses` array

## 3. Order Creation with Payment Intent

### Create Order

**Endpoint:** `POST /orders`

**Flow:**
1. Cart contents are validated
2. Shipping and billing addresses are verified
3. Payment method is processed
4. Payment intent is created with provider
5. Order is created in pending status
6. Payment details are returned for client-side completion

**Request Example:**
```http
POST /orders
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
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
  "billingAddress": {
    "fullName": "John Doe",
    "addressLine1": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10001",
    "country": "US"
  },
  "paymentMethod": "stripe"
}
```

**Response Example:**
```json
{
  "message": "Order created successfully. Complete payment to confirm.",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "orderNumber": "ORD-2024-000123",
    "customerId": "507f1f77bcf86cd799439011",
    "status": "pending",
    "items": [
      {
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "productName": "Premium Wireless Bluetooth Headphones",
        "productImage": "https://images.openshop.com/products/headphones-main.jpg",
        "variantId": "var_001",
        "quantity": 1,
        "unitPrice": 199.99,
        "totalPrice": 199.99
      }
    ],
    "summary": {
      "itemCount": 1,
      "subtotal": 199.99,
      "tax": 16.00,
      "shipping": 9.99,
      "discount": 0.00,
      "total": 225.98,
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
    "billingAddress": {
      "fullName": "John Doe",
      "addressLine1": "123 Main Street",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "US"
    },
    "paymentInfo": {
      "provider": "stripe",
      "amount": 225.98,
      "currency": "USD",
      "status": "requires_payment",
      "providerAdditionalInfo": {
        "paymentIntentId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
        "clientSecret": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P_secret_abc123def456",
        "publishableKey": "pk_test_abc123def456"
      }
    },
    "shippingInfo": {
      "carrier": "ups",
      "service": "ground",
      "status": "pending",
      "estimatedDelivery": "2024-01-29T18:00:00Z",
      "providerAdditionalInfo": {
        "serviceCode": "03"
      }
    },
    "notes": "Please leave package at front door",
    "createdAt": "2024-01-22T10:45:00Z",
    "updatedAt": "2024-01-22T10:45:00Z"
  },
  "paymentInfo": {
    "provider": "stripe",
    "amount": 225.98,
    "currency": "USD",
    "status": "requires_payment",
    "expiresAt": "2024-01-22T11:45:00Z",
    "providerAdditionalInfo": {
      "paymentIntentId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
      "clientSecret": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P_secret_abc123def456",
      "publishableKey": "pk_test_abc123def456"
    }
  },
  "timestamp": "2024-01-22T10:45:00Z"
}
```

### PayPal Order Creation

**Request Example:**
```http
POST /orders
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
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
  "billingAddress": {
    "fullName": "John Doe",
    "addressLine1": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "postalCode": "10001",
    "country": "US",
    "phone": "+1234567890"
  },
  "paymentMethod": "paypal"
}
```

**Response Example:**
```json
{
  "message": "Order created successfully. Complete payment to confirm.",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m2",
    "orderNumber": "ORD-2024-000124",
    "customerId": "507f1f77bcf86cd799439011",
    "status": "pending",
    "items": [
      {
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "productName": "Wireless Bluetooth Headphones",
        "productImage": "https://images.openshop.com/products/headphones-main.jpg",
        "quantity": 2,
        "unitPrice": 129.99,
        "totalPrice": 259.98
      },
      {
        "productId": "65f1a2b3c4d5e6f7g8h9i0j2",
        "productName": "Smartphone Case",
        "productImage": "https://images.openshop.com/products/case-main.jpg",
        "quantity": 1,
        "unitPrice": 24.99,
        "totalPrice": 24.99
      }
    ],
    "summary": {
      "subtotal": 284.97,
      "taxAmount": 22.80,
      "shippingAmount": 9.99,
      "discountAmount": 0.00,
      "totalAmount": 317.76,
      "currency": "USD"
    }
  },
  "paymentInfo": {
    "provider": "paypal",
    "amount": 225.98,
    "currency": "USD",
    "status": "requires_payment",
    "expiresAt": "2024-01-22T11:45:00Z",
    "providerAdditionalInfo": {
      "orderId": "8XH12345678901234",
      "approvalUrl": "https://www.paypal.com/checkoutnow?token=8XH12345678901234",
      "accessToken": "A21AALcE7XFh9dGrR8dVqHb..."
    }
  },
  "timestamp": "2024-01-22T10:45:00Z"
}
```

## 4. Payment Confirmation

### Confirm Payment

**Endpoint:** `POST /orders/{id}/payment/confirm`

**Flow:**
1. Client-side payment is completed using provider SDK
2. Payment confirmation is sent to server
3. Payment status is verified with provider
4. Order status is updated
5. Inventory is decremented
6. Cart is cleared
7. Confirmation email is sent

**Stripe Payment Confirmation:**
```http
POST /orders/65f1a2b3c4d5e6f7g8h9i0m1/payment/confirm
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "provider": "stripe",
  "transactionId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
  "amount": 225.98,
  "currency": "USD",
  "paymentMethod": "credit_card",
  "paymentMeta": {
    "payment_method": "pm_1MqxDr2eZvKYlo2C0J8yQZ7P",
    "last4": "4242",
    "brand": "visa",
    "exp_month": 12,
    "exp_year": 2025
  }
}
```

**Response Example:**
```json
{
  "message": "Payment confirmed successfully",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "orderNumber": "ORD-2024-000123",
    "status": "confirmed",
    "paymentInfo": {
      "provider": "stripe",
      "amount": 225.98,
      "currency": "USD",
      "status": "paid",
      "providerAdditionalInfo": {
        "paymentIntentId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
        "clientSecret": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P_secret_abc123def456"
      }
    },
    "transactionId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
    "paidAt": "2024-01-22T10:50:00Z",
    "shippingInfo": {
      "carrier": "ups",
      "service": "ground",
      "status": "processing",
      "estimatedDelivery": "2024-01-29T18:00:00Z",
      "providerAdditionalInfo": {
        "trackingNumber": "1Z999AA1234567890",
        "serviceCode": "03"
      }
    },
    "updatedAt": "2024-01-22T10:50:00Z"
  },
  "cartCleared": true,
  "emailSent": true,
  "timestamp": "2024-01-22T10:50:00Z"
}
```

## 5. Order Tracking

### Get Order Details

**Endpoint:** `GET /orders/{id}`

**Request Example:**
```http
GET /orders/65f1a2b3c4d5e6f7g8h9i0m1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "orderNumber": "ORD-2024-000123",
    "customerId": "507f1f77bcf86cd799439011",
    "status": "shipped",
    "items": [
      {
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "productName": "Wireless Bluetooth Headphones",
        "productImage": "https://images.openshop.com/products/headphones-main.jpg",
        "quantity": 1,
        "unitPrice": 129.99,
        "totalPrice": 129.99
      }
    ],
    "summary": {
      "subtotal": 129.99,
      "taxAmount": 10.40,
      "shippingAmount": 9.99,
      "discountAmount": 0.00,
      "totalAmount": 150.38,
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
    "billingAddress": {
      "fullName": "John Doe",
      "addressLine1": "123 Main Street",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "US",
      "phone": "+1234567890"
    },
    "paymentInfo": {
      "provider": "stripe",
      "amount": 225.98,
      "currency": "USD",
      "status": "paid"
    },
    "transactionId": "pi_3MqxDr2eZvKYlo2C0J8yQZ7P",
    "paidAt": "2024-01-22T10:50:00Z",
    "shippingInfo": {
      "carrier": "ups",
      "service": "ground",
      "status": "in_transit",
      "estimatedDelivery": "2024-01-29T18:00:00Z",
      "shippedAt": "2024-01-24T09:15:00Z",
      "providerAdditionalInfo": {
        "trackingNumber": "1Z999AA1234567890",
        "serviceCode": "03"
      }
    },
    "notes": "Please leave package at front door",
    "createdAt": "2024-01-22T10:45:00Z",
    "updatedAt": "2024-01-24T09:15:00Z"
  }
}
```

### Get Customer Orders

**Endpoint:** `GET /orders`

**Request Example:**
```http
GET /orders?status=shipped&page=1&limit=10&sort=newest
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "orders": [
    {
      "id": "65f1a2b3c4d5e6f7g8h9i0m1",
      "orderNumber": "ORD-2024-000123",
      "status": "shipped",
      "items": [
        {
          "productName": "Premium Wireless Bluetooth Headphones",
          "quantity": 1,
          "unitPrice": 199.99
        }
      ],
      "summary": {
        "total": 225.98,
        "currency": "USD"
      },
      "paymentInfo": {
        "provider": "stripe",
        "status": "paid"
      },
      "shippingInfo": {
        "carrier": "ups",
        "status": "in_transit",
        "estimatedDelivery": "2024-01-29T18:00:00Z",
        "providerAdditionalInfo": {
          "trackingNumber": "1Z999AA1234567890"
        }
      },
      "createdAt": "2024-01-22T10:45:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "totalItems": 5,
    "totalPages": 1,
    "hasNextPage": false
  }
}
```

## 6. Order Cancellation

### Cancel Order

**Endpoint:** `POST /orders/{id}/cancel`

**Request Example:**
```http
POST /orders/65f1a2b3c4d5e6f7g8h9i0m1/cancel
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "message": "Order cancelled successfully",
  "order": {
    "id": "65f1a2b3c4d5e6f7g8h9i0m1",
    "orderNumber": "ORD-2024-000123",
    "status": "cancelled",
    "cancelledAt": "2024-01-22T11:00:00Z"
  }
}
```

## Complete Order Placement Flow

### Standard Checkout Journey

1. **Browse & Add to Cart** → `POST /cart/items`
2. **Review Cart** → `GET /cart`
3. **Provide Addresses** → Included in order creation request
4. **Create Order** → `POST /orders` (creates payment intent)
5. **Complete Payment** (client-side using provider SDK)
6. **Confirm Payment** → `POST /orders/{id}/payment/confirm`
7. **Track Order** → `GET /orders/{id}`

### Guest Checkout Journey

1. **Add Items to Cart** (session-based)
2. **Provide Shipping Details** (no account creation)
3. **Create Order with Guest Info** → `POST /orders`
4. **Complete Payment**
5. **Email Order Confirmation** (with tracking link)

### Client-Side Payment Integration

**Stripe Payment Flow:**
```javascript
// After order creation
const { paymentInfo } = orderResponse;
const stripe = Stripe(paymentInfo.providerAdditionalInfo.publishableKey);

// Confirm payment with client secret
const result = await stripe.confirmCardPayment(
  paymentInfo.providerAdditionalInfo.clientSecret,
  {
    payment_method: {
      card: cardElement,
      billing_details: { name: 'John Doe' }
    }
  }
);

// Confirm with backend
if (result.paymentIntent.status === 'succeeded') {
  await confirmPayment(orderId, {
    provider: 'stripe',
    transactionId: result.paymentIntent.id,
    amount: result.paymentIntent.amount / 100,
    currency: result.paymentIntent.currency
  });
}
```

**PayPal Payment Flow:**
```javascript
// After order creation
const { paymentInfo } = orderResponse;

// Redirect to PayPal
window.location.href = paymentInfo.providerAdditionalInfo.approvalUrl;

// After PayPal redirect back
await confirmPayment(orderId, {
  provider: 'paypal',
  transactionId: urlParams.get('PayerID'),
  amount: paymentInfo.amount,
  currency: paymentInfo.currency
});
```

## Error Handling

### Common Errors

**400 Bad Request - Empty Cart:**
```json
{
  "error": "EMPTY_CART",
  "message": "Cannot create order from empty cart",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**400 Bad Request - Out of Stock:**
```json
{
  "error": "INSUFFICIENT_INVENTORY",
  "message": "One or more items are out of stock",
  "details": {
    "outOfStockItems": [
      {
        "productId": "65f1a2b3c4d5e6f7g8h9i0j1",
        "variantId": "var_001",
        "requested": 5,
        "available": 2
      }
    ]
  },
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**402 Payment Required:**
```json
{
  "error": "PAYMENT_FAILED",
  "message": "Payment could not be processed",
  "details": {
    "providerError": "Your card was declined",
    "errorCode": "card_declined"
  },
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**409 Conflict - Order Already Paid:**
```json
{
  "error": "ORDER_ALREADY_PAID",
  "message": "This order has already been paid",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

## Order States & Transitions

```
pending → confirmed → processing → shipped → delivered
   ↓         ↓           ↓          ↓
cancelled cancelled  cancelled  returned
```

**Status Descriptions:**
- `pending` - Order created, awaiting payment
- `confirmed` - Payment successful, order confirmed  
- `processing` - Order being prepared for shipment
- `shipped` - Order shipped, tracking available
- `delivered` - Order delivered to customer
- `cancelled` - Order cancelled (before shipping)
- `returned` - Order returned by customer

## Best Practices

1. **Inventory Management:** Reserve inventory during cart session, release on timeout
2. **Payment Security:** Use provider SDKs, never handle card details directly
3. **Order Timing:** Set appropriate timeouts for payment completion
4. **Error Recovery:** Provide clear error messages and recovery paths
5. **Email Notifications:** Send confirmations, updates, and tracking info
6. **Analytics:** Track conversion rates, abandonment points, and payment success rates