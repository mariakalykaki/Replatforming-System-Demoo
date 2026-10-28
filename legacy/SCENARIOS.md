# Scenarios

Demo and test scenarios for the Number Activation service. `USECASE.md` holds the rules; this file holds the walk-throughs and is meant to grow. Add a row, give it the next ID, and say whether it is automated.

Seed customers and numbers are described in `USECASE.md` section 7a. Timers use demo durations (T1 15s, T2 30s, T3 45s). Each number can be used once per database; reset between runs (see `CLAUDE.md`).

**Coverage:** every scenario S1-S21 has an integration test in `tests/Na.IntegrationTests/ScenarioTests.cs` (method names start with the scenario ID). S1-S9 are also run end to end, with real timers and HTTP, by `scripts/demo.sh`, which fails on any wrong final status. The S4/S5a/S5b carrier retry behaviour is additionally covered by `CarrierClientTests`, because the integration tests use an in-process carrier stub. To add a scenario: add a row here, a test named `S<ID>_...`, and (if it is a core flow) a line in `demo.sh`.

## A. Core demo (all in `scripts/demo.sh`)

| ID | Scenario | Setup | Expected | Behaviour exercised |
|---|---|---|---|---|
| S1 | Happy path | `C-1001`, `+306900000101`, postpaid, verified, `PRO`; then `confirm` | ELIGIBLE → ALLOCATING → AWAITING_ACTIVATION → ACTIVE | Workflow, outbox, carrier call |
| S2 | Review approved | `C-1004` (3 requests in 24h); `review APPROVE`; `confirm` | Score 40 (R1) → MANUAL_REVIEW → ALLOCATING → ACTIVE | Risk scoring, signal |
| S3 | Review ignored | `C-1005` on premium `+306998000001` | Score 40 (R2+R3) → MANUAL_REVIEW → T1 escalates (`escalated=true`) → T2 → EXPIRED | Timers, escalation |
| S4 | Carrier retry | number ending `50` | Carrier fails twice, third attempt succeeds → ACTIVE after confirm | Retry policy |
| S5a | Carrier timeout | number ending `00` | 504 on every attempt → FAILED, number released | Retry exhaustion, failure path |
| S5b | Carrier refusal | number ending `99` | 422, no retry → FAILED | Non-retryable failure |
| S6 | Multi-reason rejection | `C-1002`, prepaid, unverified, `PRO` | REJECTED: `OUTSTANDING_BALANCE`, `ID_REQUIRED` | Eligibility collects all failures |
| S7 | R4 reachable | prepaid, unverified, `STARTER` | Passes E6, R4 +30 → MANUAL_REVIEW | Rule interplay |
| S8 | Customer cancels | cancel while AWAITING_ACTIVATION | CANCELLED, number back to AVAILABLE | Signal, compensation |
| S9 | Activation timeout | never `confirm` | T3 → EXPIRED, number released | Timer in a late stage |

## B. Edge cases and refusals (integration tests only)

| ID | Scenario | Setup | Expected | Behaviour exercised |
|---|---|---|---|---|
| S10 | Line limit | `C-1003` (5 ACTIVE lines), any free number | REJECTED: `LINE_LIMIT_EXCEEDED` | E4 |
| S11 | Number already active | `+306900000201` | REJECTED: `NUMBER_UNAVAILABLE` | E2 |
| S12 | Unsupported range | `+447700900123` (a UK number) | REJECTED: `INVALID_NUMBER`, `NUMBER_UNAVAILABLE` | E1, E2 together |
| S13 | Duplicate open request | submit the same customer + number twice | Second: REJECTED `DUPLICATE_REQUEST` (+ `NUMBER_UNAVAILABLE`, first holds the reservation) | E5, reservation |
| S14 | Review rejected | S2 setup, `review REJECT` | REJECTED, number released | Signal, compensation |
| S15 | Risk reject | `C-1004` + premium `+306998000002` + prepaid, unverified, `STARTER` | Score 90 (R1+R3+R4) → REJECTED, number released | Third risk outcome |
| S16 | Signal in wrong state | `confirm` while MANUAL_REVIEW | HTTP 400, `errorCode` 20010 | Transition guard |
| S17 | Cancel mid-allocation | stop the worker, submit a clean request, `cancel` while ALLOCATING | HTTP 400, `errorCode` 20010 (cancel is not allowed in ALLOCATING) | Transition guard |
| S18 | Unknown activation | `GET /api/activations/999999` | HTTP 404, `errorCode` 20003 | Error mapping |
| S19 | Malformed input | omit `customerType` | HTTP 400, `errorCode` 20001 | Input validation |
| S20 | Number reuse | S8, then a new request for the same number | Second request proceeds normally | Release correctness |
| S21 | Unknown customer | `customerId` not in `na_customers` | HTTP 404, `errorCode` 20003 | Error mapping |

## C. Ideas not yet specified

Add here before promoting to a table: concurrent requests for the same number (reservation race, -20014), outbox delivery failure and re-drive, worker crash with an IN_FLIGHT row, real-duration timer configuration.
