# CampusHub Lucide compatibility package

This local package preserves the icon names, code points and original font from
the published `lucide_icons` version 0.257.0. Its upstream source is
<https://pub.dev/packages/lucide_icons/versions/0.257.0>; copyright and license
notices are retained in `LICENSE`.

Recent Flutter SDKs declare `IconData` final, so the upstream
`LucideIconData extends IconData` no longer compiles. Each generated constant now
constructs `IconData` directly with the same code point, `fontFamily: 'Lucide'`
and `fontPackage: 'lucide_icons'`. The original font is copied without changes.
No icon is renamed or remapped, and existing application/test imports remain
`package:lucide_icons/lucide_icons.dart`.

CampusHub's `pubspec.yaml` selects this directory as a path dependency. Keep it
with the application source so builds are reproducible; do not patch the global
Pub cache or Flutter SDK. This package contains no API or database configuration.
