package commons

import (
	"context"
	"log/slog"
	"os"
)

type contextKey string

const (
	RequestIDKey  contextKey = "request_id"
	TenantIDKey   contextKey = "tenant_id"
	UserIDKey     contextKey = "user_id"
	CustomerIDKey contextKey = "customer_id"
)

type contextHandler struct {
	handler slog.Handler
}

func (h *contextHandler) Handle(ctx context.Context, r slog.Record) error {
	if requestID, ok := ctx.Value(RequestIDKey).(string); ok {
		r.AddAttrs(slog.String("request_id", requestID))
	}
	if tenantID, ok := ctx.Value(TenantIDKey).(string); ok {
		r.AddAttrs(slog.String("tenant_id", tenantID))
	}
	if userID, ok := ctx.Value(UserIDKey).(string); ok {
		r.AddAttrs(slog.String("user_id", userID))
	}
	if customerID, ok := ctx.Value(CustomerIDKey).(int); ok {
		r.AddAttrs(slog.Int("customer_id", customerID))
	}
	return h.handler.Handle(ctx, r)
}

func (h *contextHandler) Enabled(ctx context.Context, level slog.Level) bool {
	return h.handler.Enabled(ctx, level)
}

func (h *contextHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &contextHandler{handler: h.handler.WithAttrs(attrs)}
}

func (h *contextHandler) WithGroup(name string) slog.Handler {
	return &contextHandler{handler: h.handler.WithGroup(name)}
}

func InitLogger(cfg LogConfig) *slog.Logger {
	var level slog.Level
	if err := level.UnmarshalText([]byte(cfg.Level)); err != nil {
		level = slog.LevelInfo
	}

	opts := &slog.HandlerOptions{Level: level}

	var base slog.Handler
	if cfg.Format == "json" {
		base = slog.NewJSONHandler(os.Stdout, opts)
	} else {
		base = slog.NewTextHandler(os.Stdout, opts)
	}

	return slog.New(&contextHandler{handler: base})
}
