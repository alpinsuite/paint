# Releasing

## Versioning

The project follows [Semantic Versioning](https://semver.org). `pubspec.yaml` is
the **single source of truth**:

```yaml
version: 0.1.0+1
#        ^^^^^ semantic version   ^ monotonic build number
```

Everything else derives from it:

| Consumer | How it gets the version |
|---|---|
| Debian control file | `packaging/build_deb.sh` reads `pubspec.yaml` |
| Tarball and AppImage names | Same |
| About dialog | `--dart-define=APP_VERSION`, defaulting to the pubspec value |
| AppStream metainfo | `tools/set_version.sh` writes a `<release>` entry |
| Git tag | Checked against the pubspec by the release workflow |

Since the version is below 1.0.0, the API and the on-disk formats may still
change between minor versions.

## Cutting a release

```bash
# 1. Bump the version everywhere
tools/set_version.sh 0.2.0

# 2. Move the Unreleased notes under a new heading in CHANGELOG.md
#    ## [0.2.0] - 2026-09-01

# 3. Commit and tag
git commit -am "Release 0.2.0"
git tag -a v0.2.0 -m "Release 0.2.0"
git push --follow-tags
```

Pushing the tag is what triggers everything else.

`tools/set_version.sh` with no argument prints the current version, which is how
CI checks that a tag matches.

## What the tag triggers

`.github/workflows/release.yml`:

1. **Checks the tag matches the pubspec version.** A mismatch fails immediately
   with the command needed to fix it, rather than publishing a package whose
   version disagrees with its tag.
2. Runs the tests, then builds the release bundle in an `ubuntu:22.04` container
   (see [PACKAGING.md](PACKAGING.md) for why).
3. Builds the `.deb`, the tarball and the AppImage.
4. Creates a **GitHub Release**, with notes extracted from the matching
   `CHANGELOG.md` section plus the install instructions, and attaches every
   artifact. A version containing a hyphen (`0.2.0-rc.1`) is marked a
   prerelease automatically.
5. Stops there. The suite's **APT repository**, `alpinsuite/apt`, picks the
   release up within the hour, so `apt upgrade` offers the new version. Run
   `gh workflow run publish.yml -R alpinsuite/apt` to publish it at once.

The AppImage step is `continue-on-error`: a failed `appimagetool` download must
not hold back the `.deb`, which is the primary artifact.

## Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com). Add
entries under `## [Unreleased]` as changes land, grouped under **Added**,
**Changed**, **Fixed**, **Deprecated** or **Removed**. The release workflow
copies the section verbatim into the GitHub Release, so write it for users
rather than as a commit log.

## Before tagging

Run the application and draw something. CI covers the analyzer, the unit tests,
the package layout and an install smoke test, but it cannot tell you whether
drawing feels right, and that is the only thing a release of this actually
promises.

## If a release goes wrong

Delete the release and its tag, fix the problem, and tag again with a **new
patch version**. Do not move a tag that has already been published: the APT
repository keeps the old `.deb` in its pool, and a reused version number gives
two different packages the same identity.

```bash
git push --delete origin v0.2.0
git tag -d v0.2.0
# fix, then
tools/set_version.sh 0.2.1
```

`workflow_dispatch` can re-run the release workflow against an existing tag if
only the publishing step failed.
