# skills

Personal collection of agent skills (Claude Code and others). One skill = one folder under `skills/` with a `SKILL.md` (frontmatter `name` + `description`) and, optionally, `reference/` and `scripts/` that the agent loads on demand.

See the skills index in [AGENTS.md](AGENTS.md).

## Structure

```
skills/
├── AGENTS.md                  # generated index (do not edit by hand)
├── skills/
│   ├── pedanteria/
│   │   └── SKILL.md
│   └── pedantry/
│       └── SKILL.md
├── configs/
│   └── CLAUDE.md              # personal global CLAUDE.md (installable as `claude-md`)
├── .claude-plugin/
│   ├── marketplace.json       # this repo IS a Claude Code marketplace
│   └── plugin.json
├── scripts/
│   ├── install.sh             # symlinks (or copies) into a skills directory
│   ├── uninstall.sh           # removes installed skills from a skills directory
│   └── validate.py            # frontmatter validation + AGENTS.md regeneration
└── .github/workflows/validate.yml
```

## Installation

### Option A — symlinks (this machine, any agent)

```bash
bash scripts/install.sh                      # interactive picker (requires a TTY)
bash scripts/install.sh --all                # all skills → ~/.claude/skills
bash scripts/install.sh pedantry             # only pedantry
bash scripts/install.sh pedantry pedanteria  # several
bash scripts/install.sh --list               # list available skills and exit
bash scripts/install.sh pedantry --target ~/.codex/skills   # arbitrary target
bash scripts/install.sh --all --copy         # copy, for environments without symlinks
```

Besides skills, the repo ships **configs** — files with fixed destinations, installable by name:

```bash
bash scripts/install.sh claude-md            # symlink ~/.claude/CLAUDE.md → configs/CLAUDE.md
CLAUDE_DIR=/elsewhere bash scripts/install.sh claude-md   # override the ~/.claude location
```

`--all` deliberately covers skills only: installing a personal `CLAUDE.md` on someone else's machine is invasive, so configs always require explicit selection.

The picker accepts numbers, names, or `a` for all skills. In non-interactive environments (CI, containers) pass item names or `--all` explicitly. With symlinks, editing in the repo updates every agent instantly. The script is idempotent; if the target already had a real directory, it backs it up as `*.bak.<timestamp>`. Unknown skill names fail before installing anything.

To uninstall, `scripts/uninstall.sh` mirrors the same interface:

```bash
bash scripts/uninstall.sh                    # interactive picker over installed skills
bash scripts/uninstall.sh --all              # remove every repo skill from the target
bash scripts/uninstall.sh pedantry           # only pedantry
bash scripts/uninstall.sh --list             # show repo skills installed in the target
bash scripts/uninstall.sh pedantry --target ~/.codex/skills
```

Symlinks are removed; real directories (`--copy` installs) are moved to `<name>.bak.<timestamp>` instead of deleted. It only touches skills that belong to this repo.

### Option B — Claude Code plugin (other machines / other people)

```bash
claude plugin marketplace add FS-Frost/skills
claude plugin install skills@skills
```

Skills installed via plugin are namespaced: `/skills:pedanteria` instead of `/pedanteria`.

> **Do not mix A and B on the same machine**: every skill would end up duplicated (with and without namespace). Rule of thumb: symlinks on the machine where this repo lives; plugin everywhere else.

## Adding a skill

1. Create `skills/<kebab-name>/SKILL.md` with frontmatter `name` (== folder) and `description` (with explicit triggers: "use it when...").
2. Run `python3 scripts/validate.py --fix-agents` to validate and regenerate the index.
3. One skill per PR.
4. When publishing changes for plugin consumers: bump `version` in `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`.

## Validation

```bash
python3 scripts/validate.py               # checks everything (runs in CI)
python3 scripts/validate.py --fix-agents  # also regenerates AGENTS.md
```
