#!/usr/bin/env bash
# Uninstalls the repo's skills and configs from an agent environment.
#
# Usage:
#   scripts/uninstall.sh [item ...] [--all] [--target DIR] [--list]
#
#   item ...      Names of skills or configs to uninstall
#   --all         Uninstall every repo skill found in the target (configs are explicit-only)
#   --target DIR  Directory to uninstall skills from (default: ~/.claude/skills)
#   --list        List repo skills and configs installed and exit
#
# Configs have fixed locations (not affected by --target):
#   claude-md → $CLAUDE_DIR/CLAUDE.md (CLAUDE_DIR defaults to ~/.claude)
#
# With no item names and no --all, an interactive picker is shown (requires a TTY).
# Symlinks are removed; real files/directories (--copy installs) are moved to
# <name>.bak.<timestamp> instead of deleted, so nothing is lost.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO/skills"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
TARGET="$HOME/.claude/skills"
ALL=false
REQUESTED=()

CONFIGS=(claude-md)

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
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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

installed_configs() {
  local name dest
  for name in "${CONFIGS[@]}"; do
    dest="$(config_dest "$name")"
    if [[ -L "$dest" || -f "$dest" ]]; then
      echo "$name"
    fi
  done
}

list_installed() {
  local found=false name dest
  for name in $(installed_skills); do
    found=true
    if [[ -L "$TARGET/$name" ]]; then
      printf '%s (symlink → %s)\n' "$name" "$(readlink "$TARGET/$name")"
    else
      printf '%s (copy)\n' "$name"
    fi
  done
  for name in $(installed_configs); do
    found=true
    dest="$(config_dest "$name")"
    if [[ -L "$dest" ]]; then
      printf '%s (config, symlink → %s)\n' "$name" "$(readlink "$dest")"
    else
      printf '%s (config, file at %s)\n' "$name" "$dest"
    fi
  done
  [[ "$found" == true ]] || echo "No repo skills or configs installed"
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

INSTALLED_SKILLS=()
while IFS= read -r name; do
  [[ -n "$name" ]] && INSTALLED_SKILLS+=("$name")
done < <(installed_skills)

INSTALLED_CONFIGS=()
while IFS= read -r name; do
  [[ -n "$name" ]] && INSTALLED_CONFIGS+=("$name")
done < <(installed_configs)

if [[ "$ALL" == true ]]; then
  if [[ ${#REQUESTED[@]} -gt 0 ]]; then
    echo "ERROR: --all cannot be combined with item names" >&2
    exit 1
  fi
  # Deliberately skills-only, mirroring install: configs require explicit selection.
  REQUESTED=("${INSTALLED_SKILLS[@]+"${INSTALLED_SKILLS[@]}"}")
  if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    echo "No repo skills installed in $TARGET — nothing to do."
    exit 0
  fi
fi

# No names and no --all → interactive picker over installed items.
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
  PICKABLE=("${INSTALLED_SKILLS[@]+"${INSTALLED_SKILLS[@]}"}" "${INSTALLED_CONFIGS[@]+"${INSTALLED_CONFIGS[@]}"}")
  if [[ ${#PICKABLE[@]} -eq 0 ]]; then
    echo "No repo skills or configs installed — nothing to do."
    exit 0
  fi
  if [[ ! -t 0 ]]; then
    echo "ERROR: no items specified and no TTY for the interactive picker." >&2
    echo "Pass item names, or use --all to uninstall every skill." >&2
    exit 1
  fi
  echo "Installed items:"
  for i in "${!PICKABLE[@]}"; do
    name="${PICKABLE[$i]}"
    if is_config "$name"; then
      printf '  %d) %s (config at %s)\n' "$((i + 1))" "$name" "$(config_dest "$name")"
    else
      printf '  %d) %s\n' "$((i + 1))" "$name"
    fi
  done
  read -r -p "Items to uninstall (numbers/names, space-separated, 'a' = all skills): " reply
  [[ -n "${reply// /}" ]] || { echo "Nothing selected, aborting." >&2; exit 1; }
  for token in $reply; do
    if [[ "$token" == "a" || "$token" == "all" ]]; then
      REQUESTED+=("${INSTALLED_SKILLS[@]+"${INSTALLED_SKILLS[@]}"}")
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

# Validate every requested name BEFORE removing anything — no partial uninstalls.
for name in "${REQUESTED[@]}"; do
  if ! is_config "$name" && [[ ! -d "$SKILLS_DIR/$name" ]]; then
    echo "ERROR: unknown item: $name (not a skill or config of this repo)" >&2
    exit 1
  fi
done

uninstall_config() {
  local name="$1"
  local dest backup
  dest="$(config_dest "$name")"
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
    echo "✓ $name removed (symlink at $dest)"
  elif [[ -f "$dest" ]]; then
    backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "✓ $name moved to $backup (was a copy — delete the backup manually if unwanted)"
  else
    echo "· $name not installed, skipping"
  fi
}

uninstall_skill() {
  local name="$1"
  local dest="$TARGET/$name"
  local backup
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
}

for name in "${REQUESTED[@]}"; do
  if is_config "$name"; then
    uninstall_config "$name"
  else
    uninstall_skill "$name"
  fi
done
