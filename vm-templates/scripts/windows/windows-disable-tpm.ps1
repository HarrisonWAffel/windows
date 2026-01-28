# windows 2025 enforces TPM checks during sysprep. These can fail in
# virtualized environments, so we disable them by adding registry keys.

$path = "HKLM:\SYSTEM\Setup\LabConfig"

If (!(Test-Path $path)) {
    New-Item -Path $path -Force | Out-Null
}

New-ItemProperty -Path $path -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $path -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $path -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $path -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $path -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force | Out-Null
