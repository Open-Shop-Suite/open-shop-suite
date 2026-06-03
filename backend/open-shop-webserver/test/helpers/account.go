package helpers

import (
	"context"
	"database/sql"
	"net/http"
	"testing"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"

	"open-shop-webserver/modules/commons"
)

// SetupTestDB creates and initializes an in-memory SQLite database for testing
func SetupTestDB(t *testing.T) *sql.DB {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("failed to open in-memory database: %v", err)
	}

	// Create tables
	if err := CreateTestTables(db); err != nil {
		t.Fatalf("failed to create tables: %v", err)
	}

	return db
}

// CreateTestAuth creates a minimal Auth instance for testing
func CreateTestAuth() *commons.Auth {
	cfg := commons.AuthConfig{
		Secret:                   "test-secret-key-for-testing-only",
		AccessTokenExpiryMinutes: 15,
		RefreshTokenExpiryDays:   7,
	}
	return commons.NewAuth(cfg)
}

// AddCustomerToContext adds customer ID to request context
func AddCustomerToContext(req *http.Request, customerID int) *http.Request {
	ctx := req.Context()
	ctx = context.WithValue(ctx, commons.CustomerIDKey, customerID)
	return req.WithContext(ctx)
}

// CreateTestTables creates the necessary schema for testing
func CreateTestTables(db *sql.DB) error {
	schema := `
	CREATE TABLE IF NOT EXISTS customers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		email TEXT UNIQUE NOT NULL,
		first_name TEXT NOT NULL,
		last_name TEXT,
		password_hash TEXT NOT NULL,
		phone TEXT,
		date_of_birth TEXT,
		email_verified BOOLEAN DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS customer_sessions (
		id TEXT PRIMARY KEY,
		customer_id INTEGER NOT NULL,
		refresh_token TEXT NOT NULL,
		device_type TEXT,
		device_name TEXT,
		ip_address TEXT,
		location TEXT,
		is_active BOOLEAN DEFAULT 1,
		expires_at DATETIME NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		last_accessed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (customer_id) REFERENCES customers(id)
	);

	CREATE TABLE IF NOT EXISTS customer_addresses (
		id TEXT PRIMARY KEY,
		customer_id INTEGER NOT NULL REFERENCES customers(id),
		type TEXT DEFAULT 'shipping',
		first_name TEXT NOT NULL,
		last_name TEXT,
		company TEXT,
		address_line1 TEXT NOT NULL,
		address_line2 TEXT,
		city TEXT NOT NULL,
		state TEXT,
		postal_code TEXT NOT NULL,
		country TEXT NOT NULL,
		phone TEXT,
		is_default BOOLEAN DEFAULT 0,
		is_validated BOOLEAN DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (customer_id) REFERENCES customers(id)
	);

	CREATE TABLE IF NOT EXISTS password_reset_tokens (
		id TEXT PRIMARY KEY,
		customer_id INTEGER NOT NULL,
		token TEXT NOT NULL,
		expires_at DATETIME NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (customer_id) REFERENCES customers(id)
	);
	`

	_, err := db.Exec(schema)
	return err
}

// CreateTestCustomer creates a test customer and returns the ID
func CreateTestCustomer(t *testing.T, db *sql.DB, email, firstName, lastName, password string) int {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), 10)
	if err != nil {
		t.Fatalf("failed to hash password: %v", err)
	}

	result, err := db.Exec(
		`INSERT INTO customers (email, first_name, last_name, password_hash, email_verified)
		 VALUES (?, ?, ?, ?, 1)`,
		email, firstName, lastName, string(hashedPassword),
	)
	if err != nil {
		t.Fatalf("failed to create test customer: %v", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		t.Fatalf("failed to get customer ID: %v", err)
	}

	return int(id)
}

// CreateTestSession creates a test session for a customer
func CreateTestSession(t *testing.T, db *sql.DB, sessionID string, customerID int, refreshToken string) {
	expiresAt := time.Now().Add(7 * 24 * time.Hour).Format(time.RFC3339)

	_, err := db.Exec(
		`INSERT INTO customer_sessions (id, customer_id, refresh_token, expires_at)
		 VALUES (?, ?, ?, ?)`,
		sessionID, customerID, refreshToken, expiresAt,
	)
	if err != nil {
		t.Fatalf("failed to create test session: %v", err)
	}
}

// CreateTestAddress creates a test address for a customer
func CreateTestAddress(t *testing.T, db *sql.DB, addressID string, customerID int, firstName, addressLine1, city, postalCode, country string) {
	_, err := db.Exec(
		`INSERT INTO customer_addresses (id, customer_id, first_name, address_line1, city, postal_code, country)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		addressID, customerID, firstName, addressLine1, city, postalCode, country,
	)
	if err != nil {
		t.Fatalf("failed to create test address: %v", err)
	}
}
