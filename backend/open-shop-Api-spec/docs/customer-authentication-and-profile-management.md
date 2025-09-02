# Customer Workflow Documentation

This document outlines the complete customer authentication workflow for the Open Shop e-commerce platform, including signup, login, and profile management.

## Overview

The customer authentication system supports multiple flows:
- Traditional email/password registration and login
- OAuth-based social authentication (Google, Facebook, LinkedIn)
- Email verification and password reset
- Profile management and updates

## 1. Customer Registration (Signup)

### Basic Email/Password Registration

**Endpoint:** `POST /auth/register`

**Flow:**
1. Customer provides registration details
2. System validates email uniqueness
3. Password is hashed and stored
4. Email verification is sent
5. Customer account is created in pending state

**Request Example:**
```http
POST /auth/register
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com",
  "password": "SecurePassword123!",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "dateOfBirth": "1990-05-15"
}
```

**Response Example:**
```json
{
  "message": "Registration successful. Please check your email for verification.",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "dateOfBirth": "1990-05-15",
    "isEmailVerified": false,
    "createdAt": "2024-01-22T10:30:00Z"
  },
  "emailVerificationSent": true,
  "timestamp": "2024-01-22T10:30:00Z"
}
```

### OAuth Registration

**Endpoints:**
- Google: `POST /auth/oauth/google`
- Facebook: `POST /auth/oauth/facebook`
- LinkedIn: `POST /auth/oauth/linkedin`

**Flow:**
1. Customer initiates OAuth with provider
2. Provider redirects with authorization code
3. System exchanges code for user profile
4. Account is created or linked
5. JWT tokens are issued

**Request Example (Google):**
```http
POST /auth/oauth/google
Content-Type: application/json
```

```json
{
  "code": "4/0AX4XfWj...",
  "redirectUri": "https://mystore.com/auth/callback"
}
```

**Response Example:**
```json
{
  "message": "OAuth authentication successful",
  "customer": {
    "id": "507f1f77bcf86cd799439012",
    "email": "john.doe@gmail.com",
    "firstName": "John",
    "lastName": "Doe",
    "isEmailVerified": true,
    "oauthProviders": ["google"],
    "createdAt": "2024-01-22T10:30:00Z"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresAt": "2024-01-22T11:30:00Z"
  }
}
```

## 2. Email Verification

### Send Verification Email

**Endpoint:** `POST /auth/email/send-verification`

**Request Example:**
```http
POST /auth/email/send-verification
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com"
}
```

**Response Example:**
```json
{
  "message": "Verification email sent successfully",
  "emailSent": true,
  "expiresAt": "2024-01-22T11:30:00Z"
}
```

### Verify Email

**Endpoint:** `POST /auth/email/verify`

**Request Example:**
```http
POST /auth/email/verify
Content-Type: application/json
```

```json
{
  "token": "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
}
```

**Response Example:**
```json
{
  "message": "Email verified successfully",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "isEmailVerified": true,
    "verifiedAt": "2024-01-22T10:45:00Z"
  }
}
```

## 3. Customer Login

### Email/Password Login

**Endpoint:** `POST /auth/login`

**Flow:**
1. Customer provides email and password
2. System validates credentials
3. JWT access and refresh tokens are issued
4. Customer profile is returned

**Request Example:**
```http
POST /auth/login
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com",
  "password": "SecurePassword123!"
}
```

**Response Example:**
```json
{
  "message": "Login successful",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "isEmailVerified": true,
    "addresses": [
      {
        "id": "addr_123",
        "type": "shipping",
        "isDefault": true,
        "fullName": "John Doe",
        "addressLine1": "123 Main Street",
        "city": "New York",
        "state": "NY",
        "postalCode": "10001",
        "country": "US"
      }
    ],
    "lastLoginAt": "2024-01-22T10:30:00Z"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresAt": "2024-01-22T11:30:00Z"
  }
}
```

## 4. Token Management

### Refresh Access Token

**Endpoint:** `POST /auth/token/refresh`

**Request Example:**
```http
POST /auth/token/refresh
Content-Type: application/json
```

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response Example:**
```json
{
  "message": "Token refreshed successfully",
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresAt": "2024-01-22T12:30:00Z"
  }
}
```

### Logout

**Endpoint:** `POST /auth/logout`

**Request Example:**
```http
POST /auth/logout
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response Example:**
```json
{
  "message": "Logged out successfully",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

## 5. Password Reset

### Request Password Reset

**Endpoint:** `POST /auth/password/forgot`

**Request Example:**
```http
POST /auth/password/forgot
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com"
}
```

**Response Example:**
```json
{
  "message": "Password reset email sent",
  "emailSent": true,
  "expiresAt": "2024-01-22T11:30:00Z"
}
```

### Reset Password

**Endpoint:** `POST /auth/password/reset`

**Request Example:**
```http
POST /auth/password/reset
Content-Type: application/json
```

```json
{
  "token": "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz",
  "newPassword": "NewSecurePassword123!"
}
```

**Response Example:**
```json
{
  "message": "Password reset successful",
  "passwordResetAt": "2024-01-22T10:45:00Z"
}
```

## 6. Profile Management

### Get Profile

**Endpoint:** `GET /profile`

**Request Example:**
```http
GET /profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response Example:**
```json
{
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "dateOfBirth": "1990-05-15",
    "isEmailVerified": true,
    "preferences": {
      "emailNotifications": true,
      "smsNotifications": false,
      "currency": "USD",
      "language": "en"
    },
    "addresses": [
      {
        "id": "addr_123",
        "type": "shipping",
        "fullName": "John Doe",
        "addressLine1": "123 Main Street",
        "addressLine2": "Apt 4B",
        "city": "New York",
        "state": "NY",
        "postalCode": "10001",
        "country": "US",
        "phone": "+1234567890",
        "isDefault": true,
        "isValidated": true,
        "createdAt": "2024-01-20T08:00:00Z",
        "updatedAt": "2024-01-22T10:30:00Z"
      }
    ],
    "createdAt": "2024-01-22T10:30:00Z",
    "updatedAt": "2024-01-22T10:30:00Z"
  }
}
```

### Update Profile

**Endpoint:** `PUT /profile`

**Request Example:**
```http
PUT /profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "firstName": "Jonathan",
  "lastName": "Doe",
  "phone": "+1234567891",
  "preferences": {
    "emailNotifications": false,
    "smsNotifications": true,
    "currency": "USD",
    "language": "en"
  }
}
```

**Response Example:**
```json
{
  "message": "Profile updated successfully",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "Jonathan",
    "lastName": "Doe",
    "phone": "+1234567891",
    "preferences": {
      "emailNotifications": false,
      "smsNotifications": true,
      "currency": "USD",
      "language": "en"
    },
    "updatedAt": "2024-01-22T10:45:00Z"
  }
}
```

## Complete Registration & Login Flow

### New Customer Journey
1. **Register** → `POST /auth/register`
2. **Verify Email** → `POST /auth/email/verify`
3. **Login** → `POST /auth/login`
4. **Update Profile** → `PUT /profile` (optional)

### Returning Customer Journey
1. **Login** → `POST /auth/login`
2. **Refresh Token** → `POST /auth/token/refresh` (when needed)
3. **Logout** → `POST /auth/logout`

### Error Handling

Common error responses:

**400 Bad Request:**
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Invalid email format",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**401 Unauthorized:**
```json
{
  "error": "INVALID_CREDENTIALS",
  "message": "Invalid email or password",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**409 Conflict:**
```json
{
  "error": "EMAIL_ALREADY_EXISTS",
  "message": "An account with this email already exists",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

## Security Considerations

- All passwords are hashed using secure algorithms
- JWT tokens have short expiration times
- Refresh tokens are rotated on each use
- Rate limiting is applied to prevent brute force attacks
- Email verification is required for account activation
- OAuth tokens are securely validated with providers