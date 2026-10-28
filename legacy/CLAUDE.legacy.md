# CLAUDE.md

Number Activation: a deliberately small .NET + Oracle telecom service. `USECASE.md` is the spec: statuses, rules, timers and mock behaviour. `SCENARIOS.md` holds the demo/test scenarios; add new ones there, not in the spec. Keep the code light.

## Commands

```bash
cp .env.example .env                       # first time only (a local-dev .env already exists)
podman compose --env-file .env up -d       # Oracle on host port 1522 (na-oracle); wait for "DATABASE IS READY TO USE!"
scripts/db-apply.sh                        # schema, packages, seeds, compile-error + reachability checks
scripts/run-local.sh                       # Oracle + mock carrier (:5101) + worker + API (:5100)
scripts/demo.sh                            # all demo scenarios, ~2 min; needs a fresh DB
dotnet build && dotnet test               # unit tests; integration tests are skipped unless ConnectionStrings__Oracle is set
# Integration tests (S1-S21 against real Oracle): stop the worker first, it would steal outbox rows
ConnectionStrings__Oracle="User Id=na_app;Password=<APP_USER_PASSWORD>;Data Source=localhost:1522/FREEPDB1;" dotnet test tests/Na.IntegrationTests
dotnet test --filter "FullyQualifiedName~OutboxRelayServiceTests"

# Reset to a clean database (demo numbers can only be used once)
podman compose --env-file .env down -v && podman compose --env-file .env up -d && scripts/db-apply.sh
```

Connection string: `ConnectionStrings__Oracle="User Id=na_app;Password=<APP_USER_PASSWORD>;Data Source=localhost:1522/FREEPDB1;"` (env var, or `dotnet user-secrets`). Never in appsettings.

## Architecture

**Guiding rule (same as markella-mnp): all business logic is in PL/SQL.** .NET raises events and reads back what the database decided. It never picks a status.

- `Na.Application`: records, interfaces, three thin services (`ActivationService`, `OutboxRelayService`, `TimerSweepService`). No DB or HTTP code.
- `Na.Infrastructure`: `Database/` (ODP.NET via `OracleExecutor`, which wraps each call in a transaction and translates ORA-20001..20099 into `BusinessRuleViolationException`) and `ExternalApis/` (HttpClients with `AddStandardResilienceHandler`).
- `Na.Api`: minimal API on :5100. Signals are `POST /{id}/review|confirm|cancel`; each just raises an event.
- `Na.Worker`: `OutboxRelayWorker` (delivers outbox rows) and `TimerSweepWorker` (calls `pkg_timers.fn_fire_due`; it is only the clock).
- `Na.MockExternalApis`: carrier + notification stand-in; behaviour keyed on MSISDN suffix (`00` 504, `99` 422, `50` fails twice).

### Tests
- `tests/Na.Application.Tests`: unit tests with hand-rolled fakes, plus `CarrierClientTests` (real resilience pipeline over a scripted HTTP handler).
- `tests/Na.IntegrationTests`: one test per scenario in `SCENARIOS.md`, against the real schema. Each test creates its own customers and numbers (no reset needed, re-runnable); time is moved by editing `na_timers.due_at`, not by waiting. Carrier and notification gateways are in-process stubs. Tests run serially because they share the outbox.
- `scripts/demo.sh`: end-to-end check of S1-S9 with real timers and the mock API; exits 1 on a wrong status.

### Database (`database/`)
- `pkg_activations`: `fn_submit` (create, eligibility, risk) and `pr_raise_event` (the single entry point for every status change; locks the row).
- `pkg_workflow_engine`: interprets `na_workflow_branches` + `na_workflow_actions`. The first branch whose condition is true is the only one that fires; no match raises -20010. One `na_audit_log` row per event.
- `pkg_eligibility` (E1-E6, returns all failures), `pkg_risk` (R1-R4, points in `na_risk_factors`, thresholds in `na_config`), `pkg_conditions`, `pkg_timers`, `pkg_outbox`.
- Eligibility/risk outcomes are statuses, not errors. Error codes: -20001 malformed input, -20003 not found, -20010 unhandled event, -20011 unknown timer, -20012 unknown condition, -20013 unknown action, -20014 number no longer available, -20015 unknown notification.
- Carrier allocation is an outbox row with audience CARRIER; the relay calls the carrier and raises `ALLOCATION_SUCCEEDED/FAILED`.
- New schema change: add a new numbered `database/schema/NNN_*.sql`; never edit an applied one. Apply order: all `.pks` before any `.pkb`.
- Timer durations are seeded at demo values (15/30/45 seconds); real values are in a comment in `database/seed/001_seed_reference_data.sql`.
- Gotcha: `SQLERRM` cannot be used directly inside SQL; assign it to a variable first.
