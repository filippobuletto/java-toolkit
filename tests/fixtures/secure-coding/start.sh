#!/usr/bin/env bash
exec java \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  -Dcom.sun.jndi.ldap.object.trustURLCodebase=true \
  -jar app.jar
