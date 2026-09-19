#!/usr/bin/env bash
#
# Packages the release bundle as a single-file AppImage.
#
# Complements the .deb: the AppImage needs no package manager and runs on
# distributions that are not Debian-derived.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_ID="io.github.rbuache.Paint"
BUNDLE="build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml)"
ARCH="$(uname -m)"

if [[ ! -x "$BUNDLE/paint" ]]; then
  echo "no release bundle at $BUNDLE — run 'flutter build linux --release'" >&2
  exit 1
fi

APPDIR="build/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/metainfo" "$APPDIR/usr/share/icons/hicolor"

cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
install -m 644 "packaging/deb/$APP_ID.desktop" \
  "$APPDIR/usr/share/applications/$APP_ID.desktop"
install -m 644 "packaging/deb/$APP_ID.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/$APP_ID.metainfo.xml"
cp -r packaging/icons/hicolor/. "$APPDIR/usr/share/icons/hicolor/"

# AppImage looks for these three at the AppDir root.
cp "packaging/deb/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp "packaging/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"
cp "packaging/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/paint" "$@"
APPRUN
chmod 755 "$APPDIR/AppRun"

TOOL="build/appimagetool"
if [[ ! -x "$TOOL" ]]; then
  echo "downloading appimagetool..."
  curl -fsSL -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "$TOOL"
fi

mkdir -p build/dist
OUTPUT="build/dist/Paint-${VERSION}-${ARCH}.AppImage"
# --appimage-extract-and-run avoids needing FUSE, which CI containers lack.
ARCH="$ARCH" "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"

echo "built $OUTPUT"
