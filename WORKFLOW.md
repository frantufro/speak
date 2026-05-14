# Product Development Workflow

This project uses a curated subset of [Matt Pocock's skills](https://github.com/mattpocock/skills), copied into `.claude/skills/`. The skills are not independent — they compose into a single, opinionated workflow for shipping product changes with AI agents.

## Cross-cutting concepts

Three ideas run through every skill:

- **Vertical slices / tracer bullets** — always cut end-to-end (schema → API → UI → tests), never horizontally by layer.
- **HITL vs AFK** — explicitly mark whether a piece of work needs a human (architecture call, design review) or can be completed by an autonomous agent alone. Prefer AFK.
- **`CONTEXT.md` (domain glossary) + `docs/adr/` (decisions)** — most skills read and update these files inline so vocabulary stays consistent and decisions don't get re-litigated.

## The five phases

### 1. Discovery & design

- **`grill-me`** — the agent interviews you about the plan, one question at a time, walking the full decision tree until everything is resolved.
- **`grill-with-docs`** — same but stronger: challenges your wording against the existing glossary and ADRs, sharpens fuzzy terms, and updates `CONTEXT.md` inline as decisions crystallize.
- **`prototype`** — throwaway code that answers a specific question. Two branches: a tiny interactive terminal app for state/logic questions, or several radically different UI variations on one route. Throwaway from day one.

### 2. Specification

- **`to-prd`** — turns the current conversation into a PRD (problem, solution, user stories, implementation decisions, testing decisions, out of scope) and publishes it to the issue tracker with the `ready-for-agent` label. Calls out **deep modules** (small interface, rich implementation) that should be tested in isolation.

### 3. Triage & breakdown

- **`to-issues`** — takes a PRD or plan and breaks it into **tracer-bullet vertical-slice issues**. Each issue is HITL or AFK, with explicit blockers. Iterates with you on granularity before publishing.
- **`triage`** — a small state machine for incoming issues. Every issue carries one category (`bug` / `enhancement`) and one state (`needs-triage` → `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`). For bugs: **always reproduce before grilling**.

### 4. Implementation

- **`tdd`** — red-green-refactor, but **vertical**: one test → its implementation → next test. Never "write all tests, then all code" — that produces tests coupled to imagined behavior. Tests are integration-style, exercising the public interface; they should survive internal refactors.
- **`diagnose`** — disciplined loop for hard bugs:
  1. **Build a feedback loop** (this is the skill — everything else is mechanical)
  2. Reproduce
  3. Generate 3–5 ranked, falsifiable hypotheses
  4. Instrument with `[DEBUG-xxxx]` prefixed logs
  5. Write the regression test → apply the fix
  6. Cleanup + post-mortem (state the winning hypothesis in the commit/PR)

### 5. Maintenance & continuity

- **`improve-codebase-architecture`** — finds **deepening opportunities**: shallow modules whose interface is nearly as complex as their implementation. Uses the deletion test ("if I deleted this module, would complexity vanish or reappear across N callers?") and a fixed vocabulary: module, interface, seam, adapter, depth, leverage, locality.
- **`zoom-out`** — when entering unfamiliar code, ask for a higher-level map of the relevant modules and callers (using the project's domain glossary).
- **`handoff`** — compact the current conversation into a handoff document so a fresh session can continue without re-discovering context.
- **`write-a-skill`** — when you spot a repeatable pattern in your own work, package it as a new skill (kept under `.claude/skills/`).

## Happy-path flow

```
grill-me / grill-with-docs   ──┐
       │                        ├─→  to-prd  ──→  to-issues  ──→  triage (per issue)
       └─ prototype (optional)─┘                                        │
                                                                        ▼
                                       (for each AFK issue)            tdd
                                                                        │
                                       (if a bug appears)          diagnose
                                                                        │
                                       (periodically)  improve-codebase-architecture
                                                                        │
                                       (when switching sessions)    handoff
```

## Underlying philosophy

An agent should be able to pick up any issue labeled `ready-for-agent` and complete it end-to-end without further context. The glossary, ADRs, vertical slices, and deep modules exist to make that possible.

## First-time setup

Before invoking any of the skills that publish to an issue tracker (`to-prd`, `to-issues`, `triage`), the project needs a one-time configuration step (issue tracker, triage label vocabulary, documentation locations). Matt's repo ships a `setup-matt-pocock-skills` skill for this, but it was intentionally excluded from this project — configure those settings manually, or pull the skill from upstream:

```bash
curl -L https://github.com/mattpocock/skills/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=3 -C .claude/skills/ \
    skills-main/skills/engineering/setup-matt-pocock-skills
```

To refresh the existing skills from upstream, re-run the equivalent extraction for each skill folder.

## STT Engine Contract Tests

The `STTContractTests` target contains end-to-end tests that run `WhisperKitSTTEngine` against
real fixture WAV files. They are **excluded from the default `swift test` run** to keep CI fast.

### Running the contract tests

```bash
# 1. Fixture WAVs are committed to Tests/STTContractTests/Fixtures/.
#    If they're missing (e.g. after a fresh clone with LFS not initialised),
#    regenerate them (requires macOS + ffmpeg):
bin/fetch-test-fixtures

# 2. Run with the opt-in flag and a target filter:
SPEAK_CONTRACT_TESTS=1 swift test --filter STTContractTests
```

The tests use the `openai_whisper-tiny` model (~75 MB). WhisperKit downloads it on first run
and caches it locally. Subsequent runs use the cache and complete in under a minute.

### What the tests assert

| Test | Fixture | Assertion |
|------|---------|-----------|
| `test_englishClip_containsExpectedWords` | `english.wav` | Transcript contains "weather", "sun", or "today" |
| `test_spanishClip_containsExpectedWordsAndDetectedLanguageIsSpanish` | `spanish.wav` | Transcript contains Spanish words; `sourceLanguage == .spanish` |
| `test_silenceClip_producesEmptyOrNearEmptyTranscript` | `silence.wav` | Transcript is ≤ 10 characters |
| `test_shortUtterance_producesNonEmptyTranscript` | `short.wav` | Transcript is non-empty |
