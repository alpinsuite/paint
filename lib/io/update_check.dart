/// Looks up whether a newer Paint has been published.
///
/// The check reads the APT repository's own package index rather than the
/// GitHub API. Three reasons: it is the same host the user already trusts to
/// deliver the packages, so the check adds no new party to the picture; it is
/// unauthenticated and unmetered, where the GitHub API is rate-limited per IP
/// and would fail unpredictably on a shared address; and it reports what can
/// actually be installed, which is not always the newest tag.
///
/// Nothing here downloads or replaces anything. The application is installed by
/// dpkg into a root-owned directory and must not modify itself behind the
/// package manager's back; the most it should do is say that `apt upgrade` has
/// something to offer.
library;

import 'dart:convert';
import 'dart:io';

/// The published package index for the stable suite.
const String kPackagesIndexUrl =
    'https://apt.buache.systems/dists/stable/main/binary-amd64/Packages';

/// The package the index is searched for.
const String kPackageName = 'paint';

/// How the index is retrieved. Injected so the logic can be tested without a
/// network, and so a caller could route it through a proxy.
typedef IndexFetcher = Future<String> Function(Uri url);

/// Compares two versions of the form `1.2.3` or `1.2.3-rc.1`.
///
/// Returns a negative number when [a] is older, zero when they are equal, and
/// a positive number when [a] is newer. A prerelease sorts *before* the release
/// it leads to, so `0.2.0-rc.1` is older than `0.2.0` — which is what
/// semantic versioning says and what the release workflow assumes when it marks
/// a hyphenated version as a prerelease.
int compareVersions(String a, String b) {
  final (aNumbers, aSuffix) = _split(a);
  final (bNumbers, bSuffix) = _split(b);

  final length = aNumbers.length > bNumbers.length
      ? aNumbers.length
      : bNumbers.length;
  for (var i = 0; i < length; i++) {
    // A missing component is zero, so 1.2 and 1.2.0 compare equal.
    final left = i < aNumbers.length ? aNumbers[i] : 0;
    final right = i < bNumbers.length ? bNumbers[i] : 0;
    if (left != right) return left.compareTo(right);
  }

  if (aSuffix == bSuffix) return 0;
  if (aSuffix.isEmpty) return 1;
  if (bSuffix.isEmpty) return -1;
  return aSuffix.compareTo(bSuffix);
}

/// True when [candidate] is a version worth telling the user about.
bool isNewerVersion(String candidate, String current) =>
    compareVersions(candidate, current) > 0;

(List<int>, String) _split(String version) {
  final trimmed = version.trim();
  final hyphen = trimmed.indexOf('-');
  final numbers = hyphen == -1 ? trimmed : trimmed.substring(0, hyphen);
  final suffix = hyphen == -1 ? '' : trimmed.substring(hyphen + 1);
  return (
    numbers.split('.').map((part) => int.tryParse(part) ?? 0).toList(),
    suffix,
  );
}

/// The highest version of [kPackageName] in an APT `Packages` index.
///
/// The index is RFC822-style stanzas separated by blank lines, and the pool
/// keeps older packages, so several stanzas for the same package are normal and
/// they are not ordered.
String? latestVersionIn(String packagesIndex) {
  String? best;
  String? name;
  String? version;

  void endOfStanza() {
    if (name == kPackageName && version != null) {
      if (best == null || compareVersions(version!, best!) > 0) best = version;
    }
    name = null;
    version = null;
  }

  for (final line in const LineSplitter().convert(packagesIndex)) {
    if (line.trim().isEmpty) {
      endOfStanza();
    } else if (line.startsWith('Package:')) {
      name = line.substring('Package:'.length).trim();
    } else if (line.startsWith('Version:')) {
      version = line.substring('Version:'.length).trim();
    }
  }
  endOfStanza();

  return best;
}

/// Asks the repository what the newest published version is.
class UpdateCheck {
  const UpdateCheck({
    this.fetch = fetchOverHttps,
    this.indexUrl = kPackagesIndexUrl,
  });

  final IndexFetcher fetch;
  final String indexUrl;

  /// The published version, when it is newer than [currentVersion]. Null when
  /// the current version is already the newest, and null when the check could
  /// not be completed — an update check that cannot reach the network is not an
  /// error the user needs to hear about unless they asked for it, which is why
  /// [checkFailed] reports that case separately.
  Future<String?> newerThan(String currentVersion) async {
    final latest = await latestPublished();
    if (latest == null) return null;
    return isNewerVersion(latest, currentVersion) ? latest : null;
  }

  /// The newest published version, or null when the index could not be read.
  Future<String?> latestPublished() async {
    try {
      final body = await fetch(Uri.parse(indexUrl));
      return latestVersionIn(body);
    } on Object {
      // Offline, DNS failure, a captive portal returning HTML, a half-published
      // repository: none of these are worth an exception escaping into the UI.
      return null;
    }
  }
}

/// Raised when the check could not reach the index, so an explicit
/// "check now" can say so rather than claiming the app is up to date.
class UpdateCheckFailure implements Exception {
  const UpdateCheckFailure();
}

/// How long the whole check may take before it is abandoned.
///
/// This bounds the entire operation rather than any one step. An earlier
/// version put the deadline on reading the response, which left name resolution
/// and connection setup unbounded — and a machine with no working resolver then
/// hung forever, so the check neither succeeded nor reported a failure. From
/// the outside that is indistinguishable from "up to date", which is the one
/// answer it must never give by accident.
const Duration kUpdateCheckDeadline = Duration(seconds: 10);

/// The default fetcher: a plain HTTPS GET with a deadline on the whole thing.
Future<String> fetchOverHttps(Uri url) async {
  final client = HttpClient()
    ..connectionTimeout = kUpdateCheckDeadline
    ..userAgent = 'paint-update-check'
    // Respects http_proxy, https_proxy and no_proxy. Dart does not consult
    // them on its own, and a desktop behind a corporate proxy is common enough
    // that not doing so would look like the check is simply broken.
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    return await _get(client, url).timeout(kUpdateCheckDeadline);
  } finally {
    client.close(force: true);
  }
}

Future<String> _get(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    // Drained so the connection can be reused or closed cleanly rather than
    // left half-read.
    await response.drain<void>();
    throw const UpdateCheckFailure();
  }
  return response.transform(utf8.decoder).join();
}
