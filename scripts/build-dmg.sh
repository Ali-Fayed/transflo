#!/usr/bin/env bash
# Builds a Release app (or packages --app) into a drag-to-Applications installer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=""
OUTPUT_DIR="$ROOT/build/releases"
WORKSPACE=""
MOUNT_POINT=""

usage() {
  cat <<'HELP'
Usage: scripts/build-dmg.sh [--app /path/to/Transflo.app] [--output-dir /path/to/folder]

Without --app, builds Transflo in Release using temporary build storage.
The installer window shows Transflo's dark illustrated design (Finder keeps it the same in light and dark mode).
The finished DMG is saved in build/releases by default. Existing installers are never overwritten.
HELP
}

fail() { echo "error: $*" >&2; exit 1; }
cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then hdiutil detach "$MOUNT_POINT" -quiet || true; fi
  if [[ -n "$WORKSPACE" && -d "$WORKSPACE" ]]; then rm -rf "$WORKSPACE"; fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app|--output-dir)
      [[ $# -ge 2 && -n "$2" ]] || fail "$1 needs a path"
      if [[ "$1" == --app ]]; then APP="$2"; else OUTPUT_DIR="$2"; fi
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $1" ;;
  esac
done

for tool in hdiutil ditto codesign lipo swift python3; do
  command -v "$tool" >/dev/null || fail "$tool is required"
done
WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/transflo-dmg.XXXXXX")"

if [[ -z "$APP" ]]; then
  for binary in ffmpeg ffprobe; do
    [[ -x "$ROOT/Vendor/ffmpeg/bin/$binary" ]] || fail "Run scripts/build-ffmpeg.sh first ($binary missing)"
  done
  if [[ ! -d "$ROOT/Transflo.xcodeproj" ]]; then "$ROOT/scripts/bootstrap.sh"; fi
  echo "Building Transflo Release…"
  xcodebuild build -quiet -project "$ROOT/Transflo.xcodeproj" -scheme TransfloForMac -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$WORKSPACE/DerivedData" \
    CLANG_MODULE_CACHE_PATH="$WORKSPACE/ModuleCache"
  APP="$WORKSPACE/DerivedData/Build/Products/Release/Transflo.app"
fi

[[ -d "$APP" ]] || fail "App bundle not found: $APP"
APP="$(cd "$APP" && pwd)"
PLIST="$APP/Contents/Info.plist"
[[ -f "$PLIST" ]] || fail "App Info.plist is missing"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")"
[[ "$BUNDLE_ID" == com.transflo.app ]] || fail "Expected a Transflo app bundle"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
[[ -n "$VERSION" && "$VERSION" != *[!a-zA-Z0-9._-]* ]] || fail "Invalid app version"
[[ ! -d "$APP/Contents/PlugIns" ]] || fail "Use a Release app without embedded test bundles"
for binary in ffmpeg ffprobe; do
  [[ -x "$APP/Contents/Helpers/$binary" ]] || fail "App is missing bundled $binary"
done
codesign --verify --deep --strict "$APP"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/Transflo")"
case "$ARCHS" in
  arm64) ARCH=arm64 ;;
  x86_64) ARCH=x86_64 ;;
  *) ARCH=universal ;;
esac

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
DESTINATION="$OUTPUT_DIR/Transflo-$VERSION-$ARCH.dmg"
[[ ! -e "$DESTINATION" && ! -L "$DESTINATION" ]] || fail "Installer already exists: $DESTINATION"
# Install layout-writing dependencies only in disposable build storage, or reuse a prepared Python.
DESIGN_PYTHON="${TRANSFLO_DMG_PYTHON:-}"
if [[ -z "$DESIGN_PYTHON" ]]; then
  python3 -m venv "$WORKSPACE/python"
  DESIGN_PYTHON="$WORKSPACE/python/bin/python"
  "$DESIGN_PYTHON" -m pip install --quiet -r "$ROOT/scripts/dmg/requirements.txt"
fi
"$DESIGN_PYTHON" -c 'import ds_store, mac_alias'
STAGING="$WORKSPACE/Installer"
mkdir -p "$STAGING/.Licenses" "$STAGING/.background"
ditto "$APP" "$STAGING/Transflo.app"
ln -s /Applications "$STAGING/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGING/.VolumeIcon.icns"
cp "$ROOT/LICENSE" "$STAGING/.Licenses/Transflo-MIT.txt"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGING/.Licenses/Third-Party-Notices.md"
# The build log records absolute paths; publish it without the local checkout location.
sed "s|$ROOT|<repo>|g" "$ROOT/Vendor/ffmpeg/BUILDINFO.txt" > "$STAGING/.Licenses/FFmpeg-BuildInfo.txt"
cp "$ROOT/Vendor/ffmpeg/checksums.txt" "$STAGING/.Licenses/FFmpeg-Checksums.txt"
VOLUME_NAME="Install Transflo"
swift -module-cache-path "$WORKSPACE/SwiftModuleCache" "$ROOT/scripts/dmg/render-background.swift" \
  "$STAGING/.background/installer.png"

# Configure Finder on a writable image so background aliases reference the final volume, not staging.
WRITABLE="$WORKSPACE/Transflo-writable.dmg"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDRW "$WRITABLE"
MOUNT_POINT="$WORKSPACE/volume"
mkdir "$MOUNT_POINT"
hdiutil attach "$WRITABLE" -nobrowse -mountpoint "$MOUNT_POINT" -quiet
"$DESIGN_PYTHON" "$ROOT/scripts/dmg/configure-finder.py" "$MOUNT_POINT"
# Give the mounted volume Transflo's icon. Finder layout metadata selects icon view.
/usr/bin/xattr -wx com.apple.FinderInfo '0000000000000000040000000000000000000000000000000000000000000000' "$MOUNT_POINT"
hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""

# Create beside the destination so publication can use an atomic, no-overwrite hard link.
IMAGE_WORKSPACE="$(mktemp -d "$OUTPUT_DIR/.transflo-dmg.XXXXXX")"
cleanup_all() { cleanup; rm -rf "$IMAGE_WORKSPACE"; }
trap cleanup_all EXIT
IMAGE="$IMAGE_WORKSPACE/Transflo.dmg"
hdiutil convert "$WRITABLE" -format UDZO -imagekey zlib-level=9 -o "$IMAGE"
hdiutil verify "$IMAGE"
ln "$IMAGE" "$DESTINATION"
echo "Installer: $DESTINATION"
du -h "$DESTINATION"
