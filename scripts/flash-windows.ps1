#Requires -RunAsAdministrator
param(
  [string]$Iso = "",
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z]$')]
  [string]$DriveLetter
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $Iso) {
  $Iso = Join-Path $Root "out\stickllm-amd-rtx3090.hybrid.iso"
}

if (-not (Test-Path $Iso)) {
  Write-Error "Missing ISO: $Iso — build with WSL: ./scripts/build.sh"
}

$letter = $DriveLetter.ToUpper()
$vol = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if (-not $vol) { Write-Error "No volume for ${letter}:" }
if ($vol.DriveType -ne 'Removable') {
  Write-Error "Refusing: ${letter}: is DriveType=$($vol.DriveType) (need Removable)"
}

Write-Host "ISO:  $Iso"
Write-Host "USB:  ${letter}:  label=$($vol.FileSystemLabel)  size=$([math]::Round($vol.Size/1GB,2)) GB"
Write-Host ""
Write-Host "This ERASES the USB and writes a raw hybrid ISO (DD mode)."
$confirm = Read-Host "Type FLASH to continue"
if ($confirm -ne "FLASH") { Write-Host "Aborted."; exit 1 }

# Prefer WSL dd for reliable raw write
$wslIso = (wsl wslpath -a "$Iso").Trim()
$boot = Get-CimInstance Win32_DiskDrive | Where-Object { $_.InterfaceType -match 'USB|SCSI' } 
# Map letter → physical disk via partition
$part = Get-Partition -DriveLetter $letter
$diskNumber = $part.DiskNumber
$phys = "\\\\.\\PhysicalDrive$diskNumber"

Write-Host "PhysicalDrive$diskNumber → $phys"

# Use Rufus-like approach via WSL if the device is visible; else instruct Rufus
Write-Host ""
Write-Host "Recommended on Windows: use Rufus in DD Image mode."
Write-Host "  ISO: $Iso"
Write-Host "  Target: ${letter}: (PhysicalDrive$diskNumber)"
Write-Host ""
Write-Host "Attempting WSL raw write (requires USB visible as /dev/sdX in WSL)…"

$sd = wsl bash -lc "lsblk -dn -o NAME,SIZE,RM,MODEL | awk '\$3==1{print \$1, \$2, \$4}'"
Write-Host "WSL removable disks:`n$sd"
$dev = Read-Host "Enter WSL device name only (e.g. sdc) or press Enter to abort and use Rufus"
if (-not $dev) { Write-Host "Aborted — use Rufus DD mode."; exit 1 }

wsl bash -lc "set -e; test -b /dev/$dev; wipefs -a /dev/$dev; dd if='$wslIso' of=/dev/$dev bs=4M status=progress oflag=sync"
Write-Host "Done. Eject ${letter}: and boot with Secure Boot disabled."
