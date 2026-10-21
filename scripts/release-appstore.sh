#!/usr/bin/env bash
# Builds the sandboxed Mac App Store edition and exports it for App Store Connect.
#
#   TRANSFLO_TEAM_ID=ABCDE12345 scripts/release-appstore.sh            # automatic signing (Xcode account)
#   TRANSFLO_TEAM_ID=... TRANSFLO_APPSTORE_PROFILE="<profile name>" ...   # manual: your own profile
#   TRANSFLO_UPLOAD=1 ... scripts/release-appstore.sh                    # upload instead of writing a .pkg
#
# Automatic signing needs Xcode signed in to the team (Settings › Accounts): Xcode registers the App ID,
# creates the distribution certificate and profile, and re-signs everything, the ffmpeg helpers
# included, when it exports. Manual signing needs the "Apple Distribution" and "3rd Party Mac
# Developer Installer" certificates and a Mac App Store profile (see docs/APP_STORE.md).
# On CI (no Xcode account), sign in with an App Store Connect API key (Admin role, for cloud signing):
#   TRANSFLO_ASC_KEY_PATH=AuthKey_ABC.p8 TRANSFLO_ASC_KEY_ID=ABC TRANSFLO_ASC_ISSUER_ID=<uuid>
# Existing outputs are never overwritten.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TRANSFLO_RELEASE_OUTPUT_DIR:-$ROOT/build/releases}/appstore"
TEAM="${TRANSFLO_TEAM_ID:-}"
PROFILE="${TRANSFLO_APPSTORE_PROFILE:-}"
DESTINATION=$([[ "${TRANSFLO_UPLOAD:-0}" == 1 ]] && echo upload || echo export)
AUTH=()
if [[ -n "${TRANSFLO_ASC_KEY_PATH:-}" ]]; then
  AUTH=(-authenticationKeyPath "$TRANSFLO_ASC_KEY_PATH" -authenticationKeyID "${TRANSFLO_ASC_KEY_ID:?}"
        -authenticationKeyIssuerID "${TRANSFLO_ASC_ISSUER_ID:?}")
fi

fail() { echo "error: $*" >&2; exit 1; }
[[ -n "$TEAM" ]] || fail "set TRANSFLO_TEAM_ID to your Apple Developer team ID"
for binary in ffmpeg ffprobe; do
  [[ -x "$ROOT/Vendor/ffmpeg/bin/$binary" ]] || fail "run scripts/build-ffmpeg.sh first ($binary missing)"
done
VERSION="$(awk -F' = ' '$1 == "MARKETING_VERSION" { print $2 }' "$ROOT/Configs/Base.xcconfig")"
VERSION="${TRANSFLO_APPSTORE_VERSION:-$VERSION}"
BUILD="${TRANSFLO_APPSTORE_BUILD:-$(awk -F' = ' '$1 == "CURRENT_PROJECT_VERSION" { print $2 }' "$ROOT/Configs/Base.xcconfig")}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[1-9][0-9]*$ ]] || fail "invalid App Store version/build"
ARCHIVE="$OUT/Transflo-$VERSION.xcarchive"
[[ ! -e "$ARCHIVE" ]] || fail "$ARCHIVE already exists; move it aside first"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/transflo-appstore.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
[[ -d "$ROOT/Transflo.xcodeproj" ]] || "$ROOT/scripts/bootstrap.sh"

echo "Archiving Transflo $VERSION (App Store edition)…"
if [[ -n "$PROFILE" ]]; then
  SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER="$PROFILE")
else
  SIGNING=(CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" -allowProvisioningUpdates)
fi
xcodebuild archive -quiet -project "$ROOT/Transflo.xcodeproj" -scheme "TransfloForMac App Store" -configuration AppStore \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -derivedDataPath "$WORK/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  "${SIGNING[@]}" ${AUTH[@]+"${AUTH[@]}"}

APP="$ARCHIVE/Products/Applications/Transflo.app"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q com.apple.security.app-sandbox \
  || fail "the archived app is not sandboxed"
# Resource bundles must carry no signature of their own (ITMS-90284); the helpers must be signed.
for bundle in "$APP"/Contents/Resources/*.bundle; do
  [[ ! -d "$bundle/Contents/_CodeSignature" ]] || fail "$(basename "$bundle") is still signed on its own"
done
for helper in ffmpeg ffprobe; do
  codesign -d --entitlements - "$APP/Contents/Helpers/$helper" 2>/dev/null | grep -q com.apple.security.inherit \
    || fail "$helper is not signed to inherit the sandbox"
done

OPTIONS="$WORK/ExportOptions.plist"
sed -e "s|@DESTINATION@|$DESTINATION|" -e "s|@TEAM_ID@|$TEAM|" -e "s|@PROFILE@|$PROFILE|" \
  "$ROOT/scripts/release/ExportOptions-AppStore.plist.in" > "$OPTIONS"
if [[ -z "$PROFILE" ]]; then
  # Let Xcode pick the cloud-managed distribution certificate and profile.
  plutil -replace signingStyle -string automatic "$OPTIONS"
  for key in signingCertificate installerSigningCertificate provisioningProfiles; do plutil -remove "$key" "$OPTIONS"; done
fi
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
  -exportPath "$OUT/export-$VERSION" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

echo
if [[ "$DESTINATION" == upload ]]; then
  echo "Uploaded Transflo $VERSION to App Store Connect. Pick the build in the app's version page."
else
  echo "App Store package ready: $OUT/export-$VERSION (upload it with Transporter, or rerun with TRANSFLO_UPLOAD=1)"
fi
