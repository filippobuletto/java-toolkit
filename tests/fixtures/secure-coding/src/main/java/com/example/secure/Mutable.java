package com.example.secure;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class Mutable implements Cloneable {
    public static int counter = 0;
    public static final String[] ROLES = {"reader", "writer"};
    public static final List<String> NAMES = new ArrayList<>();

    private Date created = new Date();

    public Date created() {
        return created;
    }

    public native int digest(byte[] data, int offset, int length);
}
