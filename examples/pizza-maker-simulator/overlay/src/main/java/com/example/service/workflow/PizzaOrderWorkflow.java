package com.example.service.workflow;

import io.temporal.workflow.WorkflowInterface;
import io.temporal.workflow.WorkflowMethod;

@WorkflowInterface
public interface PizzaOrderWorkflow {

    @WorkflowMethod
    void run(Long orderId);
}
