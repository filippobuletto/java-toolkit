package com.example.legacy;

import java.util.List;

public class Shapes {
    public static final String QUERY = "SELECT id, name\n" +
            "FROM shape\n" +
            "WHERE active = 1\n";

    public String describe(Object shape) {
        if (shape instanceof String) {
            String s = (String) shape;
            return "named " + s;
        } else if (shape instanceof Integer) {
            Integer sides = (Integer) shape;
            return sides + " sides";
        }
        return "unknown";
    }

    public String kind(int sides) {
        String result;
        switch (sides) {
            case 3:
                result = "triangle";
                break;
            case 4:
                result = "square";
                break;
            default:
                result = "polygon";
        }
        return result;
    }

    public String last(List<String> names) {
        return names.get(names.size() - 1);
    }

    public Integer boxed(int n) {
        return new Integer(n);
    }
}
