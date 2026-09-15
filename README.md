# MonthPeek

A minimal, beautiful, floating month calendar for the macOS menu bar. Free and open source (MIT), macOS 14+.

Click the date in your menu bar and a clean, translucent calendar card pops down — above whatever you're working on, even fullscreen apps — without ever stealing your focus. Click anywhere else and it tucks itself back into the bar. That's the whole app.

## Features

- **Menu bar only** — no Dock icon, no main window. The icon is a tiny calendar glyph showing today's date, refreshed at midnight.
- **Left-click** toggles the floating calendar panel; **right-click** (or ctrl-click) gives exactly two menu items: *Preferences…* and *Quit*.
- **Floats above everything** — regular apps, other Spaces, and fullscreen apps — and never steals focus from the app you're using.
- **Month navigation** with the ← → buttons, scroll wheel, or trackpad swipe; smooth slide-and-fade transitions. Click the month title to jump back to today.
- **Today** highlighted with a filled accent circle; adjacent-month days dimmed; weekends subtly tinted; soft hover states.
- **Calendar events, if you want them** — an opt-in *Show calendar events* toggle lists the selected day's events under the grid, colored per calendar exactly as in Calendar.app, with an optional dot under days that have events and a checklist to hide calendars. Read-only, off by default, and MonthPeek never asks for calendar access until you turn it on.
- **Resizable** by dragging edges/corners (240×260 up to 600×640) — typography and spacing scale fluidly with the panel, and the size is remembered.
- **Esc closes**, click-outside closes (unless pinned), springy pop-down/retract-up animation.
- **Preferences**: Appearance (System / Light / Dark), week start (Sunday / Monday), week numbers, pin panel, launch at login.

## Privacy: no permissions, no connection required

MonthPeek is a calendar you *look at* — by design it has no access to anything:

- **No permissions.** It never triggers a macOS permission prompt. No Calendar/EventKit access, no Accessibility, no Screen Recording — nothing. There are no events, reminders, or integrations to grant access to.
- **No network. No connection required.** The app makes zero network requests — no analytics, no telemetry, no update checks. It works identically with Wi-Fi off, forever.
- **No third-party dependencies.** Pure Swift + SwiftUI + AppKit. The entire codebase is small enough to audit in an afternoon, and you can verify every claim above with a few greps.
- The only thing it stores is your preferences and panel size, in its own `UserDefaults` domain on your Mac.

## Install

1. Download `MonthPeek-x.y.z.zip` from the [latest release](https://github.com/masudurHimel/monthpeek/releases/latest) and unzip it.
2. Move `MonthPeek.app` to `/Applications`.
3. Open `MonthPeek.app` — the calendar icon appears in your menu bar.

> [!IMPORTANT]
> **You will likely see a warning on first launch** — macOS may say it *"could not verify MonthPeek is free of malware"*. **This is expected and the app is completely safe.** MonthPeek is open source and built by GitHub Actions straight from this repository, but it is **not notarized by Apple, because the maintainer doesn't have a paid Apple Developer account** (notarization requires one). The warning dialog only offers **Done** and **Move to Bin**, so:
>
> 1. Click **Done** (not Move to Bin).
> 2. Open **System Settings → Privacy & Security**, scroll down to *"MonthPeek" was blocked to protect your Mac*, and click **Open Anyway**.
> 3. Confirm, and MonthPeek launches. This is needed only once.
>
> Alternatively, run `xattr -d com.apple.quarantine /Applications/MonthPeek.app` in Terminal and open the app normally.
>
> If you'd rather not trust a downloaded binary at all, the entire source is right here — audit it and build it yourself (below) in under a minute.

## Usage

| Action | Result |
| --- | --- |
| Left-click the menu bar icon | Toggle the calendar panel |
| Right-click / ctrl-click the icon | Menu: Preferences…, Quit |
| ← → buttons, scroll, or swipe | Previous / next month |
| Click the month title | Jump back to today |
| Drag panel edges/corners | Resize (remembered) |
| Drag the panel background | Move the panel |
| Esc or click outside | Close the panel (Pin panel keeps it open) |

## Preferences

Right-click the menu bar icon → **Preferences…**

- **Appearance** — System / Light / Dark (the panel follows automatically)
- **Week starts on** — Sunday / Monday
- **Show week numbers** — adds a week-number gutter to the grid
- **Pin panel** — keep the calendar open when clicking elsewhere
- **Launch at login** — uses Apple's `SMAppService`; no helper app, no daemon
- **Show calendar events** — off by default. Turning it on asks macOS for read access to your calendars and adds an events band under the grid showing the selected day. Click a day to select it; today is selected whenever the panel opens, with the list starting at the next event still ahead. Click an event to open it in Calendar.app.
- **Show event dots in the grid** — off by default. A small dot under days with events, in the calendar's color (gray when several calendars share a day).
- **Calendars** — with events on, a checklist of every calendar from Calendar.app. Uncheck to hide one; calendars you add later show up automatically.

> [!NOTE]
> **About the calendar permission.** MonthPeek only *reads* events and only when *Show calendar events* is on; it never creates, edits, or deletes anything, and it still makes no network requests. Because builds are ad-hoc signed (see below), macOS ties the grant to each specific build: expect to be asked again after updating. If the toggle refuses to stay on, allow MonthPeek under **System Settings → Privacy & Security → Calendars**.

## Build from source

Requires only the **Xcode Command Line Tools** (`xcode-select --install`) — no Xcode, no dependencies.

```bash
git clone https://github.com/masudurHimel/monthpeek.git
cd monthpeek
Scripts/make-app.sh
open build/MonthPeek.app
```

`Scripts/make-app.sh` builds a release binary with Swift Package Manager, assembles `build/MonthPeek.app`, and ad-hoc signs it ("Sign to Run Locally"). Options:

- `--universal` — build an arm64 + x86_64 binary
- `--install` — copy the result to `/Applications` and launch it (quits any running copy first)

Run the tests with `swift test`.

> [!NOTE]
> `swift run` alone won't behave correctly — the app must run from a bundle so `LSUIElement` (no Dock icon) and `SMAppService` (launch at login) work. Always launch via the built `.app`.

If you have full Xcode installed, `xed .` opens the package as a first-class Xcode project.

## Releases

Releases are fully automated ([.github/workflows/release.yml](.github/workflows/release.yml)):

1. A PR bumps `VERSION` and adds a matching section to [CHANGELOG.md](CHANGELOG.md).
2. On merge to `master`, CI runs the tests, builds a **universal** (Apple Silicon + Intel) app, zips it, tags `vX.Y.Z`, and publishes a GitHub Release with the changelog section as release notes.
3. Nothing happens if the version in `VERSION` is already tagged — so ordinary merges never accidentally ship.

Every published binary is built by GitHub Actions from the tagged source — never on a maintainer's machine.

### Signing with a Developer ID instead

Builds are ad-hoc signed by default, which is fine for your own Mac but triggers the Gatekeeper warning above on others. If you fork this and have an Apple Developer account:

1. Find your identity: `security find-identity -v -p codesigning`
2. In `Scripts/make-app.sh`, replace the ad-hoc signing line with:
   ```bash
   codesign --force --options runtime --timestamp \
     -s "Developer ID Application: Your Name (TEAMID)" "$APP"
   ```
3. Notarize and staple so Gatekeeper accepts it without warnings:
   ```bash
   ditto -c -k --keepParent build/MonthPeek.app MonthPeek.zip
   xcrun notarytool submit MonthPeek.zip --keychain-profile <profile> --wait
   xcrun stapler staple build/MonthPeek.app
   ```

## Project layout

```
Sources/MonthPeek/
  MonthPeekApp.swift                 Entry point (accessory app, no Dock icon)
  StatusItemController.swift         Menu bar icon + left/right click routing
  Panel/CalendarPanel.swift          Non-activating floating NSPanel
  Panel/PanelController.swift        Show/hide, positioning, size persistence
  Calendar/MonthGrid.swift           Pure date math (unit tested)
  Calendar/CalendarViewModel.swift   Month state, scroll/swipe navigation
  Calendar/CalendarView.swift        SwiftUI calendar UI + animations
  Events/EventSchedule.swift         Pure event grouping / dot / sizing rules (unit tested)
  Events/EventStoreService.swift     Read-only EventKit wrapper (only file that imports EventKit)
  Events/EventListView.swift         Events band under the grid
  Preferences/                       Preferences window + settings storage
Resources/Info.plist                 LSUIElement bundle plist
Scripts/make-app.sh                  Build → bundle → sign
Tests/MonthPeekTests/                MonthGrid + EventSchedule tests (swift test)
.github/workflows/                   CI + automated releases
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: keep it minimal, keep it dependency-free, and never add anything that needs a permission prompt or a network connection *by default* — opt-in, read-only features are the one exception, and they must stay off until the user turns them on.

## License

[MIT](LICENSE) — free forever.
