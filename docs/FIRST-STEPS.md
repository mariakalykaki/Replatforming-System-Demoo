# First steps

This scaffold is deliberately empty of business logic — every piece of the
stack is wired up and runnable, but there's no sample feature to delete
first. This doc shows the first thing to add in each layer. Copy-paste and
rename as needed; package base is `com.example.service` — rename it (and
the Maven `groupId`/`artifactId` in `pom.xml`) to your actual service name
before going further.

Run `make up` first (see root `README.md`) so Postgres/Kafka/Temporal/etc.
are available, then `mvn quarkus:dev` for live-reload while you work
through these.

## First REST endpoint

```java
// src/main/java/com/example/service/resource/PingResource.java
package com.example.service.resource;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

@Path("/ping")
public class PingResource {

    @GET
    public String ping() {
        return "pong";
    }
}
```

Check it: `curl http://localhost:8080/ping`. Full OpenAPI/Swagger UI is at
http://localhost:8080/q/swagger-ui once anything is mapped.

## First database table

Add a migration (Flyway runs these automatically on startup, in order):

```sql
-- src/main/resources/db/migration/V2__add_widget.sql
create table widget (
    id bigint generated always as identity primary key,
    name varchar(255) not null
);
```

Then the entity:

```java
// src/main/java/com/example/service/domain/Widget.java
package com.example.service.domain;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class Widget extends PanacheEntityBase {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    public String name;
}
```

Uses `PanacheEntityBase` with an explicit `IDENTITY` id rather than plain
`PanacheEntity`: with schema management turned off
(`quarkus.hibernate-orm.database.generation=none`), Hibernate needs its id
strategy to match whatever the Flyway migration actually created.
`PanacheEntity`'s default id strategy expects a Hibernate-managed sequence,
which doesn't exist here — it would fail on the first insert with a "relation
... does not exist" error for a sequence you never created. `findById`,
`listAll`, etc. still work the same via `PanacheEntityBase`.

`Widget.listAll()`, `Widget.persist(widget)`, etc. come from Panache.
Inspect the table via Adminer (http://localhost:8081) or `make psql`.

## First Drools rule

Drools is wired via `DroolsProducer` (`src/main/java/com/example/service/config/DroolsProducer.java`),
which builds a `KieContainer` from whatever's under `src/main/resources/rules/`.
Add a rule file there:

```
// src/main/resources/rules/widget.drl
package rules;

import com.example.service.domain.Widget;

rule "Reject blank widget names"
when
    $w : Widget(name == null || name.trim().length() == 0)
then
    System.out.println("Invalid widget: " + $w);
end
```

Use it from a CDI bean by injecting the `KieContainer` and opening a
session per use (KieSession is stateful/not thread-safe, so don't share
one across requests):

```java
@Inject
KieContainer kieContainer;

void evaluate(Widget widget) {
    // Named explicitly (matches kmodule.xml's ksession name) rather than
    // newKieSession()'s zero-arg "default session" lookup, which doesn't
    // reliably resolve it under Quarkus's classloading.
    var session = kieContainer.newKieSession("serviceKSession");
    try {
        session.insert(widget);
        session.fireAllRules();
    } finally {
        session.dispose();
    }
}
```

## First Temporal workflow + worker

Temporal owns orchestration state; `TemporalClientProducer` only exposes a
`WorkflowClient` for starting workflows. A `Worker` needs at least one
workflow implementation to register, so it's added alongside the first one:

```java
// src/main/java/com/example/service/workflow/WidgetWorkflow.java
package com.example.service.workflow;

import io.temporal.workflow.WorkflowInterface;
import io.temporal.workflow.WorkflowMethod;

@WorkflowInterface
public interface WidgetWorkflow {
    @WorkflowMethod
    String process(String widgetName);
}
```

```java
// src/main/java/com/example/service/workflow/WidgetWorkflowImpl.java
package com.example.service.workflow;

public class WidgetWorkflowImpl implements WidgetWorkflow {
    @Override
    public String process(String widgetName) {
        return "processed: " + widgetName;
    }
}
```

Register a worker on application startup:

```java
// src/main/java/com/example/service/config/TemporalWorkerStartup.java
package com.example.service.config;

import com.example.service.workflow.WidgetWorkflowImpl;
import io.quarkus.runtime.LaunchMode;
import io.quarkus.runtime.StartupEvent;
import io.temporal.client.WorkflowClient;
import io.temporal.worker.WorkerFactory;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class TemporalWorkerStartup {

    @Inject
    WorkflowClient workflowClient;

    @ConfigProperty(name = "temporal.task-queue")
    String taskQueue;

    void onStart(@Observes StartupEvent ev) {
        if (LaunchMode.current() == LaunchMode.TEST) {
            // There's no Dev Service for Temporal, and WorkerFactory.start() below
            // makes a blocking call to verify the namespace exists - so under
            // `mvn test` this would fail unless `make up` happens to already be
            // running. Skip starting a real worker here; test workflow/activity
            // logic itself with Temporal's TestWorkflowEnvironment instead.
            return;
        }
        WorkerFactory factory = WorkerFactory.newInstance(workflowClient);
        var worker = factory.newWorker(taskQueue);
        worker.registerWorkflowImplementationTypes(WidgetWorkflowImpl.class);
        factory.start();
    }
}
```

That `LaunchMode` check matters: there's no Dev Service for Temporal the
way there is for Postgres/Kafka, and `factory.start()` makes a blocking
call to verify the configured namespace exists. Without the guard, `mvn
test` fails outright unless `make up` happens to already be running.

Kick one off from anywhere with a `WorkflowClient` injected (e.g. a REST
resource), and watch it run in Temporal UI at http://localhost:8088:

```java
WidgetWorkflow wf = workflowClient.newWorkflowStub(
        WidgetWorkflow.class,
        WorkflowOptions.newBuilder().setTaskQueue(taskQueue).build());
wf.process("example");
```

## First Camel route

Quarkus's Camel extension auto-discovers `RouteBuilder` CDI beans — no
extra registration needed:

```java
// src/main/java/com/example/service/routes/RegistryLookupRoute.java
package com.example.service.routes;

import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.builder.RouteBuilder;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@ApplicationScoped
public class RegistryLookupRoute extends RouteBuilder {

    @ConfigProperty(name = "registry.base-url")
    String registryBaseUrl;

    @Override
    public void configure() {
        from("direct:lookupRegistry")
                .toD(registryBaseUrl + "/__example/ping");
    }
}
```

This calls the WireMock stub at `infra/wiremock/mappings/example.json` —
replace both once you know the real external system this service talks to,
and add a matching stub under `infra/wiremock/mappings/`.

## First Kafka producer/consumer

```properties
# application.properties
mp.messaging.outgoing.widget-events.connector=smallrye-kafka
mp.messaging.outgoing.widget-events.topic=widget-events
mp.messaging.outgoing.widget-events.value.serializer=org.apache.kafka.common.serialization.StringSerializer

mp.messaging.incoming.widget-events-in.connector=smallrye-kafka
mp.messaging.incoming.widget-events-in.topic=widget-events
mp.messaging.incoming.widget-events-in.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
```

```java
@Inject
@Channel("widget-events")
Emitter<String> widgetEvents;

void publish(String widgetName) {
    widgetEvents.send(widgetName);
}
```

```java
@Incoming("widget-events-in")
void consume(String widgetName) {
    // handle it
}
```

Watch topics/messages at http://localhost:8089 (Kafka UI), or from the CLI
with `make kafka-topics` / `make kafka-console-consumer TOPIC=widget-events`.

## First test

```java
// src/test/java/com/example/service/PingResourceTest.java
package com.example.service;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

@QuarkusTest
class PingResourceTest {

    @Test
    void pingRespondsWithPong() {
        given().when().get("/ping").then().statusCode(200).body(is("pong"));
    }
}
```

`mvn test` runs this against Dev Services' disposable containers — you
don't need `make up` running for tests to pass.
