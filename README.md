# Java JAR Test Project

A simple Spring Boot application that runs a web server and returns a greeting message.

## Project Structure

```
java-jar-test/
└── build/
    └── libs/
        └── project.jar
```

## Prerequisites

- Java 17 or higher
- Port 9000 available (or modify the port as needed)

## Running the Application

1. Navigate to the project directory:
   ```bash
   cd java-jar-test
   ```

2. Run the JAR file:
   ```bash
   java -jar build/libs/project.jar
   ```

3. The application will start on port 9000 by default.

### Changing the Port

To run on a different port (e.g., 8080):
```bash
java -Dserver.port=8080 -jar build/libs/project.jar
```

## Accessing the Application

Once running, open your web browser and visit:
```
http://localhost:9000
```

You should see the message: `Hello from Test Project!`

## Building from Source (Optional)

If you have the source code and want to rebuild the JAR:

1. Ensure you have Gradle installed
2. Run:
   ```bash
   ./gradlew clean build
   ```
3. The JAR will be generated in `build/libs/project.jar`

## Stopping the Application

Press `Ctrl+C` in the terminal where the application is running to stop it.

## Troubleshooting

- **Port already in use**: If you see an error about port 9000 being in use, either:
  - Stop the process using port 9000, or
  - Run the application on a different port using the `-Dserver.port` flag

- **Java version issues**: Ensure you have Java 17 or higher installed

## License

This project is for testing purposes only.
