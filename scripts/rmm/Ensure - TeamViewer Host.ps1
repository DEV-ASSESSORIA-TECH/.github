$ErrorActionPreference = "Stop"

$TempDir = "C:\ProgramData\TacticalRMM\Installers"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# AJUSTE ESTES VALORES
$InstallerUrl = "https://SEU-LINK-INTERNO-OU-OFICIAL/TeamViewer_Host.msi"
$InstallerPath = Join-Path $TempDir "TeamViewer_Host.msi"

# Se voce usa TeamViewer Tensor/Corporate, ajuste os parametros oficiais do seu deployment.
# Exemplo generico. Nao use sem revisar no portal do TeamViewer.
$MsiArgs = "/i `"$InstallerPath`" /qn /norestart"

function Get-TeamViewerService {
    $svc = Get-Service -Name "TeamViewer" -ErrorAction SilentlyContinue
    if ($svc) { return $svc }

    $svc = Get-Service -Name "TeamViewer*" -ErrorAction SilentlyContinue | Select-Object -First 1
    return $svc
}

$service = Get-TeamViewerService

if (-not $service) {
    Write-Output "TeamViewer nao encontrado. Baixando instalador..."

    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing

    Write-Output "Instalando TeamViewer Host..."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArgs -Wait -PassThru

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        Write-Output "Falha ao instalar TeamViewer. ExitCode: $($process.ExitCode)"
        exit 1
    }

    Start-Sleep -Seconds 10
    $service = Get-TeamViewerService

    if (-not $service) {
        Write-Output "Instalacao terminou, mas servico TeamViewer nao foi encontrado."
        exit 1
    }
}

Write-Output "TeamViewer encontrado. Garantindo servico automatico e iniciado..."

Set-Service -Name $service.Name -StartupType Automatic

if ($service.Status -ne "Running") {
    Start-Service -Name $service.Name
}

Start-Sleep -Seconds 3
$service = Get-Service -Name $service.Name

if ($service.Status -eq "Running") {
    Write-Output "OK - TeamViewer ativo. Servico: $($service.Name)"
    exit 0
}

Write-Output "CRITICAL - TeamViewer instalado, mas servico nao iniciou. Status: $($service.Status)"
exit 2