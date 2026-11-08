package org.acme.greeting;

import static io.restassured.RestAssured.given;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GreetingResourceTest {

    @Test
    void listsGreetings() {
        given().when().get("/api/greetings").then().statusCode(200);
    }
}
