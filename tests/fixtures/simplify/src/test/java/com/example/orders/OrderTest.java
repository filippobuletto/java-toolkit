package com.example.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class OrderTest {

    @Test
    void constructorCopiesItems() {
        List<String> items = new ArrayList<>(List.of("a"));
        Order order = new Order("o1", items);
        items.add("b");
        assertEquals(List.of("a"), order.getItems());
    }

    @Test
    void getItemsReturnsMutableCopy() {
        Order order = new Order("o1", List.of("a"));
        List<String> view = order.getItems();
        view.add("b");
        assertEquals(List.of("a"), order.getItems());
    }

    @Test
    void nullIdIsRejectedWithName() {
        NullPointerException e = assertThrows(NullPointerException.class, () -> new Order(null, List.of()));
        assertEquals("id", e.getMessage());
    }

    @Test
    void nullItemsAreRejected() {
        assertThrows(NullPointerException.class, () -> new Order("o1", null));
    }

    @Test
    void shippingRequiresPayment() {
        Order order = new Order("o1", List.of());
        IllegalStateException e = assertThrows(IllegalStateException.class, order::markShipped);
        assertEquals("order o1 is not paid", e.getMessage());
        assertFalse(order.isShipped());
        order.markPaid();
        order.markShipped();
        assertTrue(order.isShipped());
    }
}
