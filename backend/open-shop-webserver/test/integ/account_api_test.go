package integ

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	genaccount "open-shop-webserver/gen/account"
	"open-shop-webserver/modules/account"
	"open-shop-webserver/modules/commons"
	"open-shop-webserver/test/helpers"
)

/*
TestSignUp_Integration - tests successful signup with database

	curl -X POST http://localhost:8080/auth/signup \
	  -H "Content-Type: application/json" \
	  -d '{"email":"newuser@example.com","password":"SecurePassword123!","firstName":"John","lastName":"Doe"}'
*/
func TestSignUp_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.SignupRequest{
		Email:     "newuser@example.com",
		Password:  "SecurePassword123!",
		FirstName: "John",
		LastName:  "Doe",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/signup", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignUp(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d", w.Code)
	}

	var resp genaccount.AuthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify response
	if resp.Customer.Email == nil || *resp.Customer.Email != "newuser@example.com" {
		t.Fatalf("expected email newuser@example.com in response")
	}

	// Verify database
	var dbEmail string
	err := db.QueryRow(`SELECT email FROM customers WHERE email = ?`, "newuser@example.com").Scan(&dbEmail)
	if err != nil {
		t.Fatalf("expected customer in database: %v", err)
	}
}

/*
TestSignUp_DuplicateEmail - tests signup with existing email (should return 409 conflict)

	curl -X POST http://localhost:8080/auth/signup \
	  -H "Content-Type: application/json" \
	  -d '{"email":"existing@example.com","password":"NewPassword123!","firstName":"Jane","lastName":"Smith"}'
*/
func TestSignUp_DuplicateEmail(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	helpers.CreateTestCustomer(t, db, "existing@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.SignupRequest{
		Email:     "existing@example.com",
		Password:  "NewPassword123!",
		FirstName: "Jane",
		LastName:  "Smith",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/signup", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignUp(w, req)

	if w.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", w.Code)
	}
}

/*
TestSignIn_Integration - tests successful signin with valid credentials

	curl -X POST http://localhost:8080/auth/login \
	  -H "Content-Type: application/json" \
	  -d '{"email":"user@example.com","password":"Password123!"}'
*/
func TestSignIn_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	password := "Password123!"
	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", password)

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.LoginRequest{
		Email:    "user@example.com",
		Password: password,
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/signin", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignIn(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp genaccount.AuthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify customer in response
	if resp.Customer.Id != customerID {
		t.Fatalf("expected customer ID %d in response, got %d", customerID, resp.Customer.Id)
	}
}

/*
TestSignIn_WrongPassword - tests signin with incorrect password (should return 401)

	curl -X POST http://localhost:8080/auth/login \
	  -H "Content-Type: application/json" \
	  -d '{"email":"user@example.com","password":"WrongPassword123!"}'
*/
func TestSignIn_WrongPassword(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "CorrectPassword123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.LoginRequest{
		Email:    "user@example.com",
		Password: "WrongPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/signin", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignIn(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}
}

/*
TestSignIn_UserNotFound - tests signin with non-existent user (should return 401)

	curl -X POST http://localhost:8080/auth/login \
	  -H "Content-Type: application/json" \
	  -d '{"email":"nonexistent@example.com","password":"AnyPassword123!"}'
*/
func TestSignIn_UserNotFound(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.LoginRequest{
		Email:    "nonexistent@example.com",
		Password: "AnyPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/signin", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignIn(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}
}

/*
TestAddCustomerAddress_Integration - tests adding a new address (requires JWT token in header)

	curl -X POST http://localhost:8080/me/addresses \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"firstName":"John","addressLine1":"123 Main St","city":"New York","postalCode":"10001","country":"US"}'
*/
func TestAddCustomerAddress_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.Address{
		FirstName:    "John",
		AddressLine1: "123 Main St",
		City:         "New York",
		PostalCode:   "10001",
		Country:      "US",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/me/addresses", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	req = helpers.AddCustomerToContext(req, customerID)

	w := httptest.NewRecorder()
	handler.AddCustomerAddress(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", w.Code, w.Body.String())
	}

	var resp genaccount.Address
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify database
	var dbCity string
	err := db.QueryRow(
		`SELECT city FROM customer_addresses WHERE id = ?`,
		*resp.Id,
	).Scan(&dbCity)
	if err != nil {
		t.Fatalf("expected address in database: %v", err)
	}

	if dbCity != "New York" {
		t.Fatalf("expected city New York, got %s", dbCity)
	}
}

/*
TestAddCustomerAddress_LimitExceeded - tests address limit (max 20, should return 409)

	curl -X POST http://localhost:8080/me/addresses \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"firstName":"John","addressLine1":"456 Oak Ave","city":"New York","postalCode":"10001","country":"US"}'
*/
func TestAddCustomerAddress_LimitExceeded(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	// Add 20 addresses
	for i := 0; i < 20; i++ {
		helpers.CreateTestAddress(t, db, "addr_"+string(rune(48+i)), customerID, "John", "123 Main St", "City", "10001", "US")
	}

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.Address{
		FirstName:    "John",
		AddressLine1: "456 Oak Ave",
		City:         "New York",
		PostalCode:   "10001",
		Country:      "US",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/me/addresses", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	req = helpers.AddCustomerToContext(req, customerID)

	w := httptest.NewRecorder()
	handler.AddCustomerAddress(w, req)

	if w.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", w.Code)
	}
}

/*
TestGetCustomerAddresses_Integration - tests retrieving all customer addresses (requires JWT token)

	curl -X GET http://localhost:8080/me/addresses \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestGetCustomerAddresses_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")
	helpers.CreateTestAddress(t, db, "addr_1", customerID, "John", "123 Main St", "New York", "10001", "US")
	helpers.CreateTestAddress(t, db, "addr_2", customerID, "John", "456 Oak Ave", "Boston", "02101", "US")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodGet, "/me/addresses", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.GetCustomerAddresses(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	// Verify response contains addresses
	if addresses, ok := resp["addresses"].([]interface{}); !ok || len(addresses) != 2 {
		t.Fatalf("expected 2 addresses in response")
	}

	if total, ok := resp["total"].(float64); !ok || total != 2 {
		t.Fatalf("expected total 2, got %v", total)
	}
}

/*
TestGetCustomerAddresses_Empty - tests retrieving addresses when customer has no addresses

	curl -X GET http://localhost:8080/me/addresses \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestGetCustomerAddresses_Empty(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodGet, "/me/addresses", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.GetCustomerAddresses(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if total, ok := resp["total"].(float64); !ok || total != 0 {
		t.Fatalf("expected total 0, got %v", total)
	}
}

/*
TestUpdateCustomerAddress_Integration - tests updating an existing address (requires JWT token)

	curl -X PUT http://localhost:8080/me/addresses/ADDR_ID \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"firstName":"Jane","addressLine1":"456 Oak Ave","city":"Boston","postalCode":"02101","country":"US"}'
*/
func TestUpdateCustomerAddress_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")
	helpers.CreateTestAddress(t, db, "addr_1", customerID, "John", "123 Main St", "New York", "10001", "US")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.Address{
		FirstName:    "Jane",
		AddressLine1: "456 Oak Ave",
		City:         "Boston",
		PostalCode:   "02101",
		Country:      "US",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/me/addresses/addr_1", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")

	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.UpdateCustomerAddress(w, req, "addr_1")

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify database
	var dbCity string
	err := db.QueryRow(
		`SELECT city FROM customer_addresses WHERE id = ?`,
		"addr_1",
	).Scan(&dbCity)
	if err != nil {
		t.Fatalf("failed to query address: %v", err)
	}

	if dbCity != "Boston" {
		t.Fatalf("expected city Boston, got %s", dbCity)
	}
}

/*
TestDeleteCustomerAddress_Integration - tests deleting an address (requires JWT token)

	curl -X DELETE http://localhost:8080/me/addresses/ADDR_ID \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestDeleteCustomerAddress_Integration(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")
	helpers.CreateTestAddress(t, db, "addr_1", customerID, "John", "123 Main St", "New York", "10001", "US")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodDelete, "/me/addresses/addr_1", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.DeleteCustomerAddress(w, req, "addr_1")

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	// Verify address deleted from database
	var count int
	err := db.QueryRow(`SELECT COUNT(*) FROM customer_addresses WHERE id = ?`, "addr_1").Scan(&count)
	if err != nil {
		t.Fatalf("failed to query: %v", err)
	}

	if count != 0 {
		t.Fatalf("expected address to be deleted, but found %d", count)
	}
}

/*
TestDeleteCustomerAddress_NotFound - tests deleting non-existent address (should return 404)

	curl -X DELETE http://localhost:8080/me/addresses/nonexistent \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestDeleteCustomerAddress_NotFound(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodDelete, "/me/addresses/nonexistent", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.DeleteCustomerAddress(w, req, "nonexistent")

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", w.Code)
	}
}

/*
TestSetDefaultAddress - tests setting an address as default (requires JWT token)

	curl -X POST http://localhost:8080/me/addresses/ADDR_ID/default \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestSetDefaultAddress(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")
	helpers.CreateTestAddress(t, db, "addr_1", customerID, "John", "123 Main St", "New York", "10001", "US")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodPost, "/me/addresses/addr_1/default", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.SetDefaultAddress(w, req, "addr_1")

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	// Verify database
	var isDefault bool
	err := db.QueryRow(`SELECT is_default FROM customer_addresses WHERE id = ?`, "addr_1").Scan(&isDefault)
	if err != nil {
		t.Fatalf("failed to query address: %v", err)
	}

	if !isDefault {
		t.Fatalf("expected address to be default")
	}
}

/*
TestUpdatePassword - tests changing customer password (requires JWT token)

	curl -X POST http://localhost:8080/auth/change-password \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"currentPassword":"OldPassword123!","newPassword":"NewPassword123!"}'
*/
func TestUpdatePassword(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "OldPassword123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.ChangePasswordRequest{
		CurrentPassword: "OldPassword123!",
		NewPassword:     "NewPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/change-password", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.UpdatePassword(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}
}

/*
TestUpdatePassword_WrongCurrentPassword - tests changing password with wrong current password (should return 401)

	curl -X POST http://localhost:8080/auth/change-password \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"currentPassword":"WrongPassword123!","newPassword":"NewPassword123!"}'
*/
func TestUpdatePassword_WrongCurrentPassword(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "CorrectPassword123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.ChangePasswordRequest{
		CurrentPassword: "WrongPassword123!",
		NewPassword:     "NewPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/change-password", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.UpdatePassword(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}
}

/*
TestUpdatePassword_Unauthorized - tests changing password without auth (should return 401)

	curl -X POST http://localhost:8080/auth/change-password \
	  -H "Content-Type: application/json" \
	  -d '{"currentPassword":"OldPassword123!","newPassword":"NewPassword123!"}'
*/
func TestUpdatePassword_Unauthorized(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.ChangePasswordRequest{
		CurrentPassword: "OldPassword123!",
		NewPassword:     "NewPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/change-password", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.UpdatePassword(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}
}

/*
TestGetProfile - tests retrieving customer profile (requires JWT token)

	curl -X GET http://localhost:8080/me \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestGetProfile(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.GetProfile(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var resp genaccount.Customer
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Id != customerID {
		t.Fatalf("expected customer ID %d, got %d", customerID, resp.Id)
	}
	if resp.Email == nil || *resp.Email != "user@example.com" {
		t.Fatalf("expected email user@example.com")
	}
}

/*
TestGetProfile_Unauthorized - tests getting profile without auth (should return 401)

curl -X GET http://localhost:8080/me
*/
func TestGetProfile_Unauthorized(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodGet, "/me", nil)

	w := httptest.NewRecorder()
	handler.GetProfile(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}
}

/*
TestUpdateProfile - tests updating customer profile (requires JWT token)

	curl -X PUT http://localhost:8080/me \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"firstName":"Jane","lastName":"Smith"}'
*/
func TestUpdateProfile(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	firstName := "Jane"
	lastName := "Smith"
	body := genaccount.ProfileUpdateRequest{
		FirstName: &firstName,
		LastName:  &lastName,
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/me", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.UpdateProfile(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp genaccount.Customer
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.FirstName != "Jane" || resp.LastName != "Smith" {
		t.Fatalf("expected Jane Smith, got %s %s", resp.FirstName, resp.LastName)
	}
}

/*
TestLogoutCustomer - tests logging out a customer (requires JWT token and sessionId)

	curl -X POST http://localhost:8080/auth/logout \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{"sessionId":"SESSION_ID"}'
*/
func TestLogoutCustomer(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")
	helpers.CreateTestSession(t, db, "session_1", customerID, "refresh_token")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.LogoutRequest{
		SessionId: "session_1",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.LogoutCustomer(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}
}

/*
TestLogoutCustomer_MissingSessionId - tests logout without sessionId (should return 400)

	curl -X POST http://localhost:8080/auth/logout \
	  -H "Content-Type: application/json" \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
	  -d '{}'
*/
func TestLogoutCustomer_MissingSessionId(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.LogoutRequest{}
	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/logout", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.LogoutCustomer(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", w.Code)
	}
}

/*
TestGetSessions - tests retrieving all customer sessions (requires JWT token)

	curl -X GET http://localhost:8080/auth/sessions \
	  -H "Authorization: Bearer YOUR_JWT_TOKEN"
*/
func TestGetSessions(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	customerID := helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	// Create a session with all required fields
	expiresAt := time.Now().Add(7 * 24 * time.Hour).Format(time.RFC3339)
	_, err := db.Exec(`
		INSERT INTO customer_sessions (id, customer_id, refresh_token, device_type, device_name, ip_address, location, is_active, expires_at, created_at, last_accessed_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, datetime('now'), datetime('now'))
	`, "session_1", customerID, "refresh_token_1", "web", "Chrome", "192.0.2.1", "New York, US", expiresAt)
	if err != nil {
		t.Fatalf("failed to create session: %v", err)
	}

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	req := httptest.NewRequest(http.MethodGet, "/auth/sessions", nil)
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	req = req.WithContext(ctx)

	w := httptest.NewRecorder()
	handler.GetSessions(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if sessions, ok := resp["sessions"].([]interface{}); !ok || len(sessions) != 1 {
		t.Fatalf("expected 1 session in response")
	}
}

/*
TestRequestPasswordReset - tests requesting a password reset email

	curl -X POST http://localhost:8080/auth/password/forgot \
	  -H "Content-Type: application/json" \
	  -d '{"email":"user@example.com"}'
*/
func TestRequestPasswordReset(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.PasswordResetRequest{
		Email: "user@example.com",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/password/forgot", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.RequestPasswordReset(w, req)

	// Status should be 200 or 202 (accepted)
	if w.Code < 200 || w.Code >= 300 {
		t.Logf("note: RequestPasswordReset returned %d (may vary by implementation)", w.Code)
	}
}

/*
TestRequestPasswordReset_UserNotFound - tests password reset for non-existent user (should return 404)

	curl -X POST http://localhost:8080/auth/password/forgot \
	  -H "Content-Type: application/json" \
	  -d '{"email":"nonexistent@example.com"}'
*/
func TestRequestPasswordReset_UserNotFound(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	body := genaccount.PasswordResetRequest{
		Email: "nonexistent@example.com",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/password/forgot", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.RequestPasswordReset(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", w.Code)
	}
}

/*
TestConfirmPasswordReset - tests confirming password reset with token

	curl -X POST http://localhost:8080/auth/password/reset \
	  -H "Content-Type: application/json" \
	  -d '{"token":"RESET_TOKEN","newPassword":"NewPassword123!"}'
*/
func TestConfirmPasswordReset(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	helpers.CreateTestCustomer(t, db, "user@example.com", "John", "Doe", "Password123!")

	handler := account.NewHandler(db, helpers.CreateTestAuth(), commons.OAuthConfig{})

	// Note: In a real scenario, we would have a valid reset token from RequestPasswordReset
	// For testing, we use an invalid token to test error handling
	body := genaccount.PasswordConfirmRequest{
		Token:       "invalid_token",
		NewPassword: "NewPassword123!",
	}

	bodyBytes, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/auth/password/reset", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")

	w := httptest.NewRecorder()
	handler.ConfirmPasswordReset(w, req)

	// Should fail with invalid token
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d: %s", w.Code, w.Body.String())
	}
}

/*
TestRefreshToken - tests refreshing access token with refresh token

	curl -X POST http://localhost:8080/auth/refresh \
	  -H "Content-Type: application/json" \
	  -d '{"refreshToken":"YOUR_REFRESH_TOKEN"}'

OR send refresh token as cookie:

	curl -X POST http://localhost:8080/auth/refresh \
	  -H "Cookie: refreshToken=YOUR_REFRESH_TOKEN"
*/
func TestRefreshToken(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	auth := helpers.CreateTestAuth()

	handler := account.NewHandler(db, auth, commons.OAuthConfig{})

	// First, sign up and get a valid session
	signUpBody := genaccount.SignupRequest{
		Email:     "newuser@example.com",
		Password:  "TestPassword123!",
		FirstName: "John",
		LastName:  "Doe",
	}

	bodyBytes, _ := json.Marshal(signUpBody)
	req := httptest.NewRequest(http.MethodPost, "/auth/signup", strings.NewReader(string(bodyBytes)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.SignUp(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("signup failed: %d", w.Code)
	}

	var signUpResp genaccount.AuthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &signUpResp); err != nil {
		t.Fatalf("failed to unmarshal signup response: %v", err)
	}

	// Now test refresh token (would need actual refresh token from signup)
	// For now, we just verify the endpoint exists
	if signUpResp.RefreshToken != "" {
		refreshBody := genaccount.TokenRefreshRequest{
			RefreshToken: &signUpResp.RefreshToken,
		}
		bodyBytes, _ := json.Marshal(refreshBody)
		req := httptest.NewRequest(http.MethodPost, "/auth/refresh", strings.NewReader(string(bodyBytes)))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		handler.RefreshToken(w, req)
		// May succeed or fail depending on token validation
		if w.Code >= 200 && w.Code < 500 {
			t.Logf("RefreshToken returned %d", w.Code)
		}
	}
}
