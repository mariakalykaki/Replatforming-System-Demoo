package com.example.service.routes;

import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.dataformat.JsonLibrary;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Reuses the scaffold's generic "registry.base-url" (WireMock) as the mocked
 * payment gateway for this example - both just mean "whatever external
 * system this service calls out to."
 */
@ApplicationScoped
public class PaymentGatewayRoute extends RouteBuilder {

    @ConfigProperty(name = "registry.base-url")
    String paymentGatewayBaseUrl;

    @Override
    public void configure() {
        from("direct:chargePayment")
                .routeId("charge-payment")
                .log("Charging payment: ${body}")
                .marshal().json(JsonLibrary.Jackson)
                .setHeader("CamelHttpMethod", constant("POST"))
                .setHeader("Content-Type", constant("application/json"))
                .toD(paymentGatewayBaseUrl + "/payments/charge")
                .unmarshal().json(JsonLibrary.Jackson, PaymentResult.class);
    }
}
