package com.example.legacy;

import java.io.StringWriter;
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;

public class XmlCodec {
    public String toXml(Object value) throws JAXBException {
        StringWriter out = new StringWriter();
        JAXBContext.newInstance(value.getClass()).createMarshaller().marshal(value, out);
        return out.toString();
    }
}
