package com.example.secure;

import java.io.IOException;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.logging.Logger;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.script.ScriptEngineManager;

public class Injection {
    private static final Logger LOG = Logger.getLogger("injection");

    ResultSet findUser(Connection con, String name) throws SQLException {
        Statement st = con.createStatement();
        return st.executeQuery("SELECT * FROM users WHERE name = '" + name + "'");
    }

    void remove(Connection con, String id) throws SQLException {
        String sql = "DELETE FROM users WHERE id = " + id;
        try (Statement st = con.createStatement()) {
            st.executeUpdate(sql);
        }
    }

    Process list(String dir) throws IOException {
        return Runtime.getRuntime().exec("ls " + dir);
    }

    Process shell(String command) throws IOException {
        return new ProcessBuilder("sh", "-c", command).start();
    }

    Object eval(String code) throws Exception {
        return new ScriptEngineManager().getEngineByName("js").eval(code);
    }

    Object resolve(String name) throws NamingException {
        return new InitialContext().lookup(name);
    }

    void audit(String user, String password) {
        LOG.info("login " + user + " with " + password);
    }
}
