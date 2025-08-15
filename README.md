Windows Update Mock (PowerShell)
A full-screen Windows Update–style experience for demos, kiosks, and testing. It shows a realistic “Installing Windows Updates” UI, restricts user input, hides/clips the cursor, suppresses escape hotkeys, and temporarily disables targeted HID devices (touchpad/touchscreen/digitizer/pen), then restores them on exit. Includes a headless fallback for non-interactive sessions.

Important: Requires Administrator privileges and STA mode.

Features
UI and Focus

Full-screen, borderless, top-most “Installing Windows Updates” screen.

Animated 0–100% progress with contextual status messages.

Watchdog re-enforces top-most, focus, and cursor position.

Input Restriction

Blocks user input via BlockInput.

Hides the cursor and clips it to the screen bounds.

Suppresses Win key and common escape combos: Alt+Tab, Alt+F4, Ctrl+Esc.

Device Management (HID)

Temporarily disables targeted HID devices (touchpad/touchscreen/digitizer/pen).

Safely re-enables them on exit.

Skips HID management gracefully if PnpDevice module is unavailable.

Headless Fallback

Detects non-interactive sessions (e.g., some service/agent contexts).

Runs without UI and input blocking, simulates progress, and performs full cleanup.

Requirements
Windows 10/11.

Administrator privileges.

STA mode (Single-Threaded Apartment).

Windows PowerShell 5.1 recommended (with .NET Framework 4.x and WinForms).

PnpDevice PowerShell module (included in modern Windows). If missing, HID disable/enable is skipped.

Quick Start (One-Liner)
Run from an elevated Command Prompt (Run as administrator):

powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

If PATH doesn’t resolve powershell:

"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

From a 32‑bit shell on 64‑bit Windows:

"C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

Notes

-sta is required because the script uses WinForms and low-level keyboard hooks.

-ep Bypass applies only to the launched process.

-nop and -w hidden are optional for a cleaner UX.

Headless Mode
When the script detects a non-interactive desktop:

Skips UI, input blocking, and hooks.

Applies HID device changes (if possible).

Simulates progress in the console.

Restores devices on exit.

This avoids “UserInteractive” errors when no desktop is available (e.g., some agent/service sessions).

HID Targeting and Exclusions
The script matches device names case-insensitively using patterns:

Targets include: touch pad/touchpad, touch screen/touchscreen, digitizer/pen, HID-compliant touch devices, Wacom.

Exclusions include: keyboard/mouse, generic USB input devices, essential system HID devices.

Edit the TargetPatterns and Exclusions arrays in the script to suit specific hardware.

Local Run (Cloned Repo)
From an elevated Windows PowerShell:

powershell.exe -sta -ExecutionPolicy Bypass -File .\script.ps1

Troubleshooting
'powershell' is not recognized:

Use the full path: System32 or Sysnative (for 32‑bit shell on 64‑bit OS).

UI fails with “not in UserInteractive mode”:

Run in an interactive user desktop session (local or via RDP), or rely on headless mode.

HID re-enable “Generic failure”:

Run a device rescan: pnputil /scan-devices

Re-run enabling per InstanceId in elevated PowerShell:

Enable-PnpDevice -InstanceId 'HID......' -Confirm:$false

In rare cases, sign-out or restart may be needed for touch/pen stacks.

No PnpDevice module:

The script continues without HID disable/enable and logs a warning.

Security Notes
Running with Administrator and bypassing execution policy has risk—use trusted sources only.

The script intentionally restricts input and hides/limits devices temporarily; test in a safe environment first.

Known Limitations
Some environments block UI or hooks (non-interactive sessions).

Certain HID devices may require a rescan or reboot to fully restore after changes.

Third-party security tools may flag input blocking or Win32 API calls.

File Structure
script.ps1

Main script with UI, input blocking, device targeting, and headless fallback.

License
MIT

Contributing
Issues and pull requests are welcome. Please include:

OS version

PowerShell version

Whether the session was interactive or headless

Relevant console logs (redact sensitive info)

Support
Open an issue if you have questions, bugs, or feature requests.
