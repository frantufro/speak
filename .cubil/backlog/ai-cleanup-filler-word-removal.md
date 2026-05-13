---
created: 2026-05-13
---

# AI cleanup / filler-word removal

Strip 'um', 'uh', 'like', smooth disfluencies post-Transcription. Needs a small local LLM (e.g. Llama 3.2 1B via MLX or Phi-3 mini) and a prompt loop. UX question: preview-before-Injection or always-apply? Latency budget: total Capture→Injection must stay snappy. Slot into the post-STT-engine seam noted in ADR 0004.
