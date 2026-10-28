# service (rename me)

Local dev scaffold for a single Quarkus microservice built on:

- **Quarkus** — REST, persistence, config
- **Temporal** — owns orchestration state (timers, retries, workflow position)
- **PostgreSQL** — owns domain + regulatory state (plus Temporal's own history, in a separate database)
- **Drools** — embedded rules engine
- **Apache Camel** — integration routes to external systems

This is a template: copy it per microservice, then rename the Maven
`groupId`/`artifactId` in [pom.xml](pom.xml) and the Java package
(`com.example.service`) to match. There's no sample business logic — see
[docs/FIRST-STEPS.md](docs/FIRST-STEPS.md) for how to add the first REST
endpoint, DB table, Drools rule, Temporal workflow, Camel route, and Kafka
producer/consumer.

## Prerequisites

Java 21, Maven, and Docker **or** Podman. See [docs/INSTALL.md](docs/INSTALL.md)
for OS-specific install steps (macOS, Linux, Windows) and one-time Podman +
Testcontainers setup.

## Quick start

```bash
make up          # start infra: postgres, temporal, kafka, wiremock, adminer, UIs
mvn quarkus:dev  # run the app with live reload, against that infra
```

Once you've written something worth containerizing:

```bash
make build        # mvn package + build the app's container image
make up           # re-run: now also starts the app container itself
```

```bash
mvn test          # or: make test — runs the test suite with disposable
                  # Dev Services containers; doesn't need `make up`
```

Run `make help` for the full list of targets (`down`, `clean`, `logs`, `ps`,
`psql`, `kafka-topics`, `kafka-console-consumer`, ...).

## New to this stack? Generate a worked example

```bash
make example                    # pizza-maker-simulator in ../pizza-maker-simulator
```

Copies this blank scaffold into a sibling directory and layers a small but
complete "take online pizza orders" feature on top — REST → Drools →
Temporal → Camel → Postgres → Kafka, all wired together. This scaffold
itself is untouched; it's a separate, disposable project to read, run, and
break. See `examples/pizza-maker-simulator/overlay/docs/PIZZA-EXAMPLE.md`
(or `docs/PIZZA-EXAMPLE.md` inside the generated project) for a full
walkthrough once it's created.

```bash
make example-clean              # stops its stack and deletes ../pizza-maker-simulator
```

Both accept `NAME=` / `DIR=` to target a different example or path (e.g.
`make example-clean DIR=../pizza-try-2`). `example-clean` refuses to delete
anything that doesn't look like a generated example (checks for a marker
line in its README.md), so it won't blindly `rm -rf` an unrelated directory.

## What `make up` starts

| Service | URL / port | Purpose |
|---|---|---|
| Postgres | `localhost:5432` (db `appdb`, user/pass `app`/`app`) | Domain + regulatory state |
| Adminer | http://localhost:8081 | Browse Postgres |
| Temporal | `localhost:7233` | Orchestration state (timers, retries, workflow position) |
| Temporal UI | http://localhost:8088 | Watch workflow executions |
| Kafka | `localhost:9092` | Notification / event pub-sub |
| Kafka UI | http://localhost:8089 | Browse topics/messages |
| WireMock | http://localhost:8090/__admin | Mock for whatever external system this service calls |
| App (once built) | http://localhost:8080 | The service itself |

Postgres also contains `temporal` and `temporal_visibility` databases,
used only by the Temporal server container — the app itself only ever
talks to `appdb`.

`make up` always starts the infra containers. It additionally starts the
app container, but only once `make build` has produced a jar — until then
there's nothing to containerize, so it's skipped automatically and `make up`
tells you so.

## Project layout

```
src/main/java/com/example/service/
  resource/   REST endpoints
  domain/     JPA/Panache entities
  workflow/   Temporal workflow interfaces + implementations
  activity/   Temporal activities
  routes/     Camel RouteBuilders
  config/     CDI wiring for Drools/Temporal (infra glue, not business logic)
src/main/resources/
  rules/              Drools .drl files
  db/migration/        Flyway migrations
infra/
  postgres/init.sql    Creates the temporal/temporal_visibility databases
  wiremock/mappings/   Stubs for the mocked external system
```

## Troubleshooting

- `make down` / `make clean` printing `Error: no container ... found` —
  harmless Podman noise when the stack (or the app container specifically)
  was never running. See [docs/INSTALL.md](docs/INSTALL.md#known-harmless-noise).
- `mvn test` can't find a container engine — see the Podman + Testcontainers
  setup in [docs/INSTALL.md](docs/INSTALL.md#podman--testcontainers-mvn-test).
- Neither `docker` nor `podman` on `PATH` — `make` targets fail fast with a
  pointer to [docs/INSTALL.md](docs/INSTALL.md).
