#!/usr/bin/env bash
# Builds an LGPL-only, statically linked arm64 ffmpeg + ffprobe for Transflo.
#
#   scripts/build-ffmpeg.sh                     # verify sources against Vendor/ffmpeg/checksums.txt, then build
#   scripts/build-ffmpeg.sh --record-checksums  # first run only: download, record SHA-256s, then build
#   scripts/build-ffmpeg.sh --rebuild-deps      # rebuild codec libraries even if already built
#
# Output: Vendor/ffmpeg/bin/{ffmpeg,ffprobe} plus Vendor/ffmpeg/BUILDINFO.txt (configure line + versions)
# for LGPL compliance. No GPL or non-free component is ever enabled: --disable-gpl --disable-nonfree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/Vendor/ffmpeg"
SRC="$VENDOR/src"
BUILD="$VENDOR/build"
PREFIX="$BUILD/prefix"
CHECKSUMS="$VENDOR/checksums.txt"
JOBS="$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.ncpu)"
export MACOSX_DEPLOYMENT_TARGET=14.0
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export CFLAGS="-arch arm64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -O2"
export LDFLAGS="-arch arm64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"

# name|version|url — the single source of truth for pinned versions.
SOURCES=(
  "ffmpeg|8.0|https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz"
  "lame|3.100|https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
  "libogg|1.3.5|https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz"
  "libvorbis|1.3.7|https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
  "opus|1.5.2|https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz"
  "libvpx|1.15.0|https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz"
  "libwebp|1.5.0|https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz"
  "dav1d|1.5.1|https://code.videolan.org/videolan/dav1d/-/archive/1.5.1/dav1d-1.5.1.tar.gz"
  "svtav1|3.0.2|https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.0.2/SVT-AV1-v3.0.2.tar.gz"
)

fail() { echo "error: $*" >&2; exit 1; }

RECORD=false
REBUILD_DEPS=false
for arg in "$@"; do
  case "$arg" in
    --record-checksums) RECORD=true ;;
    --rebuild-deps) REBUILD_DEPS=true ;;
    *) fail "unknown option $arg" ;;
  esac
done

require_tools() {
  local tool
  for tool in curl shasum make pkg-config meson ninja cmake nasm autoreconf; do
    command -v "$tool" >/dev/null || fail "$tool is required (brew install pkg-config meson ninja cmake nasm autoconf automake libtool)"
  done
}

expected_checksum() {
  [[ -f "$CHECKSUMS" ]] || return 0
  awk -v file="$1" '$2 == file { print $1 }' "$CHECKSUMS"
}

# Downloads one archive (if missing), verifies or records its SHA-256 and unpacks it into $SRC/<name>.
fetch() {
  local name="$1" version="$2" url="$3"
  local archive="$SRC/${name}-${version}.tar.${url##*.tar.}"
  [[ -f "$archive" ]] || curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$url"

  local actual expected
  actual="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
  expected="$(expected_checksum "$(basename "$archive")")"
  if [[ -n "$expected" ]]; then
    [[ "$actual" == "$expected" ]] || fail "checksum mismatch for $(basename "$archive")"
  elif $RECORD; then
    echo "$actual  $(basename "$archive")" >> "$CHECKSUMS"
  else
    fail "no recorded checksum for $(basename "$archive"); review the source and rerun with --record-checksums"
  fi

  rm -rf "${SRC:?}/$name"
  mkdir -p "$SRC/$name"
  tar -xf "$archive" -C "$SRC/$name" --strip-components 1
}

autotools_build() {
  local name="$1"; shift
  (cd "$SRC/$name" && ./configure --prefix="$PREFIX" --enable-static --disable-shared "$@" && make -j"$JOBS" && make install)
}

# Static libraries produced by build_libraries; when all exist they are reused unless --rebuild-deps.
DEPENDENCY_LIBS=(libmp3lame.a libogg.a libvorbis.a libvorbisenc.a libopus.a libvpx.a libwebp.a libdav1d.a libSvtAv1Enc.a)

dependencies_built() {
  local lib
  for lib in "${DEPENDENCY_LIBS[@]}"; do
    [[ -f "$PREFIX/lib/$lib" ]] || return 1
  done
}

build_libraries() {
  autotools_build lame --disable-frontend --disable-decoder
  autotools_build libogg
  # libvorbis 1.3.7's configure passes -force_cpusubtype_ALL on Darwin, which current ld rejects.
  sed -i '' 's/-force_cpusubtype_ALL//g' "$SRC/libvorbis/configure"
  autotools_build libvorbis --with-ogg="$PREFIX"
  autotools_build opus --disable-doc --disable-extra-programs
  (cd "$SRC/libvpx" && ./configure --prefix="$PREFIX" --target=arm64-darwin23-gcc --enable-static --disable-shared \
     --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth \
     && make -j"$JOBS" && make install)
  autotools_build libwebp --disable-gl --disable-sdl --disable-png --disable-jpeg --disable-tiff --disable-gif
  (cd "$SRC/dav1d" && meson setup build --prefix="$PREFIX" --libdir=lib --buildtype=release \
     --default-library=static -Denable_tools=false -Denable_tests=false && ninja -C build install)
  (cd "$SRC/svtav1" && cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
     -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF -DBUILD_TESTING=OFF \
     -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
     && ninja -C build install)
}

FFMPEG_FLAGS=(
  --prefix="$PREFIX"
  --arch=arm64 --target-os=darwin --enable-cross-compile
  --pkg-config-flags=--static
  --extra-cflags="-I$PREFIX/include $CFLAGS"
  --extra-ldflags="-L$PREFIX/lib $LDFLAGS"
  --extra-libs=-liconv
  --disable-gpl --disable-nonfree --disable-autodetect
  --disable-shared --enable-static
  --disable-doc --disable-ffplay --disable-network --disable-debug
  --enable-videotoolbox --enable-audiotoolbox
  --enable-zlib --enable-bzlib --enable-iconv
  --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx
  --enable-libwebp --enable-libdav1d --enable-libsvtav1
)

build_ffmpeg() {
  (cd "$SRC/ffmpeg" && ./configure "${FFMPEG_FLAGS[@]}" && make -j"$JOBS" && make install)
  mkdir -p "$VENDOR/bin"
  cp "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe" "$VENDOR/bin/"
}

write_buildinfo() {
  {
    echo "Built $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(sw_vers -productVersion) / $(uname -m)"
    echo
    echo "Sources:"
    printf '  %s\n' "${SOURCES[@]}"
    echo
    echo "ffmpeg configure:"
    printf '  %s\n' "${FFMPEG_FLAGS[@]}"
    echo
    "$VENDOR/bin/ffmpeg" -hide_banner -version | head -1
  } | sed "s|$ROOT|<repo>|g" > "$VENDOR/BUILDINFO.txt"
}

verify_license() {
  local configuration
  configuration="$("$VENDOR/bin/ffmpeg" -hide_banner -buildconf)"
  grep -q -- "--enable-gpl" <<<"$configuration" && fail "GPL was enabled; refusing to ship this binary"
  grep -q -- "--enable-nonfree" <<<"$configuration" && fail "non-free was enabled; refusing to ship this binary"
  echo "License check passed: LGPL build."
}

main() {
  require_tools
  mkdir -p "$SRC" "$PREFIX"
  local entry name version url
  for entry in "${SOURCES[@]}"; do
    IFS='|' read -r name version url <<<"$entry"
    fetch "$name" "$version" "$url"
  done
  if $REBUILD_DEPS || ! dependencies_built; then
    build_libraries
  else
    echo "Reusing codec libraries in $PREFIX (pass --rebuild-deps to rebuild)."
  fi
  build_ffmpeg
  verify_license
  write_buildinfo
  echo "Done: $VENDOR/bin/ffmpeg"
}

main "$@"
