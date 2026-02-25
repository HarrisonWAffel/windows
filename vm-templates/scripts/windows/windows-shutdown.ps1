# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
    .DESCRIPTION
    Runs sysprep to generalize the Windows installation.
    This script is designed to work with both VirtualBox and QEMU/KVM Packer builds.
#>

$ErrorActionPreference = "Continue"

Write-Host "=========================================="
Write-Host "Starting Windows Sysprep and Shutdown"
Write-Host "=========================================="

# Path to the sysprep unattend file (copied by Packer file provisioner)
$unattendPath = "C:\autounattend.xml"

# Check if unattend file exists
if (Test-Path $unattendPath) {
    Write-Host "Found unattend file at: $unattendPath"
} else {
    Write-Host "WARNING: Unattend file not found at $unattendPath"
    Write-Host "Proceeding with sysprep without unattend file..."
    $unattendPath = $null
}

# Stop Windows Update service to prevent interference
Write-Host "Stopping Windows Update service..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue

# Clear Windows Update cache to reduce image size
Write-Host "Clearing Windows Update cache..."
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear temp files
Write-Host "Clearing temporary files..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Build sysprep arguments
$sysprepPath = "C:\\Windows\\system32\\Sysprep\\sysprep.exe"

if ($null -ne $unattendPath -and (Test-Path $unattendPath)) {
    $sysprepArgs = "/generalize", "/oobe", "/shutdown", "/mode:vm", "/unattend:$unattendPath"
} else {
    $sysprepArgs = "/generalize", "/oobe", "/shutdown", "/mode:vm"
}

Write-Host "Executing: $sysprepPath $($sysprepArgs -join ' ')"
Write-Host ""
Write-Host "Sysprep will quit when complete. Packer's shutdown_command will handle VM shutdown."
Write-Host "=========================================="

# Start sysprep without -Wait so we can monitor logs while it runs
$sysprepProcess = Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -PassThru

Write-Host "Sysprep started (PID: $($sysprepProcess.Id)). Monitoring logs..."

# Sysprep log paths
$actLogPath = "C:\Windows\System32\Sysprep\Panther\setupact.log"
$errLogPath = "C:\Windows\System32\Sysprep\Panther\setuperr.log"

$actLogLastPos = 0
$errLogLastPos = 0

# Periodically print new lines from sysprep act and err logs
while (-not $sysprepProcess.HasExited) {
    # Print new lines from the action log
    if (Test-Path $actLogPath) {
        $actContent = Get-Content -Path $actLogPath -Raw -ErrorAction SilentlyContinue
        if ($null -ne $actContent -and $actContent.Length -gt $actLogLastPos) {
            $newContent = $actContent.Substring($actLogLastPos)
            foreach ($line in ($newContent -split "`r?`n" | Where-Object { $_ -ne "" })) {
                Write-Host "[SYSPREP-ACT] $line"
            }
            $actLogLastPos = $actContent.Length
        }
    }

    # Print new lines from the error log
    if (Test-Path $errLogPath) {
        $errContent = Get-Content -Path $errLogPath -Raw -ErrorAction SilentlyContinue
        if ($null -ne $errContent -and $errContent.Length -gt $errLogLastPos) {
            $newContent = $errContent.Substring($errLogLastPos)
            foreach ($line in ($newContent -split "`r?`n" | Where-Object { $_ -ne "" })) {
                Write-Host "[SYSPREP-ERR] $line"
            }
            $errLogLastPos = $errContent.Length
        }
    }

    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Sysprep process exited with code: $($sysprepProcess.ExitCode)"
Write-Host "=========================================="

# Print any remaining log content after exit
if (Test-Path $actLogPath) {
    $actContent = Get-Content -Path $actLogPath -Raw -ErrorAction SilentlyContinue
    if ($null -ne $actContent -and $actContent.Length -gt $actLogLastPos) {
        foreach ($line in ($actContent.Substring($actLogLastPos) -split "`r?`n" | Where-Object { $_ -ne "" })) {
            Write-Host "[SYSPREP-ACT] $line"
        }
    }
}
if (Test-Path $errLogPath) {
    $errContent = Get-Content -Path $errLogPath -Raw -ErrorAction SilentlyContinue
    if ($null -ne $errContent -and $errContent.Length -gt $errLogLastPos) {
        foreach ($line in ($errContent.Substring($errLogLastPos) -split "`r?`n" | Where-Object { $_ -ne "" })) {
            Write-Host "[SYSPREP-ERR] $line"
        }
    }
}


