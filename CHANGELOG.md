# Changelog

All notable changes to this project are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Relicensed to GPL-3.0-or-later.** Anyone may still use, study, modify and
  redistribute Paint. What changes is that a redistributed copy, modified or
  not, has to carry its source and the same freedoms with it, so nobody can
  build a closed product on this one. Running it, and changing it for your own
  use, carry no obligation at all. Releases up to and including 0.2.0 were
  published under the MIT License and stay available under it; this applies
  from the next release onward.

- The widget kit the interface is drawn with now comes from the `slate_ui`
  package ([alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit)) instead of
  a copy in `lib/slate/`. Nothing about the interface changes; the code that
  draws it simply lives somewhere else, pinned to a tag.

## [0.2.0] - 2026-08-07

### Added

- **An optional update check**, under **Help ▸ Check for Updates
  Automatically**. It is off until you turn it on — this is the only thing in
  the program that opens a socket, and "no network" stays literally true for
  anyone who leaves it alone. Once enabled it asks the APT repository, at most
  once a day, whether a newer version has been published, and shows a quiet
  notice in the status bar with a button that copies
  `sudo apt update && sudo apt upgrade`.

  It never downloads and never installs. Paint is installed by dpkg into a
  root-owned directory, so replacing its own files would need privilege it does
  not have and would leave the package database describing files that are no
  longer there. **Help ▸ Check for Updates Now** runs a single check whatever
  the setting says, and reports when it could not reach the repository rather
  than implying everything is current.

### Changed

- The published download page leads with what the program is — icon, name, a
  download button naming the exact package and its size, and a screenshot that
  follows the reader's colour scheme — instead of opening with a wall of shell
  commands. The apt instructions are unchanged and still the recommended path.

## [0.1.0] - 2026-08-07

First release: a complete, usable editor with parity against classic MS Paint.

### Added

- **Tools** — pencil, brush (round, square and two calligraphic slash tips),
  eraser (to transparent or to the secondary colour), fill bucket with
  tolerance and a contiguous/global switch, colour picker, text, line, curve,
  rectangle, rounded rectangle, ellipse and polygon.
- **Selection** — rectangular and free-form, with floating move, eight resize
  handles, arrow-key nudge, delete, invert, select all and crop to selection.
- **Colours** — primary and secondary swatches with right-click drawing, the
  classic 28-colour palette, a custom colour editor with HSV, RGB, alpha and
  hex entry, and a remembered list of mixed colours.
- **Image operations** — flip horizontal and vertical, rotate by 90/180/270,
  resize by pixels or percentage, canvas size with a nine-point anchor,
  stretch and skew, invert colours and clear image.
- **Undo and redo** governed by a memory budget rather than a step count, so
  small edits give a very deep history.
- **Files** — open and save PNG, JPEG, BMP, GIF, TIFF, TGA and ICO; open WebP,
  Photoshop and Netpbm. Recent files, an unsaved-changes guard, and a file
  path accepted on the command line.
- **Drag and drop** of image files onto the window.
- **Clipboard** copy and paste of images, pasted as a floating selection.
  Copying is written through GTK directly, because the clipboard package this
  started on does not implement image writing on Linux and reports success
  without putting anything anywhere. Cut does not delete the pixels unless the
  copy actually succeeded.
- A **Copy** button in the bottom-right corner, next to the zoom controls, so a
  quick sketch can go straight onto the clipboard and into a chat or document
  without opening a menu. It copies the selection when there is one and the
  whole image otherwise, and confirms in place for a couple of seconds.
- **View** — zoom from 2% to 6400%, with the mouse wheel zooming around the
  pointer and Shift and the wheel scrolling sideways. Fit-to-window, actual
  size, middle-button panning, and a status bar showing cursor position, image
  size and zoom.
- **A window drawn entirely by the application.** There is no system title bar:
  the menus, the document name and the window buttons share a single row in the
  app's own colours, which is one row of chrome less than a system bar stacked
  on a separate menu row. Dragging the bar moves the window, double-clicking it
  maximises, and the window edges resize as usual.
- **Appearance** — a restrained light or dark theme that can follow the desktop,
  drawn with **Slate**, a compact widget kit written for this application and
  kept free of anything specific to it, in `lib/slate/` — since extracted into
  the [slate_ui](https://github.com/alpinsuite/ui-kit) package.
  Menus, dropdowns, dialogs, buttons, sliders and separators are one coherent
  set rather than Material's defaults: flat surfaces, hairline rules instead of
  elevation, tight rows, and a thin icon set drawn as paths so every glyph
  matches at any size. Dropdowns sit in no bordered box — they read as their
  value until the pointer reaches them.
- **Internationalization** wired up through ARB files, English for now.
- **Packaging** — Debian package with desktop entry, MIME associations,
  hicolor icons, AppStream metadata and a man page; an AppImage; and a signed
  APT repository published to GitHub Pages, with a download page generated
  alongside it so the version, the link and the size always match the package
  that was just released.

[Unreleased]: https://github.com/rbuache/paint/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/rbuache/paint/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rbuache/paint/releases/tag/v0.1.0
