<#
.SYNOPSIS
    CHECK - TeamViewer Host
.DESCRIPTION
    Verifica se o servico TeamViewer esta instalado, habilitado e Running.
    Tambem confirma presenca no registro ARP (chaves de desinstalacao).
    Retorna exit 0 se OK, exit 1 se qualquer condicao falhar.
.NOTES
    Tipo no TRMM  : PowerShell
    Run Check Every: 60
    Timeout       : 30
#>

$ErrorActionPreference = 'SilentlyContinue'

# --- VERIFICAR SERVICO ---
$svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='TeamViewer'" |
    Select-Object -First 1

if (-not $svc) {
    # Tentar tambem pelo DisplayName caso o Name tenha variado
    $svc = Get-CimInstance -ClassName Win32_Service |
        Where-Object { $_.DisplayName -like 'TeamViewer*' } |
        Select-Object -First 1
}

if (-not $svc) {
    Write-Output "FAIL: Servico TeamViewer nao encontrado."
    $host.SetShouldExit(1)
    exit 1
}

if ($svc.StartMode -eq 'Disabled') {
    Write-Output "FAIL: Servico '$($svc.DisplayName)' esta DISABLED."
    $host.SetShouldExit(1)
    exit 1
}

if ($svc.State -ne 'Running') {
    Write-Output "FAIL: Servico '$($svc.DisplayName)' esta $($svc.State)."
    $host.SetShouldExit(1)
    exit 1
}

# --- VERIFICAR REGISTRO ARP (confirmacao adicional de instalacao) ---
$arpRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$arpHit = foreach ($root in $arpRoots) {
    Get-ItemProperty $root -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'TeamViewer*' }
}
$arpEntry = $arpHit | Select-Object -First 1

# --- OK ---
Write-Output "OK: $($svc.DisplayName) | State: $($svc.State) | StartMode: $($svc.StartMode)"
if ($arpEntry) {
    Write-Output "ARP: $($arpEntry.DisplayName) v$($arpEntry.DisplayVersion)"
}
$host.SetShouldExit(0)
exit 0
