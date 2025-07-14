C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Clear-Host; Write-Host 'Loading...'; $src = '%~0'; $target = Join-Path -Path $env:TEMP -ChildPath '%~n0.ps1'; $eol = $false; (@(Get-Content -Path $src | Where-Object { if($_ -eq '# END OF LOADER #') { $eol = $true }; return $eol }) -join ([char]0xa)) | Out-File -FilePath $target; Invoke-Expression -Command ($target + ' -StartInstallWizard'); Remove-Item -Path $target -Force"
goto :EOF
exit
# END OF LOADER #

<#
This script is used to install or update the Ephemeral Session Browser, as well as containing the main logic itself.
The ESB allows you to run a Chromium-based browser in a temporary session, which is useful for having 
many (temporary) browser sessions without cluttering your main browser profile, or having to resort to many browsers 
and using their incognito mode.

Ephemeral Session Browser is licensed to you under the Apache License 2.0.
https://github.com/shadow578/Entra-Intune-Utilities/tree/main/EphemeralSessionBrowser
(c) 2025 shadow578
#>
param(
  [switch]
  $StartInstallWizard,

  [switch]
  $Uninstall, # only in combination with -StartInstallWizard

  [switch]
  $RunAfterInstallOrUpdate
)


# the program information table allows you to easily rename the program, making white-labeling easy.
$ProgramInfo = [PSCustomObject]@{
  # the version of the program.
  Version        = "25W28b"

  # the vendor is displayed as the developer of the program in various places.
  Vendor         = "shadow587"

  # the name of the program.
  # "Name" is used for the executable etc. and should not contain spaces.
  # "DisplayName" is used for the user interface and can contain spaces.
  Name           = "EphemeralSessionBrowser"
  DisplayName    = "Ephemeral Session Browser"

  # additional information only shown in the about dialog.
  # the url is opened via Start-Process, so it can be any valid URL (even mailto:)
  License        = "Apache License 2.0"
  AboutLinkText  = "Visit the GitHub repository"
  AboutLinkUrl   = "https://github.com/shadow578/Entra-Intune-Utilities/tree/main/EphemeralSessionBrowser"

  # the program icon that is used for the shortcuts and in the uninstall entry.
  # create using this command:
  # [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes(".\assets\ESB.ico")) | Set-Clipboard
  ProgramIconB64 = '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'
}

function Get-ChromePath([switch] $AllowNull) {
  $cmd = Get-Command "chrome.exe" -ErrorAction SilentlyContinue
  if ($null -eq $cmd) {
    $cmd = Get-Command "C:\Program Files\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
  }
  if ($null -eq $cmd) {
    $cmd = Get-Command "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" -ErrorAction SilentlyContinue
  }

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
  $installDirectory = Join-Path -Path $env:LOCALAPPDATA -ChildPath "$($ProgramInfo.Vendor)\$($ProgramInfo.Name)"
  
  return [PSCustomObject]@{
    InstallDirectory  = $installDirectory
    MainScriptPath    = Join-Path -Path $installDirectory -ChildPath "$($ProgramInfo.Name).ps1"
    LoaderPath        = Join-Path -Path $installDirectory -ChildPath "$($ProgramInfo.Name).loader.bat"
    ProgramIcon       = Join-Path -Path $installDirectory -ChildPath "$($ProgramInfo.Name).ico"
    DesktopShortcut   = Join-Path -Path $desktopPath -ChildPath "$($ProgramInfo.DisplayName).lnk"
    StartMenuShortcut = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs\$($ProgramInfo.DisplayName).lnk"
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
  $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$($ProgramInfo.Name)"
  if ($Create -and (-not (Test-Path -Path $uninstallKey))) {
    New-Item -Path $uninstallKey -Force | Out-Null
  }
  return $uninstallKey
}

function Remove-ESBInstall([switch] $RemoveProfiles) {
  Write-Host "Removing $($ProgramInfo.DisplayName) installation..."
  $paths = Get-InstallPaths

  Remove-Item -Path $paths.MainScriptPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.LoaderPath -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.DesktopShortcut -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.StartMenuShortcut -ErrorAction SilentlyContinue
  Remove-Item -Path $paths.ProgramIcon -ErrorAction SilentlyContinue

  Remove-Item -Path (Get-UninstallKey -Create:$false) -ErrorAction SilentlyContinue

  if ($RemoveProfiles) {
    Remove-Item -Path ((Get-ProfilesPaths).Directory) -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $paths.InstallDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function New-ESBInstall([switch] $DesktopShortcut, [switch] $StartMenuShortcut) {
  # before installing, remove any previous installation, keeping profiles
  Remove-ESBInstall -RemoveProfiles:$false

  Write-Host "Installing $($ProgramInfo.DisplayName)..."
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

  # decode and write program icon
  [System.IO.File]::WriteAllBytes($paths.ProgramIcon, [System.Convert]::FromBase64String($ProgramInfo.ProgramIconB64))

  # add uninstall entry to registry
  $uninstallKey = Get-UninstallKey -Create
  Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value $ProgramInfo.DisplayName
  Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value $paths.ProgramIcon
  Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value $ProgramInfo.Vendor
  Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value $ProgramInfo.Version
  Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "$($paths.LoaderPath) -StartInstallWizard -Uninstall"
  Set-ItemProperty -Path $uninstallKey -Name "ModifyPath" -Value "$($paths.LoaderPath) -StartInstallWizard"

  # create shortcuts
  if ($DesktopShortcut) {
    New-Shortcut -Path $paths.DesktopShortcut -Target $paths.LoaderPath -Description $ProgramInfo.DisplayName -IconLocation $paths.ProgramIcon
  }

  if ($StartMenuShortcut) {
    New-Shortcut -Path $paths.StartMenuShortcut -Target $paths.LoaderPath -Description $ProgramInfo.DisplayName -IconLocation $paths.ProgramIcon
  }
}

function Start-ESBAfterInstallOrUpdate() {
  Start-Process -FilePath ((Get-InstallPaths).LoaderPath) -ArgumentList "-RunAfterInstallOrUpdate"
}

function Start-TUIInstallWizard() {
  Write-Host "Welcome to the $($ProgramInfo.DisplayName) installation wizard."

  if ($Uninstall) {
    $choice = "u"
  }
  else {
    $choice = Read-Host "Do you want to (I)nstall or (U)ninstall the $($ProgramInfo.DisplayName)? [I/U]"
    $choice = $choice.Trim().ToLower()
  }

  if ($choice.StartsWith('i')) {
    $desktopShortcut = Read-Host "Do you want to create a desktop shortcut? [Yes/No]"
    $desktopShortcut = $desktopShortcut.Trim().ToLower()
    $desktopShortcut = $desktopShortcut.StartsWith('y')

    $startMenuShortcut = Read-Host "Do you want to create a Start Menu shortcut? [Yes/No]"
    $startMenuShortcut = $startMenuShortcut.Trim().ToLower()
    $startMenuShortcut = $startMenuShortcut.StartsWith('y')

    $runAfterInstall = Read-Host "Do you want to run the $($ProgramInfo.DisplayName) after installation completes? [Yes/No]"
    $runAfterInstall = $runAfterInstall.Trim().ToLower()
    $runAfterInstall = $runAfterInstall.StartsWith('y')

    New-ESBInstall -DesktopShortcut:$desktopShortcut -StartMenuShortcut:$startMenuShortcut

    if ($runAfterInstall) {
      Start-ESBAfterInstallOrUpdate
    }
  }
  elseif ($choice.StartsWith('u')) {
    $removeProfiles = Read-Host "Do you want to remove profiles as well? [Yes/No]"
    $removeProfiles = $removeProfiles.Trim().ToLower()
    $removeProfiles = $removeProfiles.StartsWith('y')

    Remove-ESBInstall -RemoveProfiles:$removeProfiles
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

  $isInstalled = Test-Path -Path ((Get-InstallPaths).MainScriptPath)

  Add-Type -AssemblyName System.Windows.Forms

  #region main window
  $window = New-Object System.Windows.Forms.Form
  $window.Text = "$($ProgramInfo.DisplayName) Installation Wizard"
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
Welcome to the $($ProgramInfo.DisplayName) Installation Wizard!
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
      New-ESBInstall -DesktopShortcut:$createDesktopShortcutCheck.Checked -StartMenuShortcut:$createStartMenuShortcutCheck.Checked
      [System.Windows.Forms.MessageBox]::Show("$($ProgramInfo.DisplayName) has been installed successfully.", "Installation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
      
      if ($launchAfterInstallCheck.Checked) {
        Start-ESBAfterInstallOrUpdate
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
Welcome to the $($ProgramInfo.DisplayName) Removal Wizard!
This wizard will help you remove the $($ProgramInfo.DisplayName) from your system.
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
      Remove-ESBInstall -RemoveProfiles:$removeProfilesCheck.Checked
      [System.Windows.Forms.MessageBox]::Show("$($ProgramInfo.DisplayName) has been uninstalled successfully.", "Uninstallation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
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

Besides this tool, you can also access the base profile by pressing SHIFT while launching the $($ProgramInfo.DisplayName).
"@
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
      Start-ESBAfterInstallOrUpdate
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
$($ProgramInfo.DisplayName) ($($ProgramInfo.Version)), by $($ProgramInfo.Vendor).

This tool allows you to run many independent browser sessions side-by-side, equivalent to running many independent incognito windows.
Changes made to these sessions does not persist after the browser is closed, making it ideal temporary browsing needs.

$($ProgramInfo.DisplayName) is licensed under the $($ProgramInfo.License).
"@
  $aboutText.MaximumSize = New-Object System.Drawing.Size(($tabContentSize.Width - 20), ($tabContentSize.Height - 20 - 20))
  $aboutText.Location = New-Object System.Drawing.Point(10, 10)
  $aboutText.AutoSize = $true
  $aboutTab.Controls.Add($aboutText)

  $aboutText.PerformLayout()
  $y += $aboutText.Size.Height + 10

  $githubLink = New-Object System.Windows.Forms.LinkLabel
  $githubLink.Text = $ProgramInfo.AboutLinkText
  $githubLink.Location = New-Object System.Drawing.Point(10, $y)
  $githubLink.AutoSize = $true
  $githubLink.Add_Click({
      Write-Host "Opening $($ProgramInfo.AboutLinkUrl)..."
      Start-Process $ProgramInfo.AboutLinkUrl
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
    "--install-autogenerated-theme=`"$themeRGB`"",
    "--no-default-browser-check",
    "--no-first-run"
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
    return (GetAsyncKeyState(keyCode) & 0x8000) != 0; 
  }
}
"@

  return [KeyHelper]::IsKeyPressed(0x10) # 0x10 == VK_SHIFT
}

function Show-BaseProfileInfoMessage($FirstRun) {
  try {
    $commonBody = @"
Any changes made to this profile will be saved and used for future sessions.

To save changes, simply close the browser window.
To access the base profile at a later time, press SHIFT while launching the $($ProgramInfo.DisplayName).
"@

    if ($FirstRun) {
      $title = "Welcome to the $($ProgramInfo.DisplayName)"
      $body = @"
Welcome to the $($ProgramInfo.DisplayName)!

Since this is the first time you're starting the browser, it started in the base profile.
$commonBody
"@
    }
    else {
      $title = "$($ProgramInfo.DisplayName)"
      $body = @"
The $($ProgramInfo.DisplayName) has started in the base profile upon your request.
$commonBody
"@
    }

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
  Write-Host "$($ProgramInfo.DisplayName) Version $($ProgramInfo.Version)"

  if ($StartInstallWizard) {
    Start-InstallWizard
    return
  }

  Start-EphemeralBrowser
}
Main
