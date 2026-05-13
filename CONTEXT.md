# speak

A macOS dictation app inspired by Whispr Flow. The user presses a global hotkey, speaks, and the transcribed text is injected into the currently focused text field. Speech-to-text runs on a local model — no audio leaves the machine.

## Language

**Capture**:
One press-hold-release cycle of the hotkey, producing an audio clip that is transcribed and injected. The unit of work in the app.
_Avoid_: session, dictation, flow, recording, utterance.

**Transcription**:
Converting a **Capture**'s audio into text in the same language as was spoken (**Source language** = **Target language**).
_Avoid_: STT, speech-to-text (use only when referring to the engine/model layer).

**Translation**:
Converting a **Capture**'s audio into text in a language different from the one spoken (**Source language** ≠ **Target language**). Out of scope for v1.
_Avoid_: localization, conversion.

**Injection**:
The act of placing the final text into whichever text field has focus at injection time. v1 uses clipboard-paste-and-restore (write text to pasteboard → synthesize ⌘V → restore previous pasteboard contents).
_Avoid_: paste, type, output, send.

**Source language**:
The language the user is speaking during a **Capture**.
_Avoid_: input language, spoken language.

**Target language**:
The language the injected text should be in. In v1 this is always equal to **Source language**; v2 introduces user-selectable targets via **Translation**.
_Avoid_: output language, destination language.

**Hold-to-talk hotkey**:
The global keyboard shortcut the user holds down for the duration of a **Capture**. Press = start, release = finalize. No toggle mode.
_Avoid_: push-to-talk, PTT, trigger key.

**STT engine**:
The local speech-to-text pipeline: WhisperKit (Argmax) running a Whisper model on Apple Silicon via MLX/CoreML. Implementation layer only — the rest of the app talks to it through a small interface and never imports WhisperKit types directly.
_Avoid_: model, ASR, recognizer (when referring to the abstraction).

## Relationships

- A **Capture** has one **Source language** and produces text in one **Target language**.
- A **Capture** ends with **Injection** into the app that has focus at injection time.
- The **STT engine** is the only component that knows about WhisperKit; everything upstream consumes its output as plain text plus a **Source language** tag.
- **Transcription** and **Translation** are the two modes a **Capture** can run in. v1 only supports **Transcription**.

## Example dialogue

> **Dev:** "When the user releases the hotkey, do we start a new **Capture** if they press it again immediately?"
> **Domain expert:** "No — one **Capture** at a time. If the previous one's **Transcription** hasn't finished injecting, the new press is ignored (or queued — we'll decide). The **Hold-to-talk hotkey** semantics make overlap nonsensical anyway."
>
> **Dev:** "What if the focused app changes between the start of a **Capture** and **Injection**?"
> **Domain expert:** "**Injection** targets whatever has focus at injection time, not capture time. The user moved their cursor on purpose."

## Flagged ambiguities

- "language" was being used to mean both **Source language** and **Target language** — resolved by always qualifying which one.
- "session" was avoided in favour of **Capture** because session is overloaded (auth, HTTP, app lifecycle).
