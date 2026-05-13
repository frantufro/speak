# speak

## Development workflow

This project follows the workflow described in [WORKFLOW.md](./WORKFLOW.md) — an opinionated, vertical-slice / tracer-bullet flow built on Matt Pocock's skills (copied into `.claude/skills/`).

Before starting any non-trivial work, read `WORKFLOW.md` to know which skill applies at which phase (discovery → spec → triage → implementation → maintenance).

### Issue tracker: cubil

This project uses [cubil](https://github.com/frantufro/cubil) as its issue tracker. Tasks are markdown files in `.cubil/{backlog,doing,done}/`; roadmaps live in `.cubil/roadmaps/`.

Workflow skills (`to-prd`, `to-issues`, `triage`) publish via the `cubil` CLI:

- `cubil new "<title>" -m "<body>"` — create a task in `backlog/`, prints slug
- `cubil list` / `cubil show <slug>` — inspect
- `cubil start <slug>` / `cubil finish <slug>` — execution state (`backlog → doing → done`)
- `cubil mv <slug> <status>` — non-linear moves
- `cubil roadmap new "<title>" -m "..."` / `cubil roadmap add <roadmap> <task>` — group tasks

**Triage state mapping** (Matt's vocabulary → cubil): cubil's status folders track *execution* state, not triage state. Store triage role in YAML frontmatter on each task:

```yaml
---
category: bug | enhancement
state: needs-triage | needs-info | ready-for-agent | ready-for-human | wontfix
---
```

Newly created tasks default to `state: needs-triage` and live in `.cubil/backlog/`. `wontfix` tasks move to `.cubil/done/`.

**Existing roadmaps**:
- `v1` — the core **Capture → Transcription → Injection** loop per ADR 0004. Contains the PRD and five tracer-bullet slices.
- `v2` — Whispr-Flow-style features deferred from v1 per ADR 0004.

---

## Behavioral guidelines

Adapted from [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md). Bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
