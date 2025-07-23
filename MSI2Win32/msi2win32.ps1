param(
    [Parameter(Mandatory = $true)]
    [string]
    $MSIFile
)


function Main() {
    $msiDirectory = Split-Path -Parent $MSIFile
    $msiFileName = Split-Path -Leaf $MSIFile

    Remove-Item -Path "$PSSCRIPTROOT\Temp" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path "$PSSCRIPTROOT\Temp" -ItemType Directory -Force | Out-Null
    Copy-Item -Path $MSIFile -Destination "$PSSCRIPTROOT\Temp\$msiFileName" -Force

    Write-Host "Processing $msiDirectory : $msiFileName"

    push-location "$PSSCRIPTROOT\Temp"
    Start-Process -FilePath "$PSSCRIPTROOT\IntuneWinAppUtil.exe" -ArgumentList @(
        "-c", ".",
        "-s", "$msiFileName",
        "-o", "."
    ) -NoNewWindow -Wait
    pop-location

    Copy-Item -Path "$PSSCRIPTROOT\Temp\*.intunewin" -Destination "$msiDirectory\" -Force
    Remove-Item -Path "$PSSCRIPTROOT\Temp" -Recurse -Force -ErrorAction SilentlyContinue
}
Main
