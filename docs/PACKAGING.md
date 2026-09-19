# Packaging and distribution

How Paint is packaged, how the APT repository works, and what the other
channels would cost.

## What CI produces

| Artifact | Built by | When |
|---|---|---|
| `paint_<version>_amd64.deb` | `packaging/build_deb.sh` | Every CI run, and every release |
| `paint-<version>-linux-x64.tar.gz` | `tar` over the release bundle | Every CI run, and every release |
| `Paint-<version>-x86_64.AppImage` | `packaging/build_appimage.sh` | Releases only |

## The glibc baseline

Release binaries are built inside an `ubuntu:22.04` container, not on the
GitHub runner's own image.

A Flutter bundle built on Ubuntu 24.04 links against glibc 2.39 and will not
start on Ubuntu 22.04 or Debian 12. Building against 2.35 runs on everything
from Ubuntu 22.04 and Debian 12 upwards, which is most of the installed base.
It also makes `dpkg-shlibdeps` emit the pre-`t64` library names that those
releases actually ship — a package built on 24.04 would depend on
`libgtk-3-0t64`, which does not exist on 22.04.

## Inside the `.deb`

```
/usr/bin/paint                                   launcher shim
/usr/lib/paint/                                  the Flutter bundle
/usr/share/applications/io.github.rbuache.Paint.desktop
/usr/share/metainfo/io.github.rbuache.Paint.metainfo.xml
/usr/share/icons/hicolor/{16..512,scalable}/apps/io.github.rbuache.Paint.*
/usr/share/man/man1/paint.1.gz
/usr/share/doc/paint/{copyright,changelog.gz}
```

The bundle keeps its own layout under `/usr/lib/paint` because the engine
locates its data relative to the executable. `/usr/bin/paint` is a two-line
shim rather than a symlink, for the same reason.

The desktop entry declares `MimeType=` for every readable format, so Paint
appears under "Open With" for images, and `StartupWMClass=paint` so the running
window matches its launcher icon. `postinst` refreshes the desktop and icon
caches so the entry appears without a logout.

**Dependencies are computed, never written by hand.** `dpkg-shlibdeps` reads the
ELF binaries — including the bundled engine libraries — and reports exactly what
they link against. A hand-written list is correct the day it is written and
wrong after the next engine upgrade. A conservative fallback exists only for
building on a non-Debian host.

## The APT repository

Paint does not publish its own. Every Buache Systems application is served from
one signed repository, [alpinsuite/apt](https://github.com/alpinsuite/apt), at
`https://apt.buache.systems`: one key and one `.sources` file for the whole
suite.

That repository pulls. Once an hour it downloads the `.deb`s from the newest
three published releases of each application, checks that a clean Debian
container will install from the result, signs the index and deploys it. So the
release workflow here ends at the GitHub Release: it holds no archive key for
apt and pushes nothing anywhere else. A draft or a prerelease is never
published to apt, because `apt upgrade` would hand it to everyone.

To publish a release without waiting for the hour:

```bash
gh workflow run publish.yml -R alpinsuite/apt
```

The layout, the key handling and the install test are documented there.

### Signing

The archive key lives in `alpinsuite/apt`. This repository still reads
`APT_GPG_PRIVATE_KEY` and `APT_GPG_PASSPHRASE`, for one thing only: signing the
release's `SHA256SUMS`, so a `.deb` downloaded by hand can be verified against
the same key apt trusts. Without them the sums are published unsigned, with a
warning.

### What users run

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.buache.systems/buache-systems-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/buache-systems.gpg > /dev/null
sudo curl -fsSL -o /etc/apt/sources.list.d/buache-systems.sources \
  https://apt.buache.systems/buache-systems.sources
sudo apt update && sudo apt install paint
```

## Testing the repository locally

```bash
flutter build linux --release
bash packaging/build_deb.sh
bash ../apt/test_install.sh build/dist/*.deb
```

`test_install.sh` builds a repository around the package with a throwaway key
and follows the instructions above inside a clean `debian:12` container.

## Other channels considered

| Channel | Verdict |
|---|---|
| **Launchpad PPA** | The most familiar route for Ubuntu users, but Launchpad's builders have no network access. The Flutter SDK and the whole pub cache — roughly a gigabyte — would have to be vendored into the source tarball, and a separate build maintained per Ubuntu series. Not worth blocking v1; possible later. |
| **Snap** | Snapcraft ships an official `flutter` extension, which makes this the easiest real *store* route, with automatic updates. Needs a Snapcraft Store account. A good M2 addition. |
| **Flatpak / Flathub** | Best cross-distro reach and a genuine sandbox, but the Flutter SDK has to be vendored into the manifest and the build is slow. Worth doing once the APT repository is settled. |
| **AppImage** | Already built: one file, no package manager, runs nearly everywhere. The natural companion to the `.deb`. |
| **Debian / Ubuntu archive** | Needs a sponsor and a DFSG-clean build, and Flutter itself is not packaged in Debian. Long-term only. |
| **`.deb` on Releases alone** | The fallback (`apt install ./paint_*.deb`), but it gives no upgrade path — which is exactly what the APT repository exists to provide. |

## Validating a package

```bash
lintian build/dist/*.deb
desktop-file-validate packaging/deb/io.github.rbuache.Paint.desktop
appstreamcli validate packaging/deb/io.github.rbuache.Paint.metainfo.xml
dpkg-deb --contents build/dist/*.deb
```

Several lintian policy checks do not apply to a self-contained bundled
application, so CI reports its findings without failing on them.
