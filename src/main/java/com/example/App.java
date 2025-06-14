package com.example;

import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class App {
    public static void main(String[] args) throws Exception {
        int port = 9000;
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        
        // Create a simple context that returns "Hello from Test Project!"
        server.createContext("/", exchange -> {
            String response = "Hello from Test Project!\n";
            exchange.sendResponseHeaders(200, response.length());
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(response.getBytes());
            }
        });
        
        // Start the server
        server.start();
        System.out.println("Server started on port " + port);
        System.out.println("Access the server at: http://localhost:" + port);
    }
}
