$svc = Get-Service -Name "TeamViewer" -ErrorAction SilentlyContinue

if (-not $svc) {
    $svc = Get-Service -Name "TeamViewer*" -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $svc) {
    Write-Output "CRITICAL - Servico TeamViewer nao encontrado."
    exit 2
}

if ($svc.StartType -eq "Disabled") {
    Write-Output "CRITICAL - Servico TeamViewer esta desativado."
    exit 2
}

if ($svc.Status -ne "Running") {
    Write-Output "CRITICAL - Servico TeamViewer nao esta rodando. Status: $($svc.Status)"
    exit 2
}

Write-Output "OK - TeamViewer ativo. Servico: $($svc.Name)"
exit 0