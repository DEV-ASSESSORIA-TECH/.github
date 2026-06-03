<#
.SYNOPSIS
    CHECK - TeamViewer Monitoring (1E Client / Advanced Monitoring)
.DESCRIPTION
    Verifica se o servico '1E Client' esta instalado e em execucao.
    O TeamViewer Advanced Monitoring instala automaticamente o 1E Client
    em endpoints Windows x64 com TeamViewer Host/Full Client x64.
    Se o 1E Client sumir, a remediacao correta e reinstalar o TeamViewer Host
    com o mesmo CUSTOMCONFIGID (o add-on e re-provisionado automaticamente).
    Retorna exit 0 se OK, exit 1 se falhar.
.NOTES
    Tipo no TRMM  : PowerShell
    Run Check Every: 60
    Timeout       : 30
#>

$ErrorActionPreference = 'SilentlyContinue'

$svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='1E Client'" |
    Select-Object -First 1

if (-not $svc) {
    # Fallback: buscar por DisplayName
    $svc = Get-CimInstance -ClassName Win32_Service |
        Where-Object { $_.DisplayName -like '1E Client*' } |
        Select-Object -First 1
}

if (-not $svc) {
    Write-Output "FAIL: Servico '1E Client' nao encontrado. TeamViewer Monitoring pode nao estar provisionado."
    $host.SetShouldExit(1)
    exit 1
}

if ($svc.StartMode -eq 'Disabled') {
    Write-Output "FAIL: 1E Client esta DISABLED."
    Write-Output "State: $($svc.State) | StartMode: $($svc.StartMode)"
    $host.SetShouldExit(1)
    exit 1
}

if ($svc.State -ne 'Running') {
    Write-Output "FAIL: 1E Client esta $($svc.State) (esperado: Running)."
    $host.SetShouldExit(1)
    exit 1
}

# Verificar diretorio de instalacao via registro
$installDir = (Get-ItemProperty 'HKLM:\SOFTWARE\1E\Client' -ErrorAction SilentlyContinue).InstallationDirectory
$confPath   = if ($installDir) { Join-Path $installDir '1E.Client.conf' } else { $null }
$confExists = $confPath -and (Test-Path $confPath)

Write-Output "OK: 1E Client | State: $($svc.State) | StartMode: $($svc.StartMode)"
if ($installDir) { Write-Output "InstallDir: $installDir" }
if ($confExists) { Write-Output "Config encontrado: $confPath" }

$host.SetShouldExit(0)
exit 0
