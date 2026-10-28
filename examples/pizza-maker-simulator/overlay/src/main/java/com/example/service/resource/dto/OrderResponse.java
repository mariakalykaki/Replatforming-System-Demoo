package com.example.service.resource.dto;

import com.example.service.domain.PizzaOrder;

import java.math.BigDecimal;

public class OrderResponse {
    public Long id;
    public String status;
    public BigDecimal totalPrice;
    public String rejectionReason;

    public OrderResponse(PizzaOrder order) {
        this.id = order.id;
        this.status = order.status.name();
        this.totalPrice = order.totalPrice;
        this.rejectionReason = order.rejectionReason;
    }
}
