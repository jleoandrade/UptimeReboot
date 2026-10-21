# Read-only: shows which revision of the "Uptime Reboot" application the SCCM client really has,
# and whether the new policy was downloaded. Run elevated on the client.

function Format-LogLine([string]$Line) {
    # CMTrace line -> "[date time] message"
    if ($Line -match '^<!\[LOG\[(.*)\]LOG\]!><time="([0-9:]+)\.\d+[^"]*" date="([^"]+)"') { "[$($Matches[3]) $($Matches[2])] $($Matches[1])" }
    else { $Line }
}

$logs = 'C:\Windows\CCM\Logs'
$os = Get-CimInstance -ClassName Win32_OperatingSystem
'Now on client: {0:yyyy-MM-dd HH:mm} | Uptime: {1:N0} min' -f $os.LocalDateTime, ($os.LocalDateTime - $os.LastBootUpTime).TotalMinutes

'===== Application as the client sees it (WMI, authoritative)'
Get-CimInstance -Namespace root\ccm\ClientSDK -ClassName CCM_Application -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*Uptime*' } |
    Select-Object Name, Revision, InstallState, EvaluationState, LastEvalTime | Format-List | Out-String

'===== Last detection of the deployment type (AppDiscovery.log): the revision only changes here after an evaluation'
Select-String -Path "$logs\AppDiscovery.log" -Pattern 'Lab - Uptime Maximum 1h.*Revision' |
    Select-Object -Last 1 | ForEach-Object { Format-LogLine $_.Line }

'===== Last policy downloads (PolicyAgent.log)'
Select-String -Path "$logs\PolicyAgent.log" -Pattern 'Received|Requesting|Successfully|policy update' |
    Select-Object -Last 6 | ForEach-Object { Format-LogLine $_.Line }

'===== Deployment type definition downloads (CIDownloader.log)'
Select-String -Path "$logs\CIDownloader.log" -Pattern '7714dcca' -ErrorAction SilentlyContinue |
    Select-Object -Last 4 | ForEach-Object { Format-LogLine $_.Line }
