package org.acme.greeting;

import javax.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class GreetingService {

    public Greeting save(Greeting greeting) {
        greeting.persist();
        return greeting;
    }
}
