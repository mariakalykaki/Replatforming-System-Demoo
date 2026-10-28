# CLAUDE.md

Project: **Number Activation (replatform)**. A behaviour-preserving migration of a legacy .NET + Oracle (PL/SQL) telecom service to **Quarkus, Temporal, Drools, Apache Camel and PostgreSQL**.

Read this file fully before changing anything. Rules marked **MUST** are blocking findings in code review.

## 1. Source of truth for behaviour

The legacy system lives in `legacy/`. It is read-only: never edit it.

| Read | For |
|---|---|
| `legacy/USECASE.md` | statuses, transitions, eligibility E1-E6, risk R1-R4, timers T1-T3, mock integrations, error codes |
| `legacy/SCENARIOS.md` | scenarios S1-S21 with setup and expected outcome |
| `legacy/database_export_with_seed_data.sql`, `legacy/database/` | schema, seed data and the PL/SQL logic (consult when the spec is silent) |
| `legacy/scripts/demo.sh` | end-to-end check of S1-S9 over HTTP |

The goal is the **same observable behaviour**, not a line-by-line port of PL/SQL. If code and spec disagree, or the spec is silent, do not guess: ask in an issue comment.

## 2. Parity requirements (MUST)

- **REST contract unchanged**: `POST /api/activations` (201), `GET /api/activations/{id}` (status + audit trail), `POST /api/activations/{id}/review` (`{"decision":"APPROVE|REJECT"}`), `/confirm`, `/cancel`. Same field names and status values as the legacy responses.
- **Errors** are RFC 7807 problem details with `title` "The request was refused.", `detail`, `status` and an `errorCode` extension. `20003` maps to 404, every other business code (`20001`, `20010`, `20011`-`20015`) to 400. Unexpected faults give 500 with a `traceId`.
- **Eligibility and risk outcomes are statuses, not errors**: a rejected request is a successful `201` with status `REJECTED` and all failure reasons together.
- An **unhandled (status, event) pair is an error** (`20010`, HTTP 400), never a silent no-op.
- **Every status change writes one audit row** (event, from status, to status, detail, time).
- **A number can never be reserved twice**; the losing request gets `20014`.
- The number is **released** on every terminal path after it was reserved, except ACTIVE: risk or review REJECTED, EXPIRED, FAILED, CANCELLED.
- All limits, points, thresholds and timer durations are **configuration in tables, never constants in code**.

## 3. Architecture

One deployable service (see Decisions). Packages under `src/main/java/<base package>/`:

| Package | Contents |
|---|---|
| `resource/` | REST endpoints, DTOs, exception mapping |
| `domain/` | JPA/Panache entities, the transition table |
| `workflow/` | Temporal workflow interfaces and implementations |
| `activity/` | Temporal activities: all I/O lives here |
| `routes/` | Camel RouteBuilders, one per external system |
| `config/` | CDI wiring (Temporal client and worker, Drools) |
| `src/main/resources/rules/` | Drools `.drl` files |
| `src/main/resources/db/migration/` | Flyway migrations |

### State ownership

- **PostgreSQL** is the source of truth for activation status, audit trail, number pool and configuration. `GET` reads Postgres only.
- **Temporal** owns orchestration: position in the flow, timers, retries.
- Each transition is one activity that, in a **single DB transaction**, updates the status, the number pool and writes the audit row.

### Temporal

- One workflow per activation, workflow id `activation-<activationId>`, started on submit.
- **MUST**: workflow code is deterministic. No DB, HTTP, Drools, randomness or wall-clock reads inside workflow code. Use `Workflow.sleep`/timers and `Workflow.currentTimeMillis`. All I/O goes through activities.
- **MUST**: activities are idempotent (they run at least once), keyed by activation id.
- **MUST**: `review`, `confirm` and `cancel` answer **synchronously**. An event not allowed in the current status returns HTTP 400 with `errorCode` 20010 (scenarios S16, S17). Use Temporal Updates with a validator, or an equivalent that gives the same result. A fire-and-forget signal alone does not satisfy this.
- The allowed (status, event) pairs from `USECASE.md` section 2 are defined **once** (in `domain/`) and used by both API validation and the workflow.
- Timers T1-T3 read their duration from config (demo values 15 s / 30 s / 45 s; real 24 h / 48 h / 72 h). **MUST**: a timer never fires after its state has been left (cancel on every exit).
- Carrier allocation is an activity with a retry policy. Timeouts, connection errors and 5xx are retryable; 422 is non-retryable and goes straight to FAILED; exhausted retries go to FAILED. Retry count and backoff are configuration. Observable behaviour to preserve: S4 succeeds on the third attempt, S5a ends FAILED, S5b ends FAILED without retry.

### Drools

- `.drl` files under `src/main/resources/rules/`.
- Eligibility returns **all** failures (E1-E6), not the first. Risk scoring is additive (R1-R4) and maps the score to AUTO_APPROVE / MANUAL_REVIEW / REJECT using thresholds from config.
- Rules are **pure**: no DB or HTTP access inside rules. An activity loads the facts (customer, number, counts, config) and inserts them. Evaluate rules inside an activity, never inside workflow code.

### Camel

- One route per external system: carrier (`POST carrier/allocate`) and customer notification. Base URLs come from config (`carrier.base-url`, `notifications.base-url`).
- Routes contain no business decisions. They translate HTTP/IO failures into retryable or non-retryable exceptions that the Temporal activity understands.
- Notifications follow `notification_types` (CUSTOMER goes to the notification endpoint, OPERATIONS is logged/alerted). **MUST**: a failing notification never blocks or rolls back an activation.

### PostgreSQL

- Flyway only. Never edit an applied migration; add `V<n>__description.sql`. snake_case names.
- Oracle to Postgres type mapping: `NUMBER` to `bigint`/`integer`/`numeric`, `VARCHAR2` to `varchar`, `'Y'/'N'` flags to `boolean`, `TIMESTAMP WITH TIME ZONE` to `timestamptz`.
- Number reservation is atomic: `UPDATE ... SET status='RESERVED' WHERE msisdn=? AND status='AVAILABLE'`; zero rows updated means `20014`.
- No stored procedures or triggers for business logic.

## 4. Decisions in force

Change here, and tell the Business Analyst, if they are overruled.

- **D1 One deployable.** The scaffold is "copy per microservice"; we start with a single service and split later along the package boundaries above.
- **D2 Kafka is not used in v1.** Remove `quarkus-messaging-kafka` and the `kafka` config from the app (the compose file may keep it). This also avoids a Kafka container in tests.
- **D3 No outbox table.** Temporal activity retries replace the outbox relay; notifications are best-effort activities (see Camel).

## 5. Testing

Tools are pinned in `.mise.toml` (Java 21, Maven 3.9). Run `mvn test`.

- **Rules**: plain JUnit tests against the `KieContainer`, no containers.
- **Workflows**: Temporal `TestWorkflowEnvironment` with time skipping (test dependency `io.temporal:temporal-testing`). **Never wait in real time** for T1-T3. Dev Services does not provide Temporal, so tests must not rely on `localhost:7233`.
- **HTTP level**: `@QuarkusTest` + RestAssured. These start a Postgres container via Dev Services and therefore need a container engine.
- **One test per scenario**, with the scenario ID at the start of the method name (`S6_multiReasonRejection`). Every scenario cited in an issue's acceptance criteria **MUST** have such a test.
- **If tests cannot run in your environment** (for example no container engine), say exactly which ones could not run in the PR. Never report green for something that did not run.
- **End to end**: `legacy/scripts/demo.sh` (S1-S9) against the running service with `API=http://localhost:8080/api/activations`. This runs in CI, not in the agent sandbox.

## 6. Conventions

- Java 21. Rename `com.example.service` and the Maven `groupId`/`artifactId` to the real names in the first issue (the scaffold says "RENAME ME").
- Keep the diff within the issue. No drive-by refactoring, no dependency upgrades, no infra changes (`docker-compose.yml`, `Makefile`) unless the issue says so.
- `examples/` is reference only: the pizza example shows how every layer is wired. Do not copy its business logic and do not reference it from production code.

## 7. Review checklist (Code Reviewer)

1. Every scenario ID in the issue has a passing test named after it, and the review states which tests were actually run.
2. Status codes, `errorCode` values, statuses and audit rows match the legacy behaviour.
3. Workflow code is deterministic; I/O only in activities; activities idempotent.
4. Invalid events answer synchronously with 400/20010.
5. Thresholds, limits and durations come from config tables.
6. No double reservation; the number is released on every non-ACTIVE terminal path; no timer survives leaving its state.
7. Scope stays inside the issue.
