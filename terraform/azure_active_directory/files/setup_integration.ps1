$ProgressPreference = "SilentlyContinue"

while ($true) {
    try {
        $domain = Get-ADDomain
    }
    catch {
        Write-Output "Waiting for Active Directory domain to be set up..."
        Start-Sleep 3
        continue
    }
    break
}

$impersonationAccountUsername = "${impersonation_account_username}"
$impersonationAccountPassword = "${impersonation_account_password}"

$gmsas = Convertfrom-Json @"
${jsonencode(gmsas)}
"@

$activeDirectoryDir = "C:\etc\rancher-dev\active_directory"

# Create values.yaml
$activeDirectoryIntegrationsDir = "$activeDirectoryDir\values.json"
$values = [PSCustomObject]@{
    activeDirectory = @{
        domain = @{
            DNSRoot = $domain.DNSRoot
            Forest = $domain.Forest
            NetBIOSName = $domain.NetBIOSName
            ObjectGUID = $domain.ObjectGUID
            SID = $domain.DomainSID.Value
        }
        ccg = @{
            impersonationAccount = [PSCustomObject]@{
                username = $impersonationAccountUsername
                password = $impersonationAccountPassword
            }
        }
        gmsas = @($gmsas)
    }
}
$values | ConvertTo-Json -Compress -Depth 10 | Set-Content -Path $activeDirectoryIntegrationsDir | Out-Null
Write-Output "Wrote values.json to $activeDirectoryIntegrationsDir"

$activeDirectoryArchive = "$activeDirectoryDir.tar.gz"
tar -czvf $activeDirectoryArchive -C $activeDirectoryDir .

Write-Output "Generated archive $activeDirectoryArchive from $activeDirectoryDir"
