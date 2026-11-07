#!/bin/sh
exec java -XX:+UseConcMarkSweepGC -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:gc.log -XX:MaxPermSize=256m -jar target/legacy.jar "$@"
