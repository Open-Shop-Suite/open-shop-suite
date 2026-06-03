package main

import (
	"flag"
	"fmt"
	"log"
	"log/slog"
	"net/http"

	genaccount "open-shop-webserver/gen/account"
	genadmin "open-shop-webserver/gen/admin"
	genproduct "open-shop-webserver/gen/product"
	"open-shop-webserver/modules/account"
	"open-shop-webserver/modules/admin"
	"open-shop-webserver/modules/commons"
	"open-shop-webserver/modules/product"
)

type Server struct {
	*account.AccountHandler
	*product.ProductHandler
	*admin.AdminHandler
}

func main() {
	configPath := flag.String("config", "config/dev.toml", "path to config file")
	flag.Parse()

	cfg, err := commons.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	slog.SetDefault(commons.InitLogger(cfg.Log))

	db, err := commons.NewDB(cfg.Database)
	if err != nil {
		slog.Error("db connection failed", "error", err)
		log.Fatal(err)
	}
	sqlDB := db.GetConnection()
	auth := commons.NewAuth(cfg.Auth)

	mux := http.NewServeMux()

	server := &Server{
		account.NewHandler(sqlDB, auth, cfg.Auth.OAuth),
		product.NewHandler(),
		admin.NewHandler(),
	}

	authMW := commons.AuthMiddleware(auth)

	genaccount.HandlerWithOptions(server, genaccount.StdHTTPServerOptions{
		BaseRouter:  mux,
		Middlewares: []genaccount.MiddlewareFunc{commons.RequestIDMiddleware, authMW},
	})
	genproduct.HandlerWithOptions(server, genproduct.StdHTTPServerOptions{
		BaseRouter:  mux,
		Middlewares: []genproduct.MiddlewareFunc{commons.RequestIDMiddleware, authMW},
	})
	genadmin.HandlerWithOptions(server, genadmin.StdHTTPServerOptions{
		BaseRouter:  mux,
		Middlewares: []genadmin.MiddlewareFunc{commons.RequestIDMiddleware, authMW},
	})

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	slog.Info("server starting", "addr", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
