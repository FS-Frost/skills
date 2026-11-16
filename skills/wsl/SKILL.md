---
name: wsl
description: Diagnoses and maintains WSL2 virtual disks on Windows. Reclaims C: space by cleaning up inside Linux and Docker, compacting any distro's ext4.vhdx or Docker's docker_data.vhdx, backing it up, setting it sparse so it stops growing, or moving it to another drive. Use it when the user says WSL or Docker takes too much space, C: is full after deleting files in Linux, the .vhdx won't shrink, or they want to compact, back up or move a distro, enable sparseVhd or --set-sparse, or when wsl fails with Wsl/Service/WSAETIMEDOUT. Triggers: "ext4.vhdx", "docker_data.vhdx", "compact wsl", "free up wsl space", "sparse", "Optimize-VHD", "diskpart compact vdisk", "wsl --manage --move", "wsl --shutdown", "/wsl".
argument-hint: "[distro] [goal: diagnose | clean | compact | sparse | backup | move]"
---

# Skill: WSL — virtual disks

Goal: get Windows to reclaim the space Linux has already freed inside a WSL2 distro (or Docker's data disk), without losing data, and keep the disk from bloating again.

Language: reply in the user's language.

## Why it happens

Every WSL2 distro lives in a dynamic `ext4.vhdx`. Docker Desktop keeps its images, containers and volumes in a separate `docker_data.vhdx`. These files **grow** when Linux writes, but **do not shrink** when Linux deletes. Deleting 100 GB inside the distro gives nothing back to C: until the `.vhdx` is compacted or set sparse.

## Rules

- **Reading and diagnosing is free.** Examples: `wsl --version`, `wsl -l -v`, `wsl --help`, reading the registry, `Get-Item` for sizes, `fsutil sparse queryflag`, `df -h` and `du` inside the distro, `docker system df`.
- **Before every action that changes something, tell the user in one line what you will do and why, and wait for their OK.** One OK covers only that action. This includes deleting files inside Linux, `docker ... prune`, `fstrim`, editing `.wslconfig`, `wsl --shutdown`, compacting, copying the backup, `--set-sparse`, `--move`, and starting the distro once its disk has been modified.
- **Never** use `wsl --unregister`, delete a `.vhdx`, or pass `--allow-unsafe` without asking explicitly and explaining the risk. `--unregister` erases the whole distro.
- **Don't invent flags.** Check every command against `wsl --help` on the actual machine. Sparse, export, import and `--move` have changed between WSL versions, and older versions lack some of them.
- Compacting, copying the disk, `--set-sparse` and `--move` require **PowerShell as Administrator**. If the terminal isn't elevated, say so and stop.

## Quirks of `wsl.exe` output

- `wsl -l -v` and `wsl --help` print UTF-16. In PowerShell it shows up with spaces between letters. To search that output, clean it first: `(wsl --help) -join "`n" -replace "`0",""`.
- `wsl --help` exits with a non-zero code. That is not an error.
- The output language follows Windows. Don't search for literal English strings.

## Pick the path by goal

| Goal | Steps |
|---|---|
| `diagnose` | Section 1 only. Report and propose a plan. |
| `clean` | Section 1 → step 0 (and 0b if Docker). |
| `compact` | Full flow, steps 0–7, skipping 6 if the user doesn't want sparse. |
| `sparse` | Section 1 → steps 3, 5, 6, 7. Back up first. |
| `backup` | Section 1 → step 3 → step 5. |
| `move` | Section 1 → step 3 → step 5 → section 3. |
| none given | Section 1, then recommend a path based on what you found. |

## 1. Diagnosis (read-only)

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
wsl --version
wsl -l -v
Get-Content "$env:USERPROFILE\.wslconfig"
Get-PSDrive -PSProvider FileSystem              # free space on C: and on any other drive usable for backup or move
Get-Command Optimize-VHD -ErrorAction SilentlyContinue   # present only if the Hyper-V module is installed
```

Find every disk, distros and Docker:

```powershell
$disks = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | ForEach-Object {
  $p = Get-ItemProperty $_.PSPath
  if ($p.DistributionName) {
    $vhd = (Join-Path $p.BasePath 'ext4.vhdx') -replace '^\\\\\?\\',''
    if (Test-Path -LiteralPath $vhd) { [pscustomobject]@{ Name=$p.DistributionName; VHD=$vhd } }
  }
}
$disks += Get-ChildItem "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter *.vhdx -ErrorAction SilentlyContinue |
  ForEach-Object { [pscustomobject]@{ Name="Docker ($($_.Name))"; VHD=$_.FullName } }
$disks | Select-Object Name, VHD, @{n='GB';e={[math]::Round((Get-Item -LiteralPath $_.VHD).Length/1GB,1)}} | Sort-Object GB -Descending
```

- Some distros, such as `docker-desktop`, register their `BasePath` with the `\\?\` prefix. `Test-Path` and `Get-Item` without `-LiteralPath` fail on it, which is why the script strips it.
- **Docker's data disk is not a registered distro.** Recent Docker Desktop versions keep it at `%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx`; older ones at `%LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx`. A custom location can be set in Docker Desktop → Settings → Resources → Advanced. It is often the biggest disk on the machine.
- Microsoft Store distros keep their disk at `%LOCALAPPDATA%\Packages\<Package>\LocalState\ext4.vhdx`. Imported ones keep it wherever it was imported to.
- Compare each `.vhdx` size with the real usage from `wsl -d <Distro> -- df -h /` (or `docker system df` for Docker). The gap is what compaction can recover.
- Find what takes space inside Linux: `wsl -d <Distro> -- sh -c "du -xh --max-depth=1 / 2>/dev/null | sort -h | tail -15"`, then drill into the largest directory, usually `/home/<user>`.
- If there are several similar distros (e.g. `Ubuntu` and `Ubuntu-24.04`), they are **independent installs**, each with its own disk. Identify the one in use with:
  - the `*` in `wsl -l -v`, which marks the default distro;
  - `/etc/os-release` and `whoami` inside each one;
  - each `.vhdx`'s `LastWriteTime`.

## 2. Reclaiming space

Follow this order. Before each step, explain what you'll do and ask for the OK.

0. **Free space inside Linux.** Compacting without deleting anything first recovers almost nothing. Usual suspects:
   - `~/.cache` (pip, npm, yarn, browsers), stray `node_modules`, old build output and virtualenvs;
   - `sudo apt-get clean` (or the distro's package manager equivalent);
   - `sudo journalctl --vacuum-size=200M`.

   Show the user what you found with sizes and let them choose. Never delete anything under `/home` without their explicit choice of each item.

   0b. **Clean up Docker** if its disk is large. Show `docker system df` first, then propose one at a time:
   - `docker builder prune` — build cache, usually the biggest win and the safest;
   - `docker image prune -a` — every image not used by a container; they'll be pulled or rebuilt again;
   - `docker container prune` — stopped containers;
   - `docker volume prune` — **can delete databases and other persistent data.** Only propose it after listing the volumes with `docker volume ls` and the user confirms they're disposable.

1. **`fstrim` with the distro running**: `wsl -d <Distro> -u root -- sh -c "sync; fstrim -av"`.
   - Marks blocks Linux no longer uses as free, so compaction can reclaim them.
   - It's normal for it to report hundreds of GiB: it walks all the free space in the filesystem, not just what was deleted today.
   - For `docker_data.vhdx`, there is no user distro to run it from. Compaction still works, but may recover less.
2. **Configure `.wslconfig`**: add `sparseVhd=true` under `[experimental]`, leaving everything else untouched.
   - It only affects disks created afterwards. Existing ones don't change.
3. **Shut down WSL**:
   - Ask the user to quit Docker Desktop from the tray icon → *Quit*. Closing the window isn't enough.
   - Confirm no processes remain: `Get-Process | ? Name -like '*docker*'`.
   - Run `wsl --shutdown` and check with `wsl -l -v` that every distro says `Stopped`.
4. **Compact** with WSL shut down:
   - If `Optimize-VHD` exists: `Optimize-VHD -Path <vhdx> -Mode Full`.
   - Otherwise (e.g. Windows Home), write a diskpart script and run it:

     ```powershell
     $script = "$env:TEMP\compact-wsl.txt"
     @(
       'select vdisk file="<vhdx>"'
       'attach vdisk readonly'
       'compact vdisk'
       'detach vdisk'
       'exit'
     ) | Set-Content -Encoding ascii $script
     diskpart /s $script
     ```

   - Record the size before and after.
5. **Back up** the already-compacted disk, before enabling sparse or moving:
   - Check first that the destination has at least the `.vhdx` size free (`Get-PSDrive`). If C: doesn't, propose another drive. Backing up **after** compacting is usually what makes it fit.
   - Copy with `Copy-Item -LiteralPath <vhdx> <destination>`, then check that both `Length` values match. A hash (`Get-FileHash`) takes about as long as the copy: offer it, don't run it by default.
   - To restore: `wsl --shutdown` and replace the original with the copy.
   - Alternative, if `wsl --help` lists it: `wsl --export <Distro> <file> --format vhd`, restored with `wsl --import ... --vhd`.
6. **Enable sparse**: `wsl --manage <Distro> --set-sparse true`.
   - Verify with `fsutil sparse queryflag <vhdx>`.
   - If WSL refuses and asks for `--allow-unsafe`, **stop**. Explain the risk and offer the alternative: skip sparse and compact by hand when needed.
   - Doesn't apply to `docker_data.vhdx`: it isn't a registered distro.
7. **Verify**:
   - Start the distro and run `df -h /`, `whoami` and `ls ~` to confirm it boots and the data is there. For Docker: open Docker Desktop and run `docker images`.
   - Check C:'s free space.
   - Remind the user they can reopen Docker.

## 3. Moving a disk to another drive

When C: is short on space and another drive has room, moving often beats compacting. Do it after compacting (smaller copy) and with a backup in place.

- **Distro**: `wsl --manage <Distro> --move <new folder>`, only if `wsl --help` lists `--move`. Without it, the fallback is `wsl --export` + `wsl --unregister` + `wsl --import`, which goes through `--unregister`: explain the risk, confirm the export is complete, and get an explicit OK for that step alone.
- **Docker**: Docker Desktop → Settings → Resources → Advanced → *Disk image location*. Docker moves the disk itself. Don't move `docker_data.vhdx` by hand.
- Afterwards, verify as in step 7 and rerun the diagnosis script to confirm the new path.

## Long-running operations

Compacting, copying and moving take tens of minutes and show no progress.

- Run them in the background with a completion marker, so you get notified instead of polling:

  ```powershell
  Optimize-VHD -Path <vhdx> -Mode Full *> "$env:TEMP\wsl-op.log"; "DONE ok=$? $(Get-Date)" | Add-Content "$env:TEMP\wsl-op.log"
  ```

  Use your harness's background execution if it has one. If it doesn't, give the user the command to run in their own admin window and ask them to tell you when it's done.
- Tell the user it has no progress bar and don't make up percentages or time estimates.

## Risks and reversibility

| Step | Risk | Reversible? |
|---|---|---|
| Deleting inside Linux | Losing files the user still needed. | No. That's why each item needs their choice. |
| `docker ... prune` | Images and cache come back on rebuild. `volume prune` can destroy data. | Images/cache: yes, rebuilding. Volumes: no. |
| `fstrim` | Very low. Only touches empty blocks. | Nothing to undo: data doesn't change. |
| `sparseVhd=true` in `.wslconfig` | None on existing data. | Yes, by removing the line. |
| `wsl --shutdown` | Anything unsaved in WSL and Docker is lost. | Yes, everything starts again. |
| Compacting | Low. A power cut or interruption midway can corrupt the disk. | Can't be undone, but content doesn't change. |
| `--set-sparse true` | **The one with real risk.** Experimental; there have been corruption reports. Some versions require `--allow-unsafe`. | Yes, with `--set-sparse false`. Damage already done isn't reverted. |
| `--move` | Interruption midway. | Yes, moving back. Keep the backup until verified. |

The biggest overall risk is having no backup. If the disk doesn't fit for export before compacting, back it up after compacting and before `--set-sparse` or `--move`.

## What to expect (observed in practice)

- **Duration**: compacting a ~240 GB `.vhdx` took ~70 minutes, and copying a ~129 GB `.vhdx` to the same drive, ~66 minutes.
- **You won't get down to real usage**: after compacting, the `.vhdx` stayed at ~129 GB with 92 GB used in Linux. The `.vhdx` is freed in large blocks, and a block with even a little data can't be released. After a mass deletion, fragmentation leaves that gap. Sparse plus a later `fstrim` can recover part of it.
- **Temporary space**: while `Optimize-VHD` runs, C:'s free space can drop by several GB. It comes back when it finishes.
- **`Copy-Item` reserves the whole file up front**: the destination size doesn't show progress. To know how long it's been running, use the destination file's `CreationTime`.
- **C:'s free space can rise after `wsl --shutdown`**: the VM's swap and memory are released.
- **On a sparse disk, `Length` isn't what it occupies**: measure C:'s free space or "Size on disk" in Properties.

## Final report

End with this, filled with real values only:

- Disks touched: path, size before → after.
- C: free space before → after.
- Backup: where it is, its size, and when it's safe to delete it.
- How to revert each change made (sparse, `.wslconfig`, move).
- Recommended maintenance for this setup (next section).

## Maintenance

- With a sparse disk: after deleting a lot inside Linux, run `sudo fstrim -av`. It frees the space in Windows without shutting anything down.
- Without sparse: repeat `fstrim`, `wsl --shutdown` and compaction when the `.vhdx` grows a lot again.
- For Docker: `docker builder prune` from time to time, then compact `docker_data.vhdx` if it doesn't shrink.
- Once the sparse or moved disk has been working fine for a few days, the backup can be deleted. Only with the user's OK.

## If `wsl` fails with `Wsl/Service/WSAETIMEDOUT`

It tends to happen after mass scans or deletions that fragment the WSL kernel's RAM. If a shell inside the distro is still open, run as root:

```sh
sync; echo 3 > /proc/sys/vm/drop_caches; echo 1 > /proc/sys/vm/compact_memory
```

If there's no access, `wsl --shutdown` from Windows. It counts as an action that changes something: ask for the OK.

To prevent it, propose `autoMemoryReclaim=gradual` in `.wslconfig` (under `[experimental]` in the versions that introduced it). Check the current WSL documentation for the installed version before writing it: the setting's section and values have changed.

## Anti-patterns

- Compacting before freeing anything inside Linux or Docker.
- Compacting with the distro or Docker running.
- Chaining several actions under a single OK.
- `docker volume prune` or deleting under `/home` without the user picking each item.
- Forcing `--allow-unsafe` or `--unregister` to "finish faster".
- Using flags from memory without checking them against `wsl --help`.
- Polling or making up percentages during long operations.
- Promising the `.vhdx` will end up equal to the usage `df` reports.
- Moving `docker_data.vhdx` by hand instead of through Docker Desktop.
