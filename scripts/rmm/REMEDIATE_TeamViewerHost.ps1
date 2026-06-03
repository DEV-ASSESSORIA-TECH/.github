<#
.SYNOPSIS
    REMEDIATE - TeamViewer Host
.DESCRIPTION
    Acionado quando o CHECK do TeamViewer Host falha.
    Comportamento:
      - Servico Disabled -> reabilita e inicia
      - Servico Stopped  -> inicia
      - Nao instalado    -> instala MSI corporativo silenciosamente

    IMPORTANTE: O MSI do TeamViewer Host deve ser o MSI personalizado
    gerado pela sua conta/licenca TeamViewer (com CUSTOMCONFIGID embutido),
    ou voce deve fornecer CUSTOMCONFIGID e ASSIGNMENTID abaixo.
    NAO use o MSI generico publico sem configurar o assignment.
.NOTES
    Tipo no TRMM  : PowerShell
    Trigger       : On Check Failure (check CHECK_TeamViewerHost)
    Timeout       : 300
#>

$ErrorActionPreference = 'Stop'

# =============================================================
# CONFIG - ajuste para o seu ambiente
# =============================================================
# Opcao A: MSI pre-configurado em share interno (RECOMENDADO)
$TvMsiPath = '\\fileserver\rmm-repo\TeamViewer_Host.msi'
# Opcao B: MSI generico + parametros de assignment
# $TvMsiPath      = '\\fileserver\rmm-repo\TeamViewer_Host_generic.msi'
$TvCustomConfigId = 'SEU_CUSTOM_CONFIG_ID'   # do painel TeamViewer
$TvAssignmentId   = 'SEU_ASSIGNMENT_ID'       # do painel TeamViewer (opcional se pre-configurado)
# =============================================================

function Get-TVService {
    $s = Get-CimInstance -ClassName Win32_Service -Filter "Name='TeamViewer'" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $s) {
        $s = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'TeamViewer*' } |
            Select-Object -First 1
    }
    return $s
}

$svc = Get-TVService

if ($svc) {
    Write-Output "Servico encontrado: '$($svc.DisplayName)' | State: $($svc.State) | StartMode: $($svc.StartMode)"

    if ($svc.StartMode -eq 'Disabled') {
        Write-Output "Reabilitando (Disabled -> Automatic)..."
        Set-Service -Name $svc.Name -StartupType Automatic
    }

    if ($svc.State -ne 'Running') {
        Write-Output "Iniciando servico..."
        Start-Service -Name $svc.Name
        Start-Sleep -Seconds 8
    }

    $svcFinal = Get-TVService
    if ($svcFinal.State -eq 'Running') {
        Write-Output "OK: TeamViewer em execucao."
        $host.SetShouldExit(0)
        exit 0
    } else {
        Write-Output "FAIL: Servico ainda nao Running apos tentativa."
        $host.SetShouldExit(1)
        exit 1
    }
}

# Servico nao existe - instalar
Write-Output "Servico TeamViewer nao encontrado. Instalando..."

if (-not (Test-Path $TvMsiPath)) {
    Write-Output "FAIL: MSI nao encontrado em '$TvMsiPath'. Configure a variavel TvMsiPath."
    $host.SetShouldExit(1)
    exit 1
}

$msiArgs = @(
    '/i', "`"$TvMsiPath`"",
    '/qn',
    '/l*v', "`"$env:TEMP\teamviewer_install.log`""
)

# Adicionar parametros de assignment apenas se configurados
if ($TvCustomConfigId -ne 'SEU_CUSTOM_CONFIG_ID') {
    $msiArgs += "CUSTOMCONFIGID=$TvCustomConfigId"
}
if ($TvAssignmentId -ne 'SEU_ASSIGNMENT_ID') {
    $msiArgs += "ASSIGNMENTID=$TvAssignmentId"
}

Write-Output "Executando msiexec com args: $($msiArgs -join ' ')"
$proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
Write-Output "MSI ExitCode: $($proc.ExitCode)"

if ($proc.ExitCode -notin @(0, 3010)) {
    Write-Output "FAIL: msiexec retornou $($proc.ExitCode). Veja $env:TEMP\teamviewer_install.log"
    $host.SetShouldExit(1)
    exit 1
}

Start-Sleep -Seconds 10

$svcFinal = Get-TVService
if ($svcFinal -and $svcFinal.State -eq 'Running') {
    Write-Output "OK: TeamViewer Host instalado e em execucao."
    $host.SetShouldExit(0)
    exit 0
} else {
    Write-Output "FAIL: Instalacao concluida mas servico nao Running. Estado: $($svcFinal.State)"
    $host.SetShouldExit(1)
    exit 1
}
