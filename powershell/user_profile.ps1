# set PowerShell to UTF-8

Import-Module posh-git
Import-Module oh-my-posh
$omp_config = Join-Path $PSScriptRoot ".\deepak.omp.json"
oh-my-posh --init --shell pwsh --config $omp_config | Invoke-Expression
Set-PoshPrompt Parado

# Alias
Set-Alias -Name vim -Value nvim
Set-Alias ll ls
Set-Alias g git
Set-Alias grep findstr
Set-Alias conda "/Users/meher/opt/anaconda3/bin/conda"
Set-Alias python "~/opt/anaconda3/envs/conda/bin/python"
Set-Alias python-ai "~/miniforge3/envs/tensorflow/bin/python"
Set-Alias pip-ai "/Users/meher/miniforge3/bin/pip"
Set-Alias pip "/Users/meher/opt/anaconda3/bin/pip"

