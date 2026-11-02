package org.slf4j;
public interface Logger {
    void info(String message, Object... args);
    void warn(String message, Object... args);
}
