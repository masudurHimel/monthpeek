# Changelog

All notable changes to MonthPeek are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and MonthPeek adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Bump the version in this file and in `VERSION` together, in the same pull
request, when you intend to ship. Merging that PR to `master` cuts the release.

## [0.1.0] - 2026-08-09

### Added
- Initial release: a menu-bar-only floating month calendar for macOS 14+.
- Menu bar icon drawn as a small calendar glyph showing today's date number,
  refreshed automatically at midnight.
- Left-click toggles a floating calendar panel anchored below the icon;
  right-click (or ctrl-click) shows a two-item menu: Preferences… and Quit.
- The panel floats above every app — including fullscreen ones — without
  stealing focus, with a springy pop-down/retract-up open/close animation.
- Month navigation via ← → buttons, scroll wheel, or trackpad swipe, with a
  slide-and-fade transition; clicking the month title jumps back to today.
- Resizable panel (240×260 – 600×640) whose typography and spacing scale
  fluidly with size; the last size is remembered across launches.
- Today highlighted with a filled accent circle; adjacent-month days dimmed;
  weekends subtly tinted; soft hover state on day cells.
- Preferences window: Appearance (System/Light/Dark), week start
  (Sunday/Monday), week numbers, pin panel, launch at login (`SMAppService`).
- Zero permissions, zero network, zero third-party dependencies.
