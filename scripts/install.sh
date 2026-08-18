#!/usr/bin/env bash
# Installs the repo's skills into an agent skills directory.
#
# Usage:
#   scripts/install.sh [skill ...] [--all] [--target DIR] [--copy] [--list]
#
#   skill ...     Names of skills to install
#   --all         Install every skill under skills/
#   --target DIR  Directory to install into (default: ~/.claude/skills)
#   --copy        Copy instead of symlink (for environments that don't follow symlinks)
#   --list        List available skills and exit
#
# With no skill names and no --all, an interactive picker is shown (requires a TTY).
#
# With symlinks (default), editing in the repo updates every agent instantly.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
TARGET="$HOME/.claude/skills"
MODE="link"
ALL=false
REQUESTED=()

usage() {
  sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

list_skills() {
  for dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$dir")"
    # First line of the frontmatter description, for quick discovery.
    desc="$(sed -n 's/^description: //p' "$dir/SKILL.md" | head -n 1)"
    printf '%s — %s\n' "$name" "${desc:-(no description)}"
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
      list_skills
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
    echo "ERROR: --all cannot be combined with skill names" >&2
    exit 1
  fi
  REQUESTED=("${AVAILABLE[@]}")
fi

# No names and no --all → interactive picker.
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
  if [[ ! -t 0 ]]; then
    echo "ERROR: no skills specified and no TTY for the interactive picker." >&2
    echo "Pass skill names, or use --all to install everything." >&2
    exit 1
  fi
  echo "Available skills:"
  for i in "${!AVAILABLE[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${AVAILABLE[$i]}"
  done
  read -r -p "Skills to install (numbers/names, space-separated, 'a' = all): " reply
  [[ -n "${reply// /}" ]] || { echo "Nothing selected, aborting." >&2; exit 1; }
  for token in $reply; do
    if [[ "$token" == "a" || "$token" == "all" ]]; then
      REQUESTED=("${AVAILABLE[@]}")
      break
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$((token - 1))
      if (( idx < 0 || idx >= ${#AVAILABLE[@]} )); then
        echo "ERROR: option out of range: $token" >&2
        exit 1
      fi
      REQUESTED+=("${AVAILABLE[$idx]}")
    else
      REQUESTED+=("$token")
    fi
  done
fi

# Validate every requested name BEFORE installing anything — no partial installs.
for name in "${REQUESTED[@]}"; do
  if [[ ! -d "$SKILLS_DIR/$name" ]]; then
    echo "ERROR: unknown skill: $name" >&2
    echo "Available skills:" >&2
    list_skills >&2
    exit 1
  fi
done

mkdir -p "$TARGET"

for name in "${REQUESTED[@]}"; do
  src="$SKILLS_DIR/$name"
  dest="$TARGET/$name"

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
done
