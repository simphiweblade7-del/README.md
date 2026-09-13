# SystemBoost

**Free up disk space and make Windows run faster — portable, USB-ready.**

SystemBoost is a Windows 10/11 maintenance toolkit you can run directly from any
folder or a USB drive. It does **not** need to be installed to work, but it also
ships with an optional installer if you want shortcuts on a particular PC.

> ⚠️ **Only run it as Administrator** (it self-prompts via UAC). It makes
> aggressive-but-reversible changes and always creates a **System Restore point**
> and logs every action. Use the **Undo** option to revert the last run.

---

## What it does

| Action | What it frees / speeds up |
|--------|---------------------------|
| **Space** | Temp files, Windows Update cache, browser caches, Recycle Bin, `Windows.old`, WinSxS component store (via DISM), crash dumps, error-report queues, Delivery Optimization cache, font cache |
| **Speed** | High-performance power plan, reduced visual/animation effects, lower menu delay, responsiveness & multimedia scheduling registry tweaks, enables Prefetch/Superfetch, system-managed pagefile, disables telemetry/indexing/background services, flushes DNS, defrags/TRIMs the drive, SFC health check, startup-program cleanup |

Everything that can be undone is recorded to `C:\ProgramData\SystemBoost\undo.json`
and can be reverted from the **Undo** menu.

---

## Quick start (portable — no install)

1. Copy the whole `SystemBoost` folder anywhere (a USB stick works great).
2. Double-click **`SystemBoost.bat`**.
3. If a blue UAC box appears, click **Yes**.
4. Pick an option from the menu:
   - `4) FULL BOOST` — easiest (clean + speed together)
   - `1) Free up disk space`
   - `3) Boost speed`
   - `5) System report`
   - `6) Undo last changes`

You can also run it from the command line:

```bat
SystemBoost.bat            :: interactive menu
SystemBoost.bat /full      :: clean + optimize (recommended)
SystemBoost.bat /clean     :: aggressive disk cleanup only
SystemBoost.bat /quickclean:: fast, safe cleanup only
SystemBoost.bat /optimize  :: performance tweaks only
SystemBoost.bat /report    :: system report, makes no changes
SystemBoost.bat /undo      :: revert the last run
SystemBoost.bat /yes       :: auto-confirm, no prompts
SystemBoost.bat /norestore :: skip creating a restore point
SystemBoost.bat /build-usb=DRIVE  :: copy the tool to a USB drive (e.g. /build-usb=E)
```

---

## Loading it onto a USB drive

Easiest way:

```bat
SystemBoost.bat /build-usb=E
```

(replace `E` with your USB drive letter). This copies the tool to `E:\SystemBoost`,
adds **`START-SystemBoost.bat`** at the root of the stick, and drops a
`README-SYSTEMBOOST.txt` so anyone can use it.

Or just copy the `SystemBoost` folder onto the stick and run
`SystemBoost\SystemBoost.bat`. See **[docs/HOWTO_USB.md](docs/HOWTO_USB.md)**.

---

## Installing it on a PC (optional)

Run **`install.bat`** as Administrator to copy SystemBoost to
`C:\ProgramData\SystemBoost` and add **Desktop** and **Start menu** shortcuts.
Run **`uninstall.bat`** to remove it later.

---

## Configuration

Edit `SystemBoost.config.json`:

```json
{
  "general": { "allowRestorePoint": true },
  "services": { "disableFax": false },
  "exclusions": [ "C:\\path\\you\\never\\want\\deleted" ]
}
```

- `allowRestorePoint` – set `false` to stop creating System Restore points.
- `services.disableFax` – set `true` to also disable the Fax service.
- `exclusions` – add absolute paths that must never be touched.

---

## Project layout

```
SystemBoost/
├── SystemBoost.bat          <- main double-click launcher (portable)
├── SystemBoost.ps1          <- PowerShell engine (menu + command line)
├── SystemBoost.config.json  <- settings / exclusions
├── install.bat              <- optional installer
├── uninstall.bat            <- optional uninstaller
├── make-shortcuts.vbs       <- shortcut helper used by install.bat
├── build-standalone.ps1     <- optional: wrap into a single .exe / zip
├── modules/
│   ├── Common.ps1           <- helpers (logging, restore point, undo, config)
│   ├── Clean.ps1            <- disk-space freeing routines
│   ├── Optimize.ps1         <- speed / performance tweaks
│   └── Report.ps1           <- system report & diagnostics
└── docs/
    └── HOWTO_USB.md         <- step-by-step USB guide
```

---

## Safety & privacy

- A **System Restore point** is created before any change (unless you pass `/norestore`
  or disable `allowRestorePoint`).
- All actions are written to `%TEMP%\SystemBoost.log`.
- Changes are reversible via **Undo**.
- SystemBoost runs entirely **on your machine** — no data is sent anywhere,
  and it needs **no internet connection**.

## Requirements

- **Windows 10 or Windows 11** (any edition, 64-bit recommended).
- Runs on built-in **Windows PowerShell 5.1** — nothing else to install.
- **Administrator** rights (auto-elevates).

## Disclaimer

This tool modifies system settings and deletes files to free space. It is provided
"as is" without warranty. Test on a machine you can restore, and review the on-screen
warnings before the aggressive options. You are responsible for your own system.
