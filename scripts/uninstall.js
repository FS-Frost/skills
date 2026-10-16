#!/usr/bin/env node
// Uninstalls the repo's skills and configs from an agent environment.
//
// Usage:
//   scripts/uninstall.sh [item ...] [--all] [--target DIR] [--list]
//   node scripts/uninstall.js [item ...] [--all] [--target DIR] [--list] [--clean-backups]
//
//   item ...          Names of skills or configs to uninstall
//   --all             Uninstall every repo skill found in the target (configs are explicit-only)
//   --target DIR      Directory to uninstall skills from (default: ~/.claude/skills)
//   --list            List repo skills and configs installed and exit
//   --clean-backups   Remove all *.bak.* files left by previous installs/uninstalls
//
// Configs have fixed locations (not affected by --target):
//   claude-md → CLAUDE_DIR/CLAUDE.md (CLAUDE_DIR defaults to ~/.claude)
//
// With no item names and no --all, an interactive picker is shown (requires a TTY).
// Symlinks are removed; real files/directories (--copy installs) are moved to
// <name>.bak.<timestamp> instead of deleted, so nothing is lost.
"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");

const REPO = path.resolve(__dirname, "..");
const SKILLS_DIR = path.join(REPO, "skills");
const CLAUDE_DIR = process.env.CLAUDE_DIR || path.join(os.homedir(), ".claude");
const DEFAULT_TARGET = path.join(os.homedir(), ".claude", "skills");

const CONFIGS = ["claude-md"];

function configDest(name) {
  if (name === "claude-md") return path.join(CLAUDE_DIR, "CLAUDE.md");
  throw new Error(`unknown config: ${name}`);
}

function isConfig(name) {
  return CONFIGS.includes(name);
}

function repoSkillNames() {
  if (!fs.existsSync(SKILLS_DIR)) return [];
  return fs
    .readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function isSymlink(p) {
  try {
    return fs.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

function pathExists(p) {
  try {
    fs.lstatSync(p);
    return true;
  } catch {
    return false;
  }
}

function resolveLink(p) {
  try {
    return fs.realpathSync(p);
  } catch {
    return "?";
  }
}

function installedSkills(target) {
  return repoSkillNames().filter((name) => {
    const dest = path.join(target, name);
    return isSymlink(dest) || (pathExists(dest) && fs.statSync(dest).isDirectory());
  });
}

function installedConfigs() {
  return CONFIGS.filter((name) => {
    const dest = configDest(name);
    return isSymlink(dest) || (pathExists(dest) && fs.statSync(dest).isFile());
  });
}

function listInstalled(target) {
  let found = false;
  for (const name of installedSkills(target)) {
    found = true;
    const dest = path.join(target, name);
    if (isSymlink(dest)) {
      console.log(`${name} (symlink → ${resolveLink(dest)})`);
    } else {
      console.log(`${name} (copy)`);
    }
  }
  for (const name of installedConfigs()) {
    found = true;
    const dest = configDest(name);
    if (isSymlink(dest)) {
      console.log(`${name} (config, symlink → ${resolveLink(dest)})`);
    } else {
      console.log(`${name} (config, file at ${dest})`);
    }
  }
  if (!found) console.log("No repo skills or configs installed");
}

function timestamp() {
  const now = new Date();
  return now
    .toISOString()
    .replace(/[-:T]/g, "")
    .replace(/\.\d+Z$/, "");
}

function uninstallConfig(name) {
  const dest = configDest(name);
  if (isSymlink(dest)) {
    fs.unlinkSync(dest);
    console.log(`✓ ${name} removed (symlink at ${dest})`);
  } else if (pathExists(dest) && fs.statSync(dest).isFile()) {
    const backup = `${dest}.bak.${timestamp()}`;
    fs.renameSync(dest, backup);
    console.log(
      `✓ ${name} moved to ${backup} ` +
        `(was a copy — delete the backup manually if unwanted)`
    );
  } else {
    console.log(`· ${name} not installed, skipping`);
  }
}

function uninstallSkill(name, target) {
  const dest = path.join(target, name);
  if (isSymlink(dest)) {
    fs.unlinkSync(dest);
    console.log(`✓ ${name} removed (symlink)`);
  } else if (pathExists(dest) && fs.statSync(dest).isDirectory()) {
    const backup = `${dest}.bak.${timestamp()}`;
    fs.renameSync(dest, backup);
    console.log(
      `✓ ${name} moved to ${backup} ` +
        `(was a copy — delete the backup manually if unwanted)`
    );
  } else {
    console.log(`· ${name} not installed in ${target}, skipping`);
  }
}

function ask(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

function showMenu(pickable) {
  console.log("Installed items:");
  pickable.forEach((name, i) => {
    if (isConfig(name)) {
      console.log(`  ${i + 1}) ${name} (config at ${configDest(name)})`);
    } else {
      console.log(`  ${i + 1}) ${name}`);
    }
  });
}

function parseReply(reply, pickable, allItems, validNames) {
  const tokens = reply
    .split(/[\s,]+/)
    .map((t) => t.trim())
    .filter(Boolean);
  if (tokens.length === 0) return { error: "Nothing selected." };

  const selected = [];
  for (const token of tokens) {
    if (token === "a" || token === "all") {
      selected.push(...allItems);
    } else if (/^\d+$/.test(token)) {
      const idx = parseInt(token, 10) - 1;
      if (idx < 0 || idx >= pickable.length) {
        return { error: `Option out of range: ${token}` };
      }
      selected.push(pickable[idx]);
    } else if (validNames && !validNames.has(token)) {
      return { error: `Unknown item: ${token}` };
    } else {
      selected.push(token);
    }
  }
  return { selected };
}

async function interactivePick(pickable, target) {
  if (pickable.length === 0) {
    console.log("No repo skills or configs installed — nothing to do.");
    process.exit(0);
  }
  if (!process.stdin.isTTY) {
    console.error(
      "ERROR: no items specified and no TTY for the interactive picker."
    );
    console.error("Pass item names, or use --all to uninstall every skill.");
    process.exit(1);
  }

  const skills = installedSkills(target);
  const validNames = new Set([...repoSkillNames(), ...CONFIGS]);
  const backups = [...findBackups(target), ...findBackups(CLAUDE_DIR)];

  showMenu(pickable);
  if (backups.length > 0) {
    console.log(`\n  c) clean ${backups.length} backup(s)`);
  }

  while (true) {
    const reply = await ask(
      "Items to uninstall (numbers/names, space-separated, 'a' = all skills" +
        (backups.length > 0 ? ", 'c' = clean backups" : "") +
        "): "
    );
    const trimmed = reply.trim().toLowerCase();
    if (trimmed === "c" && backups.length > 0) {
      cleanBackups(target);
      process.exit(0);
    }
    const result = parseReply(reply, pickable, skills, validNames);
    if (result.error) {
      console.error(`ERROR: ${result.error} Try again.`);
      continue;
    }
    return result.selected;
  }
}

function findBackups(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (/\.bak\.\d{14}$/.test(entry.name)) {
      results.push(path.join(dir, entry.name));
    }
  }
  return results;
}

function cleanBackups(target) {
  const backups = [
    ...findBackups(target),
    ...findBackups(CLAUDE_DIR),
  ];
  if (backups.length === 0) {
    console.log("No backups found.");
    return;
  }
  for (const p of backups) {
    const stat = fs.lstatSync(p);
    if (stat.isDirectory()) {
      fs.rmSync(p, { recursive: true, force: true });
    } else {
      fs.unlinkSync(p);
    }
    console.log(`✓ removed ${p}`);
  }
  console.log(`${backups.length} backup(s) cleaned.`);
}

function usage() {
  const lines = fs
    .readFileSync(__filename, "utf8")
    .split("\n")
    .slice(1, 20)
    .map((l) => l.replace(/^\/\/\s?/, ""));
  console.log(lines.join("\n"));
}

async function main() {
  let target = DEFAULT_TARGET;
  let uninstallAll = false;
  let doList = false;
  let doCleanBackups = false;
  let doHelp = false;
  const requested = [];

  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--target":
        if (i + 1 >= args.length) {
          console.error("ERROR: --target requires a directory");
          process.exit(1);
        }
        target = args[++i];
        break;
      case "--all":
        uninstallAll = true;
        break;
      case "--list":
        doList = true;
        break;
      case "--clean-backups":
        doCleanBackups = true;
        break;
      case "-h":
      case "--help":
        doHelp = true;
        break;
      default:
        if (args[i].startsWith("-")) {
          console.error(`ERROR: unknown option: ${args[i]}`);
          usage();
          process.exit(1);
        }
        requested.push(args[i]);
    }
  }

  if (doHelp) { usage(); process.exit(0); }
  if (doList) { listInstalled(target); process.exit(0); }
  if (doCleanBackups) { cleanBackups(target); process.exit(0); }

  const skills = installedSkills(target);
  const configs = installedConfigs();

  if (uninstallAll) {
    if (requested.length > 0) {
      console.error("ERROR: --all cannot be combined with item names");
      process.exit(1);
    }
    requested.push(...skills);
    if (requested.length === 0) {
      console.log(`No repo skills installed in ${target} — nothing to do.`);
      process.exit(0);
    }
  }

  if (requested.length === 0) {
    const pickable = [...skills, ...configs];
    requested.push(...(await interactivePick(pickable, target)));
  }

  // Validate all names before removing anything.
  for (const name of requested) {
    if (!isConfig(name) && !fs.existsSync(path.join(SKILLS_DIR, name))) {
      console.error(
        `ERROR: unknown item: ${name} (not a skill or config of this repo)`
      );
      process.exit(1);
    }
  }

  for (const name of requested) {
    if (isConfig(name)) {
      uninstallConfig(name);
    } else {
      uninstallSkill(name, target);
    }
  }
}

main();
