package com.example.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class MoneyTest {

    @Test
    void valueSemantics() {
        Money a = new Money(100, "EUR");
        Money b = new Money(100, "EUR");
        assertEquals(a, b);
        assertEquals(a.hashCode(), b.hashCode());
        assertNotEquals(a, new Money(100, "USD"));
        assertNotEquals(a, null);
        assertEquals(100, a.cents());
        assertEquals("EUR", a.currency());
    }

    @Test
    void toStringFormat() {
        assertEquals("Money[cents=100, currency=EUR]", new Money(100, "EUR").toString());
    }

    @Test
    void nullCurrencyIsRejectedWithName() {
        NullPointerException e = assertThrows(NullPointerException.class, () -> new Money(1, null));
        assertEquals("currency", e.getMessage());
    }

    @Test
    void plus() {
        assertEquals(new Money(250, "EUR"), new Money(100, "EUR").plus(new Money(150, "EUR")));
        IllegalArgumentException e = assertThrows(IllegalArgumentException.class,
                () -> new Money(1, "EUR").plus(new Money(1, "USD")));
        assertEquals("currency mismatch: EUR vs USD", e.getMessage());
    }
}
