package main

import (
	"log"
	"net/http"
	"os"

	genaccount "open-shop-webserver/gen/account"
	genadmin   "open-shop-webserver/gen/admin"
	genproduct "open-shop-webserver/gen/product"
	"open-shop-webserver/modules/account"
	"open-shop-webserver/modules/admin"
	"open-shop-webserver/modules/product"
)

type Server struct {
	*account.AccountHandler
	*product.ProductHandler
	*admin.AdminHandler
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()

	server := &Server{
		AccountHandler: account.NewAccountHandler(),
		ProductHandler: product.NewProductHandler(),
		AdminHandler:   admin.NewAdminHandler(),
	}

	genaccount.HandlerFromMux(server, mux)
	genproduct.HandlerFromMux(server, mux)
	genadmin.HandlerFromMux(server, mux)

	log.Printf("server listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
