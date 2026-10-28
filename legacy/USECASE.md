# Number Activation — Use Case

A deliberately small telecom service: take a phone number (MSISDN) and move it through an activation workflow governed by business rules.

Built on .NET + Oracle, with all business logic in PL/SQL (same pattern as `markella-mnp`).

## 1. Input

`POST /api/activations`

| Field | Type | Notes |
|---|---|---|
| `msisdn` | string | E.164, e.g. `+306900000123` |
| `customerId` | string | |
| `customerType` | `PREPAID` \| `POSTPAID` | |
| `idVerified` | bool | |
| `planCode` | string | |

Other endpoints: `GET /api/activations/{id}` (status and audit trail), `POST /{id}/review` (`APPROVE|REJECT`), `POST /{id}/confirm` (SIM activated), `POST /{id}/cancel`.

## 2. Statuses and transitions

| From | Event | Guard | To |
|---|---|---|---|
| (new) | REQUEST_RECEIVED | eligibility fails | REJECTED |
| (new) | REQUEST_RECEIVED | eligibility passes | ELIGIBLE |
| ELIGIBLE | RISK_SCORED | decision = AUTO_APPROVE | ALLOCATING |
| ELIGIBLE | RISK_SCORED | decision = MANUAL_REVIEW | MANUAL_REVIEW |
| ELIGIBLE | RISK_SCORED | decision = REJECT | REJECTED |
| MANUAL_REVIEW | REVIEW_APPROVED | | ALLOCATING |
| MANUAL_REVIEW | REVIEW_REJECTED | | REJECTED |
| MANUAL_REVIEW | REVIEW_TIMER_ESCALATE (T1) | | MANUAL_REVIEW (escalated flag set, notify ops) |
| MANUAL_REVIEW | REVIEW_TIMER_EXPIRED (T2) | | EXPIRED (number released) |
| ALLOCATING | ALLOCATION_SUCCEEDED | | AWAITING_ACTIVATION |
| ALLOCATING | ALLOCATION_FAILED | retries exhausted | FAILED |
| AWAITING_ACTIVATION | SIM_CONFIRMED | | ACTIVE |
| AWAITING_ACTIVATION | ACTIVATION_TIMER_EXPIRED (T3) | | EXPIRED (number released back to pool) |
| REQUESTED/ELIGIBLE/MANUAL_REVIEW/AWAITING_ACTIVATION | CUSTOMER_CANCELLED | | CANCELLED (number released if reserved) |

Terminal: `REJECTED`, `EXPIRED`, `FAILED`, `CANCELLED`, `ACTIVE`.
Unhandled (status, event) pairs are an error, never a silent no-op.

## 3. Eligibility rules (evaluated on submit; all must pass)

| Code | Rule | Failure reason |
|---|---|---|
| E1 | MSISDN is valid E.164 and in a supported range (Greek mobile `+30690…`; `+30699…` is the premium range) | INVALID_NUMBER |
| E2 | Number exists in the pool with status `AVAILABLE` | NUMBER_UNAVAILABLE |
| E3 | Customer has no outstanding balance | OUTSTANDING_BALANCE |
| E4 | Customer has fewer than 5 active lines | LINE_LIMIT_EXCEEDED |
| E5 | No open (non-terminal) activation for this customer and number | DUPLICATE_REQUEST |
| E6 | If `PREPAID` and `planCode` is not `STARTER`, `idVerified` must be true | ID_REQUIRED |

E6 deliberately exempts the `STARTER` plan so that R4 (below) stays reachable: a prepaid, unverified customer on `STARTER` passes eligibility but is pushed to manual review by risk scoring.

All failures are collected and returned together, not just the first.

## 4. Risk scoring (additive)

| Code | Factor | Points |
|---|---|---|
| R1 | 3 or more activation requests by this customer in the last 24h | +40 |
| R2 | Customer account created less than 7 days ago | +20 |
| R3 | Number in a premium/high-risk range | +20 |
| R4 | `PREPAID` and not `idVerified` | +30 |

| Score | Decision |
|---|---|
| 0–29 | AUTO_APPROVE |
| 30–69 | MANUAL_REVIEW |
| 70+ | REJECT |

Thresholds, points, limits and windows (5 lines, 3 requests, 24h, 7 days) live in config tables, not code.

## 5. Timers (configurable; demo defaults in seconds)

| Code | Purpose | Real default | Demo default |
|---|---|---|---|
| T1 | Manual review escalation | 24h | 15s |
| T2 | Manual review expiry | 48h | 30s |
| T3 | Customer SIM activation window | 72h | 45s |

Timers are rows in a table, fired by a polling worker; durations come from a config table.

## 6. External integrations (mocked)

- **Carrier allocation (REST):** `POST /carrier/allocate`. Behaviour keyed on MSISDN suffix:
  - ends `00` → 504 gateway timeout every time (exercises retry, then FAILED)
  - ends `99` → 422 hard rejection (FAILED immediately, no retry)
  - ends `50` → fails twice, succeeds on third attempt
  - anything else → success
- **Notifications:** each status change writes an outbox message (audience: `CUSTOMER` → SMS/email, `OPERATIONS` → log/alert). A worker relays to a mock notification endpoint.

## 7. Business error codes (`RAISE_APPLICATION_ERROR`)

Eligibility and risk outcomes are **statuses**, not errors (a rejected request is a successful `201` with `REJECTED` and its reasons). Errors are for malformed input and engine faults:

`-20001` malformed input (missing field, bad enum), `-20003` activation or customer not found, `-20010` unhandled event for current status, `-20011` unknown timer code, `-20012` unknown condition name, `-20013` unknown action type, `-20014` number no longer available (reservation race), `-20015` unknown notification code.

Mapped to HTTP 400 with the message in `detail`.

## 7a. Seed data for the demo scenarios

| Customer | Profile |
|---|---|
| `C-1001` | Clean, long-standing, no balance |
| `C-1002` | Outstanding balance (25.00) |
| `C-1003` | Already has 5 active lines |
| `C-1004` | 3 requests in the last 24h (R1) |
| `C-1005` | Account created yesterday (R2) |
| `C-1006`–`C-1011` | Clean spares, one per demo scenario so R1 velocity is not tripped by the demo itself |

Number pool (Greek mobile numbers): standard numbers `+3069000001xx` (including `…100`, `…150`, `…199` for the carrier behaviours), premium numbers `+30699800000x` (R3), and one number already `ACTIVE` (E2).

## 8. Demo scenarios

Kept in `SCENARIOS.md` so they can grow without touching this spec. The core set (S1-S9) is scripted in `scripts/demo.sh`.
