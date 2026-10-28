package com.example.service.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import io.temporal.client.WorkflowClient;
import io.temporal.client.WorkflowClientOptions;
import io.temporal.serviceclient.WorkflowServiceStubs;
import io.temporal.serviceclient.WorkflowServiceStubsOptions;

/**
 * Produces a WorkflowClient connected to the Temporal frontend started by
 * `make up` (temporal.service-address / temporal.namespace).
 *
 * Deliberately does NOT start a Worker here: a Worker needs at least one
 * workflow implementation to register, which doesn't exist yet in this
 * scaffold. See docs/FIRST-STEPS.md for wiring up the first workflow +
 * worker together.
 */
@ApplicationScoped
public class TemporalClientProducer {

    @ConfigProperty(name = "temporal.service-address")
    String serviceAddress;

    @ConfigProperty(name = "temporal.namespace")
    String namespace;

    @Produces
    @Singleton
    public WorkflowServiceStubs workflowServiceStubs() {
        return WorkflowServiceStubs.newServiceStubs(
                WorkflowServiceStubsOptions.newBuilder()
                        .setTarget(serviceAddress)
                        .build());
    }

    @Produces
    @Singleton
    public WorkflowClient workflowClient(WorkflowServiceStubs stubs) {
        return WorkflowClient.newInstance(stubs,
                WorkflowClientOptions.newBuilder()
                        .setNamespace(namespace)
                        .build());
    }
}
