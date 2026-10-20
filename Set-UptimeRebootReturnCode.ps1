<#
.SYNOPSIS
    Sets return code 17010 to Soft Reboot on the "Uptime Reboot" deployment type and shows the result.

.DESCRIPTION
    Run from the Configuration Manager console PowerShell (PS <SiteCode>:\>), ConfigMgr 2107 or later.
    Idempotent: if 17010 is already Soft Reboot, nothing is changed.
    Shows the deployment type revision and the return codes before and after. The client must receive a
    revision HIGHER than the one shown in AppDiscovery.log for the change to take effect.

.EXAMPLE
    .\Set-UptimeRebootReturnCode.ps1 -ApplicationName 'Lab - Uptime Maximum 1h'
#>

param(
    # Application name exactly as shown in Software Library > Applications (Name column)
    [Parameter(Mandatory)]
    [string]$ApplicationName,

    # Deployment type name as shown in AppDiscovery.log / AppEnforce.log
    [string]$DeploymentTypeName = 'Lab - Uptime Maximum 1h'
)

$ErrorActionPreference = 'Stop'
$RebootCode = 17010

function Get-UptimeDeploymentType {
    $deploymentType = Get-CMDeploymentType -ApplicationName $ApplicationName -DeploymentTypeName $DeploymentTypeName
    if (-not $deploymentType) { throw "Deployment type '$DeploymentTypeName' not found in application '$ApplicationName'." }
    $deploymentType
}

function Show-ReturnCodes($DeploymentType, $Label) {
    "===== $Label - deployment type revision (CIVersion): $($DeploymentType.CIVersion)"
    Get-CMDeploymentTypeReturnCode -InputObject $DeploymentType | Format-Table -AutoSize | Out-String
}

$deploymentType = Get-UptimeDeploymentType
Show-ReturnCodes $deploymentType 'BEFORE'

$current = Get-CMDeploymentTypeReturnCode -InputObject $deploymentType | Where-Object { $_.Code -eq $RebootCode }
if (-not $current) {
    Add-CMDeploymentTypeReturnCode -InputObject $deploymentType -ReturnCode $RebootCode -Name 'UptimeRebootRequired' `
        -CodeType SoftReboot -Description 'Uptime at or above threshold'
    "Return code $RebootCode added as Soft Reboot."
}
elseif ("$($current.Class)" -ne 'SoftReboot') {
    Set-CMDeploymentTypeReturnCode -InputObject $deploymentType -ReturnCode $RebootCode -CodeType SoftReboot
    "Return code $RebootCode changed from $($current.Class) to Soft Reboot."
}
else {
    "Return code $RebootCode is already Soft Reboot. Nothing changed."
}

Show-ReturnCodes (Get-UptimeDeploymentType) 'AFTER'
