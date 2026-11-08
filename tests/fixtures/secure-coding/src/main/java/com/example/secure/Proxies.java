package com.example.secure;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;

public class Proxies implements InvocationHandler {
    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        return method.invoke(this, args);
    }
}
