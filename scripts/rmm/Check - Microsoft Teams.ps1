$provisioned = Get-AppxProvisionedPackage -Online | Where-Object {
    $_.DisplayName -eq "MSTeams"
}

$installedForUsers = Get-AppxPackage -AllUsers | Where-Object {
    $_.Name -eq "MSTeams"
}

if ($provisioned -or $installedForUsers) {
    Write-Output "OK - Microsoft Teams instalado/provisionado."
    exit 0
}

Write-Output "CRITICAL - Microsoft Teams ausente."
exit 2