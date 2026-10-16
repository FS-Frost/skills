#!/usr/bin/env node
// Installs the repo's skills and configs into an agent environment.
//
// Usage:
//   scripts/install.sh [item ...] [--all] [--target DIR] [--copy] [--list]
//   node scripts/install.js [item ...] [--all] [--target DIR] [--copy] [--list]
//
//   item ...      Names of skills or configs to install
//   --all         Install every skill under skills/ (configs are explicit-only)
//   --target DIR  Directory to install skills into (default: ~/.claude/skills)
//   --copy        Copy instead of symlink (for environments that don't follow symlinks)
//   --list        List available skills and configs and exit
//
// Configs have fixed destinations (not affected by --target):
//   claude-md → CLAUDE_DIR/CLAUDE.md (CLAUDE_DIR defaults to ~/.claude)
//
// With no item names and no --all, an interactive picker is shown (requires a TTY).
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

function configSrc(name) {
  if (name === "claude-md") return path.join(REPO, "configs", "CLAUDE.md");
  throw new Error(`unknown config: ${name}`);
}

function configDest(name) {
  if (name === "claude-md") return path.join(CLAUDE_DIR, "CLAUDE.md");
  throw new Error(`unknown config: ${name}`);
}

function isConfig(name) {
  return CONFIGS.includes(name);
}

function availableSkills() {
  if (!fs.existsSync(SKILLS_DIR)) return [];
  return fs
    .readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function skillDescription(name) {
  const skillMd = path.join(SKILLS_DIR, name, "SKILL.md");
  if (!fs.existsSync(skillMd)) return "(no description)";
  const content = fs.readFileSync(skillMd, "utf8");
  const match = content.match(/^description:\s+(.+)/m);
  return match ? match[1].trim().replace(/^['"]|['"]$/g, "") : "(no description)";
}

function listItems() {
  for (const name of availableSkills()) {
    console.log(`${name} — ${skillDescription(name)}`);
  }
  for (const name of CONFIGS) {
    console.log(`${name} — config → ${configDest(name)}`);
  }
}

function timestamp() {
  const now = new Date();
  return now
    .toISOString()
    .replace(/[-:T]/g, "")
    .replace(/\.\d+Z$/, "");
}

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function copyRecursive(src, dest) {
  fs.cpSync(src, dest, { recursive: true });
}

function removePath(p) {
  if (!fs.existsSync(p) && !isSymlink(p)) return;
  const stat = fs.lstatSync(p);
  if (stat.isDirectory() && !stat.isSymbolicLink()) {
    fs.rmSync(p, { recursive: true, force: true });
  } else {
    fs.unlinkSync(p);
  }
}

function isSymlink(p) {
  try {
    fs.lstatSync(p);
    return fs.lstatSync(p).isSymbolicLink();
  } catch {
    return false;
  }
}

function trySymlink(src, dest) {
  removePath(dest);
  const type = fs.statSync(src).isDirectory() ? "junction" : "file";
  try {
    fs.symlinkSync(src, dest, type);
    return true;
  } catch {
    return false;
  }
}

function installItem(src, dest, name, mode) {
  mkdirp(path.dirname(dest));

  // Back up real (non-symlink) destinations.
  if (fs.existsSync(dest) && !isSymlink(dest)) {
    const backup = `${dest}.bak.${timestamp()}`;
    fs.renameSync(dest, backup);
    console.log(`⚠ backup: ${dest} → ${backup}`);
  }

  if (mode === "copy") {
    removePath(dest);
    copyRecursive(src, dest);
    console.log(`✓ ${name} → ${dest} (copy)`);
  } else {
    if (trySymlink(src, dest)) {
      console.log(`✓ ${name} → ${dest} (symlink)`);
    } else {
      copyRecursive(src, dest);
      console.log(
        `✓ ${name} → ${dest} (copy — symlink unavailable, ` +
          `enable Developer Mode or use --copy to silence this)`
      );
    }
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
  console.log("Available items:");
  pickable.forEach((name, i) => {
    if (isConfig(name)) {
      console.log(`  ${i + 1}) ${name} (config → ${configDest(name)})`);
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

async function interactivePick(pickable) {
  if (!process.stdin.isTTY) {
    console.error(
      "ERROR: no items specified and no TTY for the interactive picker."
    );
    console.error("Pass item names, or use --all to install every skill.");
    process.exit(1);
  }

  const skills = availableSkills();
  const validNames = new Set([...skills, ...CONFIGS]);
  showMenu(pickable);

  while (true) {
    const reply = await ask(
      "Items to install (numbers/names, space-separated, 'a' = all skills): "
    );
    const result = parseReply(reply, pickable, skills, validNames);
    if (result.error) {
      console.error(`ERROR: ${result.error} Try again.`);
      continue;
    }
    return result.selected;
  }
}

function usage() {
  const lines = fs
    .readFileSync(__filename, "utf8")
    .split("\n")
    .slice(1, 17)
    .map((l) => l.replace(/^\/\/\s?/, ""));
  console.log(lines.join("\n"));
}

async function main() {
  let target = DEFAULT_TARGET;
  let mode = "link";
  let installAll = false;
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
        installAll = true;
        break;
      case "--copy":
        mode = "copy";
        break;
      case "--list":
        listItems();
        process.exit(0);
      case "-h":
      case "--help":
        usage();
        process.exit(0);
      default:
        if (args[i].startsWith("-")) {
          console.error(`ERROR: unknown option: ${args[i]}`);
          usage();
          process.exit(1);
        }
        requested.push(args[i]);
    }
  }

  const skills = availableSkills();

  if (installAll) {
    if (requested.length > 0) {
      console.error("ERROR: --all cannot be combined with item names");
      process.exit(1);
    }
    requested.push(...skills);
  }

  if (requested.length === 0) {
    const pickable = [...skills, ...CONFIGS];
    requested.push(...(await interactivePick(pickable)));
  }

  // Validate all names before installing anything.
  for (const name of requested) {
    if (
      !isConfig(name) &&
      !fs.existsSync(path.join(SKILLS_DIR, name))
    ) {
      console.error(`ERROR: unknown item: ${name}`);
      listItems();
      process.exit(1);
    }
  }

  mkdirp(target);

  for (const name of requested) {
    if (isConfig(name)) {
      installItem(configSrc(name), configDest(name), name, mode);
    } else {
      installItem(
        path.join(SKILLS_DIR, name),
        path.join(target, name),
        name,
        mode
      );
    }
  }
}

main();
