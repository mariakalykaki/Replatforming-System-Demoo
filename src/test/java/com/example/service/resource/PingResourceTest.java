package com.example.service.resource;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.startsWith;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

@QuarkusTest
class PingResourceTest {

    @Test
    void pingReturnsPong() {
        given()
                .when().get("/ping")
                .then()
                .statusCode(200)
                .contentType(startsWith("text/plain"))
                .body(equalTo("pong"));
    }

    @Test
    void pingIgnoresQueryParameters() {
        given()
                .queryParam("foo", "bar")
                .when().get("/ping")
                .then()
                .statusCode(200)
                .contentType(startsWith("text/plain"))
                .body(equalTo("pong"));
    }
}
