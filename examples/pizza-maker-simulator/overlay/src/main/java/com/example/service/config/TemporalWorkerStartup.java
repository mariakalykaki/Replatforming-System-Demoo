package com.example.service.config;

import com.example.service.activity.PizzaOrderActivitiesImpl;
import com.example.service.workflow.PizzaOrderWorkflowImpl;
import io.quarkus.runtime.LaunchMode;
import io.quarkus.runtime.StartupEvent;
import io.temporal.client.WorkflowClient;
import io.temporal.worker.WorkerFactory;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * TemporalClientProducer only exposes a WorkflowClient (see its own
 * Javadoc for why) - this is where the first workflow+activities actually
 * get registered and the Worker is started.
 */
@ApplicationScoped
public class TemporalWorkerStartup {

    @Inject
    WorkflowClient workflowClient;

    @Inject
    PizzaOrderActivitiesImpl pizzaOrderActivities;

    @ConfigProperty(name = "temporal.task-queue")
    String taskQueue;

    void onStart(@Observes StartupEvent event) {
        if (LaunchMode.current() == LaunchMode.TEST) {
            // There's no Dev Service for Temporal, and WorkerFactory.start() below
            // makes a blocking call to verify the namespace exists - so under
            // `mvn test` this would fail unless `make up` happens to already be
            // running. Skip starting a real worker here; test workflow/activity
            // logic itself with Temporal's TestWorkflowEnvironment instead
            // (see Temporal's Java SDK testing docs).
            return;
        }
        WorkerFactory factory = WorkerFactory.newInstance(workflowClient);
        var worker = factory.newWorker(taskQueue);
        worker.registerWorkflowImplementationTypes(PizzaOrderWorkflowImpl.class);
        worker.registerActivitiesImplementations(pizzaOrderActivities);
        factory.start();
    }
}
