# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
    .DESCRIPTION
    Runs sysprep to generalize the Windows installation and then shuts down the VM.
    This script is designed to work with both VirtualBox and QEMU/KVM Packer builds.

    Note: Sysprep will shutdown the system, so this script starts sysprep and exits
    immediately. Packer's shutdown_command serves as a fallback.
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
$sysprepPath = "$env:SystemRoot\System32\Sysprep\sysprep.exe"

if ($null -ne $unattendPath -and (Test-Path $unattendPath)) {
    $sysprepArgs = "/generalize", "/oobe", "/shutdown", "/mode:vm", "/unattend:$unattendPath"
} else {
    $sysprepArgs = "/generalize", "/oobe", "/shutdown", "/mode:vm"
}

Write-Host "Executing: $sysprepPath $($sysprepArgs -join ' ')"
Write-Host ""
Write-Host "Sysprep will shutdown the system when complete."
Write-Host "=========================================="

# Start sysprep WITHOUT waiting - it will shutdown the system itself
# Using Start-Process without -Wait so the script can return to Packer
# Sysprep's /shutdown flag will handle the actual shutdown
Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -NoNewWindow

# Give sysprep a moment to start before script exits
Start-Sleep -Seconds 5

Write-Host "Sysprep started. System will shutdown shortly..."

# Exit cleanly - sysprep will handle the shutdown
exit 0


