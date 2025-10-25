package com.openshop.database;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
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
public class OracleSchemaTest extends AbstractDatabaseSchemaTest {

    private static final String SCHEMA_NAME = "openshop";

    @Container
    static final GenericContainer<?> oracle = new GenericContainer<>("container-registry.oracle.com/database/free:23.9.0.0-arm64")
            .withExposedPorts(1521, 5500)
            .withEnv("ORACLE_PWD", "Test@123")
            .waitingFor(Wait.forLogMessage(".*DATABASE IS READY TO USE.*", 1))
            .withStartupTimeout(Duration.ofMinutes(10))
            .withReuse(false);

    @Override
    protected String getJdbcUrl() {
        return "jdbc:oracle:thin:@//localhost:" + oracle.getMappedPort(1521) + "/freepdb1";
    }

    @Override
    protected String getUsername() {
        return "system";
    }

    @Override
    protected String getPassword() {
        return "Test@123";
    }

    @Override
    protected String getMigrationLocation() {
        return "filesystem:db/migration/oracle";
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
        return tableName.toUpperCase();
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
            validateIndexesOracle(connection);
        } catch (SQLException e) {
            throw new RuntimeException("Failed to validate index structure", e);
        }
    }

    @Test
    void shouldValidateSchemaExists() throws SQLException {
        // Deploy schema first
        deploySchema();

        try (Connection connection = DriverManager.getConnection(getJdbcUrl(), getUsername(), getPassword())) {
            // For Oracle, verify the schema exists
            try (Statement stmt = connection.createStatement()) {
                ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM all_users WHERE USERNAME = '" + SCHEMA_NAME + "'");
                assertThat(rs.next() && rs.getInt(1) > 0)
                        .as("Oracle schema '%s' should exist", SCHEMA_NAME)
                        .isTrue();
            }
        }
    }

    private void validateIndexesOracle(Connection connection) throws SQLException {
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

            // For Oracle, use direct query to avoid privilege issues with getIndexInfo
            try (PreparedStatement stmt = connection.prepareStatement(
                    "SELECT INDEX_NAME FROM ALL_INDEXES WHERE OWNER = ? AND TABLE_NAME = ?")) {
                stmt.setString(1, SCHEMA_NAME);
                stmt.setString(2, getTableNameForQuery(tableName));
                try (ResultSet rs = stmt.executeQuery()) {
                    while (rs.next()) {
                        String indexName = rs.getString("INDEX_NAME");
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

            // Filter out system-generated indexes that might not be in our expectations
            // Oracle generates SYS_C* for constraints, SYS_* for internal indexes
            extraIndexes.removeIf(idx -> idx.startsWith("SYS_"));

            assertThat(extraIndexes)
                    .as("Table '%s' should not have extra indexes. Found: %s", tableName, extraIndexes)
                    .isEmpty();
        }
    }
}
