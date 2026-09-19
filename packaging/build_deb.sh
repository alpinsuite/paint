#!/usr/bin/env bash
#
# Builds paint_<version>_<arch>.deb from an already-built Flutter bundle.
#
# Run `flutter build linux --release` first, or pass --build to have this script
# do it. The result lands in build/dist/.
#
# Runtime dependencies are computed with dpkg-shlibdeps rather than written by
# hand, so they stay correct as the Flutter engine's own dependencies change.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PACKAGE="paint"
APP_ID="io.github.rbuache.Paint"
MAINTAINER="${DEB_MAINTAINER:-rbuache <rbuache@gmail.com>}"

BUILD_FIRST=0
for arg in "$@"; do
  case "$arg" in
    --build) BUILD_FIRST=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Version comes from pubspec.yaml, minus the +build suffix Debian has no use for.
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml)"
if [[ -z "$VERSION" ]]; then
  echo "could not read version from pubspec.yaml" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
BUNDLE="build/linux/x64/release/bundle"

if [[ "$BUILD_FIRST" == "1" ]]; then
  flutter build linux --release
fi

if [[ ! -x "$BUNDLE/$PACKAGE" ]]; then
  echo "no release bundle at $BUNDLE — run 'flutter build linux --release'" >&2
  exit 1
fi

STAGE="build/deb/${PACKAGE}_${VERSION}_${ARCH}"
rm -rf "$STAGE"
mkdir -p \
  "$STAGE/DEBIAN" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/lib/$PACKAGE" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/metainfo" \
  "$STAGE/usr/share/doc/$PACKAGE" \
  "$STAGE/usr/share/man/man1"

# The bundle keeps its own layout under /usr/lib/paint; only a launcher goes on
# PATH, which is the convention for self-contained desktop applications.
cp -r "$BUNDLE/." "$STAGE/usr/lib/$PACKAGE/"
chmod 755 "$STAGE/usr/lib/$PACKAGE/$PACKAGE"

cat > "$STAGE/usr/bin/$PACKAGE" <<'LAUNCHER'
#!/bin/sh
# The engine looks for its data and libraries relative to the executable, so it
# has to be invoked from its own directory rather than through a symlink.
exec /usr/lib/paint/paint "$@"
LAUNCHER
chmod 755 "$STAGE/usr/bin/$PACKAGE"

install -m 644 "packaging/deb/$APP_ID.desktop" \
  "$STAGE/usr/share/applications/$APP_ID.desktop"
install -m 644 "packaging/deb/$APP_ID.metainfo.xml" \
  "$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"

for dir in packaging/icons/hicolor/*/; do
  size="$(basename "$dir")"
  target="$STAGE/usr/share/icons/hicolor/$size/apps"
  mkdir -p "$target"
  cp "$dir/apps/"* "$target/"
done

install -m 644 LICENSE "$STAGE/usr/share/doc/$PACKAGE/copyright"
gzip -9nc packaging/deb/paint.1 > "$STAGE/usr/share/man/man1/$PACKAGE.1.gz"
gzip -9nc CHANGELOG.md > "$STAGE/usr/share/doc/$PACKAGE/changelog.gz"

INSTALLED_SIZE="$(du -ks "$STAGE" | cut -f1)"

# dpkg-shlibdeps reads the ELF binaries and reports exactly what they link
# against. It must run from the staging root and needs a control file to exist.
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $PACKAGE
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Homepage: https://github.com/rbuache/paint
Description: simple, easy-to-use image editor
 Paint is a straightforward raster image editor for the Linux desktop, in the
 spirit of the classic Windows accessory: open a picture, draw on it, save it,
 and get on with your day.
 .
 It offers pencil, brush, eraser, fill, shape and text tools, rectangular and
 free-form selection, the usual flip/rotate/resize/skew operations, deep undo,
 drag-and-drop, clipboard support and a restrained light or dark theme.
CONTROL

DEPENDS=""
if command -v dpkg-shlibdeps > /dev/null 2>&1; then
  mkdir -p "$STAGE/debian"
  touch "$STAGE/debian/control"
  (
    cd "$STAGE"
    # The bundled engine libraries are shipped in the package itself, so point
    # the resolver at them instead of letting it fail on an unpackaged path.
    LD_LIBRARY_PATH="usr/lib/$PACKAGE/lib:${LD_LIBRARY_PATH:-}" \
      dpkg-shlibdeps -O --ignore-missing-info \
        "usr/lib/$PACKAGE/$PACKAGE" "usr/lib/$PACKAGE/lib/"*.so 2> shlibdeps.log \
        > shlibdeps.out || true
  )
  DEPENDS="$(sed -n 's/^shlibs:Depends=//p' "$STAGE/shlibdeps.out" 2>/dev/null || true)"
  rm -rf "$STAGE/debian" "$STAGE/shlibdeps.out" "$STAGE/shlibdeps.log"
fi

# Fall back to the known-good minimum when shlibdeps is unavailable (for
# instance on a non-Debian build host).
if [[ -z "$DEPENDS" ]]; then
  DEPENDS="libc6, libgtk-3-0, libglib2.0-0, libstdc++6, zlib1g"
  echo "warning: dpkg-shlibdeps produced nothing; using the fallback list" >&2
fi
echo "Depends: $DEPENDS" >> "$STAGE/DEBIAN/control"

# Refresh the icon and desktop caches so the launcher entry appears without a
# logout, and clean up on removal.
cat > "$STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
  fi
fi
POSTINST

cat > "$STAGE/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
  fi
fi
POSTRM

chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

mkdir -p build/dist
OUTPUT="build/dist/${PACKAGE}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUTPUT"

echo "built $OUTPUT"
dpkg-deb --info "$OUTPUT" | sed 's/^/  /'
