# Open Shop E-commerce Database Schema

A comprehensive, multi-database DDL implementation for the Open Shop e-commerce platform, supporting MySQL, PostgreSQL, and Oracle Database Free with Maven-based deployment automation.

## Overview

This database schema is designed based on the OpenAPI 3.1.0 specification and provides a complete e-commerce solution with support for:

- **Customer Management**: Authentication, profiles, addresses, and OAuth integration
- **Product Catalog**: Products, variants, categories, suppliers, and searchable attributes
- **Shopping Experience**: Cart functionality, wishlists, and abandonment tracking
- **Order Processing**: Complete order lifecycle with payment and shipping integration
- **Community Features**: Reviews, ratings, and customer feedback system

## Database Support

### MySQL 8.0+
- InnoDB storage engine optimizations
- JSON data type for flexible attributes
- Full-text search capabilities
- Comprehensive indexing strategy

### PostgreSQL 13+
- JSONB for high-performance JSON operations
- Advanced full-text search with ranking
- Generated columns and partial indexes
- Array data types for complex attributes

### Oracle Database Free (21c+)
- Basic JSON data type support
- Function-based indexes for case-insensitive search
- Standard Oracle constraints and triggers
- Compatible with Oracle Database Free tier limitations

## Architecture

The database schema uses a **single comprehensive migration approach** for better IDE navigation and symbol jumping:

### Current Structure
```
open-shop-database/
├── db/migration/
│   ├── mysql/
│   │   └── V001__initial_open_shop_schema.sql    # Complete MySQL schema
│   ├── postgresql/
│   │   └── V001__initial_open_shop_schema.sql    # Complete PostgreSQL schema
│   └── oracle/
│       └── V001__initial_open_shop_schema.sql    # Complete Oracle schema
├── docs/                                         # Project documentation
│   ├── schema_analysis.md
│   ├── migration_plan.md
│   └── domain_dependencies.md
├── flyway.conf                                   # Flyway configuration
├── pom.xml                                       # Maven build configuration
└── README.md                                     # This file
```

### Business Domains Covered
1. **System Foundation**: Core infrastructure, sessions, and audit trails
2. **Customer Management**: Authentication, profiles, addresses, and preferences  
3. **Product Catalog**: Products, variants, categories, suppliers, and attributes
4. **Shopping Experience**: Carts, wishlists, and customer interactions
5. **Order Management**: Orders, payments, shipping, reviews, and coupons

## Quick Start

### Prerequisites

- **Java**: Version 17 or higher
- **Maven**: Version 3.6 or higher
- **Database**: One of MySQL 8.0+, PostgreSQL 13+, or Oracle Database Free 21c+

### Setup Instructions

1. **Clone and Navigate**
   ```bash
   git clone <repository-url>
   cd open-shop-database
   ```

2. **Configure Database Connection**

   Edit `flyway.conf` and uncomment your database section. Use a **system admin user** (with full database privileges) for migrations:

   ```properties
   # For MySQL
   flyway.url=jdbc:mysql://localhost:3306/openshop?useSSL=true&serverTimezone=UTC&allowPublicKeyRetrieval=true
   flyway.user=root
   flyway.password=your_admin_password
   flyway.locations=filesystem:db/migration/mysql
   flyway.schemas=openshop
   ```

   ```properties
   # For PostgreSQL
   flyway.url=jdbc:postgresql://localhost:5432/openshop?sslmode=prefer
   flyway.user=postgres
   flyway.password=your_admin_password
   flyway.locations=filesystem:db/migration/postgresql
   flyway.schemas=openshop
   ```

   ```properties
   # For Oracle
   flyway.url=jdbc:oracle:thin:@//localhost:1521/freepdb1
   flyway.user=system
   flyway.password=your_admin_password
   flyway.locations=filesystem:db/migration/oracle
   flyway.schemas=openshop
   ```

3. **Deploy Database Schema**
   ```bash
   # Deploy migrations
   mvn flyway:migrate

   # Check migration status
   mvn flyway:info

   # Validate migration checksums
   mvn flyway:validate
   ```

### Database-Specific Setup

**Note:** Flyway uses a system admin user for migrations. Create a web-server user for runtime operations:

- **Flyway User**: System admin user (e.g., `root`, `postgres`, `system`) with full database privileges to create schemas, tables, views, etc.
- **Web-Server User** (e.g., `app_user`): Limited privileges for application runtime operations (SELECT, INSERT, UPDATE, DELETE) on the openshop schema

#### MySQL Setup
```sql
-- Create web-server user with broad privileges
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_app_password';

-- Grant privileges for DML and Query on ALL databases/schemas
GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'app_user'@'%';
GRANT EXECUTE ON *.* TO 'app_user'@'%';

FLUSH PRIVILEGES;
```

#### PostgreSQL Setup
```sql
-- Create web-server user with limited privileges (Flyway handles database/schema creation)
CREATE USER app_user WITH ENCRYPTED PASSWORD 'secure_app_password';
GRANT CONNECT ON DATABASE openshop TO app_user;
GRANT USAGE ON SCHEMA openshop TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA openshop TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA openshop TO app_user;

-- Grant permissions on future tables/sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA openshop GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA openshop GRANT USAGE, SELECT ON SEQUENCES TO app_user;
```

#### Oracle Setup
```sql
-- 1. Create the web-server user with a secure password
CREATE USER app_user IDENTIFIED BY "secure_app_password"
DEFAULT TABLESPACE users;

-- 2. Grant the CONNECT permission (minimum to log in)
GRANT CREATE SESSION TO app_user;

-- 3. Grant privileges for DML and Query on ALL schemas
-- Allows app_user to SELECT from tables/views in any schema (e.g., openshop.products)
GRANT SELECT ANY TABLE TO app_user;

-- Allows app_user to INSERT into tables in any schema
GRANT INSERT ANY TABLE TO app_user;

-- Allows app_user to UPDATE rows in tables in any schema
GRANT UPDATE ANY TABLE TO app_user;

-- Allows app_user to DELETE rows from tables in any schema
GRANT DELETE ANY TABLE TO app_user;

-- Allows app_user to EXECUTE procedures/functions/packages in any schema
GRANT EXECUTE ANY PROCEDURE TO app_user;

-- Grant privilege for using sequences 
GRANT SELECT ANY SEQUENCE TO app_user;
    
COMMIT;
```

## Key Features

### Enhanced E-commerce Schema
- **Supplier Management**: Complete vendor/supplier tracking with lead times and minimum orders
- **EAV Product Attributes**: Queryable product attributes using Entity-Attribute-Value model
- **Wishlist System**: Multiple wishlists per customer with sharing capabilities
- **Advanced Cart Features**: Real-time inventory checking, coupon support, abandonment tracking

### Performance Optimizations
- Database-specific indexing strategies
- Function-based indexes for search optimization
- Composite indexes for common query patterns
- JSON path indexing where supported

### Security & Compliance
- Complete audit trail for all data changes
- Soft delete patterns for data retention
- OAuth integration (Google, Facebook, LinkedIn)
- GDPR-compliant customer data handling

## Maven Integration

The project uses Maven with Flyway plugin for automated database deployments:

### Key Maven Commands
```bash
# Deploy all pending migrations
mvn flyway:migrate

# Show migration status and history
mvn flyway:info

# Validate migration checksums
mvn flyway:validate

# Clean database (development only!)
mvn flyway:clean

# Repair metadata table if needed
mvn flyway:repair
```

### Configuration Management
- Single `flyway.conf` file for all configuration
- Environment variable support for sensitive data
- No duplicate configuration between Maven and Flyway
- Profile-free approach - configuration driven by flyway.conf

## Data Model Highlights

### Customer Management
- OAuth integration with major providers
- Multiple address management with validation
- Flexible customer preferences using JSON
- Session management and security tracking

### Product Catalog
- Hierarchical category structure with suppliers
- Product variants with individual pricing and inventory
- EAV model for queryable product attributes
- Image management with multiple types and colors

### Shopping Experience
- Real-time cart calculations with tax and shipping estimates
- Multiple wishlists per customer with privacy controls
- Coupon system with usage tracking and expiration
- Cart abandonment tracking for marketing

### Order Processing
- Comprehensive order lifecycle management
- Payment provider integration with transaction tracking
- Shipping carrier integration with tracking numbers
- Review and rating system with moderation

## Maintenance & Monitoring

### Regular Tasks
- **Daily**: Monitor slow queries and optimize as needed
- **Weekly**: Check database statistics and update if necessary
- **Monthly**: Clean up expired sessions and abandoned carts
- **Quarterly**: Review index usage and optimize

### Performance Monitoring
```sql
-- Check database size (MySQL)
SELECT 
    table_schema as database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables
WHERE table_schema = 'openshop';

-- Check database size (PostgreSQL)
SELECT pg_size_pretty(pg_database_size('openshop')) as database_size;

-- Check database size (Oracle)
SELECT SUM(bytes/1024/1024) as size_mb
FROM user_segments;
```

## Migration Strategy

### Design Principles
- **Single Comprehensive Files**: Better IDE navigation and symbol jumping
- **Database-Agnostic Business Logic**: Consistent across all platforms
- **Performance-Focused**: Optimized indexes and constraints for each database
- **Production-Ready**: Proper error handling and transaction management

### Deployment Best Practices
- Always validate migrations in development first
- Use environment variables for sensitive configuration
- Monitor migration performance and timing
- Keep rollback procedures documented and tested

## Security Considerations

- **Never commit passwords** to version control
- **Use environment variables** for sensitive data: `FLYWAY_PASSWORD=your_admin_password` (for system admin Flyway user) and configure your application to use `your_app_password` (for web-server user)
- **Enable SSL/TLS** for all database connections
- **Restrict database permissions** to minimum required - system admin user has full privileges for migrations, web-server user has only SELECT/INSERT/UPDATE/DELETE on the openshop schema
- **Regular security audits** of database access and permissions

## Troubleshooting

### Common Issues
1. **Connection Timeouts**: Increase `flyway.commandTimeout` in flyway.conf
2. **Migration Conflicts**: Use `mvn flyway:repair` for checksum mismatches
3. **Permission Errors**: Verify database user has sufficient privileges
4. **Lock Contention**: Check for long-running transactions during migration

### Support Resources
- Check the `docs/` directory for detailed schema documentation
- Review Flyway logs for migration warnings or errors
- Use database-specific monitoring tools for performance analysis
- Consult database vendor documentation for platform-specific issues

## Contributing

When making schema changes:

1. Follow existing naming conventions and patterns
2. Include appropriate indexes and constraints
3. Add comprehensive comments for complex logic
4. Test on all supported database platforms
5. Update documentation and migration notes

## License

This database schema is part of the Open Shop e-commerce platform. Refer to the main project repository for license information.
