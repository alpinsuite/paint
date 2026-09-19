# Contributing

## Getting set up

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter pub get
flutter run -d linux
```

Flutter 3.44.8 is what CI uses; other 3.x versions will probably work but are
not tested.

## Before you push

The same four checks CI runs:

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
flutter test
```

## Conventions

**Every user-visible string goes in `lib/l10n/app_en.arb`** and is read through
`AppLocalizations.of(context)`. Run `flutter gen-l10n` after editing the ARB and
commit the generated files — CI fails if they are stale. The hardcoded-string
check will catch a literal passed to a `Text` widget.

**Pixels only change through `DocumentController`.** `commitRegion` for anything
with a dirty rectangle, `commitCanvas` for whole-image operations. Nothing else
may mutate a layer's bitmap, or undo stops being complete.

**A tool's `draw` is used for both the preview and the commit.** Do not add a
second drawing path — see [DECISIONS.md](docs/DECISIONS.md#3-preview-and-commit-share-one-draw-method).

**Declare honest `bounds`.** The commit clips to them, so under-reporting
produces a visibly clipped edit. Inflate by the stroke width.

**Pixel operations belong in `ops/`**, take and return a `ui.Image`, never mutate
their input, and import no widgets. That is what makes them unit-testable.

**Anything that loops over pixels runs off the UI thread** — `Isolate.run` or
`compute`.

**Comment the "why", not the "what".** Explain a non-obvious constraint, a
trade-off or a bug the code is avoiding. Do not narrate what the next line does.

## Tests

Unit tests for `ops/`, `controller/`, `model/` and `io/` are expected with any
change to those layers. Test observable behaviour rather than implementation
details, and give assertions a `reason:` when the failure would otherwise be
cryptic.

```bash
flutter test
flutter test test/ops/flood_fill_test.dart
```

## Commits and pull requests

Write the subject line in the imperative — "Add the polygon tool", not "Added".
Explain *why* in the body when it is not obvious from the diff.

Add a `CHANGELOG.md` entry under `## [Unreleased]` for anything a user would
notice. Do not bump the version in a pull request; releases do that (see
[RELEASING.md](docs/RELEASING.md)).

## Where things live

[ARCHITECTURE.md](docs/ARCHITECTURE.md) has the map. In short: `ui` depends on
`controller`, which depends on `model`, `ops` and `core`. Nothing in `ops/` or
`model/` may import a widget.
