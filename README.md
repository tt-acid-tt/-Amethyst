# Amethyst — GitHub Actions build

The **Build Amethyst** workflow compiles the updated `AmethystConfig` and `WetFloor` classes, remaps `WetFloor` from Yarn to Intermediary, packages the mod JAR, validates the JAR/shaders, and creates a source ZIP.

## One-time build input upload

The repository needs the binary input bundle `Amethyst-CI-Input.zip` in its root. Upload that ZIP as a single file using **Add file → Upload files** and commit it. It contains the Minecraft 1.21.11 Yarn/Fabric compile cache, remapper, staged mod classes, resources, and sources required by the incremental build. Do not extract it before uploading.

After that commit, Actions starts automatically.

## Download

Open **Actions → Build Amethyst → latest successful run → Artifacts** and download:

- `Amethyst-WetFloor-JAR` — ready-to-install Fabric JAR.
- `Amethyst-WetFloor-Source` — source archive.

Artifacts are kept for 30 days. You can also start a run manually with **Run workflow** after the input ZIP is present.

The compile-only stubs under `ci/stubs` are not packaged into the mod JAR; they only let the incremental compiler resolve APIs that are supplied by Minecraft/Fabric at runtime.
