# CLAUDE.md

Working notes for agents making changes here. Human-facing documentation lives
in [README.md](README.md) and [docs/](docs/); this file is the short version of
what you need before touching the code.

## What this is

A Flutter raster image editor for Linux desktop — a modern equivalent of classic
Windows Paint. Single window, single document, single layer, no network access
of any kind.

## Environment

The Flutter SDK is **not** preinstalled in a fresh container. Install it before
running anything:

```bash
curl -sSL -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz
tar xf /tmp/flutter.tar.xz -C /opt
git config --global --add safe.directory /opt/flutter   # required when running as root
export PATH="/opt/flutter/bin:$PATH"

apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

Pin **3.44.8** — it is what CI uses.

## Commands

```bash
flutter pub get
flutter gen-l10n                       # after any change to lib/l10n/app_en.arb
flutter analyze --fatal-infos
dart format --set-exit-if-changed .
bash tools/check_hardcoded_strings.sh
flutter test
flutter build linux --release          # → build/linux/x64/release/bundle/paint

bash packaging/build_deb.sh            # → build/dist/paint_<version>_amd64.deb
bash packaging/build_appimage.sh
tools/set_version.sh                   # print version; pass one to set it
```

Run all four checks before claiming a change is done. They are exactly what the
CI analyze job runs, so a green local run means that job is green.

The packaging job is a different matter: it builds in an `ubuntu:22.04`
container, and 24.04 tooling is more permissive than 22.04's. Green packaging
locally does **not** imply green packaging in CI.

## Running the app headlessly

There is no display in the container, but the app runs fine under Xvfb, and
`xdotool` can drive it. This is the only way to verify anything about how the
editor actually behaves:

```bash
apt-get install -y xvfb x11-utils xdotool imagemagick
nohup Xvfb :99 -screen 0 1400x900x24 -nolisten tcp > /tmp/xvfb.log 2>&1 &
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
cd build/linux/x64/release/bundle && nohup ./paint /path/to/image.png &
sleep 12                                    # first frame takes a while
import -display :99 -window root /tmp/shot.png
```

Then read `/tmp/shot.png` to see what happened. `xdotool key b`,
`xdotool mousemove X Y click 1` and mousedown/mousemove/mouseup sequences drive
the tools. The palette alignment bug and the shortcut-versus-text-input bug were
both found this way and neither was visible from the source.

Never use `pkill -f <pattern>` where the pattern also appears in the command
you are running — it matches your own shell and kills the session.

## Rules that matter

1. **Pixels change only through `DocumentController`** — `commitRegion` for
   anything with a dirty rectangle, `commitCanvas` for whole-image operations.
   Any other path to a layer's bitmap breaks undo.

2. **A tool's `draw(Canvas)` is used for the live preview *and* the commit.**
   Never add a second drawing path; that is how preview and result drift apart.

3. **`ToolGesture.bounds` must cover everything `draw` paints.** The commit clips
   to it. Inflate by the stroke width.

4. **Every user-visible string lives in `lib/l10n/app_en.arb`.** Run
   `flutter gen-l10n` and commit the generated files; CI fails when they are
   stale, and `tools/check_hardcoded_strings.sh` fails on a literal in a `Text`.

5. **`ops/` and `model/` must not import widgets.** That is what keeps them
   testable without a widget binding.

6. **Anything looping over pixels goes off the UI thread** — `Isolate.run` or
   `compute`.

7. **Pixel work is in straight (non-premultiplied) alpha.** Convert at the
   boundary with `ImageUtils.toStraightRgbaBytes` /
   `fromStraightRgbaBytes`.

8. **`ui.Image` is refcounted — dispose it.** Whoever replaces an image disposes
   the one it displaced. History keeps its own copies (`.clone()` for
   `CanvasEdit`), so document images can be disposed freely.

9. **The window is undecorated.** `main.dart` sets `TitleBarStyle.hidden` and
   `lib/ui/window_bar.dart` draws the title bar, so moving, maximising and
   resizing are the application's job — `WindowResizeEdges` provides the grips.
   Anything placed at the very edge of the window competes with them.

10. **Keyboard shortcuts and text input conflict.** Unmodified bindings are
   withdrawn while `CanvasController.textSession` is open, because handling a
   key here stops it reaching the text input plugin. If you add an unmodified
   shortcut, put it inside that guard in `lib/ui/app_shell.dart`.

11. **The widget kit is its own package now.** Everything is drawn with
   `slate_ui`, pinned to a tag in `pubspec.yaml`. Reach for a Material widget in
   `lib/ui/` only when the kit genuinely has no equivalent; when it plausibly
   should have one, add it in
   [alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit), release it, and
   bump the `ref` here. That is more ceremony than editing the widget in place
   was, and it is the point — the interface has a version number, and a change
   to it is something this application opts into.

## Layout

```
lib/core/       image_utils (all ui.Image creation), settings, theme
lib/model/      plain data: PaintDocument, Layer, Selection, ToolSettings
lib/controller/ DocumentController, SelectionController, ViewportController,
                CanvasController, History
lib/tools/      Tool + ToolGesture, one file per family
lib/ops/        pure pixel operations (flood fill, transforms)
lib/io/         codecs, file dialogs, clipboard
lib/ui/         widgets; AppActions is the single home for every command
packaging/      deb, AppImage, APT repo, icons
tools/          set_version.sh, check_hardcoded_strings.sh
```

Dependency direction is one-way: `ui` → `controller` → `model`/`ops`/`core`.
Nothing goes the other way. `ui` also depends on the `slate_ui` package, which
by construction depends on nothing here.

`AppActions` is where every user command is implemented once, so the menu, the
shortcuts and any future toolbar all behave identically. Add commands there, not
in the widgets.

## Gotchas discovered the hard way

- `dart format` reformats aggressively. Anchor-based patch scripts written
  against pre-format source will stop matching — read the file first.
- `Row` defaults to `CrossAxisAlignment.center`, which silently vertically
  centres a side panel that should fill the height.
- `flutter build linux` on Ubuntu 24.04 produces a binary needing glibc 2.39.
  Release builds must run in an `ubuntu:22.04` container; see
  [docs/PACKAGING.md](docs/PACKAGING.md).
- That container is a bare image running as root, which costs three things CI
  had to be taught: `subosito/flutter-action` shells out to `jq`, which is not
  installed; git refuses both the checkout and the Flutter SDK as
  "dubious ownership" until `safe.directory` is set; and
  `/etc/dpkg/dpkg.cfg.d/excludes` drops `/usr/share/man` and most of
  `/usr/share/doc` on install, so after `apt-get install` those files are listed
  by `dpkg -L` but are not on disk. Check documentation with
  `dpkg-deb --contents`, not on the filesystem. All handled in
  `.github/workflows/`; add anything similar there rather than in a build script.
- `desktop-file-validate` on 24.04 (0.27) accepts spec `Version=1.5`; the 22.04
  one CI uses (0.26) rejects it. The desktop entry declares 1.1 for that reason.
  Validating packaging locally proves less than it looks — the container is the
  arbiter.
- `package:image` cannot encode WebP or PSD — decode only. `ImageCodecs` already
  models this with `canEncode`.
- `super_clipboard` needs a Rust toolchain; `pasteboard` is used instead.
- `Matrix4` is not available from `dart:ui` alone; build the column-major
  `Float64List` by hand, as `TransformOps.stretchAndSkew` does.

## Before finishing

- All four checks pass.
- New behaviour in `ops/`, `controller/`, `model/` or `io/` has tests.
- User-visible changes have a `CHANGELOG.md` entry under `## [Unreleased]`.
- Do not bump the version in a normal change — releases do that
  ([docs/RELEASING.md](docs/RELEASING.md)).
- Comments explain *why*, never *what*.
