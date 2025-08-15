Windows Update Mock (PowerShell)
A full-screen Windows Update–style UI with input blocking, cursor hiding/clipping, hotkey suppression, and temporary disabling/enabling of targeted HID devices (touchpad/touchscreen/digitizer). Designed for demos, kiosks, and testing.

Important: This script requires Administrator privileges and must run in STA because it uses WinForms and low-level keyboard hooks.

Features
Full-screen, top-most fake “Installing Windows Updates” UI.

Input restriction:

BlockInput, cursor hide, cursor clip to screen.

Suppress Win key and common escape combos: Alt+Tab, Alt+F4, Ctrl+Esc.

Periodic watchdog to re-enforce top-most, focus, and input block.

Temporarily disable selected HID devices (touchpad/touchscreen/digitizer/pen) and re-enable them on exit.

Headless fallback: if running in a non-interactive session (e.g., some service agents), the script auto-runs without UI and simulates progress while still applying and restoring device state.

Requirements
Windows 10/11.

Administrator privileges.

STA mode (Single-Threaded Apartment).

PowerShell with .NET Framework 4.x and WinForms:

Windows PowerShell 5.1 recommended.

PnpDevice module (built into modern Windows) for device enable/disable:

If unavailable, HID disable/enable is skipped with a warning.

Quick Run (One-Liner)
From an elevated Command Prompt (Run as administrator):

powershell -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

Notes:

-sta is required (WinForms).

-ep Bypass applies to the launched process only.

-nop and -w hidden are optional for cleaner UX.

If the environment doesn’t resolve powershell in PATH, use the full path:

"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

For 32-bit shell on 64-bit Windows:

"C:\Windows\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -nop -w hidden -sta -ep Bypass -c "iwr -useb https://raw.githubusercontent.com/sam-tam-sam/DWA/main/script.ps1 | iex"

Headless Mode
When the script detects a non-interactive desktop (e.g., some remote agents/services), it:

Skips UI and input blocking.

Disables targeted HID devices (if possible).

Simulates progress in the console.

Restores devices on exit.

This avoids “UserInteractive” errors when no desktop is available.

Safety and Cleanup
The script attempts to:

Always unblock input, unclip the cursor, and show the cursor on exit.

Re-enable any devices it disabled.

Perform a final cleanup in a “finally” block to handle unexpected errors.

If a device fails to re-enable immediately (“Generic failure”), try:

pnputil /scan-devices

Re-run Enable-PnpDevice for that InstanceId in an elevated, interactive session.

In rare cases, sign-out/restart may be needed for touch/pen stacks.

Customize Target Devices
Targets are matched case-insensitively by name patterns. You can edit these arrays in the script:

TargetPatterns: touch pad/touchpad, touch screen/touchscreen, digitizer/pen, HID-compliant variants, Wacom.

Exclusions: keyboard, mouse, generic USB input, essential HID devices.

This prevents accidental loss of core input like keyboards/mice.

Local Run (Cloned Repo)
If you cloned the repo, run from an elevated PowerShell:

powershell.exe -sta -ExecutionPolicy Bypass -File .\script.ps1

Security Notes
Running with Administrator privileges and bypassing execution policy carries risk—only run scripts from trusted sources.

The script intentionally restricts input and device functionality temporarily; test in a safe environment before production use.

Troubleshooting
“‘powershell’ is not recognized”: use full path (System32 or Sysnative).

“UserInteractive” error: run in a user desktop session (local or RDP), or rely on headless mode in non-interactive environments.

HID re-enable failures: use pnputil /scan-devices, or re-run Enable-PnpDevice for each InstanceId in an elevated, interactive session.

License
MIT (or your preferred license).
