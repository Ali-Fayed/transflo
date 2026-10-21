#!/usr/bin/env bash
# Generates Transflo.xcodeproj from project.yml. Run after cloning and after editing project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in xcodegen swiftlint; do
  command -v "$tool" >/dev/null || { echo "error: $tool is not installed (brew install $tool)" >&2; exit 1; }
done

xcodegen generate --spec project.yml
echo "Generated Transflo.xcodeproj"
