# Pi Agent Workflow

Personal Pi coding-agent configuration. **Edit here, use everywhere.**

This repo holds all your Pi extensions, skills, prompt templates, themes, and settings. Symlinks wire each resource to `~/.pi/agent/` so edits in this repo take effect immediately (themes even hot-reload).

## Directory Layout

```
pi-agent-workflow/
├── README.md                   # ← you are here
├── setup.sh                    # One-command setup (create symlinks)
├── settings.json               # Global Pi settings (~/.pi/agent/settings.json)
├── AGENTS.md                   # Global context file (~/.pi/agent/AGENTS.md)
│
├── prompts/                    # Prompt templates → ~/.pi/agent/prompts/
│   ├── daily-log.md            #   /daily-log — write a daily log entry
│   ├── ci-debug.md             #   /ci-debug — debug a failing CI workflow
│   └── review.md               #   /review — code review checklist
│
├── skills/                     # Skills → ~/.pi/agent/skills/
│   └── oncall-dev/
│       └── SKILL.md            #   /skill:oncall-dev — dev tasks for oncall-agent
│
├── extensions/                 # Extensions → ~/.pi/agent/extensions/
│   ├── confirm-destructive.ts  #   Block dangerous commands (rm -rf, sudo)
│   └── git-checkpoint.ts       #   Auto-stash/restore on each turn
│
└── themes/                     # Themes → ~/.pi/agent/themes/
    └── (your custom themes here)
```

## Quick Start

```bash
# 1. Clone or copy this repo wherever you like
git clone <url> ~/pi-agent-workflow

# 2. Run setup (creates all symlinks)
cd ~/pi-agent-workflow
bash setup.sh

# 3. Verify everything is linked
ls -la ~/.pi/agent/prompts/
ls -la ~/.pi/agent/skills/
ls -la ~/.pi/agent/extensions/

# 4. Start using pi — edits in this repo are live
pi
```

## What Gets Linked

| Repo path | Target | Purpose |
|-----------|--------|---------|
| `settings.json` | `~/.pi/agent/settings.json` | Global settings |
| `AGENTS.md` | `~/.pi/agent/AGENTS.md` | Global context file |
| `prompts/` | `~/.pi/agent/prompts/` | Prompt templates (`/name`) |
| `skills/` | `~/.pi/agent/skills/` | Skills (`/skill:name`) |
| `extensions/` | `~/.pi/agent/extensions/` | Extensions (auto-loaded) |
| `themes/` | `~/.pi/agent/themes/` | Themes (hot-reload) |

## How It Works

Pi discovers resources from `~/.pi/agent/` by default:

- **Extensions** from `~/.pi/agent/extensions/*.ts`
- **Skills** from `~/.pi/agent/skills/*/SKILL.md`
- **Prompts** from `~/.pi/agent/prompts/*.md`
- **Themes** from `~/.pi/agent/themes/*.json`
- **Settings** from `~/.pi/agent/settings.json`
- **Context** from `~/.pi/agent/AGENTS.md`

The `setup.sh` script creates symbolic links from each directory/file in this repo to the corresponding location under `~/.pi/agent/`. Edit files here, and pi picks up the changes (themes even hot-reload without restart).

## Customizing

1. **Edit any file** in this repo — changes are live immediately
2. **Add a new resource** → create the file in the right directory, run `setup.sh` again to link it
3. **Remove a resource** → delete the file, run `setup.sh` again (broken symlinks are cleaned up)

After adding/removing extensions or skills inside pi, use `/reload` to pick them up without restarting.

## Per-Project Overrides

This repo covers your **global** Pi config. For project-specific settings, create `.pi/` directories inside individual projects (e.g., `.pi/settings.json`, `.pi/prompts/`). Pi loads project-local resources **after** global ones, so they override without affecting this repo.

## Uninstall

```bash
# Remove all symlinks without deleting source files
bash setup.sh --unlink

# Or just delete the broken symlinks manually
find ~/.pi/agent/ -type l -xtype l -delete
```


## Cloning with all knowledge repos

This repo includes daily-record and personal-base as git submodules under `subrepos/`:
```bash
git clone --recursive https://github.com/ccijunk/pi-agent-workflow.git

# Or if already cloned:
git submodule update --init --recursive
```

Use `sync-knowledge.sh` to commit and push all subrepos at once:
```bash
bash sync-knowledge.sh "daily log 2026.6.26"
```
