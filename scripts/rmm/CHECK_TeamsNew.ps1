<#
.SYNOPSIS
    CHECK - Microsoft Teams (novo / New Teams)
.DESCRIPTION
    Verifica se o pacote MSIX 'MSTeams' esta provisionado para todos os usuarios
    e se o processo ms-teams.exe esta em execucao em alguma sessao.
    Teams novo NAO tem servico Windows. A deteccao correta e pelo pacote AppX
    e pelo processo via Win32_Process (visivel do contexto SYSTEM).
    Retorna exit 0 se OK, exit 1 se falhar.
.NOTES
    Tipo no TRMM  : PowerShell
    Run Check Every: 60
    Timeout       : 30
#>

$ErrorActionPreference = 'SilentlyContinue'

# --- VERIFICAR PACOTE APPX/MSIX ---
$pkg = Get-AppxPackage -AllUsers -Name '*MSTeams*' -ErrorAction SilentlyContinue |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1

if (-not $pkg) {
    Write-Output "FAIL: Pacote MSTeams nao encontrado (Get-AppxPackage -AllUsers *MSTeams* retornou vazio)."
    $host.SetShouldExit(1)
    exit 1
}

Write-Output "Pacote: $($pkg.PackageFullName)"
Write-Output "Versao: $($pkg.Version)"
Write-Output "InstallLocation: $($pkg.InstallLocation)"

# --- VERIFICAR PROCESSO EM EXECUCAO ---
$procs = Get-CimInstance -ClassName Win32_Process -Filter "Name='ms-teams.exe'" -ErrorAction SilentlyContinue
$procCount = ($procs | Measure-Object).Count

if ($procCount -eq 0) {
    Write-Output "FAIL: ms-teams.exe nao esta em execucao em nenhuma sessao."
    Write-Output "O pacote esta instalado mas Teams nao foi iniciado pelo usuario."
    $host.SetShouldExit(1)
    exit 1
}

Write-Output "OK: ms-teams.exe em execucao ($procCount instancia(s))."
$host.SetShouldExit(0)
exit 0
