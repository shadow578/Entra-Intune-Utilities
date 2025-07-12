@echo off
setlocal enabledelayedexpansion
set "TARGET=%TEMP%\EphemeralSessionBrowser.installer.ps1"
set SKIP=17
del "%TARGET%" 2>nul
set i=0
> "%TARGET%" (
  for /f "usebackq delims=" %%A in ("%~f0") do (
    set /a i+=1
    if !i! gtr %SKIP% echo(%%A)
  )
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File %TARGET% -Installer
del "%TARGET%" 2>nul
goto :EOF
exit
# --- end of installer bootstrapper ---

param(
  [switch]
  $Installer,

  [switch]
  $RunAfterInstallOrUpdate
)

function Get-ChromePath([switch] $AllowNull) {
  $cmd = Get-Command "chrome.exe"
  if ($null -eq $cmd) {
    if ($AllowNull) {
      Write-Host "Chrome executable not found, returning null."
      return $null
    }

    throw "Chrome executable not found! Please ensure that Google Chrome is installed and available in your PATH."
  }
  
  Write-Host "Using Chrome executable Version $($cmd.Version) at $($cmd.Source)"
  return $cmd.Source
}

function Get-InstallPaths() {
  $desktopPath = [System.Environment]::GetFolderPath("Desktop")
  $installDirectory = Join-Path -Path $env:LOCALAPPDATA -ChildPath "shadow578\EphemeralSessionBrowser"
  
  return [PSCustomObject]@{
    InstallDirectory  = $installDirectory
    MainScriptPath    = Join-Path -Path $installDirectory -ChildPath "EphemeralSessionBrowser.ps1"
    LoaderPath        = Join-Path -Path $installDirectory -ChildPath "EphemeralSessionBrowser.loader.bat"
    DesktopShortcut   = Join-Path -Path $desktopPath -ChildPath "EphemeralSessionBrowser.lnk"
    StartMenuShortcut = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs\Ephemeral Session Browser.lnk"
  }
}

function Get-ProfilesPaths() {
  $paths = Get-InstallPaths
  $profilesPath = Join-Path -Path $paths.InstallDirectory -ChildPath "profiles"

  return [PSCustomObject]@{
    Directory   = $profilesPath
    BaseProfile = Join-Path -Path $profilesPath -ChildPath "base"
  }
}

#region Installer

function Install-Chrome() {
  $chromePath = Get-ChromePath -AllowNull
  if ($null -eq $chromePath) {
    Write-Host "Chrome is not installed. Attempting to install via winget."
    try {
      winget install Google.Chrome
    }
    catch {
      Write-Host "Failed to install Chrome via winget: $_" -ForegroundColor Red
    }
  }

  $chromePath = Get-ChromePath -AllowNull
  if ($null -eq $chromePath) {
    Write-Host "Chrome installation failed. Please install Google Chrome manually and rerun the script."
    throw "Chrome installation failed!"
  }
}

function New-Shortcut([string] $Path, [string] $Target, [string] $Description = "", [string] $IconLocation = "") {
  $wsh = New-Object -ComObject WScript.Shell
  $shortcut = $wsh.CreateShortcut($Path)
  $shortcut.TargetPath = $Target

  if ($Description) {
    $shortcut.Description = $Description
  }

  if ($IconLocation) {
    $shortcut.IconLocation = $IconLocation
  }
  
  $shortcut.Save()
}

function Remove-ESPInstall([switch] $RemoveProfiles) {
  Write-Host "Removing EphemeralSessionBrowser installation..."
  $paths = Get-InstallPaths

  Remove-Item -Path $paths.MainScriptPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.LoaderPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.DesktopShortcut -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.StartMenuShortcut -ErrorAction SilentlyContinue

  if ($RemoveProfiles) {
    Remove-Item -Path ((Get-ProfilesPaths).Directory) -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function New-ESPInstall() {
  # before installing, remove any previous installation, keeping profiles
  Remove-ESPInstall -RemoveProfiles:$false

  Write-Host "Installing EphemeralSessionBrowser..."
  $paths = Get-InstallPaths

  # write program scripts
  New-Item -ItemType Directory -Path $paths.InstallDirectory -Force | Out-Null
  Copy-Item -Path $PSCommandPath -Destination $paths.MainScriptPath -Force
  $loader = @"
@echo off
powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$($paths.MainScriptPath)" %*
"@

  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($paths.LoaderPath, $loader, $utf8NoBom)

  # create shortcuts
  New-Shortcut -Path $paths.DesktopShortcut -Target $paths.LoaderPath -Description "Ephemeral Session Browser" -IconLocation "$(Get-ChromePath),4"
  New-Shortcut -Path $paths.StartMenuShortcut -Target $paths.LoaderPath -Description "Ephemeral Session Browser" -IconLocation "$(Get-ChromePath),4"

  # chrome is required, so attempt install
  Install-Chrome

  # initial run
  Start-Process -FilePath $paths.LoaderPath -ArgumentList "-RunAfterInstallOrUpdate"
}

function Start-InstallWizard() {
  $choice = Read-Host "Install or uninstall [i/u]?"

  if ($choice -eq 'i') {
    New-ESPInstall
  }
  elseif ($choice -eq 'u') {
    $removeProfiles = Read-Host "Remove profiles as well? [y/n]"
    if ($removeProfiles -eq 'y') {
      Remove-ESPInstall -RemoveProfiles:$true
    }
    else {
      Remove-ESPInstall -RemoveProfiles:$false
    }
  }
  else {
    Write-Host "Invalid choice. Please enter 'i' to install or 'u' to uninstall."
    Start-InstallWizard
  }

  Write-Host "Installation/Uninstallation complete. You can now run the Ephemeral Session Browser."
  Read-Host "Press Enter to exit"
}

#endregion

#region Browser

#$ProfilesPath = Join-Path -Path $PSScriptRoot -ChildPath "profiles"
#$BaseProfilePath = Join-Path -Path $ProfilesPath -ChildPath "base"

function Get-RandomRGB() {
  # generate a random HSL color hue, with fixed saturation and lightness
  $h = Get-Random -Minimum 0 -Maximum 360
  $s = Get-Random -Minimum 0.33 -Maximum 0.66
  $l = Get-Random -Minimum 0.33 -Maximum 0.66

  # HSL to RGB conversion
  $c = (1 - [math]::Abs(2 * $l - 1)) * $s
  $x = $c * (1 - [math]::Abs(($h / 60) % 2 - 1))
  $m = $l - $c / 2

  switch ($h) {
    { $_ -lt 60 } { $r1 = $c; $g1 = $x; $b1 = 0; break }
    { $_ -lt 120 } { $r1 = $x; $g1 = $c; $b1 = 0; break }
    { $_ -lt 180 } { $r1 = 0; $g1 = $c; $b1 = $x; break }
    { $_ -lt 240 } { $r1 = 0; $g1 = $x; $b1 = $c; break }
    { $_ -lt 300 } { $r1 = $x; $g1 = 0; $b1 = $c; break }
    default { $r1 = $c; $g1 = 0; $b1 = $x }
  }

  $r = [math]::Round(255 * ($r1 + $m))
  $g = [math]::Round(255 * ($g1 + $m))
  $b = [math]::Round(255 * ($b1 + $m))

  return "$r,$g,$b"
}

function Start-Browser([string] $ProfilePath, [bool] $IsBaseProfile) {
  $themeRGB = "255,255,255"
  if (-not $IsBaseProfile) {
    $themeRGB = Get-RandomRGB
  }

  Write-Host "starting chrome with profile at $ProfilePath, theme = $themeRGB, isBaseProfile = $IsBaseProfile"
  return Start-Process -FilePath "$(Get-ChromePath)" -ArgumentList @(
    "--user-data-dir=`"$ProfilePath`"",
    "--install-autogenerated-theme=`"$themeRGB`""
  ) -PassThru
}

function New-EphemeralProfileName() {
  $profileName = "tmp$(Get-Random -Minimum 1000 -Maximum 9999)"
  return $profileName
}

function Get-EphemeralProfilePath($ProfilesConfig, [string] $Name, [bool] $CreateIfNotExists) {
  $tmpProfilePath = Join-Path -Path ($ProfilesConfig.Directory) -ChildPath $Name

  if ($CreateIfNotExists -and -not (Test-Path -Path $tmpProfilePath)) {
    Write-Host "profile path $tmpProfilePath does not exist, creating it now"
    New-EphemeralProfile -ProfilesConfig $ProfilesConfig -Name $Name
  }

  return $tmpProfilePath
}

function New-EphemeralProfile($ProfilesConfig, [string] $Name) {
  $tmpProfilePath = Get-EphemeralProfilePath -ProfilesConfig $profiles -Name $Name -CreateIfNotExists:$false

  Write-Host "preparing temporary profile at $tmpProfilePath"
  Remove-Item -Path $tmpProfilePath -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item -Path ($ProfilesConfig.BaseProfile) -Destination $tmpProfilePath -Recurse -Force
}

function Remove-EphemeralProfile($ProfilesConfig, [string] $Name) {
  $tmpProfilePath = Get-EphemeralProfilePath -ProfilesConfig $ProfilesConfig -Name $Name -CreateIfNotExists:$false

  Write-Host "removing temporary profile at $tmpProfilePath"
  Remove-Item -Path $tmpProfilePath -Recurse -Force -ErrorAction SilentlyContinue
}

function Set-CachedProfileName($ProfilesConfig, [string] $Name) {
  $cachedProfilePath = Join-Path -Path ($ProfilesConfig.Directory) -ChildPath "cached.txt"
  if (-not (Test-Path -Path ($ProfilesConfig.Directory))) {
    New-Item -ItemType Directory -Path ($ProfilesConfig.Directory) -Force
  }
  Set-Content -Path $cachedProfilePath -Value $Name
  Write-Host "cached profile name set to $Name"
}

function Get-CachedProfileName($ProfilesConfig) {
  $cachedProfilePath = Join-Path -Path ($ProfilesConfig.Directory) -ChildPath "cached.txt"
  if (Test-Path -Path $cachedProfilePath) {
    return Get-Content -Path $cachedProfilePath
  }
  return $null
}

function Test-ShiftKeyPressedAsync() {
  Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class KeyHelper
{
  [DllImport("user32.dll")]
  static extern short GetAsyncKeyState(int vKey);

  public static bool IsKeyPressed(int keyCode)
  {
    // note: ^!= is required here since loader will otherwise mangle the expression
    return (GetAsyncKeyState(keyCode) & 0x8000) ^!= 0; 
  }
}
"@

  return [KeyHelper]::IsKeyPressed(0x10) # 0x10 == VK_SHIFT
}

function Show-BaseProfileInfoMessage($FirstRun) {
  try {
    $commonBody = @"
Any changes made to this profile will be saved and used for future sessions.
<br>
To save changes, simply close the browser window.
To access the base profile at a later time, press SHIFT while launching the Ephemeral Session Browser.
"@

    if ($FirstRun) {
      $title = "Welcome to the Ephemeral Session Browser"
      $body = @"
Welcome to the Ephemeral Session Browser!
<br>
Since this is the first time you're starting the browser, it started in the base profile.
$commonBody
"@
    }
    else {
      $title = "Ephemeral Session Browser"
      $body = @"
The Ephemeral Session Browser has started in the base profile upon your request.
$commonBody
"@
    }

    # loader mangles empty lines
    $body = $body -replace "<br>", "`n" 

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($body, $title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
  }
  catch {
    Write-Host "failed to show message box: $_"
  }
}

function Start-EphemeralBrowser() {
  $profiles = Get-ProfilesPaths

  if (-not (Test-Path -Path ($profiles.Directory))) {
    New-Item -ItemType Directory -Path ($profiles.Directory) -Force
  }

  $firstRun = -not (Test-Path -Path ($profiles.BaseProfile))
  $shiftPressed = Test-ShiftKeyPressedAsync
  if ($firstRun -or $shiftPressed -or $RunAfterInstallOrUpdate) {
    Write-Host "starting chrome with base profile at $($profiles.BaseProfile) (first run: $firstRun, shift pressed: $shiftPressed, after install or update: $RunAfterInstallOrUpdate)"
    $browser = Start-Browser -ProfilePath ($profiles.BaseProfile) -IsBaseProfile $true

    Show-BaseProfileInfoMessage -FirstRun $firstRun

    $browser.WaitForExit()

    Write-Host "recreating cached profile after editing base profile"
    $cachedProfileName = Get-CachedProfileName -ProfilesConfig $profiles
    if ($null -ne $cachedProfileName) {
      Remove-EphemeralProfile -ProfilesConfig $profiles -Name $cachedProfileName
    }
    $cachedProfileName = New-EphemeralProfileName
    New-EphemeralProfile -ProfilesConfig $profiles -Name $cachedProfileName
    Set-CachedProfileName -ProfilesConfig $profiles -Name $cachedProfileName
  }
  else {
    $cachedProfileName = Get-CachedProfileName -ProfilesConfig $profiles
    if ($null -eq $cachedProfileName) {
      Write-Host "no cached profile name found, creating profile on-demand"
      $cachedProfileName = New-EphemeralProfileName
      New-EphemeralProfile -ProfilesConfig $profiles -Name $cachedProfileName
    }

    $profilePath = Get-EphemeralProfilePath -ProfilesConfig $profiles -Name $cachedProfileName -CreateIfNotExists:$true
    $browser = Start-Browser -ProfilePath $profilePath -IsBaseProfile $false

    $nextProfileName = New-EphemeralProfileName
    New-EphemeralProfile -ProfilesConfig $profiles -Name $nextProfileName
    Set-CachedProfileName -ProfilesConfig $profiles -Name $nextProfileName

    $browser.WaitForExit()

    Remove-EphemeralProfile -ProfilesConfig $profiles -Name $cachedProfileName
  }
}

#endregion

function Main() {
  if ($Installer) {
    Start-InstallWizard
    return
  }

  Start-EphemeralBrowser
}
Main
