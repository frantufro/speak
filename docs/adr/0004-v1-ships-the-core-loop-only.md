# v1 ships the core loop only — no post-processing, no translation

v1 of speak is deliberately the minimum thing that earns the name: hold the **Hold-to-talk hotkey**, speak in ES or EN, **Transcription** runs locally via the **STT engine**, and the result is **Injection**'d into the focused field. That's it. Everything else associated with Whispr Flow is deferred.

## What's explicitly out of v1

- **AI cleanup / filler-word removal** ("um", "uh", "like" stripping; grammar smoothing). This is Whispr Flow's signature feature and the most likely thing a future reader will assume was forgotten. It was not. It needs a second model (small local LLM) and a prompt loop, and it doubles project scope.
- **Voice commands** ("new line", "delete that", "period").
- **Custom vocabulary** (names, jargon prompted into the **STT engine**).
- **Translation** (different **Target language** than **Source language**) — already noted in CONTEXT.md as v2.
- **Capture history** (browse past **Captures**).

## Considered options

- **Ship the core loop only (chosen)** — Smallest thing that's useful. Forces us to validate that the **Capture → Transcription → Injection** loop feels good before adding more surface. Lets the **STT engine** abstraction settle.
- **Ship with AI cleanup included** — Better product, but doubles scope, introduces a second model with its own download/quantization/latency questions, and adds a UX question ("preview the cleanup before paste?") that needs a real design pass.
- **Ship with voice commands** — Same shape of trade-off; needs an intent layer parallel to the transcript.

## Consequences

- **v1 may feel "just dictation"** compared to Whispr Flow. Accepted — quality of the core loop matters more than feature parity for a personal tool.
- **The pipeline is designed with a seam after the **STT engine** output** so a post-processing stage (cleanup, translate, voice-command interpreter) can slot in without rewiring upstream.
- **Punctuation and capitalization come free** from Whisper itself, so the v1 output is still readable prose, not raw words.
