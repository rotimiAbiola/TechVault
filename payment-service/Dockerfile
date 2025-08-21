FROM openjdk:17-jdk-slim

WORKDIR /app

# Install curl and maven for health checks and building
RUN apt-get update && apt-get install -y curl maven && rm -rf /var/lib/apt/lists/*

# Copy pom.xml
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5004

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5004/health || exit 1

# Run the application
CMD ["java", "-jar", "target/payment-service-1.0.0.jar"]
