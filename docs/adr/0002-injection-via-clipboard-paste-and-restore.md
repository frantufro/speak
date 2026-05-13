# Injection via clipboard-paste-and-restore

**Injection** writes transcribed text to `NSPasteboard.general`, synthesizes a ⌘V via CGEvent, waits ~80ms for the target app to consume the paste, then restores the previous pasteboard contents (preserving all `NSPasteboardItem` types, not just strings).

## Considered options

- **Clipboard paste-and-restore (chosen)** — Works in every app that accepts ⌘V: Electron apps, terminals, native Cocoa fields, web inputs in browsers, IDEs. One injection mechanism for every target. Implementation is a few hundred lines.
- **Synthesize keystrokes for each character** — Looks "cleaner" but is meaningfully worse in practice. Slow for long transcripts (one CGEvent per glyph), wrong with international keyboard layouts (CGEvent uses virtual keycodes that map differently per layout — "ñ" on a US layout becomes garbage), breaks dead keys, fails on Unicode the layout can't produce. Rejected.
- **Accessibility API direct text insertion** (`AXUIElementSetAttributeValue` on the focused element's `kAXValueAttribute`) — In theory the cleanest path. In practice: most apps don't implement the writable text attribute, results are inconsistent across Cocoa/Electron/web, and we'd still need a fallback. Rejected as primary; possible future enhancement for the apps where it works.
- **Apple Events / scripting** — App-specific, only works for scriptable apps, fragile. Rejected.

## Consequences

- **Secure input blocks Injection.** If `IsSecureEventInputEnabled()` returns true (any password field is focused, or some terminal modes), synthesized ⌘V is dropped silently. We detect this before injecting and show a toast: "speak won't dictate into secure fields." Accepted trade-off.
- **Clipboard restore race.** If the user copies something during the ~80ms paste window, our restore overwrites it. The window is small but not zero. Lived with for v1; documented as a known limitation.
- **Apps that don't respond to ⌘V silently fail.** Some terminals in raw mode, some games, some kiosk apps. Documented limitation.
- **Empty transcripts don't touch the pasteboard.** If the user holds the hotkey and says nothing, we skip pasteboard manipulation entirely — no clipboard wipe-and-restore for no reason.
- **Rich clipboard contents survive.** We restore via `NSPasteboardItem` arrays, not just `string(forType: .string)`, so a copied image or file URL is preserved across an Injection.
