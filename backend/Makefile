SPEC                 := open-shop-Api-spec/open-shop-api-spec.yaml
SPEC_DIR             := open-shop-Api-spec
SERVER               := open-shop-webserver
GOPATH               := $(shell go env GOPATH)
CODEGEN              := $(GOPATH)/bin/oapi-codegen
OAPI_CODEGEN_VERSION := v2.6.0
BIN                  := $(SERVER)/bin/server

.PHONY: generate build run clean

$(CODEGEN):
	go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@$(OAPI_CODEGEN_VERSION)

generate: $(CODEGEN)
	mkdir -p $(SERVER)/gen/account
	mkdir -p $(SERVER)/gen/product
	mkdir -p $(SERVER)/gen/admin
	cd $(SERVER) && $(CODEGEN) --config=../$(SPEC_DIR)/oapi-account.yaml ../$(SPEC)
	cd $(SERVER) && $(CODEGEN) --config=../$(SPEC_DIR)/oapi-product.yaml ../$(SPEC)
	cd $(SERVER) && $(CODEGEN) --config=../$(SPEC_DIR)/oapi-admin.yaml   ../$(SPEC)

build: generate
	cd $(SERVER) && go build -o bin/server ./cmd/server/...

run: generate
	cd $(SERVER) && go run ./cmd/server/...

clean:
	rm -f $(SERVER)/gen/account/account.gen.go
	rm -f $(SERVER)/gen/product/product.gen.go
	rm -f $(SERVER)/gen/admin/admin.gen.go
	rm -f $(BIN)
