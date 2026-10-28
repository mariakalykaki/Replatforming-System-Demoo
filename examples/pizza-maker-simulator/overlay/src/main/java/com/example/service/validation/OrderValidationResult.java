package com.example.service.validation;

import java.util.ArrayList;
import java.util.List;

/** Mutable fact that rules write to, rather than returning a value from the rules engine. */
public class OrderValidationResult {

    private boolean rejected = false;
    private final List<String> reasons = new ArrayList<>();

    public void reject(String reason) {
        rejected = true;
        reasons.add(reason);
    }

    public boolean isRejected() {
        return rejected;
    }

    public List<String> getReasons() {
        return reasons;
    }
}
