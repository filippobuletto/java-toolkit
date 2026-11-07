package com.example.legacy;

import java.util.Objects;

public final class Order {
    private final String id;
    private final int quantity;

    public Order(String id, int quantity) {
        this.id = id;
        this.quantity = quantity;
    }

    public String getId() { return id; }
    public int getQuantity() { return quantity; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Order)) return false;
        Order other = (Order) o;
        return quantity == other.quantity && Objects.equals(id, other.id);
    }

    @Override
    public int hashCode() { return Objects.hash(id, quantity); }

    @Override
    public String toString() { return "Order[id=" + id + ", quantity=" + quantity + "]"; }
}
