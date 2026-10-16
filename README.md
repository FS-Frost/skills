# skills

Personal collection of agent skills (Claude Code and others). One skill = one folder under `skills/` with a `SKILL.md` (frontmatter `name` + `description`) and, optionally, `reference/` and `scripts/` that the agent loads on demand.

See the skills index in [AGENTS.md](AGENTS.md).

## Requirements

- **Node.js 18+** — all scripts are Node.js. Already present on most machines with Claude Code.

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
│   ├── install.js             # cross-platform installer (symlinks or copies)
│   ├── uninstall.js           # cross-platform uninstaller
│   └── validate.js            # frontmatter validation + AGENTS.md regeneration
└── .github/workflows/validate.yml
```

## Installation

### Option A — symlinks (this machine, any agent)

All scripts are Node.js for cross-platform support (Linux, macOS, Windows):

```bash
node scripts/install.js                      # interactive picker (requires a TTY)
node scripts/install.js --all                # all skills → ~/.claude/skills
node scripts/install.js pedantry             # only pedantry
node scripts/install.js pedantry pedanteria  # several
node scripts/install.js --list               # list available skills and exit
node scripts/install.js pedantry --target ~/.codex/skills   # arbitrary target
node scripts/install.js --all --copy         # copy, for environments without symlinks
```

Besides skills, the repo ships **configs** — files with fixed destinations, installable by name:

```bash
node scripts/install.js claude-md            # symlink ~/.claude/CLAUDE.md → configs/CLAUDE.md
CLAUDE_DIR=/elsewhere node scripts/install.js claude-md   # override the ~/.claude location
```

`--all` deliberately covers skills only: installing a personal `CLAUDE.md` on someone else's machine is invasive, so configs always require explicit selection.

The picker accepts numbers, names, or `a` for all skills. In non-interactive environments (CI, containers) pass item names or `--all` explicitly. With symlinks, editing in the repo updates every agent instantly. The script is idempotent; if the target already had a real directory, it backs it up as `*.bak.<timestamp>`. Unknown skill names fail before installing anything.

> **Windows note:** symlinks require Developer Mode enabled or an admin terminal. If symlink creation fails, the installer falls back to copying automatically.

To uninstall, `scripts/uninstall.js` mirrors the same interface:

```bash
node scripts/uninstall.js                    # interactive picker over installed skills
node scripts/uninstall.js --all              # remove every repo skill from the target
node scripts/uninstall.js pedantry           # only pedantry
node scripts/uninstall.js --list             # show repo skills installed in the target
node scripts/uninstall.js pedantry --target ~/.codex/skills
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
2. Run `node scripts/validate.js --fix-agents` to validate and regenerate the index.
3. One skill per PR.
4. When publishing changes for plugin consumers: bump `version` in `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json`.

## Validation

```bash
node scripts/validate.js               # checks everything (runs in CI)
node scripts/validate.js --fix-agents  # also regenerates AGENTS.md
```
