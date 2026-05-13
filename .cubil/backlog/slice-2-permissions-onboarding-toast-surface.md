---
created: 2026-05-13
category: enhancement
state: ready-for-agent
---

# Slice 2: permissions onboarding + toast surface

## Parent

`v1-core-capture-transcription-injection-loop` (the v1 PRD; in the `v1` cubil roadmap).

## What to build

Make `speak` survive its first launch and the macOS permissions dance gracefully, and give it a generic toast surface for runtime messages — starting with the "won't dictate into secure fields" message that Slice 1 left logging to stderr.

Concretely:

- A first-run onboarding window that walks the user through the three permissions `speak` needs, one at a time:
  - **Microphone** (AVAudioSession / `AVCaptureDevice.requestAccess(for: .audio)`)
  - **Accessibility** (the system pane; we can detect grant status via `AXIsProcessTrusted()` and deep-link to the Privacy pane)
  - **Input Monitoring** (also Privacy pane; required for the global `CGEventTap`)

  Each step explains in one or two plain-language sentences *why* `speak` needs that permission. No copy-pasted Apple boilerplate.

- A `PermissionsService` module that exposes `current() -> PermissionsStatus` and `request(_ kind: PermissionKind, completion: ...)`. It also publishes status changes so the rest of the app can react when a permission is revoked at runtime.

- Runtime revocation handling: if any required permission is missing when the user holds the hotkey, the **Capture** does not start. Instead, the menu-bar item surfaces a "Permissions needed" entry that re-opens the onboarding window at the relevant step.

- A generic `ToastPresenter` — a small, transient floating bezel (or `NSWindow`-based overlay; reuse `NSUserNotification` only if it fits) capable of displaying short messages in the bottom-right of the active screen. It is **not** a notification-center notification. It must be visible for a few seconds and dismissable.

- Wire Slice 1's secure-input detection to the `ToastPresenter` with the message: **"speak won't dictate into secure fields."** Slice 1's stderr log is replaced by this toast.

## Acceptance criteria

- [ ] On first launch (no permissions previously granted), an onboarding window appears with a step for each of Microphone, Accessibility, and Input Monitoring.
- [ ] Each onboarding step shows a plain-language rationale (not the macOS stock prompt text) explaining why `speak` needs that permission.
- [ ] Granting all three permissions dismisses the onboarding window and shows the menu-bar `speak: idle` state. The app is fully usable from that point without restart.
- [ ] If the user dismisses onboarding without granting a permission, the menu-bar item shows a "Permissions needed" entry that re-opens onboarding at the missing permission's step.
- [ ] If the user revokes a permission via System Settings while `speak` is running, the next attempted **Capture** does not start; the menu-bar item updates to "Permissions needed".
- [ ] Holding the **Hold-to-talk hotkey** while a password field is focused triggers a toast in the bottom-right of the active screen with the text "speak won't dictate into secure fields." Slice 1's stderr log is no longer emitted for this case.
- [ ] The toast auto-dismisses after a few seconds and can be manually dismissed by clicking it.
- [ ] The toast surface is generic — `ToastPresenter.show(_ text: String)` can be called from anywhere in the app, not just the secure-input path.
- [ ] `PermissionsService` is tested for the "we asked, we got an answer, we acted on it" flow with a fake permissions provider. UI tests are skipped per the v1 testing decisions in the PRD.

## Blocked by

- `slice-1-tracer-bullet-end-to-end-loop-minimal-menu-bar-shell` — needs the menu-bar shell and the secure-input detection hook.
