# Loading SystemBoost onto a USB drive

SystemBoost is designed to **run from a USB stick** with no installation. Here are
both ways to set that up.

---

## Option A — let SystemBoost build it for you (easiest)

1. Run `SystemBoost.bat` on any Windows PC (double-click, click **Yes** on UAC).
2. Choose **`7) Build USB package`**.
3. Type your USB drive letter (e.g. `E` or `F:`).

SystemBoost copies itself to `E:\SystemBoost`, then creates:
- `E:\START-SystemBoost.bat` — the launcher on the USB root
- `E:\README-SYSTEMBOOST.txt` — short instructions for whoever uses the stick

You can also do it from the command line:

```bat
SystemBoost.bat /build-usb=E
```

Then **safely eject** the USB. On any Windows PC, plug it in, open the drive,
and double-click `START-SystemBoost.bat`.

> Windows often disables `autorun`, so *don't* rely on plugging the stick in alone —
> always double-click the `.bat`.

---

## Option B — copy it manually

1. Copy the whole `SystemBoost` folder onto the USB stick.
2. On the target PC, open the stick and double-click
   `SystemBoost\SystemBoost.bat`.
3. Click **Yes** on the UAC prompt.

---

## Using SystemBoost from the USB

- **Type down** or **double-click** `SystemBoost.bat`.
- If you're on the USB root launcher, keep the stick in the drive while it runs.
- For a one-click full tune-up: **`4) FULL BOOST`**.
- Check what's slow/full first: **`5) System report`**.

---

## Things to know

- **Needs Administrator rights.** The launcher shows a UAC "Allow" prompt — click **Yes**.
- It's **portable**: nothing is installed on the PC you clean, unless you use `install.bat`.
- Changes are **reversible**: every run records what it did, and the **`Undo`** option
  puts things back. A System Restore point is also created first.
- It works **offline** — no internet needed, nothing is uploaded.
- Works on **Windows 10 and Windows 11**.

---

## Troubleshooting

| Problem | What to do |
|---------|------------|
| UAC prompt doesn't appear / "must be admin" | Right-click `SystemBoost.bat` → **Run as administrator**. |
| Stick isn't the drive letter I typed | Check the letter in File Explorer (e.g. `E:\`). |
| SmartScreen warns | Click **More info → Run anyway** (it's a local script, not a download). |
| `Windows.old` won't delete | It may be in use — reboot, then retry via the Space menu. |
| Undo doesn't restore everything | Re-run and check `%TEMP%\SystemBoost.log`; things like defrag/trim aren't revertible but are harmless. |

---

## Making a portable single-file `.exe` (optional)

If you want one deliverable file instead of a folder, see `SystemBoost\build-standalone.ps1`.
It packages the tool into a single self-extracting `.exe` using Windows' built-in
`iexpress`, or into a zip. (Requires running on Windows; PowerShell 5.1.)
