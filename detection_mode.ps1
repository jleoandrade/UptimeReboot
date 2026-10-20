#requires -version 5.1

<#
.SYNOPSIS
    SCCM detection method for uptime enforcement.

.DESCRIPTION
    LAB:
    Considers the deployment detected while uptime is below 60 minutes.

    Once uptime reaches 60 minutes, exits successfully without STDOUT,
    causing SCCM to consider the Deployment Type not detected.

    No restart is performed by this script.

.NOTES
    Purpose: SCCM Lab-Uptime
    Context: SYSTEM
#>

$ErrorActionPreference = 'Stop'

# ============================================================
# CONFIGURATION
# ============================================================

$MaximumUptimeMinutes = 60


# ============================================================
# MAIN
# ============================================================

try {

    $OperatingSystem = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction Stop

    $LastBootTime = $OperatingSystem.LastBootUpTime

    if ($null -eq $LastBootTime) {
        throw 'LastBootUpTime returned null.'
    }

    $CurrentTime = Get-Date

    $Uptime = $CurrentTime - $LastBootTime

    $UptimeMinutes = [math]::Floor(
        $Uptime.TotalMinutes
    )


    # ========================================================
    # COMPLIANT
    #
    # Uptime < 60 minutes
    #
    # STDOUT causes SCCM to detect the Deployment Type.
    # ========================================================

    if ($UptimeMinutes -lt $MaximumUptimeMinutes) {

        Write-Output 'Installed'

        exit 0
    }


    # ========================================================
    # THRESHOLD REACHED
    #
    # Uptime >= 60 minutes
    #
    # Exit 0 WITHOUT STDOUT.
    # SCCM detection should therefore indicate not detected.
    # ========================================================

    exit 0

}
catch {

    # Fail safely.
    #
    # We don't want an inability to determine uptime
    # to become authorization to restart the endpoint.

    exit 1
}
