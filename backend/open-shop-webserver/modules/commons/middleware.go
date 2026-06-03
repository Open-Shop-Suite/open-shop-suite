package commons

import (
	"context"
	"log/slog"
	"net/http"
	"strconv"
	"strings"

	"github.com/google/uuid"
	genaccount "open-shop-webserver/gen/account"
	genadmin "open-shop-webserver/gen/admin"
	genproduct "open-shop-webserver/gen/product"
)

func RequestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := r.Header.Get("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
		}
		ctx := context.WithValue(r.Context(), RequestIDKey, requestID)
		w.Header().Set("X-Request-ID", requestID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func AuthMiddleware(auth *Auth) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := r.Context()
			// Check if endpoint requires Bearer auth from any module
			requiresAuth := false
			if _, ok := ctx.Value(genaccount.BearerAuthScopes).([]string); ok {
				requiresAuth = true
			} else if _, ok := ctx.Value(genproduct.BearerAuthScopes).([]string); ok {
				requiresAuth = true
			} else if _, ok := ctx.Value(genadmin.AdminBearerAuthScopes).([]string); ok {
				requiresAuth = true
			}

			if requiresAuth {
				claims, err := auth.ValidateToken(extractBearerToken(r))
				if err != nil || claims == nil {
					http.Error(w, "unauthorized", http.StatusUnauthorized)
					return
				}
				customerID, err := strconv.Atoi(claims.CustomerID)
				if err != nil {
					slog.ErrorContext(ctx, "failed to parse customer_id from token", "customer_id", claims.CustomerID, "error", err)
					http.Error(w, "unauthorized", http.StatusUnauthorized)
					return
				}
				ctx = context.WithValue(ctx, CustomerIDKey, customerID)
				r = r.WithContext(ctx)
			}
			next.ServeHTTP(w, r)
		})
	}
}

func extractBearerToken(r *http.Request) string {
	const bearerPrefix = "Bearer "
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, bearerPrefix) {
		return ""
	}
	return auth[len(bearerPrefix):]
}
