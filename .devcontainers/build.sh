#!/usr/bin/env bash
###############################################################################
# Nexus Go — codespace build script
#
# Assumes the devcontainer has already run setup-sdk.sh, so ANDROID_HOME and
# Java are ready. This script:
#   1. Generates the full Android project from the embedded JSON manifest
#   2. Creates a release keystore (if missing)
#   3. Downloads the Gradle wrapper
#   4. Builds the release APK
#
# Usage (from the repo root inside the codespace):
#   chmod +x build.sh
#   ./build.sh
#
# Output APK: NexusGo/app/build/outputs/apk/release/app-release.apk
###############################################################################
set -euo pipefail

PROJECT_DIR="${1:-NexusGo}"
JSON_FILE="${JSON_FILE:-nexus_go_project.json}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Sanity checks
# ---------------------------------------------------------------------------
[ -f "$JSON_FILE" ] || { err "Missing $JSON_FILE in current directory"; exit 1; }
command -v java >/dev/null 2>&1 || { err "Java not found"; exit 1; }
[ -n "${ANDROID_HOME:-}" ] || { err "ANDROID_HOME not set — run .devcontainer/setup-sdk.sh first"; exit 1; }

# Pick a JSON unpacker
if command -v node >/dev/null 2>&1; then
    UNPACKER="node"
elif command -v python3 >/dev/null 2>&1; then
    UNPACKER="python3"
else
    err "Need either node or python3 to unpack the project JSON"
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Unpack project files
# ---------------------------------------------------------------------------
log "Unpacking $JSON_FILE into $PROJECT_DIR/"
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

if [ "$UNPACKER" = "node" ]; then
    node -e "
        const fs = require('fs'), path = require('path');
        const o = JSON.parse(fs.readFileSync('$JSON_FILE','utf8'));
        for (const [k,v] of Object.entries(o.files)) {
            const t = path.join('$PROJECT_DIR', k);
            fs.mkdirSync(path.dirname(t), { recursive: true });
            fs.writeFileSync(t, v);
        }
        console.log('   wrote ' + Object.keys(o.files).length + ' files');
    "
else
    python3 -c "
import json, os
o = json.load(open('$JSON_FILE'))
for k, v in o['files'].items():
    t = os.path.join('$PROJECT_DIR', k)
    os.makedirs(os.path.dirname(t), exist_ok=True)
    open(t, 'w').write(v)
print('   wrote ' + str(len(o['files'])) + ' files')
"
fi

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# 3. local.properties — point Gradle at the Android SDK
# ---------------------------------------------------------------------------
log "Writing local.properties (sdk.dir=$ANDROID_HOME)"
echo "sdk.dir=$ANDROID_HOME" > local.properties

# ---------------------------------------------------------------------------
# 4. Release keystore
# ---------------------------------------------------------------------------
if [ ! -f release.keystore ]; then
    log "Generating release keystore (alias=nexusgo, password=nexusgo)"
    keytool -genkeypair -v -keystore release.keystore -alias nexusgo \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass nexusgo -keypass nexusgo \
        -dname "CN=NexusGo, OU=Dev, O=NexusGo, L=NA, ST=NA, C=IN" \
        >/dev/null 2>&1
fi

# ---------------------------------------------------------------------------
# 5. Gradle wrapper jar
# ---------------------------------------------------------------------------
if [ ! -f gradle/wrapper/gradle-wrapper.jar ]; then
    log "Downloading gradle-wrapper.jar"
    curl -fsSL -o gradle/wrapper/gradle-wrapper.jar \
        https://github.com/gradle/gradle/raw/v8.2.0/gradle/wrapper/gradle-wrapper.jar
fi

chmod +x gradlew 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Reminder about Firebase config
# ---------------------------------------------------------------------------
if grep -q "REPLACE_ME\|REPLACE-WITH-REAL\|nexus-go-REPLACE" app/google-services.json 2>/dev/null; then
    err "WARNING: app/google-services.json is still the placeholder."
    err "         Build will succeed but Firebase features will not work."
    err "         Replace it with your real config from console.firebase.google.com"
fi

# ---------------------------------------------------------------------------
# 7. Build the APK
# ---------------------------------------------------------------------------
log "Building release APK (this takes 3-5 min on first run)"
./gradlew clean assembleRelease

APK="app/build/outputs/apk/release/app-release.apk"
if [ -f "$APK" ]; then
    SIZE=$(du -h "$APK" | cut -f1)
    log "Done. APK ($SIZE) ready at:"
    echo "    $(pwd)/$APK"
else
    err "Build finished but APK not found at $APK"
    exit 1
fi
