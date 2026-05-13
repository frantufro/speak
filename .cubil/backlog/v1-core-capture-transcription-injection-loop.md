---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# v1: The core Capture → Transcription → Injection loop

## Problem Statement

The author wants Whispr-Flow-style dictation on macOS without sending audio to a cloud service. Existing options all have a disqualifying flaw:

- **Whispr Flow / Wispr Flow** — closed-source, cloud-bound, can't run offline, can't be hacked on.
- **macOS built-in dictation** — slow to start, accuracy lags Whisper, language switching is a context-menu trip per **Capture**.
- **VoiceInk / MacWhisper / Superwhisper** — closest in spirit, but each makes opinionated UX choices the author wants to change, and none are a personal codebase he can steer.

The author types in two languages (Spanish, English) all day across native apps, terminals, browsers, and IDEs. He wants to hold a key, speak, and have the text appear in whichever text field has focus — fast, accurate, and entirely local.

## Solution

`speak` is a macOS menu-bar app. The user holds the **Hold-to-talk hotkey** (right-Option by default), speaks, and releases. The **STT engine** (WhisperKit running Whisper on Apple Silicon) transcribes the audio locally. The transcribed text is **Injection**'d into whichever app has focus at injection time, via clipboard-paste-and-restore.

A small floating overlay near the cursor shows live state (idle → recording → transcribing). The menu-bar item mirrors the same state and provides access to settings, model choice, and quit.

v1 ships the **Capture → Transcription → Injection** loop and nothing else. All Whispr-Flow features beyond that (AI cleanup, voice commands, custom vocabulary, **Translation** to a different **Target language**, **Capture** history) are in the v2 roadmap, deliberately deferred per [ADR 0004](./docs/adr/0004-v1-ships-the-core-loop-only.md).

## User Stories

### Hotkey and Capture lifecycle

1. As the user, I want to hold a global hotkey from anywhere on the system, so that I can start a **Capture** without switching apps.
2. As the user, I want the hotkey to default to right-Option, so that I don't have to fight Apple Intelligence or the system dictation hotkey for the Fn key.
3. As the user, I want to remap the **Hold-to-talk hotkey** in settings (including to Fn if I want), so that I can adapt to my own keyboard and muscle memory.
4. As the user, I want press-to-start / release-to-finalize semantics (no toggle mode), so that the lifecycle of a **Capture** is unambiguous and I never end up "stuck in recording".
5. As the user, I want a visible indicator that a **Capture** is active, so that I know my words are being recorded.
6. As the user, I want a **Capture** that runs longer than 3 minutes to be cut off cleanly, so that a forgotten hotkey can't fill my disk or block the app.
7. As the user, I want pressing the hotkey while a previous **Capture** is still transcribing or injecting to be ignored (not queued), so that overlapping presses don't produce garbled output.
8. As the user, I want releasing the hotkey before any audio has been captured (a very short tap) to produce no output and no clipboard manipulation, so that accidental taps are no-ops.

### Transcription

9. As the user, I want **Transcription** to run entirely locally with no network round-trip, so that my audio never leaves my machine.
10. As the user, I want the **STT engine** to auto-detect whether I'm speaking Spanish or English on each **Capture**, so that I don't have to flip a switch every time I switch languages mid-conversation.
11. As the user, I want **Transcription** latency to feel "fast enough to dictate into" — sub-second from release to **Injection** for short **Captures** — so that the loop feels conversational rather than batch.
12. As the user, I want punctuation and capitalization to be inferred by the model (not added by post-processing), so that the output is readable prose.
13. As the user, I want the model to be chosen on first run based on a sensible default (e.g. `large-v3-turbo`), so that the app works out of the box without me reading the WhisperKit docs.
14. As the user, I want to pick a different model in settings, so that I can trade off accuracy and speed on my hardware.
15. As the user, I want models to be downloaded and cached by the **STT engine** itself, so that I don't have to manage model files manually.

### Injection

16. As the user, I want the transcribed text to be **Injection**'d into the app that has focus *at injection time*, not capture time, so that I can move my cursor after speaking and still get the text where I want it.
17. As the user, I want **Injection** to work in any app that accepts ⌘V — native Cocoa, Electron, terminals, browsers, IDEs — so that I don't have a "supported app list" to learn.
18. As the user, I want my clipboard contents to be preserved across an **Injection**, including rich content (images, files, formatted text), so that dictation doesn't destroy whatever I had copied.
19. As the user, I want `speak` to refuse to **Injection** into secure input fields (password fields, etc.) and show a clear toast explaining why, so that I don't lose a transcription into the void.
20. As the user, I want an empty **Capture** (hotkey held but nothing spoken) to skip pasteboard manipulation entirely, so that my clipboard isn't disturbed for no reason.

### UI surfaces

21. As the user, I want a menu-bar item that shows the current state (idle / recording / transcribing), so that I have a persistent reference for what `speak` is doing.
22. As the user, I want a floating overlay near the cursor (or some non-blocking screen location) that mirrors the state, so that I don't have to look up at the menu bar mid-**Capture**.
23. As the user, I want a settings window accessible from the menu bar, so that I can change hotkey, model, and overlay position without touching a config file.
24. As the user, I want a "Quit" item in the menu bar, so that I can close `speak` cleanly.
25. As the user, I want `speak` to launch at login (opt-in), so that it's always there when I want it.

### Permissions and onboarding

26. As the user, I want first-run onboarding to walk me through the macOS permissions `speak` needs (Microphone, Accessibility, Input Monitoring), so that I'm not staring at a silent failure.
27. As the user, I want each permission request to explain *why* `speak` needs it (in plain language, not Apple's stock prompt), so that I trust what I'm granting.
28. As the user, I want `speak` to detect at runtime when a required permission has been revoked and surface a clear "fix this" path, so that I'm not debugging silent failures after a macOS update.

### Installation

29. As the user, I want a `bin/install` script that builds `speak.app` from source and installs it to `/Applications/`, so that I can set up `speak` on my machine without a DMG or App Store.
30. As the user, I want `git pull && bin/install` to be the entire update mechanism, so that there's no auto-updater to babysit.

## Implementation Decisions

### Major modules

The build decomposes into the following modules. The **deep** ones (small interface, rich implementation, stable shape) are the testing priorities.

#### `HotkeyMonitor` (deep)
Listens for the **Hold-to-talk hotkey** globally via `CGEventTap`. Emits `onPress` and `onRelease` callbacks. Encapsulates: modifier-only key handling, debouncing, key-up timing edge cases, hotkey rebinding at runtime. Interface stays tiny (`start()`, `stop()`, two callbacks); implementation is the gnarly bit.

#### `AudioRecorder` (deep)
Captures microphone audio at 16 kHz mono via `AVAudioEngine` while the hotkey is held. Encapsulates: engine setup, format conversion, microphone permission, and the 3-minute hard cap. Interface: `start()` returns an async stream of audio frames; `stop()` returns the accumulated buffer.

#### `STTEngine` (protocol) and `WhisperKitSTTEngine` (implementation) — deep
The abstraction barrier per [ADR 0001](./docs/adr/0001-swift-only-mac-app-with-whisperkit.md). The protocol takes an audio buffer + optional language hint and returns transcribed text plus the detected **Source language**. The implementation owns: model download/caching, MLX/CoreML loading, language auto-detection, punctuation/capitalization (free from Whisper). **Nothing outside this module imports WhisperKit types.**

#### `PasteboardInjector` (deep)
The five-step injection mechanism from [ADR 0002](./docs/adr/0002-injection-via-clipboard-paste-and-restore.md): save full `NSPasteboardItem` array → write transcription → synthesize ⌘V via `CGEvent` → wait ~80ms → restore items. Also owns: `IsSecureEventInputEnabled()` detection and the "won't dictate into secure fields" toast trigger.

#### `CaptureCoordinator` (deep)
The orchestrator. Owns the state machine for a **Capture**:

```
idle ──press──▶ recording ──release──▶ transcribing ──ok──▶ injecting ──done──▶ idle
                                       └─error─▶ error ─────────────────▶ idle
```

Enforces the "ignore new press during in-flight **Capture**" rule from user story 7. Wires together `HotkeyMonitor`, `AudioRecorder`, `STTEngine`, `PasteboardInjector`. Publishes state for UI surfaces to observe.

#### `PermissionsService` (shallow but isolated)
Wraps the AVFoundation / Accessibility / Input Monitoring permission APIs. Drives onboarding and runtime detection of revoked permissions.

#### `MenuBarController` (UI)
The persistent menu-bar item. Reads `CaptureCoordinator` state; provides Settings/Quit menu.

#### `OverlayPresenter` (UI)
The floating overlay near the cursor. Reads `CaptureCoordinator` state.

#### `SettingsStore`
`@AppStorage`-backed user defaults: hotkey choice, model, overlay position, launch-at-login, language preference (auto-detect by default; future-proof slot for forcing a **Source language**).

#### `OnboardingFlow` (UI)
First-run wizard for the three permissions. Re-entrant from settings.

#### `bin/install`
Shell script: `xcodebuild` the app, `cp -R` it to `/Applications/`. No code signing, no notarization, no DMG (per [ADR 0003](./docs/adr/0003-personal-use-no-distribution.md)).

### Key interface shapes

- `STTEngine` is a Swift `protocol`. A `FakeSTTEngine` (returns a canned transcript) makes `CaptureCoordinator` fully testable without loading a real model.
- `PasteboardInjector` takes an `NSPasteboardProtocol`-style seam so the save/restore semantics can be tested against an in-memory fake.
- `CaptureCoordinator` exposes its state as a Combine `Published` or `Observable` so both `MenuBarController` and `OverlayPresenter` consume the same source of truth without polling.

### Architectural decisions inherited from ADRs

- **Swift-only, WhisperKit as the STT engine** ([ADR 0001](./docs/adr/0001-swift-only-mac-app-with-whisperkit.md)).
- **Clipboard-paste-and-restore for injection** ([ADR 0002](./docs/adr/0002-injection-via-clipboard-paste-and-restore.md)).
- **Personal-use install, no distribution apparatus** ([ADR 0003](./docs/adr/0003-personal-use-no-distribution.md)).
- **Core loop only in v1** ([ADR 0004](./docs/adr/0004-v1-ships-the-core-loop-only.md)).

### Settings persistence

- `UserDefaults` via `@AppStorage`. No custom serialization layer. Settings: hotkey keycode + modifier mask, model name, overlay position, launch-at-login bool, auto-detect-language bool.

### Concurrency

- The **STT engine** runs on a background `Task`; **Injection** hops back to the main actor to touch `NSPasteboard` and synthesize the CGEvent.
- One in-flight **Capture** at a time (enforced by `CaptureCoordinator`); the press event is dropped if state != `idle`.

## Testing Decisions

### What makes a good test here

Tests exercise the **public interface** of a module against realistic inputs and assert observable outcomes. They should not pin the test to a specific call sequence or internal helper. A test that survives an internal rewrite is a good test; a test that breaks every time you refactor is testing implementation, not behavior.

For UI surfaces (`MenuBarController`, `OverlayPresenter`, `OnboardingFlow`), the cost-to-value of automated tests in v1 is poor — they're shallow wrappers around state, and breakage is obvious on first launch. Skip them in v1.

### Modules with tests in v1

- **`CaptureCoordinator`** — highest-value target. Test the state machine end-to-end with fakes for `HotkeyMonitor`, `AudioRecorder`, `STTEngine`, `PasteboardInjector`. Cover: happy path, overlapping presses, empty **Capture**, STT failure, injection failure, secure-input refusal, 3-minute cap.
- **`PasteboardInjector`** — test save/restore semantics with an in-memory pasteboard fake. Cover: text restored, image restored (rich content), no-write on empty input, secure-input short-circuit.
- **`STTEngine` contract** — a small suite of integration tests that load the real WhisperKit engine against a few fixture WAV files and assert the transcript is non-empty and language detection is plausible. These are slow; mark them as an opt-in suite, not part of the default test run.
- **`SettingsStore`** — trivial round-trip tests, mostly to prevent typos in key names.

### Modules without tests in v1

- `HotkeyMonitor` — `CGEventTap` is hostile to unit testing. Validated by hand at runtime.
- `AudioRecorder` — same reason. Validated against the real microphone during dogfooding.
- `PermissionsService` — wraps Apple APIs; the only logic worth testing is "we asked, we got an answer, we acted on it" which is shallow.
- All UI modules — see above.

### Prior art

There is no prior art in this codebase — `speak` is greenfield. Reference shapes from the WhisperKit example projects (for STT engine wiring) and from VoiceInk / MacWhisper (open-source, MIT/Apache) for the menu-bar + overlay scaffolding. WhisperKit's own test suite is the model for how to write fixture-based STT contract tests.

## Out of Scope

Explicitly deferred to v2 (tracked in the `v2` roadmap in cubil, sourced from [ADR 0004](./docs/adr/0004-v1-ships-the-core-loop-only.md)):

- **AI cleanup / filler-word removal** ("um", "uh", "like" stripping; grammar smoothing). Requires a second local model and a prompt loop.
- **Voice commands** ("new line", "delete that", "period"). Requires an intent layer parallel to the transcript.
- **Custom vocabulary** (names, jargon prompted into the **STT engine**).
- **Translation** — forcing a **Target language** different from the **Source language**. Requires the seam after STT output to wire in a translation step.
- **Capture history** — browsing past **Captures**.

Also out of scope (not even v2):

- Linux/Windows port. macOS-only per [ADR 0001](./docs/adr/0001-swift-only-mac-app-with-whisperkit.md).
- Headless CLI. Would need its own binary linking WhisperKit; not free from the GUI codebase.
- App Store distribution. Structurally impossible due to sandboxing per [ADR 0003](./docs/adr/0003-personal-use-no-distribution.md).
- Code signing / notarization / DMG / Sparkle. Personal-use install only.
- Cloud-backed STT, telemetry, crash reporting. No audio or usage data leaves the machine.

## Further Notes

- The **STT engine** abstraction is the single most important seam in the codebase. Treat the WhisperKit import as a build dependency of one module only; everything upstream consumes `STTEngine` via the protocol. This is what lets the post-processing seam (v2: cleanup, translate, voice-command interpreter) slot in cleanly.
- "Quality of the core loop matters more than feature parity with Whispr Flow." If v1 dictation feels great in Spanish + English across the apps the author actually uses (browser, IDE, terminal, Slack, Notes), it ships. Feature breadth comes in v2.
- The 3-minute **Capture** cap is a safety belt, not an intended use. The expected **Capture** duration is 2–20 seconds.
- The first agent to pick this up should start with a **tracer-bullet vertical slice**: minimum end-to-end loop (hotkey → record 1s → run STT → paste). Get one transcribed word into a focused TextEdit window before building the menu bar, overlay, settings, or onboarding. Per [WORKFLOW.md](./WORKFLOW.md), `/to-issues` against this PRD will produce that slice plan.
