/// The running version, as a single source of truth for the whole application.
///
/// `pubspec.yaml` holds the canonical value and `tools/set_version.sh` copies it
/// into the default below, the same way it copies it into the AppStream
/// metainfo. Dart cannot read pubspec at runtime without a plugin, and the two
/// places that need this — the About box and the update check — must agree with
/// the version the package manager thinks it installed.
///
/// Getting this wrong is not cosmetic. The update check compares this against
/// what the repository publishes, so a build that understates its own version
/// tells every user an upgrade is waiting and never stops.
///
/// The environment override exists so a build can stamp a version without
/// touching the tree — a nightly, or a reproducible rebuild of an old tag.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  // set_version.sh rewrites this line. Keep it on one line and in this shape.
  defaultValue: '0.2.0',
);
