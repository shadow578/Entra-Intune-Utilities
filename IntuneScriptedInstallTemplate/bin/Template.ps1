<# Intune Win32 Scripted Install Template, Version 25W20a #>
param(
    <# Install the program #>
    [Parameter()]
    [switch]
    $Install,

    <# Uninstall the program #>
    [Parameter()]
    [switch]
    $Remove
)

function DoInstall() {
    # check all files required for the install are present
    # use $PSSCRIPTROOT\ to check for files in the same directory as this script
    $installDependencies = @(
        # "$PSScriptRoot\my_installer.msi",
    )
    foreach ($file in $installDependencies) {
        if (-not (Test-Path -Path $file -PathType Leaf)) {
            Write-Host "missing dependency: '$file'"
            exit 404
        }
    }


    # run a msi installer, waiting for it to finish
    # more arguments may be added if required
    #
    # Start-Process -FilePath "C:\Windows\System32\msiexec.exe" -ArgumentList @(
    #     "/i",
    #     "`"$PSScriptRoot\my_installer.msi`"",
    #     "/qn"
    # ) -Wait


    # wait for a file to be created during the install, with a timeout of 10 minutes
    # the function should be moved out of the DoInstall function if it is used
    #
    # function WaitForFile([string] $Path, [int] $Timeout = 600)
    # {
    #     Write-Host "Waiting for $Path, timeout $Timeout seconds"
    # 
    #     $found = $false
    #     $elapsed = 0
    #     while($elapsed -lt $Timeout)
    #     {
    #         if (Test-Path -Path $Path)
    #         {
    #             Write-Host "Found $Path"
    #             $found = $true
    #             break
    #         }
    # 
    #         Start-Sleep -Seconds 10
    #         $elapsed += 10
    #     }
    #     
    #     if (-not $found)
    #     {
    #         Write-Host "Timeout waiting for $Path to be created"
    #     }
    # 
    #     return $found
    # }
    # 
    # if (-not (WaitForFile -Path "C:\Path\To\program.exe"))
    # {
    #     exit 500
    # }
    

    #TODO: add your custom install logic here
}

function DoUninstall() {
    #TODO: add your custom uninstall logic here
}

$global:ProjectName = "<<TEMPLATE_PROJECT_NAME>>".Replace("<", "").Replace(">", "")
$global:Version = "<<TEMPLATE_VERSION_STRING>>"

Start-Transcript -Path "C:\MDM\Logs\$($ProjectName).log" -ErrorAction SilentlyContinue
if ($Install) {
    Write-Host "Starting Install of $($ProjectName) $($Version)" -InformationAction "Continue"
    DoInstall
}
elseif ($Remove) {
    Write-Host "Starting Removal of $($ProjectName) $($Version)" -InformationAction "Continue"
    DoUninstall
}
