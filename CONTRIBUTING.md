# Contributing to MonthPeek

Thanks for your interest! MonthPeek is deliberately small — a calendar you
look at, nothing more — so the bar for new features is "does this keep the
app minimal?". Bug fixes and polish are always welcome.

## Ground rules

- **No third-party dependencies.** The project builds with the Xcode Command
  Line Tools alone and must stay that way.
- **No permissions, no network.** MonthPeek must never trigger a macOS
  permission prompt or make a network request. PRs that add either will be
  declined regardless of the feature.
- **macOS 14+** is the deployment target.

## Getting started

```bash
git clone https://github.com/masudurHimel/monthpeek.git
cd monthpeek
Scripts/make-app.sh      # build + bundle + ad-hoc sign
open build/MonthPeek.app
```

Run the tests with `swift test`. If you have full Xcode, `xed .` opens the
package as a regular Xcode project.

## Making changes

1. Fork and branch from `master`.
2. Keep date math in `Calendar/MonthGrid.swift` pure and covered by tests in
   `Tests/MonthPeekTests/`.
3. Run `swift test` and click through the app (left-click panel, right-click
   menu, resize, Esc, scroll navigation) before opening a PR.
4. Don't bump `VERSION` in feature PRs — releases are cut separately (see
   below).

## Releasing (maintainers)

A release is cut automatically by GitHub Actions when a commit on `master`
changes `VERSION` to a semver value that has no `vX.Y.Z` tag yet:

1. Add a section for the new version to `CHANGELOG.md`.
2. Set the same version in `VERSION`.
3. Merge to `master`. CI builds a universal binary, zips the app, tags the
   commit, and publishes a GitHub Release with the changelog section as notes.
