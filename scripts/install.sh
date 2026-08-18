#!/usr/bin/env bash
# Installs the repo's skills and configs into an agent environment.
#
# Usage:
#   scripts/install.sh [item ...] [--all] [--target DIR] [--copy] [--list]
#
#   item ...      Names of skills or configs to install
#   --all         Install every skill under skills/ (configs are explicit-only)
#   --target DIR  Directory to install skills into (default: ~/.claude/skills)
#   --copy        Copy instead of symlink (for environments that don't follow symlinks)
#   --list        List available skills and configs and exit
#
# Configs have fixed destinations (not affected by --target):
#   claude-md → $CLAUDE_DIR/CLAUDE.md (CLAUDE_DIR defaults to ~/.claude)
#
# With no item names and no --all, an interactive picker is shown (requires a TTY).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
TARGET="$HOME/.claude/skills"
MODE="link"
ALL=false
REQUESTED=()

CONFIGS=(claude-md)

config_src() {
  case "$1" in
    claude-md) echo "$REPO/configs/CLAUDE.md" ;;
  esac
}

config_dest() {
  case "$1" in
    claude-md) echo "$CLAUDE_DIR/CLAUDE.md" ;;
  esac
}

is_config() {
  local name
  for name in "${CONFIGS[@]}"; do
    [[ "$name" == "$1" ]] && return 0
  done
  return 1
}

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

list_items() {
  for dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$dir")"
    desc="$(sed -n 's/^description: //p' "$dir/SKILL.md" | head -n 1)"
    printf '%s — %s\n' "$name" "${desc:-(no description)}"
  done
  for name in "${CONFIGS[@]}"; do
    printf '%s — config → %s\n' "$name" "$(config_dest "$name")"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { echo "ERROR: --target requires a directory" >&2; exit 1; }
      TARGET="$2"
      shift 2
      ;;
    --all)
      ALL=true
      shift
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --list)
      list_items
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      REQUESTED+=("$1")
      shift
      ;;
  esac
done

AVAILABLE=()
for dir in "$SKILLS_DIR"/*/; do
  AVAILABLE+=("$(basename "$dir")")
done

if [[ "$ALL" == true ]]; then
  if [[ ${#REQUESTED[@]} -gt 0 ]]; then
    echo "ERROR: --all cannot be combined with item names" >&2
    exit 1
  fi
  # Deliberately skills-only: installing a personal CLAUDE.md is invasive,
  # so configs require explicit selection.
  REQUESTED=("${AVAILABLE[@]}")
fi

# No names and no --all → interactive picker.
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
  if [[ ! -t 0 ]]; then
    echo "ERROR: no items specified and no TTY for the interactive picker." >&2
    echo "Pass item names, or use --all to install every skill." >&2
    exit 1
  fi
  PICKABLE=("${AVAILABLE[@]}" "${CONFIGS[@]}")
  echo "Available items:"
  for i in "${!PICKABLE[@]}"; do
    name="${PICKABLE[$i]}"
    if is_config "$name"; then
      printf '  %d) %s (config → %s)\n' "$((i + 1))" "$name" "$(config_dest "$name")"
    else
      printf '  %d) %s\n' "$((i + 1))" "$name"
    fi
  done
  read -r -p "Items to install (numbers/names, space-separated, 'a' = all skills): " reply
  [[ -n "${reply// /}" ]] || { echo "Nothing selected, aborting." >&2; exit 1; }
  for token in $reply; do
    if [[ "$token" == "a" || "$token" == "all" ]]; then
      REQUESTED+=("${AVAILABLE[@]}")
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$((token - 1))
      if (( idx < 0 || idx >= ${#PICKABLE[@]} )); then
        echo "ERROR: option out of range: $token" >&2
        exit 1
      fi
      REQUESTED+=("${PICKABLE[$idx]}")
    else
      REQUESTED+=("$token")
    fi
  done
fi

# Validate every requested name BEFORE installing anything — no partial installs.
for name in "${REQUESTED[@]}"; do
  if ! is_config "$name" && [[ ! -d "$SKILLS_DIR/$name" ]]; then
    echo "ERROR: unknown item: $name" >&2
    echo "Available items:" >&2
    list_items >&2
    exit 1
  fi
done

install_config() {
  local name="$1"
  local src dest backup
  src="$(config_src "$name")"
  dest="$(config_dest "$name")"
  mkdir -p "$(dirname "$dest")"

  # If the destination is a real file (not a symlink), back it up before replacing.
  if [[ -f "$dest" && ! -L "$dest" ]]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "⚠ backup: $dest → $backup"
  fi

  if [[ "$MODE" == "copy" ]]; then
    rm -f "$dest"
    cp "$src" "$dest"
    echo "✓ $name → $dest (copy)"
  else
    ln -sfn "$src" "$dest"
    echo "✓ $name → $dest (symlink)"
  fi
}

install_skill() {
  local name="$1"
  local src="$SKILLS_DIR/$name"
  local dest="$TARGET/$name"
  local backup

  # If the destination is a real directory (not a symlink), back it up before replacing.
  if [[ -d "$dest" && ! -L "$dest" ]]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "⚠ backup: $dest → $backup"
  fi

  if [[ "$MODE" == "copy" ]]; then
    rm -f "$dest"
    cp -R "$src" "$dest"
    echo "✓ $name → $dest (copy)"
  else
    ln -sfn "$src" "$dest"
    echo "✓ $name → $dest (symlink)"
  fi
}

mkdir -p "$TARGET"

for name in "${REQUESTED[@]}"; do
  if is_config "$name"; then
    install_config "$name"
  else
    install_skill "$name"
  fi
done
