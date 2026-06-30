# Migrate daily-record into personal-base as an Obsidian Vault — Plan for Small Model

> **Executor:** Run units top to bottom. Each unit ends in one verify command.
> Check the box only when that command shows the expected PASS.
> If a unit is too large or too vague to execute, STOP and invoke the
> `write-plan-for-small-model` skill on that unit to split it further, then add a
> **Split into:** link here and keep this unit's box unchecked until that child
> doc is finished.

> **Called by:** none (top-level plan).

**Goal:** Move all files from `subrepos/daily-record` into `subrepos/personal-base/knowledge/`, make that folder an Obsidian vault, fully remove the `daily-record` submodule, and update every doc/script that referenced it.

**Architecture:** `daily-record` and `personal-base` are both git submodules of the parent repo `pi-agent-workflow`. We copy daily-record's content (preserving its subfolder layout and keeping images beside their notes) into a new `knowledge/` directory inside the personal-base submodule, add a `.obsidian/` vault config there, commit inside personal-base, then in the parent repo `git rm` the daily-record submodule, scrub textual references, and bump the personal-base pointer.

**Tech Stack:** git submodules, rsync, Obsidian (vault = any folder containing a `.obsidian/` dir), Markdown.

## Global Constraints

- All commands are run from the repo root: `/home/laeq/code/harness/pi-agent-workflow`. Copy commands verbatim.
- Keep images beside the notes that reference them. Do NOT move images into a central folder and do NOT rewrite any image links.
- daily-record's only internal links are two image links in `日志2024.10.9.md` (`image-1.png`, `image-2.png`); both images sit in the same directory as that note, so co-locating them keeps the links valid. There are no note-to-note relative links.
- Obsidian vault config goes at `subrepos/personal-base/knowledge/.obsidian/` (vault root = `knowledge/`).
- Vault must keep Markdown-style links (`[text](file.md)`), NOT wikilinks: set `"useMarkdownLinks": true`.
- Do the copy (Unit 1) BEFORE removing the submodule (Unit 3). Never remove daily-record before its files are safely copied and committed.
- Units 1–2 commit inside the personal-base submodule (`subrepos/personal-base`). Units 3–5 commit in the parent repo.

## Done Definition

The plan is finished when every verify below shows PASS. No other criteria.

---

### Unit 1: Copy daily-record content into personal-base/knowledge/  (code)

**Files:**
- Create: `subrepos/personal-base/knowledge/` (whole tree, copied from `subrepos/daily-record/`)
- Verify: inline shell check (no test file)

**Interfaces:**
- Produces: directory `subrepos/personal-base/knowledge/` containing 31 files, including `知l识` subdirs `agent/`, `virtual-machine/`, `leetcode/`, `项目/`, and root images `image.png`, `image-1.png`, `image-2.png`.

**Recurse if:** rsync is unavailable or the file count check fails for an unexpected reason you cannot resolve in one pass.

- [ ] **Step 1 — Code piece.** Create the target dir and copy everything except git metadata:

```bash
mkdir -p subrepos/personal-base/knowledge
rsync -a --exclude='.git' --exclude='.gitignore' subrepos/daily-record/ subrepos/personal-base/knowledge/
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command (checks count and the representative files, one per subdir, plus all three images and the image-link targets):

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
n=$(find "$K" -type f | wc -l)
test "$n" -eq 31 || { echo "FAIL: expected 31 files, got $n"; exit 1; }
for f in \
  "agent.md" "agent/plan.md" "leetcode/leecode.md" \
  "virtual-machine/lxc.md" "项目/投资业务.pptx" "项目/债券基金流程图.drawio" \
  "vLLM.md" "面试.md" "日志2024.10.9.md" \
  "image.png" "image-1.png" "image-2.png"; do
  test -f "$K/$f" || { echo "FAIL: missing $K/$f"; exit 1; }
done
# image links in 日志2024.10.9.md resolve relative to the note (same dir)
grep -q "image-1.png" "$K/日志2024.10.9.md"
grep -q "image-2.png" "$K/日志2024.10.9.md"
test -f "$K/image-1.png" && test -f "$K/image-2.png"
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: prints `FAIL: ...` — re-run the rsync in Step 1 (verify the trailing slashes on both paths) and re-run this check.

- [ ] **Step 4 — Commit (inside the personal-base submodule).**

```bash
git -C subrepos/personal-base add knowledge
git -C subrepos/personal-base commit -m "feat(knowledge): import daily-record notes into knowledge/"
```

---

### Unit 2: Make knowledge/ an Obsidian vault  (code)

**Files:**
- Create: `subrepos/personal-base/knowledge/.obsidian/app.json`
- Create: `subrepos/personal-base/knowledge/.obsidian/appearance.json`
- Create: `subrepos/personal-base/knowledge/.obsidian/core-plugins.json`
- Modify (overwrite): `subrepos/personal-base/knowledge/README.md`
- Modify: `subrepos/personal-base/AGENTS.md` (add one bullet under "## Key directories")
- Verify: inline python check (no test file)

**Interfaces:**
- Consumes: `subrepos/personal-base/knowledge/` from Unit 1.
- Produces: a `.obsidian/` directory that makes `knowledge/` open as a vault with Markdown links and attachments beside notes.

**Recurse if:** Obsidian config schema needs to differ from what is shown (you do not need Obsidian installed; these files are plain JSON and just need to be valid).

- [ ] **Step 1 — Code piece (vault config).** Create the `.obsidian` directory and write all three JSON files exactly:

```bash
mkdir -p subrepos/personal-base/knowledge/.obsidian
```

`subrepos/personal-base/knowledge/.obsidian/app.json`:

```json
{
  "useMarkdownLinks": true,
  "newLinkFormat": "relative",
  "attachmentFolderPath": "./",
  "alwaysUpdateLinks": true,
  "showUnsupportedFiles": true
}
```

`subrepos/personal-base/knowledge/.obsidian/appearance.json`:

```json
{}
```

`subrepos/personal-base/knowledge/.obsidian/core-plugins.json`:

```json
[
  "file-explorer",
  "global-search",
  "switcher",
  "graph",
  "backlink",
  "outgoing-link",
  "tag-pane",
  "page-preview",
  "daily-notes",
  "templates",
  "note-composer",
  "command-palette",
  "editor-status",
  "bookmarks",
  "outline",
  "word-count"
]
```

- [ ] **Step 2 — Code piece (vault README).** Overwrite `subrepos/personal-base/knowledge/README.md` with exactly:

```markdown
# Knowledge Base (Obsidian Vault)

Chinese technical notes imported from the former `daily-record` repo.

- Open this `knowledge/` folder directly as an Obsidian vault.
- Links are Markdown-style (`[text](file.md)`), not wikilinks.
- Images are stored beside the notes that reference them.

## Topics
- `agent/`, `agent.md` — agent systems
- `virtual-machine/` — lxc, microk8s, ubuntu plans
- `leetcode/` — algorithm notes
- `项目/` — project diagrams (.drawio) and decks (.pptx)
- `日志YYYY.M.D.md` — daily logs
- `vLLM.md`, `vllm-stack.md`, `harness-engineering.md` — infra notes
```

- [ ] **Step 3 — Code piece (personal-base AGENTS.md).** In `subrepos/personal-base/AGENTS.md`, find this block:

```markdown
## Key directories
- `curator/` — Python content curation tool
```

Insert a new bullet immediately AFTER the `## Key directories` line so it reads:

```markdown
## Key directories
- `knowledge/` — Obsidian vault of imported tech notes (agent, vLLM, k8s, 日志, 项目)
- `curator/` — Python content curation tool
```

- [ ] **Step 4 — Verify framework + entry point.** Run this one command:

```bash
python3 -c '
import json, pathlib, sys
base = pathlib.Path("subrepos/personal-base/knowledge/.obsidian")
app = json.loads((base/"app.json").read_text())
assert app["useMarkdownLinks"] is True, "useMarkdownLinks must be true"
assert app["attachmentFolderPath"] == "./", "attachments must stay beside notes"
json.loads((base/"appearance.json").read_text())
cp = json.loads((base/"core-plugins.json").read_text())
assert isinstance(cp, list) and "file-explorer" in cp, "core-plugins must be a list"
readme = pathlib.Path("subrepos/personal-base/knowledge/README.md").read_text()
assert "Obsidian Vault" in readme, "README not updated"
agents = pathlib.Path("subrepos/personal-base/AGENTS.md").read_text()
assert "knowledge/` — Obsidian vault" in agents, "AGENTS.md key-dir bullet missing"
print("PASS")
'
```

- [ ] **Step 5 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: `AssertionError` names the missing/wrong field — fix that file and re-run.

- [ ] **Step 6 — Commit (inside the personal-base submodule).**

```bash
git -C subrepos/personal-base add knowledge/.obsidian knowledge/README.md AGENTS.md
git -C subrepos/personal-base commit -m "feat(knowledge): add Obsidian vault config and README"
```

---

### Unit 3: Remove the daily-record submodule (parent repo)  (code)

**Files:**
- Delete: `subrepos/daily-record/` (submodule working tree)
- Modify: `.gitmodules` (git removes the daily-record section automatically)
- Delete: `.git/modules/subrepos/daily-record` (stored submodule git dir)
- Verify: inline shell check

**Interfaces:**
- Consumes: Unit 1 already copied all daily-record files, so deleting the source is safe.

**Recurse if:** `git rm` reports the submodule has uncommitted changes you did not expect and you cannot determine why in one pass.

- [ ] **Step 1 — Code piece.** Deinit, remove, and purge the stored git dir:

```bash
git submodule deinit -f subrepos/daily-record
git rm -f subrepos/daily-record
rm -rf .git/modules/subrepos/daily-record
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
git submodule status | grep -q "daily-record" && { echo "FAIL: still a submodule"; exit 1; } || true
grep -q "daily-record" .gitmodules && { echo "FAIL: still in .gitmodules"; exit 1; } || true
test -e subrepos/daily-record && { echo "FAIL: dir still exists"; exit 1; } || true
test -e .git/modules/subrepos/daily-record && { echo "FAIL: git dir remains"; exit 1; } || true
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0. (`.gitmodules` now lists only `subrepos/personal-base`.)
  - FAIL: the message says which artifact remains — remove it (re-run the matching line from Step 1) and re-run the check.

- [ ] **Step 4 — Commit (parent repo).**

```bash
git add .gitmodules subrepos/daily-record
git commit -m "chore: remove daily-record submodule (merged into personal-base/knowledge)"
```

---

### Unit 4: Scrub textual references to daily-record (parent repo)  (code)

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `REPO_GUIDE.md`
- Modify: `bootstrap.sh`
- Modify: `sync-knowledge.sh`
- Modify: `prompts/daily-log.md`
- Verify: grep returns zero matches in those six files

**Recurse if:** any old text block below does not match the file exactly (the file changed since planning) — re-read the file and split this unit per file.

- [ ] **Step 1 — Edit `AGENTS.md` (convention block).** Replace this exact block:

```markdown
### daily-record (Markdown knowledge base)
- Path: `subrepos/daily-record/` (git submodule)
- Each .md file covers one topic area
- Subdirs for multi-file topics (agent/, virtual-machine/, leetcode/)
- Daily logs named 日志YYYY.M.D.md
- Images stored alongside notes
```

with:

```markdown
### knowledge base (Markdown, inside personal-base)
- Path: `subrepos/personal-base/knowledge/` (Obsidian vault)
- Each .md file covers one topic area
- Subdirs for multi-file topics (agent/, virtual-machine/, leetcode/, 项目/)
- Daily logs named 日志YYYY.M.D.md
- Images stored alongside notes
```

- [ ] **Step 2 — Edit `AGENTS.md` (clone section line).** Replace this exact line:

```
This repo uses git submodules for daily-record and personal-base:
```

with:

```
This repo uses a git submodule for personal-base:
```

- [ ] **Step 3 — Edit `README.md`.** Replace this exact line:

```
This repo includes daily-record and personal-base as git submodules under `subrepos/`:
```

with:

```
This repo includes personal-base as a git submodule under `subrepos/`:
```

- [ ] **Step 4 — Edit `REPO_GUIDE.md`.** Delete this exact line (remove the whole line):

```
- `daily-record` — Knowledge base (has conventions in AGENTS.md)
```

- [ ] **Step 5 — Edit `bootstrap.sh`.** Delete this exact line (remove the whole line):

```
    "daily-record"           # Knowledge base
```

- [ ] **Step 6 — Edit `sync-knowledge.sh`.** Replace these two exact comment lines:

```
#   (cd subrepos/daily-record && git add ... && git push)
#   git add subrepos/daily-record && git commit && git push
```

with:

```
#   (cd subrepos/personal-base && git add ... && git push)
#   git add subrepos/personal-base && git commit && git push
```

- [ ] **Step 7 — Edit `prompts/daily-log.md`.** Replace this exact line:

```
description: Write a daily log entry in daily-record format
```

with:

```
description: Write a daily log entry in knowledge-base format
```

Then replace this exact line:

```
Write a new daily log file named `日志$(date +%Y.%-m.%-d).md` in the daily-record repo.
```

with:

```
Write a new daily log file named `日志$(date +%Y.%-m.%-d).md` in `subrepos/personal-base/knowledge/`.
```

- [ ] **Step 8 — Verify framework + entry point.** Run this one command (scoped to the six edited files so the plan doc itself is not matched):

```bash
bash -c '
m=$(grep -In "daily-record" AGENTS.md README.md REPO_GUIDE.md bootstrap.sh sync-knowledge.sh prompts/daily-log.md || true)
if [ -n "$m" ]; then echo "FAIL: remaining references:"; echo "$m"; exit 1; fi
echo PASS
'
```

- [ ] **Step 9 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: lists the file:line still containing `daily-record` — edit that line and re-run.

- [ ] **Step 10 — Commit (parent repo).**

```bash
git add AGENTS.md README.md REPO_GUIDE.md bootstrap.sh sync-knowledge.sh prompts/daily-log.md
git commit -m "docs: point references from daily-record to personal-base/knowledge"
```

---

### Unit 5: Bump personal-base pointer and final whole-repo verify  (code)

**Files:**
- Modify: parent repo's `subrepos/personal-base` gitlink (points to the new commits from Units 1–2)
- Verify: inline shell check (working tree clean + content present + no daily-record submodule)

**Interfaces:**
- Consumes: commits made inside `subrepos/personal-base` in Units 1–2; submodule removal from Unit 3; doc edits from Unit 4.

**Recurse if:** `git status` shows unexpected unstaged changes you cannot account for.

- [ ] **Step 1 — Code piece.** Stage the updated submodule pointer and commit it in the parent repo:

```bash
git add subrepos/personal-base
git commit -m "chore: bump personal-base pointer (knowledge vault import)"
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command (the whole Done Definition in one shot):

```bash
bash -c '
set -e
# parent working tree clean
test -z "$(git status --porcelain)" || { echo "FAIL: parent tree not clean"; git status --porcelain; exit 1; }
# personal-base submodule tree clean
test -z "$(git -C subrepos/personal-base status --porcelain)" || { echo "FAIL: personal-base not clean"; exit 1; }
# knowledge content present (31 notes/assets) with vault config
n=$(find subrepos/personal-base/knowledge -type f -not -path "*/.obsidian/*" | wc -l)
test "$n" -eq 31 || { echo "FAIL: expected 31 knowledge files, got $n"; exit 1; }
test -f subrepos/personal-base/knowledge/.obsidian/app.json || { echo "FAIL: no vault config"; exit 1; }
# daily-record fully gone
git submodule status | grep -q "daily-record" && { echo "FAIL: daily-record submodule remains"; exit 1; } || true
test -e subrepos/daily-record && { echo "FAIL: daily-record dir remains"; exit 1; } || true
# no lingering references in the six docs
grep -Iq "daily-record" AGENTS.md README.md REPO_GUIDE.md bootstrap.sh sync-knowledge.sh prompts/daily-log.md && { echo "FAIL: doc reference remains"; exit 1; } || true
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0. The migration is complete.
  - FAIL: the message names the failing condition — go back to the unit that owns it (content → Units 1–2, submodule → Unit 3, docs → Unit 4), fix, commit, and re-run this check.

- [ ] **Step 4 — Commit.** Nothing to commit if Step 1 already committed and the tree is clean. If Step 2 reported residual changes you fixed, commit them now:

```bash
git add -A
git commit -m "chore: finalize daily-record to personal-base/knowledge migration" || echo "nothing to commit"
```

---

## Notes for the executor

- Pushing is intentionally not in this plan. When all five verifies pass and you want the changes on the remotes, push the submodule first, then the parent:
  ```bash
  git -C subrepos/personal-base push
  git push
  ```
- The former daily-record GitHub repo (`ccijunk/daily-record`) is untouched by this plan; archiving or deleting it on GitHub is a manual decision left to the user.
