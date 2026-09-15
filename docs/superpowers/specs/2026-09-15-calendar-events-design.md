# Calendar events under the month grid

**Date:** 2026-09-15
**Status:** approved (design mock reviewed and accepted)

## Goal

Let the user opt in to seeing their macOS calendar events inside the MonthPeek
panel. Off by default. When on, the panel extends downward by an *events band*
that lists the events of the currently selected day, colored per calendar
exactly as Calendar.app colors them. A per-calendar checklist in Preferences
hides calendars the user does not want to see.

Read-only. MonthPeek never creates, edits, or deletes events.

## Non-goals

- Editing events. Rows open the event in Calendar.app (added after the
  first review); MonthPeek itself never writes.
- Showing events for a range (week, month, upcoming). Only the selected day.
- A per-day event *count* or multi-dot indicator in the grid.
- Reminders, birthdays as a separate feature, or anything outside EventKit's
  `.event` entity type.

## Policy change

CONTRIBUTING.md and README.md currently say the app must never trigger a
permission prompt. That rule becomes:

> MonthPeek never asks for a permission, makes a network request, or touches
> user data *unless the user turns a feature on that needs it*. Every such
> feature is off by default, is read-only, and is documented here.

Calendar access is the first and only such feature.

## User-facing behavior

### Preferences

Below a divider under the existing controls:

- **Show calendar events** (toggle, default off). Caption: "Lists the selected
  day's events under the grid. Read-only. While this is off, MonthPeek never
  asks for calendar access."
  - Turning it on requests full read access to events. If the result is
    anything other than full access, the toggle springs back off and the
    caption turns into: "Calendar access is off for MonthPeek. Allow it in
    System Settings › Privacy & Security › Calendars, then turn this on
    again." The System Settings phrase is a link that opens the Calendars
    privacy pane.
- **Show event dots in the grid** (toggle, default off). Caption: "Marks days
  that have events." Disabled while events are off.
- **Calendars** checklist, visible only while events are on and access is
  granted. Every calendar EventKit returns, grouped by account (source title),
  each row: checkbox, color swatch in the calendar's own color, title, and a
  small tag for "Shared" or "Subscribed" where applicable. Unchecking hides
  the calendar. Stored as a set of *hidden* calendar identifiers so calendars
  added later show up automatically.

### Panel

- **Selection.** The grid gains a selected day. Today is selected whenever the
  panel opens (the panel already snaps to today on open). Clicking a day cell
  selects it. Navigating months moves the selection to the same day number in
  the new month, clamped to that month's last day. "Jump to today" selects
  today.
- **Selected day look.** Today keeps its filled accent circle. A selected day
  other than today gets a soft fill (primary at 8%) with a 1.5 pt accent ring.
  Selecting today changes nothing visually beyond the list.
- **Dots.** When the dots toggle is on, a 4 pt dot sits 3 pt below the day
  number on any day with at least one visible event. Its color is the
  calendar's color when every event that day is from one calendar, otherwise
  neutral gray. On today's cell the dot is white. Adjacent-month days show
  their dot at the same dimmed opacity as their number.
- **Events band.** Appears below the grid, separated by a hairline. Header row:
  the selected day ("Tue, Sep 15") left, count ("3 events") right. Then one
  row per event: 3 × 24 pt calendar-colored bar, time column (start with end
  beneath, or "ALL DAY"), title, calendar name in small muted text. All-day
  events sort first, then by start time, then title. Up to four rows are
  visible; more scroll inside the band, with the fifth row peeking through
  cut off as the hint. No events shows a single centered "No events" row.
  Today's list starts scrolled to the first timed event that has not ended
  yet (an event in progress stays visible); if everything is over it starts
  at the last event. Other days start at the top. Clicking a row opens the
  event in Calendar.app via `ical://ekevent/<occurrence>/<calendarItemIdentifier>?method=show&options=more` (the local UUID; EventKit's `eventIdentifier` only opens the app); the
  row shows a soft hover fill and an "Open in Calendar" tooltip.
- **Sizing.** The saved panel size continues to describe the grid. The band is
  added below it, sized from its row count and the same width-derived scale
  factor the grid uses. The window frame grows and shrinks (animated, top edge
  anchored under the menu bar) as the selected day's row count changes. When
  the user resizes the panel, the grid height saved is `frame.height - band`.
  Min and max window heights shift by the current band height. The base max
  height stays 640 for the grid.
- **Scrolling.** Wheel/trackpad over the grid still flips months. Over the
  band it scrolls the list. The existing local scroll monitor decides by the
  pointer's position inside the window.
- **Refresh.** Events for the visible six-week window are fetched when the
  panel opens, when the displayed month changes, when the toggle or the
  checklist changes, and whenever EventKit posts its store-changed
  notification. Opening the panel also asks EventKit to refresh its sources
  so server-side changes Calendar.app has not pulled yet arrive. Fetches are
  never cancelled: each merges only its own window into a per-day cache, so a
  slow fetch cannot blank a month and visited months reopen instantly. A
  settings or store change clears the cache and refetches the visible month.
- **Revoked access.** If the stored toggle is on but authorization is no
  longer full access at launch, the band and dots do not appear and the
  Preferences caption shows the denied text. The stored toggle is left as is.

## Architecture

```
PanelController ──owns──► CalendarViewModel ──reads──► EventStoreService.shared
      │                          │                          │  (EventKit)
      │ sets frame               │ publishes                │ publishes
      ▼                          ▼                          ▼
 CalendarPanel          PanelRootView                PreferencesView
                       ├ CalendarView (grid)          (toggles, checklist)
                       └ EventListView (band)
```

### New files

| File | Role |
| --- | --- |
| `Sources/MonthPeek/Events/EventItem.swift` | Plain value types: `EventItem`, `CalendarInfo`, `EventColor` (RGBA doubles, so nothing from EventKit or AppKit leaks past the service). |
| `Sources/MonthPeek/Events/EventSchedule.swift` | Pure logic, unit tested: group events by day (multi-day expansion), sort within a day, dot color, selection follow on month change, band height, today's initial scroll anchor. |
| `Sources/MonthPeek/Events/EventStoreService.swift` | Thin `ObservableObject` singleton over `EKEventStore` (main-thread use; the store is created lazily so EventKit is untouched while the feature is off): authorization status, request access, calendar list, fetch a window off the main thread, forward the store-changed notification. Exposes no write methods. |
| `Sources/MonthPeek/Events/EventListView.swift` | The band. |
| `Tests/MonthPeekTests/EventScheduleTests.swift` | Tests for `EventSchedule`. |

### Changed files

| File | Change |
| --- | --- |
| `Resources/Info.plist` | `NSCalendarsFullAccessUsageDescription`. |
| `Preferences/AppSettings.swift` | Keys `showEvents`, `showEventDots`, `hiddenCalendarIDs`; `HiddenCalendars` accessor; `EventsSettings` helper for the "effective" on state. |
| `Preferences/PreferencesView.swift` | New toggles, denied caption, calendar checklist. |
| `Calendar/CalendarViewModel.swift` | `selectedDate`, `eventsByDay`, `eventsEnabled`, `select(_:)`, selection follow in `navigate`, fetch wiring. |
| `Calendar/CalendarView.swift` | `PanelRootView` splits grid/band; `DayCell` gains selection, dot, tap. |
| `Panel/PanelController.swift` | Band-aware frame, min/max, resize save, scroll monitor scoping. |
| `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` | Feature docs, policy amendment, Unreleased entry. |

### Data flow

1. Preferences toggle → `EventStoreService.requestAccess()` → status published.
2. `CalendarViewModel` observes: service status/changes, `UserDefaults`
   changes, its own `displayedMonth`. Any of these triggers `reloadEvents()`,
   which asks the service for the six-week window minus hidden calendars,
   then stores `EventSchedule.group(...)` into `eventsByDay`.
3. `PanelController` observes `eventsEnabled`, `selectedDate`, `eventsByDay`
   and recomputes the band height with `EventSchedule.bandHeight`, adjusting
   the window frame when it changes.
4. `PanelRootView` computes the same band height from its own geometry and
   lays out grid over band. Both sides use one function so they never
   disagree.

### Error handling

- Authorization request throws → treated as denied.
- Fetch runs in a detached task; results are delivered on the main actor and
  dropped if events were disabled meanwhile.
- Missing Info.plist key would crash on request; CI's bundle sanity check
  asserts the key is present.

### Testing

- `EventSchedule` is fully covered: multi-day expansion (inclusive of a
  23:59:59 all-day end, exclusive of an exact-midnight timed end), ordering,
  dot color for single vs mixed calendars, selection follow with clamping
  (Jan 31 → Feb 28), band height for 0, 1, 4, 5 rows.
- EventKit itself is not exercised in tests; CI cannot grant the permission.
- Manual: toggle on → prompt → events appear; deny → caption; uncheck a
  calendar → its events and dots vanish; edit an event in Calendar.app with
  the panel open → row updates; resize → grid height persists; wheel over
  band scrolls, over grid flips month.

## Signing caveat (documented in README)

Ad-hoc signed builds have no stable identity for the privacy database, so
macOS re-asks for calendar access after each update and after each local
rebuild. This is inherent to shipping without a Developer ID.
