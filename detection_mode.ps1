#requires -version 5.1

<#
.SYNOPSIS
    Configuration Manager detection method for uptime enforcement.

.DESCRIPTION
    If device uptime is below 60 minutes:
        Writes "Installed" to STDOUT.
        Configuration Manager considers the Deployment Type detected.

    If device uptime is 60 minutes or greater:
        Produces no STDOUT.
        Configuration Manager considers the Deployment Type not detected.

    This script does not modify the device.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================================================
# CONFIGURATION
# ============================================================

$MaximumUptimeMinutes = 60


# ============================================================
# DETECTION
# ============================================================

try {

    $OperatingSystem = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction Stop


    if ($null -eq $OperatingSystem) {

        throw 'Win32_OperatingSystem returned null.'
    }


    $LastBootTime = $OperatingSystem.LastBootUpTime


    if ($null -eq $LastBootTime) {

        throw 'LastBootUpTime returned null.'
    }


    $CurrentTime = Get-Date

    $Uptime = $CurrentTime - $LastBootTime


    if ($Uptime.TotalMinutes -lt 0) {

        throw 'Calculated uptime is negative.'
    }


    $UptimeMinutes = [math]::Floor(
        $Uptime.TotalMinutes
    )


    # Uptime is below the maximum threshold.
    # STDOUT + exit code 0 means detected.

    if ($UptimeMinutes -lt $MaximumUptimeMinutes) {

        Write-Output 'Installed'

        exit 0
    }


    # Uptime reached or exceeded the threshold..
    #
    # Exit code 0 with no STDOUT means not detected.
    # Configuration Manager can then enforce the Required deployment.

    exit 0
}
catch {

    # Detection failures must never be interpreted
    # as authorization to restart the device.

    exit 1
}
