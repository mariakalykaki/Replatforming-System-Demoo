package com.example.service.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;

import org.kie.api.KieServices;
import org.kie.api.runtime.KieContainer;

/**
 * Wires the embedded Drools engine into CDI. Quarkus has no first-party
 * Drools extension, so the KieContainer is built the plain-Java way from
 * the classpath (src/main/resources/META-INF/kmodule.xml + rules/*.drl).
 */
@ApplicationScoped
public class DroolsProducer {

    @Produces
    @ApplicationScoped
    public KieContainer kieContainer() {
        return KieServices.Factory.get().getKieClasspathContainer();
    }
}
