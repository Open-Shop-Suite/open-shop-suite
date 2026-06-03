package acceptance

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	genaccount "open-shop-webserver/gen/account"
	"open-shop-webserver/modules/account"
	"open-shop-webserver/modules/admin"
	"open-shop-webserver/modules/commons"
	"open-shop-webserver/modules/product"
	"open-shop-webserver/test/helpers"
)

// =============================================================================
// ACCEPTANCE TESTS - Batch 1: Core Happy Path Scenarios
// =============================================================================

func TestHappyPath_UserSignUpAndReceiveAccessToken(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signupReq := map[string]string{
		"email":     "alice@example.com",
		"password":  "SecurePass123!",
		"firstName": "Alice",
		"lastName":  "Johnson",
	}

	resp := makeRequest(t, "POST", server.URL+"/auth/signup", signupReq, "")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("signup failed: expected 201, got %d", resp.StatusCode)
	}

	var signupResp RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&signupResp); err != nil {
		t.Fatalf("failed to decode signup response: %v", err)
	}

	if signupResp.AccessToken == "" {
		t.Fatalf("expected access token in signup response")
	}

	if signupResp.RefreshToken == "" {
		t.Fatalf("expected refresh token in signup response")
	}

	if signupResp.Customer.Email != "alice@example.com" {
		t.Fatalf("expected customer email alice@example.com, got %s", signupResp.Customer.Email)
	}
}

func TestHappyPath_UserCanLoginWithEmailPassword(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// First signup
	signupReq := map[string]string{
		"email":     "bob@example.com",
		"password":  "MyPassword123!",
		"firstName": "Bob",
		"lastName":  "Smith",
	}
	_ = doSignup(t, server.URL, signupReq)

	// Then login
	loginReq := map[string]string{
		"email":    "bob@example.com",
		"password": "MyPassword123!",
	}

	resp := makeRequest(t, "POST", server.URL+"/auth/signin", loginReq, "")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login failed: expected 200, got %d", resp.StatusCode)
	}

	var loginResp RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil {
		t.Fatalf("failed to decode login response: %v", err)
	}

	if loginResp.AccessToken == "" {
		t.Fatalf("expected access token after login")
	}

	if loginResp.Customer.Email != "bob@example.com" {
		t.Fatalf("expected customer email bob@example.com, got %s", loginResp.Customer.Email)
	}
}

func TestHappyPath_UserCanAddSingleAddress(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	token := doSignup(t, server.URL, map[string]string{
		"email":     "carol@example.com",
		"password":  "SecurePass123!",
		"firstName": "Carol",
		"lastName":  "White",
	}).AccessToken

	addressReq := map[string]string{
		"firstName":    "Carol",
		"lastName":     "White",
		"addressLine1": "789 Pine St",
		"city":         "Seattle",
		"postalCode":   "98101",
		"country":      "US",
		"type":         "shipping",
	}

	addResp := doAddAddress(t, server.URL, addressReq, token)

	if addResp.Address.Id == "" {
		t.Fatalf("expected address id in response")
	}
}

func TestHappyPath_UserCanListAllAddresses(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	token := doSignup(t, server.URL, map[string]string{
		"email":     "david@example.com",
		"password":  "SecurePass123!",
		"firstName": "David",
		"lastName":  "Brown",
	}).AccessToken

	// Add 3 addresses
	addresses := []map[string]string{
		{
			"firstName": "David", "lastName": "Brown", "addressLine1": "100 Oak St",
			"city": "Portland", "postalCode": "97201", "country": "US", "type": "shipping",
		},
		{
			"firstName": "David", "lastName": "Brown", "addressLine1": "200 Maple St",
			"city": "Portland", "postalCode": "97202", "country": "US", "type": "billing",
		},
		{
			"firstName": "David", "lastName": "Brown", "addressLine1": "300 Elm St",
			"city": "Portland", "postalCode": "97203", "country": "US", "type": "shipping",
		},
	}

	for _, addr := range addresses {
		resp := makeRequest(t, "POST", server.URL+"/me/addresses", addr, token)
		resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("failed to add address: %d", resp.StatusCode)
		}
	}

	// List all addresses
	resp := makeRequest(t, "GET", server.URL+"/me/addresses", nil, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("list addresses failed: expected 200, got %d", resp.StatusCode)
	}

	var listResp struct {
		Addresses []map[string]interface{} `json:"addresses"`
		Total     int                       `json:"total"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&listResp); err != nil {
		t.Fatalf("failed to decode list response: %v", err)
	}

	if listResp.Total != 3 {
		t.Fatalf("expected 3 addresses, got %d", listResp.Total)
	}

	if len(listResp.Addresses) != 3 {
		t.Fatalf("expected 3 addresses in array, got %d", len(listResp.Addresses))
	}
}

func TestHappyPath_UserCanUpdateAddress(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	token := doSignup(t, server.URL, map[string]string{
		"email":     "eve@example.com",
		"password":  "SecurePass123!",
		"firstName": "Eve",
		"lastName":  "Green",
	}).AccessToken

	// Add address
	addressReq := map[string]string{
		"firstName":    "Eve",
		"lastName":     "Green",
		"addressLine1": "400 Cedar St",
		"city":         "Austin",
		"postalCode":   "78701",
		"country":      "US",
		"type":         "shipping",
	}

	addResp := doAddAddress(t, server.URL, addressReq, token)
	addressID := addResp.Address.Id

	// Update address
	updateReq := map[string]string{
		"firstName":    "Eve",
		"lastName":     "Blue",
		"addressLine1": "400 Cedar St",
		"city":         "Austin",
		"postalCode":   "78701",
		"country":      "US",
		"type":         "shipping",
	}

	resp := makeRequest(t, "PUT", server.URL+"/me/addresses/"+addressID, updateReq, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update address failed: expected 200, got %d", resp.StatusCode)
	}

	var updateResp map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&updateResp); err != nil {
		t.Fatalf("failed to decode update response: %v", err)
	}

	lastName, ok := updateResp["lastName"].(string)
	if !ok || lastName != "Blue" {
		t.Fatalf("expected lastName Blue, got %v", updateResp["lastName"])
	}
}

func TestHappyPath_UserCanDeleteAddress(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	token := doSignup(t, server.URL, map[string]string{
		"email":     "frank@example.com",
		"password":  "SecurePass123!",
		"firstName": "Frank",
		"lastName":  "Red",
	}).AccessToken

	// Add address
	addressReq := map[string]string{
		"firstName":    "Frank",
		"lastName":     "Red",
		"addressLine1": "500 Birch St",
		"city":         "Denver",
		"postalCode":   "80201",
		"country":      "US",
		"type":         "billing",
	}

	addResp := doAddAddress(t, server.URL, addressReq, token)
	addressID := addResp.Address.Id

	// Delete address
	resp := makeRequest(t, "DELETE", server.URL+"/me/addresses/"+addressID, nil, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("delete address failed: expected 200, got %d", resp.StatusCode)
	}

	// Verify it's deleted by listing addresses
	listResp := doListAddresses(t, server.URL, token)
	if listResp.Total != 0 {
		t.Fatalf("expected 0 addresses after deletion, got %d", listResp.Total)
	}
}

// =============================================================================
// ACCEPTANCE TESTS - Batch 2: Extended Happy Path (Profile, Sessions, Password)
// =============================================================================

func TestHappyPath_UserCanViewOwnProfile(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "profile1@example.com",
		"password":  "SecurePass123!",
		"firstName": "Profile",
		"lastName":  "User",
	})
	token := signup.AccessToken

	resp := makeRequest(t, "GET", server.URL+"/me", nil, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("get profile failed: expected 200, got %d", resp.StatusCode)
	}

	var profile map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&profile); err != nil {
		t.Fatalf("failed to decode profile response: %v", err)
	}

	if profile["email"] != "profile1@example.com" {
		t.Fatalf("expected email profile1@example.com, got %v", profile["email"])
	}
}

func TestHappyPath_UserCanUpdateProfile(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "profile2@example.com",
		"password":  "SecurePass123!",
		"firstName": "Old",
		"lastName":  "Name",
	})
	token := signup.AccessToken

	updateReq := map[string]string{
		"firstName": "New",
		"lastName":  "Updated",
	}

	resp := makeRequest(t, "PATCH", server.URL+"/me", updateReq, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update profile failed: expected 200, got %d", resp.StatusCode)
	}

	var updated map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&updated); err != nil {
		t.Fatalf("failed to decode update response: %v", err)
	}

	if updated["firstName"] != "New" || updated["lastName"] != "Updated" {
		t.Fatalf("profile not updated correctly")
	}
}

func TestHappyPath_UserCanChangePassword(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "password1@example.com",
		"password":  "OldPassword123!",
		"firstName": "Pass",
		"lastName":  "User",
	})
	token := signup.AccessToken

	changeReq := map[string]string{
		"currentPassword": "OldPassword123!",
		"newPassword":     "NewPassword456!",
	}

	resp := makeRequest(t, "POST", server.URL+"/auth/change-password", changeReq, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("change password failed: expected 200, got %d", resp.StatusCode)
	}

	// Verify old password doesn't work
	loginReq := map[string]string{
		"email":    "password1@example.com",
		"password": "OldPassword123!",
	}
	loginResp := makeRequest(t, "POST", server.URL+"/auth/signin", loginReq, "")
	defer loginResp.Body.Close()

	if loginResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("old password should not work, got status %d", loginResp.StatusCode)
	}

	// Verify new password works
	newLoginReq := map[string]string{
		"email":    "password1@example.com",
		"password": "NewPassword456!",
	}
	newLoginResp := makeRequest(t, "POST", server.URL+"/auth/signin", newLoginReq, "")
	defer newLoginResp.Body.Close()

	if newLoginResp.StatusCode != http.StatusOK {
		t.Fatalf("new password should work, got status %d", newLoginResp.StatusCode)
	}
}

func TestHappyPath_UserCanCreateMultipleSessions(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "multi@example.com",
		"password":  "SecurePass123!",
		"firstName": "Multi",
		"lastName":  "Session",
	})
	token1 := signup.AccessToken

	// Login again to create second session
	login2 := makeRequest(t, "POST", server.URL+"/auth/signin", map[string]string{
		"email":    "multi@example.com",
		"password": "SecurePass123!",
	}, "")
	defer login2.Body.Close()

	if login2.StatusCode != http.StatusOK {
		t.Fatalf("second login failed: expected 200, got %d", login2.StatusCode)
	}

	var token2Resp RegisterResponse
	if err := json.NewDecoder(login2.Body).Decode(&token2Resp); err != nil {
		t.Fatalf("failed to decode second login response: %v", err)
	}

	if token2Resp.AccessToken == "" {
		t.Fatalf("expected access token from second login")
	}

	// Both tokens should be valid and allow access to protected resources
	resp1 := makeRequest(t, "GET", server.URL+"/me/addresses", nil, token1)
	defer resp1.Body.Close()

	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("first token should allow access to /me/addresses, got %d", resp1.StatusCode)
	}

	resp2 := makeRequest(t, "GET", server.URL+"/me/addresses", nil, token2Resp.AccessToken)
	defer resp2.Body.Close()

	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("second token should allow access to /me/addresses, got %d", resp2.StatusCode)
	}
}

func TestHappyPath_UserCanListAllActiveSessions(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "sessions@example.com",
		"password":  "SecurePass123!",
		"firstName": "Session",
		"lastName":  "User",
	})
	token := signup.AccessToken

	resp := makeRequest(t, "GET", server.URL+"/auth/sessions", nil, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("get sessions failed: expected 200, got %d", resp.StatusCode)
	}

	var sessionsResp map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&sessionsResp); err != nil {
		t.Fatalf("failed to decode sessions response: %v", err)
	}

	// Should have at least 1 session (from signup)
	sessions, ok := sessionsResp["sessions"].([]interface{})
	if !ok || len(sessions) < 1 {
		t.Fatalf("expected at least 1 session")
	}
}

// =============================================================================
// ACCEPTANCE TESTS - Batch 3: Security & Authorization (Negative Path)
// =============================================================================

func TestSecurityPath_CannotAccessProtectedEndpointWithoutJWT(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Create a user first (just to have one in DB)
	_ = doSignup(t, server.URL, map[string]string{
		"email":     "user1@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "One",
	})

	// Try to access protected endpoint WITHOUT JWT token
	resp := makeRequest(t, "GET", server.URL+"/me/addresses", nil, "")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized, got %d", resp.StatusCode)
	}
}

func TestSecurityPath_CannotAccessWithInvalidJWTToken(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Create a user
	_ = doSignup(t, server.URL, map[string]string{
		"email":     "user2@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "Two",
	})

	// Try to access protected endpoint with invalid/malformed JWT
	invalidToken := "invalid.jwt.token"
	resp := makeRequest(t, "GET", server.URL+"/me/addresses", nil, invalidToken)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized with invalid token, got %d", resp.StatusCode)
	}
}

func TestSecurityPath_CannotAccessOtherUserData(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Create User A
	userASignup := doSignup(t, server.URL, map[string]string{
		"email":     "userA@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "A",
	})
	tokenA := userASignup.AccessToken

	// User A adds an address
	addrA := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "User",
		"lastName":     "A",
		"addressLine1": "100 A Street",
		"city":         "City A",
		"postalCode":   "12345",
		"country":      "US",
		"type":         "shipping",
	}, tokenA)
	addressAID := addrA.Address.Id

	// Create User B
	userBSignup := doSignup(t, server.URL, map[string]string{
		"email":     "userB@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "B",
	})
	tokenB := userBSignup.AccessToken

	// User B tries to access User A's address via API
	// This is a tricky test - the list endpoint returns user's own addresses
	// Let's test by trying to directly access/update the address ID created by User A

	// User B tries to update User A's address
	updateReq := map[string]string{
		"firstName":    "Hacker",
		"lastName":     "Hacker",
		"addressLine1": "100 A Street",
		"city":         "Hacked",
		"postalCode":   "99999",
		"country":      "US",
		"type":         "shipping",
	}

	resp := makeRequest(t, "PUT", server.URL+"/me/addresses/"+addressAID, updateReq, tokenB)
	defer resp.Body.Close()

	// Should be 404 (not found) or 403 (forbidden) - address doesn't belong to User B
	if resp.StatusCode != http.StatusNotFound && resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 404 or 403 when accessing other user's address, got %d", resp.StatusCode)
	}
}

func TestSecurityPath_CannotDeleteOtherUserData(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Create User A
	userASignup := doSignup(t, server.URL, map[string]string{
		"email":     "userC@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "C",
	})
	tokenA := userASignup.AccessToken

	// User A adds an address
	addrA := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "User",
		"lastName":     "C",
		"addressLine1": "200 C Street",
		"city":         "City C",
		"postalCode":   "54321",
		"country":      "US",
		"type":         "shipping",
	}, tokenA)
	addressAID := addrA.Address.Id

	// Create User D
	userDSignup := doSignup(t, server.URL, map[string]string{
		"email":     "userD@example.com",
		"password":  "SecurePass123!",
		"firstName": "User",
		"lastName":  "D",
	})
	tokenD := userDSignup.AccessToken

	// User D tries to delete User C's address
	resp := makeRequest(t, "DELETE", server.URL+"/me/addresses/"+addressAID, nil, tokenD)
	defer resp.Body.Close()

	// Should be 404 (not found) or 403 (forbidden) - address doesn't belong to User D
	if resp.StatusCode != http.StatusNotFound && resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 404 or 403 when deleting other user's address, got %d", resp.StatusCode)
	}

	// Verify User C can still access their address
	listResp := doListAddresses(t, server.URL, tokenA)
	if listResp.Total != 1 {
		t.Fatalf("expected User C still has 1 address, got %d", listResp.Total)
	}
}

// =============================================================================
// ACCEPTANCE TESTS - Batch 4: Validation & Edge Cases
// =============================================================================

func TestValidation_CannotSignupWithDuplicateEmail(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// First signup
	_ = doSignup(t, server.URL, map[string]string{
		"email":     "duplicate@example.com",
		"password":  "SecurePass123!",
		"firstName": "First",
		"lastName":  "User",
	})

	// Try to signup with same email
	resp := makeRequest(t, "POST", server.URL+"/auth/signup", map[string]string{
		"email":     "duplicate@example.com",
		"password":  "SecurePass123!",
		"firstName": "Second",
		"lastName":  "User",
	}, "")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 Conflict for duplicate email, got %d", resp.StatusCode)
	}
}

func TestValidation_CannotAddAddressWithMissingRequiredFields(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "valid@example.com",
		"password":  "SecurePass123!",
		"firstName": "Valid",
		"lastName":  "User",
	})
	token := signup.AccessToken

	// Try to add address without required fields
	incompleteAddr := map[string]string{
		"firstName": "John",
		// Missing lastName, addressLine1, city, postalCode, country
	}

	resp := makeRequest(t, "POST", server.URL+"/me/addresses", incompleteAddr, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 BadRequest for missing fields, got %d", resp.StatusCode)
	}
}

func TestValidation_CannotAddMoreThan20Addresses(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "limit@example.com",
		"password":  "SecurePass123!",
		"firstName": "Limit",
		"lastName":  "User",
	})
	token := signup.AccessToken

	// Add 20 addresses
	for i := 1; i <= 20; i++ {
		addr := map[string]string{
			"firstName":    "User",
			"lastName":     "Limit",
			"addressLine1": fmt.Sprintf("%d Main St", i),
			"city":         "TestCity",
			"postalCode":   "12345",
			"country":      "US",
			"type":         "shipping",
		}
		_ = doAddAddress(t, server.URL, addr, token)
	}

	// Try to add 21st address
	addr21 := map[string]string{
		"firstName":    "User",
		"lastName":     "Limit",
		"addressLine1": "21 Over Limit St",
		"city":         "TestCity",
		"postalCode":   "12345",
		"country":      "US",
		"type":         "shipping",
	}

	resp := makeRequest(t, "POST", server.URL+"/me/addresses", addr21, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("expected 409 Conflict when exceeding address limit, got %d", resp.StatusCode)
	}
}

func TestValidation_CanSetDefaultAddressTwiceToSameAddress(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "default@example.com",
		"password":  "SecurePass123!",
		"firstName": "Default",
		"lastName":  "User",
	})
	token := signup.AccessToken

	// Add address
	addr := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "User",
		"lastName":     "Default",
		"addressLine1": "100 Default St",
		"city":         "TestCity",
		"postalCode":   "12345",
		"country":      "US",
		"type":         "shipping",
	}, token)
	addressID := addr.Address.Id

	// Set as default
	resp1 := makeRequest(t, "PATCH", server.URL+"/me/addresses/"+addressID+"/default", nil, token)
	defer resp1.Body.Close()

	if resp1.StatusCode != http.StatusOK {
		t.Fatalf("first set default failed: expected 200, got %d", resp1.StatusCode)
	}

	// Set as default again (should be idempotent)
	resp2 := makeRequest(t, "PATCH", server.URL+"/me/addresses/"+addressID+"/default", nil, token)
	defer resp2.Body.Close()

	if resp2.StatusCode != http.StatusOK {
		t.Fatalf("second set default should be idempotent, expected 200, got %d", resp2.StatusCode)
	}
}

// =============================================================================
// ACCEPTANCE TESTS - Batch 5: Session Management & Complex Workflows
// =============================================================================

// NOTE: Session invalidation endpoints (InvalidateSession, InvalidateOtherSessions)
// are not yet implemented in the handlers (return 501). These tests are skipped
// until the endpoints are fully implemented.

// =============================================================================
// ACCEPTANCE TESTS - Complex User Journeys (Multi-Step Scenarios)
// =============================================================================

func TestJourney_CompleteAccountLifecycle(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Step 1: Sign up
	signup := doSignup(t, server.URL, map[string]string{
		"email":     "lifecycle@example.com",
		"password":  "InitialPass123!",
		"firstName": "John",
		"lastName":  "Doe",
	})
	token := signup.AccessToken
	if token == "" {
		t.Fatalf("signup failed - no token received")
	}

	// Step 2: Update profile
	updateResp := makeRequest(t, "PATCH", server.URL+"/me", map[string]string{
		"firstName": "Jane",
		"lastName":  "Smith",
	}, token)
	defer updateResp.Body.Close()
	if updateResp.StatusCode != http.StatusOK {
		t.Fatalf("update profile failed: expected 200, got %d", updateResp.StatusCode)
	}

	// Step 3: Add address
	addr := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "Jane",
		"lastName":     "Smith",
		"addressLine1": "100 Lifecycle St",
		"city":         "TestCity",
		"postalCode":   "12345",
		"country":      "US",
		"type":         "shipping",
	}, token)
	addressID := addr.Address.Id

	// Step 4: Change password
	changeResp := makeRequest(t, "POST", server.URL+"/auth/change-password", map[string]string{
		"currentPassword": "InitialPass123!",
		"newPassword":     "UpdatedPass456!",
	}, token)
	defer changeResp.Body.Close()
	if changeResp.StatusCode != http.StatusOK {
		t.Fatalf("change password failed: expected 200, got %d", changeResp.StatusCode)
	}

	// Step 5: Verify profile was updated
	profileResp := makeRequest(t, "GET", server.URL+"/me", nil, token)
	defer profileResp.Body.Close()
	var profile map[string]interface{}
	json.NewDecoder(profileResp.Body).Decode(&profile)
	if profile["firstName"] != "Jane" || profile["lastName"] != "Smith" {
		t.Fatalf("profile not updated correctly")
	}

	// Step 6: Verify address exists
	listResp := doListAddresses(t, server.URL, token)
	if listResp.Total != 1 {
		t.Fatalf("expected 1 address, got %d", listResp.Total)
	}

	// Step 7: Verify can login with new password
	loginResp := makeRequest(t, "POST", server.URL+"/auth/signin", map[string]string{
		"email":    "lifecycle@example.com",
		"password": "UpdatedPass456!",
	}, "")
	defer loginResp.Body.Close()
	if loginResp.StatusCode != http.StatusOK {
		t.Fatalf("login with new password failed: expected 200, got %d", loginResp.StatusCode)
	}

	// Step 8: Verify old password doesn't work
	oldLoginResp := makeRequest(t, "POST", server.URL+"/auth/signin", map[string]string{
		"email":    "lifecycle@example.com",
		"password": "InitialPass123!",
	}, "")
	defer oldLoginResp.Body.Close()
	if oldLoginResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("old password should not work, got status %d", oldLoginResp.StatusCode)
	}

	_ = addressID // unused but part of the journey
}

func TestJourney_AddressManagementWorkflow(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	signup := doSignup(t, server.URL, map[string]string{
		"email":     "address@example.com",
		"password":  "SecurePass123!",
		"firstName": "Address",
		"lastName":  "User",
	})
	token := signup.AccessToken

	// Step 1: Add first address (shipping)
	addr1 := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "Address",
		"lastName":     "User",
		"addressLine1": "100 Shipping St",
		"city":         "ShipCity",
		"postalCode":   "11111",
		"country":      "US",
		"type":         "shipping",
	}, token)
	addr1ID := addr1.Address.Id

	// Step 2: Add second address (billing)
	addr2 := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "Address",
		"lastName":     "User",
		"addressLine1": "200 Billing St",
		"city":         "BillCity",
		"postalCode":   "22222",
		"country":      "US",
		"type":         "billing",
	}, token)
	addr2ID := addr2.Address.Id

	// Step 3: Set first address as default
	defaultResp := makeRequest(t, "PATCH", server.URL+"/me/addresses/"+addr1ID+"/default", nil, token)
	defer defaultResp.Body.Close()
	if defaultResp.StatusCode != http.StatusOK {
		t.Fatalf("set default failed: expected 200, got %d", defaultResp.StatusCode)
	}

	// Step 4: Update the default address
	updateResp := makeRequest(t, "PUT", server.URL+"/me/addresses/"+addr1ID, map[string]string{
		"firstName":    "Updated",
		"lastName":     "User",
		"addressLine1": "100 Shipping St",
		"city":         "UpdatedCity",
		"postalCode":   "11111",
		"country":      "US",
		"type":         "shipping",
	}, token)
	defer updateResp.Body.Close()
	if updateResp.StatusCode != http.StatusOK {
		t.Fatalf("update address failed: expected 200, got %d", updateResp.StatusCode)
	}

	// Step 5: Delete the billing address
	deleteResp := makeRequest(t, "DELETE", server.URL+"/me/addresses/"+addr2ID, nil, token)
	defer deleteResp.Body.Close()
	if deleteResp.StatusCode != http.StatusOK {
		t.Fatalf("delete address failed: expected 200, got %d", deleteResp.StatusCode)
	}

	// Step 6: Verify final state
	listResp := doListAddresses(t, server.URL, token)
	if listResp.Total != 1 {
		t.Fatalf("expected 1 address after deletion, got %d", listResp.Total)
	}

	// Step 7: Verify remaining address is the updated one
	finalAddr := listResp.Addresses[0]
	if finalAddr["city"] != "UpdatedCity" {
		t.Fatalf("address not updated correctly")
	}
}

func TestJourney_MultiStepSecurityScenario(t *testing.T) {
	db := helpers.SetupTestDB(t)
	defer db.Close()

	mux := setupTestMux(t, db)
	server := httptest.NewServer(mux)
	defer server.Close()

	// Step 1: User A signs up and adds an address
	userASignup := doSignup(t, server.URL, map[string]string{
		"email":     "security@example.com",
		"password":  "SecurePass123!",
		"firstName": "Security",
		"lastName":  "TestA",
	})
	tokenA := userASignup.AccessToken

	addrA := doAddAddress(t, server.URL, map[string]string{
		"firstName":    "Security",
		"lastName":     "TestA",
		"addressLine1": "100 Secret St",
		"city":         "SecretCity",
		"postalCode":   "99999",
		"country":      "US",
		"type":         "shipping",
	}, tokenA)
	addrAID := addrA.Address.Id

	// Step 2: User A verifies they can access their data
	listAResp := doListAddresses(t, server.URL, tokenA)
	if listAResp.Total != 1 {
		t.Fatalf("User A should see 1 address")
	}

	// Step 3: User B signs up
	userBSignup := doSignup(t, server.URL, map[string]string{
		"email":     "hacker@example.com",
		"password":  "HackerPass123!",
		"firstName": "Hacker",
		"lastName":  "User",
	})
	tokenB := userBSignup.AccessToken

	// Step 4: User B tries to update User A's address (should fail)
	updateResp := makeRequest(t, "PUT", server.URL+"/me/addresses/"+addrAID, map[string]string{
		"firstName":    "Hacked",
		"lastName":     "Hacked",
		"addressLine1": "100 Hacked St",
		"city":         "HackedCity",
		"postalCode":   "00000",
		"country":      "US",
		"type":         "shipping",
	}, tokenB)
	defer updateResp.Body.Close()

	if updateResp.StatusCode != http.StatusForbidden && updateResp.StatusCode != http.StatusNotFound {
		t.Fatalf("User B should not be able to update User A's address, got status %d", updateResp.StatusCode)
	}

	// Step 5: User A verifies their data is unchanged
	listAFinalResp := doListAddresses(t, server.URL, tokenA)
	if listAFinalResp.Total != 1 {
		t.Fatalf("User A should still have 1 address")
	}

	finalAddr := listAFinalResp.Addresses[0]
	if finalAddr["city"] != "SecretCity" {
		t.Fatalf("User A's address was modified!")
	}

	// Step 6: User B tries with invalid token (should fail)
	invalidResp := makeRequest(t, "GET", server.URL+"/me/addresses", nil, "invalid.token.here")
	defer invalidResp.Body.Close()
	if invalidResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("invalid token should return 401, got %d", invalidResp.StatusCode)
	}

	// Step 7: User B tries without token (should fail)
	noTokenResp := makeRequest(t, "GET", server.URL+"/me/addresses", nil, "")
	defer noTokenResp.Body.Close()
	if noTokenResp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("missing token should return 401, got %d", noTokenResp.StatusCode)
	}
}

// =============================================================================
// HELPERS - Setup and Request Functions
// =============================================================================

type RegisterResponse struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	Customer     struct {
		Id    int    `json:"id"`
		Email string `json:"email"`
	} `json:"customer"`
}

type Server struct {
	*account.AccountHandler
	*product.ProductHandler
	*admin.AdminHandler
}

func setupTestMux(t *testing.T, db *sql.DB) http.Handler {
	auth := helpers.CreateTestAuth()
	server := &Server{
		account.NewHandler(db, auth, commons.OAuthConfig{}),
		product.NewHandler(),
		admin.NewHandler(),
	}

	mux := http.NewServeMux()
	authMW := commons.AuthMiddleware(auth)
	middlewares := []genaccount.MiddlewareFunc{commons.RequestIDMiddleware, authMW}

	genaccount.HandlerWithOptions(server, genaccount.StdHTTPServerOptions{
		BaseRouter:  mux,
		Middlewares: middlewares,
	})

	return mux
}

func makeRequest(t *testing.T, method, url string, body interface{}, authToken string) *http.Response {
	var reqBody io.Reader
	if body != nil {
		bodyBytes, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("failed to marshal request body: %v", err)
		}
		reqBody = bytes.NewReader(bodyBytes)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if authToken != "" {
		req.Header.Set("Authorization", "Bearer "+authToken)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("failed to make request: %v", err)
	}

	t.Logf("%s %s: %d", method, url, resp.StatusCode)
	return resp
}

// Convenience helpers for common operations
func doSignup(t *testing.T, baseURL string, signupReq map[string]string) RegisterResponse {
	resp := makeRequest(t, "POST", baseURL+"/auth/signup", signupReq, "")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("signup failed: expected 201, got %d", resp.StatusCode)
	}

	var signupResp RegisterResponse
	if err := json.NewDecoder(resp.Body).Decode(&signupResp); err != nil {
		t.Fatalf("failed to decode signup response: %v", err)
	}

	return signupResp
}

func doAddAddress(t *testing.T, baseURL string, addressReq map[string]string, token string) struct {
	Address struct {
		Id string `json:"id"`
	} `json:"address"`
} {
	resp := makeRequest(t, "POST", baseURL+"/me/addresses", addressReq, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("add address failed: expected 201, got %d", resp.StatusCode)
	}

	// Handler returns the address directly, not wrapped
	var address struct {
		Id string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&address); err != nil {
		t.Fatalf("failed to decode add address response: %v", err)
	}

	// Return in the expected format for the helper
	return struct {
		Address struct {
			Id string `json:"id"`
		} `json:"address"`
	}{
		Address: address,
	}
}

func doListAddresses(t *testing.T, baseURL string, token string) struct {
	Addresses []map[string]interface{} `json:"addresses"`
	Total     int                       `json:"total"`
} {
	resp := makeRequest(t, "GET", baseURL+"/me/addresses", nil, token)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("list addresses failed: expected 200, got %d", resp.StatusCode)
	}

	var listResp struct {
		Addresses []map[string]interface{} `json:"addresses"`
		Total     int                       `json:"total"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&listResp); err != nil {
		t.Fatalf("failed to decode list response: %v", err)
	}

	return listResp
}
