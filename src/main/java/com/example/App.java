package com.example;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.Headers;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public class App {
    private static final AtomicBoolean isHealthy = new AtomicBoolean(true);
    private static final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
    
    public static void main(String[] args) throws Exception {
        int port = getPort();
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        
        // Add shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("Shutting down gracefully...");
            isHealthy.set(false);
            scheduler.shutdown();
            server.stop(0);
        }));
        
        // Health check endpoint
        server.createContext("/health", exchange -> {
            Headers headers = exchange.getResponseHeaders();
            headers.set("Content-Type", "application/json");
            
            if (isHealthy.get()) {
                String response = String.format(
                    "{\"status\":\"UP\",\"timestamp\":\"%s\"}",
                    Instant.now().toString()
                );
                exchange.sendResponseHeaders(200, response.length());
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(response.getBytes(StandardCharsets.UTF_8));
                }
            } else {
                String response = "{\"status\":\"DOWN\"}";
                exchange.sendResponseHeaders(503, response.length());
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(response.getBytes(StandardCharsets.UTF_8));
                }
            }
        });
        
        // Root endpoint
        server.createContext("/", exchange -> {
            String response = "Hello from Test Project!\n";
            exchange.getResponseHeaders().set("Content-Type", "text/plain");
            exchange.sendResponseHeaders(200, response.length());
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(response.getBytes(StandardCharsets.UTF_8));
            }
        });
        
        // Start the server
        server.start();
        System.out.println("Server started on port " + port);
        System.out.println("Access the server at: http://localhost:" + port);
        System.out.println("Health check: http://localhost:" + port + "/health");
    }
    
    private static int getPort() {
        String port = System.getenv("PORT");
        if (port != null && !port.isEmpty()) {
            try {
                return Integer.parseInt(port);
            } catch (NumberFormatException e) {
                System.err.println("Invalid PORT environment variable. Using default 9000");
            }
        }
        return 9000;
    }
}
