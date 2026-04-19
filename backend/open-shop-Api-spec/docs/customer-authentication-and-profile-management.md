# Customer Authentication & Profile Management

This document describes the complete customer authentication and profile management workflow for the Open Shop e-commerce platform.

## Overview

The authentication system supports:
- Email/password registration and login (immediately issues JWT tokens on signup)
- OAuth social login (Google, Facebook, LinkedIn) via a two-step authorize → callback flow
- Email verification and password reset
- Session management across multiple devices
- Profile updates and account deletion
- Address book management

**Token strategy:**
- Access token expires in **15 minutes** (`expiresIn: 900`)
- Refresh token expires in **7 days** and rotates on every use
- **Web clients** receive the refresh token in an HTTP-only cookie (`Set-Cookie`); omit it from request bodies and rely on the cookie
- **Mobile/desktop clients** receive the refresh token in the response body and must include it in refresh requests

---

## 1. Customer Registration (Signup)

### Email/Password Signup

**Endpoint:** `POST /auth/signup`

The customer is immediately authenticated after successful signup. A verification email is dispatched but is not required to receive tokens — `emailVerified` will be `false` until the email is confirmed.

Rate limited to **5 attempts per minute per IP**.

**Request:**
```http
POST /auth/signup
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com",
  "password": "MySecureP@ssw0rd",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "dateOfBirth": "1990-05-15"
}
```

Required fields: `email`, `password`, `firstName`, `lastName`. `phone` and `dateOfBirth` are optional.

**Response `201 Created`:**
```json
{
  "message": "Account created successfully and user authenticated. Please verify your email for full activation.",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "sessionId": "507f1f77bcf86cd799439055",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "dateOfBirth": "1990-05-15",
    "emailVerified": false,
    "createdAt": "2024-01-22T10:30:00Z",
    "updatedAt": "2024-01-22T10:30:00Z"
  },
  "emailVerificationSent": true,
  "timestamp": "2024-01-22T10:30:00Z"
}
```

The response also sets an HTTP-only `refreshToken` cookie for web clients.

**Error responses:**
- `409 Conflict` — email already registered

---

## 2. Email Verification

### Verify Email Address

**Endpoint:** `POST /auth/verify-email`

Rate limited to **10 attempts per hour per token**.

```json
{
  "token": "verify123token456"
}
```

**Response `200 OK`:**
```json
{
  "message": "Email address verified successfully. Your account is now active.",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `401 Unauthorized` — invalid or expired token
- `409 Conflict` — email already verified

### Resend Verification Email

**Endpoint:** `POST /auth/resend-verification`

Rate limited to **3 attempts per hour per email**.

```json
{
  "email": "john.doe@example.com"
}
```

**Response `200 OK`:**
```json
{
  "message": "Verification email sent successfully. Please check your inbox.",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**Error responses:**
- `404 Not Found` — customer account not found
- `409 Conflict` — email already verified

---

## 3. Customer Login

### Email/Password Login

**Endpoint:** `POST /auth/login`

Rate limited to **10 attempts per minute per IP**.

**Request:**
```http
POST /auth/login
Content-Type: application/json
```

```json
{
  "email": "john.doe@example.com",
  "password": "MySecureP@ssw0rd",
  "rememberMe": false
}
```

`rememberMe` is optional (default `false`); setting it to `true` extends the session duration.

**Response `200 OK`:**
```json
{
  "message": "Login successful",
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "sessionId": "507f1f77bcf86cd799439066",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "dateOfBirth": "1990-05-15",
    "emailVerified": true,
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
  "timestamp": "2024-01-22T10:30:00Z"
}
```

Also sets an HTTP-only `refreshToken` cookie for web clients.

**Error responses:**
- `401 Unauthorized` — invalid credentials

> For social login use `GET /auth/oauth/{provider}/authorize` instead.

---

## 4. OAuth Social Login

OAuth uses a two-step flow: first obtain an authorization URL from the server, redirect the user to the provider, then exchange the resulting code for tokens.

Supported providers: `google`, `facebook`, `LinkedIn`

### Step 1 — Get Authorization URL

**Endpoint:** `GET /auth/oauth/{provider}/authorize?channel=<channel>`

The client declares its platform via `channel`. The server resolves the correct registered redirect URI for the current environment (dev/staging/prod) internally — clients never need to know or hardcode URIs.

`channel` enum: `web`, `mobile_ios`, `mobile_android`, `desktop`

Rate limited to **20 attempts per minute per IP**.

**Example:**
```http
GET /auth/oauth/google/authorize?channel=web
```

**Response `200 OK`:**
```json
{
  "authorizationUrl": "https://accounts.google.com/o/oauth2/v2/auth?client_id=xxx&redirect_uri=https%3A%2F%2Fmystore.com%2Fauth%2Fcallback&response_type=code&scope=openid+email+profile&state=csrf_abc123xyz789&access_type=offline",
  "state": "csrf_abc123xyz789",
  "provider": "google",
  "expiresAt": "2024-01-15T10:45:00Z",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

The client **must persist** the `state` value and verify it on callback to prevent CSRF attacks. Then redirect the user to `authorizationUrl`.

**Error responses:**
- `400 Bad Request` — invalid provider or unknown `channel`

### Step 2 — Exchange Code for Tokens (Callback)

**Endpoint:** `POST /auth/oauth/{provider}/callback`

Called by the client after the provider redirects back. The client extracts `code` and `state` from the redirect URL and posts them here. The server uses the `state` to look up the original `channel` and resolves the redirect URI internally — the client does not send it. This endpoint creates a new account if none exists, or logs in the existing one — no separate register/login endpoints are needed for OAuth.

Rate limited to **20 attempts per minute per IP**.

**Request:**
```json
{
  "code": "4/0AX4XfWjGl1...",
  "state": "csrf_abc123xyz789"
}
```

**Response `200 OK` — new account created:**
```json
{
  "message": "Account created successfully via Google OAuth.",
  "isNewUser": true,
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "sessionId": "507f1f77bcf86cd799439055",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@gmail.com",
    "firstName": "John",
    "lastName": "Doe",
    "emailVerified": true,
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

`isNewUser: false` when an existing account is logged in.

Also sets an HTTP-only `refreshToken` cookie for web clients.

**Error responses:**
- `400 Bad Request` — user denied access or provider returned an error
- `401 Unauthorized` — invalid or expired `state` (CSRF check failed)
- `502 Bad Gateway` — OAuth provider unreachable or returned an error

---

## 5. Token Management

### Refresh Access Token

**Endpoint:** `POST /auth/refresh`

Implements **token rotation** — both the access token and refresh token are replaced on every call.

Rate limited to **20 attempts per minute per user**.

**Web clients:** omit the body — the server reads the HTTP-only cookie and sets a new one automatically.

**Mobile/desktop clients:** include `refreshToken` in the body.

**Request (mobile/desktop):**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response `200 OK`:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "timestamp": "2024-01-22T12:30:00Z"
}
```

**Error responses:**
- `401 Unauthorized` — invalid or expired refresh token

### Logout

**Endpoint:** `POST /auth/logout`

Revokes the current session only. Other device sessions remain active. Also clears the HTTP-only refresh token cookie for web clients.

```http
POST /auth/logout
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response `200 OK`:**
```json
{
  "message": "Logged out successfully",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `401 Unauthorized` — missing or invalid access token

---

## 6. Session Management

### List Active Sessions

**Endpoint:** `GET /auth/sessions`

Returns all active sessions across all devices. The current session is identified by `isCurrent: true`.

```http
GET /auth/sessions
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response `200 OK`:**
```json
{
  "sessions": [
    {
      "id": "507f1f77bcf86cd799439077",
      "deviceType": "web",
      "deviceName": "Chrome on macOS",
      "ipAddress": "203.0.113.42",
      "location": "New York, US",
      "createdAt": "2024-01-22T10:30:00Z",
      "lastActiveAt": "2024-01-22T10:45:00Z",
      "expiresAt": "2024-01-29T10:30:00Z",
      "isCurrent": true
    }
  ],
  "timestamp": "2024-01-22T10:45:00Z"
}
```

### Revoke All Other Sessions

**Endpoint:** `DELETE /auth/sessions`

Signs out all other devices while keeping the current session active ("sign out all other devices").

**Response `200 OK`:**
```json
{
  "message": "All other sessions have been revoked",
  "revokedCount": 3,
  "timestamp": "2024-01-22T10:45:00Z"
}
```

### Revoke a Specific Session

**Endpoint:** `DELETE /auth/sessions/{id}`

Revokes any session belonging to the authenticated user. If the revoked session is the current one, the response also clears the HTTP-only cookie (equivalent to logging out).

**Response `200 OK`:**
```json
{
  "message": "Session revoked successfully",
  "sessionId": "507f1f77bcf86cd799439077",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `404 Not Found` — session not found

---

## 7. Password Management

### Forgot Password

**Endpoint:** `POST /auth/password/forgot`

Sends a password reset email. Rate limited to **3 attempts per hour per email**.

```json
{
  "email": "john.doe@example.com"
}
```

**Response `200 OK`:**
```json
{
  "message": "Password reset email sent",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

**Error responses:**
- `404 Not Found` — email not registered

### Reset Password

**Endpoint:** `POST /auth/password/reset`

Completes the reset using the token from the email. Invalidates **all existing sessions** for the customer.

Rate limited to **5 attempts per hour per token**.

```json
{
  "token": "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz",
  "newPassword": "MyNewSecureP@ssw0rd"
}
```

**Response `200 OK`:**
```json
{
  "message": "Password reset successful",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `401 Unauthorized` — invalid or expired token

### Change Password (Authenticated)

**Endpoint:** `POST /auth/change-password`

Changes the password for the currently authenticated account. Requires the current password for verification. Optionally revokes all other sessions.

Rate limited to **5 attempts per hour per user**.

```http
POST /auth/change-password
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "currentPassword": "MySecureP@ssw0rd",
  "newPassword": "MyNewSecureP@ssw0rd",
  "logoutOtherSessions": true
}
```

**Response `200 OK`:**
```json
{
  "message": "Password changed successfully",
  "revokedSessionCount": 2,
  "timestamp": "2024-01-22T10:45:00Z"
}
```

`revokedSessionCount` is only present when `logoutOtherSessions` was `true`.

**Error responses:**
- `401 Unauthorized` — invalid current password

---

## 8. Profile Management

### Get Profile

**Endpoint:** `GET /me`

```http
GET /me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response `200 OK`:**
```json
{
  "id": "507f1f77bcf86cd799439011",
  "email": "john.doe@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890",
  "dateOfBirth": "1990-05-15",
  "emailVerified": true,
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
```

### Update Profile

**Endpoint:** `PATCH /me`

Partial update — only provided fields are changed. Email changes require re-verification.

Rate limited to **10 updates per hour per user**.

```http
PATCH /me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "firstName": "Jonathan",
  "lastName": "Doe",
  "phone": "+1234567891",
  "dateOfBirth": "1990-05-15"
}
```

**Response `200 OK`:**
```json
{
  "message": "Profile updated successfully",
  "customer": {
    "id": "507f1f77bcf86cd799439011",
    "email": "john.doe@example.com",
    "firstName": "Jonathan",
    "lastName": "Doe",
    "phone": "+1234567891",
    "emailVerified": true,
    "updatedAt": "2024-01-22T10:45:00Z"
  },
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `401 Unauthorized` — missing or invalid token
- `409 Conflict` — email already in use by another account

### Delete Account

**Endpoint:** `DELETE /me`

Permanently and irreversibly deletes the account and all associated data. All active sessions are revoked and the HTTP-only cookie is cleared.

Rate limited to **3 attempts per hour per user**.

The `confirmation` field must equal the literal string `"DELETE"`. Email/password accounts must also supply their current password.

```http
DELETE /me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

```json
{
  "confirmation": "DELETE",
  "password": "MySecureP@ssw0rd"
}
```

**Response `200 OK`:**
```json
{
  "message": "Your account has been permanently deleted",
  "timestamp": "2024-01-22T10:45:00Z"
}
```

**Error responses:**
- `400 Bad Request` — `confirmation` value is not `"DELETE"`
- `401 Unauthorized` — missing or invalid token

---

## 9. Address Management

All address endpoints require a valid Bearer token.

### List Addresses

**Endpoint:** `GET /me/addresses`

```http
GET /me/addresses
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response `200 OK`:**
```json
{
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
  "total": 1
}
```

### Add Address

**Endpoint:** `POST /me/addresses`

Maximum **20 addresses** per account. Address validation is performed before saving.

```json
{
  "type": "shipping",
  "fullName": "John Doe",
  "addressLine1": "456 Oak Avenue",
  "city": "Brooklyn",
  "state": "NY",
  "postalCode": "11201",
  "country": "US",
  "phone": "+1234567890",
  "isDefault": false
}
```

**Response `201 Created`:**
```json
{
  "message": "Address added successfully",
  "address": { "id": "addr_124", "..." }
}
```

### Update Address

**Endpoint:** `PUT /me/addresses/{addressId}`

```http
PUT /me/addresses/addr_123
Authorization: Bearer ...
```

**Response `200 OK`:**
```json
{
  "message": "Address updated successfully",
  "address": { "id": "addr_123", "..." }
}
```

**Error responses:**
- `404 Not Found` — address not found

### Delete Address

**Endpoint:** `DELETE /me/addresses/{addressId}`

Cannot delete the default address if it is the only address on the account.

**Response `200 OK`:**
```json
{
  "message": "Address deleted successfully",
  "deletedAddressId": "addr_123"
}
```

**Error responses:**
- `404 Not Found` — address not found
- `409 Conflict` — cannot delete the only default address

### Set Default Address

**Endpoint:** `PATCH /me/addresses/{addressId}/default`

Sets the address as the default for its type (`shipping` or `billing`). The previous default of the same type becomes non-default.

**Response `200 OK`:**
```json
{
  "message": "Default address updated successfully",
  "address": { "id": "addr_123", "isDefault": true, "..." }
}
```

**Error responses:**
- `404 Not Found` — address not found

---

## Customer Journeys

### New Customer (Email/Password)
1. `POST /auth/signup` → receive tokens, `emailVerified: false`
2. `POST /auth/verify-email` → activate account
3. Use access token for subsequent requests
4. `POST /auth/refresh` when access token expires

### New Customer (OAuth)
1. `GET /auth/oauth/{provider}/authorize?channel=web` → get `authorizationUrl` and `state`
2. Redirect user to `authorizationUrl`
3. Provider redirects back with `code` and `state`
4. `POST /auth/oauth/{provider}/callback` with `{ code, state }` → receive tokens, `isNewUser: true`

### Returning Customer
1. `POST /auth/login` → receive tokens
2. `POST /auth/refresh` when access token expires (token rotates each time)
3. `POST /auth/logout` to end current session

### Password Change
1. If authenticated: `POST /auth/change-password` with current password
2. If forgotten: `POST /auth/password/forgot` → `POST /auth/password/reset` (invalidates all sessions)

---

## Error Response Format

All error responses follow this shape:

```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable description",
  "timestamp": "2024-01-22T10:30:00Z"
}
```

Common error codes:

| HTTP Status | Error Code | Description |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Invalid request body or parameters |
| 400 | `INVALID_CHANNEL` | Unknown or unsupported channel value |
| 400 | `INVALID_CONFIRMATION` | Account deletion confirmation string incorrect |
| 401 | `INVALID_CREDENTIALS` | Wrong email or password |
| 401 | `INVALID_TOKEN` | Invalid or expired access/refresh token |
| 401 | `INVALID_STATE` | OAuth state mismatch (CSRF check failed) |
| 401 | `INVALID_CURRENT_PASSWORD` | Current password incorrect on change-password |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `EMAIL_ALREADY_EXISTS` | Account with this email already exists |
| 409 | `EMAIL_ALREADY_VERIFIED` | Email address is already verified |
| 502 | `PROVIDER_ERROR` | OAuth provider unreachable or returned an error |

---

## Security Notes

- Passwords are transmitted over HTTPS and hashed server-side with **bcrypt**
- Access tokens expire in **15 minutes**; refresh tokens expire in **7 days** and rotate on each use
- HTTP-only `refreshToken` cookies are used for web clients to prevent XSS token theft
- All OAuth flows use a server-generated `state` parameter for **CSRF protection**
- Rate limiting is enforced on all auth endpoints to prevent brute-force attacks
- Password reset and `POST /auth/change-password` invalidate sessions to contain credential-compromise blast radius
- Account deletion requires explicit `"DELETE"` confirmation and current password
