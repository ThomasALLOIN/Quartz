#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h}"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Quartz.app"
VERSION="${QUARTZ_VERSION:-1.0.0}"
BUILD_NUMBER="${QUARTZ_BUILD_NUMBER:-1}"
BUNDLE_ID="${QUARTZ_BUNDLE_ID:-com.thomasalloin.Quartz}"
SIGN_IDENTITY="${QUARTZ_SIGN_IDENTITY:--}"
ZIP_PATH="$DIST_DIR/Quartz-$VERSION-macOS-Apple-Silicon.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] \
  || [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9]+(\.[A-Za-z0-9-]+)+$ ]]; then
  print -u2 "✗ Version, numéro de build ou identifiant de bundle invalide."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 "✗ Cette première distribution de Quartz cible Apple Silicon."
  exit 1
fi

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/quartz-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/quartz-swiftpm-cache"

cd "$PROJECT_DIR"

if [[ "${QUARTZ_SKIP_VERIFY:-0}" != "1" ]]; then
  "$PROJECT_DIR/Verifier.command"
fi

swift build -c release --product QuartzPreview
swift build -c release --product quartz
BIN_DIR="$(swift build -c release --show-bin-path)"
RESOURCE_BUNDLE="$BIN_DIR/Quartz_QuartzApp.bundle"

for required_path in \
  "$BIN_DIR/QuartzPreview" \
  "$BIN_DIR/quartz" \
  "$RESOURCE_BUNDLE/model.safetensors" \
  "$RESOURCE_BUNDLE/lapis.jpg" \
  "$RESOURCE_BUNDLE/black-marble.png" \
  "$RESOURCE_BUNDLE/obelisk-relief-v1.png" \
  "$PROJECT_DIR/Distribution/Info.plist" \
  "$PROJECT_DIR/Distribution/Quartz.icns"; do
  if [[ ! -s "$required_path" ]]; then
    print -u2 "✗ Élément de distribution absent : $required_path"
    exit 1
  fi
done

if [[ "$APP_PATH" != "$PROJECT_DIR/dist/Quartz.app" ]]; then
  print -u2 "✗ Destination du bundle inattendue."
  exit 1
fi

rm -rf "$APP_PATH"
rm -f "$ZIP_PATH"
mkdir -p \
  "$APP_PATH/Contents/MacOS" \
  "$APP_PATH/Contents/Helpers" \
  "$APP_PATH/Contents/Resources"

install -m 755 "$BIN_DIR/QuartzPreview" "$APP_PATH/Contents/MacOS/Quartz"
install -m 755 "$BIN_DIR/quartz" "$APP_PATH/Contents/Helpers/quartz"
cp "$PROJECT_DIR/Distribution/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/Distribution/Quartz.icns" "$APP_PATH/Contents/Resources/Quartz.icns"
cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/Quartz_QuartzApp.bundle"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_PATH/Contents/Info.plist"
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

SIGN_ARGUMENTS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  SIGN_ARGUMENTS+=(--timestamp=none)
else
  SIGN_ARGUMENTS+=(--options runtime --timestamp)
fi

codesign "${SIGN_ARGUMENTS[@]}" "$APP_PATH/Contents/Helpers/quartz"
codesign "${SIGN_ARGUMENTS[@]}" "$APP_PATH/Contents/MacOS/Quartz"
codesign --deep "${SIGN_ARGUMENTS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")"
if [[ "$ACTUAL_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
  print -u2 "✗ L’identifiant du bundle n’a pas été conservé."
  exit 1
fi
if ! lipo -archs "$APP_PATH/Contents/MacOS/Quartz" | grep -q 'arm64'; then
  print -u2 "✗ L’exécutable Quartz n’est pas compilé pour Apple Silicon."
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

print "✓ Quartz.app assemblé et vérifié"
print "  Application : $APP_PATH"
print "  Archive     : $ZIP_PATH"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  print "  Signature   : locale ad hoc (non notarisée)"
else
  print "  Signature   : $SIGN_IDENTITY"
fi
