package com.example.service.routes;

import java.math.BigDecimal;

public class PaymentRequest {

    public BigDecimal amount;

    public PaymentRequest() {
    }

    public PaymentRequest(BigDecimal amount) {
        this.amount = amount;
    }
}
