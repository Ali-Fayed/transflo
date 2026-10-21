# Third-party notices

Transflo's own code is MIT-licensed (see [LICENSE](LICENSE)). The app bundles one third-party program, **FFmpeg**, as two separate executables (`Transflo.app/Contents/Helpers/ffmpeg` and `ffprobe`). Transflo runs them as child processes and does not link them into its own code.

## FFmpeg 8.0: LGPL 2.1 or later
- **Source:** <https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz>
- **License:** GNU Lesser General Public License, version 2.1 or later (<https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>).
- **Build:** made by [`scripts/build-ffmpeg.sh`](scripts/build-ffmpeg.sh) from pinned sources with recorded SHA-256 checksums ([`Vendor/ffmpeg/checksums.txt`](Vendor/ffmpeg/checksums.txt)).
  - The configuration is LGPL-only: `--disable-gpl --disable-nonfree --disable-autodetect`.
  - The build script refuses to bundle a binary whose `-buildconf` contains GPL or non-free components.
- **Configure options:** `--enable-videotoolbox --enable-audiotoolbox --enable-zlib --enable-bzlib --enable-iconv --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx --enable-libwebp --enable-libdav1d --enable-libsvtav1 --disable-network --disable-doc --disable-ffplay --disable-debug`, plus the static-build flags.
- **Replacing it:** you may swap in your own build. Rebuild with the script (or your own configuration) and replace the two files in `Contents/Helpers`.
- **Written offer:** for three years after each release, the maintainer will provide the complete corresponding source of the bundled FFmpeg and libraries on request, through the project's GitHub issues, at no charge beyond the cost of distribution. The sources are also linked above and below.

### Libraries built into the FFmpeg executables
| Library | Version | License | Source |
|---|---|---|---|
| LAME | 3.100 | LGPL 2.0 or later | <https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz> |
| libogg | 1.3.5 | BSD-3-Clause | <https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz> |
| libvorbis | 1.3.7 | BSD-3-Clause | <https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz> |
| Opus | 1.5.2 | BSD-3-Clause | <https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz> |
| libvpx | 1.15.0 | BSD-3-Clause + patent grant | <https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz> |
| libwebp | 1.5.0 | BSD-3-Clause + patent grant | <https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz> |
| dav1d | 1.5.1 | BSD-2-Clause | <https://code.videolan.org/videolan/dav1d/-/archive/1.5.1/dav1d-1.5.1.tar.gz> |
| SVT-AV1 | 3.0.2 | BSD-3-Clause-Clear + Alliance for Open Media Patent License 1.0 | <https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.0.2/SVT-AV1-v3.0.2.tar.gz> |

The full license texts ship inside each source archive.

## Build-time only (not shipped in the app)
| Tool | License | Used for |
|---|---|---|
| [ds-store](https://pypi.org/project/ds-store/) 1.3.3 | MIT | Laying out the DMG window (`scripts/dmg/`) |
| [mac-alias](https://pypi.org/project/mac-alias/) 2.2.3 | MIT | Laying out the DMG window (`scripts/dmg/`) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | MIT | Generating the Xcode project |
| [SwiftLint](https://github.com/realm/SwiftLint) | MIT | Linting |

## Trademarks
Transflo is an independent project. It is not affiliated with Apple or with the makers of any other file-conversion app. AirDrop, Finder, Pages, Keynote, Numbers and macOS are trademarks of Apple Inc.
