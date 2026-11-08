package com.example.secure;

import java.beans.XMLDecoder;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.Serializable;

public class Deserialization {
    static Object read(InputStream in) throws IOException, ClassNotFoundException {
        try (ObjectInputStream ois = new ObjectInputStream(in)) {
            return ois.readObject();
        }
    }

    static Object readBean(InputStream in) {
        try (XMLDecoder decoder = new XMLDecoder(in)) {
            return decoder.readObject();
        }
    }

    static class Token implements Serializable {
        private static final long serialVersionUID = 1L;
        private String value;

        private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
            in.defaultReadObject();
        }
    }
}
