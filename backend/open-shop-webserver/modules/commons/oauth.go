package commons

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// =============================================================================
// Provider Interface
// =============================================================================

type OAuthUserInfo struct {
	ProviderID string
	Email      string
	FirstName  string
	LastName   string
}

type OAuthProvider interface {
	ValidateAndGetUserInfo(ctx context.Context, token string) (*OAuthUserInfo, error)
	ProviderColumn() string // DB column name: "google_id" or "microsoft_id"
}

// =============================================================================
// Google
// =============================================================================

type GoogleOAuthProvider struct {
	cfg GoogleOAuthConfig
}

func NewGoogleOAuthProvider(cfg GoogleOAuthConfig) *GoogleOAuthProvider {
	return &GoogleOAuthProvider{cfg: cfg}
}

func (g *GoogleOAuthProvider) ProviderColumn() string { return "google_id" }

func (g *GoogleOAuthProvider) ValidateAndGetUserInfo(ctx context.Context, idToken string) (*OAuthUserInfo, error) {
	data := url.Values{}
	data.Set("id_token", idToken)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://oauth2.googleapis.com/tokeninfo", strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("google: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("google: tokeninfo call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("google: invalid id_token (status %d)", resp.StatusCode)
	}

	var claims struct {
		Sub        string `json:"sub"`
		Email      string `json:"email"`
		GivenName  string `json:"given_name"`
		FamilyName string `json:"family_name"`
		Aud        string `json:"aud"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&claims); err != nil {
		return nil, fmt.Errorf("google: decode response: %w", err)
	}

	if claims.Sub == "" || claims.Email == "" {
		return nil, fmt.Errorf("google: missing sub or email in token")
	}
	if claims.Aud != g.cfg.ClientID {
		return nil, fmt.Errorf("google: token audience mismatch")
	}

	return &OAuthUserInfo{
		ProviderID: claims.Sub,
		Email:      claims.Email,
		FirstName:  claims.GivenName,
		LastName:   claims.FamilyName,
	}, nil
}

// =============================================================================
// Microsoft
// =============================================================================

type MicrosoftOAuthProvider struct {
	cfg MicrosoftOAuthConfig
}

func NewMicrosoftOAuthProvider(cfg MicrosoftOAuthConfig) *MicrosoftOAuthProvider {
	return &MicrosoftOAuthProvider{cfg: cfg}
}

func (m *MicrosoftOAuthProvider) ProviderColumn() string { return "microsoft_id" }

func (m *MicrosoftOAuthProvider) ValidateAndGetUserInfo(ctx context.Context, accessToken string) (*OAuthUserInfo, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://graph.microsoft.com/v1.0/me", nil)
	if err != nil {
		return nil, fmt.Errorf("microsoft: build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("microsoft: graph call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("microsoft: invalid token (status %d)", resp.StatusCode)
	}

	var profile struct {
		ID                string `json:"id"`
		Mail              string `json:"mail"`
		UserPrincipalName string `json:"userPrincipalName"`
		GivenName         string `json:"givenName"`
		Surname           string `json:"surname"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&profile); err != nil {
		return nil, fmt.Errorf("microsoft: decode response: %w", err)
	}

	if profile.ID == "" {
		return nil, fmt.Errorf("microsoft: missing id in profile")
	}

	email := profile.Mail
	if email == "" {
		email = profile.UserPrincipalName
	}
	if email == "" {
		return nil, fmt.Errorf("microsoft: no email found in profile")
	}

	return &OAuthUserInfo{
		ProviderID: profile.ID,
		Email:      email,
		FirstName:  profile.GivenName,
		LastName:   profile.Surname,
	}, nil
}
