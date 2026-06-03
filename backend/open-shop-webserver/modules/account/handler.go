package account

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	genaccount "open-shop-webserver/gen/account"
	"open-shop-webserver/modules/commons"
)

type AccountHandler struct {
	db        *sql.DB
	auth      *commons.Auth
	providers map[string]commons.OAuthProvider
}

var _ genaccount.ServerInterface = (*AccountHandler)(nil)

func NewHandler(db *sql.DB, auth *commons.Auth, cfg commons.OAuthConfig) *AccountHandler {
	return &AccountHandler{
		db:   db,
		auth: auth,
		providers: map[string]commons.OAuthProvider{
			"google":    commons.NewGoogleOAuthProvider(cfg.Google),
			"microsoft": commons.NewMicrosoftOAuthProvider(cfg.Microsoft),
		},
	}
}

// =============================================================================
// SECTION 1 — OAuth
// =============================================================================

func (handler *AccountHandler) SignInWithOAuth(w http.ResponseWriter, r *http.Request, provider genaccount.SignInWithOAuthParamsProvider) {
	slog.InfoContext(r.Context(), "HandleOAuthSignIn called", "provider", provider)

	var body genaccount.OAuthCallbackRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}
	if body.IdToken == "" {
		http.Error(w, "id_token is required", http.StatusBadRequest)
		return
	}

	p, ok := handler.providers[string(provider)]
	if !ok {
		http.Error(w, "unsupported provider", http.StatusBadRequest)
		return
	}

	userInfo, err := p.ValidateAndGetUserInfo(r.Context(), body.IdToken)
	if err != nil {
		slog.ErrorContext(r.Context(), "token validation failed", "provider", provider, "error", err)
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	customer, isNew, err := handler.getOrCreateCustomer(r.Context(), p, userInfo)
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	refreshToken, err := handler.auth.GenerateRefreshToken()
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	// Use device_type from request, fall back to "api" (DB default)
	deviceType := "api"
	if body.DeviceType != nil {
		deviceType = string(*body.DeviceType)
	}

	sessionID, err := handler.createSession(r.Context(), customer.Id, refreshToken, deviceType, r.RemoteAddr)
	if err != nil {
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	email := ""
	if customer.Email != nil {
		email = *customer.Email
	}
	accessToken, err := handler.auth.GenerateAccessToken(fmt.Sprintf("%d", customer.Id), email, "customer")
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateAccessToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	msg := fmt.Sprintf("Login successful via %s.", provider)
	if isNew {
		msg = fmt.Sprintf("Account created successfully via %s.", provider)
	}

	resp := genaccount.OAuthCallbackResponse{
		IsNewUser:    isNew,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    handler.auth.AccessTokenExpirySeconds(),
		SessionId:    sessionID,
		Customer:     *customer,
		Timestamp:    time.Now().UTC(),
		Message:      &msg,
	}

	err = commons.EncodeJSON(w, http.StatusOK, resp)
	if err != nil {
		slog.ErrorContext(r.Context(), "json encoding failed", "error", err)
	}
}

// =============================================================================
// SECTION 2 — Manual Signup
// =============================================================================

func (handler *AccountHandler) SignUp(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "signup request received")

	var body genaccount.SignupRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.Email == "" || body.Password == "" || body.FirstName == "" || body.LastName == "" {
		http.Error(w, "email, password, firstName, and lastName are required", http.StatusBadRequest)
		return
	}

	if len(body.Password) < 8 || len(body.Password) > 128 {
		http.Error(w, "password must be between 8 and 128 characters", http.StatusBadRequest)
		return
	}

	existingCustomer, err := handler.getCustomerByEmail(r.Context(), body.Email)
	if existingCustomer != nil {
		_ = commons.EncodeJSON(w, http.StatusConflict, map[string]string{"error": "email already registered"})
		return
	}
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		slog.ErrorContext(r.Context(), "getCustomerByEmail failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		slog.ErrorContext(r.Context(), "bcrypt.GenerateFromPassword failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	customer, err := handler.createCustomerWithPassword(r.Context(), body.Email, string(passwordHash), body.FirstName, body.LastName)
	if err != nil {
		slog.ErrorContext(r.Context(), "createCustomerWithPassword failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	refreshToken, err := handler.auth.GenerateRefreshToken()
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	deviceType := "web"
	sessionID, err := handler.createSession(r.Context(), customer.Id, refreshToken, deviceType, r.RemoteAddr)
	if err != nil {
		slog.ErrorContext(r.Context(), "createSession failed", "customer_id", customer.Id, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	accessToken, err := handler.auth.GenerateAccessToken(fmt.Sprintf("%d", customer.Id), body.Email, "customer")
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateAccessToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	msg := "Account created successfully and user authenticated. Please verify your email for full activation."
	resp := genaccount.RegisterResponse{
		Message:      msg,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    handler.auth.AccessTokenExpirySeconds(),
		SessionId:    sessionID,
		Customer:     *customer,
		Timestamp:    time.Now().UTC(),
	}

	_ = commons.EncodeJSON(w, http.StatusCreated, resp)
}

func (handler *AccountHandler) VerifyEmailAddress(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "verify email address received")

	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (handler *AccountHandler) ResendVerificationEmail(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "resend verification email received")

	http.Error(w, "not implemented", http.StatusNotImplemented)
}

// =============================================================================
// SECTION 3 — Manual Login
// =============================================================================

func (handler *AccountHandler) SignIn(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "signin request received")

	var body genaccount.LoginRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.Email == "" || body.Password == "" {
		http.Error(w, "email and password are required", http.StatusBadRequest)
		return
	}

	customer, err := handler.getCustomerByEmail(r.Context(), body.Email)
	if customer == nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}
		slog.ErrorContext(r.Context(), "getCustomerByEmail failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	passwordHash, err := handler.getPasswordHashByEmail(r.Context(), body.Email)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}
		slog.ErrorContext(r.Context(), "getPasswordHashByEmail failed", "email", body.Email, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if passwordHash == "" {
		http.Error(w, "invalid email or password", http.StatusUnauthorized)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(body.Password)); err != nil {
		slog.DebugContext(r.Context(), "password verification failed")
		http.Error(w, "invalid email or password", http.StatusUnauthorized)
		return
	}

	refreshToken, err := handler.auth.GenerateRefreshToken()
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	sessionID, err := handler.createSession(r.Context(), customer.Id, refreshToken, "api", r.RemoteAddr)
	if err != nil {
		slog.ErrorContext(r.Context(), "createSession failed", "customer_id", customer.Id, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	email := ""
	if customer.Email != nil {
		email = *customer.Email
	}
	accessToken, err := handler.auth.GenerateAccessToken(fmt.Sprintf("%d", customer.Id), email, "customer")
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateAccessToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	resp := genaccount.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    new("Bearer"),
		ExpiresIn:    new(handler.auth.AccessTokenExpirySeconds()),
		SessionId:    sessionID,
		Customer:     *customer,
		Timestamp:    time.Now().UTC(),
	}

	_ = commons.EncodeJSON(w, http.StatusOK, resp)
}

func (handler *AccountHandler) RequestPasswordReset(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "request password reset received")

	var body genaccount.PasswordResetRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.Email == "" {
		http.Error(w, "email is required", http.StatusBadRequest)
		return
	}

	customer, err := handler.getCustomerByEmail(r.Context(), body.Email)
	if customer == nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "customer not found", http.StatusNotFound)
			return
		}
		slog.ErrorContext(r.Context(), "getCustomerByEmail failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	resetToken := generateResetToken()
	if err := handler.storeResetToken(r.Context(), customer.Id, resetToken); err != nil {
		slog.ErrorContext(r.Context(), "storeResetToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	_ = commons.EncodeJSON(w, http.StatusOK, map[string]string{"message": "Password reset link sent to email"})
}

func (handler *AccountHandler) ConfirmPasswordReset(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "confirm password reset received")

	var body genaccount.PasswordConfirmRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.Token == "" || body.NewPassword == "" {
		http.Error(w, "token and newPassword are required", http.StatusBadRequest)
		return
	}

	if len(body.NewPassword) < 8 || len(body.NewPassword) > 128 {
		http.Error(w, "password must be between 8 and 128 characters", http.StatusBadRequest)
		return
	}

	customerID, err := handler.validateResetToken(r.Context(), body.Token)
	if err != nil {
		slog.DebugContext(r.Context(), "validateResetToken failed", "error", err)
		http.Error(w, "invalid or expired token", http.StatusUnauthorized)
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		slog.ErrorContext(r.Context(), "bcrypt.GenerateFromPassword failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if err := handler.updateCustomerPassword(r.Context(), customerID, string(passwordHash)); err != nil {
		slog.ErrorContext(r.Context(), "updateCustomerPassword failed", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if err := handler.invalidateCustomerSessions(r.Context(), customerID); err != nil {
		slog.ErrorContext(r.Context(), "invalidateCustomerSessions failed", "customer_id", customerID, "error", err)
	}

	if err := handler.deleteResetToken(r.Context(), body.Token); err != nil {
		slog.ErrorContext(r.Context(), "deleteResetToken failed", "error", err)
	}

	_ = commons.EncodeJSON(w, http.StatusOK, map[string]string{"message": "Password changed successfully"})
}

func (handler *AccountHandler) UpdatePassword(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "update password request received")

	var body genaccount.ChangePasswordRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.CurrentPassword == "" || body.NewPassword == "" {
		http.Error(w, "currentPassword and newPassword are required", http.StatusBadRequest)
		return
	}

	if len(body.NewPassword) < 8 || len(body.NewPassword) > 128 {
		http.Error(w, "password must be between 8 and 128 characters", http.StatusBadRequest)
		return
	}

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	currentPasswordHash, err := handler.getPasswordHashByCustomerID(r.Context(), customerID)
	if err != nil {
		slog.ErrorContext(r.Context(), "getPasswordHashByCustomerID failed", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if currentPasswordHash == "" {
		http.Error(w, "password verification failed", http.StatusUnauthorized)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(currentPasswordHash), []byte(body.CurrentPassword)); err != nil {
		slog.DebugContext(r.Context(), "current password verification failed", "customer_id", customerID)
		http.Error(w, "invalid current password", http.StatusUnauthorized)
		return
	}

	newPasswordHash, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		slog.ErrorContext(r.Context(), "bcrypt.GenerateFromPassword failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if err := handler.updateCustomerPassword(r.Context(), customerID, string(newPasswordHash)); err != nil {
		slog.ErrorContext(r.Context(), "updateCustomerPassword failed", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if err := handler.invalidateCustomerSessions(r.Context(), customerID); err != nil {
		slog.ErrorContext(r.Context(), "invalidateCustomerSessions failed", "customer_id", customerID, "error", err)
	}

	_ = commons.EncodeJSON(w, http.StatusOK, map[string]string{"message": "Password changed successfully"})
}

func (handler *AccountHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "refresh token request received")

	var body genaccount.TokenRefreshRequest
	if r.Body != http.NoBody {
		if err := commons.DecodeJSONBody(w, r, &body); err != nil {
			return
		}
	}

	refreshToken := ""
	if body.RefreshToken != nil && *body.RefreshToken != "" {
		refreshToken = *body.RefreshToken
	}

	if refreshToken == "" {
		cookie, err := r.Cookie("refreshToken")
		if err != nil || cookie.Value == "" {
			http.Error(w, "refresh token is required", http.StatusBadRequest)
			return
		}
		refreshToken = cookie.Value
	}

	hash := sha256.Sum256([]byte(refreshToken))
	refreshTokenHash := hex.EncodeToString(hash[:])

	sessionInfo, err := handler.getSessionByRefreshToken(r.Context(), refreshTokenHash)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "invalid or expired token", http.StatusUnauthorized)
			return
		}
		slog.ErrorContext(r.Context(), "getSessionByRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	newRefreshToken, err := handler.auth.GenerateRefreshToken()
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	newAccessToken, err := handler.auth.GenerateAccessToken(fmt.Sprintf("%d", sessionInfo.CustomerID), sessionInfo.Email, "customer")
	if err != nil {
		slog.ErrorContext(r.Context(), "GenerateAccessToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	newHash := sha256.Sum256([]byte(newRefreshToken))
	newRefreshTokenHash := hex.EncodeToString(newHash[:])

	if err := handler.updateSessionRefreshToken(r.Context(), sessionInfo.SessionID, newRefreshTokenHash); err != nil {
		slog.ErrorContext(r.Context(), "updateSessionRefreshToken failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	http.SetCookie(w, &http.Cookie{
		Name:     "refreshToken",
		Value:    newRefreshToken,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   int(handler.auth.RefreshTokenExpiryDuration().Seconds()),
	})

	resp := genaccount.TokenResponse{
		AccessToken:  newAccessToken,
		RefreshToken: newRefreshToken,
		Timestamp:    time.Now().UTC(),
	}

	_ = commons.EncodeJSON(w, http.StatusOK, resp)
}

// =============================================================================
// SECTION 4 — Logout & Sessions
// =============================================================================

func (handler *AccountHandler) LogoutCustomer(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "logout request received")

	var body genaccount.LogoutRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	if body.SessionId == "" {
		http.Error(w, "sessionId is required", http.StatusBadRequest)
		return
	}

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if err := handler.invalidateSpecificSession(r.Context(), body.SessionId, customerID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "session not found", http.StatusBadRequest)
			return
		}
		slog.ErrorContext(r.Context(), "invalidateSpecificSession failed", "session_id", body.SessionId, "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	http.SetCookie(w, &http.Cookie{
		Name:     "refreshToken",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
	})

	resp := genaccount.LogoutResponse{
		Message:   "Logged out successfully",
		Timestamp: time.Now().UTC(),
	}

	_ = commons.EncodeJSON(w, http.StatusOK, resp)
}

// =============================================================================
// SECTION 5 — Customer Profile
// =============================================================================

func (handler *AccountHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "get profile request received")

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	customer, err := handler.getCustomerByID(r.Context(), customerID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "customer not found", http.StatusNotFound)
			return
		}
		slog.ErrorContext(r.Context(), "getCustomerByID failed", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusOK, customer)
}

func (handler *AccountHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "update profile request received")

	var body genaccount.ProfileUpdateRequest
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	updates := make(map[string]interface{})
	if body.FirstName != nil && *body.FirstName != "" {
		updates["first_name"] = *body.FirstName
	}
	if body.LastName != nil && *body.LastName != "" {
		updates["last_name"] = *body.LastName
	}
	if body.Phone != nil && *body.Phone != "" {
		updates["phone"] = *body.Phone
	}
	if body.DateOfBirth != nil && *body.DateOfBirth != "" {
		updates["date_of_birth"] = *body.DateOfBirth
	}

	if len(updates) == 0 {
		http.Error(w, "no fields to update", http.StatusBadRequest)
		return
	}

	if err := handler.updateCustomerProfile(r.Context(), customerID, updates); err != nil {
		slog.ErrorContext(r.Context(), "updateCustomerProfile failed", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	customer, err := handler.getCustomerByID(r.Context(), customerID)
	if err != nil {
		slog.ErrorContext(r.Context(), "getCustomerByID failed after update", "customer_id", customerID, "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusOK, customer)
}

// =============================================================================
// SECTION 6 — Addresses
// =============================================================================

func (handler *AccountHandler) GetCustomerAddresses(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "get addresses request received")

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	const query = `SELECT id, type, first_name, last_name, company, address_line1, address_line2,
	                      city, state, postal_code, country, phone, is_default, is_validated,
	                      created_at, updated_at
	               FROM customer_addresses WHERE customer_id = :customerId ORDER BY created_at DESC`

	rows, err := handler.db.QueryContext(r.Context(), query, sql.Named("customerId", customerID))
	if err != nil {
		slog.ErrorContext(r.Context(), "QueryContext failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	defer handler.closeRows(r.Context(), rows)

	addresses := make([]genaccount.Address, 0)
	for rows.Next() {
		var id string
		var addrType, lastName, company, addressLine2, state, phone sql.NullString
		var firstName, addressLine1, city, postalCode, country string
		var isDefault, isValidated sql.NullBool
		var createdAt, updatedAt sql.NullTime

		if err := rows.Scan(
			&id, &addrType, &firstName, &lastName, &company, &addressLine1, &addressLine2,
			&city, &state, &postalCode, &country, &phone, &isDefault, &isValidated,
			&createdAt, &updatedAt,
		); err != nil {
			slog.ErrorContext(r.Context(), "Scan failed", "error", err)
			http.Error(w, "internal server error", http.StatusInternalServerError)
			return
		}

		addr := scanAddress(id, addrType, lastName, company, addressLine2, state, phone,
			firstName, addressLine1, city, postalCode, country,
			isDefault, isValidated, createdAt, updatedAt)
		addresses = append(addresses, *addr)
	}

	if err := rows.Err(); err != nil {
		slog.ErrorContext(r.Context(), "rows.Err() failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]interface{}{
		"addresses": addresses,
		"total":     len(addresses),
	}
	_ = commons.EncodeJSON(w, http.StatusOK, resp)
}

func (handler *AccountHandler) AddCustomerAddress(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "add address request received")

	var body genaccount.Address
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if err := validateAddressFields(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	count, err := handler.getCustomerAddressCount(r.Context(), customerID)
	if err != nil {
		slog.ErrorContext(r.Context(), "getCustomerAddressCount failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if count >= 20 {
		http.Error(w, "maximum 20 addresses allowed per customer", http.StatusConflict)
		return
	}

	addressID := uuid.New().String()
	addrType := string(genaccount.Shipping)
	if body.Type != nil {
		addrType = string(*body.Type)
	}

	const query = `INSERT INTO customer_addresses
	               (id, customer_id, type, first_name, last_name, company, address_line1, address_line2,
	                city, state, postal_code, country, phone, is_default, is_validated, created_at, updated_at)
	               VALUES (:id, :customerId, :type, :firstName, :lastName, :company, :addressLine1, :addressLine2,
	                       :city, :state, :postalCode, :country, :phone, :isDefault, :isValidated,
	                       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	_, err = handler.db.ExecContext(r.Context(), query,
		sql.Named("id", addressID),
		sql.Named("customerId", customerID),
		sql.Named("type", addrType),
		sql.Named("firstName", body.FirstName),
		sql.Named("lastName", body.LastName),
		sql.Named("company", body.Company),
		sql.Named("addressLine1", body.AddressLine1),
		sql.Named("addressLine2", body.AddressLine2),
		sql.Named("city", body.City),
		sql.Named("state", body.State),
		sql.Named("postalCode", body.PostalCode),
		sql.Named("country", body.Country),
		sql.Named("phone", body.Phone),
		sql.Named("isDefault", false),
		sql.Named("isValidated", false),
	)
	if err != nil {
		slog.ErrorContext(r.Context(), "InsertContext failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	now := time.Now().UTC()
	body.Id = &addressID
	body.CreatedAt = &now
	body.UpdatedAt = &now
	isDefault := false
	isValidated := false
	body.IsDefault = &isDefault
	body.IsValidated = &isValidated
	addrTypePtr := genaccount.AddressType(addrType)
	body.Type = &addrTypePtr

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusCreated, body)
}

func (handler *AccountHandler) UpdateCustomerAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	slog.InfoContext(r.Context(), "update address request received")

	var body genaccount.Address
	if err := commons.DecodeJSONBody(w, r, &body); err != nil {
		return
	}

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	const checkQuery = `SELECT customer_id FROM customer_addresses WHERE id = :id`
	var ownerID int
	if err := handler.db.QueryRowContext(r.Context(), checkQuery, sql.Named("id", addressId)).Scan(&ownerID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "address not found", http.StatusNotFound)
			return
		}
		slog.ErrorContext(r.Context(), "checkQuery failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if ownerID != customerID {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	updates := make(map[string]interface{})
	if body.FirstName != "" {
		updates["first_name"] = body.FirstName
	}
	if body.LastName != nil {
		updates["last_name"] = *body.LastName
	}
	if body.Company != nil {
		updates["company"] = *body.Company
	}
	if body.AddressLine1 != "" {
		updates["address_line1"] = body.AddressLine1
	}
	if body.AddressLine2 != nil {
		updates["address_line2"] = *body.AddressLine2
	}
	if body.City != "" {
		updates["city"] = body.City
	}
	if body.State != nil {
		updates["state"] = *body.State
	}
	if body.PostalCode != "" {
		updates["postal_code"] = body.PostalCode
	}
	if body.Country != "" {
		updates["country"] = body.Country
	}
	if body.Phone != nil {
		updates["phone"] = *body.Phone
	}
	if body.Type != nil {
		updates["type"] = string(*body.Type)
	}

	if len(updates) == 0 {
		http.Error(w, "no fields to update", http.StatusBadRequest)
		return
	}

	query := `UPDATE customer_addresses SET `
	params := make([]interface{}, 0)
	index := 1

	for key, value := range updates {
		if index > 1 {
			query += ", "
		}
		query += fmt.Sprintf("%s = :%d", key, index)
		params = append(params, value)
		index++
	}

	query += fmt.Sprintf(", updated_at = CURRENT_TIMESTAMP WHERE id = :%d", index)
	params = append(params, addressId)

	if _, err := handler.db.ExecContext(r.Context(), query, params...); err != nil {
		slog.ErrorContext(r.Context(), "UpdateContext failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	addr, err := handler.getAddressByID(r.Context(), addressId, customerID)
	if err != nil {
		slog.ErrorContext(r.Context(), "getAddressByID failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusOK, addr)
}

func (handler *AccountHandler) DeleteCustomerAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	slog.InfoContext(r.Context(), "delete address request received")

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	const checkQuery = `SELECT customer_id, type FROM customer_addresses WHERE id = :id`
	var ownerID int
	var addrType string
	if err := handler.db.QueryRowContext(r.Context(), checkQuery, sql.Named("id", addressId)).Scan(&ownerID, &addrType); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "address not found", http.StatusNotFound)
			return
		}
		slog.ErrorContext(r.Context(), "checkQuery failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if ownerID != customerID {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	const deleteQuery = `DELETE FROM customer_addresses WHERE id = :id`
	if _, err := handler.db.ExecContext(r.Context(), deleteQuery, sql.Named("id", addressId)); err != nil {
		slog.ErrorContext(r.Context(), "DeleteContext failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusOK, map[string]string{"message": "Address deleted successfully"})
}

func (handler *AccountHandler) SetDefaultAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	slog.InfoContext(r.Context(), "set default address request received")

	customerID := getCustomerIDFromContext(r.Context())
	if customerID == 0 {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	const getTypeQuery = `SELECT customer_id, type FROM customer_addresses WHERE id = :id`
	var ownerID int
	var addrType string
	if err := handler.db.QueryRowContext(r.Context(), getTypeQuery, sql.Named("id", addressId)).Scan(&ownerID, &addrType); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "address not found", http.StatusNotFound)
			return
		}
		slog.ErrorContext(r.Context(), "getTypeQuery failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	if ownerID != customerID {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	const clearOthersQuery = `UPDATE customer_addresses SET is_default = 0
	                           WHERE customer_id = :customerId AND type = :type AND id != :id`
	if _, err := handler.db.ExecContext(r.Context(), clearOthersQuery,
		sql.Named("customerId", customerID),
		sql.Named("type", addrType),
		sql.Named("id", addressId)); err != nil {
		slog.ErrorContext(r.Context(), "clearOthersQuery failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	const setDefaultQuery = `UPDATE customer_addresses SET is_default = 1 WHERE id = :id`
	if _, err := handler.db.ExecContext(r.Context(), setDefaultQuery, sql.Named("id", addressId)); err != nil {
		slog.ErrorContext(r.Context(), "setDefaultQuery failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	addr, err := handler.getAddressByID(r.Context(), addressId, customerID)
	if err != nil {
		slog.ErrorContext(r.Context(), "getAddressByID failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = commons.EncodeJSON(w, http.StatusOK, addr)
}

// =============================================================================
// Helpers
// =============================================================================

func (handler *AccountHandler) GetSessions(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "get sessions request received")

	const query = `
		SELECT id, created_at, last_accessed_at, expires_at,
		       device_type, device_name, ip_address, location, is_active
		FROM   customer_sessions
		WHERE  expires_at > CURRENT_TIMESTAMP
		ORDER  BY last_accessed_at DESC`

	rows, err := handler.db.QueryContext(r.Context(), query)
	if err != nil {
		slog.ErrorContext(r.Context(), "ListSessions query failed", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}
	defer handler.closeRows(r.Context(), rows)

	sessions := make([]genaccount.Session, 0)
	for rows.Next() {
		var s genaccount.Session
		var deviceName, ipAddress, location sql.NullString
		var isActive bool
		if err := rows.Scan(
			&s.Id, &s.CreatedAt, &s.LastActiveAt, &s.ExpiresAt,
			&s.DeviceType, &deviceName, &ipAddress, &location, &isActive,
		); err != nil {
			slog.ErrorContext(r.Context(), "ListSessions scan failed", "error", err)
			http.Error(w, "internal server error", http.StatusInternalServerError)
			return
		}
		s.IsCurrent = isActive
		if deviceName.Valid {
			s.DeviceName = &deviceName.String
		}
		if ipAddress.Valid {
			s.IpAddress = &ipAddress.String
		}
		if location.Valid {
			s.Location = &location.String
		}
		sessions = append(sessions, s)
	}
	if err := rows.Err(); err != nil {
		slog.ErrorContext(r.Context(), "ListSessions rows error", "error", err)
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	resp := genaccount.SessionListResponse{
		Sessions:  sessions,
		Timestamp: time.Now().UTC(),
	}

	_ = commons.EncodeJSON(w, http.StatusOK, resp)
}

func (handler *AccountHandler) InvalidateSession(w http.ResponseWriter, r *http.Request, id genaccount.ID) {
	slog.InfoContext(r.Context(), "invalidate session request received")

	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (handler *AccountHandler) InvalidateOtherSessions(w http.ResponseWriter, r *http.Request) {
	slog.InfoContext(r.Context(), "invalidate other sessions request received")

	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (handler *AccountHandler) getOrCreateCustomer(ctx context.Context, p commons.OAuthProvider, info *commons.OAuthUserInfo) (*genaccount.Customer, bool, error) {
	// 1. Look up by provider ID (google_id or microsoft_id)
	customer, err := handler.getCustomerByProviderID(ctx, p, info.ProviderID)
	if err == nil {
		return customer, false, nil
	}

	// 2. Look up by email — link provider ID to existing account
	customer, err = handler.getCustomerByEmail(ctx, info.Email)
	if err == nil {
		if linkErr := handler.linkProviderID(ctx, p, customer.Id, info.ProviderID); linkErr != nil {
			return nil, false, linkErr
		}
		return customer, false, nil
	}

	// 3. Create new customer
	customer, err = handler.createCustomer(ctx, p, info)
	if err != nil {
		return nil, false, err
	}
	return customer, true, nil
}

func (handler *AccountHandler) getCustomerByProviderID(ctx context.Context, p commons.OAuthProvider, providerID string) (*genaccount.Customer, error) {
	query := fmt.Sprintf(
		`SELECT id, email, first_name, last_name, email_verified, created_at, updated_at
		 FROM customers WHERE %s = :providerID`, p.ProviderColumn())
	row := handler.db.QueryRowContext(ctx, query, sql.Named("providerID", providerID))
	customer, err := scanCustomer(row)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		slog.ErrorContext(ctx, "getCustomerByProviderID query failed", "provider_column", p.ProviderColumn(), "error", err)
	}
	return customer, err
}

func (handler *AccountHandler) getCustomerByEmail(ctx context.Context, email string) (*genaccount.Customer, error) {
	const query = `SELECT id, email, first_name, last_name, email_verified, created_at, updated_at
	               FROM customers WHERE email = :email`
	row := handler.db.QueryRowContext(ctx, query, sql.Named("email", email))
	customer, err := scanCustomer(row)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		slog.ErrorContext(ctx, "getCustomerByEmail query failed", "error", err)
	}
	return customer, err
}

func (handler *AccountHandler) getPasswordHashByEmail(ctx context.Context, email string) (string, error) {
	const query = `SELECT password_hash FROM customers WHERE email = :email`
	var passwordHash sql.NullString
	if err := handler.db.QueryRowContext(ctx, query, email).Scan(&passwordHash); err != nil {
		if !errors.Is(err, sql.ErrNoRows) {
			slog.ErrorContext(ctx, "getPasswordHashByEmail query failed", "email", email, "error", err)
		}
		return "", err
	}
	return passwordHash.String, nil
}

// scanCustomer is a package-level function — no receiver needed, pure data mapping.
func scanCustomer(row *sql.Row) (*genaccount.Customer, error) {
	var c genaccount.Customer
	var email sql.NullString
	var emailVerified sql.NullBool
	if err := row.Scan(&c.Id, &email, &c.FirstName, &c.LastName, &emailVerified, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	if email.Valid {
		c.Email = &email.String
	}
	if emailVerified.Valid {
		c.EmailVerified = &emailVerified.Bool
	}
	return &c, nil
}

// scanAddress maps database nullable fields to Address struct
func scanAddress(id string, addrType, lastName, company, addressLine2, state, phone sql.NullString,
	firstName, addressLine1, city, postalCode, country string,
	isDefault, isValidated sql.NullBool,
	createdAt, updatedAt sql.NullTime) *genaccount.Address {
	addr := &genaccount.Address{
		FirstName:    firstName,
		AddressLine1: addressLine1,
		City:         city,
		PostalCode:   postalCode,
		Country:      country,
	}
	addr.Id = &id
	if lastName.Valid {
		addr.LastName = &lastName.String
	}
	if company.Valid {
		addr.Company = &company.String
	}
	if addressLine2.Valid {
		addr.AddressLine2 = &addressLine2.String
	}
	if state.Valid {
		addr.State = &state.String
	}
	if phone.Valid {
		addr.Phone = &phone.String
	}
	if addrType.Valid {
		addrTypeVal := genaccount.AddressType(addrType.String)
		addr.Type = &addrTypeVal
	}
	if isDefault.Valid {
		addr.IsDefault = &isDefault.Bool
	}
	if isValidated.Valid {
		addr.IsValidated = &isValidated.Bool
	}
	if createdAt.Valid {
		addr.CreatedAt = &createdAt.Time
	}
	if updatedAt.Valid {
		addr.UpdatedAt = &updatedAt.Time
	}
	return addr
}

func (handler *AccountHandler) linkProviderID(ctx context.Context, p commons.OAuthProvider, customerID int, providerID string) error {
	query := fmt.Sprintf(
		`UPDATE customers SET %s = :providerID, updated_at = CURRENT_TIMESTAMP WHERE id = :id`,
		p.ProviderColumn())
	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("providerID", providerID),
		sql.Named("id", customerID)); err != nil {
		slog.ErrorContext(ctx, "linkProviderID failed", "provider_column", p.ProviderColumn(), "customer_id", customerID, "error", err)
		return err
	}
	return nil
}

func (handler *AccountHandler) createCustomer(ctx context.Context, p commons.OAuthProvider, info *commons.OAuthUserInfo) (*genaccount.Customer, error) {
	query := fmt.Sprintf(
		`INSERT INTO customers (email, first_name, last_name, %s, email_verified, email_verified_at, created_at, updated_at)
		 VALUES (:email, :firstName, :lastName, :providerID, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
`, p.ProviderColumn())

	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("email", info.Email),
		sql.Named("firstName", info.FirstName),
		sql.Named("lastName", info.LastName),
		sql.Named("providerID", info.ProviderID),
	); err != nil {
		slog.ErrorContext(ctx, "createCustomer insert failed", "email", info.Email, "provider_column", p.ProviderColumn(), "error", err)
		return nil, fmt.Errorf("createCustomer: %w", err)
	}

	return handler.getCustomerByEmail(ctx, info.Email)
}

func (handler *AccountHandler) createCustomerWithPassword(ctx context.Context, email, passwordHash, firstName, lastName string) (*genaccount.Customer, error) {
	const query = `INSERT INTO customers (email, password_hash, first_name, last_name, created_at, updated_at)
	               VALUES (:email, :passwordHash, :firstName, :lastName, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	_, err := handler.db.ExecContext(ctx, query,
		sql.Named("email", email),
		sql.Named("passwordHash", passwordHash),
		sql.Named("firstName", firstName),
		sql.Named("lastName", lastName),
	)
	if err != nil {
		slog.ErrorContext(ctx, "createCustomerWithPassword insert failed", "email", email, "error", err)
		return nil, fmt.Errorf("createCustomerWithPassword: %w", err)
	}

	return handler.getCustomerByEmail(ctx, email)
}

func (handler *AccountHandler) createSession(ctx context.Context, customerID int, refreshToken, deviceType, remoteAddr string) (string, error) {
	sessionUUID := uuid.New()
	sessionIDHex := strings.ReplaceAll(sessionUUID.String(), "-", "")

	// Store hash of refresh token — never store the raw token
	hash := sha256.Sum256([]byte(refreshToken))
	refreshTokenHash := hex.EncodeToString(hash[:])

	// Strip port from remote address
	ipAddress := remoteAddr
	if idx := strings.LastIndex(remoteAddr, ":"); idx != -1 {
		ipAddress = remoteAddr[:idx]
	}

	expiresAt := time.Now().UTC().Add(handler.auth.RefreshTokenExpiryDuration())

	const query = `INSERT INTO customer_sessions
		(id, customer_id, refresh_token, expires_at, device_type, ip_address, is_active, created_at, last_accessed_at)
		VALUES (:id, :customerId, :refreshToken, :expiresAt, :deviceType, :ipAddress, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`

	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("id", sessionIDHex),
		sql.Named("customerId", customerID),
		sql.Named("refreshToken", refreshTokenHash),
		sql.Named("expiresAt", expiresAt),
		sql.Named("deviceType", deviceType),
		sql.Named("ipAddress", ipAddress),
	); err != nil {
		slog.ErrorContext(ctx, "createSession insert failed", "customer_id", customerID, "device_type", deviceType, "error", err)
		return "", fmt.Errorf("createSession: %w", err)
	}

	return sessionUUID.String(), nil
}

func (handler *AccountHandler) getPasswordHashByCustomerID(ctx context.Context, customerID int) (string, error) {
	const query = `SELECT password_hash FROM customers WHERE id = :id`
	var passwordHash sql.NullString
	if err := handler.db.QueryRowContext(ctx, query, sql.Named("id", customerID)).Scan(&passwordHash); err != nil {
		if !errors.Is(err, sql.ErrNoRows) {
			slog.ErrorContext(ctx, "getPasswordHashByCustomerID query failed", "customer_id", customerID, "error", err)
		}
		return "", err
	}
	return passwordHash.String, nil
}

func (handler *AccountHandler) updateCustomerPassword(ctx context.Context, customerID int, passwordHash string) error {
	const query = `UPDATE customers SET password_hash = :passwordHash, updated_at = CURRENT_TIMESTAMP WHERE id = :id`
	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("passwordHash", passwordHash),
		sql.Named("id", customerID)); err != nil {
		slog.ErrorContext(ctx, "updateCustomerPassword failed", "customer_id", customerID, "error", err)
		return fmt.Errorf("updateCustomerPassword: %w", err)
	}
	return nil
}

func (handler *AccountHandler) invalidateCustomerSessions(ctx context.Context, customerID int) error {
	const query = `UPDATE customer_sessions SET is_active = 0 WHERE customer_id = :customerId AND is_active = 1`
	if _, err := handler.db.ExecContext(ctx, query, sql.Named("customerId", customerID)); err != nil {
		slog.ErrorContext(ctx, "invalidateCustomerSessions failed", "customer_id", customerID, "error", err)
		return fmt.Errorf("invalidateCustomerSessions: %w", err)
	}
	return nil
}

func (handler *AccountHandler) invalidateSpecificSession(ctx context.Context, sessionID string, customerID int) error {
	const query = `UPDATE customer_sessions SET is_active = 0 WHERE id = :id AND customer_id = :customerId`
	result, err := handler.db.ExecContext(ctx, query,
		sql.Named("id", sessionID),
		sql.Named("customerId", customerID))
	if err != nil {
		slog.ErrorContext(ctx, "invalidateSpecificSession failed", "session_id", sessionID, "customer_id", customerID, "error", err)
		return fmt.Errorf("invalidateSpecificSession: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		slog.ErrorContext(ctx, "RowsAffected failed", "error", err)
		return fmt.Errorf("RowsAffected: %w", err)
	}

	if rowsAffected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func (handler *AccountHandler) getCustomerByID(ctx context.Context, customerID int) (*genaccount.Customer, error) {
	const query = `SELECT id, email, first_name, last_name, email_verified, created_at, updated_at
	               FROM customers WHERE id = :id`
	row := handler.db.QueryRowContext(ctx, query, sql.Named("id", customerID))
	customer, err := scanCustomer(row)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		slog.ErrorContext(ctx, "getCustomerByID query failed", "customer_id", customerID, "error", err)
	}
	return customer, err
}

func (handler *AccountHandler) updateCustomerProfile(ctx context.Context, customerID int, updates map[string]interface{}) error {
	if len(updates) == 0 {
		return nil
	}

	query := `UPDATE customers SET `
	params := make([]interface{}, 0)
	index := 1

	for key, value := range updates {
		if index > 1 {
			query += ", "
		}
		query += fmt.Sprintf("%s = :%d", key, index)
		params = append(params, value)
		index++
	}

	query += fmt.Sprintf(", updated_at = CURRENT_TIMESTAMP WHERE id = :%d", index)
	params = append(params, customerID)

	if _, err := handler.db.ExecContext(ctx, query, params...); err != nil {
		slog.ErrorContext(ctx, "updateCustomerProfile failed", "customer_id", customerID, "error", err)
		return fmt.Errorf("updateCustomerProfile: %w", err)
	}

	return nil
}

func validateAddressFields(addr *genaccount.Address) error {
	if addr.AddressLine1 == "" {
		return fmt.Errorf("addressLine1 is required")
	}
	if addr.City == "" {
		return fmt.Errorf("city is required")
	}
	if addr.PostalCode == "" {
		return fmt.Errorf("postalCode is required")
	}
	if addr.Country == "" {
		return fmt.Errorf("country is required")
	}

	if addr.FirstName == "" && (addr.LastName == nil || *addr.LastName == "") {
		return fmt.Errorf("firstName or lastName is required")
	}

	if addr.Phone != nil && *addr.Phone != "" {
		phonePattern := regexp.MustCompile(`^\+?[1-9]\d{1,14}$`)
		if !phonePattern.MatchString(*addr.Phone) {
			return fmt.Errorf("phone format is invalid")
		}
	}

	if addr.Country != "" && len(addr.Country) != 2 {
		return fmt.Errorf("country must be a 2-letter ISO code")
	}

	return nil
}

func (handler *AccountHandler) getCustomerAddressCount(ctx context.Context, customerID int) (int, error) {
	const query = `SELECT COUNT(*) FROM customer_addresses WHERE customer_id = :customerId`
	var count int
	if err := handler.db.QueryRowContext(ctx, query, sql.Named("customerId", customerID)).Scan(&count); err != nil {
		slog.ErrorContext(ctx, "getCustomerAddressCount failed", "error", err)
		return 0, err
	}
	return count, nil
}

func (handler *AccountHandler) getAddressByID(ctx context.Context, addressID string, customerID int) (*genaccount.Address, error) {
	const query = `SELECT id, type, first_name, last_name, company, address_line1, address_line2,
	                      city, state, postal_code, country, phone, is_default, is_validated,
	                      created_at, updated_at
	               FROM customer_addresses WHERE id = :id AND customer_id = :customerId`

	var id string
	var addrType, lastName, company, addressLine2, state, phone sql.NullString
	var firstName, addressLine1, city, postalCode, country string
	var isDefault, isValidated sql.NullBool
	var createdAt, updatedAt sql.NullTime

	if err := handler.db.QueryRowContext(ctx, query,
		sql.Named("id", addressID),
		sql.Named("customerId", customerID)).Scan(
		&id, &addrType, &firstName, &lastName, &company, &addressLine1, &addressLine2,
		&city, &state, &postalCode, &country, &phone, &isDefault, &isValidated,
		&createdAt, &updatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, sql.ErrNoRows
		}
		slog.ErrorContext(ctx, "getAddressByID failed", "error", err)
		return nil, err
	}

	return scanAddress(id, addrType, lastName, company, addressLine2, state, phone,
		firstName, addressLine1, city, postalCode, country,
		isDefault, isValidated, createdAt, updatedAt), nil
}

func (handler *AccountHandler) storeResetToken(ctx context.Context, customerID int, token string) error {
	expiresAt := time.Now().UTC().Add(1 * time.Hour)
	const query = `INSERT INTO password_reset_tokens (customer_id, token, expires_at, created_at)
	               VALUES (:customerId, :token, :expiresAt, CURRENT_TIMESTAMP)`
	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("customerId", customerID),
		sql.Named("token", token),
		sql.Named("expiresAt", expiresAt)); err != nil {
		slog.ErrorContext(ctx, "storeResetToken insert failed", "customer_id", customerID, "error", err)
		return fmt.Errorf("storeResetToken: %w", err)
	}
	return nil
}

func (handler *AccountHandler) validateResetToken(ctx context.Context, token string) (int, error) {
	const query = `SELECT customer_id FROM password_reset_tokens
	               WHERE token = :token AND expires_at > CURRENT_TIMESTAMP`
	var customerID int
	if err := handler.db.QueryRowContext(ctx, query, sql.Named("token", token)).Scan(&customerID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, fmt.Errorf("token not found or expired")
		}
		slog.ErrorContext(ctx, "validateResetToken query failed", "error", err)
		return 0, err
	}
	return customerID, nil
}

func (handler *AccountHandler) deleteResetToken(ctx context.Context, token string) error {
	const query = `DELETE FROM password_reset_tokens WHERE token = :token`
	if _, err := handler.db.ExecContext(ctx, query, sql.Named("token", token)); err != nil {
		slog.ErrorContext(ctx, "deleteResetToken failed", "error", err)
		return fmt.Errorf("deleteResetToken: %w", err)
	}
	return nil
}

func generateResetToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return uuid.New().String()
	}
	return hex.EncodeToString(b)
}

func getCustomerIDFromContext(ctx context.Context) int {
	customerID, ok := ctx.Value(commons.CustomerIDKey).(int)
	if !ok {
		return 0
	}
	return customerID
}

type SessionInfo struct {
	SessionID  string
	CustomerID int
	Email      string
	ExpiresAt  time.Time
}

func (handler *AccountHandler) getSessionByRefreshToken(ctx context.Context, refreshTokenHash string) (*SessionInfo, error) {
	const query = `SELECT cs.id, cs.customer_id, c.email, cs.expires_at
	               FROM customer_sessions cs
	               JOIN customers c ON cs.customer_id = c.id
	               WHERE cs.refresh_token = :refreshToken AND cs.expires_at > CURRENT_TIMESTAMP AND cs.is_active = 1`

	var sessionInfo SessionInfo
	if err := handler.db.QueryRowContext(ctx, query, sql.Named("refreshToken", refreshTokenHash)).Scan(
		&sessionInfo.SessionID, &sessionInfo.CustomerID, &sessionInfo.Email, &sessionInfo.ExpiresAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, sql.ErrNoRows
		}
		slog.ErrorContext(ctx, "getSessionByRefreshToken query failed", "error", err)
		return nil, err
	}
	return &sessionInfo, nil
}

func (handler *AccountHandler) updateSessionRefreshToken(ctx context.Context, sessionID, newRefreshTokenHash string) error {
	const query = `UPDATE customer_sessions SET refresh_token = :refreshToken, last_accessed_at = CURRENT_TIMESTAMP WHERE id = :id`
	if _, err := handler.db.ExecContext(ctx, query,
		sql.Named("refreshToken", newRefreshTokenHash),
		sql.Named("id", sessionID)); err != nil {
		slog.ErrorContext(ctx, "updateSessionRefreshToken failed", "session_id", sessionID, "error", err)
		return fmt.Errorf("updateSessionRefreshToken: %w", err)
	}
	return nil
}

// closeRows safely closes database rows and logs any errors
func (handler *AccountHandler) closeRows(ctx context.Context, rows *sql.Rows) {
	if err := rows.Close(); err != nil {
		slog.ErrorContext(ctx, "failed to close rows", "error", err)
	}
}
