package commons

import (
	"fmt"

	"github.com/spf13/viper"
)

type AppConfig struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Log      LogConfig      `mapstructure:"log"`
	Auth     AuthConfig     `mapstructure:"auth"`
}

type AuthConfig struct {
	Secret                   string      `mapstructure:"secret"`
	AccessTokenExpiryMinutes int         `mapstructure:"access_token_expiry_minutes"`
	RefreshTokenExpiryDays   int         `mapstructure:"refresh_token_expiry_days"`
	OAuth                    OAuthConfig `mapstructure:"oauth"`
}

type OAuthConfig struct {
	Google    GoogleOAuthConfig    `mapstructure:"google"`
	Microsoft MicrosoftOAuthConfig `mapstructure:"microsoft"`
}

type GoogleOAuthConfig struct {
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
}

type MicrosoftOAuthConfig struct {
	ClientID     string `mapstructure:"client_id"`
	ClientSecret string `mapstructure:"client_secret"`
	TenantID     string `mapstructure:"tenant_id"`
}

type ServerConfig struct {
	Port int `mapstructure:"port"`
}

type LogConfig struct {
	Level  string `mapstructure:"level"`  // debug | info | warn | error
	Format string `mapstructure:"format"` // text | json
}

func LoadConfig(path string) (*AppConfig, error) {
	viper.SetConfigFile(path)
	viper.SetConfigType("toml")

	// Bind environment variables to config keys
	// Viper will use env var value if set, otherwise use config file value
	viper.BindEnv("auth.secret", "AUTH_SECRET")
	viper.BindEnv("auth.oauth.google.client_id", "GOOGLE_CLIENT_ID")
	viper.BindEnv("auth.oauth.google.client_secret", "GOOGLE_CLIENT_SECRET")
	viper.BindEnv("auth.oauth.microsoft.client_id", "AZURE_CLIENT_ID")
	viper.BindEnv("auth.oauth.microsoft.client_secret", "AZURE_CLIENT_SECRET")
	viper.BindEnv("auth.oauth.microsoft.tenant_id", "AZURE_TENANT_ID")
	viper.BindEnv("database.password", "DB_PASSWORD")

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}

	var cfg AppConfig
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}

	return &cfg, nil
}
