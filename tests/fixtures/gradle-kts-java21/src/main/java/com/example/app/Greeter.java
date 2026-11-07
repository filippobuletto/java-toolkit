package com.example.app;

import java.util.concurrent.StructuredTaskScope;

public class Greeter {
    public String greet(String name) {
        return STR."Hello \{name}";
    }

    public String both() throws Exception {
        try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
            var a = scope.fork(() -> "a");
            var b = scope.fork(() -> "b");
            scope.join().throwIfFailed();
            return a.get() + b.get();
        }
    }
}
