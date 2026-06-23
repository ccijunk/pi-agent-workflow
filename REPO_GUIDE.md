# 🗺️ Repo Discovery & Handling Guide

> This guide tells pi how to discover, understand, and work with any repo in the ccijunk ecosystem.  
> It replaces a static repo list with a dynamic discovery process.

---

## 1. How pi Discovers a Repo

When someone says "I have a repo called X" or you detect a new directory, follow these steps:

### Step 1: Find it
```bash
# Try GitHub first (works from any device)
git ls-remote https://github.com/ccijunk/<repo-name>.git HEAD

# If local (current device only)
ls ~/code/<repo-name>/
```

- If it exists on GitHub → that's the canonical source
- If it's local-only → note that it won't be available on other devices

### Step 2: Clone & read
```bash
git clone https://github.com/ccijunk/<repo-name>.git
cd <repo-name>
```

Then read in order:
1. **AGENTS.md** — if exists, this is the primary instruction for pi
2. **README.md** — project overview, setup, usage
3. **RULES.md** — if exists, this contains rules/constraints
4. **pyproject.toml** / **package.json** — tech stack, dependencies
5. **Directory structure** — quick `ls -la` to understand layout

### Step 3: Remember for the session
Store the repo info in your working memory:
```
Repo: <name>
URL:  https://github.com/ccijunk/<name>.git
Tech: Python (uv) | Node | Go | other
Has AGENTS.md: yes/no
Conventions: <anything notable>
```

---

## 2. Standard Conventions (ccijunk's patterns)

All repos from ccijunk typically follow these patterns. Use them as defaults:

### Python repos
```yaml
package_manager: uv
test_cmd: uv run pytest tests/ -v
run_cmd: uv run python -m <module>
config: pyproject.toml
```

### Node repos
```yaml
package_manager: npm (or nvm for Node version)
test_cmd: npm test
```

### Markdown knowledge repos
```yaml
format: Markdown files
structure: Subdirs for topics
entry: README.md
```

### If a repo has AGENTS.md
→ Read it. It contains project-specific instructions for pi.  
→ Follow those instructions over any generic defaults.

---

## 3. How to Add a New Repo to the Workflow

When someone wants to start using a new repo:

```yaml
# Minimal registration (just for discovery):
repo_name: <name>
url: https://github.com/ccijunk/<name>.git
purpose: <one-line description>
```

### Optional: Create AGENTS.md
If the new repo needs specific pi instructions, create an AGENTS.md in the repo root:
```markdown
# <Repo Name> — <Purpose>

## Conventions
- <what pi needs to know>
```

---

## 4. Cross-Device Strategy

| Action | From GitHub (any device) | From local (this device only) |
|--------|--------------------------|-------------------------------|
| Clone repo | `git clone https://github.com/ccijunk/<name>.git` | Copy files or push to GitHub first |
| Know conventions | Read AGENTS.md / README.md | Same |
| Run curation | `cd personal-base && uv run python -m curator.main all` | Same once cloned |
| Edit files | `git add/commit/push` after changes | Same + push if needed |

---

## 5. Quick Reference: Known Repo Categories

This is NOT an exhaustive list — it's a map of what categories exist so pi knows where to look.

### Active & Maintained
These repos have active AGENTS.md or are referenced in the main workflow:
- `pi-agent-workflow` — The harness we're in
- `personal-base` — English learning curation (has RULES.md + AGENTS.md)
- `daily-record` — Knowledge base (has conventions in AGENTS.md)

### Likely Active
Check if needed:
- `ai-workflow` / `flowctl` — Python workflow engine
- `life-system` — Life OS in plain text
- `skills` — Skills collection

### Older / Archive
Read README to determine if still active:
- `vllm-ascend`, `deer-flow`, `ai-factory`, `ai-figure-out`, etc.

---

## 6. When to Use This Guide

Read this guide when:
- Someone says "I have a new repo"
- Someone mentions a repo name you don't recognize
- Someone asks "what repos do I have?"
- You detect a directory you haven't seen before
- On a new device, after cloning pi-agent-workflow
