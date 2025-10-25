package com.openshop.database;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.*;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
public class PostgreSQLSchemaTest extends AbstractDatabaseSchemaTest {

    private static final String SCHEMA_NAME = "openshop";

    @Container
    static final GenericContainer<?> postgres = new GenericContainer<>("postgres:15")
            .withExposedPorts(5432)
            .withEnv("POSTGRES_DB", SCHEMA_NAME)
            .withEnv("POSTGRES_USER", "openshop")
            .withEnv("POSTGRES_PASSWORD", "passwordtest")
            .withEnv("POSTGRES_HOST_AUTH_METHOD", "trust")
            .waitingFor(Wait.forListeningPort())
            .withStartupTimeout(Duration.ofMinutes(5))
            .withReuse(false);

    @Override
    protected String getJdbcUrl() {
        return "jdbc:postgresql://localhost:" + postgres.getMappedPort(5432) + "/" + SCHEMA_NAME;
    }

    @Override
    protected String getUsername() {
        return "openshop";
    }

    @Override
    protected String getPassword() {
        return "passwordtest";
    }

    @Override
    protected String getMigrationLocation() {
        return "filesystem:db/migration/postgresql";
    }

    @Override
    protected boolean shouldCreateSchemas() {
        return true;
    }

    @Override
    protected String[] getAdditionalExpectedTables() {
        return new String[]{
                "FLYWAY_SCHEMA_HISTORY"
        };
    }

    @Override
    protected String getTableNameForQuery(String tableName) {
        return tableName.toLowerCase();
    }

    @Test
    void shouldHaveExactIndexStructure() {
        // First deploy the schema
        Flyway flyway = Flyway.configure()
                .dataSource(getJdbcUrl(), getUsername(), getPassword())
                .locations(getMigrationLocation())
                .createSchemas(shouldCreateSchemas())
                .schemas(SCHEMA_NAME)
                .load();

        flyway.migrate();

        try (Connection connection = DriverManager.getConnection(getJdbcUrl(), getUsername(), getPassword())) {
            validateIndexesPostgreSQL(connection);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to validate index structure", e);
        }
    }

    @Test
    void shouldValidateSchemaExists() throws SQLException {
        // Deploy schema first
        deploySchema();

        try (Connection connection = DriverManager.getConnection(getJdbcUrl(), getUsername(), getPassword())) {
            // For PostgreSQL, verify the schema exists
            try (Statement stmt = connection.createStatement()) {
                ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = '" + SCHEMA_NAME + "'");
                assertThat(rs.next() && rs.getInt(1) > 0)
                        .as("PostgreSQL schema '%s' should exist", SCHEMA_NAME)
                        .isTrue();
            }
        }
    }

    private void validateIndexesPostgreSQL(Connection connection) throws SQLException {
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

            // For PostgreSQL, use direct query to avoid privilege issues
            try (PreparedStatement stmt = connection.prepareStatement(
                    "SELECT indexname FROM pg_indexes WHERE schemaname = ? AND tablename = ?")) {
                stmt.setString(1, SCHEMA_NAME);
                stmt.setString(2, getTableNameForQuery(tableName));
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        String indexName = rs.getString("indexname");
                        if (indexName != null && indexName.toUpperCase().startsWith("IDX_")) {
                            actualIndexes.add(indexName.toUpperCase());
                        }
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

            assertThat(extraIndexes)
                    .as("Table '%s' should not have extra indexes. Found: %s", tableName, extraIndexes)
                    .isEmpty();
        }
    }
}
