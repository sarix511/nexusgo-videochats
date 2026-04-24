#!/usr/bin/env bash
###############################################################################
# Android SDK setup for Nexus Go
# Works in: GitHub Codespaces, VS Code devcontainers, plain Debian/Ubuntu
###############################################################################
set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-$HOME/android-sdk}"
# Bump this to refresh — see https://developer.android.com/studio#command-tools
CLI_VERSION="11076708"
CLI_ZIP="commandlinetools-linux-${CLI_VERSION}_latest.zip"
CLI_URL="https://dl.google.com/android/repository/${CLI_ZIP}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Make sure curl + unzip exist (devcontainers usually have them; bare boxes may not)
# ---------------------------------------------------------------------------
ensure_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log "Installing missing dependency: $1"
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$1"
        else
            apt-get update -qq && apt-get install -y -qq "$1"
        fi
    fi
}
ensure_tool curl
ensure_tool unzip

# ---------------------------------------------------------------------------
# 2. Java check
# ---------------------------------------------------------------------------
if ! command -v java >/dev/null 2>&1; then
    err "Java not found. Install Java 17+ before running this script."
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Download command-line tools (idempotent)
# ---------------------------------------------------------------------------
log "Installing Android SDK to ${SDK_ROOT}"
mkdir -p "${SDK_ROOT}/cmdline-tools"
cd "${SDK_ROOT}/cmdline-tools"

if [ ! -d latest ]; then
    log "Downloading command-line tools (${CLI_VERSION})"
    curl -fsSL -o "${CLI_ZIP}" "${CLI_URL}"
    unzip -q "${CLI_ZIP}"
    mv cmdline-tools latest
    rm -f "${CLI_ZIP}"
else
    log "Command-line tools already present, skipping download"
fi

# ---------------------------------------------------------------------------
# 4. Export env for the current shell
# ---------------------------------------------------------------------------
export ANDROID_HOME="${SDK_ROOT}"
export ANDROID_SDK_ROOT="${SDK_ROOT}"
export PATH="${PATH}:${SDK_ROOT}/cmdline-tools/latest/bin:${SDK_ROOT}/platform-tools"

# ---------------------------------------------------------------------------
# 5. Persist env for future shells (idempotent)
# ---------------------------------------------------------------------------
RC="${HOME}/.bashrc"
touch "${RC}"
if ! grep -q "# Nexus Go Android SDK" "${RC}"; then
    log "Persisting env vars to ${RC}"
    {
        echo ""
        echo "# Nexus Go Android SDK"
        echo "export ANDROID_HOME=${SDK_ROOT}"
        echo "export ANDROID_SDK_ROOT=${SDK_ROOT}"
        echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools"
    } >> "${RC}"
fi

# ---------------------------------------------------------------------------
# 6. Accept licenses + install platform/build tools
# ---------------------------------------------------------------------------
log "Accepting SDK licenses"
yes | sdkmanager --licenses >/dev/null 2>&1 || true

log "Installing platform-tools, platforms;android-34, build-tools;34.0.0"
sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" >/dev/null

log "Done. ANDROID_HOME = ${SDK_ROOT}"
log "Reload your shell or run:  source ~/.bashrc"
