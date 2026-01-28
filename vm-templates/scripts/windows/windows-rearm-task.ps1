<#
    Creates a scheduled task that runs on first boot, rearms Windows Server evaluation (extends by 180 days),
    and removes itself after execution. Can be rearmed up to 6 times (3.5 years total).
#>

$ErrorActionPreference = "Stop"

Write-Output "Setting up Windows evaluation rearm task..."

$taskName = "Windows-Rearm-Evaluation"
$taskPath = "\Microsoft\Windows\Setup\"
$scriptDir = "C:\Windows\Setup\Scripts"
$rearmScriptPath = "$scriptDir\rearm-windows.ps1"

New-Item -ItemType Directory -Force -Path $scriptDir -ErrorAction SilentlyContinue | Out-Null

@'
$ErrorActionPreference = "Continue"
Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Starting Windows evaluation rearm on $env:COMPUTERNAME"
try {
    cscript //nologo C:\Windows\System32\slmgr.vbs /rearm
    if ($LASTEXITCODE -eq 0) { Write-Output "SUCCESS: Evaluation period rearmed to 180 days" }
    else { Write-Output "ERROR: Rearm failed with exit code $LASTEXITCODE" }
} catch { Write-Output "ERROR: $_" }
Unregister-ScheduledTask -TaskName "Windows-Rearm-Evaluation" -TaskPath "\Microsoft\Windows\Setup\" -Confirm:$false -ErrorAction SilentlyContinue
Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Rearm complete. Restart recommended."
'@ | Out-File -FilePath $rearmScriptPath -Encoding UTF8 -Force

# Remove existing task if present
Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

# Register scheduled task
Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath `
    -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$rearmScriptPath`"") `
    -Trigger (New-ScheduledTaskTrigger -AtStartup) `
    -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest) `
    -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)) `
    -Description "Rearms Windows Server evaluation on first boot. Auto-deletes after execution." -Force | Out-Null

