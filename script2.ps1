# =====
# WINDOWS UPDATE MOCK - UI + INPUT BLOCK + HIDE/CLIP CURSOR + HOTKEY GUARD
# + TEMP DISABLE/ENABLE TARGETED HID DEVICES (touchpad/touchscreen/digitizer) LIKE DEVICE MANAGER
# Requires: Administrator + STA
# Run: powershell.exe -sta -ExecutionPolicy Bypass -File script.ps1
# =====
$ErrorActionPreference = 'Continue'

function Write-Log($msg, $color='White') {
  try {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
  } catch {
    Write-Output "[$(Get-Date -Format 'HH:mm:ss')] $msg"
  }
}

try {
  # Preconditions
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { Write-Log "ERROR: Administrator privileges required!" 'Red'; return }
  if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { Write-Log "ERROR: STA mode required! Use: powershell.exe -sta -File script.ps1" 'Red'; return }

  # Assemblies for WinForms
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
  } catch {
    $fwPath = if ([Environment]::Is64BitProcess) { "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319" } else { "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319" }
    Add-Type -LiteralPath "$fwPath\System.Windows.Forms.dll"
    Add-Type -LiteralPath "$fwPath\System.Drawing.dll"
  }

  # Native P/Invoke
  $cSharp = @'
using System;
using System.Runtime.InteropServices;

public static class Native {
  [DllImport("user32.dll")] public static extern bool BlockInput(bool fBlockIt);
  [DllImport("user32.dll")] public static extern int  ShowCursor(bool bShow);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

  [DllImport("user32.dll")] public static extern bool ClipCursor(ref RECT lpRect);
  [DllImport("user32.dll")] public static extern bool ClipCursor(IntPtr lpRect);

  [DllImport("user32.dll")] public static extern IntPtr GetDesktopWindow();
  [DllImport("user32.dll")] public static extern bool   GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool   SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool   BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool   SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

  public static readonly IntPtr HWND_TOPMOST   = new IntPtr(-1);
  public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
  public const uint SWP_NOSIZE     = 0x0001;
  public const uint SWP_NOMOVE     = 0x0002;
  public const uint SWP_SHOWWINDOW = 0x0040;

  // Low-Level Keyboard Hook
  public const int WH_KEYBOARD_LL = 13;
  public const int HC_ACTION      = 0;
  public const int WM_KEYDOWN     = 0x0100;
  public const int WM_SYSKEYDOWN  = 0x0104;
  public const int WM_KEYUP       = 0x0101;
  public const int WM_SYSKEYUP    = 0x0105;

  public delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);
  [DllImport("user32.dll")] public static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
  [DllImport("user32.dll")] public static extern bool   UnhookWindowsHookEx(IntPtr hhk);
  [DllImport("user32.dll")] public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
  [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string lpModuleName);

  [StructLayout(LayoutKind.Sequential)]
  public struct KBDLLHOOKSTRUCT {
    public uint vkCode;
    public uint scanCode;
    public uint flags;
    public uint time;
    public IntPtr dwExtraInfo;
  }

  // Virtual Keys
  public const int VK_LWIN   = 0x5B;
  public const int VK_RWIN   = 0x5C;
  public const int VK_TAB    = 0x09;
  public const int VK_ESCAPE = 0x1B;
  public const int VK_F4     = 0x73;
  public const int VK_SPACE  = 0x20;
  public const int VK_LMENU  = 0xA4; // Left ALT
  public const int VK_RMENU  = 0xA5; // Right ALT
  public const int VK_MENU   = 0x12; // ALT
  public const int VK_CONTROL= 0x11;

  static IntPtr _hook = IntPtr.Zero;
  static HookProc _proc = new HookProc(HookCallback);

  public static bool AltDown = false;
  public static bool CtrlDown = false;

  static bool IsWinKey(uint vk) { return (vk == VK_LWIN || vk == VK_RWIN); }

  static bool IsSuppressedCombo(uint vk) {
    if (IsWinKey(vk)) return true; // Windows key and Win+*
    if (vk == VK_CONTROL) { CtrlDown = true; return false; }
    if (vk == VK_LMENU || vk == VK_RMENU || vk == VK_MENU) { AltDown = true; return false; }
    if (AltDown && (vk == VK_TAB || vk == VK_F4 || vk == VK_SPACE)) return true; // Alt+Tab/F4/Space
    if (CtrlDown && vk == VK_ESCAPE) return true; // Ctrl+Esc
    return false;
  }

  static void UpdateModifierState(uint vk, IntPtr wParam) {
    if (wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP) {
      if (vk == VK_CONTROL) CtrlDown = false;
      if (vk == VK_LMENU || vk == VK_RMENU || vk == VK_MENU) AltDown = false;
    }
  }

  public static void InstallKbHook() {
    if (_hook != IntPtr.Zero) return;
    IntPtr hInstance = GetModuleHandle(null);
    _hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, hInstance, 0);
  }
  public static void UninstallKbHook() {
    if (_hook != IntPtr.Zero) {
      UnhookWindowsHookEx(_hook);
      _hook = IntPtr.Zero;
    }
  }

  public static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
    if (nCode == HC_ACTION) {
      KBDLLHOOKSTRUCT kb = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
      uint vk = kb.vkCode;
      if (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN) {
        if (IsSuppressedCombo(vk)) return (IntPtr)1; // swallow
      }
      UpdateModifierState(vk, wParam);
    }
    return CallNextHookEx(_hook, nCode, wParam, lParam);
  }

  // Helpers
  public static void ForceTopMost(IntPtr h) {
    try { SetWindowPos(h, HWND_TOPMOST, 0,0,0,0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW); } catch {}
    try { BringWindowToTop(h); } catch {}
    try { SetForegroundWindow(h); } catch {}
  }
}
'@
  Add-Type -TypeDefinition $cSharp

  # ===================== OPTIONAL: TEMPORARY DISABLE TARGET HID DEVICES =====================
  $GUID_HID = '{745a17a0-74d3-11d0-b6fe-00a0c90f57da}'  # Human Interface Devices

  $TargetPatterns = @(
    'touch pad','touchpad',
    'touch screen','touchscreen',
    'digitizer','pen',
    '^hid-compliant touch pad',
    '^hid-compliant touch screen',
    '^hid-compliant digitizer',
    'wacom'
  )

  $Exclusions = @(
    'keyboard','hid keyboard',
    'mouse','hid-compliant mouse',
    'usb input device',
    'microsoft input configuration device',
    'intel(r) iss hid device',
    'gpio laptop or slate indicator',
    'i2c hid device'
  )

  # FIXED: proper list initialization
  $DisabledIds = New-Object System.Collections.Generic.List[string]

  function Ensure-PnpDeviceModule {
    try {
      if (-not (Get-Module -ListAvailable -Name PnpDevice)) {
        Write-Log "PnpDevice module not found in module path, attempting Import-Module..." 'Yellow'
      }
      Import-Module PnpDevice -ErrorAction Stop | Out-Null
      return $true
    } catch {
      Write-Log "PnpDevice module unavailable. HID disable/enable will be skipped." 'Yellow'
      return $false
    }
  }

  function Get-HIDTargets {
    if (-not (Ensure-PnpDeviceModule)) { return @() }
    try {
      $all = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue
      $hid = $all | Where-Object { $_.ClassGuid -eq $GUID_HID }
      $targets = @()
      foreach ($dev in $hid) {
        $name = ($dev.FriendlyName, $dev.InstanceId, $dev.Class, $dev.ClassGuid) -join ' '
        $nlc  = $name.ToLowerInvariant()
        $matchTarget = $false
        foreach ($pat in $TargetPatterns) {
          if ($nlc -match $pat.ToLowerInvariant()) { $matchTarget=$true; break }
        }
        if (-not $matchTarget) { continue }
        $excluded = $false
        foreach ($ex in $Exclusions) {
          if ($nlc -match $ex.ToLowerInvariant()) { $excluded=$true; break }
        }
        if ($excluded) { continue }
        $targets += $dev
      }
      return $targets
    } catch {
      Write-Log "Failed to enumerate HID devices: $_" 'Yellow'
      return @()
    }
  }

  function Disable-Targets {
    $targets = Get-HIDTargets
    if (-not $targets -or $targets.Count -eq 0) { Write-Log "No HID targets matched."; return }
    foreach ($dev in $targets) {
      try {
        Write-Log "Disabling: $($dev.FriendlyName) [$($dev.InstanceId)]"
        Disable-PnpDevice -InstanceId $dev.InstanceId -Confirm:$false -ErrorAction Stop | Out-Null
        [void]$DisabledIds.Add($dev.InstanceId)
      } catch {
        Write-Log "Failed to disable: $($dev.InstanceId) ($_)" 'Yellow'
      }
    }
  }

  function Enable-PreviouslyDisabled {
    if ($DisabledIds.Count -eq 0) { return }
    foreach ($id in $DisabledIds) {
      try {
        Write-Log "Enabling: $id"
        Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop | Out-Null
      } catch {
        Write-Log "Failed to re-enable: $id ($_)" 'Yellow'
      }
    }
  }
  # ===================== END OPTIONAL SECTION =====================

  # ===================== HEADLESS FALLBACK FOR NON-INTERACTIVE SESSIONS =====================
  $global:IsUserInteractive = $false
  try {
    $global:IsUserInteractive = [System.Windows.Forms.SystemInformation]::UserInteractive
  } catch { $global:IsUserInteractive = $false }

  if (-not $global:IsUserInteractive) {
    Write-Log "Non-interactive session detected. Running in headless mode (no UI, no input block)." 'Yellow'
    Disable-Targets
    try {
      for ($i=1; $i -le 100; $i++) {
        Start-Sleep -Milliseconds 120
        if ($i % 10 -eq 0) { Write-Log "Headless progress: $i%." }
      }
    } catch {}
    try { Enable-PreviouslyDisabled } catch {}
    Write-Log "Headless run completed. Exiting."
    return
  }

  # ===================== UI BUILD =====================
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "Windows Update"
  $form.FormBorderStyle = 'None'
  $form.ShowInTaskbar = $false
  $form.TopMost = $true
  $form.StartPosition = "CenterScreen"
  $form.WindowState = 'Maximized'
  $form.BackColor = [System.Drawing.Color]::FromArgb(0,120,215)
  $form.KeyPreview = $true
  $form.AutoScaleMode = 'Dpi'
  try { $form.GetType().GetProperty('DoubleBuffered',[System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($form,$true,$null) } catch {}
  $form.Add_KeyDown({ param($s,$e) $e.Handled=$true; $e.SuppressKeyPress=$true })

  $centerPanel = New-Object System.Windows.Forms.Panel
  $centerPanel.Size = New-Object System.Drawing.Size(1000, 420)
  $centerPanel.BackColor = [System.Drawing.Color]::Transparent
  $form.Controls.Add($centerPanel)
  $center = {
    $centerPanel.Left = [Math]::Max(0, [Math]::Floor(($form.ClientSize.Width - $centerPanel.Width)/2))
    $centerPanel.Top  = [Math]::Max(0, [Math]::Floor(($form.ClientSize.Height - $centerPanel.Height)/2))
  }
  $form.add_Shown({ & $center })
  $form.add_Resize({ & $center })

  function New-CenteredLabel([string]$text,[int]$size,[bool]$bold,[int]$y) {
    $lbl = New-Object System.Windows.Forms.Label
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", $size, $style)
    $lbl.Text = $text
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.AutoSize = $true
    $centerPanel.Controls.Add($lbl)
    $lbl.Left = [Math]::Floor(($centerPanel.Width - $lbl.PreferredWidth)/2)
    $lbl.Top  = $y
    return $lbl
  }

  $titleLabel    = New-CenteredLabel "Installing Windows Updates" 32 $true 20
  $subtitleLabel = New-CenteredLabel "Please do not turn off your computer. This may take a while." 18 $false 86
  $loadingLabel  = New-CenteredLabel "LOADING..." 18 $true 150

  $progressContainer = New-Object System.Windows.Forms.Panel
  $progressContainer.Height = 30
  $progressContainer.Width  = 640
  $progressContainer.BackColor = [System.Drawing.Color]::FromArgb(0,120,215)
  $progressContainer.Left = [Math]::Floor(($centerPanel.Width - $progressContainer.Width)/2)
  $progressContainer.Top  = 195
  $centerPanel.Controls.Add($progressContainer)

  $blockWidth=5; $blockHeight=22; $gap=1
  $totalNeeded = 100*$blockWidth + 99*$gap
  if ($totalNeeded -gt $progressContainer.Width) {
    $scale = $progressContainer.Width / $totalNeeded
    $blockWidth = [Math]::Max(2,[Math]::Floor($blockWidth*$scale))
    $gap        = [Math]::Max(1,[Math]::Floor($gap*$scale))
    $totalNeeded = 100*$blockWidth + 99*$gap
  }
  $innerLeft = [Math]::Floor(($progressContainer.Width - $totalNeeded)/2)
  $innerTop  = [Math]::Floor(($progressContainer.Height - $blockHeight)/2)
  $global:progressBlocks=@()
  for ($i=0;$i -lt 100;$i++){
    $x = $innerLeft + $i*($blockWidth+$gap)
    $block = New-Object System.Windows.Forms.Panel
    $block.Width=$blockWidth; $block.Height=$blockHeight
    $block.Left=$x; $block.Top=$innerTop
    $block.BackColor=[System.Drawing.Color]::FromArgb(0,120,215)
    $progressContainer.Controls.Add($block)
    $global:progressBlocks += $block
  }

  $percentLabel = New-CenteredLabel "0% complete" 16 $false 240
  $statusLabel  = New-CenteredLabel "Preparing to install updates..." 12 $false 280
  $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(230,230,230)

  foreach ($lbl in @($titleLabel,$subtitleLabel,$loadingLabel,$percentLabel,$statusLabel)) { try { $lbl.UseCompatibleTextRendering=$false } catch {} }

  $global:progress=0
  $global:statusMessages=@(
    "Preparing to install updates...",
    "Downloading update packages...",
    "Verifying update integrity...",
    "Installing system components...",
    "Updating device drivers...",
    "Configuring system settings...",
    "Applying security patches...",
    "Optimizing system performance...",
    "Finalizing installation...",
    "Preparing system restart..."
  )
  function Update-ProgressBlocks([int]$percent){
    if ($percent -lt 0){$percent=0}
    if ($percent -gt 100){$percent=100}
    for ($j=0;$j -lt 100;$j++){
      $global:progressBlocks[$j].BackColor = if ($j -lt $percent){ [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(0,120,215) }
    }
    $progressContainer.Invalidate()
  }

  $progressTimer = New-Object System.Windows.Forms.Timer
  $progressTimer.Interval = 300
  $progressTimer.Add_Tick({
    try {
      if ($global:progress -lt 100){
        $global:progress++
        Update-ProgressBlocks -percent $global:progress
        $percentLabel.Text = "$global:progress% complete"
        $percentLabel.Left = [Math]::Floor(($centerPanel.Width - $percentLabel.PreferredWidth)/2)
        $statusIndex = [math]::Floor($global:progress/10)
        if ($statusIndex -lt $global:statusMessages.Length){
          $statusLabel.Text = $global:statusMessages[$statusIndex]
          $statusLabel.Left = [Math]::Floor(($centerPanel.Width - $statusLabel.PreferredWidth)/2)
        }
        if ($global:progress -eq 100){
          $progressTimer.Stop()
          Write-Log "Progress reached 100%." 'Green'
          Start-Sleep -Milliseconds 600
          $form.Close()
        }
      }
    } catch {}
  })
  # ===================== END UI =====================

  # ===================== Helpers =====================
  function Set-CursorVisible([bool]$visible){
    try{
      if ($visible){ for($i=0;$i -lt 32;$i++){ [void][Native]::ShowCursor($true) } }
      else         { for($i=0;$i -lt 32;$i++){ [void][Native]::ShowCursor($false) } }
    }catch{}
  }
  function Clip-CursorToScreen(){
    try{
      $hDesk=[Native]::GetDesktopWindow()
      $rect = New-Object Native+RECT
      if ([Native]::GetWindowRect($hDesk, [ref]$rect)){
        [void][Native]::ClipCursor([ref]$rect)
      }
    }catch{}
  }
  function Unclip-Cursor(){ try{ [void][Native]::ClipCursor([IntPtr]::Zero) }catch{} }
  function Force-TopMost($h){
    try{ [Native]::ForceTopMost($h) }catch{}
  }
  function Center-Cursor(){
    try{
      $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
      [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([int](($bounds.Left+$bounds.Right)/2),[int](($bounds.Top+$bounds.Bottom)/2))
    }catch{}
  }

  # 100ms watchdog: re-assert topmost/focus/clip, center cursor, re-block input
  $watchdog = New-Object System.Windows.Forms.Timer
  $watchdog.Interval = 100
  $watchdog.Add_Tick({
    try{
      $hForm=$form.Handle
      Force-TopMost $hForm
      Clip-CursorToScreen
      Center-Cursor
      [void][Native]::BlockInput($true)
      $fg = [Native]::GetForegroundWindow()
      if ($fg -ne $hForm){ [void][Native]::SetForegroundWindow($hForm) }
    }catch{}
  })

  # ===================== ORCHESTRATION =====================
  # 0) Soft safety: if input isn't blocked yet, allow ESC to close before enforcement
  $form.Add_PreviewKeyDown({
    param($s,$e)
    try {
      if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        Write-Log "Escape pressed before enforcement. Closing." 'Yellow'
        $form.Close()
      }
    } catch {}
  })

  # 1) Disable target HID devices (touchpad/touchscreen/digitizer) like Device Manager
  Disable-Targets

  # 2) Show the UI and enforce input restrictions
  $form.Add_Shown({
    try {
      [Native]::InstallKbHook()
      Set-CursorVisible $false
      Clip-CursorToScreen
      Center-Cursor
      [void][Native]::BlockInput($true)
      $watchdog.Start()
    } catch {}
    $progressTimer.Start()
  })

  $form.Add_FormClosed({
    try { $watchdog.Stop() } catch {}
    try { $progressTimer.Stop() } catch {}
    try { [void][Native]::BlockInput($false) } catch {}
    try { Unclip-Cursor } catch {}
    try { Set-CursorVisible $true } catch {}
    try { [Native]::UninstallKbHook() } catch {}
    try { Enable-PreviouslyDisabled } catch {}
  })

  [void]$form.ShowDialog()

} catch {
  Write-Log "Critical error: $_" 'Red'
} finally {
  # Absolute safety net: always restore devices and input state
  try { [void][Native]::BlockInput($false) } catch {}
  try { [void][Native]::ClipCursor([IntPtr]::Zero) } catch {}
  try { for($i=0;$i -lt 32;$i++){ [void][Native]::ShowCursor($true) } } catch {}
  try { Enable-PreviouslyDisabled } catch {}
  Write-Log "Cleanup complete."
}
