<#
.SYNOPSIS
    REMEDIATE - Microsoft Teams (novo / New Teams)
.DESCRIPTION
    Acionado quando o CHECK do Teams falha.
    Comportamento:
      - Pacote ausente  -> provisiona com teamsbootstrapper.exe
      - Pacote presente mas processo parado -> tenta religar o executavel

    IMPORTANTE: Teams novo NAO tem servico Windows. Nao existe Start-Service.
    O bootstrapper deve estar em staging local antes do deploy.
    O processo so aparece quando o usuario inicia o Teams; relancamento
    via SYSTEM pode nao criar janela no desktop do usuario.

    Para religar no contexto do usuario, o correto e usar RunAsUser
    (funcionalidade do TRMM) ou confiar no autostart do Teams apos logon.
.NOTES
    Tipo no TRMM  : PowerShell
    Trigger       : On Check Failure (check CHECK_TeamsNew)
    Timeout       : 300
#>

$ErrorActionPreference = 'Stop'

# =============================================================
# CONFIG
# =============================================================
# Caminho do bootstrapper oficial da Microsoft em staging local
# Baixe de: https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409
$BootstrapperPath = 'C:\RMMCache\teamsbootstrapper.exe'
# =============================================================

function Get-TeamsPkg {
    Get-AppxPackage -AllUsers -Name '*MSTeams*' -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
}

$pkg = Get-TeamsPkg

if (-not $pkg) {
    # Pacote ausente - provisionar
    Write-Output "Pacote MSTeams nao encontrado. Provisionando com bootstrapper..."

    if (-not (Test-Path $BootstrapperPath)) {
        Write-Output "FAIL: teamsbootstrapper.exe nao encontrado em '$BootstrapperPath'."
        Write-Output "Faca o staging do bootstrapper oficial da Microsoft nesse caminho antes do deploy."
        $host.SetShouldExit(1)
        exit 1
    }

    Write-Output "Executando: $BootstrapperPath -p"
    $proc = Start-Process -FilePath $BootstrapperPath -ArgumentList '-p' -Wait -PassThru
    Write-Output "Bootstrapper ExitCode: $($proc.ExitCode)"

    if ($proc.ExitCode -ne 0) {
        Write-Output "WARN: Bootstrapper retornou $($proc.ExitCode). Verificando pacote..."
    }

    Start-Sleep -Seconds 10
    $pkg = Get-TeamsPkg

    if (-not $pkg) {
        Write-Output "FAIL: Pacote MSTeams ainda nao encontrado apos provisionamento."
        $host.SetShouldExit(1)
        exit 1
    }

    Write-Output "OK: Teams provisionado - $($pkg.PackageFullName)"
    Write-Output "O processo ms-teams.exe sera iniciado pelo usuario no proximo logon ou abertura manual."
    $host.SetShouldExit(0)
    exit 0
}

# Pacote existe mas processo parado
Write-Output "Pacote encontrado: $($pkg.PackageFullName)"
Write-Output "Tentando religar ms-teams.exe..."

$teamsExe = Join-Path $pkg.InstallLocation 'ms-teams.exe'

if (-not (Test-Path $teamsExe)) {
    Write-Output "WARN: ms-teams.exe nao encontrado em $($pkg.InstallLocation). Reprovisionando..."
    if (Test-Path $BootstrapperPath) {
        Start-Process -FilePath $BootstrapperPath -ArgumentList '-p' -Wait
        Write-Output "Reprovisionamento concluido. Teams iniciara no proximo logon do usuario."
    }
    $host.SetShouldExit(0)
    exit 0
}

# Tentar iniciar (visivel apenas se houver sessao de usuario ativa)
Start-Process -FilePath $teamsExe -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

$procsAfter = Get-CimInstance -ClassName Win32_Process -Filter "Name='ms-teams.exe'" -ErrorAction SilentlyContinue
$countAfter = ($procsAfter | Measure-Object).Count

if ($countAfter -gt 0) {
    Write-Output "OK: ms-teams.exe em execucao ($countAfter instancia(s))."
    $host.SetShouldExit(0)
    exit 0
} else {
    Write-Output "WARN: Relancar executado mas processo nao visivel via SYSTEM."
    Write-Output "Isso e esperado quando nenhum usuario esta logado interativamente."
    Write-Output "O Teams iniciara automaticamente no proximo logon do usuario."
    # Retornar 0 porque a acao foi tomada; check detectara no proximo ciclo com usuario logado
    $host.SetShouldExit(0)
    exit 0
}
