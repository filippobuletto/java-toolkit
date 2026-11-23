package com.example.orders;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class Order {
    private final String id;
    private final List<String> items;
    private boolean paid;
    private boolean shipped;

    public Order(String id, List<String> items) {
        this.id = Objects.requireNonNull(id, "id");
        // Callers reuse their list after building an order.
        this.items = new ArrayList<>(items);
    }

    public String getId() {
        return id;
    }

    public List<String> getItems() {
        return new ArrayList<>(items);
    }

    public boolean isPaid() {
        return paid;
    }

    public boolean isShipped() {
        return shipped;
    }

    public void markPaid() {
        // set paid to true
        this.paid = true;
    }

    public void markShipped() {
        if (!paid) {
            throw new IllegalStateException("order " + id + " is not paid");
        }
        this.shipped = true;
    }
}
