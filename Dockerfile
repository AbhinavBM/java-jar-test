# Use a lightweight base image with Java 17
FROM eclipse-temurin:17-jre-jammy

# Set environment variables
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"
ENV PORT=9000

# Create a non-root user
RUN addgroup --system javauser && adduser --system --group javauser

# Set working directory
WORKDIR /app

# Copy the built JAR into the image
COPY --chown=javauser:javauser build/libs/*.jar app.jar

# Expose the port your app runs on
EXPOSE ${PORT}

# Run as non-root user for security
USER javauser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT} || exit 1

# Start the application with exec form for better signal handling
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
