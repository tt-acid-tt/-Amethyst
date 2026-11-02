#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INPUT_RAR="$REPO_ROOT/Amethyst-Original-Input.rar"
PATCH_FILE="$REPO_ROOT/ci/wetfloor-fixes.patch"
WORK_BASE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/amethyst-ci-build"
WORK="$WORK_BASE/work"
DIST="$REPO_ROOT/dist"

rm -rf "$WORK_BASE" "$DIST"
mkdir -p "$WORK/extracted" "$DIST"

if [[ -n "${AMETHYST_PROJECT_DIR:-}" ]]; then
  # Local test hook. GitHub Actions does not set this variable.
  PROJECT="$WORK/extracted/amethyst"
  cp -a "$AMETHYST_PROJECT_DIR" "$PROJECT"
else
  if [[ ! -s "$INPUT_RAR" ]]; then
    echo "::error::Missing Amethyst-Original-Input.rar in repository root. Upload the original project RAR once."
    exit 1
  fi
  sudo apt-get update
  sudo apt-get install -y unar
  unar -f -o "$WORK/extracted" "$INPUT_RAR"
  PROJECT="$WORK/extracted/amethyst"
fi

[[ -d "$PROJECT/src/main/java" && -d "$PROJECT/build/stage19" ]] || {
  echo "::error::The RAR does not contain the expected amethyst/src and amethyst/build project folders."
  exit 1
}
[[ -s "$PATCH_FILE" ]] || { echo "::error::Missing ci/wetfloor-fixes.patch"; exit 1; }
patch --batch --forward -p1 -d "$PROJECT" < "$PATCH_FILE"

SRC="$PROJECT/src/main/java"
RES="$PROJECT/src/main/resources"
BUILD="$PROJECT/build"
STAGE="$BUILD/stage19"
VANILLA="$BUILD/dev/vanilla-1.21.11-yarn.jar"
FABRIC_API="$BUILD/dev/fabric-api-yarn-0.141.2.jar"
MAPPINGS="$BUILD/dev/yarn-1.21.11/mappings"
REMAP="$BUILD/remapper-classes"
ASM="$BUILD/dev/asm/asm-9.10.1.jar:$BUILD/dev/asm/asm-tree-9.10.1.jar:$BUILD/dev/asm/asm-commons-9.10.1.jar"
KOTLIN="$STAGE/META-INF/jars/kotlin-stdlib-1.9.0.jar"

for required in "$SRC/ru/amethyst/config/AmethystConfig.java" "$SRC/ru/amethyst/features/WetFloor.java" \
  "$RES/assets/amethyst/shaders/wet/wet_floor.fsh" "$RES/assets/amethyst/shaders/xray/block_overlay.fsh" \
  "$STAGE/fabric.mod.json" "$VANILLA" "$FABRIC_API" "$MAPPINGS" "$REMAP" "$KOTLIN"; do
  [[ -e "$required" ]] || { echo "::error::Missing build input: $required"; exit 1; }
done

java -version
mkdir -p "$WORK/stub-classes" "$WORK/classes"
mapfile -d '' STUB_SOURCES < <(find "$REPO_ROOT/ci/stubs" -name '*.java' -print0)
javac --release 21 -proc:none -encoding UTF-8 -cp "$VANILLA" -d "$WORK/stub-classes" "${STUB_SOURCES[@]}"

CP="$WORK/stub-classes:$STAGE:$VANILLA:$FABRIC_API:$KOTLIN"
javac --release 21 -proc:none -encoding UTF-8 -cp "$CP" -d "$WORK/classes" \
  "$SRC/ru/amethyst/config/AmethystConfig.java" \
  "$REPO_ROOT/ci/stubs/ru/amethyst/mixin/GameRendererFovAccessor.java" \
  "$SRC/ru/amethyst/features/WetFloor.java"

echo "Java incremental compile: OK"

jar cf "$WORK/wetfloor-yarn.jar" -C "$WORK/classes" ru/amethyst/features/WetFloor.class
java -Xmx2g -cp "$REMAP:$ASM" remap.RemapTool yarn2inter "$MAPPINGS" "$WORK/wetfloor-intermediary.jar" \
  --scan "$VANILLA" --scan "$FABRIC_API" -- "$WORK/wetfloor-yarn.jar"

echo "Yarn -> Intermediary remap: OK"

cp "$WORK/classes/ru/amethyst/config/AmethystConfig.class" "$STAGE/ru/amethyst/config/AmethystConfig.class"
(cd "$STAGE" && jar xf "$WORK/wetfloor-intermediary.jar")
rm -rf "$STAGE/assets"
mkdir -p "$STAGE/assets"
cp -a "$RES/assets/." "$STAGE/assets/"
cp "$RES/amethyst.mixins.json" "$STAGE/amethyst.mixins.json"
cp "$RES/smtc_seek.ps1" "$STAGE/smtc_seek.ps1"

jar cf "$DIST/amethyst-wetfloor-fixed.jar" -C "$STAGE" .

python3 - "$DIST/amethyst-wetfloor-fixed.jar" "$RES" <<'PY'
import json, pathlib, sys, zipfile
jar_path = pathlib.Path(sys.argv[1])
res = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(jar_path) as jar:
    bad = jar.testzip()
    if bad:
        raise SystemExit(f"Corrupt JAR entry: {bad}")
    names = set(jar.namelist())
    required = [
        "fabric.mod.json",
        "ru/amethyst/config/AmethystConfig.class",
        "ru/amethyst/features/WetFloor.class",
        "ru/amethyst/features/BlockOverlay.class",
        "ru/amethyst/mixin/GameRendererFovAccessor.class",
        "assets/amethyst/shaders/wet/wet_floor.fsh",
        "assets/amethyst/shaders/wet/wet_screen.vsh",
        "assets/amethyst/shaders/xray/block_overlay.fsh",
    ]
    missing = [item for item in required if item not in names]
    if missing:
        raise SystemExit("Missing JAR entries: " + ", ".join(missing))
    metadata = json.loads(jar.read("fabric.mod.json"))
    if metadata.get("id") != "amethyst":
        raise SystemExit("Unexpected Fabric mod id")
    config = jar.read("ru/amethyst/config/AmethystConfig.class")
    wet_floor = jar.read("ru/amethyst/features/WetFloor.class")
    if b"wetScreenDrops" not in config or b"wetScreenDrops" not in wet_floor:
        raise SystemExit("WetScreenDrops field linkage check failed")
    for rel in ["assets/amethyst/shaders/wet/wet_floor.fsh", "assets/amethyst/shaders/xray/block_overlay.fsh"]:
        source_rel = rel.removeprefix("assets/")
        if jar.read(rel) != (res / "assets" / source_rel).read_bytes():
            raise SystemExit(f"Shader mismatch: {rel}")
    print(f"Validated {metadata['name']} {metadata['version']}: {len(names)} entries")
    print(f"JAR bytes: {jar_path.stat().st_size}")
PY

SOURCE_STAGE="$WORK/source-archive/Amethyst-WetFloor-Source"
mkdir -p "$SOURCE_STAGE"
cp -a "$PROJECT/src" "$SOURCE_STAGE/src"
cp -a "$PROJECT/tools" "$SOURCE_STAGE/tools"
mkdir -p "$SOURCE_STAGE/build"
cp -a "$PROJECT/build/scripts" "$SOURCE_STAGE/build/scripts"
cp "$PROJECT/build/PruneTool.java" "$SOURCE_STAGE/build/PruneTool.java"
cp "$REPO_ROOT/ci/README_RU.md" "$SOURCE_STAGE/README_RU.md"
(cd "$WORK/source-archive" && zip -q -r "$DIST/Amethyst-WetFloor-Source.zip" Amethyst-WetFloor-Source)
unzip -tq "$DIST/Amethyst-WetFloor-Source.zip"
echo "Source archive: OK"
