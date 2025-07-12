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
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File %TARGET% -StartInstallWizard
del "%TARGET%" 2>nul
goto :EOF
exit
# --- end of installer bootstrapper ---

param(
  [switch]
  $StartInstallWizard,

  [switch]
  $Uninstall, # only in combination with -StartInstallWizard

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

function Get-UninstallKey([switch] $Create) {
  $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\EphemeralSessionBrowser"
  if ($Create -and (-not (Test-Path -Path $uninstallKey))) {
    New-Item -Path $uninstallKey -Force | Out-Null
  }
  return $uninstallKey
}

function Remove-ESPInstall([switch] $RemoveProfiles) {
  Write-Host "Removing EphemeralSessionBrowser installation..."
  $paths = Get-InstallPaths

  Remove-Item -Path $paths.MainScriptPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.LoaderPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.DesktopShortcut -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.StartMenuShortcut -ErrorAction SilentlyContinue

  Remove-Item -Path (Get-UninstallKey -Create:$false) -ErrorAction SilentlyContinue

  if ($RemoveProfiles) {
    Remove-Item -Path ((Get-ProfilesPaths).Directory) -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function New-ESPInstall([switch] $DesktopShortcut, [switch] $StartMenuShortcut) {
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

  # chrome is required, so attempt install
  Install-Chrome

  $displayName = "Ephemeral Session Browser"
  $shortcutIcon = "$(Get-ChromePath),4"

  # add uninstall entry to registry
  $uninstallKey = Get-UninstallKey -Create
  Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value $displayName
  Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $shortcutIcon
  Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "shadow578"
  Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "$($paths.LoaderPath) -StartInstallWizard -Uninstall"
  Set-ItemProperty -Path $uninstallKey -Name "ModifyPath" -Value "$($paths.LoaderPath) -StartInstallWizard"

  # create shortcuts
  if ($DesktopShortcut) {
    New-Shortcut -Path $paths.DesktopShortcut -Target $paths.LoaderPath -Description $displayName -IconLocation $shortcutIcon
  }

  if ($StartMenuShortcut) {
    New-Shortcut -Path $paths.StartMenuShortcut -Target $paths.LoaderPath -Description $displayName -IconLocation $shortcutIcon
  }
}

function Start-ESPAfterInstallOrUpdate() {
  Start-Process -FilePath ((Get-InstallPaths).LoaderPath) -ArgumentList "-RunAfterInstallOrUpdate"
}

function Start-TUIInstallWizard() {
  Write-Host "Welcome to the Ephemeral Session Browser installation wizard."

  if ($Uninstall) {
    $choice = "u"
  }
  else {
    $choice = Read-Host "Do you want to (I)nstall or (U)ninstall the Ephemeral Session Browser? [I/U]"
    $choice = $choice.Trim().ToLower()
  }

  if ($choice.StartsWith('i')) {
    $desktopShortcut = Read-Host "Do you want to create a desktop shortcut? [Yes/No]"
    $desktopShortcut = $desktopShortcut.Trim().ToLower()
    $desktopShortcut = $desktopShortcut.StartsWith('y')

    $startMenuShortcut = Read-Host "Do you want to create a Start Menu shortcut? [Yes/No]"
    $startMenuShortcut = $startMenuShortcut.Trim().ToLower()
    $startMenuShortcut = $startMenuShortcut.StartsWith('y')

    $runAfterInstall = Read-Host "Do you want to run the Ephemeral Session Browser after installation completes? [Yes/No]"
    $runAfterInstall = $runAfterInstall.Trim().ToLower()
    $runAfterInstall = $runAfterInstall.StartsWith('y')

    New-ESPInstall -DesktopShortcut:$desktopShortcut -StartMenuShortcut:$startMenuShortcut

    if ($runAfterInstall) {
      Start-ESPAfterInstallOrUpdate
    }
  }
  elseif ($choice.StartsWith('u')) {
    $removeProfiles = Read-Host "Do you want to remove profiles as well? [Yes/No]"
    $removeProfiles = $removeProfiles.Trim().ToLower()
    $removeProfiles = $removeProfiles.StartsWith('y')

    Remove-ESPInstall -RemoveProfiles:$removeProfiles
  }
  else {
    Write-Host "Invalid choice. Please enter 'I' to install or 'U' to uninstall."
    Start-InstallWizard
  }

  Write-Host "Installation/Uninstallation complete."
  Read-Host "Press Enter to exit"
}

function Start-GUIInstallWizard() {
  # install location currently cannot be changed, but is displayed for information purposes
  $fixedInstallLocation = (Get-InstallPaths).InstallDirectory

  $githubUrl = "https://github.com/shadow578/Entra-Intune-Utilities/tree/main/EphemeralSessionBrowser"

  $isInstalled = Test-Path -Path ((Get-InstallPaths).MainScriptPath)

  Add-Type -AssemblyName System.Windows.Forms

  #region main window
  $window = New-Object System.Windows.Forms.Form
  $window.Text = "Ephemeral Session Browser Installation Wizard"
  $window.Size = New-Object System.Drawing.Size(400, 400)
  $window.StartPosition = "CenterScreen"
  $window.FormBorderStyle = "FixedDialog"
  $window.MaximizeBox = $false
  $window.MinimizeBox = $false

  $tabControl = New-Object System.Windows.Forms.TabControl
  $tabControl.Size = $window.Size
  $tabControl.Location = New-Object System.Drawing.Point(0, 0)
  $window.Controls.Add($tabControl)
  #endregion

  $tabContentSize = New-Object System.Drawing.Size(($window.ClientSize.Width), ($window.ClientSize.Height))
  
  #region install tab
  $y = 10

  $installTab = New-Object System.Windows.Forms.TabPage

  if ($isInstalled) {
    $installTab.Text = "Update"
  }
  else {
    $installTab.Text = "Install"
  }

  $welcomeText = New-Object System.Windows.Forms.Label
  $welcomeText.Text = @"
Welcome to the Ephemeral Session Browser Installation Wizard!
Use the options below to configure your installation.
"@
  $welcomeText.MaximumSize = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 100)
  $welcomeText.Location = New-Object System.Drawing.Point(10, $y)
  $welcomeText.AutoSize = $true
  $installTab.Controls.Add($welcomeText)

  $welcomeText.PerformLayout()
  $y += $welcomeText.Size.Height + 10

  $installLocationLabel = New-Object System.Windows.Forms.Label
  $installLocationLabel.Text = "Installation Location:"
  $installLocationLabel.Location = New-Object System.Drawing.Point(10, $y)
  $installLocationLabel.AutoSize = $true
  $installTab.Controls.Add($installLocationLabel)

  $installLocationLabel.PerformLayout()
  $y += $installLocationLabel.Size.Height

  $installLocationTextBox = New-Object System.Windows.Forms.TextBox
  $installLocationTextBox.Text = $fixedInstallLocation
  $installLocationTextBox.Location = New-Object System.Drawing.Point(10, $y)
  $installLocationTextBox.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 20)
  $installLocationTextBox.Enabled = $false
  $installTab.Controls.Add($installLocationTextBox)

  $installLocationTextBox.PerformLayout()
  $y += $installLocationTextBox.Height + 10

  $createDesktopShortcutCheck = New-Object System.Windows.Forms.CheckBox
  $createDesktopShortcutCheck.Text = "Create a desktop shortcut"
  $createDesktopShortcutCheck.Location = New-Object System.Drawing.Point(10, $y)
  $createDesktopShortcutCheck.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 20)
  $createDesktopShortcutCheck.Checked = $true
  $installTab.Controls.Add($createDesktopShortcutCheck)

  $createDesktopShortcutCheck.PerformLayout()
  $y += $createDesktopShortcutCheck.Height + 10

  $createStartMenuShortcutCheck = New-Object System.Windows.Forms.CheckBox
  $createStartMenuShortcutCheck.Text = "Add to Start Menu"
  $createStartMenuShortcutCheck.Location = New-Object System.Drawing.Point(10, $y)
  $createStartMenuShortcutCheck.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 20)
  $createStartMenuShortcutCheck.Checked = $true
  $installTab.Controls.Add($createStartMenuShortcutCheck)

  $createStartMenuShortcutCheck.PerformLayout()
  $y += $createStartMenuShortcutCheck.Height + 10

  $launchAfterInstallCheck = New-Object System.Windows.Forms.CheckBox
  $launchAfterInstallCheck.Text = "Launch to base profile after installation"
  $launchAfterInstallCheck.Location = New-Object System.Drawing.Point(10, $y)
  $launchAfterInstallCheck.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 20)
  $launchAfterInstallCheck.Checked = $true
  $installTab.Controls.Add($launchAfterInstallCheck)

  #$launchAfterInstallCheck.PerformLayout()
  #$y += $launchAfterInstallCheck.Height + 10

  $installButton = New-Object System.Windows.Forms.Button

  if ($isInstalled) {
    $installButton.Text = "Update now"
  }
  else {
    $installButton.Text = "Install now"
  }

  $installButton.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 100), 30)
  $installButton.Location = New-Object System.Drawing.Point(50, ($tabContentSize.Height - 30 - 50))
  $installButton.Add_Click({      
      New-ESPInstall -DesktopShortcut:$createDesktopShortcutCheck.Checked -StartMenuShortcut:$createStartMenuShortcutCheck.Checked
      [System.Windows.Forms.MessageBox]::Show("Ephemeral Session Browser has been installed successfully.", "Installation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
      
      if ($launchAfterInstallCheck.Checked) {
        Start-ESPAfterInstallOrUpdate
      }
      
      $window.Close()
    })

  $installTab.Controls.Add($installButton)
  $tabControl.TabPages.Add($installTab)
  #endregion

  #region uninstall tab
  $y = 10

  $uninstallTab = New-Object System.Windows.Forms.TabPage
  $uninstallTab.Text = "Uninstall"
  $uninstallTab.Enabled = $isInstalled

  $byeText = New-Object System.Windows.Forms.Label
  $byeText.Text = @"
Welcome to the Ephemeral Session Browser Removal Wizard!
This wizard will help you remove the Ephemeral Session Browser from your system.
If you choose to remove the base profile, all associated data will be deleted.
"@
  $byeText.MaximumSize = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 100)
  $byeText.Location = New-Object System.Drawing.Point(10, $y)
  $byeText.AutoSize = $true
  $uninstallTab.Controls.Add($byeText)

  $byeText.PerformLayout()
  $y += $byeText.Size.Height + 10

  $removeProfilesCheck = New-Object System.Windows.Forms.CheckBox
  $removeProfilesCheck.Text = "Remove profiles (including base profile)"
  $removeProfilesCheck.Location = New-Object System.Drawing.Point(10, $y)
  $removeProfilesCheck.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 20)
  $uninstallTab.Controls.Add($removeProfilesCheck)

  #$removeProfilesCheck.PerformLayout()
  #$y += $removeProfilesCheck.Height + 10

  $uninstallButton = New-Object System.Windows.Forms.Button
  $uninstallButton.Text = "Uninstall now"
  $uninstallButton.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 100), 30)
  $uninstallButton.Location = New-Object System.Drawing.Point(50, ($tabContentSize.Height - 30 - 50))
  $uninstallButton.Add_Click({
      Remove-ESPInstall -RemoveProfiles:$removeProfilesCheck.Checked
      [System.Windows.Forms.MessageBox]::Show("Ephemeral Session Browser has been uninstalled successfully.", "Uninstallation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
      $window.Close()
    })

  $uninstallTab.Controls.Add($uninstallButton)
  $tabControl.TabPages.Add($uninstallTab)
  #endregion

  #region base profile tab
  $y = 10

  $baseProfileTab = New-Object System.Windows.Forms.TabPage
  $baseProfileTab.Text = "Base Profile"
  $baseProfileTab.Enabled = $isInstalled

  $baseProfileText = New-Object System.Windows.Forms.Label
  $baseProfileText.Text = @"
The base profile controls the behavior of the ephemeral sessions.
Changes made to the base profile will persist across sessions.
Use it to set up bookmarks, extensions, and other settings that you want to keep.
<br>
Besides this tool, you can also access the base profile by pressing SHIFT while launching the Ephemeral Session Browser.
"@ -replace "<br>", "`n"
  $baseProfileText.MaximumSize = New-Object System.Drawing.Size(($tabContentSize.Width - 20), ($tabContentSize.Height - 20 - 20))
  $baseProfileText.Location = New-Object System.Drawing.Point(10, 10)
  $baseProfileText.AutoSize = $true
  $baseProfileTab.Controls.Add($baseProfileText)

  $baseProfileText.PerformLayout()
  $y += $baseProfileText.Size.Height + 10

  $baseProfileButton = New-Object System.Windows.Forms.Button
  $baseProfileButton.Text = "Open Base Profile"
  $baseProfileButton.Location = New-Object System.Drawing.Point(10, $y)
  $baseProfileButton.Size = New-Object System.Drawing.Size(($tabContentSize.Width - 20), 30)
  $baseProfileButton.Add_Click({
      Start-ESPAfterInstallOrUpdate
    })
  $baseProfileTab.Controls.Add($baseProfileButton)

  $baseProfileButton.PerformLayout()
  $y += $baseProfileButton.Height + 10

  $tabControl.TabPages.Add($baseProfileTab)
  #endregion

  #region about tab
  $y = 10

  $aboutTab = New-Object System.Windows.Forms.TabPage
  $aboutTab.Text = "About"

  $aboutText = New-Object System.Windows.Forms.Label
  $aboutText.Text = @"
Ephemeral Session Browser, developed by shadow587.
<br>
This tool allows you to run many independent browser sessions side-by-side, equivalent to running many independent incognito windows.
Changes made to these sessions does not persist after the browser is closed, making it ideal temporary browsing needs.
<br>
Ephemeral Session Browser is licensed under the Apache License 2.0.
More information can be found on the project's GitHub page.
"@ -replace "<br>", "`n"
  $aboutText.MaximumSize = New-Object System.Drawing.Size(($tabContentSize.Width - 20), ($tabContentSize.Height - 20 - 20))
  $aboutText.Location = New-Object System.Drawing.Point(10, 10)
  $aboutText.AutoSize = $true
  $aboutTab.Controls.Add($aboutText)

  $aboutText.PerformLayout()
  $y += $aboutText.Size.Height + 10

  $githubLink = New-Object System.Windows.Forms.LinkLabel
  $githubLink.Text = "Visit the GitHub page"
  $githubLink.Location = New-Object System.Drawing.Point(10, $y)
  $githubLink.AutoSize = $true
  $githubLink.Add_Click({
      Write-Host "Opening $githubUrl..."
      Start-Process $githubUrl
    })
  $aboutTab.Controls.Add($githubLink)

  #$githubLink.PerformLayout()
  #$y += $githubLink.Height + 10

  $tabControl.TabPages.Add($aboutTab)
  #endregion

  if ($Uninstall) {
    $tabControl.SelectedIndex = 1
  }

  $window.ShowDialog()
}

function Start-InstallWizard() {
  Write-Host "Starting install wizard..."

  try {
    Start-GUIInstallWizard
  }
  catch {
    Write-Host "Failed to start GUI install wizard, falling back to TUI install wizard." -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Start-TUIInstallWizard
  }
}

#endregion

#region Browser

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
  if ($StartInstallWizard) {
    Start-InstallWizard
    return
  }

  Start-EphemeralBrowser
}
Main
