#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h}"
USER_HOME_DIR="${HOME:?}"
SUPPORT_DIR="${QUARTZ_SUPPORT_DIR:-$USER_HOME_DIR/Library/Application Support/Quartz}"
HELPER_DIR="$SUPPORT_DIR/Helpers"
DESTINATION="$HELPER_DIR/quartz-mcp"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/quartz-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/quartz-swiftpm-cache"

cd "$PROJECT_DIR"
swift build -c release --product quartz-mcp
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$HELPER_DIR"
chmod 700 "$HELPER_DIR"
install -m 755 "$BIN_DIR/quartz-mcp" "$DESTINATION"
codesign --force --sign - --timestamp=none "$DESTINATION" >/dev/null
codesign --verify --strict "$DESTINATION"

print "✓ Serveur MCP Quartz installé"
print "  Chemin stable : $DESTINATION"
