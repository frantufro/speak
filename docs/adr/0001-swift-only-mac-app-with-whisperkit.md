# Swift-only macOS app using WhisperKit

speak targets macOS only and is built as a single-language Swift application: SwiftUI/AppKit for all UI surfaces, native macOS APIs for audio (AVAudioEngine), accessibility/paste injection, the global hotkey, and the menu-bar item. The **STT engine** is WhisperKit (Argmax), which runs Whisper on Apple Silicon via MLX/CoreML.

## Considered options

- **Swift-only (chosen)** — One language, one toolchain. WhisperKit is the fastest local Whisper on Apple Silicon (often 2–5× whisper.cpp) and handles model download/caching itself. Reference apps in the Whispr Flow niche (VoiceInk, MacWhisper, Superwhisper) all use this shape, which means a deep pool of working code to learn from.
- **Rust core + Swift shell** — Originally proposed for portability and to keep the engine swappable. Rejected: the only thing Rust would buy us is `whisper-rs`, which is slower than WhisperKit on the only platform we ship to. The FFI tax (UniFFI, two build systems, cross-language debugging) buys nothing for a Mac-only app.
- **Rust-only** — Even harder. macOS-native surfaces (floating overlay near the cursor, AX paste injection, menu bar) are painful via `objc2`, and the STT is slower.
- **`whisper.cpp` directly from Swift** — Viable. Kept as a fallback if WhisperKit's model coverage or licensing ever becomes a problem; the **STT engine** abstraction is small enough that swapping is a one-module rewrite.
- **Apple `SFSpeechRecognizer`** — Rejected for v1 (accuracy lags Whisper, language switching is clunky). Could be a "small machine / offline forever" fallback later.

## Consequences

- **macOS-only.** No Linux/Windows port without rewriting the app. Accepted — this is a personal Mac tool.
- **No free headless CLI.** A `speak-cli` would need to be a separate binary linking WhisperKit, not a re-export of a shared core.
- **iOS port is essentially free** if it's ever wanted — SwiftUI + WhisperKit both run there.
- **The `STT engine` abstraction in CONTEXT.md still applies.** Code outside the engine module should not import WhisperKit types directly, so the fallback to whisper.cpp (or anything else) stays cheap.
