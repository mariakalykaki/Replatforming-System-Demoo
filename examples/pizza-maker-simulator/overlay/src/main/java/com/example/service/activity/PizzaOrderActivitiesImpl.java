package com.example.service.activity;

import com.example.service.domain.OrderStatus;
import com.example.service.domain.PizzaOrder;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

import java.time.Instant;

/**
 * Registered on the Temporal Worker as a CDI-managed instance (not via
 * registerActivitiesImplementations(Class), which Temporal would otherwise
 * try to construct itself) so it can use @Inject for the Emitter and
 * @Transactional for the DB write, same as any other Quarkus bean.
 */
@ApplicationScoped
public class PizzaOrderActivitiesImpl implements PizzaOrderActivities {

    @Inject
    @Channel("order-events")
    Emitter<String> orderEvents;

    @Override
    @Transactional
    public void updateStatus(Long orderId, OrderStatus status) {
        PizzaOrder order = PizzaOrder.findById(orderId);
        order.status = status;
    }

    @Override
    public void publishStatusEvent(Long orderId, OrderStatus status) {
        String payload = String.format(
                "{\"orderId\":%d,\"status\":\"%s\",\"timestamp\":\"%s\"}",
                orderId, status, Instant.now());
        orderEvents.send(payload);
    }
}
