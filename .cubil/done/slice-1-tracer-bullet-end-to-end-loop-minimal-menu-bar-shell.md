---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# Slice 1: tracer-bullet end-to-end loop + minimal menu bar shell

## Parent

`v1-core-capture-transcription-injection-loop` (the v1 PRD; in the `v1` cubil roadmap).

## What to build

The first end-to-end vertical slice of `speak`. After this slice ships, the author can run `bin/install`, hold right-Option in TextEdit, speak, release, and see his words land in the focused text field. No settings, no overlay, no onboarding wizard — just the loop and the smallest possible Mac app to host it.

Concretely:

- A macOS menu-bar app target (no Dock icon; `LSUIElement = YES`) built with SwiftUI/AppKit.
- A `bin/install` script that runs `xcodebuild` and copies the `.app` to `/Applications/`. Per [ADR 0003](../docs/adr/0003-personal-use-no-distribution.md), no signing, no notarization, no DMG.
- A menu-bar item whose title text mirrors the current state: `speak: idle`, `speak: recording`, `speak: transcribing`. Icon design is out of scope for this slice. The menu has a single "Quit speak" item.
- A `HotkeyMonitor` module that watches for the **Hold-to-talk hotkey** (hardcoded to right-Option for this slice) via `CGEventTap`. Emits `onPress` and `onRelease`.
- An `AudioRecorder` module that captures microphone audio at 16 kHz mono via `AVAudioEngine` between press and release, with a hard 3-minute cap that cleanly cuts the **Capture** and forwards what was captured so far.
- An `STTEngine` Swift protocol, plus a `WhisperKitSTTEngine` implementation that loads a hardcoded `large-v3-turbo` model and returns transcribed text + detected **Source language**. Per [ADR 0001](../docs/adr/0001-swift-only-mac-app-with-whisperkit.md), no code outside this module imports WhisperKit types.
- A `PasteboardInjector` module that performs the five-step clipboard-paste-and-restore from [ADR 0002](../docs/adr/0002-injection-via-clipboard-paste-and-restore.md): save the full `NSPasteboardItem` array → write the transcription → synthesize ⌘V via `CGEvent` → wait ~80ms → restore the items. It must:
  - Preserve rich content (images, file URLs, formatted text), not just strings.
  - Skip pasteboard manipulation entirely if the transcription is empty.
  - Detect `IsSecureEventInputEnabled()` before injecting; if true, log to stderr and skip the injection. (The user-facing toast for this case is wired in Slice 2.)
- A `CaptureCoordinator` that wires the above modules into the **Capture** state machine:

```
idle ──press──▶ recording ──release──▶ transcribing ──ok──▶ injecting ──done──▶ idle
                                       └─error─▶ error ─────────────────▶ idle
```

  And enforces the overlap rule: a hotkey press received while state ≠ `idle` is dropped (not queued).

- A pasteboard seam so `PasteboardInjector` can be tested against an in-memory fake.
- A fake `STTEngine` for tests.

## Acceptance criteria

- [ ] `bin/install` builds and installs `speak.app` to `/Applications/`. The script is idempotent — re-running it pulls the latest build and replaces the installed app.
- [ ] Launching `speak.app` produces a menu-bar item with title `speak: idle` and a working "Quit speak" item; no Dock icon appears.
- [ ] Holding right-Option starts a **Capture**; releasing it ends the **Capture**. The menu-bar state text transitions `idle → recording → transcribing → idle` over the lifecycle.
- [ ] With TextEdit focused, holding right-Option, speaking "hello world" in English, and releasing causes "hello world" (or a close transcription) to appear at the TextEdit cursor.
- [ ] The same flow works with Spanish input — the **STT engine** auto-detects the **Source language** and returns Spanish text.
- [ ] Holding right-Option without speaking (empty **Capture**) leaves the clipboard untouched. Verify by copying an image first, holding the hotkey silently, releasing — image is still on the clipboard.
- [ ] Whatever was on the clipboard before a non-empty **Capture** is restored after **Injection**. Verify with a copied image, then a normal **Capture**: the transcription gets injected, then the image is back on the clipboard.
- [ ] Holding the hotkey for more than 3 minutes cleanly cuts the **Capture** at the 3-minute mark and transcribes what was captured up to that point.
- [ ] Pressing right-Option a second time while a **Capture** is still transcribing or injecting is ignored (no garbled or queued output).
- [ ] Attempting to dictate into a focused password field is detected via `IsSecureEventInputEnabled()` and silently skipped (no synthesized ⌘V), with a log line written to stderr. The toast UI is intentionally deferred to Slice 2.
- [ ] Tests cover `CaptureCoordinator` end-to-end with fakes: happy path, overlap rule, empty **Capture**, STT failure, 3-minute cap, secure-input refusal.
- [ ] Tests cover `PasteboardInjector` against an in-memory pasteboard fake: text restored, rich content (image) restored, no-write on empty input, no-paste on secure-input.
- [ ] Build succeeds with no warnings; tests pass.

## Out of scope for this slice (lands in later slices)

- The user-facing toast for secure-input refusal (Slice 2).
- Permissions onboarding wizard and runtime revocation handling (Slice 2).
- Floating overlay near the cursor (Slice 3).
- Settings window, hotkey rebinding, model picker, launch-at-login, language toggle (Slice 4).
- Model-download progress UX and STT contract test suite (Slice 5).

## Blocked by

None — can start immediately.
