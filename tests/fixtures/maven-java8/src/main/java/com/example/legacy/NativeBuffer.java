package com.example.legacy;

import java.lang.reflect.Field;
import sun.misc.Unsafe;

public class NativeBuffer {
    private static final Unsafe UNSAFE = loadUnsafe();
    private final long address;

    public NativeBuffer(long bytes) {
        this.address = UNSAFE.allocateMemory(bytes);
    }

    public void putInt(long offset, int value) { UNSAFE.putInt(address + offset, value); }
    public int getInt(long offset) { return UNSAFE.getInt(address + offset); }

    @Override
    protected void finalize() throws Throwable {
        UNSAFE.freeMemory(address);
    }

    private static Unsafe loadUnsafe() {
        try {
            Field f = Unsafe.class.getDeclaredField("theUnsafe");
            f.setAccessible(true);
            return (Unsafe) f.get(null);
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException(e);
        }
    }
}
