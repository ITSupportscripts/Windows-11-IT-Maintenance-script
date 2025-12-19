# Windows 11 IT Maintenance Menu (Batch Script)

## Overview

**Windows 11 IT Maintenance Menu** is a Windows batch script that provides a menu-driven interface for common IT maintenance tasks on Windows 11. It is designed to:

- **Run elevated** (self-relaunches with administrative rights if required).
- Execute maintenance commands in grouped workflows (**Standard**, **Advanced**, **Recovery**).
- Create a **per-run log file** with command output, exit codes, retries, and a success/failure summary.
- Provide quick access to the log folder.

---

## Features

- **Automatic elevation**
  - Detects if the script is running as administrator and relaunches itself with `RunAs` when needed.

- **Menu-driven workflows**
  - Standard maintenance (health checks, cleanup, updates, DNS flush)
  - Advanced maintenance (Windows Update service reset + networking stack reset)
  - Recovery maintenance (DISM reset base + boot repair commands)

- **Robust logging**
  - Logs stored in: `C:\IT Maintenance Logs`
  - One log file per run, with timestamp and computer/user name in the filename
  - Captures:
    - Command lines executed
    - Full command output
    - Exit codes
    - Retries (up to 3 attempts per command)
    - Summary of successful and failed commands

- **Retry mechanism**
  - Commands are attempted up to **3 times** before being marked failed.

---

## Requirements

### Supported OS
- Windows 11 (should also work on Windows 10, but is intended for Windows 11 environments)

### Permissions
- **Administrator privileges required** for most operations.  
  The script will prompt for elevation automatically.

### Dependencies
- Built-in Windows tools (typically present by default):
  - `DISM`
  - `SFC`
  - `chkdsk`
  - `UsoClient`
  - `ipconfig`
  - `cleanmgr`
  - `netsh`
  - `bootrec` (recovery-related scenarios)
  - `PowerShell` (used for elevation and timestamp generation)

---

## Quick Start

1. Save the script as a `.bat` file (for example: `Windows11_IT_Maintenance_Menu.bat`).
2. Right-click the file and choose **Run as administrator**  
   - If you run it without admin rights, the script will self-elevate.
3. Select an option from the menu:
   - `1` Standard maintenance
   - `2` Advanced maintenance
   - `3` Recovery maintenance
   - `4` Open log folder
   - `5` Exit

---

## What Each Menu Option Does

### 1) Standard maintenance
Runs common health repair and cleanup actions:

- `DISM /Online /Cleanup-Image /RestoreHealth`
- `SFC /scannow`
- `DISM /Online /Cleanup-Image /StartComponentCleanup`
- `chkdsk C: /scan`
- `UsoClient StartScan`
- `ipconfig /flushdns`
- `cleanmgr /sageset:1`
- `cleanmgr /sagerun:1`

> Notes:
> - `cleanmgr /sageset:1` opens configuration UI the first time to choose cleanup options for preset `1`.
> - `UsoClient StartScan` may behave differently depending on Windows build and update policies.

---

### 2) Advanced maintenance
Stops Windows Update-related services, renames update cache folders safely, and resets network stacks:

- Stops services:
  - `net stop wuauserv`
  - `net stop bits`
  - `net stop cryptsvc`
- Renames update cache folders (timestamped):
  - `%windir%\SoftwareDistribution` → `SoftwareDistribution.old_<timestamp>`
  - `%windir%\System32\catroot2` → `catroot2.old_<timestamp>`
- Network reset:
  - `netsh winsock reset`
  - `netsh int ip reset`

> Notes:
> - Renaming these folders forces Windows to recreate update components on next run.
> - A reboot may be required for network stack resets to fully apply.

---

### 3) Recovery maintenance
Runs more aggressive recovery operations:

- `DISM /ResetBase`
- `bootrec /fixboot`
- `bootrec /rebuildbcd`

> **Important:** `bootrec` commands are typically intended for **Windows Recovery Environment (WinRE)**.  
> Running them inside a normal Windows session may fail or produce unexpected results depending on the system state and boot configuration.

---

### 4) Open log file folder
Opens:
- `C:\IT Maintenance Logs`

---

### 5) Shut down script
Exits cleanly.

---

## Logging

### Log location
- `C:\IT Maintenance Logs`

### Log filename format
- `Computer <COMPUTERNAME> IT Maintenance script run by <USERNAME> <yyyy-MM-dd_HH-mm-ss>.log`

If a filename collision occurs, the script appends:
- `_(1)`, `_(2)`, etc.

### What’s captured
Each command execution logs:
- `[COMMAND] <actual command line>`
- Command output (stdout/stderr)
- `[RESULT] ExitCode=<code>`
- Status: `SUCCESS`, `FAILED`, retry attempts, and final failure after 3 attempts

A final **SUMMARY** lists:
- Successful commands
- Failed commands (after 3 attempts)
- The log file path

---

## Script Structure (High Level)

- **Elevation check**
  - Uses `net session` to determine admin rights.
  - Uses PowerShell `Start-Process -Verb RunAs` to relaunch the script.

- **Main loop**
  - Displays menu and routes to workflow labels.

- **Subroutines**
  - `:InitRun` — initializes timestamps, log file, and temporary summary files
  - `:RunCmd` — runs a command with logging and retry logic
  - `:FinalizeRun` — prints and logs the summary, cleans up temp files
  - `:LogEcho` — prints to console and appends to log file

---

## Security and Operational Considerations

- **Runs as Administrator**
  - Intended for IT/admin use. Use only in trusted environments.

- **System-impacting operations**
  - DISM/SFC/Component Cleanup can take significant time.
  - Update cache renames can affect Windows Update behavior until Windows rebuilds the caches.
  - Network resets may disrupt connectivity.
  - `bootrec` commands can alter boot configuration—use with caution.

- **Logging contains system details**
  - Logs may include machine name, username, and command output. Protect logs appropriately.

---

## Troubleshooting

### The script closes immediately or doesn’t elevate
- Ensure PowerShell is available and not restricted by policy.
- Try launching the script with **Run as administrator** manually.

### Commands fail repeatedly
- Review the log file for `[RESULT] ExitCode=...` and error output.
- Some commands require:
  - A reboot (e.g., `netsh` resets)
  - WinRE (e.g., `bootrec`)
  - Online connectivity (e.g., Windows Update scans)

### Cleanmgr prompts or doesn’t clean as expected
- The first run of `cleanmgr /sageset:1` requires selecting cleanup options.
- Ensure the selected options are saved for preset `1`.

---

## Customization

Common modifications:
- Add/remove commands in each workflow section (`:RUN_STANDARD`, `:RUN_ADVANCED`, `:RUN_RECOVERY`)
- Change log directory by editing:
  - `set "LOGDIR=C:\IT Maintenance Logs"`
- Adjust retry attempts by changing:
  - `Attempt !ATTEMPT! of 3 ...` logic in `:RunCmd`

---

## Disclaimer

This script is provided “as-is” without warranty. Use at your own risk. Always test in a controlled environment before deploying broadly, especially the **Recovery maintenance** option.

---

## Maintainers

- Owner: Max Timmers
- Contact: maxtimmers@live.com
- Last Updated: 19-DEC-2025
