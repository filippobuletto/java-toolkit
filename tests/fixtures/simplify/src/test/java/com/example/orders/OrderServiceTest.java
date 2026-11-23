package com.example.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;

class OrderServiceTest {
    private final OrderService service = new OrderService();

    @Test
    void labels() {
        assertEquals("none", service.describe(null));
        Order order = new Order("o1", List.of("a", "b"));
        assertEquals("o1: open (2 items)", service.describe(order));
        order.markPaid();
        assertEquals("o1: paid (2 items)", service.describe(order));
        order.markShipped();
        assertEquals("o1: shipped (2 items)", service.describe(order));
    }

    @Test
    void emptyOrder() {
        assertEquals("o2: open (empty)", service.describe(new Order("o2", List.of())));
    }
}
