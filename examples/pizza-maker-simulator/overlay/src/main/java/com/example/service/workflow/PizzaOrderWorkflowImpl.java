package com.example.service.workflow;

import com.example.service.activity.PizzaOrderActivities;
import com.example.service.domain.OrderStatus;
import io.temporal.activity.ActivityOptions;
import io.temporal.workflow.Workflow;

import java.time.Duration;

/**
 * Temporal replays this code from history, so it must stay deterministic: no
 * config/CDI injection, no real I/O here - all of that lives in the
 * activities instead. Workflow.sleep is a durable timer (survives worker
 * restarts), unlike Thread.sleep.
 */
public class PizzaOrderWorkflowImpl implements PizzaOrderWorkflow {

    // Simulated prep/bake time. Turn these up/down and restart `mvn quarkus:dev`
    // to see the effect on how long an order takes in Temporal UI.
    private static final Duration PREP_TIME = Duration.ofSeconds(5);
    private static final Duration BAKE_TIME = Duration.ofSeconds(10);

    private final PizzaOrderActivities activities = Workflow.newActivityStub(
            PizzaOrderActivities.class,
            ActivityOptions.newBuilder()
                    .setStartToCloseTimeout(Duration.ofSeconds(30))
                    .build());

    @Override
    public void run(Long orderId) {
        advance(orderId, OrderStatus.PREPARING);
        Workflow.sleep(PREP_TIME);

        advance(orderId, OrderStatus.BAKING);
        Workflow.sleep(BAKE_TIME);

        advance(orderId, OrderStatus.READY);
    }

    private void advance(Long orderId, OrderStatus status) {
        activities.updateStatus(orderId, status);
        activities.publishStatusEvent(orderId, status);
    }
}
