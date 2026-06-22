#!/usr/bin/env bash
#
# setup.sh — Create or remove symlinks from this repo to ~/.pi/agent/
#
# Usage:
#   bash setup.sh         Create symlinks (idempotent)
#   bash setup.sh --unlink  Remove symlinks (keep source files)
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PI_DIR="$HOME/.pi/agent"

# Mapping: repo path → target path under PI_DIR
# Format: source_rel_path:target_path
# target_path is relative to PI_DIR; empty means same basename
LINKS=(
  "settings.json:settings.json"
  "AGENTS.md:AGENTS.md"
  "prompts/.:prompts"
  "skills/.:skills"
  "extensions/.:extensions"
  "themes/.:themes"
)

# Files (not dirs) that should be linked by individual file
FILE_LINKS=(
  "settings.json"
  "AGENTS.md"
)

# Directories that should be linked as whole directories
DIR_LINKS=(
  "prompts"
  "skills"
  "extensions"
  "themes"
)

unlink_all() {
  echo "==> Removing symlinks..."
  for entry in "${LINKS[@]}"; do
    src="${entry%%:*}"
    target="${entry#*:}"
    target_path="$PI_DIR/$target"
    if [ -L "$target_path" ]; then
      rm -v "$target_path"
    fi
  done

  # Clean up broken symlinks in PI_DIR
  find "$PI_DIR" -maxdepth 2 -type l ! -exec test -e {} \; -delete 2>/dev/null || true
  echo "==> Done."
}

link_all() {
  echo "==> Creating symlinks..."

  # Ensure PI_DIR exists
  mkdir -p "$PI_DIR"

  # Link individual files (overwrite existing symlinks)
  for file in "${FILE_LINKS[@]}"; do
    src="$REPO_DIR/$file"
    target="$PI_DIR/$file"
    if [ -e "$src" ]; then
      if [ -L "$target" ] || [ ! -e "$target" ]; then
        ln -sfv "$src" "$target"
      elif [ -f "$target" ]; then
        echo "WARNING: $target already exists as a real file, skipping"
      fi
    fi
  done

  # Link directories (overwrite existing symlinks)
  for dir in "${DIR_LINKS[@]}"; do
    src="$REPO_DIR/$dir"
    target="$PI_DIR/$dir"
    if [ -d "$src" ]; then
      if [ -L "$target" ] || [ ! -e "$target" ]; then
        ln -sfnv "$src" "$target"
      elif [ -d "$target" ]; then
        echo "WARNING: $target already exists as a real directory, skipping"
      fi
    fi
  done

  echo "==> Done. Verify with: ls -la $PI_DIR"
}

case "${1:-}" in
  --unlink|-u|remove|uninstall)
    unlink_all
    ;;
  --help|-h)
    echo "Usage: bash setup.sh [--unlink]"
    echo ""
    echo "  (no args)   Create symlinks from this repo to ~/.pi/agent/"
    echo "  --unlink    Remove symlinks (keeps source files in repo)"
    exit 0
    ;;
  *)
    link_all
    ;;
esac
