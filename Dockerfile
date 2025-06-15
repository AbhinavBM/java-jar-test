# Use a lightweight base image with Java 17
FROM eclipse-temurin:17-jre-jammy

# Set environment variables
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
ENV PORT=9000
ENV HEALTH_CHECK_PATH=/health

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN addgroup --system javauser && adduser --system --group javauser

# Set working directory
WORKDIR /app

# Copy the built JAR into the image
COPY --chown=javauser:javauser build/libs/*.jar app.jar

# Create a health check script
RUN echo '#!/bin/sh \n\
# Check if the application is responding to health checks \n\
curl -f http://localhost:${PORT}${HEALTH_CHECK_PATH} \n' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Expose the port your app runs on
EXPOSE ${PORT}

# Run as non-root user for security
USER javauser

# Health check configuration
HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=10s \
            --retries=3 \
            CMD ["/bin/sh", "/healthcheck.sh"]

# Start the application with exec form for better signal handling
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
