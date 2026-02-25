# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
    .DESCRIPTION
    Installs QEMU Guest Agent and VirtIO drivers for Vagrant/libvirt boxes.
    This script is run as a Packer provisioner when building QEMU-based images.

    Build strategy:
      - Windows is installed using IDE disk and e1000 network (natively supported
        by Windows PE, no driver chicken-and-egg problem).
      - This script then downloads the virtio-win ISO and installs all VirtIO
        drivers (viostor, NetKVM, balloon, etc.) into the Windows driver store
        via pnputil, plus the QEMU Guest Agent and VirtIO Guest Tools MSIs.
      - The resulting qcow2 image is controller-agnostic. When the Vagrant box
        runs with libvirt using VirtIO disk bus and VirtIO NIC, the pre-installed
        drivers are automatically loaded by Windows.
#>

$ErrorActionPreference = "Stop"

# Skip if not running on QEMU/libvirt
if ($env:PROVIDER -ne "qemu" -and $env:PROVIDER -ne "libvirt") {
    Write-Host "Skipping QEMU guest tools installation: not running on QEMU/libvirt."
    return
}

Write-Host "=========================================="
Write-Host "Installing QEMU Guest Agent and VirtIO drivers..."
Write-Host "=========================================="

# Try to find VirtIO ISO already mounted on a CD drive (e.g. if manually attached)
$virtioDrivers = $null
$drives = @('D:', 'E:', 'F:', 'G:')
$probeSubPaths = @("viostor\2k25\amd64", "viostor\2k22\amd64", "vioscsi\2k25\amd64", "vioscsi\2k22\amd64")

foreach ($drive in $drives) {
    foreach ($probe in $probeSubPaths) {
        $testPath = Join-Path $drive $probe
        if (Test-Path $testPath) {
            $virtioDrivers = $drive
            Write-Host "Found VirtIO drivers ISO mounted on $drive (detected via $probe)"
            break
        }
    }
    if ($null -ne $virtioDrivers) { break }
}

# If not found on CD, download the ISO
$downloadedIso = $null
if ($null -eq $virtioDrivers) {
    Write-Host "VirtIO drivers ISO not found on CD drives. Downloading..."

    $virtioUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    $virtioIso = "C:\Windows\Temp\virtio-win.iso"

    Write-Host "Downloading from: $virtioUrl"
    Write-Host "Saving to: $virtioIso"

    # Use BITS for more reliable download, fall back to Invoke-WebRequest
    try {
        Import-Module BitsTransfer -ErrorAction SilentlyContinue
        Start-BitsTransfer -Source $virtioUrl -Destination $virtioIso -ErrorAction Stop
        Write-Host "Download completed using BITS."
    } catch {
        Write-Host "BITS transfer failed, trying Invoke-WebRequest..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $virtioUrl -OutFile $virtioIso -UseBasicParsing
        Write-Host "Download completed using Invoke-WebRequest."
    }

    # Mount the ISO
    Write-Host "Mounting VirtIO ISO..."
    $mountResult = Mount-DiskImage -ImagePath $virtioIso -PassThru
    $virtioDrivers = (Get-Volume -DiskImage $mountResult).DriveLetter + ":"
    $downloadedIso = $virtioIso
    Write-Host "VirtIO ISO mounted on $virtioDrivers"
}

# Install VirtIO drivers using pnputil
# This pre-installs drivers so they're available when disk/network is switched to VirtIO
Write-Host ""
Write-Host "Installing VirtIO drivers..."

# Helper: resolve driver path, preferring 2k25 (Server 2025) then falling back to 2k22
function Resolve-DriverPath {
    param([string]$DriverName)
    $candidates = @("$DriverName\2k25\amd64", "$DriverName\2k22\amd64")
    foreach ($candidate in $candidates) {
        $fullPath = Join-Path $virtioDrivers $candidate
        if (Test-Path $fullPath) {
            return $fullPath
        }
    }
    return $null
}

$driverNames = @(
    "viostor",    # Block storage (for virtio-blk disk)
    "vioscsi",    # SCSI controller (for virtio-scsi disk)
    "NetKVM",     # Network adapter (for virtio-net)
    "Balloon",    # Memory balloon
    "vioserial",  # Serial console
    "qxldod",     # QXL display driver
    "pvpanic",    # Panic device
    "vioinput",   # Input devices
    "viorng"      # Random number generator
)

foreach ($name in $driverNames) {
    $driverPath = Resolve-DriverPath $name
    if ($null -ne $driverPath) {
        Write-Host "Installing drivers from: $driverPath"
        $infFiles = Get-ChildItem -Path $driverPath -Filter "*.inf" -ErrorAction SilentlyContinue
        foreach ($inf in $infFiles) {
            Write-Host "  Adding driver: $($inf.Name)"
            $result = pnputil.exe /add-driver $inf.FullName /install 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Success"
            } else {
                Write-Host "    Note: $result"
            }
        }
    } else {
        Write-Host "Skipping (not found on ISO): $name"
    }
}

# Install QEMU Guest Agent MSI
Write-Host ""
Write-Host "Installing QEMU Guest Agent..."

$guestAgentMsi = Join-Path $virtioDrivers "guest-agent\qemu-ga-x86_64.msi"
if (Test-Path $guestAgentMsi) {
    Write-Host "Installing from: $guestAgentMsi"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$guestAgentMsi`"", "/qn", "/norestart" -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Host "QEMU Guest Agent installed successfully."
    } else {
        Write-Host "QEMU Guest Agent installation returned exit code: $($process.ExitCode)"
    }
} else {
    Write-Host "WARNING: QEMU Guest Agent MSI not found at $guestAgentMsi"
}

# Install VirtIO Guest Tools MSI (includes balloon service, etc.)
Write-Host ""
Write-Host "Installing VirtIO Guest Tools..."

$virtioGtMsi = Join-Path $virtioDrivers "virtio-win-gt-x64.msi"
if (Test-Path $virtioGtMsi) {
    Write-Host "Installing from: $virtioGtMsi"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$virtioGtMsi`"", "/qn", "/norestart" -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Host "VirtIO Guest Tools installed successfully."
    } else {
        Write-Host "VirtIO Guest Tools installation returned exit code: $($process.ExitCode)"
    }
} else {
    Write-Host "WARNING: VirtIO Guest Tools MSI not found at $virtioGtMsi"
}

# Start the QEMU Guest Agent service
Write-Host ""
Write-Host "Configuring QEMU Guest Agent service..."

$service = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
if ($null -ne $service) {
    Set-Service -Name "QEMU-GA" -StartupType Automatic
    Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
    Write-Host "QEMU Guest Agent service configured and started."
} else {
    Write-Host "WARNING: QEMU Guest Agent service not found."
}

# Cleanup: Unmount and delete downloaded ISO if we downloaded it
if ($null -ne $downloadedIso) {
    Write-Host ""
    Write-Host "Cleaning up downloaded ISO..."
    Dismount-DiskImage -ImagePath $downloadedIso -ErrorAction SilentlyContinue
    Remove-Item -Path $downloadedIso -Force -ErrorAction SilentlyContinue
    Write-Host "Cleanup completed."
}

Write-Host ""
Write-Host "=========================================="
Write-Host "QEMU guest tools installation complete!"
Write-Host ""
Write-Host "VirtIO drivers are now installed. When this"
Write-Host "Vagrant box runs with libvirt using VirtIO"
Write-Host "devices, the drivers will be ready."
Write-Host "=========================================="
