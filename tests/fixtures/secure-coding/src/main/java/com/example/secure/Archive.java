package com.example.secure;

import java.io.IOException;
import java.io.InputStream;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipInputStream;

public class Archive {
    static ZipInputStream open(InputStream in) {
        return new ZipInputStream(in);
    }

    static GZIPInputStream gunzip(InputStream in) throws IOException {
        return new GZIPInputStream(in);
    }
}
