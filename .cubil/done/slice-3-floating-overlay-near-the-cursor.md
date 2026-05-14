---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# Slice 3: floating overlay near the cursor

## Parent

`v1-core-capture-transcription-injection-loop` (the v1 PRD; in the `v1` cubil roadmap).

## What to build

A small floating overlay that gives the user a visual cue near where they're looking while a **Capture** is happening, so they don't have to glance up at the menu bar mid-dictation.

Concretely:

- An `OverlayPresenter` module that owns a borderless, transparent, non-activating `NSWindow` rendered on every desktop and Space. It is click-through (mouse events pass through). It is positioned near the current mouse cursor at the moment the **Capture** starts; if `CGEvent.mouseLocation` is unavailable, fall back to the top-center of the active screen.
- The overlay observes the `CaptureCoordinator` state and renders:
  - **idle** → hidden (window orderOut)
  - **recording** → a small pill/bezel with a live indicator (animated dot or simple level meter — pick whichever lands cleaner)
  - **transcribing** → the same pill with a spinner or "transcribing…" affordance
- The overlay auto-hides shortly (~250 ms) after the coordinator returns to `idle`.
- The overlay does not steal focus and does not appear in the window list / `⌘+Tab`.
- Position can be the cursor at capture-start *or* the top-center fallback; do not chase the cursor mid-capture (the user moves their cursor on purpose).

## Acceptance criteria

- [ ] Holding the **Hold-to-talk hotkey** causes the overlay to appear near the cursor location at press-time within ~100 ms.
- [ ] The overlay reflects `recording` → `transcribing` → `idle` transitions in real time.
- [ ] Releasing the hotkey keeps the overlay visible during transcription, then auto-hides ~250 ms after returning to `idle`.
- [ ] The overlay never steals focus from the underlying app — typing into a focused text field continues to work while the overlay is visible.
- [ ] Clicking through the overlay's bounds does not consume the click — it reaches the underlying app.
- [ ] The overlay appears on the screen where the cursor is, not on the primary display unconditionally.
- [ ] If cursor location is unavailable for some reason, the overlay falls back to the top-center of the active screen and the app does not crash.
- [ ] The overlay is not present in `⌘+Tab` or the Dock and does not appear when taking standard screenshots that exclude system overlays.

## Out of scope

- Configuring overlay position in Settings (Slice 4 owns settings UI; this slice ships with cursor / top-center as the only two positions).
- Theming / dark-mode tuning beyond "looks reasonable in both modes".

## Blocked by

- `slice-1-tracer-bullet-end-to-end-loop-minimal-menu-bar-shell` — needs an observable `CaptureCoordinator` state.
