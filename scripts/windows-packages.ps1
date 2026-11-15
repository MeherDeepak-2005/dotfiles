# Called from Git Bash by startup.sh. Installs native Windows binaries, never WSL.
[CmdletBinding()]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packages = @(
    @{ Name = 'git'; Command = 'git' },
    @{ Name = 'vcredist2022'; Command = '' },
    @{ Name = 'neovim'; Command = 'nvim' },
    @{ Name = 'wezterm'; Command = 'wezterm' },
    @{ Name = 'psmux'; Command = 'psmux' },
    @{ Name = 'starship'; Command = 'starship' },
    @{ Name = 'eza'; Command = 'eza' },
    @{ Name = 'fd'; Command = 'fd' },
    @{ Name = 'ripgrep'; Command = 'rg' },
    @{ Name = 'fzf'; Command = 'fzf' },
    @{ Name = 'python'; Command = 'python' },
    @{ Name = 'lua'; Command = 'lua' },
    @{ Name = 'luarocks'; Command = 'luarocks' },
    @{ Name = 'Hack-NF'; Command = '' }
)

if ($DryRun) {
    Write-Host 'DRY RUN: native Windows / Scoop; no installations or changes.'
    $packages | ForEach-Object { Write-Host ('Install/update or reuse: ' + $_.Name) }
    exit 0
}

$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run startup.sh from a normal, non-administrator Git Bash window. Scoop is per-user.'
}

$scoop = Join-Path $scoopRoot 'shims\scoop.ps1'
if (!(Test-Path -LiteralPath $scoop)) {
    Write-Host 'Installing Scoop from its official installer.'
    $installer = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-scoop-' + [Guid]::NewGuid() + '.ps1')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -OutFile $installer
        & $installer
        if (!(Test-Path -LiteralPath $scoop)) { throw 'Scoop installation did not complete.' }
    } finally {
        Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    }
}
$env:PATH = (Join-Path $scoopRoot 'shims') + ';' + $env:PATH

function Invoke-Scoop {
    param([string[]]$ScoopArgs)
    & $scoop @ScoopArgs
    if ($LASTEXITCODE -ne 0) { throw ('Scoop failed: ' + ($ScoopArgs -join ' ')) }
}

Invoke-Scoop -ScoopArgs @('update')
$buckets = @{
    'extras' = 'https://github.com/ScoopInstaller/Extras'
    'nerd-fonts' = 'https://github.com/matthewjberger/scoop-nerd-fonts'
    'psmux' = 'https://github.com/psmux/scoop-psmux'
}
foreach ($name in $buckets.Keys) {
    if (!(Test-Path -LiteralPath (Join-Path $scoopRoot ('buckets\' + $name)))) {
        Invoke-Scoop -ScoopArgs @('bucket', 'add', $name, $buckets[$name])
    }
}

foreach ($package in $packages) {
    $name = $package.Name
    $current = Join-Path $scoopRoot ('apps\' + $name + '\current')
    if ($name -eq 'vcredist2022' -and !(Test-Path -LiteralPath $current) -and
        (Test-Path -LiteralPath "$env:WINDIR\System32\vcruntime140.dll")) {
        Write-Host 'Microsoft Visual C++ runtime already present.'
        continue
    }
    if (Test-Path -LiteralPath $current) {
        # Scoop compares the installed version with refreshed manifests and skips current apps.
        Invoke-Scoop -ScoopArgs @('update', $name)
        continue
    }
    $external = if ($package.Command) { Get-Command $package.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
    # Windows Store's Python launcher is an alias, not an installed interpreter.
    if ($name -eq 'python' -and $external -and $external.Source -like '*\Microsoft\WindowsApps\*') {
        $external = $null
    }
    if ($external) {
        Write-Host ('Found an existing installation: ' + $external.Source)
        Write-Host 'Keep it (you manage its updates), or install a Scoop-managed copy for automatic updates?'
        $choice = Read-Host '[k]eep / [s]coop [k]'
        if ($choice -ne 's' -and $choice -ne 'S') {
            Write-Host ('Kept external ' + $name + '; its original package manager remains responsible for updates.')
            continue
        }
    }
    $qualified = switch ($name) {
        'wezterm' { 'extras/wezterm' }
        'Hack-NF' { 'nerd-fonts/Hack-NF' }
        'vcredist2022' { 'extras/vcredist2022' }
        'psmux' { 'psmux/psmux' }
        default { $name }
    }
    Invoke-Scoop -ScoopArgs @('install', $qualified)
}

Write-Host 'Native Windows packages checked. Scoop-managed packages update only when outdated.'
Write-Host 'Existing installations you chose to keep retain their original update mechanism.'
