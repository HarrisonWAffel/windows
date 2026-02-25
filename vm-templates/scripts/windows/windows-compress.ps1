# Remove outdated components from the Windows Side-by-Side (SxS) store to reduce disk space usage.
DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# 1. Disable hibernation to remove hiberfil.sys
powercfg.exe /h off

# 2. Stop Update service and clear the download cache
Stop-Service -Name wuauserv -Force
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# 3. Clear temporary files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# 4. Defragment to consolidate data at the front of the disk
Optimize-Volume -DriveLetter C -Defrag

# 5. Zero out free space natively
$drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$file = [System.IO.File]::Create("C:\zero.tmp")
$file.SetLength($drive.FreeSpace - 50MB) # Leaves a tiny buffer to prevent crashes
$file.Close()
Remove-Item "C:\zero.tmp" -Force