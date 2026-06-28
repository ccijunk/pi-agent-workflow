#!/usr/bin/env bash
# bootstrap.sh — Set up ccijunk's dev environment on a new machine.
#
# Clones key repos and installs dependencies.
# Works on any device — no absolute paths.
#
# Usage:
#   bash bootstrap.sh                     # Clone essential repos
#   bash bootstrap.sh --all               # Clone all known repos
#   bash bootstrap.sh --list              # List what would be cloned
#   bash bootstrap.sh --repo personal-base # Clone a specific repo
#
# After running, cd to pi-agent-workflow and start pi.
# pi will read AGENTS.md → REPO_GUIDE.md → know how to handle everything.

set -euo pipefail

CODE_DIR="${CODE_DIR:-$HOME/code}"
GITHUB_USER="ccijunk"

# ─── Repo Groups ────────────────────────────────────────────────

ESSENTIAL=(
    "pi-agent-workflow"      # Main harness — always first
    "personal-base"          # English learning curator
    "life-system"            # Life OS
)

ACTIVE=(
    "ai-workflow"            # Python workflow engine
    "skills"                 # Skills collection
)

ALL_REPOS=(
    "${ESSENTIAL[@]}"
    "${ACTIVE[@]}"
    "ai-factory"
    "ai-figure-out"
    "books-fork"
    "deer-flow"
    "vllm-ascend"
)

# ─── Helpers ────────────────────────────────────────────────────

print_header() {
    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  🚀 ccijunk's dev environment bootstrap"
    echo "══════════════════════════════════════════════════════"
    echo "  Target: $CODE_DIR"
    echo "  Date:   $(date '+%Y-%m-%d')"
    echo "══════════════════════════════════════════════════════"
    echo ""
}

check_deps() {
    if ! command -v git &> /dev/null; then
        echo "❌ git not found. Please install git first."
        exit 1
    fi
    if command -v uv &> /dev/null; then
        echo "  ✓ uv found"
    else
        echo "  ⚠️  uv not found — Python repos will need manual setup"
        echo "     Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
    echo ""
}

clone_repo() {
    local repo="$1"
    local target="$CODE_DIR/$repo"
    local url="https://github.com/$GITHUB_USER/$repo.git"

    if [ -d "$target" ]; then
        echo "  ✓ $repo already exists, updating..."
        git -C "$target" pull --ff-only 2>/dev/null || echo "    (could not pull)"
    else
        echo "  → Cloning $repo..."
        git clone "$url" "$target"
    fi

    # Install Python deps if uv + pyproject.toml exists
    if command -v uv &> /dev/null && [ -f "$target/pyproject.toml" ]; then
        echo "    Installing Python deps for $repo..."
        (cd "$target" && uv sync --quiet 2>/dev/null || echo "    (uv sync skipped)")
    fi
}

# ─── Commands ───────────────────────────────────────────────────

do_list() {
    echo "Essential repos (always needed):"
    for r in "${ESSENTIAL[@]}"; do
        echo "  • $r — https://github.com/$GITHUB_USER/$r"
    done
    echo ""
    echo "Active repos:"
    for r in "${ACTIVE[@]}"; do
        echo "  • $r — https://github.com/$GITHUB_USER/$r"
    done
    echo ""
    echo "Other known repos:"
    for r in "${ALL_REPOS[@]}"; do
        # Skip if already listed
        skip=0
        for e in "${ESSENTIAL[@]}" "${ACTIVE[@]}"; do
            [ "$r" = "$e" ] && skip=1
        done
        [ "$skip" -eq 0 ] && echo "  • $r — https://github.com/$GITHUB_USER/$r"
    done
}

do_bootstrap() {
    local repos=("$@")
    print_header
    check_deps

    mkdir -p "$CODE_DIR"

    for repo in "${repos[@]}"; do
        clone_repo "$repo"
    done

    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  ✅ Done! $# repos cloned to $CODE_DIR"
    echo "══════════════════════════════════════════════════════"
    echo ""
    echo "  Next steps:"
    echo "    cd $CODE_DIR/pi-agent-workflow"
    echo "    # start pi — it reads AGENTS.md and REPO_GUIDE.md"
    echo "    # to know everything about your repos"
    echo ""
}

# ─── Main ───────────────────────────────────────────────────────

case "${1:-}" in
    --list|-l)
        do_list
        ;;
    --all|-a)
        do_bootstrap "${ALL_REPOS[@]}"
        ;;
    --repo|-r)
        if [ -z "${2:-}" ]; then
            echo "Usage: bash bootstrap.sh --repo <repo-name>"
            exit 1
        fi
        do_bootstrap "$2"
        ;;
    --help|-h)
        echo "Usage: bash bootstrap.sh [option]"
        echo ""
        echo "Options:"
        echo "  (no args)    Clone essential repos (pi-agent-workflow, personal-base, etc.)"
        echo "  --all        Clone all known repos"
        echo "  --list       List all known repos with URLs"
        echo "  --repo NAME  Clone a specific repo"
        echo "  --help       Show this help"
        ;;
    *)
        do_bootstrap "${ESSENTIAL[@]}"
        ;;
esac
