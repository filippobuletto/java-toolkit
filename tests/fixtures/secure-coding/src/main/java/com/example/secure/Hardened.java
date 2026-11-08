package com.example.secure;

import java.io.IOException;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Date;
import java.util.List;
import java.util.Objects;

/**
 * Safe counterparts of the patterns in the other classes. Avoid {@code new ObjectInputStream(in)},
 * {@code con.createStatement()} and {@code Runtime.getRuntime().exec(cmd)} for untrusted input.
 */
public final class Hardened {
    // new ProcessBuilder("sh", "-c", command) is what Injection.shell does
    public static final List<String> ALLOWED = List.of("reader", "writer");

    private final Date created;

    public Hardened(Date created) {
        this.created = new Date(created.getTime());
    }

    public Date created() {
        return new Date(created.getTime());
    }

    ResultSet findUser(Connection con, String name) throws SQLException {
        PreparedStatement stmt = con.prepareStatement("SELECT * FROM users WHERE name = ?");
        stmt.setString(1, name);
        return stmt.executeQuery();
    }

    static Path inside(Path base, String name) throws IOException {
        Path root = base.toRealPath();
        Path candidate = root.resolve(name).normalize();
        if (!candidate.startsWith(root)) {
            throw new IllegalArgumentException("path escapes base");
        }
        return candidate;
    }

    static double finite(String text) {
        double value = Double.parseDouble(text);
        if (!Double.isFinite(value)) {
            throw new IllegalArgumentException("not finite");
        }
        return value;
    }

    private native int digest(byte[] data, int offset, int length);

    public int digestOf(byte[] data, int offset, int length) {
        Objects.checkFromIndexSize(offset, length, data.length);
        return digest(data.clone(), offset, length);
    }
}
