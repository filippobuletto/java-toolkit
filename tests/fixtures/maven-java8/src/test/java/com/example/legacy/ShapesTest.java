package com.example.legacy;

import static org.junit.Assert.assertEquals;

import java.util.Arrays;
import org.junit.Test;

public class ShapesTest {
    @Test
    public void describesShapes() {
        Shapes shapes = new Shapes();
        assertEquals("named box", shapes.describe("box"));
        assertEquals("3 sides", shapes.describe(3));
        assertEquals("triangle", shapes.kind(3));
        assertEquals("polygon", shapes.kind(7));
        assertEquals("c", shapes.last(Arrays.asList("a", "b", "c")));
    }

    @Test
    public void ordersAreValues() {
        assertEquals(new Order("a", 1), new Order("a", 1));
        assertEquals("Order[id=a, quantity=1]", new Order("a", 1).toString());
    }

    @Test
    public void nativeBufferRoundTrip() {
        NativeBuffer buffer = new NativeBuffer(16);
        buffer.putInt(4, 42);
        assertEquals(42, buffer.getInt(4));
    }
}
