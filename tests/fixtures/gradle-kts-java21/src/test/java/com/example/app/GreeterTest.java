package com.example.app;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class GreeterTest {
    @Test
    void greets() {
        assertEquals("Hello Ada", new Greeter().greet("Ada"));
    }

    @Test
    void combinesBoth() throws Exception {
        assertEquals("ab", new Greeter().both());
    }
}
