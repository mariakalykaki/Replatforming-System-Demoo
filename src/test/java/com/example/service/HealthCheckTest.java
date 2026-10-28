package com.example.service;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

/**
 * Proves the scaffold boots end-to-end under `mvn test`: Quarkus starts,
 * Dev Services provision Postgres/Kafka containers, Flyway runs V1, and the
 * app responds. No business logic to assert yet — delete once real tests
 * exist, or keep as a smoke test.
 */
@QuarkusTest
class HealthCheckTest {

    @Test
    void readinessRespondsUp() {
        given()
                .when().get("/q/health/ready")
                .then()
                .statusCode(200)
                .body("status", is("UP"));
    }
}
