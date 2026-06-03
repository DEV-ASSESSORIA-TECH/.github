<#
.SYNOPSIS
    REMEDIATE - OneDrive Sync
.DESCRIPTION
    Acionado quando o CHECK do OneDrive falha.
    Comportamento:
      - Politica bloqueadora -> remove a restricao de politica
      - Instalado mas parado -> reset e relanca o processo
      - Nao instalado        -> baixa e instala OneDriveSetup.exe

    ATENCAO: OneDrive roda no contexto do usuario, nao como servico SYSTEM.
    Este script remove bloqueios de politica e reinicia o executavel,
    mas o processo so aparecera efetivamente na sessao do usuario logado.
    Se nenhum usuario estiver logado, o check voltara a falhar ate o proximo logon.
.NOTES
    Tipo no TRMM  : PowerShell
    Trigger       : On Check Failure (check CHECK_OneDrive)
    Timeout       : 300
#>

$ErrorActionPreference = 'Stop'

# =============================================================
# CONFIG
# =============================================================
$OneDriveSetupUrl = 'https://go.microsoft.com/fwlink/p/?LinkID=2119709'
$InstallAllUsers  = $true   # $true = per-machine; $false = per-user
# =============================================================

function Find-OneDriveExe {
    $paths = @(
        "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )
    $found = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) { return $found }

    $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPath -like 'C:\Users\*' -and $_.Special -eq $false }
    foreach ($p in $profiles) {
        $c = Join-Path $p.LocalPath 'AppData\Local\Microsoft\OneDrive\OneDrive.exe'
        if (Test-Path $c) { return $c }
    }
    return $null
}

# --- PASSO 1: Remover politica bloqueadora ---
$policyKey = 'HKLM:\Software\Policies\Microsoft\Windows\OneDrive'
if (Test-Path $policyKey) {
    $policyProp = Get-ItemProperty -Path $policyKey -ErrorAction SilentlyContinue
    if ($policyProp.DisableFileSyncNGSC -eq 1) {
        Write-Output "Removendo politica DisableFileSyncNGSC..."
        Remove-ItemProperty -Path $policyKey -Name 'DisableFileSyncNGSC' -ErrorAction SilentlyContinue
        Write-Output "Politica removida."
    }
}

# --- PASSO 2: Instalar se ausente ---
$odExe = Find-OneDriveExe

if (-not $odExe) {
    Write-Output "OneDrive nao encontrado. Instalando..."
    $setupPath = "$env:TEMP\OneDriveSetup_rmm.exe"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $OneDriveSetupUrl -OutFile $setupPath -UseBasicParsing

    if (-not (Test-Path $setupPath)) {
        Write-Output "FAIL: Download do OneDriveSetup.exe falhou."
        $host.SetShouldExit(1)
        exit 1
    }

    $installArg = if ($InstallAllUsers) { '/allusers' } else { '/silent' }
    Write-Output "Instalando com argumento: $installArg"
    $proc = Start-Process -FilePath $setupPath -ArgumentList $installArg -Wait -PassThru
    Write-Output "Setup ExitCode: $($proc.ExitCode)"
    Start-Sleep -Seconds 10
    Remove-Item $setupPath -Force -ErrorAction SilentlyContinue

    $odExe = Find-OneDriveExe
    if (-not $odExe) {
        Write-Output "FAIL: OneDrive ainda nao encontrado apos instalacao."
        $host.SetShouldExit(1)
        exit 1
    }
    Write-Output "OneDrive instalado em: $odExe"
}

# --- PASSO 3: Reset e relancamento ---
# Parar instancias existentes
$existingProcs = Get-CimInstance -ClassName Win32_Process -Filter "Name='OneDrive.exe'" -ErrorAction SilentlyContinue
if ($existingProcs) {
    Write-Output "Encerrando $( ($existingProcs | Measure-Object).Count ) instancia(s) existentes..."
    $existingProcs | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
}

Write-Output "Executando reset do OneDrive: $odExe /reset"
Start-Process -FilePath $odExe -ArgumentList '/reset' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

Write-Output "Relancando OneDrive..."
Start-Process -FilePath $odExe -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

$procsAfter = Get-CimInstance -ClassName Win32_Process -Filter "Name='OneDrive.exe'" -ErrorAction SilentlyContinue
$countAfter = ($procsAfter | Measure-Object).Count

if ($countAfter -gt 0) {
    Write-Output "OK: OneDrive relancado ($countAfter instancia(s) em execucao)."
    $host.SetShouldExit(0)
    exit 0
} else {
    Write-Output "WARN: Reset e relancar executados, mas nenhum processo OneDrive visivel agora."
    Write-Output "Isso e esperado se nenhum usuario estiver logado. O processo iniciara no proximo logon."
    # Retornar 0 porque a acao foi tomada corretamente; o check detectara na proxima rodada
    $host.SetShouldExit(0)
    exit 0
}
