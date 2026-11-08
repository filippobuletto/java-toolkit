package com.example.secure;

import java.io.InputStream;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.stream.XMLInputFactory;
import javax.xml.transform.TransformerFactory;
import org.w3c.dom.Document;

public class Xml {
    static Document parse(InputStream in) throws Exception {
        return DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(in);
    }

    static XMLInputFactory stax() {
        return XMLInputFactory.newInstance();
    }

    static TransformerFactory xslt() {
        return TransformerFactory.newInstance();
    }
}
