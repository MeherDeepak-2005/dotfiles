# Fresh Windows entry point: install Git Bash, then run the same startup.sh.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Find-GitBash {
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "$env:USERPROFILE\scoop\apps\git\current\bin\bash.exe"
    )
    if ($env:SCOOP) { $candidates += "$env:SCOOP\apps\git\current\bin\bash.exe" }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git) {
        $candidates += Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

$bash = Find-GitBash
if (!$bash) {
    if (!(Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Install Microsoft App Installer (winget) or Git for Windows, then rerun this script. https://git-scm.com/download/win'
    }
    Write-Host 'Installing Git for Windows, including Git Bash. An installer may request elevation.'
    & winget.exe install --id Git.Git --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Git for Windows installation failed.' }
    $bash = Find-GitBash
    if (!$bash) { throw 'Git Bash was not found. Open a new PowerShell window and rerun bootstrap.ps1.' }
}

# Scoop and all configs are installed as the current ordinary user, not an admin.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Git Bash is ready. Run bootstrap.ps1 again from a non-administrator PowerShell window.'
}

$localStartup = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'startup.sh' } else { $null }
if ($localStartup -and (Test-Path -LiteralPath $localStartup)) {
    $unixStartup = $localStartup -replace '\\', '/'
    & $bash $unixStartup
    $installExit = $LASTEXITCODE
} else {
    $temporaryStartup = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-startup-' + [Guid]::NewGuid() + '.sh')
    try {
        Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/MeherDeepak-2005/dotfiles/main/startup.sh' -OutFile $temporaryStartup
        & $bash ($temporaryStartup -replace '\\', '/')
        $installExit = $LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $temporaryStartup -Force -ErrorAction SilentlyContinue
    }
}
if ($installExit -ne 0) { throw 'Dotfiles setup did not complete. See the error above.' }
