---
name: write-plan-for-small-model
description: Use a large model to write a verify-driven implementation plan that a small/weak model can execute step by step. Each task is a "quick verify" unit with its own code piece, a verify harness, and a single entry point.
---

# Write Plan for Small Model

Write a verify-driven implementation plan that a small/weak model can execute step by step. Each task is a "quick verify" unit with its own code piece, a verify harness, and a single entry point. The plan is finished only when every verify passes.

This skill is **recursive** — when executing a task that is still too large or too vague, call this skill again to split that task into smaller verify units.

---

## When to Use

- **User explicitly calls it**: "write a plan for small model" or "split this into verify steps"
- **Task too large**: The small model can't finish in one pass (too much context, too many files)
- **Process unclear**: The path from start to finish isn't explicit enough for a small model to follow blindly

---

## Plan Structure

A plan is a list of **Verify Units**. Each unit:

1. **One deliverable** — a single behavior, function, endpoint, or test
2. **Self-contained code piece** — all code the small model needs to write
3. **Verify harness** — how to check it works (run a command, see expected output)
4. **Single entry point** — one command to run the verify

---

## Verify Unit Template

```
### Verify N: <short name>

**What it does:** <1 sentence — the one behavior this verify proves>

**Code to write:**
<exact file path and complete code>

**Verify command:**
<exact shell command to run>

**Expected output:**
<what the small model should see if it passes>

**Pass condition:** <1 line — what "passing" means>
```

---

## Rules for Verify Units

### DO
- Each verify is **one command + one file** maximum
- Show **complete code** — no TODOs, no "similar to above"
- Expected output must be **exact** (copy-paste match)
- Smaller is better — 5 lines of code + 1 assert is a perfect verify
- Order verifies so each builds on the previous one

### DON'T
- No "implement the rest" — every piece of code must be shown
- No "handle edge cases" without showing the edge case and the fix
- No "write tests" — the verify IS the test
- No multi-file verifies unless they're trivial

---

## Recursive Splitting

If a task from the plan is still too large when it's time to execute:

1. **Pause execution** of the current plan
2. **Call this skill again** on just that one task
3. Get a sub-plan of finer verify units
4. Execute those, then return to the parent plan

```
Parent Plan:
  Verify 1: pass
  Verify 2: TOO LARGE for small model
     |
     Recursive split -> Sub-Plan:
         Verify 2a: pass
         Verify 2b: split again
           Verify 2b-i: pass
           Verify 2b-ii: pass
         Verify 2c: pass
  Verify 2: pass (all sub-verifies passed)
  Verify 3: ...
```

---

## Plan Header

Every plan starts with:

```markdown
# Plan: <goal>

**Goal:** <one sentence>

**Context:** <relevant files, architecture, constraints the small model needs>

**Total verifies:** <N>

## Verifies
```

---

## Example

```markdown
# Plan: Add evict() function to scheduler

**Goal:** Implement a function that removes a Pod from a Node and puts it back to Pending.

**Context:** We have a Node class with `.pods` list and a Pod class with `.status` field.
File to edit: `scheduler/actions.py`

**Total verifies:** 3

## Verifies

### Verify 1: Create evict() skeleton

**What it does:** Define the function signature so it's importable.

**Code to write:**
File: `scheduler/actions.py`
```python
def evict(pod, node):
    """Remove pod from node, set pod status to Pending."""
    pass
```

**Verify command:**
```bash
python3 -c "from scheduler.actions import evict; print('import OK')"
```

**Expected output:**
```
import OK
```

**Pass condition:** No ImportError.

---

### Verify 2: evict removes pod from node

**What it does:** Remove the pod from node.pods list.

**Code to write:**
File: `scheduler/actions.py` (replace evict function)
```python
def evict(pod, node):
    """Remove pod from node, set pod status to Pending."""
    node.pods.remove(pod)
    pod.status = "Pending"
```

**Verify command:**
```bash
python3 -c "
from scheduler.actions import evict

class Pod:
    def __init__(self, name): self.name = name
class Node:
    def __init__(self): self.pods = []

p = Pod('job-a-pod-1')
n = Node()
n.pods.append(p)

evict(p, n)
print('pods on node:', len(n.pods))
print('pod status:', p.status)
"
```

**Expected output:**
```
pods on node: 0
pod status: Pending
```

**Pass condition:** len(n.pods) == 0 AND p.status == "Pending"

---

### Verify 3: evict raises if pod not on node

**What it does:** Add error handling for edge case.

**Code to write:**
File: `scheduler/actions.py` (replace evict function)
```python
def evict(pod, node):
    """Remove pod from node, set pod status to Pending."""
    if pod not in node.pods:
        raise ValueError(f"Pod {pod.name} not on node")
    node.pods.remove(pod)
    pod.status = "Pending"
```

**Verify command:**
```bash
python3 -c "
from scheduler.actions import evict

class Pod:
    def __init__(self, name): self.name = name
class Node:
    def __init__(self): self.pods = []

p = Pod('job-a-pod-1')
n = Node()

try:
    evict(p, n)
    print('FAIL: should have raised')
except ValueError as e:
    print('OK:', e)
"
```

**Expected output:**
```
OK: Pod job-a-pod-1 not on node
```

**Pass condition:** ValueError raised with pod name in message.
```

---

## Execution Rules for Small Model

When executing a plan:

1. Do **one verify at a time**
2. Run the verify command
3. If output matches expected → mark complete, move to next
4. If output doesn't match → **STOP**. Report: which verify, expected vs actual, don't continue
5. Only write code exactly as shown in the verify unit — don't improvise
