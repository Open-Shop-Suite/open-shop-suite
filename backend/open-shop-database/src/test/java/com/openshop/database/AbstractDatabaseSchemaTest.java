package com.openshop.database;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.junit.jupiter.api.Test;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.HashSet;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Abstract base class for database schema tests.
 * Provides common validation methods for schema deployment and structure.
 */
public abstract class AbstractDatabaseSchemaTest {

    protected static final String SCHEMA_NAME = "openshop";

    /**
     * Returns the JDBC URL for the database connection.
     */
    protected abstract String getJdbcUrl();

    /**
     * Returns the database username.
     */
    protected abstract String getUsername();

    /**
     * Returns the database password.
     */
    protected abstract String getPassword();

    /**
     * Returns the Flyway migration location.
     */
    protected abstract String getMigrationLocation();

    /**
     * Returns whether to create schemas automatically.
     */
    protected abstract boolean shouldCreateSchemas();

    /**
     * Returns additional table names that are expected but not in the main constants.
     * This allows subclasses to specify database-specific tables (like Flyway schema history).
     */
    protected abstract String[] getAdditionalExpectedTables();

    /**
     * Returns the table name in the correct case for database queries.
     * MySQL uses lowercase, Oracle uses uppercase.
     */
    protected abstract String getTableNameForQuery(String tableName);



    /**
     * Deploys the schema and returns the migration result.
     */
    protected MigrateResult deploySchema() {
        Flyway flyway = Flyway.configure()
                .dataSource(getJdbcUrl(), getUsername(), getPassword())
                .locations(getMigrationLocation())
                .createSchemas(shouldCreateSchemas())
                .schemas(SCHEMA_NAME)
                .load();

        return flyway.migrate();
    }

    /**
     * Test that validates SQL scripts execute without errors.
     */
    @Test
    void shouldDeploySchemaWithoutSqlErrors() {
        MigrateResult result = deploySchema();

        // Assert migration was successful
        assertThat(result.success)
                .as("Schema migration should be successful")
                .isTrue();
    }

    /**
     * Test that validates table and column structure matches expected schema exactly.
     */
    @Test
    void shouldHaveExactTableAndColumnStructure() {
        // First deploy the schema
        Flyway flyway = Flyway.configure()
                .dataSource(getJdbcUrl(), getUsername(), getPassword())
                .locations(getMigrationLocation())
                .createSchemas(shouldCreateSchemas())
                .schemas(SCHEMA_NAME)
                .load();

        flyway.migrate();

        try (Connection connection = DriverManager.getConnection(getJdbcUrl(), getUsername(), getPassword())) {
            validateTables(connection);
            validateColumns(connection);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to validate table and column structure", e);
        }
    }



    /**
     * Validates that the expected schema exists.
     */
    private void validateSchemaExists(Connection connection) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();

        try (ResultSet schemas = metaData.getSchemas()) {
            boolean schemaFound = false;
            while (schemas.next()) {
                String schemaName = schemas.getString("TABLE_SCHEM");
                if (SCHEMA_NAME.equalsIgnoreCase(schemaName)) {
                    schemaFound = true;
                    break;
                }
            }
            assertThat(schemaFound)
                    .as("Schema '%s' should exist", SCHEMA_NAME)
                    .isTrue();
        }
    }

    /**
     * Validates that only expected tables exist (no extra tables).
     */
    private void validateTables(Connection connection) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();
        Set<String> expectedTables = new HashSet<>();
        for (String table : DatabaseTestConstants.EXPECTED_TABLES) {
            expectedTables.add(table.toUpperCase());
        }

        // Add database-specific additional tables
        for (String table : getAdditionalExpectedTables()) {
            expectedTables.add(table.toUpperCase());
        }

        Set<String> actualTables = new HashSet<>();

        try (ResultSet tables = metaData.getTables(null, SCHEMA_NAME, "%", new String[]{"TABLE"})) {
            while (tables.next()) {
                String tableName = tables.getString("TABLE_NAME");
                if (tableName != null) {
                    actualTables.add(tableName.toUpperCase());
                }
            }
        }

        // Check that all expected tables exist
        for (String expectedTable : expectedTables) {
            assertThat(actualTables)
                    .as("Expected table '%s' should exist", expectedTable)
                    .contains(expectedTable);
        }

        // Check that no extra tables exist
        Set<String> extraTables = new HashSet<>(actualTables);
        extraTables.removeAll(expectedTables);

        assertThat(extraTables)
                .as("No extra tables should exist. Found: %s", extraTables)
                .isEmpty();
    }

    /**
     * Validates that tables have exactly the expected columns (no extra or missing columns).
     */
    private void validateColumns(Connection connection) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();

        for (String tableName : DatabaseTestConstants.EXPECTED_TABLES) {
            List<String> expectedColumns = DatabaseTestConstants.EXPECTED_TABLE_COLUMNS.get(tableName);
            if (expectedColumns == null) {
                continue; // Skip if no expected columns defined
            }

            Set<String> expectedColumnsSet = new HashSet<>();
            for (String col : expectedColumns) {
                expectedColumnsSet.add(col.toUpperCase());
            }

            Set<String> actualColumns = new HashSet<>();

            try (ResultSet columns = metaData.getColumns(null, SCHEMA_NAME, getTableNameForQuery(tableName), "%")) {
                while (columns.next()) {
                    String columnName = columns.getString("COLUMN_NAME");
                    if (columnName != null) {
                        actualColumns.add(columnName.toUpperCase());
                    }
                }
            }

            // Check that all expected columns exist
            for (String expectedColumn : expectedColumnsSet) {
                assertThat(actualColumns)
                        .as("Table '%s' should have column '%s'", tableName, expectedColumn)
                        .contains(expectedColumn);
            }

            // Check that no extra columns exist
            Set<String> extraColumns = new HashSet<>(actualColumns);
            extraColumns.removeAll(expectedColumnsSet);

            assertThat(extraColumns)
                    .as("Table '%s' should not have extra columns. Found: %s", tableName, extraColumns)
                    .isEmpty();
        }
    }

    /**
     * Validates that tables have exactly the expected indexes (no extra or missing indexes).
     */
    private void validateIndexes(Connection connection) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();

        for (String tableName : DatabaseTestConstants.EXPECTED_TABLES) {
            List<String> expectedIndexes = DatabaseTestConstants.EXPECTED_TABLE_INDEXES.get(tableName);
            if (expectedIndexes == null) {
                continue; // Skip if no expected indexes defined
            }

            Set<String> expectedIndexesSet = new HashSet<>();
            for (String idx : expectedIndexes) {
                expectedIndexesSet.add(idx.toUpperCase());
            }

            Set<String> actualIndexes = new HashSet<>();

            try (ResultSet indexes = metaData.getIndexInfo(null, SCHEMA_NAME, getTableNameForQuery(tableName), false, false)) {
                while (indexes.next()) {
                    String indexName = indexes.getString("INDEX_NAME");
                    if (indexName != null) {
                        actualIndexes.add(indexName.toUpperCase());
                    }
                }
            }

            // Check that all expected indexes exist
            for (String expectedIndex : expectedIndexesSet) {
                assertThat(actualIndexes)
                        .as("Table '%s' should have index '%s'", tableName, expectedIndex)
                        .contains(expectedIndex);
            }

            // Check that no extra indexes exist (excluding system indexes if any)
            Set<String> extraIndexes = new HashSet<>(actualIndexes);
            extraIndexes.removeAll(expectedIndexesSet);

            // Filter out system-generated indexes that might not be in our expectations
            extraIndexes.removeIf(idx -> idx.startsWith("SYS_") || idx.contains("AUTO_"));

            assertThat(extraIndexes)
                    .as("Table '%s' should not have extra indexes. Found: %s", tableName, extraIndexes)
                    .isEmpty();
        }
    }
}
