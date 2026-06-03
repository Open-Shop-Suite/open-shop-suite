package account

import (
	"context"
	"database/sql"
	"sync"
	"testing"

	"golang.org/x/crypto/bcrypt"

	genaccount "open-shop-webserver/gen/account"
	"open-shop-webserver/modules/commons"
)

// ============= MOCKS =============

// MockDB is a mock implementation of sql.DB for testing
type MockDB struct {
	mu sync.RWMutex

	// Stored data
	customers map[int]*CustomerData
	sessions  map[string]*SessionData
	addresses map[string]*AddressData

	// Call tracking
	QueryCalls      []string
	ExecCalls       []string
	QueryRowCalls   []string
	LastError       error
	ShouldFailQuery bool
	ShouldFailExec  bool

	// Auto-increment counters
	nextCustomerID int
}

type CustomerData struct {
	ID            int
	Email         string
	FirstName     string
	LastName      string
	PasswordHash  string
	Phone         *string
	DateOfBirth   *string
	EmailVerified bool
	CreatedAt     string
	UpdatedAt     string
}

type SessionData struct {
	ID           string
	CustomerID   int
	RefreshToken string
	ExpiresAt    string
}

type AddressData struct {
	ID           string
	CustomerID   int
	Type         string
	FirstName    string
	LastName     *string
	AddressLine1 string
	City         string
	PostalCode   string
	Country      string
	IsDefault    bool
	CreatedAt    string
	UpdatedAt    string
}

func NewMockDB() *MockDB {
	return &MockDB{
		customers:      make(map[int]*CustomerData),
		sessions:       make(map[string]*SessionData),
		addresses:      make(map[string]*AddressData),
		nextCustomerID: 10000,
	}
}

// QueryContext mocks database queries
func (m *MockDB) QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.QueryCalls = append(m.QueryCalls, query)

	if m.ShouldFailQuery && m.LastError != nil {
		return nil, m.LastError
	}

	return nil, nil
}

// QueryRowContext mocks database single row queries
func (m *MockDB) QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row {
	m.mu.Lock()
	m.QueryRowCalls = append(m.QueryRowCalls, query)
	m.mu.Unlock()

	return nil
}

// ExecContext mocks database execution
func (m *MockDB) ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.ExecCalls = append(m.ExecCalls, query)

	if m.ShouldFailExec && m.LastError != nil {
		return nil, m.LastError
	}

	return &MockResult{}, nil
}

type MockResult struct{}

func (m *MockResult) LastInsertId() (int64, error) {
	return 1, nil
}

func (m *MockResult) RowsAffected() (int64, error) {
	return 1, nil
}

// Helper methods for testing
func (m *MockDB) AddCustomer(email, firstName, lastName, passwordHash string) int {
	m.mu.Lock()
	defer m.mu.Unlock()

	id := m.nextCustomerID
	m.nextCustomerID++

	m.customers[id] = &CustomerData{
		ID:            id,
		Email:         email,
		FirstName:     firstName,
		LastName:      lastName,
		PasswordHash:  passwordHash,
		EmailVerified: true,
		CreatedAt:     "2024-01-01T00:00:00Z",
		UpdatedAt:     "2024-01-01T00:00:00Z",
	}

	return id
}

func (m *MockDB) GetCustomer(id int) *CustomerData {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.customers[id]
}

func (m *MockDB) GetCustomerByEmail(email string) *CustomerData {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, cust := range m.customers {
		if cust.Email == email {
			return cust
		}
	}
	return nil
}

func (m *MockDB) AddSession(sessionID string, customerID int, refreshToken string, expiresAt string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.sessions[sessionID] = &SessionData{
		ID:           sessionID,
		CustomerID:   customerID,
		RefreshToken: refreshToken,
		ExpiresAt:    expiresAt,
	}
}

func (m *MockDB) GetSession(sessionID string) *SessionData {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.sessions[sessionID]
}

func (m *MockDB) AddAddress(addressID string, customerID int, addressType, firstName, addressLine1, city, postalCode, country string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.addresses[addressID] = &AddressData{
		ID:           addressID,
		CustomerID:   customerID,
		Type:         addressType,
		FirstName:    firstName,
		AddressLine1: addressLine1,
		City:         city,
		PostalCode:   postalCode,
		Country:      country,
		CreatedAt:    "2024-01-01T00:00:00Z",
		UpdatedAt:    "2024-01-01T00:00:00Z",
	}
}

func (m *MockDB) GetAddress(addressID string) *AddressData {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.addresses[addressID]
}

func (m *MockDB) GetCustomerAddressCount(customerID int) int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	count := 0
	for _, addr := range m.addresses {
		if addr.CustomerID == customerID {
			count++
		}
	}
	return count
}

// MockOAuthProvider is a mock implementation of OAuthProvider
type MockOAuthProvider struct {
	mu                sync.RWMutex
	ShouldFail        bool
	FailError         error
	ValidateCallCount int
	LastToken         string

	Email   string
	Name    string
	Picture string
}

func NewMockOAuthProvider() *MockOAuthProvider {
	return &MockOAuthProvider{
		Email:   "oauth@example.com",
		Name:    "OAuth User",
		Picture: "https://example.com/pic.jpg",
	}
}

func (m *MockOAuthProvider) ValidateAndGetUserInfo(ctx context.Context, token string) (*commons.OAuthUserInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.ValidateCallCount++
	m.LastToken = token

	if m.ShouldFail {
		return nil, m.FailError
	}

	return &commons.OAuthUserInfo{
		Email:     m.Email,
		FirstName: m.Name,
		LastName:  "User",
	}, nil
}

func (m *MockOAuthProvider) ProviderColumn() string {
	return "google_id"
}

// ============= TESTS =============

// TestValidateAddressFields_Success tests valid address scenarios
func TestValidateAddressFields_Success(t *testing.T) {
	tests := []struct {
		name string
		addr *genaccount.Address
	}{
		{
			name: "valid address with required fields only",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "US",
			},
		},
		{
			name: "valid address with all optional fields",
			addr: &genaccount.Address{
				FirstName:    "John",
				LastName:     strPtr("Doe"),
				Company:      strPtr("Acme Corp"),
				AddressLine1: "123 Main St",
				AddressLine2: strPtr("Apt 4B"),
				City:         "New York",
				State:        strPtr("NY"),
				PostalCode:   "10001",
				Country:      "US",
				Phone:        strPtr("+1234567890"),
			},
		},
		{
			name: "valid with lastName instead of firstName",
			addr: &genaccount.Address{
				LastName:     strPtr("Doe"),
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "GB",
			},
		},
		{
			name: "valid with empty firstName but non-empty lastName",
			addr: &genaccount.Address{
				FirstName:    "",
				LastName:     strPtr("Smith"),
				AddressLine1: "456 Oak Ave",
				City:         "London",
				PostalCode:   "SW1A",
				Country:      "GB",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateAddressFields(tt.addr)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
		})
	}
}

// TestValidateAddressFields_Failures tests invalid address scenarios
func TestValidateAddressFields_Failures(t *testing.T) {
	tests := []struct {
		name          string
		addr          *genaccount.Address
		expectedError string
	}{
		{
			name: "missing addressLine1",
			addr: &genaccount.Address{
				FirstName:  "John",
				City:       "New York",
				PostalCode: "10001",
				Country:    "US",
			},
			expectedError: "addressLine1 is required",
		},
		{
			name: "missing city",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				PostalCode:   "10001",
				Country:      "US",
			},
			expectedError: "city is required",
		},
		{
			name: "missing postalCode",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				Country:      "US",
			},
			expectedError: "postalCode is required",
		},
		{
			name: "missing country",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
			},
			expectedError: "country is required",
		},
		{
			name: "missing firstName and lastName",
			addr: &genaccount.Address{
				FirstName:    "",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "US",
			},
			expectedError: "firstName or lastName is required",
		},
		{
			name: "invalid phone format - too short",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "US",
				Phone:        strPtr("+1"),
			},
			expectedError: "phone format is invalid",
		},
		{
			name: "invalid phone format - with dashes",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "US",
				Phone:        strPtr("+123-456-7890"),
			},
			expectedError: "phone format is invalid",
		},
		{
			name: "invalid country code - too long",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "USA",
			},
			expectedError: "country must be a 2-letter ISO code",
		},
		{
			name: "invalid country code - too short",
			addr: &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "U",
			},
			expectedError: "country must be a 2-letter ISO code",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateAddressFields(tt.addr)
			if err == nil {
				t.Fatalf("expected error, got nil")
			}
			if err.Error() != tt.expectedError {
				t.Fatalf("expected error %q, got %q", tt.expectedError, err.Error())
			}
		})
	}
}

// TestBcryptPasswordHashing tests password hashing and verification
func TestBcryptPasswordHashing(t *testing.T) {
	password := "SecurePassword123!"

	hash, err := bcrypt.GenerateFromPassword([]byte(password), 10)
	if err != nil {
		t.Fatalf("failed to hash password: %v", err)
	}

	// Verify correct password
	err = bcrypt.CompareHashAndPassword(hash, []byte(password))
	if err != nil {
		t.Fatalf("password verification failed for correct password: %v", err)
	}

	// Verify incorrect password
	err = bcrypt.CompareHashAndPassword(hash, []byte("WrongPassword123!"))
	if err == nil {
		t.Fatalf("expected error for incorrect password, got nil")
	}
}

// TestPhoneValidationPatterns tests E.164 phone format validation
func TestPhoneValidationPatterns(t *testing.T) {
	tests := []struct {
		name          string
		phone         string
		shouldBeValid bool
	}{
		{"valid with plus and 11 digits", "+12345678901", true},
		{"valid with plus and 15 digits", "+123456789012345", true},
		{"valid without plus and 11 digits", "12345678901", true},
		{"valid US format", "+1234567890", true},
		{"valid international format", "+447911123456", true},
		{"invalid leading zero", "+01234567890", false},
		{"invalid too short", "+1", false},
		{"invalid with dashes", "+123-456-7890", false},
		{"invalid empty", "", true}, // Empty is valid (phone is optional)
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr := &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "New York",
				PostalCode:   "10001",
				Country:      "US",
				Phone:        strPtr(tt.phone),
			}

			err := validateAddressFields(addr)
			if tt.shouldBeValid && err != nil {
				t.Fatalf("expected valid, got error: %v", err)
			}
			if !tt.shouldBeValid && err == nil {
				t.Fatalf("expected invalid, got nil error")
			}
		})
	}
}

// TestCountryCodeValidation tests ISO 3166-1 alpha-2 country code validation
func TestCountryCodeValidation(t *testing.T) {
	validCountries := []string{"US", "GB", "DE", "FR", "JP", "CN", "IN", "AU", "CA", "MX"}

	for _, country := range validCountries {
		t.Run("valid "+country, func(t *testing.T) {
			addr := &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "City",
				PostalCode:   "12345",
				Country:      country,
			}

			err := validateAddressFields(addr)
			if err != nil {
				t.Fatalf("unexpected error for valid country %s: %v", country, err)
			}
		})
	}

	invalidCountries := []string{"USA", "U", "123"}

	for _, country := range invalidCountries {
		t.Run("invalid "+country, func(t *testing.T) {
			addr := &genaccount.Address{
				FirstName:    "John",
				AddressLine1: "123 Main St",
				City:         "City",
				PostalCode:   "12345",
				Country:      country,
			}

			err := validateAddressFields(addr)
			if err == nil {
				t.Fatalf("expected error for invalid country %s", country)
			}
			if err.Error() != "country must be a 2-letter ISO code" {
				t.Fatalf("expected country code error, got: %v", err)
			}
		})
	}
}

// Helper function
func strPtr(s string) *string {
	return &s
}
