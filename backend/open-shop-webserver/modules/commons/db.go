package commons

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/godror/godror"
	_ "github.com/jackc/pgx/v5/stdlib"
)

type PoolConfig struct {
	MaxOpenConns    int `mapstructure:"max_open_conns"`
	MaxIdleConns    int `mapstructure:"max_idle_conns"`
	ConnMaxLifetime int `mapstructure:"conn_max_lifetime"`
	ConnMaxIdleTime int `mapstructure:"conn_max_idle_time"`
}

type DatabaseConfig struct {
	Driver   string     `mapstructure:"driver"`
	Host     string     `mapstructure:"host"`
	Port     int        `mapstructure:"port"`
	Name     string     `mapstructure:"name"`
	User     string     `mapstructure:"user"`
	Password string     `mapstructure:"password"`
	SSLMode  string     `mapstructure:"ssl_mode"`
	Pool     PoolConfig `mapstructure:"pool"`
}

type DB struct {
	pool *sql.DB
}

// NewDB opens a single shared connection pool and verifies reachability.
// The returned *DB is safe for concurrent use across all handlers.
func NewDB(cfg DatabaseConfig) (*DB, error) {
	dsn, err := buildDSN(cfg)
	if err != nil {
		return nil, err
	}

	pool, err := sql.Open(cfg.Driver, dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	p := cfg.Pool
	if p.MaxOpenConns > 0 {
		pool.SetMaxOpenConns(p.MaxOpenConns)
	}
	if p.MaxIdleConns > 0 {
		pool.SetMaxIdleConns(p.MaxIdleConns)
	}
	if p.ConnMaxLifetime > 0 {
		pool.SetConnMaxLifetime(time.Duration(p.ConnMaxLifetime) * time.Second)
	}
	if p.ConnMaxIdleTime > 0 {
		pool.SetConnMaxIdleTime(time.Duration(p.ConnMaxIdleTime) * time.Second)
	}

	if err := pool.Ping(); err != nil {
		_ = pool.Close()
		return nil, fmt.Errorf("ping db: %w", err)
	}

	return &DB{pool: pool}, nil
}

func (d *DB) GetConnection() *sql.DB {
	return d.pool
}

func buildDSN(cfg DatabaseConfig) (string, error) {
	switch cfg.Driver {
	case "pgx":
		return fmt.Sprintf(
			"host=%s port=%d dbname=%s user=%s password=%s sslmode=%s",
			cfg.Host, cfg.Port, cfg.Name, cfg.User, cfg.Password, cfg.SSLMode,
		), nil
	case "mysql":
		return fmt.Sprintf(
			"%s:%s@tcp(%s:%d)/%s?parseTime=true",
			cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name,
		), nil
	case "godror":
		return fmt.Sprintf(
			`user="%s" password="%s" connectString="%s:%d/%s"`,
			cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name,
		), nil
	default:
		return "", fmt.Errorf("unsupported driver: %s (use pgx, mysql, or godror)", cfg.Driver)
	}
}
