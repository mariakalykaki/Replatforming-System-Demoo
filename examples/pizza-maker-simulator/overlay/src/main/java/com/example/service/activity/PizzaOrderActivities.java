package com.example.service.activity;

import com.example.service.domain.OrderStatus;
import io.temporal.activity.ActivityInterface;
import io.temporal.activity.ActivityMethod;

@ActivityInterface
public interface PizzaOrderActivities {

    @ActivityMethod
    void updateStatus(Long orderId, OrderStatus status);

    @ActivityMethod
    void publishStatusEvent(Long orderId, OrderStatus status);
}
