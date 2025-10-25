package com.openshop.database;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import static org.testcontainers.containers.wait.strategy.Wait.forListeningPort;
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
public class MySQLSchemaTest extends AbstractDatabaseSchemaTest {

    private static final int DB_PORT = 3306;

    @Container
    static final GenericContainer<?> mysql = new GenericContainer<>(
            "mysql:9.0")
            .withExposedPorts(DB_PORT)
            .withEnv("MYSQL_ROOT_PASSWORD", "rootpassword")
            .withEnv("MYSQL_DATABASE", SCHEMA_NAME)
            .withEnv("MYSQL_USER", "openshop")
            .withEnv("MYSQL_PASSWORD", "passwordtest")
            .withCommand("--log-bin-trust-function-creators=1")
            .waitingFor(forListeningPort())
            .withStartupTimeout(Duration.ofMinutes(5))
            .withReuse(false);

    @Override
    protected String getJdbcUrl() {
        return "jdbc:mysql://localhost:" + mysql.getMappedPort(DB_PORT) + "/" + SCHEMA_NAME +
               "?allowPublicKeyRetrieval=true&useSSL=false";
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
        return "filesystem:db/migration/mysql";
    }

    @Override
    protected boolean shouldCreateSchemas() {
        return false;
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
            validateIndexesMySQL(connection);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to validate index structure", e);
        }
    }

    @Test
    void shouldValidateSchemaExists() throws SQLException {
        // Deploy schema first
        deploySchema();

        try (Connection connection = DriverManager.getConnection(getJdbcUrl(), getUsername(), getPassword())) {
            // For MySQL, verify we're connected to the right database
            String catalog = connection.getCatalog();
            assertThat(catalog)
                    .as("MySQL database '%s' should exist", SCHEMA_NAME)
                    .isEqualToIgnoringCase(SCHEMA_NAME);
        }
    }

    private void validateIndexesMySQL(Connection connection) throws SQLException {
        DatabaseMetaData metaData = connection.getMetaData();

        for (String tableName : DatabaseTestConstants.EXPECTED_TABLES) {
            List<String> expectedIndexes = DatabaseTestConstants.EXPECTED_TABLE_INDEXES.get(tableName);
            if (expectedIndexes == null) {
                expectedIndexes = new ArrayList<>();
            }

            // For MySQL, only validate explicit IDX_ prefixed indexes (not implicit constraint indexes)
            List<String> filteredExpectedIndexes = expectedIndexes.stream()
                    .filter(idx -> idx.toUpperCase().startsWith("IDX_"))
                    .toList();

            Set<String> expectedIndexesSet = new HashSet<>();
            for (String idx : filteredExpectedIndexes) {
                expectedIndexesSet.add(idx.toUpperCase());
            }

            Set<String> actualIndexes = new HashSet<>();

            try (ResultSet indexes = metaData.getIndexInfo(null, SCHEMA_NAME, getTableNameForQuery(tableName), false, false)) {
                while (indexes.next()) {
                    String indexName = indexes.getString("INDEX_NAME");
                    if (indexName != null && indexName.toUpperCase().startsWith("IDX_")) {
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
