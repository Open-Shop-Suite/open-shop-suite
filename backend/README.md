# Open Shop Backend

Backend services for the Open Shop e-commerce platform.

## Structure

```
backend/
├── open-shop-Api-spec/     # API specifications and documentation
└── open-shop-web-server/   # Go Fiber web server application
```

## Components

### API Specification (`open-shop-Api-spec/`)
- OpenAPI/Swagger documentation
- API contract definitions
- Schema validation rules
- Documentation for all endpoints

### Web Server (`open-shop-web-server/`)
- Go Fiber-based REST API implementation
- Main backend server application

## Technology Stack

- **Framework**: Go Fiber v2
- **Documentation**: OpenAPI/Swagger

## Getting Started

### Prerequisites
- Go 1.19 or higher

### Development
```bash
# Install dependencies
go mod download

# Start development server
go run main.go

# Build for production
go build -o bin/server main.go
```