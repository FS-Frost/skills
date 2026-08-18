#!/usr/bin/env bash
# Uninstalls the repo's skills from an agent skills directory.
#
# Usage:
#   scripts/uninstall.sh [skill ...] [--all] [--target DIR] [--list]
#
#   skill ...     Names of skills to uninstall
#   --all         Uninstall every repo skill found in the target
#   --target DIR  Directory to uninstall from (default: ~/.claude/skills)
#   --list        List repo skills installed in the target and exit
#
# With no skill names and no --all, an interactive picker is shown (requires a TTY).
# Symlinks are removed; real directories (--copy installs) are moved to
# <name>.bak.<timestamp> instead of deleted, so nothing is lost.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
TARGET="$HOME/.claude/skills"
ALL=false
REQUESTED=()

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Repo skills present in the target (symlink or directory), i.e. uninstallable.
installed_skills() {
  for dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$dir")"
    if [[ -L "$TARGET/$name" || -d "$TARGET/$name" ]]; then
      echo "$name"
    fi
  done
}

list_installed() {
  local found=false
  for name in $(installed_skills); do
    found=true
    if [[ -L "$TARGET/$name" ]]; then
      printf '%s (symlink → %s)\n' "$name" "$(readlink "$TARGET/$name")"
    else
      printf '%s (copy)\n' "$name"
    fi
  done
  [[ "$found" == true ]] || echo "No repo skills installed in $TARGET"
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
    --list)
      list_installed
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

INSTALLED=()
while IFS= read -r name; do
  [[ -n "$name" ]] && INSTALLED+=("$name")
done < <(installed_skills)

if [[ "$ALL" == true ]]; then
  if [[ ${#REQUESTED[@]} -gt 0 ]]; then
    echo "ERROR: --all cannot be combined with skill names" >&2
    exit 1
  fi
  REQUESTED=("${INSTALLED[@]+"${INSTALLED[@]}"}")
  if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    echo "No repo skills installed in $TARGET — nothing to do."
    exit 0
  fi
fi

# No names and no --all → interactive picker over installed skills.
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
  if [[ ${#INSTALLED[@]} -eq 0 ]]; then
    echo "No repo skills installed in $TARGET — nothing to do."
    exit 0
  fi
  if [[ ! -t 0 ]]; then
    echo "ERROR: no skills specified and no TTY for the interactive picker." >&2
    echo "Pass skill names, or use --all to uninstall everything." >&2
    exit 1
  fi
  echo "Installed skills in $TARGET:"
  for i in "${!INSTALLED[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${INSTALLED[$i]}"
  done
  read -r -p "Skills to uninstall (numbers/names, space-separated, 'a' = all): " reply
  [[ -n "${reply// /}" ]] || { echo "Nothing selected, aborting." >&2; exit 1; }
  for token in $reply; do
    if [[ "$token" == "a" || "$token" == "all" ]]; then
      REQUESTED=("${INSTALLED[@]}")
      break
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$((token - 1))
      if (( idx < 0 || idx >= ${#INSTALLED[@]} )); then
        echo "ERROR: option out of range: $token" >&2
        exit 1
      fi
      REQUESTED+=("${INSTALLED[$idx]}")
    else
      REQUESTED+=("$token")
    fi
  done
fi

# Validate every requested name BEFORE removing anything — no partial uninstalls.
for name in "${REQUESTED[@]}"; do
  if [[ ! -d "$SKILLS_DIR/$name" ]]; then
    echo "ERROR: unknown skill: $name (not a skill of this repo)" >&2
    exit 1
  fi
done

for name in "${REQUESTED[@]}"; do
  dest="$TARGET/$name"
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
    echo "✓ $name removed (symlink)"
  elif [[ -d "$dest" ]]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "✓ $name moved to $backup (was a copy — delete the backup manually if unwanted)"
  else
    echo "· $name not installed in $TARGET, skipping"
  fi
done
