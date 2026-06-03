<#
.SYNOPSIS
    REMEDIATE - TeamViewer Monitoring (1E Client)
.DESCRIPTION
    Acionado quando o CHECK do TVMonitoring falha.
    Comportamento por estado:
      - 1E Client Disabled/Stopped -> tenta reabilitar/iniciar
      - 1E Client nao instalado    -> reinstala o TeamViewer Host com o mesmo
                                      CUSTOMCONFIGID para reprovisionar o add-on

    NOTA CRITICA: Nao instale o 1E Client MSI diretamente fora do fluxo
    do TeamViewer. O correto e reinstalar o TeamViewer Host com o mesmo
    CUSTOMCONFIGID e o 1E sera re-provisionado automaticamente pelo console.
.NOTES
    Tipo no TRMM  : PowerShell
    Trigger       : On Check Failure (check CHECK_TVMonitoring)
    Timeout       : 300
#>

$ErrorActionPreference = 'Stop'

# =============================================================
# CONFIG
# =============================================================
$TvMsiPath        = '\\fileserver\rmm-repo\TeamViewer_Host.msi'
$TvCustomConfigId = 'SEU_CUSTOM_CONFIG_ID'
$TvAssignmentId   = 'SEU_ASSIGNMENT_ID'
# =============================================================

function Get-1EService {
    $s = Get-CimInstance -ClassName Win32_Service -Filter "Name='1E Client'" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $s) {
        $s = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '1E Client*' } |
            Select-Object -First 1
    }
    return $s
}

$svc = Get-1EService

if ($svc) {
    Write-Output "1E Client encontrado | State: $($svc.State) | StartMode: $($svc.StartMode)"

    if ($svc.StartMode -eq 'Disabled') {
        Write-Output "Reabilitando 1E Client..."
        Set-Service -Name $svc.Name -StartupType Automatic
    }

    if ($svc.State -ne 'Running') {
        Write-Output "Iniciando 1E Client..."
        Start-Service -Name $svc.Name
        Start-Sleep -Seconds 8
    }

    $svcFinal = Get-1EService
    if ($svcFinal.State -eq 'Running') {
        Write-Output "OK: 1E Client em execucao."
        $host.SetShouldExit(0)
        exit 0
    } else {
        Write-Output "WARN: Servico nao ficou Running. Tentando reprovisionar via reinstalacao do TeamViewer Host..."
    }
}

# 1E nao existe ou nao iniciou - reprovisionar reinstalando o TeamViewer Host
Write-Output "Reprovisionando TeamViewer Monitoring via reinstalacao do Host..."

if (-not (Test-Path $TvMsiPath)) {
    Write-Output "FAIL: MSI nao encontrado em '$TvMsiPath'."
    $host.SetShouldExit(1)
    exit 1
}

$msiArgs = @(
    '/i', "`"$TvMsiPath`"",
    '/qn',
    '/l*v', "`"$env:TEMP\tv_reprovisioning.log`""
)
if ($TvCustomConfigId -ne 'SEU_CUSTOM_CONFIG_ID') {
    $msiArgs += "CUSTOMCONFIGID=$TvCustomConfigId"
}
if ($TvAssignmentId -ne 'SEU_ASSIGNMENT_ID') {
    $msiArgs += "ASSIGNMENTID=$TvAssignmentId"
}

$proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
Write-Output "MSI ExitCode: $($proc.ExitCode)"

if ($proc.ExitCode -notin @(0, 3010)) {
    Write-Output "FAIL: msiexec retornou $($proc.ExitCode)."
    $host.SetShouldExit(1)
    exit 1
}

Start-Sleep -Seconds 15

$svcFinal = Get-1EService
if ($svcFinal -and $svcFinal.State -eq 'Running') {
    Write-Output "OK: 1E Client em execucao apos reprovisionamento."
    $host.SetShouldExit(0)
    exit 0
} else {
    Write-Output "FAIL: 1E Client ainda nao Running apos reprovisionamento. O add-on pode precisar de alguns minutos para ser provisionado pelo console do TeamViewer."
    Write-Output "Estado atual: $($svcFinal.State)"
    $host.SetShouldExit(1)
    exit 1
}
