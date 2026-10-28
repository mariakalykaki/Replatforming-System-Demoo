# Pizza Maker Simulator — walkthrough

A worked example of "take an online order" built on this scaffold's stack.
Read this alongside the code — it's short on purpose. Start the app first:

```bash
make up
mvn quarkus:dev
```

## ⚠️ Before you start: the store-hours rule

One of the Drools rules (`src/main/resources/rules/pizza-rules.drl`) rejects
every order placed outside **11:00–22:00 server local time**. If you're
trying this outside that window, every order below will come back `400`
with `"Store is closed..."` — that's the rule working correctly, not a bug.
To test anytime, temporarily widen or comment out the
`"Store is only open 11:00-22:00"` rule, save, and `mvn quarkus:dev` will
hot-reload it.

## 1. Place a valid order

```bash
curl -s -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "customerName": "Ada",
    "pizzas": [
      { "size": "MEDIUM", "toppings": ["pepperoni", "mushroom"] },
      { "size": "SMALL",  "toppings": ["olives"] }
    ]
  }' | tee /tmp/order.json

ORDER_ID=$(python3 -c "import json;print(json.load(open('/tmp/order.json'))['id'])")
echo "Order ID: $ORDER_ID"
```

You should get back `202 Accepted` with `"status":"RECEIVED"`. Behind that
one response:

1. Price was computed in Java (`OrderResource.basePrice` + topping price).
2. Drools checked it (`PizzaOrderValidator` → `pizza-rules.drl`) against the
   order-validation and store-capacity/hours rules.
3. Camel called the mocked payment gateway (`PaymentGatewayRoute` →
   WireMock stub at `infra/wiremock/mappings/payment-gateway.json`), which
   always approves.
4. The order was persisted (`appdb`, table `pizza_order`/`pizza_item`).
5. A `PizzaOrderWorkflow` was started in Temporal.

## 2. Watch it cook

```bash
watch -n1 "curl -s http://localhost:8080/orders/$ORDER_ID"
```

Over about 15 seconds you should see `status` move
`RECEIVED → PREPARING → BAKING → READY` (5s prep + 10s bake, hardcoded in
`PizzaOrderWorkflowImpl` — change those constants to speed up/slow down).

At the same time:

- **Temporal UI** (http://localhost:8088) — find the workflow by ID
  `pizza-order-<id>`, see each activity call (`updateStatus`,
  `publishStatusEvent`) and the timers between them.
- **Kafka UI** (http://localhost:8089) — topic `order-events` gets one
  message per status transition.
- **Adminer** (http://localhost:8081) — browse `pizza_order` / `pizza_item`
  / `pizza_item_topping` directly.

## 3. Trigger each rejection rule

**Below minimum order value** ($10.00):

```bash
curl -s -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerName":"Bob","pizzas":[{"size":"SMALL","toppings":[]}]}'
# -> 400, "Order total must be at least $10.00 (currently $8.00)."
```

**Too many toppings** (max 6):

```bash
curl -s -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerName":"Cleo","pizzas":[{"size":"LARGE","toppings":["pepperoni","mushroom","olives","onion","ham","pineapple","anchovy"]}]}'
# -> 400, "A pizza can have at most 6 toppings (one has 7)."
```

**Size/topping conflict** (no stuffed crust on small):

```bash
curl -s -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{"customerName":"Dev","pizzas":[{"size":"SMALL","toppings":["stuffed-crust"]}]}'
# -> 400, "Stuffed crust isn't available on small pizzas."
```

**Kitchen at capacity**: place 5 valid orders back to back (without waiting
for them to reach `READY`) and a 6th will be rejected with "Kitchen is at
capacity" — `kitchenLoad` is a live count of orders currently `PREPARING`
or `BAKING` (see `OrderResource.createOrder`).

## Things to try changing

- Add a new rule to `pizza-rules.drl` (e.g. reject orders with more than 4
  pizzas) — no Java changes needed, just restart `mvn quarkus:dev`.
- Change `PREP_TIME`/`BAKE_TIME` in `PizzaOrderWorkflowImpl` and watch the
  timing change in Temporal UI.
- Make the mocked payment gateway decline sometimes: edit
  `infra/wiremock/mappings/payment-gateway.json`, or add a second mapping
  matching on a request body field, and see `OrderResource` reject the
  order with `402 Payment Required`.
- Add a `/orders` listing endpoint, or a Kafka consumer that logs every
  `order-events` message (see the root `docs/FIRST-STEPS.md` Kafka section
  for the `@Incoming` pattern).
