package com.example.orders;

final class StatusLabels {
    private StatusLabels() {
    }

    static String forOrder(Order order) {
        return OrderLabel.label(order);
    }
}
