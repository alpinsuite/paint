# Architecture

How the editor is put together, and why. Read [DECISIONS.md](DECISIONS.md) for
the reasoning behind the choices summarised here.

## Shape of the code

```
lib/
  main.dart                 entry point: window, providers, CLI argument
  app.dart                  MaterialApp: theme, localisations
  core/
    image_utils.dart        every ui.Image is produced here
    settings/               persisted preferences (shared_preferences)
    theme/                  sober light/dark themes + canvas colours
  model/                    plain data: document, layer, selection, tool settings
  controller/               mutable state and the rules that govern it
  tools/                    one file per family of tools
  ops/                      pure pixel operations, no Flutter widgets
  io/                       codecs, file dialogs, clipboard
  ui/                       widgets
  l10n/                     app_en.arb + generated AppLocalizations
```

The dependency direction is one-way: `ui` → `controller` → `model`/`ops`/`core`.
Nothing in `ops/` or `model/` imports a widget, which is what makes them
straightforward to unit test without a widget binding. `ui` also depends on the
`slate_ui` package, which cannot import anything from here at all now that it
lives in a repository of its own.

## State

Six objects live for the lifetime of the process and are handed to the widget
tree by `provider`:

| Object | Responsibility |
|---|---|
| `SettingsController` | Theme, recent files, undo budget, default canvas size, custom colours. |
| `DocumentController` | The bitmap and the undo history. **The only thing that mutates pixels.** |
| `SelectionController` | The current selection, and lifting/anchoring its pixels. |
| `ToolSettings` | Active tool, colours, stroke width, per-tool options. |
| `ViewportController` | Zoom, pan, and the screen ↔ image transform. |
| `CanvasController` | Turns pointer and keyboard input into tool gestures. |

They are all `ChangeNotifier`s. There is no reactive framework beyond that: the
canvas is a `CustomPainter` whose `repaint` is a `Listenable.merge` of the four
notifiers that can change what is on screen.

## The document

`PaintDocument` is immutable. Every edit produces a new one:

```dart
final updated = document.withActiveImage(newBitmap);
```

That is what makes undo tractable — restoring a previous state is swapping which
document is current, not trying to reverse a mutation in place.

A document holds a `List<Layer>`, which in this version always has exactly one
entry. The type exists so that adding a layers panel later is an additive change
to the UI rather than a rewrite of the document, the history and every image
operation.

## Rendering

`CanvasPainter.paint` does, in order:

1. Fill the backdrop.
2. Draw the transparency checkerboard, clipped to the image rectangle, in
   **screen space** so it reads as "behind the image" rather than as content.
3. Apply the viewport transform (translate, then scale).
4. `saveLayer` → draw each visible layer → draw the live tool preview →
   `restore`. The layer is what lets an eraser stroke composite with
   `BlendMode.clear` and punch through the image instead of the checkerboard.
5. Draw the floating selection pixels.
6. Draw overlays outside the layer: rubber bands, control points, marching ants
   and selection handles. These are chrome and are never committed.

`FilterQuality.none` is used at zoom ≥ 1 so magnified pixels stay crisp; a paint
program that blurs at 800% cannot be used for touching up individual pixels.

## Tools: preview and commit are the same code

A `ToolGesture` has one `draw(Canvas)` method. It is called every frame to
render the live preview, and once more when the gesture is committed to the
bitmap:

```dart
// live preview, inside CanvasPainter.paint
gesture?.draw(canvas);

// commit, inside DocumentController.commitRegion
final updated = await ImageUtils.drawOver(source, (canvas) {
  canvas.save();
  canvas.clipRect(rect);
  draw(canvas);        // ← the very same closure
  canvas.restore();
});
```

There is no second implementation that could disagree with the first, so what
the user sees while dragging is what lands in the image.

A gesture also reports `bounds`: the region it touches. The commit clips to it
and undo preserves only those pixels. A tool that under-reports its bounds
produces a clipped edit, so shape tools inflate by their stroke width and
freehand tools by the full brush width.

Tools that act on press with no drag — the fill bucket and the colour picker —
return `null` from `begin` and implement `tap` instead. Selection tools return a
gesture with `modifiesBitmap == false`, so it changes editing state without
touching the undo stack.

## Undo

`History` is bounded by a **memory budget** (512 MB by default), not a step
count. Two entry kinds:

- `RegionEdit` — the touched rectangle's pixels before and after. Every drawing
  tool produces one. Keeping whole-canvas snapshots would exhaust the budget
  after a handful of brush strokes on a large image.
- `CanvasEdit` — the whole bitmap before and after, for operations with no small
  dirty region: resize, rotate, crop, colour adjustments.

Oldest entries are evicted first once over budget, except that the newest entry
is never evicted — a single edit larger than the whole budget must still be
undoable once, or the user is stuck with a change they cannot reverse.

Small edits on a small image therefore give a very deep history, and whole-canvas
edits on a huge image give a shallow one, which is the behaviour people
actually want.

## Ownership of `ui.Image`

`ui.Image` is refcounted and must be disposed. The rule throughout:

- The document owns its layers' images.
- History owns its own copies. `RegionEdit` extracts fresh region images;
  `CanvasEdit` calls `.clone()` so disposing the document's copy does not free
  the history's.
- Whoever replaces an image disposes the one it displaced.

## Serialised edits

Rasterising goes through the engine and is therefore asynchronous. Two
overlapping commits would each build on the same stale bitmap and one would be
silently lost, so `DocumentController` funnels every edit through a promise
chain:

```dart
Future<T> _serialize<T>(Future<T> Function() action) { ... }
```

Edits queue rather than race.

## Threading

Flood fill runs on a background isolate (`Isolate.run`); a full-canvas fill on a
large image is tens of milliseconds of tight-loop work that would drop frames on
the UI thread. Image encoding and the `package:image` decode fallback go through
`compute` for the same reason.

Pixel operations work in **straight** (non-premultiplied) alpha, because that is
the space users reason about: a 50%-transparent red is `(255, 0, 0, 128)`, not
the `(128, 0, 0, 128)` the engine stores. `ImageUtils` converts at the boundary.

## Selection

A selection has two states:

- **Anchored** — the shape is marked, but the pixels are still part of the layer.
- **Floating** — the first move or resize lifts the pixels: the region is erased
  from the layer (to transparent, or to the secondary colour, per the
  "transparent selection" option) and the pixels become an image carried by the
  selection.

Anchoring stamps them back down as a normal undoable region edit. That two-state
model is what makes a selection behave like Paint's rather than like a permanent
crop. Pasting creates a floating selection directly, so a paste can be dragged
into place before it becomes part of the image.

## The interface kit

Everything the user sees is drawn with **Slate**, the `slate_ui` package from
[alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit), pinned to a tag in
`pubspec.yaml`. It supplies the palette, the metrics, a path-drawn icon set and
the controls: menus, selects, buttons, checkboxes, sliders, fields, separators
and dialogs.

The rule that gives it its shape is that it holds nothing specific to this
application. No controller, no model, no `AppLocalizations`, no image-editor
concept, and no user-facing string literal — every label and tooltip is a
parameter, so the caller owns translation. Holding that line from the start is
what let the kit be lifted out in one piece, and the package boundary now
enforces what was previously a rule: a widget that cannot name a Paint concept
cannot quietly grow a dependency on one.

Changing a colour, a metric or a control is a change in that repository, a
release, and a `ref` bump here.

Material is not discarded. `SlateThemeData.toMaterialTheme()` produces a
`ThemeData` in the same palette, because an app still gets Scaffold, Navigator,
tooltips and text selection from Material and those must not arrive looking like
a different program. `CanvasColors` stays outside the kit as a `ThemeExtension`:
the backdrop, the transparency checkerboard and the marching ants describe the
drawing surface, not the chrome, and no general interface kit should have an
opinion about them.

Two implementation notes that are easy to get wrong:

- **`SlateMenuScope` is installed above the `MenuAnchor`, never inside its
  builder.** The menu panel is an `OverlayPortal` child, so it inherits from the
  anchor's ancestors and not from the widget the anchor's builder returns.
  Putting the scope in the builder compiles and silently does nothing — the rows
  never find it and the menu never closes.
- **The menu bar shares one coordinator.** Each top-level menu owns its own
  `MenuController`, so without shared state, sliding from an open File menu onto
  Edit would do nothing. `SlateMenuBar` holds which controller is open and turns
  a hover into a switch.

## Internationalization

Every user-visible string lives in `lib/l10n/app_en.arb` and is read through
`AppLocalizations`. `tools/check_hardcoded_strings.sh` fails CI when a literal
is passed to a `Text` widget, and CI also verifies that the generated
localisations are not stale. Adding a language is dropping in `app_fr.arb` and
running `flutter gen-l10n`; no UI code changes.

## Where the platform shows through

Kept deliberately small, so the app stays portable even though only Linux is
built today:

- `linux/runner/my_application.cc` — window size and the hicolor icon name.
- `window_manager` — title and close interception for the unsaved-changes guard.
- `file_selector` — GTK open/save dialogs.
- `desktop_drop` — files dropped onto the window.
- `pasteboard` — image clipboard.
