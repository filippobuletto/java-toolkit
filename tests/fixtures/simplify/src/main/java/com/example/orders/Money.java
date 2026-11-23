package com.example.orders;

import java.util.Objects;

final class Money {
    private final long cents;
    private final String currency;

    Money(long cents, String currency) {
        Objects.requireNonNull(currency, "currency");
        this.cents = cents;
        this.currency = currency;
    }

    long cents() {
        return cents;
    }

    String currency() {
        return currency;
    }

    Money plus(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("currency mismatch: " + currency + " vs " + other.currency);
        }
        return new Money(cents + other.cents, currency);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof Money)) {
            return false;
        }
        Money other = (Money) o;
        return cents == other.cents && currency.equals(other.currency);
    }

    @Override
    public int hashCode() {
        return Objects.hash(cents, currency);
    }

    @Override
    public String toString() {
        return "Money[cents=" + cents + ", currency=" + currency + "]";
    }
}
