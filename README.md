# Java JAR Test Project

A simple Java application that runs an HTTP server and returns a greeting message.

## Project Structure

```
java-jar-test/
├── build/
│   └── libs/
│       └── project.jar
├── src/
│   └── main/
│       └── java/
│           └── com/
│               └── example/
│                   └── App.java
├── build.gradle
├── settings.gradle
└── README.md
```

## Prerequisites

- Java 11 or higher
- Gradle (optional, as the project includes Gradle Wrapper)

## Building the Project

To build the project and create the JAR file:

```bash
# On Unix/macOS
./gradlew build

# On Windows
gradlew.bat build
```

The JAR file will be created at: `build/libs/project.jar`

## Running the Application

After building, you can run the application with:

```bash
java -jar build/libs/project.jar
```

The server will start on port 9000. Access it at:
```
http://localhost:9000
```

You should see the message: `Hello from Test Project!`

## Changing the Port

To run the server on a different port, modify the `port` variable in `src/main/java/com/example/App.java` and rebuild the project.

## Cleaning the Build

To clean the build directory:

```bash
./gradlew clean
```

## License

This project is for testing purposes only.
