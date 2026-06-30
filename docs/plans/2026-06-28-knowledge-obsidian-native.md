# Make knowledge/record/ Obsidian-Native — Plan for Small Model

> **Executor:** Run units top to bottom. Each unit ends in one verify command.
> Check the box only when that command shows the expected PASS.
> If a unit is too large or too vague to execute, STOP and invoke the
> `write-plan-for-small-model` skill on that unit to split it further, then add a
> **Split into:** link here and keep this unit's box unchecked until that child
> doc is finished.

> **Called by:** none (top-level plan).

**Goal:** Restructure `subrepos/personal-base/knowledge/record/` into an Obsidian-native vault: folder-by-topic layout, YAML frontmatter (aliases + tags) on every note, wikilinks, MOC hub notes, daily notes in `daily/`, and Obsidian config switched to wikilink mode.

**Architecture:** The vault root is `subrepos/personal-base/knowledge/`. Currently all content sits in a single `record/` folder. We will: (1) move files into topic folders under the vault root, (2) add YAML frontmatter to every `.md` file, (3) convert the 2 Obsidian embed syntaxes to wikilink embeds, (4) switch app.json to wikilinks and update daily-notes config, (5) create MOC hub notes, (6) rewrite the vault README, (7) delete the now-empty `record/` subtree, (8) clean up dangling images.

**Tech Stack:** Python 3 (for frontmatter injection + batch file moves), git, Obsidian vault JSON config.

## Global Constraints

- All commands run from the repo root: `/home/laeq/code/harness/pi-agent-workflow`.
- Commits go inside the personal-base submodule: `git -C subrepos/personal-base ...`.
- The vault root is `subrepos/personal-base/knowledge/`. After restructuring, there is NO `record/` subfolder — all topic folders sit directly under `knowledge/`.
- Images stay beside the notes that reference them. After moves, image files are relocated to match.
- File names may contain Chinese characters — all commands must handle UTF-8.
- Two files are empty placeholders (`archlinux.md`, `aibirx.md`) — delete them instead of adding frontmatter.
- The `agent/plan.md` file references "agent" content; it moves to `agent/plan.md` (same relative path under `knowledge/agent/`).
- The `项目/` folder has `.drawio` and `.pptx` binary files — move them alongside their parent note.
- Daily notes (`日志*.md`) move to `daily/` and get renamed to Obsidian's `YYYY-MM-DD.md` format (e.g. `日志2024.10.9.md` → `daily/2024-10-09.md`).
- All frontmatter uses `aliases` (list) and `tags` (list). No inline `#tags`. The `created` field uses ISO date if inferable from filename, otherwise `unknown`.
- Wikilinks use shortest path: `[[note name]]` (not `[[folder/note name]]`), since all note names are unique after the rename.
- The `.obsidian/` config changes: `useMarkdownLinks: false`, `newLinkFormat: "shortestPath"`, and daily-notes plugin configured for `daily/` folder with `YYYY-MM-DD` format.
- After all moves, if any image file (`.png`, `.jpg`) has NO referencing `.md` file in the same directory, move it to an `_attachments/` folder at vault root.

## Done Definition

The plan is finished when every verify below shows PASS. No other criteria.

---

### Unit 1: Python helper script for frontmatter injection  (code)

**Files:**
- Create: `subrepos/personal-base/tools/add_frontmatter.py`
- Verify: inline shell check

**Interfaces:**
- Produces: a reusable script `add_frontmatter.py` that takes a `.md` file path + optional `--aliases` + `--tags` + `--created` and injects a YAML frontmatter block at the top of the file (or replaces an existing one). Used by Units 2–4.

**Recurse if:** the script logic is too large for one pass — split into "parse existing frontmatter" and "inject new frontmatter" sub-units.

- [ ] **Step 1 — Code piece.** Write this file exactly:

```python
#!/usr/bin/env python3
"""Inject or replace YAML frontmatter in a Markdown file."""
import argparse
import sys
from pathlib import Path


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Return (metadata_dict, body) from text. If no frontmatter, returns ({}, text)."""
    if not text.startswith("---\n"):
        return {}, text
    parts = text.split("---\n", 2)
    if len(parts) < 3:
        return {}, text
    meta_str = parts[1]
    body = parts[2]
    meta: dict = {}
    key = None
    for line in meta_str.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("- "):
            if key is not None:
                val = stripped[2:].strip().strip('"').strip("'")
                meta[key].append(val)
        elif ":" in stripped:
            k, _, v = stripped.partition(":")
            key = k.strip()
            val = v.strip().strip('"').strip("'")
            if val:
                meta[key] = val
            else:
                meta[key] = []
        else:
            if key is not None and isinstance(meta[key], list):
                val = stripped.strip().strip('"').strip("'")
                meta[key].append(val)
    return meta, body


def build_frontmatter(meta: dict) -> str:
    lines = ["---"]
    for key, value in meta.items():
        if isinstance(value, list):
            lines.append(f"{key}:")
            for item in value:
                lines.append(f"  - {item}")
        else:
            lines.append(f"{key}: {value}")
    lines.append("---")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file", help="Path to .md file")
    parser.add_argument("--aliases", nargs="*", default=[], help="Alias list")
    parser.add_argument("--tags", nargs="*", default=[], help="Tag list")
    parser.add_argument("--created", default="unknown", help="ISO date")
    args = parser.parse_args()
    path = Path(args.file)
    if not path.exists():
        print(f"FAIL: file not found: {path}", file=sys.stderr)
        sys.exit(1)
    text = path.read_text(encoding="utf-8")
    existing_meta, body = parse_frontmatter(text)
    if args.aliases:
        existing_meta["aliases"] = args.aliases
    if args.tags:
        existing_meta["tags"] = args.tags
    if args.created:
        existing_meta["created"] = args.created
    new_text = build_frontmatter(existing_meta) + "\n" + body
    path.write_text(new_text, encoding="utf-8")
    print(f"OK: {path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command:

```bash
python3 -c '
import tempfile, pathlib, subprocess, sys
td = tempfile.mkdtemp()
f = pathlib.Path(td) / "test.md"
f.write_text("# Hello\n\nBody text.\n", encoding="utf-8")
r = subprocess.run(
    ["python3", "subrepos/personal-base/tools/add_frontmatter.py", str(f),
     "--aliases", "hi", "--tags", "test", "demo", "--created", "2026-01-01"],
    capture_output=True, text=True
)
assert r.returncode == 0, f"exit {r.returncode}: {r.stderr}"
content = f.read_text(encoding="utf-8")
assert content.startswith("---\n"), f"no frontmatter: {content[:60]}"
assert "aliases:" in content, "no aliases"
assert "  - test" in content, "no tag list"
assert "created: 2026-01-01" in content, "no created"
body_after = content.split("---\n", 2)[2]
assert "# Hello" in body_after, f"body lost: {body_after[:60]}"
print("PASS")
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: assertion error tells which field is missing — fix the script and re-run.

- [ ] **Step 4 — Commit.**

```bash
git -C subrepos/personal-base add tools/add_frontmatter.py
git -C subrepos/personal-base commit -m "feat(tools): add frontmatter injection helper"
```

---

### Unit 2: Create topic folders and move files  (code)

**Files:**
- Create dirs: `subrepos/personal-base/knowledge/agent/`, `knowledge/virtual-machine/`, `knowledge/leetcode/`, `knowledge/project/`, `knowledge/daily/`, `knowledge/infra/`, `knowledge/linux/`, `knowledge/investing/`
- Move: all 31 files from `knowledge/record/` into new locations
- Delete: `knowledge/record/archlinux.md`, `knowledge/record/aibirx.md` (empty placeholders)
- Verify: inline shell check

**Interfaces:**
- Consumes: existing `knowledge/record/` tree.
- Produces: new folder layout under `knowledge/` with all files moved. The old `record/` dir still exists (its removal is Unit 7).

**Recurse if:** the move list is too large — split by topic group (one unit for vm+linux files, one for agent+infra, etc.).

**Destination mapping** (every file from `record/`):

| Source `record/...` | Destination `knowledge/...` |
|---|---|
| `agent.md` | `agent/agent.md` |
| `agent/plan.md` | `agent/plan.md` |
| `vLLM.md` | `infra/vLLM.md` |
| `vllm-stack.md` | `infra/vllm-stack.md` |
| `harness-engineering.md` | `infra/harness-engineering.md` |
| `software-engeering.md` | `infra/software-engeering.md` |
| `squid.md` | `infra/squid.md` |
| `aibirx.md` | (DELETE — empty) |
| `virtual-machine/lxc.md` | `virtual-machine/lxc.md` |
| `virtual-machine/microk8s.md` | `virtual-machine/microk8s.md` |
| `virtual-machine/plan.md` | `virtual-machine/plan.md` |
| `virtual-machine/ubuntu-plan.md` | `virtual-machine/ubuntu-plan.md` |
| `grub.md` | `linux/grub.md` |
| `brtfs-backup.md` | `linux/brtfs-backup.md` |
| `archlinux.md` | (DELETE — empty) |
| `leetcode/leecode.md` | `leetcode/leecode.md` |
| `项目.md` | `project/项目.md` |
| `项目/债券基金流程图.drawio` | `project/债券基金流程图.drawio` |
| `项目/投资业务.pptx` | `project/投资业务.pptx` |
| `项目/投资实体.drawio` | `project/投资实体.drawio` |
| `特斯拉.md` | `investing/特斯拉.md` |
| `面试.md` | `investing/面试.md` |
| `some-of-the-summary.md` | `investing/some-of-the-summary.md` |
| `日志2024.10.9.md` | `daily/2024-10-09.md` |
| `日志2025.6.16.md` | `daily/2025-06-16.md` |
| `日志2026.1.18.md` | `daily/2026-01-18.md` |
| `日志2026.6.24.md` | `daily/2026-06-24.md` |
| `image.png` | `daily/image.png` (co-located with 日志2026.1.18) |
| `image-1.png` | `infra/image-1.png` (co-located with vllm-stack.md) |
| `image-2.png` | `infra/image-2.png` (co-located with vllm-stack.md) |
| `README.md` | (will be overwritten in Unit 6 — delete now) |

Note: `日志2025.6.16.md` has `![[Pasted image 20250617174857.png]]` and `![[diagram-1.png]]` embeds — these images do not exist in the vault (they were pasted in a previous Obsidian instance). The unit will note this but NOT create placeholder files. The embeds will be converted to wikilink syntax in Unit 3.

- [ ] **Step 1 — Code piece.** Run these commands exactly:

```bash
cd subrepos/personal-base/knowledge

# Create destination dirs
mkdir -p agent virtual-machine leetcode project daily infra linux investing

# Delete empty placeholders
rm record/archlinux.md record/aibirx.md

# Delete old README (Unit 6 writes a new one at vault root)
rm record/README.md

# --- agent ---
mv record/agent.md agent/agent.md
mv record/agent/plan.md agent/plan.md
rmdir record/agent

# --- infra ---
mv record/vLLM.md infra/vLLM.md
mv record/vllm-stack.md infra/vllm-stack.md
mv record/harness-engineering.md infra/harness-engineering.md
mv record/software-engeering.md infra/software-engeering.md
mv record/squid.md infra/squid.md
mv record/image-1.png infra/image-1.png
mv record/image-2.png infra/image-2.png

# --- virtual-machine ---
mv record/virtual-machine/lxc.md virtual-machine/lxc.md
mv record/virtual-machine/microk8s.md virtual-machine/microk8s.md
mv record/virtual-machine/plan.md virtual-machine/plan.md
mv record/virtual-machine/ubuntu-plan.md virtual-machine/ubuntu-plan.md
rmdir record/virtual-machine

# --- linux ---
mv record/grub.md linux/grub.md
mv record/brtfs-backup.md linux/brtfs-backup.md

# --- leetcode ---
mv record/leetcode/leecode.md leetcode/leecode.md
rmdir record/leetcode

# --- project ---
mv record/项目.md project/项目.md
mv record/项目/债券基金流程图.drawio project/债券基金流程图.drawio
mv record/项目/投资业务.pptx project/投资业务.pptx
mv record/项目/投资实体.drawio project/投资实体.drawio
rmdir "record/项目"

# --- investing ---
mv record/特斯拉.md investing/特斯拉.md
mv record/面试.md investing/面试.md
mv record/some-of-the-summary.md investing/some-of-the-summary.md

# --- daily ---
mv record/日志2024.10.9.md daily/2024-10-09.md
mv "record/日志2025.6.16.md" daily/2025-06-16.md
mv "record/日志2026.1.18.md" daily/2026-01-18.md
mv "record/日志2026.6.24.md" daily/2026-06-24.md
mv record/image.png daily/image.png

# Remove now-empty record/ dir
rmdir record

cd /home/laeq/code/harness/pi-agent-workflow
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
test ! -e "$K/record" || { echo "FAIL: record/ still exists"; exit 1; }
for f in \
  "agent/agent.md" "agent/plan.md" \
  "infra/vLLM.md" "infra/vllm-stack.md" "infra/harness-engineering.md" \
  "infra/software-engeering.md" "infra/squid.md" \
  "infra/image-1.png" "infra/image-2.png" \
  "virtual-machine/lxc.md" "virtual-machine/microk8s.md" \
  "virtual-machine/plan.md" "virtual-machine/ubuntu-plan.md" \
  "linux/grub.md" "linux/brtfs-backup.md" \
  "leetcode/leecode.md" \
  "project/项目.md" "project/债券基金流程图.drawio" \
  "project/投资业务.pptx" "project/投资实体.drawio" \
  "investing/特斯拉.md" "investing/面试.md" "investing/some-of-the-summary.md" \
  "daily/2024-10-09.md" "daily/2025-06-16.md" \
  "daily/2026-01-18.md" "daily/2026-06-24.md" \
  "daily/image.png"; do
  test -f "$K/$f" || { echo "FAIL: missing $K/$f"; exit 1; }
done
# Verify empty files deleted
for f in "archlinux.md" "aibirx.md"; do
  found=$(find "$K" -name "$f" -type f 2>/dev/null || true)
  test -z "$found" || { echo "FAIL: empty placeholder still exists: $found"; exit 1; }
done
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: message says which file is missing or which dir still exists — re-run the matching `mv` line and the check.

- [ ] **Step 4 — Commit.**

```bash
git -C subrepos/personal-base add knowledge
git -C subrepos/personal-base commit -m "refactor(knowledge): reorganize into topic-based folders"
```

---

### Unit 3: Add YAML frontmatter to every note  (code)

**Files:**
- Modify: all 24 `.md` files under `knowledge/` (add frontmatter)
- Verify: inline shell check

**Interfaces:**
- Consumes: `tools/add_frontmatter.py` from Unit 1, and the new folder layout from Unit 2.

**Frontmatter values per file:**

| File (relative to `knowledge/`) | tags | aliases | created |
|---|---|---|---|
| `agent/agent.md` | agent, llm, roadmap | 大模型工程师学习路线图 | unknown |
| `agent/plan.md` | agent, lxc, setup | AI Agent CLI Setup in LXC | unknown |
| `infra/vLLM.md` | vllm, inference, architecture | vLLM | unknown |
| `infra/vllm-stack.md` | vllm, k8s, minikube | vllm-stack | unknown |
| `infra/harness-engineering.md` | engineering, agent, testing | harness-engineering | unknown |
| `infra/software-engeering.md` | engineering, workflow | software-engineering | unknown |
| `infra/squid.md` | squid, proxy, cache, k8s | Squid 代理缓存方案 | 2026-06-26 |
| `virtual-machine/lxc.md` | lxc, lxd, linux | LXC/LXD on Arch Linux | unknown |
| `virtual-machine/microk8s.md` | microk8s, k8s, snap | MicroK8s Remote Access | unknown |
| `virtual-machine/plan.md` | qemu, kvm, arch | Arch Linux QEMU/KVM Installation Plan | unknown |
| `virtual-machine/ubuntu-plan.md` | qemu, kvm, ubuntu | Ubuntu 24.04 QEMU/KVM Installation Plan | unknown |
| `linux/grub.md` | grub, arch, dual-boot | grub | unknown |
| `linux/brtfs-backup.md` | btrfs, backup | btrfs-backup | unknown |
| `leetcode/leecode.md` | leetcode, algorithm, go | LeetCode 57 Insert Interval | unknown |
| `project/项目.md` | project, ddd, rpc | 项目 | unknown |
| `investing/特斯拉.md` | tesla, investing | 特斯拉 | unknown |
| `investing/面试.md` | interview, huawei | 面试 | unknown |
| `investing/some-of-the-summary.md` | investing, llm | some-of-the-summary | unknown |
| `daily/2024-10-09.md` | daily-log | 日志2024.10.9 | 2024-10-09 |
| `daily/2025-06-16.md` | daily-log | 日志2025.6.16 | 2025-06-16 |
| `daily/2026-01-18.md` | daily-log | 日志2026.1.18 | 2026-01-18 |
| `daily/2026-06-24.md` | daily-log | 日志2026.6.24 | 2026-06-24 |

- [ ] **Step 1 — Code piece.** Run these commands exactly (each call is one line; do not wrap):

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base

python3 tools/add_frontmatter.py knowledge/agent/agent.md --aliases "大模型工程师学习路线图" --tags agent llm roadmap --created unknown

python3 tools/add_frontmatter.py knowledge/agent/plan.md --aliases "AI Agent CLI Setup in LXC" --tags agent lxc setup --created unknown

python3 tools/add_frontmatter.py knowledge/infra/vLLM.md --aliases vLLM --tags vllm inference architecture --created unknown

python3 tools/add_frontmatter.py knowledge/infra/vllm-stack.md --aliases vllm-stack --tags vllm k8s minikube --created unknown

python3 tools/add_frontmatter.py knowledge/infra/harness-engineering.md --aliases harness-engineering --tags engineering agent testing --created unknown

python3 tools/add_frontmatter.py knowledge/infra/software-engeering.md --aliases software-engineering --tags engineering workflow --created unknown

python3 tools/add_frontmatter.py knowledge/infra/squid.md --aliases "Squid 代理缓存方案" --tags squid proxy cache k8s --created 2026-06-26

python3 tools/add_frontmatter.py knowledge/virtual-machine/lxc.md --aliases "LXC/LXD on Arch Linux" --tags lxc lxd linux --created unknown

python3 tools/add_frontmatter.py knowledge/virtual-machine/microk8s.md --aliases "MicroK8s Remote Access" --tags microk8s k8s snap --created unknown

python3 tools/add_frontmatter.py knowledge/virtual-machine/plan.md --aliases "Arch Linux QEMU/KVM Installation Plan" --tags qemu kvm arch --created unknown

python3 tools/add_frontmatter.py knowledge/virtual-machine/ubuntu-plan.md --aliases "Ubuntu 24.04 QEMU/KVM Installation Plan" --tags qemu kvm ubuntu --created unknown

python3 tools/add_frontmatter.py knowledge/linux/grub.md --aliases grub --tags grub arch dual-boot --created unknown

python3 tools/add_frontmatter.py knowledge/linux/brtfs-backup.md --aliases btrfs-backup --tags btrfs backup --created unknown

python3 tools/add_frontmatter.py knowledge/leetcode/leecode.md --aliases "LeetCode 57 Insert Interval" --tags leetcode algorithm go --created unknown

python3 tools/add_frontmatter.py "knowledge/project/项目.md" --aliases 项目 --tags project ddd rpc --created unknown

python3 tools/add_frontmatter.py "knowledge/investing/特斯拉.md" --aliases 特斯拉 --tags tesla investing --created unknown

python3 tools/add_frontmatter.py "knowledge/investing/面试.md" --aliases 面试 --tags interview huawei --created unknown

python3 tools/add_frontmatter.py knowledge/investing/some-of-the-summary.md --aliases some-of-the-summary --tags investing llm --created unknown

python3 tools/add_frontmatter.py knowledge/daily/2024-10-09.md --aliases 日志2024.10.9 --tags daily-log --created 2024-10-09

python3 tools/add_frontmatter.py knowledge/daily/2025-06-16.md --aliases 日志2025.6.16 --tags daily-log --created 2025-06-16

python3 tools/add_frontmatter.py knowledge/daily/2026-01-18.md --aliases 日志2026.1.18 --tags daily-log --created 2026-01-18

python3 tools/add_frontmatter.py knowledge/daily/2026-06-24.md --aliases 日志2026.6.24 --tags daily-log --created 2026-06-24

cd /home/laeq/code/harness/pi-agent-workflow
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
count=0
for f in $(find "$K" -name "*.md" -not -path "*/.obsidian/*" -type f); do
  head -1 "$f" | grep -q "^---$" || { echo "FAIL: no frontmatter in $f"; exit 1; }
  count=$((count+1))
done
echo "Files with frontmatter: $count"
# Must have aliases and tags in at least infra/squid.md (known values)
grep -q "aliases:" "$K/infra/squid.md" || { echo "FAIL: no aliases in squid.md"; exit 1; }
grep -q "tags:" "$K/infra/squid.md" || { echo "FAIL: no tags in squid.md"; exit 1; }
grep -q "created: 2026-06-26" "$K/infra/squid.md" || { echo "FAIL: wrong created in squid.md"; exit 1; }
# Daily notes must have created dates
grep -q "created: 2024-10-09" "$K/daily/2024-10-09.md" || { echo "FAIL: daily note created date"; exit 1; }
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `Files with frontmatter: 22` (or more, if other .md files exist) then `PASS`, exit code 0.
  - FAIL: names the file missing frontmatter — re-run its `add_frontmatter.py` line and re-check.

- [ ] **Step 4 — Commit.**

```bash
git -C subrepos/personal-base add knowledge
git -C subrepos/personal-base commit -m "feat(knowledge): add YAML frontmatter to all notes"
```

---

### Unit 4: Convert image embeds to wikilink syntax and switch vault config  (code)

**Files:**
- Modify: `subrepos/personal-base/knowledge/daily/2025-06-16.md` (convert `![[...]]` embeds)
- Modify: `subrepos/personal-base/knowledge/daily/2026-01-18.md` (convert `image.png` markdown ref to wikilink)
- Modify: `subrepos/personal-base/knowledge/infra/vllm-stack.md` (convert markdown image refs `image-1.png`, `image-2.png` to wikilink embeds)
- Modify: `subrepos/personal-base/knowledge/.obsidian/app.json` (switch to wikilinks)
- Create: `subrepos/personal-base/knowledge/.obsidian/daily-notes.json` (configure daily notes plugin)
- Verify: inline shell check

**Interfaces:**
- Consumes: the moved files from Unit 2, the frontmatter from Unit 3.

**Recurse if:** the embed syntax conversion has edge cases not covered — split into "daily notes" and "infra notes" sub-units.

- [ ] **Step 1 — Code piece (daily/2025-06-16.md).** The file contains two Obsidian embed lines:
  - `![[Pasted image 20250617174857.png]]` — this image does not exist in the vault. Replace with:
    ```
    > **Missing image:** `Pasted image 20250617174857.png` — re-paste from original Obsidian vault.
    ```
  - `![[diagram-1.png]]` — this image also does not exist. Replace with:
    ```
    > **Missing image:** `diagram-1.png` — re-export from original diagram tool.
    ```
  Use `sed` or the Edit tool. The exact replace commands:

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base/knowledge
sed -i 's/\!\[\[Pasted image 20250617174857\.png\]\]/> **Missing image:** `Pasted image 20250617174857.png` — re-paste from original Obsidian vault./g' daily/2025-06-16.md
sed -i 's/\!\[\[diagram-1\.png\]\]/> **Missing image:** `diagram-1.png` — re-export from original diagram tool./g' daily/2025-06-16.md
cd /home/laeq/code/harness/pi-agent-workflow
```

- [ ] **Step 2 — Code piece (daily/2026-01-18.md).** This file has a Markdown image ref `![](image.png)`. Replace it with the Obsidian wikilink embed:

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base/knowledge
sed -i 's/\!\[\](image\.png)/![[image.png]]/g' daily/2026-01-18.md
cd /home/laeq/code/harness/pi-agent-workflow
```

- [ ] **Step 3 — Code piece (infra/vllm-stack.md).** This file has two Markdown image refs. Replace both with wikilink embeds:

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base/knowledge
sed -i 's/\!\[\](image-1\.png)/![[image-1.png]]/g' infra/vllm-stack.md
sed -i 's/\!\[\](image-2\.png)/![[image-2.png]]/g' infra/vllm-stack.md
cd /home/laeq/code/harness/pi-agent-workflow
```

- [ ] **Step 4 — Code piece (.obsidian/app.json).** Write this file exactly (replaces the current content):

```json
{
  "useMarkdownLinks": false,
  "newLinkFormat": "shortestPath",
  "attachmentFolderPath": "./",
  "alwaysUpdateLinks": true,
  "showUnsupportedFiles": true
}
```

- [ ] **Step 5 — Code piece (.obsidian/daily-notes.json).** Write this file exactly:

```json
{
  "folder": "daily",
  "template": "",
  "format": "YYYY-MM-DD"
}
```

- [ ] **Step 6 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
# app.json must have wikilinks
app=$(cat "$K/.obsidian/app.json")
echo "$app" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"useMarkdownLinks\"] is False; assert d[\"newLinkFormat\"]==\"shortestPath\""
# daily-notes.json must exist with correct folder
dn=$(cat "$K/.obsidian/daily-notes.json")
echo "$dn" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[\"folder\"]==\"daily\"; assert d[\"format\"]==\"YYYY-MM-DD\""
# No markdown-style image embeds left in .md files (ignore the "Missing image" blockquotes)
md_imgs=$(grep -rn "!\[\](" "$K" --include="*.md" --exclude-dir=.obsidian || true)
test -z "$md_imgs" || { echo "FAIL: markdown image embeds remain: $md_imgs"; exit 1; }
# wikilink embeds should exist in vllm-stack.md
grep -q "\!\[\[image-1.png\]\]" "$K/infra/vllm-stack.md" || { echo "FAIL: no wikilink embed for image-1"; exit 1; }
grep -q "\!\[\[image-2.png\]\]" "$K/infra/vllm-stack.md" || { echo "FAIL: no wikilink embed for image-2"; exit 1; }
echo PASS
'
```

- [ ] **Step 7 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: tells which check failed — fix the matching sed/file write and re-run.

- [ ] **Step 8 — Commit.**

```bash
git -C subrepos/personal-base add knowledge
git -C subrepos/personal-base commit -m "feat(knowledge): switch to wikilinks, configure daily-notes plugin"
```

---

### Unit 5: Create MOC (Map of Content) hub notes  (code)

**Files:**
- Create: `subrepos/personal-base/knowledge/Home.md`
- Create: `subrepos/personal-base/knowledge/agent/MOC.md`
- Create: `subrepos/personal-base/knowledge/infra/MOC.md`
- Create: `subrepos/personal-base/knowledge/virtual-machine/MOC.md`
- Create: `subrepos/personal-base/knowledge/linux/MOC.md`
- Create: `subrepos/personal-base/knowledge/project/MOC.md`
- Create: `subrepos/personal-base/knowledge/investing/MOC.md`
- Create: `subrepos/personal-base/knowledge/leetcode/MOC.md`
- Create: `subrepos/personal-base/knowledge/daily/MOC.md`
- Verify: inline shell check

**Interfaces:**
- Consumes: the folder layout and frontmatter from Units 2–3. MOCs use `[[wikilink]]` syntax to reference their child notes.

**Recurse if:** the MOC content is too large to write in one pass — split into "Home + agent/infra MOCs" and "remainder MOCs".

- [ ] **Step 1 — Code piece.** Write each file exactly.

`knowledge/Home.md`:

```markdown
---
aliases: [Home, Dashboard]
tags: [moc]
created: 2026-06-28
---
# 🏠 Knowledge Vault

Welcome to the vault. Browse by topic:

## Topics
- [[MOC|Agent]] — LLM agent systems, roadmaps, CLI setup
- [[MOC|Infra]] — vLLM, vllm-stack, Squid proxy, engineering workflow
- [[MOC|Virtual Machine]] — QEMU/KVM, LXC, MicroK8s setup
- [[MOC|Linux]] — GRUB, btrfs backup
- [[MOC|Project]] — investment subsystem, RPC framework
- [[MOC|Investing]] — Tesla, interviews, career notes
- [[MOC|Leetcode]] — algorithm problems
- [[MOC|Daily]] — daily logs (YYYY-MM-DD)

## Quick links
- [[agent|Agent Learning Roadmap]]
- [[vLLM|vLLM Architecture]]
- [[Squid 代理缓存方案|Squid Cache Plan]]
```

`knowledge/agent/MOC.md`:

```markdown
---
aliases: [Agent MOC]
tags: [moc, agent]
created: 2026-06-28
---
# Agent

- [[agent|大模型工程师学习路线图]]
- [[AI Agent CLI Setup in LXC|Agent CLI in LXC]]
```

`knowledge/infra/MOC.md`:

```markdown
---
aliases: [Infra MOC]
tags: [moc, infra]
created: 2026-06-28
---
# Infra

- [[vLLM|vLLM Architecture]]
- [[vllm-stack|vllm-stack K8s Setup]]
- [[harness-engineering|Harness Engineering]]
- [[software-engineering|Software Engineering]]
- [[Squid 代理缓存方案|Squid Proxy Cache]]
```

`knowledge/virtual-machine/MOC.md`:

```markdown
---
aliases: [Virtual Machine MOC]
tags: [moc, virtual-machine]
created: 2026-06-28
---
# Virtual Machine

- [[LXC/LXD on Arch Linux|LXC/LXD Setup]]
- [[MicroK8s Remote Access|MicroK8s]]
- [[Arch Linux QEMU/KVM Installation Plan|Arch KVM Plan]]
- [[Ubuntu 24.04 QEMU/KVM Installation Plan|Ubuntu KVM Plan]]
```

`knowledge/linux/MOC.md`:

```markdown
---
aliases: [Linux MOC]
tags: [moc, linux]
created: 2026-06-28
---
# Linux

- [[grub|GRUB Dual Boot]]
- [[btrfs-backup|Btrfs Backup]]
```

`knowledge/project/MOC.md`:

```markdown
---
aliases: [Project MOC]
tags: [moc, project]
created: 2026-06-28
---
# Project

- [[项目|Projects Overview]]
```

`knowledge/investing/MOC.md`:

```markdown
---
aliases: [Investing MOC]
tags: [moc, investing]
created: 2026-06-28
---
# Investing

- [[特斯拉|Tesla Business]]
- [[面试|Interview]]
- [[some-of-the-summary|Summary & Roadmap]]
```

`knowledge/leetcode/MOC.md`:

```markdown
---
aliases: [Leetcode MOC]
tags: [moc, leetcode]
created: 2026-06-28
---
# Leetcode

- [[LeetCode 57 Insert Interval|LC 57 Insert Interval]]
```

`knowledge/daily/MOC.md`:

```markdown
---
aliases: [Daily MOC]
tags: [moc, daily-log]
created: 2026-06-28
---
# Daily Notes

- [[2024-10-09|2024-10-09]]
- [[2025-06-16|2025-06-16]]
- [[2026-01-18|2026-01-18]]
- [[2026-06-24|2026-06-24]]
```

- [ ] **Step 2 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
test -f "$K/Home.md" || { echo "FAIL: no Home.md"; exit 1; }
for d in agent infra virtual-machine linux project investing leetcode daily; do
  test -f "$K/$d/MOC.md" || { echo "FAIL: no $d/MOC.md"; exit 1; }
  head -1 "$K/$d/MOC.md" | grep -q "^---$" || { echo "FAIL: no frontmatter in $d/MOC.md"; exit 1; }
done
# Home must link to every topic MOC
for d in agent infra virtual-machine linux project investing leetcode daily; do
  grep -q "\[\[MOC|" "$K/Home.md" || { echo "FAIL: Home missing MOC links"; exit 1; }
done
echo PASS
'
```

- [ ] **Step 3 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: names the missing MOC — create it and re-run.

- [ ] **Step 4 — Commit.**

```bash
git -C subrepos/personal-base add knowledge
git -C subrepos/personal-base commit -m "feat(knowledge): add MOC hub notes and Home dashboard"
```

---

### Unit 6: Write vault README and update personal-base AGENTS.md  (code)

**Files:**
- Create: `subrepos/personal-base/knowledge/README.md`
- Modify: `subrepos/personal-base/AGENTS.md` (update knowledge/ bullet to reflect new structure)
- Verify: inline shell check

**Interfaces:**
- Consumes: the folder layout, frontmatter, MOCs, and wikilink config from Units 2–5.

- [ ] **Step 1 — Code piece (knowledge/README.md).** Write this file exactly:

```markdown
# Knowledge Vault

An Obsidian-native vault of Chinese technical notes.

## Opening the vault
1. Open Obsidian → "Open folder as vault"
2. Select this `knowledge/` directory

## Vault conventions
- **Wikilinks** (`[[note name]]`) — not markdown links
- **Daily notes** live in `daily/` (format: `YYYY-MM-DD.md`)
- **Images** stay beside their notes; orphaned images go to `_attachments/`
- **MOC notes** (`MOC.md`) in each topic folder serve as hub indexes
- **Home.md** is the vault landing page

## Folder structure
```
knowledge/
├── Home.md          # Vault dashboard
├── agent/           # Agent systems, LLM roadmap
├── infra/           # vLLM, Squid proxy, engineering
├── virtual-machine/ # QEMU/KVM, LXC, MicroK8s
├── linux/           # GRUB, btrfs
├── project/         # Investment subsystem diagrams
├── investing/       # Tesla, interviews, career
├── leetcode/        # Algorithm problems
├── daily/           # Daily logs (YYYY-MM-DD.md)
└── .obsidian/       # Vault config
```
```

- [ ] **Step 2 — Code piece (AGENTS.md).** In `subrepos/personal-base/AGENTS.md`, replace this exact line:

```markdown
- `knowledge/` — Obsidian vault of imported tech notes (agent, vLLM, k8s, 日志, 项目)
```

with:

```markdown
- `knowledge/` — Obsidian-native vault (wikilinks, MOCs, daily notes in `daily/`, topics in `agent/`, `infra/`, `virtual-machine/`, `linux/`, `project/`, `investing/`, `leetcode/`)
```

- [ ] **Step 3 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge
test -f "$K/README.md" || { echo "FAIL: no README"; exit 1; }
grep -q "Obsidian-native" "$K/README.md" || { echo "FAIL: README not updated"; exit 1; }
grep -q "Wikilinks" "$K/README.md" || { echo "FAIL: no wikilink convention"; exit 1; }
agents=$(cat subrepos/personal-base/AGENTS.md)
echo "$agents" | grep -q "Obsidian-native vault" || { echo "FAIL: AGENTS.md not updated"; exit 1; }
echo PASS
'
```

- [ ] **Step 4 — Expected result.**
  - PASS: prints `PASS`, exit code 0.
  - FAIL: names which check failed — fix the file and re-run.

- [ ] **Step 5 — Commit.**

```bash
git -C subrepos/personal-base add knowledge/README.md AGENTS.md
git -C subrepos/personal-base commit -m "docs(knowledge): vault README and AGENTS.md update"
```

---

### Unit 7: Final whole-vault verify  (code)

**Files:**
- Verify only (no new files)

**Interfaces:**
- Consumes: everything from Units 1–6.

- [ ] **Step 1 — Verify framework + entry point.** Run this one command:

```bash
bash -c '
set -e
K=subrepos/personal-base/knowledge

# 1. No record/ dir
test ! -e "$K/record" || { echo "FAIL: record/ dir still exists"; exit 1; }

# 2. All expected folders exist
for d in agent infra virtual-machine linux project investing leetcode daily .obsidian; do
  test -d "$K/$d" || { echo "FAIL: missing folder $K/$d"; exit 1; }
done

# 3. Home.md exists
test -f "$K/Home.md" || { echo "FAIL: no Home.md"; exit 1; }

# 4. MOC in every topic folder
for d in agent infra virtual-machine linux project investing leetcode daily; do
  test -f "$K/$d/MOC.md" || { echo "FAIL: no MOC in $d"; exit 1; }
done

# 5. Every .md has YAML frontmatter
for f in $(find "$K" -name "*.md" -not -path "*/.obsidian/*" -type f); do
  head -1 "$f" | grep -q "^---$" || { echo "FAIL: no frontmatter in $f"; exit 1; }
done

# 6. Wikilinks mode in app.json
python3 -c "import json; d=json.load(open(\"$K/.obsidian/app.json\")); assert d[\"useMarkdownLinks\"] is False; assert d[\"newLinkFormat\"]==\"shortestPath\""

# 7. Daily notes config
python3 -c "import json; d=json.load(open(\"$K/.obsidian/daily-notes.json\")); assert d[\"folder\"]==\"daily\"; assert d[\"format\"]==\"YYYY-MM-DD\""

# 8. No markdown-style image embeds (except missimg-image blockquotes)
md_imgs=$(grep -rn "!\[\](" "$K" --include="*.md" --exclude-dir=.obsidian || true)
test -z "$md_imgs" || { echo "FAIL: markdown image refs remain: $md_imgs"; exit 1; }

# 9. No old 日志*.md files anywhere
old_logs=$(find "$K" -name "日志*" -type f || true)
test -z "$old_logs" || { echo "FAIL: old 日志 files remain: $old_logs"; exit 1; }

# 10. daily/ contains YYYY-MM-DD.md files
for f in 2024-10-09.md 2025-06-16.md 2026-01-18.md 2026-06-24.md; do
  test -f "$K/daily/$f" || { echo "FAIL: missing daily/$f"; exit 1; }
done

echo PASS
'
```

- [ ] **Step 2 — Expected result.**
  - PASS: prints `PASS`, exit code 0. The vault is now Obsidian-native.
  - FAIL: the message names the failing condition — go back to the unit that owns it, fix, commit, and re-run this check.

- [ ] **Step 3 — Push.**

```bash
git -C subrepos/personal-base push || echo "push failed — retry when network is up"
```

---

## Notes for the executor

- After all units pass, bump the personal-base pointer in the parent repo:
  ```bash
  git add subrepos/personal-base
  git commit -m "chore: bump personal-base pointer (obsidian-native vault restructure)"
  git push
  ```
- The two "missing images" (`Pasted image 20250617174857.png`, `diagram-1.png`) referenced in `daily/2025-06-16.md` are not in the vault. They were pasted in a previous Obsidian instance. The user can re-paste them later. The vault notes them as missing via blockquote callouts.
- The `image.png` that was co-located with `日志2026.1.18.md` is NOT referenced by any `.md` file via filename (the file uses `![](image.png)` which was converted to `![[image.png]]` in Unit 4). It stays in `daily/` alongside the note that uses it.
