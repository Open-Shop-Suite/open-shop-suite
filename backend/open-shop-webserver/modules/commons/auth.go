package commons

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type tokenType string

const (
	accessToken  tokenType = "access"
	refreshToken tokenType = "refresh"
)

type Claims struct {
	CustomerID string    `json:"customer_id"`
	Email      string    `json:"email"`
	Role       string    `json:"role"`
	TokenType  tokenType `json:"token_type"`
	jwt.RegisteredClaims
}

type Auth struct {
	cfg AuthConfig
}

func NewAuth(cfg AuthConfig) *Auth {
	return &Auth{cfg: cfg}
}

func (a *Auth) GenerateAdminToken(adminID, email string) (string, error) {
	claims := &Claims{
		CustomerID: adminID,
		Email:      email,
		Role:       "admin",
		TokenType:  accessToken,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(a.cfg.AccessTokenExpiryMinutes) * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(a.cfg.Secret))
}

func (a *Auth) GenerateAccessToken(customerID, email, role string) (string, error) {
	claims := &Claims{
		CustomerID: customerID,
		Email:      email,
		Role:       role,
		TokenType:  accessToken,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(a.cfg.AccessTokenExpiryMinutes) * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(a.cfg.Secret))
}

// GenerateRefreshToken returns a cryptographically random opaque token.
// It is stored as-is in user_sessions.refresh_token — not a JWT.
func (a *Auth) GenerateRefreshToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", errors.New("failed to generate refresh token")
	}
	return hex.EncodeToString(b), nil
}

func (a *Auth) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(a.cfg.Secret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

func (a *Auth) AccessTokenExpirySeconds() int {
	return a.cfg.AccessTokenExpiryMinutes * 60
}

func (a *Auth) RefreshTokenExpiryDuration() time.Duration {
	return time.Duration(a.cfg.RefreshTokenExpiryDays) * 24 * time.Hour
}
