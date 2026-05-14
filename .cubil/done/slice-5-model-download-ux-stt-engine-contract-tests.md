---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# Slice 5: model download UX + STT engine contract tests

## Parent

`v1-core-capture-transcription-injection-loop` (the v1 PRD; in the `v1` cubil roadmap).

## What to build

Two related things: the user-facing UX when a Whisper model needs to be downloaded (first run, or after switching models in Slice 4), and an opt-in fixture-WAV test suite that catches regressions in the `WhisperKitSTTEngine` adapter.

Concretely:

- A model-download flow integrated with `WhisperKitSTTEngine`: when the engine is asked to transcribe but the selected model isn't cached, it downloads first. While downloading:
  - The menu-bar item state text becomes `speak: downloading model… (N%)`.
  - The floating overlay (from Slice 3) shows the same progress.
  - If the user holds the hotkey during a download, the **Capture** is rejected with a toast: "speak is downloading the model. Try again in a moment." (Uses the `ToastPresenter` from Slice 2.)
  - On completion, the menu bar returns to `speak: idle`.
- First-run download is initiated automatically the first time the user finishes onboarding (Slice 2) so they don't have to wait when they try to dictate.
- Errors during download (network failure, disk full, etc.) surface a toast and leave the previously-cached model (if any) selected.
- An opt-in `STTEngineContractTests` suite:
  - Loads `WhisperKitSTTEngine` with a small fast model (e.g. `tiny` or `base`, *not* `large-v3-turbo`, to keep CI-runnable on the author's machine in under a minute).
  - Transcribes a handful of fixture WAV files committed to the repo: one English clip, one Spanish clip, one with silence, one with very short utterance.
  - Asserts: transcripts are non-empty for the speech clips; the silence clip produces an empty or near-empty transcript; the detected **Source language** matches expectation on the language-tagged clips.
  - The suite is **opt-in**: excluded from the default test run, runnable via a separate scheme or an `xcodebuild` argument. Document the invocation in `bin/` or the README.

## Acceptance criteria

- [ ] On first run after onboarding, the selected Whisper model begins downloading automatically. The menu-bar state text shows `speak: downloading model… (N%)`.
- [ ] The floating overlay mirrors the model-download progress when visible.
- [ ] Holding the **Hold-to-talk hotkey** during a model download triggers the "downloading" toast and does not start a **Capture**.
- [ ] Switching models in Settings (Slice 4) to one that isn't cached triggers a download with the same UX.
- [ ] A failed download (simulate by disabling network) surfaces an error toast and leaves the previously-cached model active. The app remains functional with whatever model is cached.
- [ ] The contract test suite runs against fixture WAVs:
  - English clip → transcript contains expected words (case-insensitive substring assertion, not exact match).
  - Spanish clip → transcript contains expected words and detected **Source language** is Spanish.
  - Silence clip → transcript is empty or whitespace.
  - Very short utterance → transcript is non-empty.
- [ ] The contract test suite is not part of the default test run; running `xcodebuild test` without the opt-in flag does not execute it. Documentation explains how to run it.
- [ ] Fixture WAV files are committed to the repo (each under a few hundred KB; if larger, use Git LFS or document a one-shot fetch script).

## Out of scope

- Tuning the default model for accuracy/speed beyond "WhisperKit's `large-v3-turbo` is the v1 default".
- Streaming partial transcriptions during recording (v2 territory).

## Blocked by

- `slice-1-tracer-bullet-end-to-end-loop-minimal-menu-bar-shell` — needs `WhisperKitSTTEngine` and the menu-bar state surface.

## Soft dependencies (this slice is improved by, but not blocked on, the following)

- `slice-2-permissions-onboarding-toast-surface` — needs `ToastPresenter` for the "downloading" and error toasts. If Slice 2 isn't done, the agent can stub a placeholder toast inline and refactor when Slice 2 lands.
- `slice-3-floating-overlay-near-the-cursor` — needs the overlay for mirrored progress. If Slice 3 isn't done, the menu-bar text alone is sufficient for this slice's acceptance criteria.
- `slice-4-settings-window-hotkey-rebinding-model-picker-launch-at-login-auto-detect-toggle` — switching models in Settings is the second download trigger. If Slice 4 isn't done, only the first-run download path needs to work.
