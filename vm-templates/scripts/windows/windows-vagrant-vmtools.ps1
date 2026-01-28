# Install the VMWare Guest Additions when building vagrant boxes for virtualbox.
if ($env:PROVIDER -ne "virtualbox") {
    Write-Host "Skipping VirtualBox Guest Additions installation: not running on VirtualBox."
    return
}
$result = mount-diskimage C:\Users\$env:BUILD_USERNAME\VBoxGuestAdditions.iso
Set-Location (($result | Get-Volume).DriveLetter + ":")
./VBoxWindowsAdditions-amd64.exe /S