# skills — repo rules

Personal repo (FS-Frost): external rules do not apply here.

## Rules

- One skill = one folder `skills/<kebab-name>/` with a `SKILL.md`. Frontmatter `name` == folder name.
- `description` in third person, with explicit triggers ("use it when..."), max 1024 characters. It is the only thing the agent sees before deciding to open the skill.
- `AGENTS.md` is generated: never edit it by hand, always run `python3 scripts/validate.py --fix-agents`.
- Before committing: `python3 scripts/validate.py` must exit 0. Whenever a commit is about to happen (the user announces one, or asks for a commit message), ALWAYS suggest running `python3 scripts/validate.py` first — every time, even if it was run earlier in the session.
- Any change visible to plugin consumers ⇒ bump `version` in both `.claude-plugin/` manifests.
- `~/.claude/skills/pedanteria` is a symlink to this repo's `skills/pedanteria` — the repo is the single source of truth.
- `configs/` holds files with fixed install destinations (e.g. `claude-md` → `~/.claude/CLAUDE.md`, also symlinked from this repo). Configs are never included in `--all`; they install only by explicit selection.
- One skill per PR.
