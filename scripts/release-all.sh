#!/usr/bin/env bash
# Ships every channel from this Mac, in parallel: the DMG for GitHub and Homebrew, and the App Store
# archive. When the DMG is ready it publishes the GitHub release and the Homebrew cask.
#
#   TRANSFLO_TEAM_ID=<TEAMID> scripts/release-all.sh            # everything
#   TRANSFLO_TEAM_ID=... scripts/release-all.sh --skip-app-store  # GitHub + Homebrew only
#   scripts/release-all.sh --skip-github                          # App Store only
#
# Same steps as .github/workflows/release.yml. Logs go to build/releases/logs/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TRANSFLO_RELEASE_OUTPUT_DIR:-$ROOT/build/releases}"
LOGS="$OUT/logs"
GITHUB=1
APP_STORE=1
for argument in "$@"; do
  case "$argument" in
    --skip-github) GITHUB=0 ;;
    --skip-app-store) APP_STORE=0 ;;
    *) echo "usage: $0 [--skip-github] [--skip-app-store]" >&2; exit 64 ;;
  esac
done

fail() { echo "error: $*" >&2; exit 1; }
VERSION="$(awk -F' = ' '$1 == "MARKETING_VERSION" { print $2 }' "$ROOT/Configs/Base.xcconfig")"
TAG="v$VERSION"
[[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]] || fail "commit or set aside local changes first"
[[ "$APP_STORE" == 0 || -n "${TRANSFLO_TEAM_ID:-}" ]] || fail "set TRANSFLO_TEAM_ID for the App Store build"
mkdir -p "$LOGS"
# Generate the project once, so the parallel builds don't race to write it.
"$ROOT/scripts/bootstrap.sh" > "$LOGS/bootstrap.log" 2>&1

PIDS=()
if [[ "$GITHUB" == 1 ]]; then
  "$ROOT/scripts/release.sh" > "$LOGS/dmg.log" 2>&1 & PIDS+=("dmg:$!")
fi
if [[ "$APP_STORE" == 1 ]]; then
  TRANSFLO_UPLOAD=1 "$ROOT/scripts/release-appstore.sh" > "$LOGS/app-store.log" 2>&1 & PIDS+=("app-store:$!")
fi
echo "Building ${PIDS[*]%%:*} in parallel for Transflo $VERSION (logs in $LOGS)…"

STATUS=0
for entry in "${PIDS[@]}"; do
  name="${entry%%:*}"
  if wait "${entry##*:}"; then
    echo "✔ $name"
    if [[ "$name" == dmg ]]; then
      git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
        || git -C "$ROOT" tag -a "$TAG" -m "Transflo $VERSION"
      git -C "$ROOT" push -q origin "refs/tags/$TAG"
      if gh release view "$TAG" >/dev/null 2>&1; then
        gh release upload "$TAG" "$OUT/Transflo-$VERSION-arm64.dmg" --clobber
      else
        gh release create "$TAG" "$OUT/Transflo-$VERSION-arm64.dmg" --verify-tag --latest \
          --title "Transflo $VERSION" --notes-file "$OUT/release-notes-$VERSION.md"
      fi
      TAP="$(mktemp -d "${TMPDIR:-/tmp}/transflo-tap.XXXXXX")"
      gh repo clone Ali-Fayed/homebrew-transflo "$TAP" -- -q
      mkdir -p "$TAP/Casks" && cp "$OUT/transflo.rb" "$TAP/Casks/transflo.rb"
      git -C "$TAP" add Casks/transflo.rb
      git -C "$TAP" diff --cached --quiet || { git -C "$TAP" commit -qm "transflo $VERSION" && git -C "$TAP" push -q; }
      rm -rf "$TAP"
      echo "✔ GitHub release $TAG and Homebrew cask published"
    fi
  else
    echo "✘ $name failed; see $LOGS/$name.log" >&2
    STATUS=1
  fi
done
exit "$STATUS"
