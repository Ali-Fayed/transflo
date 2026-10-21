#!/usr/bin/env bash
# Local synthetic test files, independent of user data. Requires the repo's existing LGPL ffmpeg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$ROOT/TransfloMobileTests/Fixtures"
FFMPEG="$ROOT/Vendor/ffmpeg/bin/ffmpeg"
xcrun swift "$ROOT/scripts/testing/make-mobile-fixtures.swift" "$FIXTURES"
"$FFMPEG" -v error -y -i "$FIXTURES/source.png" -frames:v 1 "$FIXTURES/source.webp"
"$FFMPEG" -v error -y -i "$FIXTURES/qr.png" -frames:v 1 "$FIXTURES/qr.webp"
for extension in wav aiff m4a mp3 flac; do
  "$FFMPEG" -v error -y -f lavfi -i 'sine=frequency=440:duration=3:sample_rate=44100' "$FIXTURES/source.$extension"
done
"$FFMPEG" -v error -y -f lavfi -i 'testsrc2=size=256x256:rate=10:duration=3' \
  -f lavfi -i 'sine=frequency=440:duration=3' -c:v h264_videotoolbox -b:v 300k -c:a aac \
  -shortest "$FIXTURES/source.mp4"
"$FFMPEG" -v error -y -i "$FIXTURES/source.mp4" -c copy "$FIXTURES/source.mov"
printf 'TRANSFLO 2026\nA deterministic text fixture.\n' > "$FIXTURES/source.txt"
printf '# TRANSFLO 2026\n\nA **deterministic** document.\n' > "$FIXTURES/source.md"
printf '{\\rtf1\\ansi TRANSFLO 2026\\par A deterministic document.}' > "$FIXTURES/source.rtf"
printf '1\n00:00:00,000 --> 00:00:02,000\nTRANSFLO 2026\n' > "$FIXTURES/source.srt"
printf 'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nTRANSFLO 2026\n' > "$FIXTURES/source.vtt"

"$FFMPEG" -v error -y -i "$FIXTURES/source.wav" -c:a libvorbis "$FIXTURES/source.ogg"
"$FFMPEG" -v error -y -i "$FIXTURES/source.wav" -c:a libopus "$FIXTURES/source.opus"
"$FFMPEG" -v error -y -i "$FIXTURES/source.wav" -c:a wmav2 "$FIXTURES/source.wma"
"$FFMPEG" -v error -y -i "$FIXTURES/source.mp4" -c copy "$FIXTURES/source.mkv"
"$FFMPEG" -v error -y -i "$FIXTURES/source.mp4" -c:v libvpx-vp9 -c:a libopus "$FIXTURES/source.webm"
"$FFMPEG" -v error -y -i "$FIXTURES/source.mp4" -c:v mpeg4 -c:a libmp3lame "$FIXTURES/source.avi"
"$FFMPEG" -v error -y -i "$FIXTURES/source.mp4" -c:v wmv2 -c:a wmav2 "$FIXTURES/source.wmv"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#00a898"/><text x="12" y="128">TRANSFLO 2026</text></svg>' > "$FIXTURES/source.svg"
