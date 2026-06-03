<#
.SYNOPSIS
    CHECK - Zabbix Agent / Agent 2
.DESCRIPTION
    Verifica se o servico do Zabbix Agent (ou Agent 2) esta instalado,
    habilitado e em execucao. Retorna exit 0 se OK, exit 1 se falhou.
    Projetado para rodar como SYSTEM no Tactical RMM (Script Check).
.NOTES
    Tipo no TRMM  : PowerShell
    Run Check Every: 60 (segundos)
    Timeout       : 30
#>

$ErrorActionPreference = 'SilentlyContinue'

$serviceNames = @('Zabbix Agent', 'Zabbix Agent 2')

$svc = Get-CimInstance -ClassName Win32_Service |
    Where-Object { $_.Name -in $serviceNames -or $_.DisplayName -in $serviceNames } |
    Sort-Object -Property @{Expression = { if ($_.Name -eq 'Zabbix Agent 2') { 0 } else { 1 } }} |
    Select-Object -First 1

# --- NAO INSTALADO ---
if (-not $svc) {
    Write-Output "FAIL: Zabbix Agent nao encontrado (nenhum servico instalado)."
    $host.SetShouldExit(1)
    exit 1
}

# --- DESABILITADO ---
if ($svc.StartMode -eq 'Disabled') {
    Write-Output "FAIL: Servico '$($svc.DisplayName)' existe mas esta DISABLED."
    Write-Output "StartMode: $($svc.StartMode) | State: $($svc.State)"
    $host.SetShouldExit(1)
    exit 1
}

# --- PARADO ---
if ($svc.State -ne 'Running') {
    Write-Output "FAIL: Servico '$($svc.DisplayName)' esta $($svc.State) (nao Running)."
    Write-Output "StartMode: $($svc.StartMode) | PathName: $($svc.PathName)"
    $host.SetShouldExit(1)
    exit 1
}

# --- OK ---
Write-Output "OK: $($svc.DisplayName) - State: $($svc.State) | StartMode: $($svc.StartMode)"
Write-Output "PathName: $($svc.PathName)"
$host.SetShouldExit(0)
exit 0
