# Features

What the editor does today, what it deliberately does not, and how it lines up
against Windows Paint.

Legend: **✅** shipped · **M2** planned next · **M3** later · **—** out of scope.

## Tools

| Tool | Shortcut | Options | Status |
|---|---|---|---|
| Pencil | `P` | — (always 1 px, hard-edged, snapped to the pixel grid) | ✅ |
| Brush | `B` | size 1–64 px, tip (round, square, slash, backslash), smooth edges | ✅ |
| Eraser | `E` | size, erase to transparent or to the secondary colour | ✅ |
| Fill with colour | `F` | tolerance 0–255, contiguous or global | ✅ |
| Pick colour | `K` | — | ✅ |
| Text | `T` | family, size, bold, italic, underline, alignment, opaque background | ✅ |
| Line | `L` | width, smooth edges | ✅ |
| Curve | `C` | width, smooth edges | ✅ |
| Rectangle | `R` | width, fill style, smooth edges | ✅ |
| Rounded rectangle | `D` | width, fill style, corner radius | ✅ |
| Ellipse | `O` | width, fill style, smooth edges | ✅ |
| Polygon | `G` | width, fill style, smooth edges | ✅ |
| Rectangular selection | `S` | transparent selection | ✅ |
| Free-form selection | `A` | transparent selection | ✅ |

Modifiers while drawing: `Shift` constrains lines to 45° steps and rectangles
and ellipses to squares and circles; `Ctrl` draws a shape outwards from its
centre. Right-dragging swaps the primary and secondary colours, so the outline
and fill roles are exchanged.

The curve tool follows Paint's three-step gesture: drag the base line, then drag
it into shape twice to place the two Bézier control points. The polygon closes
when you click near its first vertex, or on `Escape`.

## Colours

- Primary and secondary swatches; left- and right-click respectively on any
  palette cell, and a swap control between them.
- The classic 28-colour Paint palette.
- A colour editor with a saturation/value field, hue and alpha sliders, RGB
  sliders and hex entry.
- Mixed colours are remembered between sessions and shown as a recent row.
- Full alpha support throughout, with a checkerboard behind transparent areas.

## Selection

Selections start *anchored* — the shape is marked but the pixels are still part
of the image. The first drag *lifts* them: the region is cleared (to transparent
or to the secondary colour, per the "transparent selection" option) and the
pixels float until they are put down again.

| | Status |
|---|---|
| Rectangular and free-form shapes | ✅ |
| Move by dragging | ✅ |
| Resize by eight handles | ✅ |
| Nudge with the arrow keys | ✅ |
| Cut, copy, paste, delete | ✅ |
| Select all, deselect, invert | ✅ |
| Crop image to the selection | ✅ |
| Paste as a floating selection, growing the canvas if needed | ✅ |

## Image operations

Flip horizontal and vertical · rotate 90° left/right and 180° · resize by pixels
or percentage, with an aspect-ratio lock and a smooth/nearest-neighbour switch ·
canvas size with a nine-point anchor · stretch and skew in one dialog · invert
colours · clear image.

## Files

| Format | Open | Save | Notes |
|---|---|---|---|
| PNG | ✅ | ✅ | Default; keeps transparency |
| JPEG | ✅ | ✅ | Quality setting; flattens transparency onto white |
| BMP | ✅ | ✅ | |
| GIF | ✅ | ✅ | First frame on open |
| TIFF | ✅ | ✅ | |
| TGA | ✅ | ✅ | |
| ICO | ✅ | ✅ | |
| WebP | ✅ | — | `package:image` has no WebP encoder |
| Photoshop | ✅ | — | Flattened |
| Netpbm (PNM/PBM/PGM/PPM) | ✅ | — | |

Also: recent files, an unsaved-changes guard on new/open/quit, a file path
accepted on the command line, drag-and-drop onto the window, MIME registration
so Paint appears under "Open With", and copy/paste of images via the system
clipboard.

## View

Zoom 2%–6400%, with `Ctrl+scroll` zooming around the pointer, a logarithmic zoom
slider, fit-to-window and actual-size. Middle-button panning. Crisp
nearest-neighbour rendering at zoom ≥ 100% so individual pixels stay editable.
A status bar showing cursor position, image size and zoom.

## Undo

Bounded by a memory budget (512 MB by default) rather than a step count. Drawing
tools store only the rectangle they touched, so ordinary editing gives a very
deep history; whole-canvas operations store a full snapshot and are therefore
shallower. The most recent edit is never evicted.

---

## Parity with Windows Paint

### Classic MS Paint

| Feature | Status |
|---|---|
| Pencil, brush, eraser, fill, colour picker | ✅ |
| Line, curve, rectangle, rounded rectangle, ellipse, polygon | ✅ |
| Text tool | ✅ |
| Magnifier | ✅ (zoom control and `Ctrl+scroll` rather than a tool) |
| Rectangular and free-form selection, move, resize, crop | ✅ |
| Two active colours, palette, Edit Colors dialog | ✅ |
| Cut, copy, paste, paste from file, copy to file, select all | ✅ |
| Undo / redo | ✅ (far deeper than Paint's three steps) |
| Flip, rotate 90/180/270 | ✅ |
| Stretch and skew | ✅ |
| Resize image, canvas attributes | ✅ |
| Invert colours, clear image | ✅ |
| Draw opaque / transparent selection | ✅ |
| New, open, save, save as, recent files | ✅ |
| Status bar with coordinates and size | ✅ |
| Rotate by an arbitrary angle | M2 |
| Show grid / gridlines | M2 |
| Rulers | M2 |
| Thumbnail / navigator | M2 |
| Full screen (View bitmap) | M2 |
| Print, page setup, print preview | M3 (export to PDF + system print dialog) |
| Set as desktop wallpaper | M3 |
| Send in e-mail | M3 |

### Windows 11 Paint

| Feature | Status |
|---|---|
| Dark mode | ✅ |
| Transparency / alpha throughout | ✅ |
| Zoom slider | ✅ |
| Crop | ✅ |
| Deep undo | ✅ |
| Layers (add, delete, reorder, opacity, merge) | M2 |
| Extra brushes: airbrush, marker, calligraphy, crayon, watercolour, oil | M2 |
| Magic wand / auto-select | M2 |
| AI background removal, Cocreator, Image Creator | — |

The AI features are the one deliberate omission: they require sending your image
to a remote service, and this editor does everything locally.

---

## Roadmap

### M2 — the next pass

- **Layers**, with a panel and a native `.paintproj` format (a zip of a manifest
  plus one PNG per layer) so they survive a save. The document model already
  carries a layer list, so this is additive.
- More brushes: airbrush, marker, calligraphy, crayon, watercolour.
- Magic wand selection, colour-replace and gradient tools.
- Adjustments: brightness/contrast, hue/saturation, blur, sharpen.
- Pixel grid, rulers, guides and snapping.
- Multi-document tabs.
- Autosave and crash recovery.
- Rotate by an arbitrary angle; navigator thumbnail; full-screen view.
- Stylus and tablet pressure driving brush size and opacity.
- **Pixel-art mode** — nearest-neighbour zoom, a pixel grid and anti-aliasing
  off by default. A niche Paint has always served badly.
- **Symmetry / mirror drawing** — cheap to build on the existing tool framework
  and genuinely fun.

### M3 — later

- Print and export to PDF.
- Screenshot import through `xdg-desktop-portal`, so it works under Wayland.
- Set as desktop wallpaper.
- A command palette (`Ctrl+Shift+P`).
- Flatpak and Snap builds alongside the `.deb` and AppImage.
- Additional translations — the plumbing is already in place, only ARB files are
  needed.
