package org.acme.orders;

import io.smallrye.mutiny.Uni;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;

@Path("/orders")
public class OrderResource {

    @POST
    @Transactional
    public Uni<String> place(String order) {
        return Uni.createFrom().item(order);
    }
}
