package com.example.orders;

public class OrderService {

    public String describe(Order order) {
        String result;
        if (order != null) {
            if (order.getItems().size() > 0) {
                result = order.getId() + ": " + StatusLabels.forOrder(order) + " (" + order.getItems().size() + " items)";
            } else {
                result = order.getId() + ": " + StatusLabels.forOrder(order) + " (empty)";
            }
        } else {
            result = StatusLabels.forOrder(order);
        }
        return result;
    }
}
