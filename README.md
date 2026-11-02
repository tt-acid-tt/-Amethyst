# Amethyst — WetFloor downloads

This repository is prepared to publish the mod JAR and source archive as separate GitHub Actions artifacts.

## Files required in the repository root

- `amethyst-wetfloor-fixed.jar`
- `Amethyst-WetFloor-Source.zip`

## How to publish downloads

1. Upload those two files to the repository root (Add file → Upload files).
2. Open **Actions** → **Amethyst downloads**.
3. Select **Run workflow** → **Run workflow**.
4. Open the completed run and download the two entries under **Artifacts**:
   - `Amethyst-WetFloor-JAR`
   - `Amethyst-WetFloor-Source`

Artifacts are retained for 30 days. The workflow does not overwrite or delete repository files.
