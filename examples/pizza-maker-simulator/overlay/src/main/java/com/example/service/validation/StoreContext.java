package com.example.service.validation;

import java.time.LocalTime;

/** Facts about the store at the moment an order comes in, separate from the order itself. */
public class StoreContext {

    public final LocalTime now;
    public final int kitchenLoad;

    public StoreContext(LocalTime now, int kitchenLoad) {
        this.now = now;
        this.kitchenLoad = kitchenLoad;
    }

    // Drools' DRL compiler needs a JavaBean-style getter to resolve the type
    // of a property that's then called with a method in a rule constraint
    // (e.g. `now.isBefore(...)` in pizza-rules.drl).
    public LocalTime getNow() {
        return now;
    }

    public int getKitchenLoad() {
        return kitchenLoad;
    }
}
