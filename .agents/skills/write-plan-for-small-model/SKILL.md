---
name: write-plan-for-small-model
description: Use a large model to write a verify-driven implementation plan that a small/weak model can execute step by step. Each task is a "quick verify" unit with its own code piece, a verify harness, and a single entry point; the plan is finished only when every verify passes. The skill is recursive — when executing a task that is still too large or too vague, call this skill again to split that task into smaller verify units. Use when (0) the user explicitly invokes it, (1) a task is too large for a small model to finish in one pass, or (2) the process is not clear enough for a small model to execute reliably.
---

# Write Plan For Small Model

## Overview

Two models split the work. A **large model** (you, when writing) thinks hard, designs, and produces a plan. A **small model** (the executor) does the typing, runs commands, and reports pass/fail. The small model cannot infer intent, cannot fill gaps, and cannot recover from ambiguity. Your job is to remove every decision from the executor's path.

The unit of the plan is the **quick verify**: a small slice of work that ends in a single command the executor runs to get an unambiguous PASS or FAIL. Decompose the whole task into quick-verify units. **The plan is finished when every verify passes — nothing more, nothing less.**

**Announce at start:** "I'm using the write-plan-for-small-model skill to write a verify-driven plan."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md` (user preference overrides this).

## The Quick Verify Unit

Every task in the plan is exactly one quick verify. A quick verify has four parts, and all four must be written out in full:

1. **Code piece** — the complete code the executor writes or changes. Show it verbatim. No "implement X", no diffs the executor must reconstruct.
2. **Verify framework** — the harness that runs the check. A pytest test, an assert script, a curl + grep, a `python -c "..."`, a CLI invocation with expected stdout. Pick whatever is fastest to set up. It does not have to be a unit-test framework.
3. **Verify entry point** — the single exact command the executor runs. One command. Copy it verbatim.
4. **Expected result** — what PASS looks like and what FAIL looks like, in concrete terms (exact string, exit code, file contents).

If you cannot write all four parts concretely, the unit is not ready. Either you split it further or you research until you can.

### Quick verify, not heavy testing

The goal is a fast, direct check that the slice works — not test-design perfection. When the real process is long (a pipeline, a multi-stage flow), **write the direct process end to end first, then verify it by running it and debugging**, rather than mocking every layer. Prefer:

- A runnable script over an abstract test when the flow is sequential.
- One assert at the meaningful output over many asserts on internal state.
- `print` + `grep` + eyeball-able output when that is the fastest unambiguous signal.

Keep each verify under a few minutes of executor time.

## Decomposition

Split the whole task into quick-verify units. Split along whichever boundary is cleaner:

- **Business-meaningful** boundaries — one user-facing capability per unit (e.g. "upload a file", "list files", "delete a file").
- **Code-meaningful** boundaries — one module / function / interface per unit (e.g. "parser", "validator", "writer").

Each unit must be independently verifiable: its entry point runs and passes without later units existing. When units depend on each other, write an **Interfaces** block (see template) so the executor knows the exact names and types a neighboring unit produces, without reading that unit.

## Recursion — docs as function calls

This skill calls itself, and **the calling convention is documents**. The mapping is strict:

- **One skill call = one doc.** Every invocation of this skill produces exactly one plan doc. Nothing more.
- **A task refers to its child doc.** When a unit is split, the parent unit links *down* to the child doc that splits it — this is the call.
- **The child doc refers back to its caller.** The child doc's header links *up* to the parent doc and the exact parent unit it expands — this is the return address.
- **Return = the parent unit passes when the child doc is finished.** A child doc is "finished" when every verify in it passes. At that moment the parent unit's verify is expected to pass. The parent unit's checkbox stays unchecked until then.

Think of each doc as a function body, each unit as a statement, and a split unit as a call into another function that returns control (and a PASS) to the line that called it.

**Split a unit (make the call) when any of these is true:**

- **Too large** — the small model cannot finish the unit's code piece in one pass.
- **Too vague** — the process is not clear enough for the small model to execute without guessing.
- **The user asks** — explicit invocation.

### Calling convention

When splitting Unit N of `docs/plans/2026-06-28-feature.md`:

1. Write the child doc to `docs/plans/2026-06-28-feature--unit-N.md`.
2. In the **parent unit**, add the call link:
   > **Split into:** `docs/plans/2026-06-28-feature--unit-N.md` — this unit's verify passes when that doc is finished.
3. In the **child doc header**, add the return link:
   > **Called by:** `docs/plans/2026-06-28-feature.md` → Unit N. When every verify here passes, return and check Unit N's box.

```
docs/plans/2026-06-28-feature.md          (call: write-plan-for-small-model)
├── Unit 1
├── Unit 2  ──call──▶  docs/plans/2026-06-28-feature--unit-2.md
│   ▲                  ├── Unit 2.1  (verify ✓)
│   │                  ├── Unit 2.2  (verify ✓)
│   └──── return ──────┴── Unit 2.3  (verify ✓)  all pass ⇒ Unit 2 box checked
├── Unit 3
└── Unit 4, Unit 5

A child doc may call again: Unit 2.2 ──call──▶ ...--unit-2-2.md, same convention.
```

## Writing for a small model

The executor is literal. Hold to these or the plan fails in execution:

- **Exact file paths**, every time. No "the config file".
- **Complete code in every step.** If a step changes code, the full code is in the step. Never "similar to Unit 2" — repeat it; the executor may read units out of order.
- **One action per step** (2–5 min): write code → run verify (expect fail) → fix → run verify (expect pass) → commit.
- **Exact commands with expected output.** The executor copies them; it does not compose them.
- **No placeholders.** Banned: "TBD", "TODO", "add error handling", "handle edge cases", "write tests for the above", any reference to a function/type not defined in some unit.
- **No decisions left open.** If there is a choice (library, name, path), you make it now and write it down.

## Plan Document Header

Every plan starts with this header:

```markdown
# [Feature Name] — Plan for Small Model

> **Executor:** Run units top to bottom. Each unit ends in one verify command.
> Check the box only when that command shows the expected PASS.
> If a unit is too large or too vague to execute, STOP and invoke the
> `write-plan-for-small-model` skill on that unit to split it further.

> **Called by:** [top-level plan: "none". Child doc: `docs/plans/<parent>.md` → Unit N.
> When every verify here passes, return and check Unit N's box in the parent.]

**Goal:** [one sentence]

**Architecture:** [2–3 sentences]

**Tech Stack:** [key tools / libraries]

## Global Constraints

[Project-wide rules — version floors, dependency limits, naming/copy rules,
platform requirements — one line each, exact values copied verbatim.
Every unit implicitly includes these.]

## Done Definition

The plan is finished when every verify below shows PASS. No other criteria.

---
```

## Unit Template

````markdown
### Unit N: [Name]  (business | code)

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:120-145`
- Verify: `tests/exact/path/to/verify_n.py`

**Interfaces:** (only if other units depend on this one)
- Consumes: [exact signatures this unit uses from earlier units]
- Produces: [exact function names, params, return types later units rely on]

**Recurse if:** the code piece below is too large to finish in one pass, or any
step is unclear. Then invoke `write-plan-for-small-model` on this unit, and add:
> **Split into:** `docs/plans/<this-plan>--unit-N.md` — this unit's verify passes
> when that child doc is finished. Keep this box unchecked until then.

- [ ] **Step 1 — Code piece.** Write this file exactly:

```python
def parse_line(line: str) -> dict:
    key, _, value = line.partition("=")
    return {"key": key.strip(), "value": value.strip()}
```

- [ ] **Step 2 — Verify framework.** Write the harness exactly:

```python
# tests/test_parse_line.py
from app.parser import parse_line

def test_parse_line():
    assert parse_line("a = 1") == {"key": "a", "value": "1"}
```

- [ ] **Step 3 — Verify entry point.** Run this one command:

```bash
uv run pytest tests/test_parse_line.py -v
```

- [ ] **Step 4 — Expected result.**
  - PASS: output contains `1 passed`, exit code 0.
  - FAIL: `ModuleNotFoundError` or `assert` mismatch — fix the code piece, rerun.

- [ ] **Step 5 — Commit.**

```bash
git add app/parser.py tests/test_parse_line.py
git commit -m "feat: parse_line key=value"
```
````

## Self-Review

After writing the plan, re-read the spec with fresh eyes and check:

1. **Coverage** — every spec requirement maps to a unit. List gaps; add units for them.
2. **Verifiability** — every unit has all four parts (code piece, framework, entry point, expected result) written concretely. No unit is "describe-only".
3. **Placeholders** — scan for the banned patterns above; replace with real content.
4. **Type consistency** — names/signatures used in later units match what earlier units' Interfaces blocks produce (`clearLayers()` in Unit 3 must not become `clearFullLayers()` in Unit 7).
5. **Small-model readiness** — for each unit, ask: could a literal executor that knows nothing about this project run this without a decision? If not, make the decision or recurse.

Fix issues inline.

## Execution Handoff

After saving, tell the user:

"Plan saved to `docs/plans/<filename>.md`. Hand it to the small model and run units top to bottom. Each unit ends in one verify command — check the box on PASS. If the executor hits a unit that is too large or too vague, it invokes this skill again on that unit to split it. The plan is done when every verify passes."
