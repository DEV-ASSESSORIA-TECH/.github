<#
.SYNOPSIS
    CHECK - OneDrive Sync
.DESCRIPTION
    Verifica se o OneDrive esta instalado, nao bloqueado por politica e
    em execucao em pelo menos uma sessao de usuario.
    Usa Win32_Process (CIM global) para enxergar processos de usuario
    a partir do contexto SYSTEM do agente TRMM.
    Retorna exit 0 se OK, exit 1 se falhou.
.NOTES
    Tipo no TRMM  : PowerShell
    Run Check Every: 60
    Timeout       : 30
#>

$ErrorActionPreference = 'SilentlyContinue'

# --- VERIFICAR POLITICA BLOQUEADORA ---
$policyKey  = 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive'
$policyProp = Get-ItemProperty -Path $policyKey -ErrorAction SilentlyContinue
if ($policyProp.DisableFileSyncNGSC -eq 1) {
    Write-Output "FAIL: OneDrive bloqueado por politica (DisableFileSyncNGSC=1)."
    $host.SetShouldExit(1)
    exit 1
}

# --- VERIFICAR INSTALACAO (per-machine e per-user) ---
$perMachinePaths = @(
    "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
    "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
)
$installedPath = $perMachinePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $installedPath) {
    # Buscar em perfis de usuario carregados
    $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPath -like 'C:\Users\*' -and $_.Special -eq $false }

    foreach ($profile in $profiles) {
        $candidate = Join-Path $profile.LocalPath 'AppData\Local\Microsoft\OneDrive\OneDrive.exe'
        if (Test-Path $candidate) {
            $installedPath = $candidate
            break
        }
    }
}

if (-not $installedPath) {
    Write-Output "FAIL: OneDrive.exe nao encontrado em nenhum caminho conhecido."
    $host.SetShouldExit(1)
    exit 1
}

Write-Output "Instalado em: $installedPath"

# --- VERIFICAR PROCESSO EM EXECUCAO (CIM - visivel do contexto SYSTEM) ---
$procs = Get-CimInstance -ClassName Win32_Process -Filter "Name='OneDrive.exe'" -ErrorAction SilentlyContinue
$procCount = ($procs | Measure-Object).Count

if ($procCount -eq 0) {
    Write-Output "FAIL: OneDrive.exe instalado mas nenhuma instancia em execucao encontrada."
    $host.SetShouldExit(1)
    exit 1
}

Write-Output "OK: OneDrive em execucao ($procCount instancia(s))."
Write-Output "Instalacao: $installedPath"
$host.SetShouldExit(0)
exit 0
