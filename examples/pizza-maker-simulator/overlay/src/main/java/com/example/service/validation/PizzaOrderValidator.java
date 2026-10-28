package com.example.service.validation;

import com.example.service.domain.PizzaItem;
import com.example.service.domain.PizzaOrder;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;

import java.time.LocalTime;

@ApplicationScoped
public class PizzaOrderValidator {

    @Inject
    KieContainer kieContainer;

    public OrderValidationResult validate(PizzaOrder order, int currentKitchenLoad) {
        OrderValidationResult result = new OrderValidationResult();
        StoreContext context = new StoreContext(LocalTime.now(), currentKitchenLoad);

        // KieSession is stateful and not thread-safe: one per validation call.
        // Named explicitly (matches kmodule.xml) rather than relying on
        // newKieSession()'s zero-arg "default session" lookup, which doesn't
        // reliably resolve it under Quarkus's classloading.
        KieSession session = kieContainer.newKieSession("serviceKSession");
        try {
            session.insert(result);
            session.insert(context);
            session.insert(order);
            for (PizzaItem item : order.items) {
                session.insert(item);
            }
            session.fireAllRules();
        } finally {
            session.dispose();
        }
        return result;
    }
}
