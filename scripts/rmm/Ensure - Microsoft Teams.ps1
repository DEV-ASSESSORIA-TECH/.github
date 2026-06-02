$ErrorActionPreference = "Stop"

$TempDir = "C:\ProgramData\TacticalRMM\Installers"
$Bootstrapper = Join-Path $TempDir "teamsbootstrapper.exe"
$BootstrapperUrl = "https://go.microsoft.com/fwlink/?linkid=2243204"

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

function Test-NewTeamsInstalled {
    $provisioned = Get-AppxProvisionedPackage -Online | Where-Object {
        $_.DisplayName -eq "MSTeams"
    }

    $installedForUsers = Get-AppxPackage -AllUsers | Where-Object {
        $_.Name -eq "MSTeams"
    }

    if ($provisioned -or $installedForUsers) {
        return $true
    }

    return $false
}

if (Test-NewTeamsInstalled) {
    Write-Output "Microsoft Teams ja esta instalado/provisionado."
    exit 0
}

Write-Output "Microsoft Teams nao encontrado. Baixando bootstrapper..."

Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $Bootstrapper -UseBasicParsing

Write-Output "Instalando Microsoft Teams machine-wide..."
$process = Start-Process -FilePath $Bootstrapper -ArgumentList "-p" -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Output "Microsoft Teams instalado/provisionado com sucesso."
    exit 0
}

Write-Output "Falha ao instalar Teams. ExitCode: $($process.ExitCode)"
exit 1