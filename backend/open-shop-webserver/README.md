# Open Shop Web Server

Go HTTP backend for the Open Shop e-commerce platform.

## Prerequisites

- Go 1.26+
- `oapi-codegen` v2.6.0

Install `oapi-codegen`:

```bash
go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest
```

## Build and Run

All commands are run from the `backend/` directory.

### Run (development)

```bash
make run
```

### Build binary

```bash
make build
```

Outputs binary to `open-shop-webserver/bin/server`.

### Run binary directly

```bash
./open-shop-webserver/bin/server
```

With environment variables:

```bash
PORT=8080 DB_URL=oracle://user:pass@host/dbname ./open-shop-webserver/bin/server
```

### Clean

```bash
make clean
```

Removes generated files and the binary.

---

## Project Structure

```
open-shop-webserver/
├── cmd/
│   └── server/
│       └── main.go               ← entry point, wires all modules together
├── gen/                          ← auto-generated from spec, never edit manually
│   ├── types.gen.go              ← all request/response models
│   ├── account.gen.go            ← account ServerInterface + router wiring
│   ├── product.gen.go            ← product ServerInterface + router wiring
│   └── admin.gen.go              ← admin ServerInterface + router wiring
├── modules/
│   ├── account/                  ← auth, OAuth, profile, sessions, addresses
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── repository.go
│   ├── product/                  ← catalog, search, cart, orders, reviews, wishlist
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── repository.go
│   └── admin/                    ← inventory, orders, analytics, customers
│       ├── handler.go
│       ├── service.go
│       └── repository.go
├── shared/
│   ├── middleware/               ← JWT auth, logging, rate limiting
│   └── db/                      ← Oracle DB connection pool setup
├── go.mod
└── go.sum
```

---

## API Specification

The OpenAPI spec is the source of truth for all endpoints, models, and tag groupings.

```
backend/
└── open-shop-Api-spec/
    ├── open-shop-api-spec.yaml   ← OpenAPI 3.0.3 spec
    ├── oapi-types.yaml           ← codegen config: shared models
    ├── oapi-account.yaml         ← codegen config: account module
    ├── oapi-product.yaml         ← codegen config: product module
    └── oapi-admin.yaml           ← codegen config: admin module
```

Regenerate code whenever the spec changes:

```bash
make generate
```

| Generated file | Interface | Tag filter |
|---|---|---|
| `gen/account.gen.go` | 22 handler methods | `account` |
| `gen/product.gen.go` | 24 handler methods | `product` |
| `gen/admin.gen.go` | 15 handler methods | `admin` |
| `gen/types.gen.go` | all models | — |

Each module's `handler.go` implements its respective `ServerInterface`. The `main.go` composes all three into a single server via struct embedding.
