---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# Slice 4: settings window — hotkey rebinding, model picker, launch-at-login, auto-detect toggle

## Parent

`v1-core-capture-transcription-injection-loop` (the v1 PRD; in the `v1` cubil roadmap).

## What to build

A real settings window that lets the user change the things Slice 1 hardcoded. After this slice, the **Hold-to-talk hotkey** is no longer right-Option-only, the model is no longer `large-v3-turbo`-only, and the app can launch on login.

Concretely:

- A Settings window opened from a new "Settings…" item in the menu-bar menu (between the state-text and "Quit speak").
- Four settings sections:
  1. **Hotkey** — a hotkey-capture control. Pressing a key (with optional modifiers) while focus is on the control records the new hotkey. The change applies immediately; `HotkeyMonitor` accepts a runtime rebind without restart. The default remains right-Option. Fn is selectable but the UI shows a small note: "Fn may conflict with Apple Intelligence / built-in dictation."
  2. **Model** — a dropdown of WhisperKit-supported models (at minimum `large-v3-turbo`, `large-v3`, `medium`, `small`). Switching triggers a download if the model is not cached; the menu-bar state updates to reflect the download (UX for this lands in Slice 5; this slice just initiates and persists the choice).
  3. **Launch at login** — a checkbox wired to `SMAppService.mainApp` (modern `ServiceManagement` API, not the deprecated `SMLoginItemSetEnabled`).
  4. **Language** — a single toggle: "Auto-detect language" (default ON). When ON, the **STT engine** detects **Source language** per **Capture**. When OFF, the toggle expands to a language picker — but v1 only ships ES and EN as forced options, and forcing a **Target language** different from **Source language** remains v2. (This reserves the UI slot without doing **Translation**.)
- A `SettingsStore` module backed by `@AppStorage` / `UserDefaults` with typed accessors for each setting. Round-trip tests for each accessor.
- `HotkeyMonitor` exposes a `rebind(_ newCombo: HotkeyCombo)` method; calling it tears down and re-installs the `CGEventTap` cleanly without dropping events from the new combo.

## Acceptance criteria

- [ ] Opening Settings from the menu bar shows a window with the four sections above.
- [ ] Recording a new hotkey in the Hotkey section makes that hotkey active immediately. Right-Option stops working as the **Hold-to-talk hotkey** after the rebind; the new hotkey works.
- [ ] Selecting a new model in the Model dropdown persists the choice across app restarts. The next **Capture** uses the new model.
- [ ] Toggling "Launch at login" actually registers / deregisters `speak` as a login item — verifiable by signing out and back in, or by checking System Settings → General → Login Items.
- [ ] "Auto-detect language" defaults to ON. Turning it OFF surfaces a language picker with ES and EN. The toggle state and picker selection persist.
- [ ] When auto-detect is OFF, the **STT engine** is told which **Source language** to assume; **Target language** remains equal to **Source language** (no **Translation** in v1).
- [ ] All settings persist across app relaunch.
- [ ] `SettingsStore` has round-trip unit tests for hotkey, model, launch-at-login, and language settings (covers typos in `@AppStorage` keys).
- [ ] Rebinding the hotkey while a **Capture** is in flight is handled cleanly — either deferred until the **Capture** ends or rejected with a user-visible message; do not lose the **Capture**.

## Out of scope

- Model download progress UX (Slice 5).
- Overlay position picker (deferred; not in v1).
- Forcing a **Target language** different from **Source language** (v2 — see `translation-target-language-different-from-source` in the `v2` roadmap).

## Blocked by

- `slice-1-tracer-bullet-end-to-end-loop-minimal-menu-bar-shell` — needs `HotkeyMonitor` and the `STTEngine`/`WhisperKitSTTEngine` modules to rebind against.
