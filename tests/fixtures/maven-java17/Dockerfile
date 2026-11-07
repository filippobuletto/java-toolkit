FROM eclipse-temurin:17-jre
COPY target/service.jar /app/service.jar
ENTRYPOINT ["java", "-XX:+UseZGC", "-XX:+ZGenerational", "-XX:+UseBiasedLocking", "--illegal-access=permit", "-jar", "/app/service.jar"]
