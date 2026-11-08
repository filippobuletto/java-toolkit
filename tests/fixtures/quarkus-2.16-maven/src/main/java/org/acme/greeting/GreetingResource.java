package org.acme.greeting;

import java.util.List;

import javax.inject.Inject;
import javax.transaction.Transactional;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;

@Path("/greetings")
public class GreetingResource {

    @Inject
    GreetingService service;

    @GET
    public List<Greeting> list() {
        return Greeting.listAll();
    }

    @POST
    @Transactional
    public Greeting create(Greeting greeting) {
        return service.save(greeting);
    }
}
