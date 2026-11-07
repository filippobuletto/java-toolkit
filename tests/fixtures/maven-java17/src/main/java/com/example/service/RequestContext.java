package com.example.service;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;
import java.util.List;

public class RequestContext {
    private static final ThreadLocal<String> USER = new ThreadLocal<>();
    private final ExecutorService pool = Executors.newFixedThreadPool(200);

    public void check() {
        if (System.getSecurityManager() != null) {
            System.getSecurityManager().checkPermission(new RuntimePermission("exitVM"));
        }
    }

    public List<String> upper(List<String> in) {
        return in.stream().map(String::toUpperCase).collect(Collectors.toList());
    }

    public static void load() {
        System.loadLibrary("fastcodec");
    }
}
