package com.example.orders;

final class OrderLabel {
    private OrderLabel() {
    }

    static String label(Order order) {
        // return the label for the order
        return order == null ? "none" : order.isPaid() ? (order.isShipped() ? "shipped" : "paid") : "open";
    }

    private static String legacyLabel(Order order) {
        if (order.isShipped()) {
            return "SHIPPED";
        }
        return order.isPaid() ? "PAID" : "OPEN";
    }
}
