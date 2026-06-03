<#
.SYNOPSIS
    REMEDIATE - Zabbix Agent / Agent 2
.DESCRIPTION
    Acionado quando o CHECK do Zabbix falha (Task "On Check Failure").
    Comportamento:
      - Servico existe mas Disabled  -> reabilita e inicia
      - Servico existe mas Stopped   -> inicia
      - Servico nao existe           -> instala via MSI silencioso

    ANTES DE USAR: ajuste as variaveis da secao CONFIG abaixo.
.NOTES
    Tipo no TRMM  : PowerShell
    Trigger       : On Check Failure (check CHECK_ZabbixAgent)
    Timeout       : 300
#>

$ErrorActionPreference = 'Stop'

# =============================================================
# CONFIG - ajuste para o seu ambiente
# =============================================================
$ZabbixServer       = '192.168.1.10'          # IP ou FQDN do servidor Zabbix
$ZabbixServerActive = '192.168.1.10'          # Normalmente igual ao Server
$ZabbixVersion      = '7.4.11'                # Versao desejada
$ZabbixArch         = 'amd64'                 # amd64 ou i386
$ZabbixMsiUrl       = "https://cdn.zabbix.com/zabbix/binaries/stable/7.4/$ZabbixVersion/zabbix_agent2-$ZabbixVersion-windows-$ZabbixArch-openssl.msi"
# Alternativa recomendada: aponte para share interno
# $ZabbixMsiUrl = '\\fileserver\rmm-repo\zabbix_agent2.msi'
# =============================================================

function Get-ZabbixService {
    Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('Zabbix Agent', 'Zabbix Agent 2') -or
                       $_.DisplayName -in @('Zabbix Agent', 'Zabbix Agent 2') } |
        Sort-Object -Property @{Expression = { if ($_.Name -eq 'Zabbix Agent 2') { 0 } else { 1 } }} |
        Select-Object -First 1
}

$svc = Get-ZabbixService

if ($svc) {
    Write-Output "Servico encontrado: '$($svc.DisplayName)' | State: $($svc.State) | StartMode: $($svc.StartMode)"

    if ($svc.StartMode -eq 'Disabled') {
        Write-Output "Reabilitando servico (Disabled -> Automatic)..."
        Set-Service -Name $svc.Name -StartupType Automatic
    }

    if ($svc.State -ne 'Running') {
        Write-Output "Iniciando servico..."
        Start-Service -Name $svc.Name
        Start-Sleep -Seconds 5
    }

    $svcFinal = Get-ZabbixService
    if ($svcFinal.State -eq 'Running') {
        Write-Output "OK: Servico '$($svcFinal.DisplayName)' em execucao."
        $host.SetShouldExit(0)
        exit 0
    } else {
        Write-Output "FAIL: Servico ainda nao esta Running apos tentativa de start."
        $host.SetShouldExit(1)
        exit 1
    }
}

# Servico nao existe - instalar
Write-Output "Servico nao encontrado. Iniciando instalacao do Zabbix Agent 2..."

$msiPath = "$env:TEMP\zabbix_agent2_rmm.msi"

if ($ZabbixMsiUrl -like 'http*') {
    Write-Output "Baixando MSI de: $ZabbixMsiUrl"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ZabbixMsiUrl -OutFile $msiPath -UseBasicParsing
} else {
    Write-Output "Copiando MSI de: $ZabbixMsiUrl"
    Copy-Item -Path $ZabbixMsiUrl -Destination $msiPath -Force
}

if (-not (Test-Path $msiPath)) {
    Write-Output "FAIL: MSI nao encontrado em $msiPath apos download/copia."
    $host.SetShouldExit(1)
    exit 1
}

Write-Output "Instalando Zabbix Agent 2 silenciosamente..."
$msiArgs = @(
    '/i', "`"$msiPath`"",
    '/qn',
    '/l*v', "`"$env:TEMP\zabbix_install.log`"",
    "SERVER=$ZabbixServer",
    "SERVERACTIVE=$ZabbixServerActive",
    "HOSTNAME=$env:COMPUTERNAME"
)

$proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
Write-Output "MSI ExitCode: $($proc.ExitCode)"

if ($proc.ExitCode -notin @(0, 3010)) {
    Write-Output "FAIL: msiexec retornou codigo $($proc.ExitCode). Veja $env:TEMP\zabbix_install.log"
    $host.SetShouldExit(1)
    exit 1
}

Start-Sleep -Seconds 8

$svcFinal = Get-ZabbixService
if ($svcFinal -and $svcFinal.State -eq 'Running') {
    Write-Output "OK: Zabbix Agent instalado e em execucao."
    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    $host.SetShouldExit(0)
    exit 0
} else {
    Write-Output "FAIL: Instalacao concluida mas servico nao esta Running."
    Write-Output "Estado: $($svcFinal.State)"
    $host.SetShouldExit(1)
    exit 1
}
