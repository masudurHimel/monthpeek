# Changelog

All notable changes to MonthPeek are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and MonthPeek adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Bump the version in this file and in `VERSION` together, in the same pull
request, when you intend to ship. Merging that PR to `master` cuts the release.

## [Unreleased]

### Added
- **Show calendar events** (Preferences, off by default). When on, the panel
  extends below the grid with an events band listing the selected day's
  events, each in its calendar's own color. Today is selected when the panel
  opens; click any day to select it; navigating months keeps the same day
  number. Read-only: MonthPeek never modifies events.
- **Show event dots in the grid** (off by default): a small dot under days
  that have events, tinted with the calendar color or gray when calendars mix.
- Per-calendar checklist in Preferences to hide calendars from the band and
  dots. New calendars appear automatically.
- Click an event to open it in Calendar.app. Today's list starts at the first
  event still ahead (scroll up for earlier ones); other days start at the top.
- Scroll wheel over the band scrolls the list; over the grid it still flips
  months.

### Changed
- The "no permissions" rule is now "nothing asks by default": features that
  need a permission are opt-in, read-only, and documented. Turning on calendar
  events triggers the macOS Calendars prompt; leaving it off never does.

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
