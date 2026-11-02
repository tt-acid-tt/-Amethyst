package net.fabricmc.loader.api;
public class FabricLoader {
    public static FabricLoader getInstance() { return new FabricLoader(); }
    public java.nio.file.Path getGameDir() { return java.nio.file.Path.of("."); }
    public java.nio.file.Path getConfigDir() { return java.nio.file.Path.of("."); }
}
